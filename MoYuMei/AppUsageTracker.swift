import AppKit
import Combine

struct AppUsageRecord: Identifiable {
    let id: String          // bundleIdentifier
    var appName: String
    var fishingSeconds: TimeInterval
    var workingSeconds: TimeInterval
    var icon: NSImage?

    var totalSeconds: TimeInterval { fishingSeconds + workingSeconds }

    func hasSameVisibleContent(as other: AppUsageRecord) -> Bool {
        id == other.id
            && appName == other.appName
            && Int(fishingSeconds) == Int(other.fishingSeconds)
            && Int(workingSeconds) == Int(other.workingSeconds)
            && icon === other.icon
    }
}

enum OvertimeDurationMode: String, CaseIterable, Identifiable {
    case actual = "实际时长"
    case halfDay = "半天"
    case fullDay = "全天"

    var id: String { rawValue }

    var dayFraction: Double {
        switch self {
        case .actual: return 0
        case .halfDay: return 0.5
        case .fullDay: return 1
        }
    }
}

enum OvertimeSettlement {
    case unpaid
    case hourly(amount: Double)
    case fixed(amount: Double)
    case salaryMultiplier(multiplier: Double, duration: OvertimeDurationMode)

    var isSingleCharge: Bool {
        switch self {
        case .fixed:
            return true
        case .salaryMultiplier(_, let duration):
            return duration != .actual
        case .unpaid, .hourly:
            return false
        }
    }
}

class AppUsageTracker: ObservableObject {
    @Published var records: [AppUsageRecord] = []
    @Published var isFishingMode: Bool = false  // 手动切换：摸鱼中 / 搬砖中
    @Published var isOvertimeMode: Bool = false
    @Published private(set) var dailyArchives: [String: [AppUsageRecord]] = [:]
    @Published private(set) var overtimeArchives: [String: DailyOvertimeRecord] = [:]

    // 今日拆分秒数（从 records 聚合）
    var totalFishingSeconds: TimeInterval { records.reduce(0) { $0 + $1.fishingSeconds } }
    var totalWorkingSeconds: TimeInterval { records.reduce(0) { $0 + $1.workingSeconds } }
    var liveFishingSeconds: TimeInterval { liveTotals().fishing }
    var liveWorkingSeconds: TimeInterval { liveTotals().working }
    var currentCategory: AppCategory {
        guard let activeID else { return isFishingMode ? .fishing : .working }
        return category(for: activeID)
    }
    var isCurrentlyFishing: Bool { currentCategory == .fishing }
    var currentStatus: UsageStatus { status(at: Date()) }

    private let selfBundleID = Bundle.main.bundleIdentifier ?? ""
    private weak var salaryManager: SalaryManager?

    private var activeID: String?
    private var activeStart: Date?
    private var activeDayKey: String?
    private var overtimeModeActive = false
    private var overtimeStart: Date?
    private var currentOvertimeSettlement: OvertimeSettlement = .unpaid
    private var currentOvertimeFixedPaid = false
    // storage: bundleID -> (name, fishingSec, workingSec, icon)
    private var storage: [String: (name: String, fishing: TimeInterval, working: TimeInterval, icon: NSImage?)] = [:]
    private var appMetadata: [String: (name: String, icon: NSImage?)] = [:]

    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private let storageFile = "usage-data.json"
    private var lastUsageSave = Date.distantPast
    private let saveInterval: TimeInterval = 15

    init(salaryManager: SalaryManager) {
        self.salaryManager = salaryManager
        loadUsage()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.appDidActivate(note)
        }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        activeDayKey = dayKey(for: Date())

        if let frontmost = NSWorkspace.shared.frontmostApplication,
           let id = frontmost.bundleIdentifier, id != selfBundleID {
            activeID = id
            activeStart = Date()
            let meta = metadata(from: frontmost, bundleID: id)
            storage[id] = (meta.name, 0, 0, meta.icon)
            appMetadata[id] = meta
        }
    }

    private func appDidActivate(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        guard let id = app?.bundleIdentifier, id != selfBundleID else {
            commitCurrent(); activeID = nil; return
        }
        commitCurrent()
        activeID = id
        activeStart = Date()
        activeDayKey = dayKey(for: Date())
        if storage[id] == nil {
            let metadata = metadata(from: app, bundleID: id)
            storage[id] = (metadata.name, 0, 0, metadata.icon)
            appMetadata[id] = metadata
        } else if let app {
            let metadata = metadata(from: app, bundleID: id)
            appMetadata[id] = metadata
            storage[id]?.name = metadata.name
            if storage[id]?.icon == nil {
                storage[id]?.icon = metadata.icon
            }
        }
    }

    private func commitCurrent() {
        guard let id = activeID, let start = activeStart else { return }
        let now = Date()
        commitActiveApp(id: id, from: start, to: now)
        activeStart = now
        activeDayKey = dayKey(for: now)
    }

    private func tick() {
        commitOvertimeIfNeeded(to: Date())
        commitCurrent()
        publishRecords(records(from: storage))
        persistCurrentDay()
    }

    func liveTotals(at date: Date = Date()) -> (fishing: TimeInterval, working: TimeInterval) {
        var fishing = storage.values.reduce(0) { $0 + $1.fishing }
        var working = storage.values.reduce(0) { $0 + $1.working }

        guard let id = activeID,
              let start = activeStart else {
            return (fishing, working)
        }

        let elapsed = salaryManager?.workingSeconds(from: start, to: date) ?? 0
        let category = category(for: id)
        if category == .fishing {
            fishing += elapsed
        } else {
            working += elapsed
        }

        return (fishing, working)
    }

    func liveRecords(at date: Date = Date()) -> [AppUsageRecord] {
        var snapshot = storage

        if let id = activeID, let start = activeStart {
            let elapsed = salaryManager?.workingSeconds(from: start, to: date) ?? 0
            let category = category(for: id)
            if category == .fishing {
                snapshot[id]?.fishing += elapsed
            } else {
                snapshot[id]?.working += elapsed
            }
        }

        return records(from: snapshot)
    }

    func toggleFishingMode() {
        commitCurrent()
        isFishingMode.toggle()
    }

    func toggleOvertimeMode(settlement: OvertimeSettlement? = nil, delayUntilWorkEnds: Bool = false) {
        let now = Date()
        if overtimeModeActive {
            commitOvertimeIfNeeded(to: now)
        } else {
            commitCurrent()
        }

        let shouldStart = !overtimeModeActive
        overtimeModeActive = shouldStart
        isOvertimeMode = shouldStart
        currentOvertimeSettlement = shouldStart ? (settlement ?? defaultOvertimeSettlement()) : .unpaid
        currentOvertimeFixedPaid = false
        overtimeStart = shouldStart ? overtimeStartDate(for: now, delayUntilWorkEnds: delayUntilWorkEnds) : nil
        activeStart = now
        activeDayKey = dayKey(for: now)
    }

    func status(at date: Date = Date()) -> UsageStatus {
        if overtimeModeActive,
           salaryManager?.isWorkingTime(at: date) != true,
           date >= (overtimeStart ?? date) {
            return .overtime
        }
        guard salaryManager?.isWorkingTime(at: date) == true else { return .free }
        return currentCategory == .fishing ? .fishing : .working
    }

    private func category(for bundleID: String) -> AppCategory {
        if salaryManager?.fishingApps.contains(bundleID) == true { return .fishing }
        if salaryManager?.workingApps.contains(bundleID) == true { return .working }
        return isFishingMode ? .fishing : .working
    }

    func archivedRecords(for dayKey: String) -> [AppUsageRecord] {
        if dayKey == self.dayKey(for: Date()) {
            return liveRecords()
        }
        return dailyArchives[dayKey] ?? []
    }

    func daySummaries(forMonthContaining date: Date) -> [DailyUsageSummary] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
        var summaries: [DailyUsageSummary] = []
        var cursor = monthInterval.start

        while cursor < monthInterval.end {
            let key = dayKey(for: cursor)
            let records = archivedRecords(for: key)
            summaries.append(
                DailyUsageSummary(
                    id: key,
                    date: cursor,
                    fishingSeconds: records.reduce(0) { $0 + $1.fishingSeconds },
                    workingSeconds: records.reduce(0) { $0 + $1.workingSeconds },
                    overtimeSeconds: overtimeArchives[key]?.seconds ?? 0
                )
            )
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? monthInterval.end
        }

        return summaries
    }

    func liveOvertimeRecord(at date: Date = Date()) -> DailyOvertimeRecord {
        let key = dayKey(for: date)
        var record = overtimeArchives[key] ?? DailyOvertimeRecord()

        guard overtimeModeActive,
              salaryManager?.isWorkingTime(at: date) != true,
              let start = overtimeStart else {
            return record
        }

        let segments = nonWorkingSegments(from: start, to: date)
        let firstSegmentKey = segments.first.map { dayKey(for: $0.start) }

        for segment in segments where dayKey(for: segment.start) == key {
            let shouldPreviewSingleCharge = currentOvertimeSettlement.isSingleCharge && !currentOvertimeFixedPaid && firstSegmentKey == key
            applyOvertime(from: segment.start, to: segment.end, into: &record, applySingleCharge: shouldPreviewSingleCharge)
        }

        return record
    }

    func exportUsageData() -> Data? {
        commitCurrent()
        persistCurrentDay(for: activeDayKey)
        return encodedUsageState(prettyPrinted: true)
    }

    func importUsageData(_ data: Data) throws {
        let state = try JSONDecoder().decode(UsageStorageState.self, from: data)
        commitCurrent()
        applyUsageState(state)
        saveUsage()
    }

    func clearUsageData() {
        storage = [:]
        records = []
        dailyArchives = [:]
        overtimeArchives = [:]
        appMetadata = [:]
        activeStart = activeID == nil ? nil : Date()
        activeDayKey = dayKey(for: Date())
        overtimeStart = overtimeModeActive ? Date() : nil
        lastUsageSave = Date.distantPast
        AppStorage.remove(storageFile)
    }

    private func persistCurrentDay(for key: String? = nil) {
        let key = key ?? dayKey(for: Date())
        publishDailyArchive(key: key, records: records(from: storage))
    }

    private func commitActiveApp(id: String, from start: Date, to end: Date) {
        guard end > start else { return }

        var cursor = start
        while cursor < end {
            let segmentEnd = endOfDaySegment(from: cursor, boundedBy: end)
            let segmentKey = dayKey(for: cursor)

            if let previousDayKey = activeDayKey, previousDayKey != segmentKey {
                persistCurrentDay(for: previousDayKey)
                storage = [:]
                activeDayKey = segmentKey
            }

            if storage[id] == nil {
                storage[id] = metadataForApp(bundleID: id)
            }

            let elapsed = salaryManager?.workingSeconds(from: cursor, to: segmentEnd) ?? 0
            let category = category(for: id)
            if category == .fishing {
                storage[id]?.fishing += elapsed
            } else {
                storage[id]?.working += elapsed
            }

            cursor = segmentEnd
        }
    }

    private func endOfDaySegment(from start: Date, boundedBy end: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: start)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? end
        return min(end, nextDay)
    }

    private func metadata(from app: NSRunningApplication?, bundleID: String) -> (name: String, icon: NSImage?) {
        let name = app?.localizedName
            ?? appMetadata[bundleID]?.name
            ?? AppIconLoader.displayName(forBundleIdentifier: bundleID)
            ?? bundleID
        let icon = AppIconLoader.icon(for: app)
            ?? appMetadata[bundleID]?.icon
            ?? AppIconLoader.icon(forBundleIdentifier: bundleID)
        return (name, icon)
    }

    private func metadataForApp(bundleID: String) -> (name: String, fishing: TimeInterval, working: TimeInterval, icon: NSImage?) {
        let metadata = appMetadata[bundleID]
        let name = metadata?.name
            ?? AppIconLoader.displayName(forBundleIdentifier: bundleID)
            ?? bundleID
        let icon = metadata?.icon ?? AppIconLoader.icon(forBundleIdentifier: bundleID)
        return (name, 0, 0, icon)
    }

    private func commitOvertimeIfNeeded(to end: Date) {
        guard overtimeModeActive, let start = overtimeStart else { return }
        commitOvertime(from: start, to: end)
        overtimeStart = end
    }

    private func commitOvertime(from start: Date, to end: Date) {
        guard end > start else { return }

        var didCommitSingleCharge = false

        for segment in nonWorkingSegments(from: start, to: end) {
            let key = dayKey(for: segment.start)
            var record = overtimeArchives[key] ?? DailyOvertimeRecord()
            let shouldCommitSingleCharge = currentOvertimeSettlement.isSingleCharge && !currentOvertimeFixedPaid && !didCommitSingleCharge
            applyOvertime(from: segment.start, to: segment.end, into: &record, applySingleCharge: shouldCommitSingleCharge)
            if shouldCommitSingleCharge {
                didCommitSingleCharge = true
            }
            publishOvertimeArchive(key: key, record: record, forceSave: true)
        }

        if didCommitSingleCharge {
            currentOvertimeFixedPaid = true
        }
    }

    private func nonWorkingSegments(from start: Date, to end: Date) -> [(start: Date, end: Date)] {
        guard end > start else { return [] }

        var segments: [(start: Date, end: Date)] = []
        var cursor = start

        while cursor < end {
            let dayEnd = endOfDaySegment(from: cursor, boundedBy: end)
            var available = [(start: cursor, end: dayEnd)]

            for work in salaryManager?.workingIntervals(on: cursor) ?? [] {
                available = available.flatMap { segment -> [(start: Date, end: Date)] in
                    let overlapStart = max(segment.start, work.start)
                    let overlapEnd = min(segment.end, work.end)
                    guard overlapEnd > overlapStart else { return [segment] }

                    var pieces: [(start: Date, end: Date)] = []
                    if segment.start < overlapStart {
                        pieces.append((segment.start, overlapStart))
                    }
                    if overlapEnd < segment.end {
                        pieces.append((overlapEnd, segment.end))
                    }
                    return pieces
                }
            }

            segments.append(contentsOf: available.filter { $0.end > $0.start })
            cursor = dayEnd
        }

        return segments
    }

    private func applyOvertime(from start: Date, to end: Date, into record: inout DailyOvertimeRecord, applySingleCharge: Bool) {
        let elapsed = max(end.timeIntervalSince(start), 0)
        guard elapsed > 0 else { return }

        let salary = salaryManager
        let salaryPerSecond = salary?.salaryPerSecond ?? 0

        switch currentOvertimeSettlement {
        case .unpaid:
            record.seconds += elapsed
            record.unpaidValue += elapsed * salaryPerSecond
        case .hourly(let amount):
            record.seconds += elapsed
            record.unpaidValue += elapsed * salaryPerSecond
            record.income += elapsed / 3600 * max(amount, 0)
        case .fixed(let amount):
            record.seconds += elapsed
            record.unpaidValue += elapsed * salaryPerSecond
            if applySingleCharge {
                record.income += max(amount, 0)
                record.fixedPaid = true
            }
        case .salaryMultiplier(let multiplier, let duration):
            if duration == .actual {
                record.seconds += elapsed
                record.unpaidValue += elapsed * salaryPerSecond
                record.income += elapsed * salaryPerSecond * max(multiplier, 0)
            } else if applySingleCharge {
                let billedSeconds = (salary?.workSecondsPerDay ?? 0) * duration.dayFraction
                record.seconds += billedSeconds
                record.unpaidValue += billedSeconds * salaryPerSecond
                record.income += billedSeconds * salaryPerSecond * max(multiplier, 0)
                record.fixedPaid = true
            }
        }
    }

    private func defaultOvertimeSettlement() -> OvertimeSettlement {
        switch salaryManager?.overtimePayMode ?? .unpaid {
        case .hourly:
            return .hourly(amount: salaryManager?.overtimeAmount ?? 0)
        case .unpaid:
            return .unpaid
        }
    }

    private func overtimeStartDate(for date: Date, delayUntilWorkEnds: Bool) -> Date {
        guard delayUntilWorkEnds,
              salaryManager?.isWorkday(at: date) == true,
              let lastWorkEnd = salaryManager?.workingIntervals(on: date).map({ $0.end }).max(),
              date < lastWorkEnd else {
            return date
        }

        return lastWorkEnd
    }

    private func publishRecords(_ newRecords: [AppUsageRecord]) {
        guard !records.hasSameVisibleContent(as: newRecords) else { return }
        records = newRecords
    }

    private func publishDailyArchive(key: String, records: [AppUsageRecord], forceSave: Bool = false) {
        if !forceSave,
           let existing = dailyArchives[key],
           existing.hasSameVisibleContent(as: records) {
            saveUsageIfNeeded(force: false)
            return
        }
        dailyArchives[key] = records
        saveUsageIfNeeded(force: forceSave)
    }

    private func publishOvertimeArchive(key: String, record: DailyOvertimeRecord, forceSave: Bool = false) {
        if !forceSave, overtimeArchives[key]?.hasSameVisibleContent(as: record) == true {
            saveUsageIfNeeded(force: false)
            return
        }
        overtimeArchives[key] = record
        saveUsageIfNeeded(force: forceSave)
    }

    private func records(from snapshot: [String: (name: String, fishing: TimeInterval, working: TimeInterval, icon: NSImage?)]) -> [AppUsageRecord] {
        snapshot
            .map { AppUsageRecord(id: $0, appName: $1.name, fishingSeconds: $1.fishing, workingSeconds: $1.working, icon: $1.icon) }
            .sorted { $0.totalSeconds > $1.totalSeconds }
    }

    private func dayKey(for date: Date) -> String {
        DateFormatting.dayKey(for: date)
    }

    private func saveUsageIfNeeded(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastUsageSave) >= saveInterval else { return }
        saveUsage()
        lastUsageSave = now
    }

    private func saveUsage() {
        if let data = encodedUsageState(prettyPrinted: false) {
            AppStorage.save(data, to: storageFile)
        }
    }

    private func encodedUsageState(prettyPrinted: Bool) -> Data? {
        let state = UsageStorageState(
            days: dailyArchives.mapValues { records in
                records.map {
                    StoredAppUsageRecord(
                        id: $0.id,
                        appName: $0.appName,
                        fishingSeconds: $0.fishingSeconds,
                        workingSeconds: $0.workingSeconds
                    )
                }
            },
            overtimeDays: overtimeArchives
        )

        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try? encoder.encode(state)
    }

    private func loadUsage() {
        if let data = AppStorage.load(from: storageFile),
           let state = try? JSONDecoder().decode(UsageStorageState.self, from: data) {
            applyUsageState(state)
            return
        }
        // migrate from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "MoYuMei.AppUsageTracker.v1"),
           let state = try? JSONDecoder().decode(UsageStorageState.self, from: data) {
            applyUsageState(state)
            UserDefaults.standard.removeObject(forKey: "MoYuMei.AppUsageTracker.v1")
            saveUsage()
        }
    }

    private func applyUsageState(_ state: UsageStorageState) {
        dailyArchives = state.days.mapValues { records in
            records.map {
                let name = AppIconLoader.displayName(forBundleIdentifier: $0.id) ?? $0.appName
                return AppUsageRecord(
                    id: $0.id,
                    appName: name,
                    fishingSeconds: $0.fishingSeconds,
                    workingSeconds: $0.workingSeconds,
                    icon: AppIconLoader.icon(forBundleIdentifier: $0.id)
                )
            }
        }
        records = dailyArchives[dayKey(for: Date())] ?? []
        overtimeArchives = state.overtimeDays ?? [:]
        storage = Dictionary(uniqueKeysWithValues: records.map {
            ($0.id, (name: $0.appName, fishing: $0.fishingSeconds, working: $0.workingSeconds, icon: $0.icon))
        })
        appMetadata = Dictionary(uniqueKeysWithValues: records.map {
            ($0.id, (name: $0.appName, icon: $0.icon))
        })
    }


    deinit {
        commitCurrent()
        persistCurrentDay(for: activeDayKey)
        saveUsage()
        timer?.invalidate()
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
}

struct DailyUsageSummary: Identifiable {
    let id: String
    var date: Date
    var fishingSeconds: TimeInterval
    var workingSeconds: TimeInterval
    var overtimeSeconds: TimeInterval

    var totalSeconds: TimeInterval { fishingSeconds + workingSeconds + overtimeSeconds }
}

private struct UsageStorageState: Codable {
    var days: [String: [StoredAppUsageRecord]]
    var overtimeDays: [String: DailyOvertimeRecord]?
}

private struct StoredAppUsageRecord: Codable {
    var id: String
    var appName: String
    var fishingSeconds: TimeInterval
    var workingSeconds: TimeInterval
}

struct DailyOvertimeRecord: Codable {
    var seconds: TimeInterval = 0
    var income: Double = 0
    var unpaidValue: Double = 0
    var fixedPaid: Bool = false

    func hasSameVisibleContent(as other: DailyOvertimeRecord) -> Bool {
        Int(seconds) == Int(other.seconds)
            && income == other.income
            && unpaidValue == other.unpaidValue
            && fixedPaid == other.fixedPaid
    }
}

private extension Array where Element == AppUsageRecord {
    func hasSameVisibleContent(as other: [AppUsageRecord]) -> Bool {
        guard count == other.count else { return false }
        return zip(self, other).allSatisfy { $0.hasSameVisibleContent(as: $1) }
    }
}

import Foundation
import Combine

enum WorkSchedule: String, CaseIterable, Identifiable {
    case bigSmallWeek = "大小周"
    case singleRest   = "单休"
    case doubleRest   = "双休"
    var id: String { rawValue }
}

enum OvertimePayMode: String, CaseIterable, Identifiable {
    case hourly = "小时计费"
    case fixed = "一次性"
    case unpaid = "无偿"

    var id: String { rawValue }
}

class SalaryManager: ObservableObject {
    @Published var monthlySalary: Double = 10000 { didSet { saveSettings() } }
    @Published var workSchedule: WorkSchedule = .doubleRest { didSet { saveSettings() } }
    @Published var bigWeekReferenceDate: Date = {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: Date()))!
    }() { didSet { saveSettings() } }
    @Published var workStartHour: Int = 9 { didSet { saveSettings() } }
    @Published var workStartMinute: Int = 0 { didSet { saveSettings() } }
    @Published var workEndHour: Int = 18 { didSet { saveSettings() } }
    @Published var workEndMinute: Int = 0 { didSet { saveSettings() } }
    @Published var lunchStartHour: Int = 12 { didSet { saveSettings() } }
    @Published var lunchStartMinute: Int = 0 { didSet { saveSettings() } }
    @Published var lunchEndHour: Int = 13 { didSet { saveSettings() } }
    @Published var lunchEndMinute: Int = 0 { didSet { saveSettings() } }
    @Published var overtimePayMode: OvertimePayMode = .unpaid { didSet { saveSettings() } }
    @Published var overtimeAmount: Double = 0 { didSet { saveSettings() } }

    // 摸鱼/搬砖 App 列表（存 bundleID）
    @Published var fishingApps: Set<String> = [] { didSet { saveSettings() } }
    @Published var workingApps: Set<String> = [] { didSet { saveSettings() } }

    var isBigWeek: Bool { isBigWeek(at: Date()) }

    func isBigWeek(at date: Date) -> Bool {
        let refMonday = Self.mondayOfWeek(containing: bigWeekReferenceDate)
        let targetMonday = Self.mondayOfWeek(containing: date)
        let days = Calendar.current.dateComponents([.day], from: refMonday, to: targetMonday).day ?? 0
        let weeks = days / 7
        return weeks % 2 == 0
    }

    func setCurrentWeekAsBig(_ big: Bool) {
        let thisMonday = Self.mondayOfWeek(containing: Date())
        if big {
            bigWeekReferenceDate = thisMonday
        } else {
            bigWeekReferenceDate = Calendar.current.date(byAdding: .day, value: 7, to: thisMonday)!
        }
    }

    static func mondayOfWeek(containing date: Date) -> Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: date))!
    }

    private var isRestoring = false
    private let settingsFile = "salary-settings.json"

    init() {
        loadSettings()
    }

    func exportSettingsData() -> Data? {
        encodedSettingsState(prettyPrinted: true)
    }

    func importSettingsData(_ data: Data) throws {
        let state = try JSONDecoder().decode(SalarySettingsState.self, from: data)
        applySettingsState(state)
        saveSettings()
    }

    var workDaysPerMonth: Double {
        switch workSchedule {
        case .doubleRest:   return 21.75
        case .singleRest:   return 26.0
        case .bigSmallWeek: return 23.875
        }
    }

    var workSecondsPerDay: Double {
        let workStart = Self.clampHour(workStartHour) * 60 + Self.clampMinute(workStartMinute)
        let workEnd = Self.clampHour(workEndHour) * 60 + Self.clampMinute(workEndMinute)
        let lunchStart = Self.clampHour(lunchStartHour) * 60 + Self.clampMinute(lunchStartMinute)
        let lunchEnd = Self.clampHour(lunchEndHour) * 60 + Self.clampMinute(lunchEndMinute)
        let workMinutes = max(workEnd - workStart, 0)
        let breakMinutes = max(min(workEnd, lunchEnd) - max(workStart, lunchStart), 0)
        return Double(max(workMinutes - breakMinutes, 0)) * 60
    }

    var salaryPerSecond: Double {
        guard workSecondsPerDay > 0, workDaysPerMonth > 0 else { return 0 }
        return max(monthlySalary, 0) / workDaysPerMonth / workSecondsPerDay
    }

    // 基于时钟计算今日在岗总秒数
    func workedSecondsToday(at date: Date = Date()) -> Double {
        guard isWorkday(at: date) else { return 0 }

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        return workingSeconds(from: startOfDay, to: date)
    }

    var workedSecondsToday: Double { workedSecondsToday() }
    var earnedToday: Double { workedSecondsToday * salaryPerSecond }
    func earnedToday(at date: Date = Date()) -> Double { workedSecondsToday(at: date) * salaryPerSecond }

    func isWorkingTime(at date: Date = Date()) -> Bool {
        guard isWorkday(at: date) else { return false }

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let nowSec = date.timeIntervalSince(startOfDay)
        let startSec = Double((Self.clampHour(workStartHour) * 60 + Self.clampMinute(workStartMinute)) * 60)
        let endSec = Double((Self.clampHour(workEndHour) * 60 + Self.clampMinute(workEndMinute)) * 60)
        let lunchStartSec = Double((Self.clampHour(lunchStartHour) * 60 + Self.clampMinute(lunchStartMinute)) * 60)
        let lunchEndSec = Double((Self.clampHour(lunchEndHour) * 60 + Self.clampMinute(lunchEndMinute)) * 60)

        guard nowSec >= startSec, nowSec < endSec else { return false }
        if lunchEndSec > lunchStartSec, nowSec >= lunchStartSec, nowSec < lunchEndSec {
            return false
        }
        return true
    }

    var isWorkday: Bool {
        isWorkday(at: Date())
    }

    func isWorkday(at date: Date) -> Bool {
        let w = Calendar.current.component(.weekday, from: date)
        switch workSchedule {
        case .doubleRest:   return w >= 2 && w <= 6
        case .singleRest:   return w >= 2 && w <= 7
        case .bigSmallWeek:
            if w >= 2 && w <= 6 { return true }
            return w == 7 && !isBigWeek(at: date)
        }
    }

    func workingSeconds(from start: Date, to end: Date) -> TimeInterval {
        guard end > start else { return 0 }

        let calendar = Calendar.current
        var total: TimeInterval = 0
        var cursor = start

        while cursor < end {
            let startOfDay = calendar.startOfDay(for: cursor)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? end
            let segmentEnd = min(end, nextDay)

            for interval in workingIntervals(on: cursor) {
                let overlapStart = max(cursor, interval.start)
                let overlapEnd = min(segmentEnd, interval.end)
                if overlapEnd > overlapStart {
                    total += overlapEnd.timeIntervalSince(overlapStart)
                }
            }

            cursor = segmentEnd
        }

        return total
    }

    func workingIntervals(on date: Date) -> [(start: Date, end: Date)] {
        guard isWorkday(at: date) else { return [] }

        let calendar = Calendar.current
        guard
            let workStart = calendar.date(bySettingHour: workStartHour, minute: workStartMinute, second: 0, of: date),
            let workEnd = calendar.date(bySettingHour: workEndHour, minute: workEndMinute, second: 0, of: date),
            workEnd > workStart
        else {
            return []
        }

        guard
            let lunchStart = calendar.date(bySettingHour: lunchStartHour, minute: lunchStartMinute, second: 0, of: date),
            let lunchEnd = calendar.date(bySettingHour: lunchEndHour, minute: lunchEndMinute, second: 0, of: date),
            lunchEnd > lunchStart
        else {
            return [(workStart, workEnd)]
        }

        let breakStart = max(workStart, lunchStart)
        let breakEnd = min(workEnd, lunchEnd)
        guard breakEnd > breakStart else {
            return [(workStart, workEnd)]
        }

        var intervals: [(start: Date, end: Date)] = []
        if breakStart > workStart {
            intervals.append((workStart, breakStart))
        }
        if workEnd > breakEnd {
            intervals.append((breakEnd, workEnd))
        }
        return intervals
    }

    func category(for bundleID: String) -> AppCategory {
        if fishingApps.contains(bundleID) { return .fishing }
        if workingApps.contains(bundleID) { return .working }
        return .working // 默认归搬砖
    }

    private func saveSettings() {
        guard !isRestoring else { return }
        guard let data = encodedSettingsState(prettyPrinted: false) else { return }
        AppStorage.save(data, to: settingsFile)
    }

    private func encodedSettingsState(prettyPrinted: Bool) -> Data? {
        let state = SalarySettingsState(
            monthlySalary: max(monthlySalary, 0),
            workSchedule: workSchedule.rawValue,
            bigWeekReferenceDate: bigWeekReferenceDate.timeIntervalSince1970,
            workStartHour: Self.clampHour(workStartHour),
            workStartMinute: Self.clampMinute(workStartMinute),
            workEndHour: Self.clampHour(workEndHour),
            workEndMinute: Self.clampMinute(workEndMinute),
            lunchStartHour: Self.clampHour(lunchStartHour),
            lunchStartMinute: Self.clampMinute(lunchStartMinute),
            lunchEndHour: Self.clampHour(lunchEndHour),
            lunchEndMinute: Self.clampMinute(lunchEndMinute),
            overtimePayMode: overtimePayMode.rawValue,
            overtimeAmount: max(overtimeAmount, 0),
            fishingApps: Array(fishingApps),
            workingApps: Array(workingApps)
        )

        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try? encoder.encode(state)
    }

    private func loadSettings() {
        if let data = AppStorage.load(from: settingsFile),
           let state = try? JSONDecoder().decode(SalarySettingsState.self, from: data) {
            applySettingsState(state)
            return
        }
        // migrate from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "MoYuMei.SalarySettings.v2"),
           let state = try? JSONDecoder().decode(SalarySettingsState.self, from: data) {
            applySettingsState(state)
            UserDefaults.standard.removeObject(forKey: "MoYuMei.SalarySettings.v2")
            saveSettings()
        }
    }

    private func applySettingsState(_ state: SalarySettingsState) {
        isRestoring = true
        defer { isRestoring = false }

        monthlySalary = max(state.monthlySalary, 0)
        workSchedule = WorkSchedule(rawValue: state.workSchedule) ?? .doubleRest
        bigWeekReferenceDate = Date(timeIntervalSince1970: state.bigWeekReferenceDate)
        workStartHour = Self.clampHour(state.workStartHour)
        workStartMinute = Self.clampMinute(state.workStartMinute)
        workEndHour = Self.clampHour(state.workEndHour)
        workEndMinute = Self.clampMinute(state.workEndMinute)
        lunchStartHour = Self.clampHour(state.lunchStartHour)
        lunchStartMinute = Self.clampMinute(state.lunchStartMinute)
        lunchEndHour = Self.clampHour(state.lunchEndHour)
        lunchEndMinute = Self.clampMinute(state.lunchEndMinute)
        overtimePayMode = OvertimePayMode(rawValue: state.overtimePayMode) ?? .unpaid
        overtimeAmount = max(state.overtimeAmount, 0)
        fishingApps = Set(state.fishingApps.filter { AppIconLoader.isInstalled(bundleID: $0) })
        workingApps = Set(state.workingApps.filter { AppIconLoader.isInstalled(bundleID: $0) })
    }

    private static func clampHour(_ value: Int) -> Int {
        min(max(value, 0), 23)
    }

    private static func clampMinute(_ value: Int) -> Int {
        min(max(value, 0), 59)
    }
}

enum AppCategory {
    case fishing, working
}

enum UsageStatus {
    case working, fishing, free, overtime
}

private struct SalarySettingsState: Codable {
    var monthlySalary: Double
    var workSchedule: String
    var bigWeekReferenceDate: Double
    var workStartHour: Int
    var workStartMinute: Int
    var workEndHour: Int
    var workEndMinute: Int
    var lunchStartHour: Int
    var lunchStartMinute: Int
    var lunchEndHour: Int
    var lunchEndMinute: Int
    var overtimePayMode: String
    var overtimeAmount: Double
    var fishingApps: [String]
    var workingApps: [String]

    enum CodingKeys: String, CodingKey {
        case monthlySalary, workSchedule, bigWeekReferenceDate
        case workStartHour, workStartMinute, workEndHour, workEndMinute
        case lunchStartHour, lunchStartMinute, lunchEndHour, lunchEndMinute
        case overtimePayMode, overtimeAmount
        case fishingApps, workingApps
        case isBigWeek
    }

    init(
        monthlySalary: Double,
        workSchedule: String,
        bigWeekReferenceDate: Double,
        workStartHour: Int,
        workStartMinute: Int,
        workEndHour: Int,
        workEndMinute: Int,
        lunchStartHour: Int,
        lunchStartMinute: Int,
        lunchEndHour: Int,
        lunchEndMinute: Int,
        overtimePayMode: String,
        overtimeAmount: Double,
        fishingApps: [String],
        workingApps: [String]
    ) {
        self.monthlySalary = monthlySalary
        self.workSchedule = workSchedule
        self.bigWeekReferenceDate = bigWeekReferenceDate
        self.workStartHour = workStartHour
        self.workStartMinute = workStartMinute
        self.workEndHour = workEndHour
        self.workEndMinute = workEndMinute
        self.lunchStartHour = lunchStartHour
        self.lunchStartMinute = lunchStartMinute
        self.lunchEndHour = lunchEndHour
        self.lunchEndMinute = lunchEndMinute
        self.overtimePayMode = overtimePayMode
        self.overtimeAmount = overtimeAmount
        self.fishingApps = fishingApps
        self.workingApps = workingApps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        monthlySalary = try container.decode(Double.self, forKey: .monthlySalary)
        workSchedule = try container.decode(String.self, forKey: .workSchedule)
        if let ref = try container.decodeIfPresent(Double.self, forKey: .bigWeekReferenceDate) {
            bigWeekReferenceDate = ref
        } else {
            let wasBig = try container.decodeIfPresent(Bool.self, forKey: .isBigWeek) ?? true
            let monday = SalaryManager.mondayOfWeek(containing: Date())
            if wasBig {
                bigWeekReferenceDate = monday.timeIntervalSince1970
            } else {
                let nextMonday = Calendar.current.date(byAdding: .day, value: 7, to: monday)!
                bigWeekReferenceDate = nextMonday.timeIntervalSince1970
            }
        }
        workStartHour = try container.decode(Int.self, forKey: .workStartHour)
        workStartMinute = try container.decode(Int.self, forKey: .workStartMinute)
        workEndHour = try container.decode(Int.self, forKey: .workEndHour)
        workEndMinute = try container.decode(Int.self, forKey: .workEndMinute)
        lunchStartHour = try container.decodeIfPresent(Int.self, forKey: .lunchStartHour) ?? 12
        lunchStartMinute = try container.decodeIfPresent(Int.self, forKey: .lunchStartMinute) ?? 0
        lunchEndHour = try container.decodeIfPresent(Int.self, forKey: .lunchEndHour) ?? 13
        lunchEndMinute = try container.decodeIfPresent(Int.self, forKey: .lunchEndMinute) ?? 0
        overtimePayMode = try container.decodeIfPresent(String.self, forKey: .overtimePayMode) ?? OvertimePayMode.unpaid.rawValue
        overtimeAmount = try container.decodeIfPresent(Double.self, forKey: .overtimeAmount) ?? 0
        fishingApps = try container.decodeIfPresent([String].self, forKey: .fishingApps) ?? []
        workingApps = try container.decodeIfPresent([String].self, forKey: .workingApps) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monthlySalary, forKey: .monthlySalary)
        try container.encode(workSchedule, forKey: .workSchedule)
        try container.encode(bigWeekReferenceDate, forKey: .bigWeekReferenceDate)
        try container.encode(workStartHour, forKey: .workStartHour)
        try container.encode(workStartMinute, forKey: .workStartMinute)
        try container.encode(workEndHour, forKey: .workEndHour)
        try container.encode(workEndMinute, forKey: .workEndMinute)
        try container.encode(lunchStartHour, forKey: .lunchStartHour)
        try container.encode(lunchStartMinute, forKey: .lunchStartMinute)
        try container.encode(lunchEndHour, forKey: .lunchEndHour)
        try container.encode(lunchEndMinute, forKey: .lunchEndMinute)
        try container.encode(overtimePayMode, forKey: .overtimePayMode)
        try container.encode(overtimeAmount, forKey: .overtimeAmount)
        try container.encode(fishingApps, forKey: .fishingApps)
        try container.encode(workingApps, forKey: .workingApps)
    }
}

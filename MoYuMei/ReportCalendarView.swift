import SwiftUI
import AppKit

struct ReportCalendarView: View {
    @EnvironmentObject var salary: SalaryManager
    @EnvironmentObject var tracker: AppUsageTracker

    @State private var month = Date()
    @State private var selectedDayKey: String = Self.dayKey(for: Date())
    @State private var rankingScope: RankingScope = .day

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    var selectedRecords: [AppUsageRecord] {
        tracker.archivedRecords(for: selectedDayKey)
    }

    var selectedReport: ReportSnapshot {
        report(for: selectedRecords, overtime: tracker.overtimeArchives[selectedDayKey])
    }

    var monthSummaries: [DailyUsageSummary] {
        tracker.daySummaries(forMonthContaining: month)
    }

    var monthRecords: [AppUsageRecord] {
        mergeRecords(monthSummaries.flatMap { tracker.archivedRecords(for: $0.id) })
    }

    var rankingRecords: [AppUsageRecord] {
        switch rankingScope {
        case .day:
            return selectedRecords
        case .week:
            return mergeRecords(daysInSelectedWeek().flatMap { tracker.archivedRecords(for: $0) })
        case .month:
            return monthRecords
        }
    }

    var rankingReport: ReportSnapshot {
        report(for: rankingRecords, overtime: overtimeRecord(for: rankingScope))
    }

    var usageDays: Int {
        monthSummaries.filter { $0.totalSeconds > 0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("摸鱼日报")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("查看摸鱼、搬砖和加班日报。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            SettingsCard("今日概览", subtitle: selectedDayKey) {
                HStack(spacing: 10) {
                    hourMetric(title: "摸鱼占比", value: selectedReport.fishingRateText, color: .orange)
                    hourMetric(title: "摸鱼时长", value: formatHours(selectedReport.fishingSeconds), color: .orange)
                    hourMetric(title: "搬砖时长", value: formatHours(selectedReport.workingSeconds), color: .blue)
                }

                HStack(spacing: 10) {
                    hourMetric(title: "加班时长", value: formatHours(selectedReport.overtimeSeconds), color: .red)
                    hourMetric(title: "加班入账", value: String(format: "¥%.2f", selectedReport.overtimeIncome), color: .red)
                    hourMetric(title: "白干亏损", value: String(format: "¥%.2f", selectedReport.unpaidValue), color: .purple)
                }

                distributionBar(fishingSeconds: selectedReport.fishingSeconds, workingSeconds: selectedReport.workingSeconds)

                HStack(spacing: 12) {
                    distributionIcon(systemName: "fish.fill", title: "摸鱼", value: formatHours(selectedReport.fishingSeconds), color: .orange)
                    distributionIcon(systemName: "briefcase.fill", title: "搬砖", value: formatHours(selectedReport.workingSeconds), color: .blue)
                }

                topAppList(rows: selectedReport.topApps)
            }

            SettingsCard("应用排行", subtitle: rankingScope.rawValue) {
                Picker("", selection: $rankingScope) {
                    ForEach(RankingScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    hourMetric(title: "日报天数", value: "\(usageDays) 天", color: .green)
                    hourMetric(title: "摸鱼总时长", value: formatHours(rankingReport.fishingSeconds), color: .orange)
                    hourMetric(title: "搬砖总时长", value: formatHours(rankingReport.workingSeconds), color: .blue)
                }

                HStack(spacing: 10) {
                    hourMetric(title: "加班总时长", value: formatHours(rankingReport.overtimeSeconds), color: .red)
                    hourMetric(title: "加班入账", value: String(format: "¥%.2f", rankingReport.overtimeIncome), color: .red)
                    hourMetric(title: "白干亏损", value: String(format: "¥%.2f", rankingReport.unpaidValue), color: .purple)
                }

                topAppList(rows: rankingReport.topApps)
            }

            SettingsCard("月度日报", subtitle: monthTitle(month)) {
                HStack {
                    Button(action: { shiftMonth(-1) }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Text(monthTitle(month))
                        .font(.system(size: 14, weight: .semibold))

                    Spacer()

                    Button(action: { shiftMonth(1) }) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(calendarCells(), id: \.id) { cell in
                        calendarCell(cell)
                    }
                }
            }
        }
        .onAppear {
            if selectedRecords.isEmpty {
                selectedDayKey = Self.dayKey(for: Date())
            }
        }
    }

    func calendarCell(_ cell: CalendarCell) -> some View {
        Group {
            if let summary = cell.summary {
                let isSelected = summary.id == selectedDayKey
                Button(action: { selectedDayKey = summary.id }) {
                    VStack(spacing: 5) {
                        Text("\(Calendar.current.component(.day, from: summary.date))")
                            .font(.system(size: 12, weight: .semibold))
                        HStack(spacing: 3) {
                            Image(systemName: "fish.fill")
                                .font(.system(size: 8))
                            Text(fishingRateText(summary))
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(color(for: summary))
                    }
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(isSelected ? color(for: summary).opacity(0.22) : Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(height: 44)
            }
        }
    }

    func hourMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func topAppList(rows: [TopAppRow]) -> some View {
        VStack(spacing: 0) {
            if rows.isEmpty {
                Text("暂无排行，今天还没有日报")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    topAppRow(index: index + 1, row: row)
                    if index < rows.count - 1 {
                        Divider().opacity(0.35)
                    }
                }
            }
        }
    }

    func topAppRow(index: Int, row: TopAppRow) -> some View {
        HStack(spacing: 10) {
            Text("\(index)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 18)

            Group {
                if let icon = row.icon {
                    Image(nsImage: icon).resizable().interpolation(.high)
                } else {
                    Image(systemName: "app.fill").foregroundColor(.secondary)
                }
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.appName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(row.color)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatHours(row.seconds))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                Text(String(format: "¥%.3f", row.income))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    func distributionBar(fishingSeconds: TimeInterval, workingSeconds: TimeInterval) -> some View {
        let total = max(fishingSeconds + workingSeconds, 1)
        let fishingRatio = max(min(fishingSeconds / total, 1), 0)

        return GeometryReader { proxy in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.orange)
                    .frame(width: proxy.size.width * fishingRatio)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.blue.opacity(0.85))
            }
        }
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .background(Color.primary.opacity(0.06))
    }

    func distributionIcon(systemName: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    func calendarCells() -> [CalendarCell] {
        let calendar = Calendar.current
        let summaries = tracker.daySummaries(forMonthContaining: month)
        guard let first = summaries.first?.date else { return [] }
        let leading = (calendar.component(.weekday, from: first) + 5) % 7
        let blanks = (0..<leading).map { CalendarCell(id: "blank-\($0)", summary: nil) }
        return blanks + summaries.map { CalendarCell(id: $0.id, summary: $0) }
    }

    func color(for summary: DailyUsageSummary) -> Color {
        guard summary.totalSeconds > 0 else { return Color.secondary.opacity(0.28) }
        let ratio = summary.fishingSeconds / summary.totalSeconds
        if ratio >= 0.6 { return .orange }
        if ratio <= 0.25 { return .blue }
        return .green
    }

    func report(for records: [AppUsageRecord], overtime: DailyOvertimeRecord? = nil) -> ReportSnapshot {
        return ReportSnapshot(
            fishingSeconds: records.reduce(0) { $0 + $1.fishingSeconds },
            workingSeconds: records.reduce(0) { $0 + $1.workingSeconds },
            overtimeSeconds: overtime?.seconds ?? 0,
            overtimeIncome: overtime?.income ?? 0,
            unpaidValue: overtime?.unpaidValue ?? 0,
            topApps: topAppRows(from: records)
        )
    }

    func overtimeRecord(for scope: RankingScope) -> DailyOvertimeRecord {
        switch scope {
        case .day:
            return tracker.overtimeArchives[selectedDayKey] ?? DailyOvertimeRecord()
        case .week:
            return mergeOvertime(daysInSelectedWeek().map { tracker.overtimeArchives[$0] })
        case .month:
            return mergeOvertime(monthSummaries.map { tracker.overtimeArchives[$0.id] })
        }
    }

    func mergeOvertime(_ records: [DailyOvertimeRecord?]) -> DailyOvertimeRecord {
        records.reduce(DailyOvertimeRecord()) { result, item in
            guard let item else { return result }
            return DailyOvertimeRecord(
                seconds: result.seconds + item.seconds,
                income: result.income + item.income,
                unpaidValue: result.unpaidValue + item.unpaidValue,
                fixedPaid: result.fixedPaid || item.fixedPaid
            )
        }
    }

    func topAppRows(from records: [AppUsageRecord]) -> [TopAppRow] {
        let salaryPerSecond = salary.salaryPerSecond
        let rows = records.flatMap { record -> [TopAppRow] in
            [
                TopAppRow(
                    id: "\(record.id)-fishing",
                    appName: record.appName,
                    icon: record.icon,
                    category: .fishing,
                    seconds: record.fishingSeconds,
                    income: record.fishingSeconds * salaryPerSecond
                ),
                TopAppRow(
                    id: "\(record.id)-working",
                    appName: record.appName,
                    icon: record.icon,
                    category: .working,
                    seconds: record.workingSeconds,
                    income: record.workingSeconds * salaryPerSecond
                )
            ]
        }

        return rows
            .filter { $0.seconds > 0 }
            .sorted { $0.seconds > $1.seconds }
            .prefix(10)
            .map { $0 }
    }

    func mergeRecords(_ records: [AppUsageRecord]) -> [AppUsageRecord] {
        var storage: [String: (name: String, fishing: TimeInterval, working: TimeInterval, icon: NSImage?)] = [:]

        for record in records {
            var item = storage[record.id] ?? (record.appName, 0, 0, record.icon)
            item.fishing += record.fishingSeconds
            item.working += record.workingSeconds
            if item.icon == nil { item.icon = record.icon }
            storage[record.id] = item
        }

        return storage
            .map { AppUsageRecord(id: $0, appName: $1.name, fishingSeconds: $1.fishing, workingSeconds: $1.working, icon: $1.icon) }
            .sorted { $0.totalSeconds > $1.totalSeconds }
    }

    func daysInSelectedWeek() -> [String] {
        guard let selectedDate = Self.date(from: selectedDayKey),
              let week = Calendar.current.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return [selectedDayKey]
        }

        var days: [String] = []
        var cursor = week.start
        while cursor < week.end {
            days.append(Self.dayKey(for: cursor))
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor) ?? week.end
        }
        return days
    }

    func shiftMonth(_ value: Int) {
        month = Calendar.current.date(byAdding: .month, value: value, to: month) ?? month
    }

    func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter.string(from: date)
    }

    func formatDuration(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600, m = (Int(s) % 3600) / 60, sec = Int(s) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }

    func formatHours(_ seconds: TimeInterval) -> String {
        String(format: "%.1f 小时", seconds / 3600)
    }

    func fishingRateText(_ summary: DailyUsageSummary) -> String {
        guard summary.totalSeconds > 0 else { return "0%" }
        return String(format: "%.0f%%", summary.fishingSeconds / summary.totalSeconds * 100)
    }

    static func dayKey(for date: Date) -> String {
        DateFormatting.dayKey(for: date)
    }

    static func date(from dayKey: String) -> Date? {
        DateFormatting.date(from: dayKey)
    }

    struct CalendarCell: Identifiable {
        let id: String
        var summary: DailyUsageSummary?
    }

    struct ReportSnapshot {
        var fishingSeconds: TimeInterval
        var workingSeconds: TimeInterval
        var overtimeSeconds: TimeInterval
        var overtimeIncome: Double
        var unpaidValue: Double
        var topApps: [TopAppRow]

        var fishingRateText: String {
            let total = fishingSeconds + workingSeconds
            guard total > 0 else { return "0%" }
            return String(format: "%.0f%%", fishingSeconds / total * 100)
        }
    }

    enum RankingScope: String, CaseIterable, Identifiable {
        case day = "日榜"
        case week = "周榜"
        case month = "月榜"

        var id: String { rawValue }
    }

    struct TopAppRow: Identifiable {
        var id: String
        var appName: String
        var icon: NSImage?
        var category: AppCategory
        var seconds: TimeInterval
        var income: Double

        var color: Color {
            category == .fishing ? .orange : .blue
        }
    }
}

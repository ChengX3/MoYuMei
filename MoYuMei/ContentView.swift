import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var salary: SalaryManager
    @EnvironmentObject var tracker: AppUsageTracker

    var body: some View {
        VStack(spacing: 0) {
            earningsCard
            Divider().opacity(0.4)
            appUsageCard
            Divider().opacity(0.4)
            bottomBar
        }
        .frame(width: 330)
        .background(ShortcutBridge().frame(width: 0, height: 0))
    }

    // MARK: 薪资卡

    var earningsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日进账")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                statusBadge
            }

            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                let now = timeline.date
                let liveTotals = tracker.liveTotals(at: now)
                let workingSeconds = liveTotals.working
                let fishingSeconds = liveTotals.fishing
                let salaryPerSecond = salary.salaryPerSecond
                let overtime = tracker.liveOvertimeRecord(at: now)
                let baseIncome = salary.earnedToday(at: now)
                let totalIncome = baseIncome + overtime.income

                Text(String(format: "¥%.4f", totalIncome))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .contentTransition(.numericText(value: totalIncome))
                    .animation(.snappy(duration: 0.25), value: totalIncome)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 14) {
                    earningsSplit(label: "搬砖", earned: workingSeconds * salaryPerSecond, seconds: workingSeconds, color: .blue)
                    Divider().frame(height: 28)
                    earningsSplit(label: "摸鱼", earned: fishingSeconds * salaryPerSecond, seconds: fishingSeconds, color: .orange)
                    Divider().frame(height: 28)
                    earningsSplit(label: "FUCK", earned: overtime.income, seconds: overtime.seconds, color: .red)
                }
                .padding(.top, 2)
            }

            HStack(spacing: 6) {
                pill(String(format: "%.5f/秒", salary.salaryPerSecond))
                if !salary.isWorkday {
                    pill("今天休息")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    var statusBadge: some View {
        Text(statusTitle(tracker.currentStatus))
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(statusColor(tracker.currentStatus))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(statusColor(tracker.currentStatus).opacity(0.12))
            .clipShape(Capsule())
    }

    func earningsSplit(label: String, earned: Double, seconds: TimeInterval, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Text(String(format: "¥%.3f", earned))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: earned))
                .animation(.snappy(duration: 0.2), value: earned)
            Text(formatDuration(seconds))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.primary.opacity(0.06))
            .clipShape(Capsule())
    }

    // MARK: 应用日报

    var appUsageCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("应用日报")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor(tracker.currentStatus))
                        .frame(width: 6, height: 6)
                    Text(statusTitle(tracker.currentStatus))
                        .font(.system(size: 10))
                        .foregroundColor(statusColor(tracker.currentStatus))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            let fishingItems = tracker.records.filter { $0.fishingSeconds > 0 }.prefix(4)
            let workingItems = tracker.records.filter { $0.workingSeconds > 0 }.prefix(4)

            if fishingItems.isEmpty && workingItems.isEmpty {
                Text("开几个 App，日报才有东西看")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                if !fishingItems.isEmpty {
                    usageSection(title: "摸鱼", color: .orange, items: Array(fishingItems), secondsKeyPath: \.fishingSeconds)
                }
                if !fishingItems.isEmpty && !workingItems.isEmpty {
                    Divider().padding(.horizontal, 16).opacity(0.4)
                }
                if !workingItems.isEmpty {
                    usageSection(title: "搬砖", color: .blue, items: Array(workingItems), secondsKeyPath: \.workingSeconds)
                }
            }
        }
        .padding(.bottom, 8)
    }

    func usageSection(title: String, color: Color, items: [AppUsageRecord], secondsKeyPath: KeyPath<AppUsageRecord, TimeInterval>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(color)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ForEach(Array(items.enumerated()), id: \.element.id) { idx, record in
                appRow(record: record, seconds: record[keyPath: secondsKeyPath])
                if idx < items.count - 1 {
                    Divider().padding(.leading, 44).opacity(0.4)
                }
            }
        }
    }

    func appRow(record: AppUsageRecord, seconds: TimeInterval) -> some View {
        HStack(spacing: 10) {
            Group {
                if let icon = record.icon {
                    Image(nsImage: icon).resizable().interpolation(.high)
                } else {
                    Image(systemName: "app.fill").foregroundColor(.secondary)
                }
            }
            .frame(width: 22, height: 22)
            Text(record.appName)
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer()
            Text(formatDuration(seconds))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: 底部栏

    var bottomBar: some View {
        HStack(spacing: 0) {
            Button(action: { tracker.toggleFishingMode() }) {
                HStack(spacing: 5) {
                    Image(systemName: tracker.isFishingMode ? "fish.fill" : "laptopcomputer")
                        .font(.system(size: 12))
                    Text(tracker.isFishingMode ? "摸鱼" : "搬砖")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(tracker.isFishingMode ? .orange : .blue)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background((tracker.isFishingMode ? Color.orange : Color.blue).opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("t", modifiers: .command)
            .padding(.leading, 12)

            Button(action: { toggleOvertime() }) {
                Text("FUCK")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(tracker.isOvertimeMode ? .red : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background((tracker.isOvertimeMode ? Color.red : Color.secondary).opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)

            Spacer()

            Button(action: { SettingsWindowController.shared.show(tab: .report) }) {
                HStack(spacing: 5) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 12))
                    Text("日报")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)

            Button(action: { SettingsWindowController.shared.show(tab: .salary) }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .padding(.trailing, 14)
        }
        .padding(.vertical, 8)
    }

    func formatDuration(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600, m = (Int(s) % 3600) / 60, sec = Int(s) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }

    func statusTitle(_ status: UsageStatus) -> String {
        switch status {
        case .working: return "搬砖中"
        case .fishing: return "摸鱼中"
        case .free: return "休息中"
        case .overtime: return "加班中"
        }
    }

    func statusColor(_ status: UsageStatus) -> Color {
        switch status {
        case .working: return .blue
        case .fishing: return .orange
        case .free: return .green
        case .overtime: return .red
        }
    }

    func toggleOvertime() {
        if tracker.isOvertimeMode {
            tracker.toggleOvertimeMode()
            return
        }

        if salary.isWorkday {
            FixedOvertimeWindowController.shared.show(context: .workday)
        } else {
            FixedOvertimeWindowController.shared.show(context: .restDay)
        }
    }
}

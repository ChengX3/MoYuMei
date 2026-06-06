import SwiftUI
import AppKit

class FixedOvertimeWindowController: NSObject, NSWindowDelegate {
    static let shared = FixedOvertimeWindowController()
    private var window: NSWindow?

    func show(context: OvertimeWindowContext) {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = context.title
        w.isRestorable = false
        w.center()
        w.contentView = NSHostingView(
            rootView: FixedOvertimeWindowView(
                context: context,
                onCancel: {
                    FixedOvertimeWindowController.shared.close()
                },
                onStart: { settlement in
                    appUsageTracker.toggleOvertimeMode(
                        settlement: settlement,
                        delayUntilWorkEnds: context == .workday
                    )
                    FixedOvertimeWindowController.shared.close()
                }
            )
            .environmentObject(appSalaryManager)
        )
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }

    func close() {
        if let window {
            window.delegate = nil
            window.contentView = nil
            window.close()
        }
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.delegate = nil
            window.contentView = nil
        }
        window = nil
    }
}

struct FixedOvertimeWindowView: View {
    @EnvironmentObject var salary: SalaryManager

    let context: OvertimeWindowContext
    @State private var settlementKind: RestDaySettlementKind = .salaryMultiplier
    @State private var workdaySettlementKind: WorkdaySettlementKind = .hourly
    @State private var durationMode: OvertimeDurationMode = .actual
    @State private var multiplier: Double = 2
    @State private var amount: Double = 0
    @State private var hourlyAmount: Double = 0

    let onCancel: () -> Void
    let onStart: (OvertimeSettlement) -> Void

    init(context: OvertimeWindowContext, onCancel: @escaping () -> Void, onStart: @escaping (OvertimeSettlement) -> Void) {
        self.context = context
        self.onCancel = onCancel
        self.onStart = onStart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text(context.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            if context == .workday {
                workdayFields
            } else {
                restDayFields
            }

            HStack {
                Spacer()
                Button("算了", action: onCancel)
                Button("开始加班") {
                    onStart(settlement)
                }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            hourlyAmount = salary.overtimePayMode == .hourly ? salary.overtimeAmount : 0
            workdaySettlementKind = salary.overtimePayMode == .hourly ? .hourly : .unpaid
        }
    }

    var settlement: OvertimeSettlement {
        if context == .workday {
            switch workdaySettlementKind {
            case .hourly:
                return .hourly(amount: max(hourlyAmount, 0))
            case .fixed:
                return .fixed(amount: max(amount, 0))
            case .unpaid:
                return .unpaid
            }
        } else {
            switch settlementKind {
            case .salaryMultiplier:
                return .salaryMultiplier(multiplier: multiplier, duration: durationMode)
            case .fixed:
                return .fixed(amount: max(amount, 0))
            }
        }
    }

    var nonNegativeAmount: Binding<Double> {
        Binding(
            get: { max(amount, 0) },
            set: { amount = max($0, 0) }
        )
    }

    var nonNegativeHourlyAmount: Binding<Double> {
        Binding(
            get: { max(hourlyAmount, 0) },
            set: { hourlyAmount = max($0, 0) }
        )
    }

    var workdayFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $workdaySettlementKind) {
                ForEach(WorkdaySettlementKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            switch workdaySettlementKind {
            case .hourly:
                SettingRow("加班时薪", subtitle: "默认读取设置页的工作日加班时薪。") {
                    HStack(spacing: 8) {
                        Text("¥").foregroundColor(.secondary)
                        TextField("", value: nonNegativeHourlyAmount, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                }
            case .fixed:
                fixedAmountRow
            case .unpaid:
                Text("无偿加班不进收入，但会按正常时薪估算这段时间的白干亏损。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    var restDayFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $settlementKind) {
                ForEach(RestDaySettlementKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            if settlementKind == .salaryMultiplier {
                VStack(alignment: .leading, spacing: 10) {
                    SettingRow("计时方式", subtitle: settlementPreview) {
                        Picker("", selection: $durationMode) {
                            ForEach(OvertimeDurationMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 190)
                    }

                    SettingRow("工资倍率") {
                        Picker("", selection: $multiplier) {
                            ForEach([1.0, 2.0, 3.0], id: \.self) { value in
                                Text(String(format: "%.0fx", value)).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                }
            } else {
                fixedAmountRow
            }
        }
    }

    var fixedAmountRow: some View {
        SettingRow("一次性金额", subtitle: "这次收入只记一次，时长按实际加班时间记录。") {
            HStack(spacing: 8) {
                Text("¥")
                    .foregroundColor(.secondary)
                TextField("", value: nonNegativeAmount, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    var settlementPreview: String {
        switch durationMode {
        case .actual:
            return "从开始到结束按实际休息日时长计算。"
        case .halfDay:
            return String(format: "按 %.1f 小时结算。", salary.workSecondsPerDay / 3600 * durationMode.dayFraction)
        case .fullDay:
            return String(format: "按 %.1f 小时结算。", salary.workSecondsPerDay / 3600 * durationMode.dayFraction)
        }
    }
}

enum OvertimeWindowContext: Equatable {
    case workday
    case restDay

    var title: String {
        switch self {
        case .workday: return "工作日加班"
        case .restDay: return "休息日加班"
        }
    }

    var subtitle: String {
        switch self {
        case .workday:
            return "选择这次结算方式；如果还没下班，会等下班后开始计时。"
        case .restDay:
            return "选择这次按实际时长、半天、全天或一次性金额结算。"
        }
    }
}

private enum WorkdaySettlementKind: String, CaseIterable, Identifiable {
    case hourly = "按小时"
    case fixed = "一次性"
    case unpaid = "无偿"

    var id: String { rawValue }
}

private enum RestDaySettlementKind: String, CaseIterable, Identifiable {
    case salaryMultiplier = "工资倍率"
    case fixed = "一次性"

    var id: String { rawValue }
}

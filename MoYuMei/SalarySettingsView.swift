import SwiftUI

struct SalarySettingsView: View {
    @EnvironmentObject var salary: SalaryManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("薪资设置")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("设置每秒收入，以及什么时候算搬砖。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            SettingsCard("薪资参数", subtitle: "填写月薪后自动计算每秒收入。") {
                SettingRow("月薪", subtitle: String(format: "当前 %.5f 元/秒", salary.salaryPerSecond)) {
                    HStack(spacing: 6) {
                        Text("¥").foregroundColor(.secondary)
                        TextField("", value: nonNegativeBinding($salary.monthlySalary), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            SettingsCard("搬砖日历", subtitle: "设置哪些日期算搬砖。") {
                SettingRow("搬砖制") {
                    segmentedControl(values: WorkSchedule.allCases, selection: salary.workSchedule, width: 230) { value in
                        salary.workSchedule = value
                    }
                }

                if salary.workSchedule == .bigSmallWeek {
                    Divider().opacity(0.35)
                    SettingRow("本周双休", subtitle: "关闭后，这个周六也算搬砖日。自动按周翻转。") {
                        Toggle("", isOn: Binding(
                            get: { salary.isBigWeek },
                            set: { salary.setCurrentWeekAsBig($0) }
                        ))
                        .labelsHidden()
                    }
                }
            }

            SettingsCard("作息边界", subtitle: "只在搬砖时段内计算收入。") {
                SettingRow("开工时间") {
                    timePicker(hourBinding($salary.workStartHour), minuteBinding($salary.workStartMinute))
                }
                Divider().opacity(0.35)
                SettingRow("收工时间") {
                    timePicker(hourBinding($salary.workEndHour), minuteBinding($salary.workEndMinute))
                }
                Divider().opacity(0.35)
                SettingRow("午休开始") {
                    timePicker(hourBinding($salary.lunchStartHour), minuteBinding($salary.lunchStartMinute))
                }
                Divider().opacity(0.35)
                SettingRow("午休结束") {
                    timePicker(hourBinding($salary.lunchEndHour), minuteBinding($salary.lunchEndMinute))
                }
            }

            SettingsCard("加班规则", subtitle: "开启加班后，休息时段会单独计入日报。") {
                SettingRow("计费方式") {
                    segmentedControl(values: OvertimePayMode.allCases, selection: salary.overtimePayMode, width: 260) { value in
                        salary.overtimePayMode = value
                    }
                }

                if salary.overtimePayMode != .unpaid {
                    Divider().opacity(0.35)
                    SettingRow(salary.overtimePayMode == .hourly ? "加班时薪" : "本次固定加班收入", subtitle: salary.overtimePayMode == .hourly ? "按小时计算加班收入。" : "一次性加班的默认金额，开始时还能临时改。") {
                        HStack(spacing: 6) {
                            Text("¥").foregroundColor(.secondary)
                            TextField("", value: nonNegativeBinding($salary.overtimeAmount), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } else {
                    Divider().opacity(0.35)
                    Text("无偿加班不进收入，但会按正常时薪估算这段时间的白干亏损。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    func nonNegativeBinding(_ binding: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { max(binding.wrappedValue, 0) },
            set: { newValue in
                let sanitized = max(newValue, 0)
                guard binding.wrappedValue != sanitized else { return }
                binding.wrappedValue = sanitized
            }
        )
    }

    func segmentedControl<Value>(
        values: [Value],
        selection: Value,
        width: CGFloat,
        onSelect: @escaping (Value) -> Void
    ) -> some View where Value: Identifiable & Equatable & RawRepresentable, Value.RawValue == String {
        HStack(spacing: 0) {
            ForEach(values) { value in
                let isSelected = value == selection
                Button(action: {
                    guard value != selection else { return }
                    onSelect(value)
                }) {
                    Text(value.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .frame(width: width)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    func hourBinding(_ binding: Binding<Int>) -> Binding<Int> {
        Binding(
            get: { min(max(binding.wrappedValue, 0), 23) },
            set: { newValue in
                let sanitized = min(max(newValue, 0), 23)
                guard binding.wrappedValue != sanitized else { return }
                binding.wrappedValue = sanitized
            }
        )
    }

    func minuteBinding(_ binding: Binding<Int>) -> Binding<Int> {
        Binding(
            get: { min(max(binding.wrappedValue, 0), 59) },
            set: { newValue in
                let sanitized = min(max(newValue, 0), 59)
                guard binding.wrappedValue != sanitized else { return }
                binding.wrappedValue = sanitized
            }
        )
    }

    func timePicker(_ hour: Binding<Int>, _ minute: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            Picker("", selection: hour) {
                ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .frame(width: 58)
            .labelsHidden()

            Text(":").foregroundColor(.secondary)

            Picker("", selection: minute) {
                ForEach([0, 15, 30, 45], id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .frame(width: 58)
            .labelsHidden()
        }
    }
}

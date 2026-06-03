import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

struct SoftwareSettingsView: View {
    @EnvironmentObject var salary: SalaryManager
    @EnvironmentObject var tracker: AppUsageTracker

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchStatusText = Self.launchStatusText()
    @State private var showingClearAlert = false
    @State private var showingImportSalaryAlert = false
    @State private var showingImportReportAlert = false
    @State private var showingPresetAlert = false
    @State private var pendingImportData: Data?
    @State private var pendingImportFilename: String?
    @State private var salaryDataStatus: String?
    @State private var reportDataStatus: String?
    @State private var presetStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("软件设置")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("管理启动方式、薪资设置数据和摸鱼日报数据。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            SettingsCard("启动", subtitle: launchStatusText) {
                SettingRow("开机自启", subtitle: "登录 macOS 后自动启动摸鱼没。") {
                    Toggle("", isOn: Binding(
                        get: { launchAtLogin },
                        set: { updateLaunchAtLogin($0) }
                    ))
                    .labelsHidden()
                }
            }

            SettingsCard("预设分类", subtitle: presetStatus ?? "内置 \(DefaultAppCategories.fishingCount) 个摸鱼 App 和 \(DefaultAppCategories.workingCount) 个搬砖 App 预设。") {
                SettingRow("应用预设", subtitle: "追加到名单，不会覆盖你已有的分类。") {
                    Button {
                        showingPresetAlert = true
                    } label: {
                        Label("应用预设", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                }
            }

            SettingsCard("薪资设置数据", subtitle: "导入或导出月薪、搬砖日历、作息边界、加班规则和名单。") {
                SettingRow("导入导出", subtitle: salaryDataStatus ?? "导入或导出 JSON 文件。") {
                    HStack(spacing: 8) {
                        Button {
                            exportSalaryData()
                        } label: {
                            Label("导出", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            importSalaryData()
                        } label: {
                            Label("导入", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            SettingsCard("摸鱼日报数据", subtitle: "导入、导出或清理本地保存的摸鱼日报。") {
                SettingRow("导入导出", subtitle: reportDataStatus ?? "导入或导出 JSON 文件。") {
                    HStack(spacing: 8) {
                        Button {
                            exportUsageData()
                        } label: {
                            Label("导出", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            importUsageData()
                        } label: {
                            Label("导入", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Divider().opacity(0.35)

                SettingRow("数据清理", subtitle: "清空本地摸鱼日报、排行和加班数据。") {
                    Button(role: .destructive) {
                        showingClearAlert = true
                    } label: {
                        Label("清理", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onAppear {
            refreshLaunchStatus()
        }
        .alert("清理日报数据？", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清理", role: .destructive) {
                tracker.clearUsageData()
                reportDataStatus = "摸鱼日报数据已清理。"
            }
        } message: {
            Text("这会删除本地保存的摸鱼日报、排行和加班数据。")
        }
        .alert("导入薪资设置？", isPresented: $showingImportSalaryAlert) {
            Button("取消", role: .cancel) { pendingImportData = nil; pendingImportFilename = nil }
            Button("导入", role: .destructive) {
                guard let data = pendingImportData else { return }
                do {
                    try salary.importSettingsData(data)
                    salaryDataStatus = "已导入 \(pendingImportFilename ?? "文件")。"
                } catch {
                    salaryDataStatus = "导入失败：\(error.localizedDescription)"
                }
                pendingImportData = nil; pendingImportFilename = nil
            }
        } message: {
            Text("导入会覆盖当前的月薪、工时、加班规则和名单设置。")
        }
        .alert("导入日报数据？", isPresented: $showingImportReportAlert) {
            Button("取消", role: .cancel) { pendingImportData = nil; pendingImportFilename = nil }
            Button("导入", role: .destructive) {
                guard let data = pendingImportData else { return }
                do {
                    try tracker.importUsageData(data)
                    reportDataStatus = "已导入 \(pendingImportFilename ?? "文件")。"
                } catch {
                    reportDataStatus = "导入失败：\(error.localizedDescription)"
                }
                pendingImportData = nil; pendingImportFilename = nil
            }
        } message: {
            Text("导入会覆盖当前的摸鱼日报、排行和加班数据。")
        }
        .alert("应用预设分类？", isPresented: $showingPresetAlert) {
            Button("取消", role: .cancel) {}
            Button("应用") {
                applyPresets()
            }
        } message: {
            Text("会把内置的摸鱼和搬砖 App 追加到名单，已有的分类不会被覆盖。")
        }
    }

    func applyPresets() {
        var addedFishing = 0
        var addedWorking = 0

        for id in DefaultAppCategories.fishing {
            guard AppIconLoader.isInstalled(bundleID: id) else { continue }
            guard !salary.fishingApps.contains(id), !salary.workingApps.contains(id) else { continue }
            salary.fishingApps.insert(id)
            addedFishing += 1
        }

        for id in DefaultAppCategories.working {
            guard AppIconLoader.isInstalled(bundleID: id) else { continue }
            guard !salary.fishingApps.contains(id), !salary.workingApps.contains(id) else { continue }
            salary.workingApps.insert(id)
            addedWorking += 1
        }

        if addedFishing == 0 && addedWorking == 0 {
            presetStatus = "预设中的 App 要么已添加，要么未安装。"
        } else {
            presetStatus = "已追加 \(addedFishing) 个摸鱼 + \(addedWorking) 个搬砖 App（仅已安装）。"
        }
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchStatusText = "开机自启设置失败：\(error.localizedDescription)"
        }
        refreshLaunchStatus()
    }

    func refreshLaunchStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        launchStatusText = Self.launchStatusText()
    }

    func exportUsageData() {
        guard let data = tracker.exportUsageData() else {
            reportDataStatus = "没有可导出的摸鱼日报数据。"
            return
        }

        exportJSON(data: data, defaultName: "moyumei-daily-report.json") { result in
            reportDataStatus = result
        }
    }

    func importUsageData() {
        importJSON(onFailure: { message in
            reportDataStatus = message
        }) { data, filename in
            pendingImportData = data
            pendingImportFilename = filename
            showingImportReportAlert = true
        }
    }

    func exportSalaryData() {
        guard let data = salary.exportSettingsData() else {
            salaryDataStatus = "没有可导出的薪资设置数据。"
            return
        }

        exportJSON(data: data, defaultName: "moyumei-salary-settings.json") { result in
            salaryDataStatus = result
        }
    }

    func importSalaryData() {
        importJSON(onFailure: { message in
            salaryDataStatus = message
        }) { data, filename in
            pendingImportData = data
            pendingImportFilename = filename
            showingImportSalaryAlert = true
        }
    }

    func exportJSON(data: Data, defaultName: String, completion: @escaping (String) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                DispatchQueue.main.async { completion("已导出到 \(url.lastPathComponent)。") }
            } catch {
                DispatchQueue.main.async { completion("导出失败：\(error.localizedDescription)") }
            }
        }
    }

    func importJSON(onFailure: @escaping (String) -> Void, completion: @escaping (Data, String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                DispatchQueue.main.async { completion(data, url.lastPathComponent) }
            } catch {
                DispatchQueue.main.async { onFailure("读取文件失败：\(error.localizedDescription)") }
            }
        }
    }

    static func launchStatusText() -> String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "开机自启已开启。"
        case .requiresApproval:
            return "开机自启需要在系统设置中批准。"
        case .notRegistered:
            return "开机自启未开启。"
        case .notFound:
            return "当前应用暂时不能注册开机自启。"
        @unknown default:
            return "开机自启状态未知。"
        }
    }
}

import SwiftUI
import AppKit
import Combine

class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    private var selection: SettingsSelection?

    func show(tab: SettingsTab = .salary) {
        if let selection {
            selection.select(tab)
        }
        if let w = window { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 620),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        w.title = "摸鱼没设置"
        w.isRestorable = false
        w.center()
        let selection = SettingsSelection(tab: tab)
        self.selection = selection
        w.contentView = NSHostingView(
            rootView: SettingsView(selection: selection)
                .environmentObject(appSalaryManager)
                .environmentObject(appUsageTracker)
        )
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = w
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.delegate = nil
            window.contentView = nil
        }
        window = nil
        selection = nil
    }
}

class SettingsSelection: ObservableObject {
    @Published var tab: SettingsTab

    init(tab: SettingsTab) {
        self.tab = tab
    }

    func select(_ tab: SettingsTab) {
        guard self.tab != tab else { return }
        self.tab = tab
    }
}

enum SettingsTab: String, CaseIterable {
    case salary  = "薪资设置"
    case report  = "摸鱼日报"
    case fishing = "摸鱼名单"
    case working = "搬砖名单"
    case software = "软件设置"

    var icon: String {
        switch self {
        case .salary:  return "yensign.circle"
        case .report:  return "chart.pie"
        case .fishing: return "fish"
        case .working: return "laptopcomputer"
        case .software: return "slider.horizontal.3"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var salary: SalaryManager
    @EnvironmentObject var tracker: AppUsageTracker
    @ObservedObject var selection: SettingsSelection

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("摸鱼没")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("设置摸鱼、搬砖、加班和软件规则")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)

                VStack(spacing: 6) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        settingsTabButton(tab)
                    }
                }
                .padding(.horizontal, 10)

                Spacer()
            }
            .frame(width: 164)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.72))

            Divider()

            ZStack {
                Color(nsColor: .controlBackgroundColor).opacity(0.45)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    Group {
                        switch selection.tab {
                        case .salary:  SalarySettingsView()
                        case .report:  ReportCalendarView()
                        case .fishing: AppListSettingsView(title: "摸鱼名单", subtitle: "切到这些 App，会自动记为摸鱼。", accent: .orange, apps: $salary.fishingApps, exclude: salary.workingApps)
                        case .working: AppListSettingsView(title: "搬砖名单", subtitle: "切到这些 App，会自动记为搬砖。", accent: .blue, apps: $salary.workingApps, exclude: salary.fishingApps)
                        case .software: SoftwareSettingsView()
                        }
                    }
                    .environmentObject(salary)
                    .environmentObject(tracker)
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(width: 720, height: 620)
    }

    func settingsTabButton(_ tab: SettingsTab) -> some View {
        Button(action: { selection.select(tab) }) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .foregroundColor(selection.tab == tab ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(selection.tab == tab ? Color.accentColor.opacity(0.14) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            content
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            content
        }
    }
}

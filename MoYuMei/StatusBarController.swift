import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        StatusBarController.shared.start()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        _ = appUsageTracker.exportUsageData()
        return .terminateNow
    }
}

final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private lazy var statusMenu: NSMenu = makeStatusMenu()

    private override init() {
        super.init()
    }

    func start() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "fish", accessibilityDescription: "摸鱼没")
            button.target = self
            button.action = #selector(statusButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 330, height: 460)
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environmentObject(appSalaryManager)
                .environmentObject(appUsageTracker)
        )

        statusItem = item
    }

    func showSettings(tab: SettingsTab = .salary) {
        closePopover()
        SettingsWindowController.shared.show(tab: tab)
    }

    func quit() {
        closePopover()
        _ = appUsageTracker.exportUsageData()
        NSApp.terminate(nil)
    }

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    @objc private func showSalarySettings() {
        showSettings(tab: .salary)
    }

    @objc private func showReport() {
        showSettings(tab: .report)
    }

    @objc private func quitFromMenu() {
        quit()
    }

    private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    private func showMenu() {
        closePopover()
        guard let item = statusItem else { return }
        item.menu = statusMenu
        item.button?.performClick(nil)
        item.menu = nil
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(showSalarySettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)

        let reportItem = NSMenuItem(title: "摸鱼日报", action: #selector(showReport), keyEquivalent: "")
        reportItem.target = self
        menu.addItem(reportItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)

        return menu
    }
}

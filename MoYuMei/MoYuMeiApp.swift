import SwiftUI

@main
struct MoYuMeiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置...") {
                    StatusBarController.shared.showSettings(tab: .salary)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(replacing: .appTermination) {
                Button("退出") {
                    StatusBarController.shared.quit()
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}

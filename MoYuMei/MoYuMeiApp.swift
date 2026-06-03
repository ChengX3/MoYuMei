import SwiftUI

@main
struct MoYuMeiApp: App {
    @StateObject private var tracker = appUsageTracker

    var body: some Scene {
        MenuBarExtra("摸鱼没", systemImage: "fish") {
            ContentView()
                .environmentObject(appSalaryManager)
                .environmentObject(tracker)
        }
        .menuBarExtraStyle(.window)
    }
}

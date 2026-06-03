import SwiftUI
import AppKit

class FixedOvertimeWindowController: NSObject, NSWindowDelegate {
    static let shared = FixedOvertimeWindowController()
    private var window: NSWindow?

    func show(defaultAmount: Double) {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "这次 FUCK 收入"
        w.isRestorable = false
        w.center()
        w.contentView = NSHostingView(
            rootView: FixedOvertimeWindowView(
                amount: defaultAmount,
                onCancel: {
                    FixedOvertimeWindowController.shared.close()
                },
                onStart: { amount in
                    appUsageTracker.toggleOvertimeMode(amount: amount)
                    FixedOvertimeWindowController.shared.close()
                }
            )
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
    @State private var amount: Double
    let onCancel: () -> Void
    let onStart: (Double) -> Void

    init(amount: Double, onCancel: @escaping () -> Void, onStart: @escaping (Double) -> Void) {
        _amount = State(initialValue: amount)
        self.onCancel = onCancel
        self.onStart = onStart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("这次 FUCK 收入")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("一次性 FUCK 收入每次可以不同，这次单独记。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Text("¥")
                    .foregroundColor(.secondary)
                TextField("", value: $amount, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Spacer()
                Button("算了", action: onCancel)
                Button("开始 FUCK") {
                    onStart(amount)
                }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

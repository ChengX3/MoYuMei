import AppKit
import SwiftUI

struct ShortcutBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> ShortcutCaptureView {
        ShortcutCaptureView()
    }

    func updateNSView(_ nsView: ShortcutCaptureView, context: Context) {
        nsView.window?.makeFirstResponder(nsView)
    }
}

final class ShortcutCaptureView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let hasCommand = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
        guard hasCommand, let character = event.charactersIgnoringModifiers else {
            super.keyDown(with: event)
            return
        }

        switch character {
        case ",":
            StatusBarController.shared.showSettings(tab: .salary)
        case "q":
            StatusBarController.shared.quit()
        default:
            super.keyDown(with: event)
        }
    }
}

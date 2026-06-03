import AppKit

enum AppIconLoader {
    static func isInstalled(bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    static func icon(for app: NSRunningApplication?) -> NSImage? {
        app?.icon ?? icon(forBundleURL: app?.bundleURL)
    }

    static func icon(forBundleIdentifier bundleID: String) -> NSImage? {
        icon(forBundleURL: appURL(forBundleIdentifier: bundleID))
    }

    static func icon(forBundleURL appURL: URL?) -> NSImage? {
        guard let appURL else { return nil }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    static func displayName(forBundleIdentifier bundleID: String) -> String? {
        guard let appURL = appURL(forBundleIdentifier: bundleID),
              let bundle = Bundle(url: appURL) else {
            return nil
        }
        return (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
    }

    private static func appURL(forBundleIdentifier bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }
}

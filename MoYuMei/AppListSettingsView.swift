import SwiftUI
import AppKit

struct AppListSettingsView: View {
    let title: String
    let subtitle: String
    let accent: Color
    @Binding var apps: Set<String>
    let exclude: Set<String>

    @State private var allApps: [(id: String, name: String, icon: NSImage?)] = []
    @State private var searchText: String = ""

    var filtered: [(id: String, name: String, icon: NSImage?)] {
        let candidates = allApps.filter { !apps.contains($0.id) && !exclude.contains($0.id) }
        guard !searchText.isEmpty else { return candidates }
        return candidates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var selectedApps: [(id: String, name: String, icon: NSImage?)] {
        Array(apps).sorted().map { id in
            allApps.first(where: { $0.id == id })
                ?? (id: id, name: AppIconLoader.displayName(forBundleIdentifier: id) ?? id, icon: AppIconLoader.icon(forBundleIdentifier: id))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            SettingsCard("已添加", subtitle: selectedApps.isEmpty ? "名单还是空的，先添加几个 App。" : "已添加 \(selectedApps.count) 个 App。") {
                if selectedApps.isEmpty {
                    emptyAppState
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        ForEach(selectedApps, id: \.id) { app in
                            selectedAppChip(app)
                        }
                    }
                }
            }

            SettingsCard("添加 App", subtitle: "摸鱼名单和搬砖名单不会重复。") {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜一个 App 试试...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered.prefix(60), id: \.id) { app in
                            availableAppRow(app)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 190)
            }
        }
        .task {
            guard allApps.isEmpty else { return }
            allApps = Self.scanInstalledApps()
        }
    }

    var emptyAppState: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
            Text("从下面选择 App，添加到当前名单")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func selectedAppChip(_ app: (id: String, name: String, icon: NSImage?)) -> some View {
        HStack(spacing: 8) {
            appIcon(app.icon, size: 20)
            Text(app.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 4)
            Button(action: { removeApp(app.id) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(9)
        .background(accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func availableAppRow(_ app: (id: String, name: String, icon: NSImage?)) -> some View {
        HStack(spacing: 10) {
            appIcon(app.icon, size: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(app.id)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: { addApp(app.id) }) {
                Label("添加", systemImage: "plus")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(accent)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func addApp(_ id: String) {
        apps.insert(id)
    }

    func removeApp(_ id: String) {
        apps.remove(id)
    }

    func appIcon(_ icon: NSImage?, size: CGFloat) -> some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable().interpolation(.high)
            } else {
                Image(systemName: "app.fill").foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    @MainActor
    private static func scanInstalledApps() -> [(id: String, name: String, icon: NSImage?)] {
        let selfID = Bundle.main.bundleIdentifier ?? ""
        let fm = FileManager.default
        let dirs = ["/Applications", "\(NSHomeDirectory())/Applications"]
        var result: [(id: String, name: String, icon: NSImage?)] = []

        for dir in dirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let appURL = URL(fileURLWithPath: dir).appendingPathComponent(item)
                guard let bundle = Bundle(url: appURL),
                      let bundleID = bundle.bundleIdentifier,
                      bundleID != selfID else { continue }
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? String(item.dropLast(4))
                let icon = AppIconLoader.icon(forBundleURL: appURL)
                result.append((id: bundleID, name: name, icon: icon))
            }
        }
        return result.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

import Foundation

let appSalaryManager = SalaryManager()
let appUsageTracker = AppUsageTracker(salaryManager: appSalaryManager)

enum DateFormatting {
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayKey(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func date(from dayKey: String) -> Date? {
        dayFormatter.date(from: dayKey)
    }
}

enum AppStorage {
    private static let directory: URL = {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MoYuMei", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func save(_ data: Data, to filename: String) {
        let url = directory.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
    }

    static func load(from filename: String) -> Data? {
        let url = directory.appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }

    static func remove(_ filename: String) {
        let url = directory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}

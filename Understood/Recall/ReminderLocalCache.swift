import Foundation

/// On-device JSON cache for reminders — local-first, merged by `updatedAt` on refresh.
enum ReminderLocalCache {
    static let fileName = "recall-reminders.json"

    static func load() -> [Reminder] {
        guard let data = readData(from: localURL()) else { return [] }
        return (try? JSONDecoder.recall.decode([Reminder].self, from: data)) ?? []
    }

    static func save(_ reminders: [Reminder]) {
        guard let data = try? JSONEncoder.recall.encode(reminders) else { return }
        write(data, to: localURL())
    }

    private static func localURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recall", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    private static func readData(from url: URL) -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func write(_ data: Data, to url: URL) {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    static func merge(_ local: [Reminder], _ remote: [Reminder]) -> [Reminder] {
        var map: [UUID: Reminder] = [:]
        for reminder in local { map[reminder.id] = reminder }
        for reminder in remote {
            if let existing = map[reminder.id] {
                map[reminder.id] = existing.updatedAt >= reminder.updatedAt ? existing : reminder
            } else {
                map[reminder.id] = reminder
            }
        }
        return Array(map.values)
    }
}

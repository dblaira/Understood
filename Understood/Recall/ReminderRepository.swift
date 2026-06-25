import Foundation
import Supabase

protocol ReminderRepository {
    func ensureReady() async -> Bool
    func fetchAll() async throws -> [Reminder]
    func upsert(_ reminder: Reminder) async throws
    func delete(id: UUID) async throws
}

// MARK: - DB row shapes

private struct ReminderRow: Decodable {
    var id: String
    var title: String
    var notes: String
    var url: String
    var image_path: String?
    var due_date: String?
    var due_time: String?
    var urgent: Bool
    var repeat_rule: String
    var early_reminder: String
    var list_name: String
    var flag: Bool
    var priority: String
    var location_name: String
    var when_messaging_person: String
    var kind: String
    var end_time: String?
    var when_i_am: String
    var outcome: String
    var effort: String
    var energy: String
    var context: String
    var defer_date: String?
    var waiting_on: String
    var pinned: Bool
    var up_next_order: Int?
    var seeded_from_template_id: String?
    var status: String
    var completed_at: String?
    var created_at: String?
    var updated_at: String?
}

private struct ReminderUpsert: Encodable {
    var id: String
    var title: String
    var notes: String
    var url: String
    var image_path: String?
    var due_date: String?
    var due_time: String?
    var urgent: Bool
    var repeat_rule: String
    var early_reminder: String
    var list_name: String
    var flag: Bool
    var priority: String
    var location_name: String
    var when_messaging_person: String
    var kind: String
    var end_time: String?
    var when_i_am: String
    var outcome: String
    var effort: String
    var energy: String
    var context: String
    var defer_date: String?
    var waiting_on: String
    var pinned: Bool
    var up_next_order: Int?
    var seeded_from_template_id: String?
    var status: String
    var completed_at: String?
}

private struct TagRow: Codable {
    var reminder_id: String
    var tag: String
}

private struct SubtaskRow: Codable {
    var id: String
    var reminder_id: String
    var title: String
    var done: Bool
    var position: Int
}

private enum PG {
    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static func parseTimestamp(_ value: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}

final class SupabaseReminderRepository: ReminderRepository {
    private let supabase: SupabaseService

    init(supabase: SupabaseService = .shared) {
        self.supabase = supabase
    }

    func ensureReady() async -> Bool {
        await supabase.checkSession()
        return supabase.isAuthenticated
    }

    func fetchAll() async throws -> [Reminder] {
        guard supabase.isAuthenticated else {
            throw NSError(domain: "Supabase", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let rows: [ReminderRow] = try await supabase.client.schema("recall")
            .from("reminders")
            .select()
            .neq("status", value: "deleted")
            .order("created_at", ascending: false)
            .execute()
            .value

        let tags: [TagRow] = (try? await supabase.client.schema("recall").from("reminder_tags").select().execute().value) ?? []
        let subs: [SubtaskRow] = (try? await supabase.client.schema("recall")
            .from("reminder_subtasks")
            .select()
            .order("position", ascending: true)
            .execute()
            .value) ?? []

        var tagMap: [String: [String]] = [:]
        for tag in tags { tagMap[tag.reminder_id, default: []].append(tag.tag) }

        var subMap: [String: [Subtask]] = [:]
        for sub in subs {
            subMap[sub.reminder_id, default: []].append(
                Subtask(id: UUID(uuidString: sub.id) ?? UUID(), title: sub.title, done: sub.done)
            )
        }

        var result = rows.map { reminder(from: $0, tags: tagMap[$0.id] ?? [], subtasks: subMap[$0.id] ?? []) }

        for (index, row) in rows.enumerated() {
            guard let path = row.image_path, !path.isEmpty else { continue }
            let localName = "\(row.id).jpg"
            if LocalImageStore.exists(localName) {
                result[index].imageLocalPath = localName
            } else if let data = try? await supabase.downloadReminderImage(path: path) {
                LocalImageStore.write(data, name: localName)
                result[index].imageLocalPath = localName
            }
        }

        return result
    }

    func upsert(_ reminder: Reminder) async throws {
        let reminderID = reminder.id.uuidString.lowercased()
        let imagePath = await uploadImageIfPresent(reminder)
        let row = upsertRow(from: reminder, imagePath: imagePath)

        try await supabase.client.schema("recall")
            .from("reminders")
            .upsert(row, onConflict: "id")
            .execute()

        try await supabase.client.schema("recall")
            .from("reminder_tags")
            .delete()
            .eq("reminder_id", value: reminderID)
            .execute()

        if !reminder.tags.isEmpty {
            let tagRows = reminder.tags.map { TagRow(reminder_id: reminderID, tag: $0) }
            try await supabase.client.schema("recall").from("reminder_tags").insert(tagRows).execute()
        }

        try await supabase.client.schema("recall")
            .from("reminder_subtasks")
            .delete()
            .eq("reminder_id", value: reminderID)
            .execute()

        if !reminder.subtasks.isEmpty {
            let subtaskRows = reminder.subtasks.enumerated().map { index, subtask in
                SubtaskRow(
                    id: subtask.id.uuidString.lowercased(),
                    reminder_id: reminderID,
                    title: subtask.title,
                    done: subtask.done,
                    position: index
                )
            }
            try await supabase.client.schema("recall").from("reminder_subtasks").insert(subtaskRows).execute()
        }
    }

    func delete(id: UUID) async throws {
        try await supabase.client.schema("recall")
            .from("reminders")
            .delete()
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }

    private func uploadImageIfPresent(_ reminder: Reminder) async -> String? {
        guard reminder.imageLocalPath != nil,
              let userID = supabase.currentSession?.user.id.uuidString else { return nil }
        let path = "\(userID)/\(reminder.id.uuidString.lowercased()).jpg"
        if let local = reminder.imageLocalPath, let data = LocalImageStore.data(local) {
            try? await supabase.uploadReminderImage(data: data, path: path)
        }
        return path
    }

    private func upsertRow(from reminder: Reminder, imagePath: String?) -> ReminderUpsert {
        ReminderUpsert(
            id: reminder.id.uuidString.lowercased(),
            title: reminder.title,
            notes: reminder.notes,
            url: reminder.url,
            image_path: imagePath,
            due_date: reminder.dueDate.map { PG.date.string(from: $0) },
            due_time: reminder.dueTime.map { PG.time.string(from: $0) },
            urgent: reminder.urgent,
            repeat_rule: reminder.repeatRule.rawValue,
            early_reminder: reminder.earlyReminder.rawValue,
            list_name: reminder.listName,
            flag: reminder.flag,
            priority: reminder.priority.rawValue,
            location_name: reminder.locationName,
            when_messaging_person: reminder.whenMessagingPerson,
            kind: reminder.kind.rawValue,
            end_time: reminder.endTime.map { PG.time.string(from: $0) },
            when_i_am: reminder.whenIAm,
            outcome: reminder.outcome,
            effort: reminder.effort.rawValue,
            energy: reminder.energy.rawValue,
            context: reminder.context.rawValue,
            defer_date: reminder.deferDate.map { PG.date.string(from: $0) },
            waiting_on: reminder.waitingOn,
            pinned: reminder.pinned,
            up_next_order: reminder.upNextOrder,
            seeded_from_template_id: reminder.seededFromTemplateID,
            status: reminder.status.rawValue,
            completed_at: reminder.completedAt.map { ISO8601DateFormatter().string(from: $0) }
        )
    }

    private func reminder(from row: ReminderRow, tags: [String], subtasks: [Subtask]) -> Reminder {
        var reminder = Reminder()
        reminder.id = UUID(uuidString: row.id) ?? UUID()
        reminder.title = row.title
        reminder.notes = row.notes
        reminder.url = row.url
        reminder.dueDate = row.due_date.flatMap { PG.date.date(from: $0) }
        reminder.dueTime = row.due_time.flatMap { PG.time.date(from: $0) }
        reminder.urgent = row.urgent
        reminder.repeatRule = RepeatRule(rawValue: row.repeat_rule) ?? .none
        reminder.earlyReminder = EarlyReminder(rawValue: row.early_reminder) ?? .none
        reminder.listName = row.list_name
        reminder.flag = row.flag
        reminder.priority = Priority(rawValue: row.priority) ?? .none
        reminder.locationName = row.location_name
        reminder.whenMessagingPerson = row.when_messaging_person
        reminder.kind = ReminderKind(rawValue: row.kind) ?? .reminder
        reminder.endTime = row.end_time.flatMap { PG.time.date(from: $0) }
        reminder.whenIAm = row.when_i_am
        reminder.outcome = row.outcome
        reminder.effort = Effort(rawValue: row.effort) ?? .none
        reminder.energy = Energy(rawValue: row.energy) ?? .none
        reminder.context = SuccessStep(rawValue: row.context) ?? .none
        reminder.deferDate = row.defer_date.flatMap { PG.date.date(from: $0) }
        reminder.waitingOn = row.waiting_on
        reminder.pinned = row.pinned
        reminder.upNextOrder = row.up_next_order
        reminder.seededFromTemplateID = row.seeded_from_template_id
        reminder.status = ReminderStatus(rawValue: row.status) ?? .active
        reminder.tags = tags
        reminder.subtasks = subtasks
        reminder.completedAt = row.completed_at.flatMap { PG.parseTimestamp($0) }
        reminder.createdAt = row.created_at.flatMap { PG.parseTimestamp($0) } ?? Date()
        reminder.updatedAt = row.updated_at.flatMap { PG.parseTimestamp($0) } ?? Date()
        reminder.needsSync = false
        return reminder
    }
}

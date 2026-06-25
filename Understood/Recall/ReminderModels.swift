import Foundation

enum Priority: String, Codable, CaseIterable, Identifiable {
    case none, low, medium, high
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekdays, weekly, monthly, yearly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Never"
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

enum EarlyReminder: String, Codable, CaseIterable, Identifiable {
    case none
    case m5 = "5m"
    case m10 = "10m"
    case m30 = "30m"
    case h1 = "1h"
    case d1 = "1d"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .m5: return "5 minutes before"
        case .m10: return "10 minutes before"
        case .m30: return "30 minutes before"
        case .h1: return "1 hour before"
        case .d1: return "1 day before"
        }
    }
    var lead: TimeInterval {
        switch self {
        case .none: return 0
        case .m5: return 300
        case .m10: return 600
        case .m30: return 1800
        case .h1: return 3600
        case .d1: return 86400
        }
    }
}

enum ReminderStatus: String, Codable { case active, completed, deleted }

enum ReminderKind: String, Codable, CaseIterable, Identifiable {
    case reminder, action, event
    var id: String { rawValue }
    var label: String {
        switch self {
        case .reminder: return "Reminder"
        case .action: return "Action"
        case .event: return "Event"
        }
    }
}

enum Effort: String, Codable, CaseIterable, Identifiable {
    case none, m5, m15, m30, h1, h2plus
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "—"
        case .m5: return "5m"
        case .m15: return "15m"
        case .m30: return "30m"
        case .h1: return "1h"
        case .h2plus: return "2h+"
        }
    }
}

enum Energy: String, Codable, CaseIterable, Identifiable {
    case none, low, medium, high
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "—"
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        }
    }
}

enum SuccessStep: String, Codable, CaseIterable, Identifiable {
    case none, context, circle, closeGap, chooseSuccess, codePattern, killSwitch, clearSign, compound
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .context: return "Context"
        case .circle: return "Circle"
        case .closeGap: return "Close the Gap"
        case .chooseSuccess: return "Choose Success"
        case .codePattern: return "Code the Pattern"
        case .killSwitch: return "Create Kill Switch"
        case .clearSign: return "Clear Sign of Success"
        case .compound: return "Compound"
        }
    }
}

struct Subtask: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var done: Bool = false
}

struct Reminder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: ReminderKind = .reminder
    var title: String = ""
    var notes: String = ""
    var url: String = ""
    var imageLocalPath: String? = nil
    var dueDate: Date? = nil
    var dueTime: Date? = nil
    var endTime: Date? = nil
    var urgent: Bool = false
    var repeatRule: RepeatRule = .none
    var earlyReminder: EarlyReminder = .none
    var listName: String = ""
    var flag: Bool = false
    var priority: Priority = .none
    var whenIAm: String = ""
    var outcome: String = ""
    var effort: Effort = .none
    var energy: Energy = .none
    var context: SuccessStep = .none
    var deferDate: Date? = nil
    var waitingOn: String = ""
    var locationName: String = ""
    var whenMessagingPerson: String = ""
    var seededFromTemplateID: String? = nil
    var pinned: Bool = false
    var upNextOrder: Int? = nil
    var tags: [String] = []
    var subtasks: [Subtask] = []
    var status: ReminderStatus = .active
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var completedAt: Date? = nil
    var needsSync: Bool = false
}

extension Reminder {
    var fireDate: Date? {
        if dueDate == nil && dueTime == nil { return nil }
        let cal = Calendar.current
        let base = dueDate ?? Date()
        var comps = cal.dateComponents([.year, .month, .day], from: base)
        if let t = dueTime {
            let tc = cal.dateComponents([.hour, .minute], from: t)
            comps.hour = tc.hour
            comps.minute = tc.minute
        } else {
            comps.hour = 9
            comps.minute = 0
        }
        return cal.date(from: comps)
    }

    var whenLabel: String? {
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "MMM d"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"
        if let date = dueDate, let time = dueTime {
            return dayFmt.string(from: date) + " " + timeFmt.string(from: time)
        } else if let date = dueDate {
            return dayFmt.string(from: date)
        } else if let time = dueTime {
            return timeFmt.string(from: time)
        }
        return nil
    }
}

extension AppNavigationState.CaptureKind {
    var reminderKind: ReminderKind {
        switch self {
        case .reminder: return .reminder
        case .action: return .action
        case .event: return .event
        }
    }

    var label: String { reminderKind.label }
}

extension JSONEncoder {
    static let recall: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let recall: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

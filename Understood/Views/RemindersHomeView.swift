import SwiftUI

/// Reminders tab — Up Next feed with tap-to-edit, matching Re_Call list behavior.
struct RemindersHomeView: View {
    @EnvironmentObject private var store: ReminderStore
    var onOpen: (Reminder) -> Void = { _ in }

    private var reminders: [Reminder] {
        store.active.filter { $0.kind == .reminder }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                Rectangle()
                    .fill(Color.understoodCrimson)
                    .frame(height: 2)

                VStack(alignment: .leading, spacing: 12) {
                    Text("UP NEXT")
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(2.5)
                        .foregroundStyle(Color.sandyBrown)
                        .padding(.top, 16)

                    if reminders.isEmpty {
                        Text("Nothing yet — press the bolt to add your first.")
                            .font(.system(size: 15))
                            .foregroundStyle(.textMuted)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(Array(reminders.enumerated()), id: \.element.id) { index, reminder in
                            ReminderPriorityCard(reminder: reminder, rank: index) {
                                onOpen(reminder)
                            }
                            .contextMenu {
                                Button(reminder.pinned ? "Unpin" : "Pin") {
                                    store.togglePin(reminder)
                                }
                                Button("Mark done") {
                                    store.complete(reminder)
                                }
                                Button("Delete", role: .destructive) {
                                    store.delete(reminder)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 150)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.recallPage.ignoresSafeArea())
        .accessibilityIdentifier("homeScroll")
    }

    private var hero: some View {
        Text("Reminders")
            .font(.system(size: 40, weight: .bold, design: .serif))
            .foregroundStyle(.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 60)
            .padding(.bottom, 18)
            .padding(.horizontal, 16)
            .background(Color.sandyBrown)
    }
}

struct RecallActionsHomeView: View {
    @EnvironmentObject private var store: ReminderStore
    var onOpen: (Reminder) -> Void = { _ in }

    private var actions: [Reminder] {
        store.active.filter { $0.kind == .action }
    }

    private var completedActions: [Reminder] {
        store.completed.filter { $0.kind == .action }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Actions")
                        .font(Typography.connectionHero)
                        .foregroundStyle(.textPrimary)
                    Text("Choose the move that matters.")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.understoodCrimson)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 60)
                .padding(.bottom, 18)
                .padding(.horizontal, 16)
                .background(Color.sandyBrown)

                Rectangle()
                    .fill(Color.understoodCrimson)
                    .frame(height: 2)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("PRIORITY")
                            .font(.system(size: 15, weight: .heavy))
                            .tracking(2.5)
                            .foregroundStyle(Color.sandyBrown)
                        Spacer()
                        Text("\(actions.count)")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(.top, 16)

                    if actions.isEmpty {
                        Text("No actions yet — press the bolt and choose Action.")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.recallNearBlack, in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                            ReminderPriorityCard(reminder: action, rank: index) {
                                onOpen(action)
                            }
                            .contextMenu {
                                Button(action.pinned ? "Unpin" : "Pin") {
                                    store.togglePin(action)
                                }
                                Button("Mark done") {
                                    store.complete(action)
                                }
                                Button("Delete", role: .destructive) {
                                    store.delete(action)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, completedActions.isEmpty ? 150 : 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.recallPage)

                if !completedActions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("COMPLETED")
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(1.5)
                            .foregroundStyle(.textMuted)
                        ForEach(completedActions.prefix(8)) { action in
                            Button { onOpen(action) } label: {
                                ReminderPriorityCard(reminder: action, rank: 2, completed: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 18)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 150)
                    .background(Color.understoodCream)
                }
            }
        }
        .background(Color.recallPage.ignoresSafeArea())
        .accessibilityIdentifier("actionsHome")
    }
}

struct RecallCalendarView: View {
    @EnvironmentObject private var store: ReminderStore
    var onOpen: (Reminder) -> Void = { _ in }

    @State private var month = Date()
    @State private var selected = Date()

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Text("Calendar")
                        .font(Typography.connectionHero)
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Today") {
                        selected = Date()
                        month = Date()
                    }
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.14), in: Capsule())
                }
                .padding(.top, 60)
                .padding(.bottom, 18)
                .padding(.horizontal, 16)
                .background(Color.recallNearBlack)

                Rectangle()
                    .fill(Color.understoodCrimson)
                    .frame(height: 2)

                VStack(spacing: 18) {
                    monthGrid
                    selectedDayList
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 150)
                .background(Color.understoodCream)
            }
        }
        .background(Color.understoodCream.ignoresSafeArea())
        .accessibilityIdentifier("calendarHome")
    }

    private var monthGrid: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            ForEach(weeks.indices, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    ForEach(weeks[weekIndex], id: \.self) { day in
                        dayCell(day)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.borderLight))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
        let isToday = calendar.isDateInToday(day)
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let events = reminders(on: day)
        let weight = dayWeight(events)
        return Button {
            selected = day
            if !inMonth { month = day }
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: weight >= 3 ? 20 : 18, weight: .heavy))
                    .foregroundStyle(dayTextColor(inMonth: inMonth, isToday: isToday, weight: weight))
                    .frame(width: dayMarkSize(weight), height: dayMarkSize(weight))
                    .background { dayBackground(isToday: isToday, isSelected: isSelected, weight: weight) }
                    .overlay {
                        if isSelected && !isToday {
                            Circle().stroke(Color.understoodCrimson, lineWidth: 1.5)
                        }
                    }
                if events.count > 1 {
                    Text("\(events.count)")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(weight >= 3 ? .understoodCrimson : .textMuted)
                } else {
                    Circle()
                        .fill(events.isEmpty ? Color.clear : (weight >= 3 ? Color.understoodCrimson : Color.textMuted))
                        .frame(width: weight >= 3 ? 7 : 5, height: weight >= 3 ? 7 : 5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var selectedDayList: some View {
        let items = reminders(on: selected)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(calendar.isDateInToday(selected) ? "Today" : selected.formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text(selected.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.understoodCrimson)
            }

            if items.isEmpty {
                Text("Nothing scheduled here.")
                    .font(.system(size: 15))
                    .foregroundStyle(.textMuted)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, reminder in
                    ReminderPriorityCard(reminder: reminder, rank: index) {
                        onOpen(reminder)
                    }
                }
            }
        }
    }

    private func reminders(on day: Date) -> [Reminder] {
        store.reminders
            .filter { $0.status != .deleted }
            .filter { reminder in
                guard let date = reminder.dueDate else { return false }
                return calendar.isDate(date, inSameDayAs: day)
            }
            .sorted { ($0.fireDate ?? .distantFuture) < ($1.fireDate ?? .distantFuture) }
    }

    private var weeks: [[Date]] {
        guard let monthStart = calendar.dateInterval(of: .month, for: month)?.start else { return [] }
        let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
        guard let start = calendar.date(byAdding: .day, value: -(weekdayOfFirst - 1), to: monthStart) else { return [] }
        let days = (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    private func dayWeight(_ events: [Reminder]) -> Int {
        events.map(eventWeight).max() ?? 0
    }

    private func eventWeight(_ reminder: Reminder) -> Int {
        if reminder.urgent || reminder.flag || reminder.priority == .high { return 3 }
        if reminder.priority == .medium || reminder.pinned { return 2 }
        if reminder.priority == .low || reminder.kind == .event { return 1 }
        return 0
    }

    private func dayMarkSize(_ weight: Int) -> CGFloat {
        switch weight {
        case 3...: return 42
        case 2: return 38
        case 1: return 34
        default: return 30
        }
    }

    private func dayTextColor(inMonth: Bool, isToday: Bool, weight: Int) -> Color {
        if isToday { return .white }
        if !inMonth { return .black.opacity(0.28) }
        return weight >= 3 ? .understoodCrimson : .textPrimary
    }

    @ViewBuilder private func dayBackground(isToday: Bool, isSelected: Bool, weight: Int) -> some View {
        if isToday {
            Circle().fill(Color.understoodCrimson)
        } else if weight >= 3 {
            Circle().fill(Color.understoodCrimson.opacity(0.18))
        } else if weight == 2 {
            Circle().fill(Color.sandyBrown.opacity(0.55))
        } else if weight == 1 {
            Circle().fill(Color.surfaceSubtle)
        } else if isSelected {
            Circle().fill(Color.understoodCrimson.opacity(0.10))
        }
    }
}

private struct ReminderPriorityCard: View {
    let reminder: Reminder
    var rank: Int
    var completed = false
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: kindIcon)
                        .font(.system(size: 14, weight: .bold))
                    Text(reminder.kind.label.uppercased())
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.2)
                    Spacer()
                    if reminder.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12))
                    }
                }
                .foregroundStyle(.understoodCrimson)

                Text(reminder.title)
                    .font(titleFont)
                    .foregroundStyle(completed ? .textMuted : .textPrimary)
                    .strikethrough(completed)
                    .multilineTextAlignment(.leading)

                if let when = reminder.whenLabel {
                    Text(when)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.textSecondary)
                }

                if let detail {
                    Text(detail)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.textSecondary)
                        .lineLimit(rank == 0 ? 3 : 1)
                }
            }
            .padding(rank == 0 ? 18 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(cardBorder))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(rank == 0 ? "priorityCard0" : "priorityCard")
    }

    private var kindIcon: String {
        switch reminder.kind {
        case .reminder: return "clock"
        case .action: return "bolt.fill"
        case .event: return "calendar"
        }
    }

    private var titleFont: Font {
        rank == 0 ? Typography.cardHeadline : .system(size: 18, weight: .bold)
    }

    private var cardBackground: Color {
        if completed { return Color.surfaceSubtle }
        switch rank {
        case 0: return .white
        case 1: return Color.understoodBeige
        default: return .white
        }
    }

    private var cardBorder: Color {
        if reminder.urgent || reminder.flag || reminder.priority == .high {
            return .understoodCrimson.opacity(0.45)
        }
        return .borderLight
    }

    private var detail: String? {
        if !reminder.notes.isEmpty { return reminder.notes }
        if !reminder.outcome.isEmpty { return reminder.outcome }
        if !reminder.tags.isEmpty { return reminder.tags.map { "#\($0)" }.joined(separator: " ") }
        return nil
    }
}

extension Color {
    static let recallPage = Color(red: 0x0A / 255.0, green: 0x16 / 255.0, blue: 0x26 / 255.0)
    static let recallNearBlack = Color(red: 0x0C / 255.0, green: 0x1E / 255.0, blue: 0x33 / 255.0)
}

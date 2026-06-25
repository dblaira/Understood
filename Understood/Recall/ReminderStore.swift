import Foundation
import SwiftUI
import Combine

@MainActor
final class ReminderStore: ObservableObject {
    @Published private(set) var reminders: [Reminder] = []

    private let repository: ReminderRepository

    init(repository: ReminderRepository = SupabaseReminderRepository()) {
        self.repository = repository
        reminders = ReminderLocalCache.load()
        reminders.forEach(NotificationScheduler.schedule)
    }

    var active: [Reminder] {
        reminders
            .filter { $0.status == .active }
            .sorted { compareUpNext($0, $1) }
    }

    var completed: [Reminder] {
        reminders
            .filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    func bootstrap() async {
        guard await repository.ensureReady() else { return }
        do {
            let remote = try await repository.fetchAll()
            let merged = ReminderLocalCache.merge(reminders, remote)
            guard merged != reminders else { return }
            reminders = merged
            ReminderLocalCache.save(reminders)
            reminders.forEach(NotificationScheduler.schedule)
        } catch {
            print("ReminderStore bootstrap failed: \(error.localizedDescription)")
        }
    }

    func save(_ reminder: Reminder) {
        var updated = reminder
        updated.updatedAt = Date()
        updated.needsSync = true
        upsertLocal(updated)
        NotificationScheduler.schedule(updated)
        syncToRemote(updated)
    }

    func complete(_ reminder: Reminder) {
        var updated = reminder
        updated.status = .completed
        updated.completedAt = Date()
        NotificationScheduler.cancel(updated)
        save(updated)
    }

    func uncomplete(_ reminder: Reminder) {
        var updated = reminder
        updated.status = .active
        updated.completedAt = nil
        save(updated)
    }

    func togglePin(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        var updated = reminders[index]
        updated.pinned.toggle()
        reminders[index] = updated

        if updated.pinned {
            applyBlockOrder(active.filter { !$0.pinned })
            var pinned = active.filter { $0.pinned }
            pinned.removeAll { $0.id == updated.id }
            pinned.insert(reminders[index], at: 0)
            applyBlockOrder(pinned)
        } else {
            applyBlockOrder(active.filter { $0.pinned })
            var unpinned = active.filter { !$0.pinned }
            unpinned.removeAll { $0.id == updated.id }
            unpinned.insert(reminders[index], at: 0)
            applyBlockOrder(unpinned)
        }
    }

    enum UpNextMoveDirection { case up, down }

    func moveUpNext(_ reminder: Reminder, direction: UpNextMoveDirection) {
        let feed = active
        let blockPinned = reminder.pinned
        var block = feed.filter { $0.pinned == blockPinned }
        guard let blockIndex = block.firstIndex(where: { $0.id == reminder.id }) else { return }

        let target: Int
        switch direction {
        case .up: target = blockIndex - 1
        case .down: target = blockIndex + 1
        }
        guard block.indices.contains(target) else { return }

        block.swapAt(blockIndex, target)
        applyBlockOrder(block)
    }

    func delete(_ reminder: Reminder) {
        reminders.removeAll { $0.id == reminder.id }
        NotificationScheduler.cancel(reminder)
        saveCache()
        Task {
            try? await repository.delete(id: reminder.id)
        }
    }

    private func compareUpNext(_ lhs: Reminder, _ rhs: Reminder) -> Bool {
        if lhs.pinned != rhs.pinned { return lhs.pinned }
        return compareWithinBlock(lhs, rhs)
    }

    private func compareWithinBlock(_ lhs: Reminder, _ rhs: Reminder) -> Bool {
        switch (lhs.upNextOrder, rhs.upNextOrder) {
        case let (left?, right?): return left < right
        case (nil, nil): return sortKey(lhs) < sortKey(rhs)
        case (_?, nil): return true
        case (nil, _?): return false
        }
    }

    private func sortKey(_ reminder: Reminder) -> Date {
        reminder.fireDate ?? reminder.createdAt
    }

    private func applyBlockOrder(_ ordered: [Reminder]) {
        var touched: [Reminder] = []
        for (index, item) in ordered.enumerated() {
            guard let reminderIndex = reminders.firstIndex(where: { $0.id == item.id }) else { continue }
            guard reminders[reminderIndex].upNextOrder != index else { continue }
            var updated = reminders[reminderIndex]
            updated.upNextOrder = index
            updated.updatedAt = Date()
            reminders[reminderIndex] = updated
            touched.append(updated)
        }
        guard !touched.isEmpty else { return }
        saveCache()
        for reminder in touched {
            NotificationScheduler.schedule(reminder)
            syncToRemote(reminder)
        }
    }

    private func upsertLocal(_ reminder: Reminder) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = reminder
        } else {
            reminders.append(reminder)
        }
        saveCache()
    }

    private func saveCache() {
        ReminderLocalCache.save(reminders)
    }

    private func syncToRemote(_ reminder: Reminder) {
        Task {
            guard await repository.ensureReady() else { return }
            do {
                try await repository.upsert(reminder)
                await MainActor.run {
                    guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
                    var synced = reminders[index]
                    synced.needsSync = false
                    reminders[index] = synced
                    saveCache()
                }
            } catch {
                print("Reminder sync failed: \(error.localizedDescription)")
            }
        }
    }
}

import SwiftUI

/// Reminders tab — Up Next feed with tap-to-edit, matching Re_Call list behavior.
struct RemindersHomeView: View {
    @EnvironmentObject private var store: ReminderStore
    var onOpen: (Reminder) -> Void = { _ in }

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

                    if store.active.isEmpty {
                        Text("Nothing yet — press the bolt to add your first.")
                            .font(.system(size: 15))
                            .foregroundStyle(.textMuted)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(store.active) { reminder in
                            ReminderRowCard(reminder: reminder) {
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

private struct ReminderRowCard: View {
    let reminder: Reminder
    let onTap: () -> Void

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
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.leading)

                if let when = reminder.whenLabel {
                    Text(when)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("upNextCard")
    }

    private var kindIcon: String {
        switch reminder.kind {
        case .reminder: return "clock"
        case .action: return "bolt.fill"
        case .event: return "calendar"
        }
    }
}

extension Color {
    static let recallPage = Color(red: 0x0A / 255.0, green: 0x16 / 255.0, blue: 0x26 / 255.0)
    static let recallNearBlack = Color(red: 0x0C / 255.0, green: 0x1E / 255.0, blue: 0x33 / 255.0)
}

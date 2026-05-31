//
//  BeliefLibraryView.swift
//  Understood
//
//  Phase 4: Browse all beliefs grouped by type
//

import SwiftUI

struct BeliefLibraryView: View {
    let supabase = SupabaseService.shared
    @State private var beliefs: [Entry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    /// Life area filter passed from navigation state
    var lifeAreaFilter: String = "all"

    /// The four belief types from the scoring engine
    private let beliefTypes = [
        ("identity_anchor", "Identity Anchors", "shield.fill"),
        ("pattern_interrupt", "Pattern Interrupts", "arrow.triangle.2.circlepath"),
        ("validated_principle", "Validated Principles", "checkmark.seal.fill"),
        ("process_anchor", "Process Anchors", "list.bullet.rectangle.fill")
    ]

    /// Filtered beliefs based on life area
    private var filteredBeliefs: [Entry] {
        guard lifeAreaFilter != "all" else { return beliefs }
        return beliefs.filter { $0.category.lowercased() == lifeAreaFilter.lowercased() }
    }

    var body: some View {
        ZStack {
            Color.understoodCream
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Loading connections...")
                    .foregroundStyle(.textSecondary)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.textSecondary)
                    Text(error)
                        .font(Typography.subtitle)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadBeliefs() }
                    }
                    .foregroundStyle(.textPrimary)
                }
                .padding()
            } else if filteredBeliefs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.textPrimary.opacity(0.2))
                    Text("No connections yet")
                        .font(Typography.emptyState)
                    Text("As you capture entries, the AI will\nidentify your underlying connections")
                        .font(Typography.subtitle)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        // Summary stats
                        BeliefSummaryBar(beliefs: filteredBeliefs)
                            .padding(.horizontal, 20)

                        // Grouped by type
                        ForEach(beliefTypes, id: \.0) { type, title, icon in
                            let filtered = filteredBeliefs.filter { $0.connectionType == type }
                            if !filtered.isEmpty {
                                BeliefSection(
                                    title: title,
                                    icon: icon,
                                    beliefs: filtered
                                )
                            }
                        }

                        // Uncategorized beliefs
                        let uncategorized = filteredBeliefs.filter { belief in
                            guard let type = belief.connectionType else { return true }
                            return !beliefTypes.contains(where: { $0.0 == type })
                        }
                        if !uncategorized.isEmpty {
                            BeliefSection(
                                title: "Other Connections",
                                icon: "lightbulb.fill",
                                beliefs: uncategorized
                            )
                        }

                        // Bottom spacer for FAB
                        Spacer().frame(height: 80)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .task {
            await loadBeliefs()
        }
    }

    private func loadBeliefs() async {
        isLoading = beliefs.isEmpty
        errorMessage = nil

        do {
            beliefs = try await supabase.fetchBeliefs()
            isLoading = false
        } catch {
            errorMessage = "Could not load connections.\n\(error.localizedDescription)"
            isLoading = false
            print("Fetch beliefs error: \(error)")
        }
    }
}

// MARK: - Belief Summary Bar

struct BeliefSummaryBar: View {
    let beliefs: [Entry]

    var body: some View {
        HStack(spacing: 20) {
            SummaryStatView(
                value: "\(beliefs.count)",
                label: "Total"
            )

            let types = Set(beliefs.compactMap { $0.connectionType })
            SummaryStatView(
                value: "\(types.count)",
                label: "Types"
            )

            let connected = beliefs.filter { $0.sourceEntryId != nil }.count
            SummaryStatView(
                value: "\(connected)",
                label: "Connected"
            )

            Spacer()
        }
        .padding(16)
        .background(Color.surfaceSubtle)
        .cornerRadius(12)
    }
}

struct SummaryStatView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Typography.cardHeadline)
                .foregroundStyle(.textPrimary)
            Text(label)
                .font(Typography.chipLabel)
                .foregroundStyle(.textMuted)
        }
    }
}

// MARK: - Belief Section

struct BeliefSection: View {
    let title: String
    let icon: String
    let beliefs: [Entry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.understoodCrimson)
                Text(title.uppercased())
                    .font(Typography.sectionHeader)
                    .tracking(1.5)
                    .foregroundStyle(.textMuted)
                Text("\(beliefs.count)")
                    .font(Typography.chipLabel)
                    .foregroundStyle(.textMetadata)
                Spacer()
            }
            .padding(.horizontal, 20)

            // Belief cards
            ForEach(beliefs) { belief in
                NavigationLink(destination: BeliefDetailView(belief: belief)) {
                    BeliefCard(belief: belief)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Belief Card

struct BeliefCard: View {
    let belief: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Belief text
            Text(belief.displayHeadline)
                .font(Typography.cardHeadline)
                .foregroundStyle(.textPrimary)
                .lineLimit(3)

            HStack(spacing: 12) {
                // Type badge
                if let connectionType = belief.connectionType {
                    Text(connectionType.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(Typography.chipLabel)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.understoodCrimson.opacity(0.1))
                        .foregroundStyle(.understoodCrimson)
                        .cornerRadius(12)
                }

                // Date
                Text(formatDate(belief.createdAt))
                    .font(Typography.date)
                    .foregroundStyle(.textMetadata)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.textMuted)
            }
        }
        .padding(16)
        .background(Color.understoodCream)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderLight, lineWidth: 1)
        )
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return formatShort(date)
        }
        return formatShort(date)
    }

    private func formatShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        BeliefLibraryView(lifeAreaFilter: "all")
    }
}

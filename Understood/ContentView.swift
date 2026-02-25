//
//  ContentView.swift
//  Understood
//
//  Created by Adam Blair on 2/24/26.
//

import SwiftUI

struct ContentView: View {
    let supabase = SupabaseService.shared
    @State private var entries: [Entry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Binding var showCapture: Bool

    /// Active belief to feature at top of feed
    @State private var activeBelief: Entry?

    /// Sorted entries: pinned first, then by date
    private var sortedEntries: [Entry] {
        entries.sorted { a, b in
            let aPinned = a.pinned ?? false
            let bPinned = b.pinned ?? false
            if aPinned != bPinned { return aPinned }
            return a.createdAt > b.createdAt
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.understoodCream
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading entries...")
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
                            Task { await loadEntries() }
                        }
                        .foregroundStyle(.textPrimary)
                    }
                    .padding()
                } else if entries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.textPrimary.opacity(0.2))
                        Text("No entries yet")
                            .font(Typography.emptyState)
                        Text("Tap + to capture your first entry")
                            .font(Typography.subtitle)
                            .foregroundStyle(.textSecondary)
                    }
                } else {
                    List {
                        // Active Belief card at top of feed
                        if let belief = activeBelief {
                            Section {
                                NavigationLink(destination: BeliefDetailView(belief: belief)) {
                                    ActiveBeliefCard(belief: belief)
                                }
                                .listRowBackground(Color.understoodCream)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            }
                        }

                        // Recent entries with swipe actions
                        Section {
                            ForEach(sortedEntries) { entry in
                                NavigationLink(destination: EntryDetailView(
                                    entry: entry,
                                    onDeleted: {
                                        Task { await loadEntries() }
                                    }
                                )) {
                                    EntryRow(entry: entry)
                                }
                                .listRowBackground(Color.understoodCream)
                                .listRowSeparatorTint(.surfaceChip)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        Task { await deleteEntry(entry) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        Task { await togglePin(entry) }
                                    } label: {
                                        let isPinned = entry.pinned ?? false
                                        Label(
                                            isPinned ? "Unpin" : "Pin",
                                            systemImage: isPinned ? "pin.slash.fill" : "pin.fill"
                                        )
                                    }
                                    .tint(.understoodCrimson)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await loadEntries()
                    }
                }
            }
            .navigationTitle("Understood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            try? await supabase.signOut()
                        }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.textMetadata)
                    }
                }
            }
        }
        .task {
            await loadEntries()
        }
        .onChange(of: showCapture) { _, isShowing in
            if !isShowing {
                Task { await loadEntries() }
            }
        }
    }

    // MARK: - Data

    private func loadEntries() async {
        isLoading = entries.isEmpty
        errorMessage = nil

        do {
            entries = try await supabase.fetchEntries()

            // Load active belief (highest-scored connection)
            let beliefs = try await supabase.fetchBeliefs(limit: 1)
            activeBelief = beliefs.first

            isLoading = false
        } catch {
            errorMessage = "Could not load entries.\n\(error.localizedDescription)"
            isLoading = false
            print("Fetch error: \(error)")
        }
    }

    private func deleteEntry(_ entry: Entry) async {
        do {
            try await supabase.deleteEntry(id: entry.id)
            // Remove locally for instant UI update
            await MainActor.run {
                entries.removeAll { $0.id == entry.id }
            }
        } catch {
            print("Delete error: \(error)")
        }
    }

    private func togglePin(_ entry: Entry) async {
        let newPinned = !(entry.pinned ?? false)
        do {
            try await supabase.togglePin(id: entry.id, pinned: newPinned)
            // Update locally for instant UI update
            await MainActor.run {
                if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                    entries[index].pinned = newPinned
                }
            }
        } catch {
            print("Pin error: \(error)")
        }
    }
}

// MARK: - Active Belief Card

struct ActiveBeliefCard: View {
    let belief: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ACTIVE BELIEF")
                    .font(Typography.sectionHeader)
                    .tracking(1.5)
                    .foregroundStyle(.understoodCrimson)
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(.understoodCrimson)
            }

            Text(belief.displayHeadline)
                .font(Typography.cardHeadline)
                .foregroundStyle(.textPrimary)
                .lineLimit(3)

            if let connectionType = belief.connectionType {
                Text(connectionType.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(Typography.chipLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.understoodCrimson.opacity(0.1))
                    .foregroundStyle(.understoodCrimson)
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color.surfaceSubtle)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderLight, lineWidth: 1)
        )
    }
}

// MARK: - Entry Row

struct EntryRow: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category label + pin indicator
            HStack(spacing: 6) {
                Text(entry.category.uppercased())
                    .font(Typography.categoryLabel)
                    .tracking(1.5)
                    .foregroundStyle(.understoodCrimson)

                if entry.pinned == true {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.understoodCrimson)
                }
            }

            // Headline (with fallback to content preview)
            Text(entry.displayHeadline)
                .font(Typography.cardHeadline)
                .foregroundStyle(.textPrimary)
                .lineLimit(2)

            // Bottom row: date + mood
            HStack {
                Text(formatDate(entry.createdAt))
                    .font(Typography.date)
                    .foregroundStyle(.textMetadata)

                if let mood = entry.mood, !mood.isEmpty {
                    Text("  \(mood)")
                        .font(Typography.info)
                        .foregroundStyle(.textSecondary)
                }

                Spacer()
            }
        }
        .padding(.vertical, 8)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return formatRelative(date)
        }
        return formatRelative(date)
    }

    private func formatRelative(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today, \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    ContentView(showCapture: .constant(false))
}

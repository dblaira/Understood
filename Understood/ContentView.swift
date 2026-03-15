//
//  ContentView.swift
//  Understood
//
//  Created by Adam Blair on 2/24/26.
//

import SwiftUI
import Auth

struct ContentView: View {
    let supabase = SupabaseService.shared
    @State private var entries: [Entry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    /// Life area filter passed from navigation state
    var lifeAreaFilter: String = "all"

    /// Beliefs for carousel (up to 6)
    @State private var beliefs: [Entry] = []

    /// User-reorderable entry list
    @State private var orderedEntries: [Entry] = []
    @State private var isEditingOrder = false

    /// Filtered entries based on life area
    private var filteredEntries: [Entry] {
        guard lifeAreaFilter != "all" else { return orderedEntries }
        return orderedEntries.filter { $0.category.lowercased() == lifeAreaFilter.lowercased() }
    }

    var body: some View {
        ZStack {
            Color.understoodCream
                .ignoresSafeArea()

            if isLoading {
                ScrollView {
                    SkeletonFeed()
                }
            } else if let error = errorMessage {
                ErrorBanner(message: error) {
                    Task { await loadEntries() }
                }
                .padding()
            } else if entries.isEmpty {
                EmptyStateView(
                    icon: "book.pages",
                    title: "No entries yet",
                    subtitle: "Tap + to capture your first entry"
                )
            } else {
                List {
                    // MARK: - Belief Carousel
                    if !beliefs.isEmpty && lifeAreaFilter == "all" {
                        Section {
                            BeliefCarousel(beliefs: beliefs)
                        }
                        .listRowBackground(Color.understoodBeige)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }

                    // MARK: - Section Header with Edit Toggle
                    Section {
                        HStack {
                            Text("RECENT ENTRIES")
                                .font(Typography.sectionHeader)
                                .tracking(1.5)
                                .foregroundStyle(.textMetadata)

                            Spacer()

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditingOrder.toggle()
                                }
                            } label: {
                                Text(isEditingOrder ? "Done" : "Edit")
                                    .font(Typography.uiMedium)
                                    .foregroundStyle(.understoodCrimson)
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    }
                    .listRowBackground(Color.understoodCream)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))

                    // MARK: - Entry Feed (Reorderable)
                    Section {
                        ForEach(filteredEntries) { entry in
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
                        .onMove(perform: moveEntry)
                    }
                    .environment(\.editMode, .constant(isEditingOrder ? .active : .inactive))
                }
                .listStyle(.plain)
                .refreshable {
                    await loadEntries()
                }
            }
        }
        .task {
            await loadEntries()
        }
    }

    // MARK: - Data

    private func loadEntries() async {
        isLoading = entries.isEmpty
        errorMessage = nil

        do {
            entries = try await supabase.fetchEntries()

            // Load beliefs for carousel (up to 6)
            beliefs = try await supabase.fetchBeliefs(limit: 6)

            // Apply stored custom order (or default sort)
            orderedEntries = applyStoredOrder(to: entries)

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
            Haptics.warning()
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    entries.removeAll { $0.id == entry.id }
                    orderedEntries.removeAll { $0.id == entry.id }
                    saveEntryOrder()
                }
            }
        } catch {
            Haptics.error()
            print("Delete error: \(error)")
        }
    }

    private func togglePin(_ entry: Entry) async {
        let newPinned = !(entry.pinned ?? false)
        do {
            try await supabase.togglePin(id: entry.id, pinned: newPinned)
            Haptics.medium()
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                        entries[index].pinned = newPinned
                    }
                    if let index = orderedEntries.firstIndex(where: { $0.id == entry.id }) {
                        orderedEntries[index].pinned = newPinned
                    }
                }
            }
        } catch {
            Haptics.error()
            print("Pin error: \(error)")
        }
    }

    // MARK: - Reorder

    /// Handle drag-to-reorder
    private func moveEntry(from source: IndexSet, to destination: Int) {
        orderedEntries.move(fromOffsets: source, toOffset: destination)
        saveEntryOrder()
        Haptics.light()
    }

    // MARK: - Order Persistence (UserDefaults)

    private var orderStorageKey: String {
        let userId = supabase.currentSession?.user.id.uuidString ?? "default"
        return "entry-order-\(userId)"
    }

    /// Save current entry order to UserDefaults
    private func saveEntryOrder() {
        let ids = orderedEntries.map { $0.id }
        UserDefaults.standard.set(ids, forKey: orderStorageKey)
    }

    /// Read stored entry order from UserDefaults
    private func storedEntryOrder() -> [String] {
        UserDefaults.standard.stringArray(forKey: orderStorageKey) ?? []
    }

    /// Apply stored order to fetched entries. New entries appear at top, then custom order.
    private func applyStoredOrder(to fetched: [Entry]) -> [Entry] {
        let storedIds = storedEntryOrder()

        // If no stored order, use default sort: pinned first, then newest
        guard !storedIds.isEmpty else {
            return fetched.sorted { a, b in
                let aPinned = a.pinned ?? false
                let bPinned = b.pinned ?? false
                if aPinned != bPinned { return aPinned }
                return a.createdAt > b.createdAt
            }
        }

        let storedIdSet = Set(storedIds)

        // New entries not yet in stored order (newest first)
        let newEntries = fetched
            .filter { !storedIdSet.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }

        // Previously ordered entries in their custom order
        let entryMap = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        let orderedExisting = storedIds.compactMap { entryMap[$0] }

        return newEntries + orderedExisting
    }
}

// MARK: - Belief Carousel

struct BeliefCarousel: View {
    let beliefs: [Entry]
    @State private var currentIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            // Beige header area
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    ForEach([
                        (x: 0.6, y: 0.0),
                        (x: -0.6, y: 0.0),
                        (x: 0.0, y: 0.6),
                        (x: 0.0, y: -0.6)
                    ], id: \.x) { offset in
                        Text("Connections")
                            .font(Typography.connectionHero)
                            .tracking(-0.5)
                            .foregroundStyle(.understoodCrimson)
                            .offset(x: offset.x, y: offset.y)
                    }
                    Text("Connections")
                        .font(Typography.connectionHero)
                        .tracking(-0.5)
                        .foregroundStyle(.understoodCrimson)
                }

                Text(todayDateString().uppercased())
                    .font(Typography.date)
                    .tracking(1)
                    .foregroundStyle(.textMetadata)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Quote carousel
            TabView(selection: $currentIndex) {
                ForEach(Array(beliefs.enumerated()), id: \.element.id) { index, belief in
                    NavigationLink(destination: BeliefDetailView(belief: belief)) {
                        BeliefQuoteCard(belief: belief)
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 180)

            // Custom pagination dots
            if beliefs.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<beliefs.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(index == currentIndex ? Color.understoodCrimson : Color.borderMedium)
                            .frame(
                                width: index == currentIndex ? 24 : 8,
                                height: 8
                            )
                            .animation(.easeInOut(duration: 0.2), value: currentIndex)
                    }

                    Text("\(currentIndex + 1) / \(beliefs.count)")
                        .font(Typography.date)
                        .foregroundStyle(.textMetadata)
                        .padding(.leading, 4)
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
            }

            // Crimson bottom border (matches web)
            Rectangle()
                .fill(Color.understoodCrimson)
                .frame(height: 2)
        }
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: Date())
    }
}

// MARK: - Belief Quote Card

struct BeliefQuoteCard: View {
    let belief: Entry

    var body: some View {
        VStack(spacing: 12) {
            // Quote with left crimson border
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.understoodCrimson)
                    .frame(width: 1.5)

                Text(belief.displayHeadline)
                    .font(Typography.beliefQuote)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .lineLimit(4)
                    .padding(.leading, 16)
                    .padding(.trailing, 8)
            }
            .padding(.horizontal, 20)

            // Connection type label
            if let connectionType = belief.connectionType {
                Text(connectionType.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(Typography.chipLabel)
                    .foregroundStyle(.textMetadata)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Entry Row (Dispatches to Image or Text variant)

struct EntryRow: View {
    let entry: Entry

    var body: some View {
        if entry.hasImages, let posterUrl = entry.posterImageUrl {
            ImageEntryRow(entry: entry, posterUrl: posterUrl)
        } else {
            TextEntryRow(entry: entry)
        }
    }
}

// MARK: - Image Entry Row (Editorial card with poster image)

struct ImageEntryRow: View {
    let entry: Entry
    let posterUrl: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Large poster image
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: posterUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.surfaceSubtle)
                            .frame(height: 200)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.textMuted)
                            }
                    case .empty:
                        Rectangle()
                            .fill(Color.surfaceSubtle)
                            .frame(height: 200)
                            .overlay(ProgressView())
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .cornerRadius(8)

                // Image count badge
                let imageCount = entry.allImages.count
                if imageCount > 1 {
                    HStack(spacing: 3) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 10))
                        Text("\(imageCount)")
                            .font(Typography.chipLabel)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(6)
                    .padding(8)
                }
            }

            // Content below image
            VStack(alignment: .leading, spacing: 8) {
                // Category + pin
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

                // Headline
                Text(entry.displayHeadline)
                    .font(Typography.listHeadline)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(3)

                // Date + mood
                HStack {
                    Text(EntryDateFormatter.format(entry.createdAt))
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
            .padding(.top, 10)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Text Entry Row (No image)

struct TextEntryRow: View {
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

            // Headline
            Text(entry.displayHeadline)
                .font(Typography.listHeadline)
                .foregroundStyle(.textPrimary)
                .lineLimit(2)

            // Bottom row: date + mood
            HStack {
                Text(EntryDateFormatter.format(entry.createdAt))
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
}

// MARK: - Shared Date Formatter

enum EntryDateFormatter {
    static func format(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            return formatRelative(date)
        }

        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return formatRelative(date)
        }

        return dateString
    }

    private static func formatRelative(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let df = DateFormatter()
            df.dateFormat = "h:mm a"
            return "Today, \(df.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MMM d, yyyy"
            return df.string(from: date)
        }
    }
}

#Preview {
    NavigationStack {
        ContentView(lifeAreaFilter: "all")
    }
}

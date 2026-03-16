//
//  ContentView.swift
//  Understood
//
//  Three-layer editorial Stories view: Hero, Carousel, Category + Pinned layout
//

import SwiftUI
import Auth

struct ContentView: View {
    let supabase = SupabaseService.shared
    @Environment(AppNavigationState.self) private var nav

    @State private var entries: [Entry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var beliefs: [Entry] = []
    @State private var featuredEntry: Entry?
    @State private var pinnedEntries: [Entry] = []

    var lifeAreaFilter: String = "all"

    private var stories: [Entry] {
        let filtered = entries.filter { $0.isStory }
        guard lifeAreaFilter != "all" else { return filtered }
        return filtered.filter { $0.category.lowercased() == lifeAreaFilter.lowercased() }
    }

    private var heroStory: Entry? {
        featuredEntry ?? stories.first
    }

    private var carouselStories: [Entry] {
        let skip = heroStory?.id
        return Array(stories.filter { $0.id != skip }.prefix(10))
    }

    private let categories = ["Business", "Finance", "Health", "Spiritual", "Fun", "Social", "Romance"]

    private var latestByCategory: [(category: String, entry: Entry)] {
        categories.compactMap { cat in
            if let entry = stories.first(where: { $0.category.lowercased() == cat.lowercased() }) {
                return (cat, entry)
            }
            return nil
        }
    }

    private var pinnedStories: [Entry] {
        pinnedEntries.filter { $0.isStory }
    }

    private var pinnedNotes: [Entry] {
        pinnedEntries.filter { $0.isNote }
    }

    private var pinnedActions: [Entry] {
        pinnedEntries.filter { $0.isAction }
    }

    var body: some View {
        ZStack {
            Color.understoodCream
                .ignoresSafeArea()

            if isLoading {
                ScrollView { SkeletonFeed() }
            } else if let error = errorMessage {
                ErrorBanner(message: error) {
                    Task { await loadEntries() }
                }
                .padding()
            } else if entries.isEmpty {
                EmptyStateView(
                    icon: "book.pages",
                    title: "Write your first headline",
                    subtitle: "Your personal newsroom starts with one entry.",
                    actionTitle: "Create Entry",
                    onAction: { nav.showCapture = true }
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // MARK: - Stories Header
                        StoriesHeader(lifeAreaFilter: lifeAreaFilter)

                        // MARK: - Belief Carousel
                        if !beliefs.isEmpty && lifeAreaFilter == "all" {
                            BeliefCarousel(beliefs: beliefs)
                                .background(Color.understoodBeige)
                        }

                        // MARK: - Layer 1: Hero Story
                        if let hero = heroStory {
                            NavigationLink(destination: EntryDetailView(
                                entry: hero,
                                onDeleted: { Task { await loadEntries() } },
                                onFeaturedChanged: { Task { await loadEntries() } }
                            )) {
                                HeroStoryView(entry: hero)
                            }
                            .buttonStyle(.plain)
                        }

                        // MARK: - Layer 2: Story Carousel
                        if !carouselStories.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeaderView(title: "LATEST STORIES")
                                    .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(carouselStories) { entry in
                                            NavigationLink(destination: EntryDetailView(
                                                entry: entry,
                                                onDeleted: { Task { await loadEntries() } },
                                                onFeaturedChanged: { Task { await loadEntries() } }
                                            )) {
                                                StoryCarouselCard(entry: entry)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.top, 24)
                        }

                        // MARK: - Layer 3: Category + Pinned Layout
                        VStack(spacing: 24) {
                            // By Category
                            if !latestByCategory.isEmpty && lifeAreaFilter == "all" {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeaderView(title: "BY CATEGORY")
                                        .padding(.horizontal, 20)

                                    ForEach(latestByCategory, id: \.category) { item in
                                        NavigationLink(destination: EntryDetailView(
                                            entry: item.entry,
                                            onDeleted: { Task { await loadEntries() } },
                                            onFeaturedChanged: { Task { await loadEntries() } }
                                        )) {
                                            CategoryEntryCard(category: item.category, entry: item.entry)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }

                            // Recent Stories (full list after hero + carousel)
                            let remainingStories = Array(stories
                                .filter { $0.id != heroStory?.id }
                                .dropFirst(carouselStories.count)
                                .prefix(20))

                            if !remainingStories.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeaderView(title: "MORE STORIES")
                                        .padding(.horizontal, 20)

                                    ForEach(remainingStories) { entry in
                                        NavigationLink(destination: EntryDetailView(
                                            entry: entry,
                                            onDeleted: { Task { await loadEntries() } },
                                            onFeaturedChanged: { Task { await loadEntries() } }
                                        )) {
                                            EntryRow(entry: entry)
                                                .padding(.horizontal, 20)
                                        }
                                        .buttonStyle(.plain)

                                        Divider()
                                            .foregroundStyle(.borderLight)
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }

                            // Pinned sections
                            if lifeAreaFilter == "all" {
                                pinnedSection(title: "PINNED STORIES", entries: pinnedStories)
                                pinnedSection(title: "PINNED NOTES", entries: pinnedNotes)
                                pinnedSection(title: "PINNED ACTIONS", entries: pinnedActions)
                            }
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 100)
                    }
                }
                .refreshable {
                    await loadEntries()
                }
            }
        }
        .task {
            await loadEntries()
        }
    }

    @ViewBuilder
    private func pinnedSection(title: String, entries: [Entry]) -> some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeaderView(title: title, count: entries.count, accentColor: .understoodCrimson)
                    Spacer()
                }
                .padding(.horizontal, 20)

                ForEach(entries.prefix(5)) { entry in
                    NavigationLink(destination: EntryDetailView(
                        entry: entry,
                        onDeleted: { Task { await loadEntries() } }
                    )) {
                        PinnedEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Data

    private func loadEntries() async {
        isLoading = entries.isEmpty
        errorMessage = nil

        do {
            async let storiesTask = supabase.fetchEntries(limit: 50)
            async let beliefsTask = supabase.fetchBeliefs(limit: 6)
            async let featuredTask = supabase.fetchFeaturedEntry()
            async let pinnedTask = supabase.fetchPinnedEntries()

            let (fetchedEntries, fetchedBeliefs, fetchedFeatured, fetchedPinned) =
                try await (storiesTask, beliefsTask, featuredTask, pinnedTask)

            entries = fetchedEntries
            beliefs = fetchedBeliefs
            featuredEntry = fetchedFeatured
            pinnedEntries = fetchedPinned
            isLoading = false
        } catch {
            errorMessage = "Could not load entries.\n\(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Stories Header

struct StoriesHeader: View {
    let lifeAreaFilter: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if lifeAreaFilter != "all" {
                Text(lifeAreaFilter.uppercased())
                    .font(Typography.chipLabel)
                    .tracking(1.5)
                    .foregroundStyle(.understoodCrimson)
            }

            Text(todayDateString().uppercased())
                .font(Typography.date)
                .tracking(1)
                .foregroundStyle(.textMetadata)

            Text("Stories")
                .font(Typography.connectionHero)
                .foregroundStyle(.understoodCrimson)

            Text("Your personal newsroom")
                .font(Typography.subtitle)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .background(Color.understoodBeige)
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: Date())
    }
}

// MARK: - Layer 1: Hero Story

struct HeroStoryView: View {
    let entry: Entry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let poster = entry.posterWithFocalPoint {
                AsyncImage(url: URL(string: poster.url)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 400)
                            .frame(maxWidth: .infinity)
                            .clipped()
                    case .failure, .empty:
                        darkFallback
                    @unknown default:
                        darkFallback
                    }
                }
                .frame(height: 400)
                .frame(maxWidth: .infinity)
            } else {
                darkFallback
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7), .black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content overlay
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.category.uppercased())
                    .font(Typography.categoryLabel)
                    .tracking(1.5)
                    .foregroundStyle(.understoodCrimson)

                Text(entry.displayHeadline)
                    .font(Typography.hero)
                    .foregroundStyle(.white)
                    .lineLimit(3)

                HStack(spacing: 12) {
                    Text(EntryDateFormatter.format(entry.createdAt))
                        .font(Typography.date)
                        .foregroundStyle(.white.opacity(0.7))

                    if let mood = entry.mood, !mood.isEmpty {
                        Text(mood)
                            .font(Typography.info)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                HStack(spacing: 6) {
                    Text("Read Story")
                        .font(Typography.uiMedium)
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.understoodCrimson)
                .cornerRadius(6)
                .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(height: 400)
        .clipped()
    }

    private var darkFallback: some View {
        Rectangle()
            .fill(Color.black)
            .frame(height: 400)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Layer 2: Story Carousel Card

struct StoryCarouselCard: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let posterUrl = entry.posterImageUrl {
                AsyncImage(url: URL(string: posterUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 160)
                            .clipped()
                    case .failure, .empty:
                        Rectangle()
                            .fill(Color.surfaceSubtle)
                            .frame(width: 200, height: 160)
                    @unknown default:
                        EmptyView()
                    }
                }
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.surfaceSubtle)
                    .frame(width: 200, height: 160)
                    .cornerRadius(8)
                    .overlay {
                        Image(systemName: "book.pages")
                            .font(.system(size: 24))
                            .foregroundStyle(.textMuted)
                    }
            }

            Text(entry.category.uppercased())
                .font(Typography.categoryLabel)
                .tracking(1.5)
                .foregroundStyle(.understoodCrimson)

            Text(entry.displayHeadline)
                .font(Typography.cardHeadline)
                .foregroundStyle(.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(EntryDateFormatter.format(entry.createdAt))
                .font(Typography.date)
                .foregroundStyle(.textMetadata)
        }
        .frame(width: 200)
    }
}

// MARK: - Layer 3: Category Entry Card

struct CategoryEntryCard: View {
    let category: String
    let entry: Entry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(category.uppercased())
                    .font(Typography.categoryLabel)
                    .tracking(1.5)
                    .foregroundStyle(.understoodCrimson)

                Text(entry.displayHeadline)
                    .font(Typography.listHeadline)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(EntryDateFormatter.format(entry.createdAt))
                    .font(Typography.date)
                    .foregroundStyle(.textMetadata)
            }

            Spacer()

            if let posterUrl = entry.posterImageUrl {
                AsyncImage(url: URL(string: posterUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipped()
                    default:
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.surfaceSubtle)
                            .frame(width: 72, height: 72)
                    }
                }
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color.understoodCream)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.borderLight, lineWidth: 1)
        )
    }
}

// MARK: - Pinned Entry Row

struct PinnedEntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pin.fill")
                .font(.system(size: 10))
                .foregroundStyle(.understoodCrimson)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayHeadline)
                    .font(Typography.listHeadline)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(entry.category.uppercased())
                        .font(Typography.chipLabel)
                        .foregroundStyle(.understoodCrimson)

                    if let type = entry.entryType, type != "story" {
                        Text(type.capitalized)
                            .font(Typography.chipLabel)
                            .foregroundStyle(.textMetadata)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.surfaceChip)
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Belief Carousel

struct BeliefCarousel: View {
    let beliefs: [Entry]
    @State private var currentIndex = 0

    var body: some View {
        VStack(spacing: 0) {
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
            .frame(height: 160)

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
                .padding(.top, 8)
                .padding(.bottom, 12)
            }

            Rectangle()
                .fill(Color.understoodCrimson)
                .frame(height: 2)
        }
    }
}

// MARK: - Belief Quote Card

struct BeliefQuoteCard: View {
    let belief: Entry

    var body: some View {
        VStack(spacing: 12) {
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

// MARK: - Image Entry Row

struct ImageEntryRow: View {
    let entry: Entry
    let posterUrl: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(entry.category.uppercased())
                        .font(Typography.categoryLabel)
                        .tracking(1.5)
                        .foregroundStyle(.understoodCrimson)

                    if entry.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.understoodCrimson)
                    }
                }

                Text(entry.displayHeadline)
                    .font(Typography.listHeadline)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(3)

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

// MARK: - Text Entry Row

struct TextEntryRow: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(entry.category.uppercased())
                    .font(Typography.categoryLabel)
                    .tracking(1.5)
                    .foregroundStyle(.understoodCrimson)

                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.understoodCrimson)
                }
            }

            Text(entry.displayHeadline)
                .font(Typography.listHeadline)
                .foregroundStyle(.textPrimary)
                .lineLimit(2)

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
            .environment(AppNavigationState())
    }
}

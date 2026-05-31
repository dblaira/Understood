//
//  ContentView.swift
//  Understood
//
//  Three-layer editorial Stories view: Hero, Carousel, Category + Pinned layout
//

import SwiftUI
import Auth

// MARK: - Stories landing metrics

/// Centralized layout constants for the Stories hero + fold.
private enum StoriesLandingMetrics {
    /// Space below safe-area top for hero text now that the frozen top header is gone.
    static let heroContentOffsetBelowSafeArea: CGFloat = 36
    /// Space between the final hero line and the beige story section.
    static let heroContentBottomPadding: CGFloat = 24
    static let overlayHorizontalPadding: CGFloat = 20
    static let overlayTopPadding: CGFloat = 54
    static let overlayBottomPadding: CGFloat = 10
    static let overlayIconSpacing: CGFloat = 14
    static let latestStoriesSectionTopPadding: CGFloat = 24
}

struct ContentView: View {
    let supabase = SupabaseService.shared
    @Environment(AppNavigationState.self) private var nav

    @State private var entries: [Entry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
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
        Array(stories.prefix(10))
    }

    private var remainingStories: [Entry] {
        let carouselIDs = Set(carouselStories.map(\.id))
        return Array(stories.filter { !carouselIDs.contains($0.id) }.prefix(20))
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
                GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        // MARK: - Hero Story (full-bleed dark zone, content-height driven)
                        if let hero = heroStory {
                            NavigationLink(destination: EntryDetailView(
                                entry: hero,
                                onDeleted: { Task { await loadEntries() } },
                                onFeaturedChanged: { Task { await loadEntries() } }
                            )) {
                                HeroStoryView(
                                    entry: hero,
                                    scrollSafeAreaTop: geo.safeAreaInsets.top
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // MARK: - Light Zone
                        VStack(spacing: 0) {
                            // Story Carousel (first light content — matches IMG_1177 hero + LATEST STORIES peek)
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
                                .padding(.top, StoriesLandingMetrics.latestStoriesSectionTopPadding)
                                .padding(.bottom, 24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.understoodBeige)
                            }

                            // Category + Pinned Layout (BY CATEGORY omitted on landing — use menu / filters elsewhere)
                            VStack(spacing: 24) {
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
                }
                .ignoresSafeArea(edges: .top)
                .refreshable {
                    await loadEntries()
                }
                } // GeometryReader
            }
        }
        .task {
            await loadEntries()
        }
        .onAppear {
            guard !entries.isEmpty else { return }
            Task { await loadEntries() }
        }
        .onChange(of: nav.showCapture) { _, isPresented in
            guard !isPresented else { return }
            Task { await loadEntries() }
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
            async let featuredTask = supabase.fetchFeaturedEntry()
            async let pinnedTask = supabase.fetchPinnedEntries()

            let (fetchedEntries, fetchedFeatured, fetchedPinned) =
                try await (storiesTask, featuredTask, pinnedTask)

            entries = fetchedEntries
            featuredEntry = fetchedFeatured
            pinnedEntries = fetchedPinned
            isLoading = false
        } catch {
            errorMessage = "Could not load entries.\n\(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Hero Story (full-bleed editorial)

struct HeroStoryView: View {
    let entry: Entry
    /// Safe-area top from the parent `GeometryReader` (scroll content often reports `0` when `.ignoresSafeArea(edges: .top)`).
    var scrollSafeAreaTop: CGFloat = 0

    var body: some View {
        let topInset = max(scrollSafeAreaTop, 47)
            + StoriesLandingMetrics.heroContentOffsetBelowSafeArea

        VStack(alignment: .leading, spacing: 10) {
            Text(entry.category.uppercased())
                .font(Typography.categoryLabel)
                .tracking(1.5)
                .foregroundStyle(.understoodCrimson)
                .layoutPriority(1)

            Text(entry.displayHeadline)
                .font(.custom("PlayfairDisplay-Regular", size: 40))
                .foregroundStyle(.white)
                .lineLimit(nil)
                .lineSpacing(5)
                .minimumScaleFactor(0.82)
                .layoutPriority(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 8)

            if let subheading = entry.subheading, !subheading.isEmpty {
                Text(subheading)
                    .font(Typography.subtitle)
                    .italic()
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(3)
                    .layoutPriority(1)
            }

            Text(entry.contentPreview)
                .font(Typography.body)
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(2)
                .padding(.top, 2)
        }
        .padding(.horizontal, StoriesLandingMetrics.overlayHorizontalPadding)
        .padding(.top, topInset)
        .padding(.bottom, StoriesLandingMetrics.heroContentBottomPadding)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.understoodCrimson)
                .frame(height: 3)
        }
        .clipped()
    }
}

// MARK: - Layer 2: Story Carousel Card

struct StoryCarouselCard: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                if let poster = entry.posterWithFocalPoint {
                    AsyncImage(url: URL(string: poster.url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            imageFallback(systemName: "photo")
                        case .empty:
                            imageFallback(systemName: "photo")
                                .overlay(ProgressView())
                        @unknown default:
                            imageFallback(systemName: "photo")
                        }
                    }
                    .id(poster.url)
                } else {
                    imageFallback(systemName: "book.pages")
                }

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
            .frame(width: 200, height: 160)
            .clipped()
            .cornerRadius(8)

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

    private func imageFallback(systemName: String) -> some View {
        Rectangle()
            .fill(Color.surfaceSubtle)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 24))
                    .foregroundStyle(.textMuted)
            }
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
            .frame(height: 120)

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
                .id(posterUrl)

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

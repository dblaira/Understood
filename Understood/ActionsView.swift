//
//  ActionsView.swift
//  Understood
//
//  Grouped task management with due dates, completion, and editorial styling
//

import SwiftUI

struct ActionsView: View {
    let supabase = SupabaseService.shared
    var lifeAreaFilter: String = "all"

    @State private var allActions: [Entry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCompleted = false
    @State private var completionError: String?

    // MARK: - Grouped Actions

    private var filteredActions: [Entry] {
        guard lifeAreaFilter != "all" else { return allActions }
        return allActions.filter { $0.category.lowercased() == lifeAreaFilter.lowercased() }
    }

    private var groupedActions: ActionGroups {
        ActionGroups(actions: filteredActions)
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
                    Task { await loadActions() }
                }
                .padding()
            } else if allActions.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "Nothing on the horizon",
                    subtitle: "Use Compose to set an intention for today."
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // MARK: - Hero Header
                        ActionHeroHeader(groups: groupedActions)

                        VStack(spacing: 24) {
                            // Pinned
                            if !groupedActions.pinned.isEmpty {
                                actionSection(
                                    title: "PINNED",
                                    entries: groupedActions.pinned,
                                    accentColor: .understoodCrimson
                                )
                            }

                            // Overdue
                            if !groupedActions.overdue.isEmpty {
                                actionSection(
                                    title: "OVERDUE",
                                    entries: groupedActions.overdue,
                                    accentColor: .overdueRed
                                )
                            }

                            // Due Today
                            if !groupedActions.today.isEmpty {
                                actionSection(
                                    title: "DUE TODAY",
                                    entries: groupedActions.today,
                                    accentColor: .actionGreen
                                )
                            }

                            // Upcoming
                            if !groupedActions.upcoming.isEmpty {
                                actionSection(
                                    title: "UPCOMING",
                                    entries: groupedActions.upcoming,
                                    accentColor: .textMetadata
                                )
                            }

                            // Recently Completed (collapsible)
                            if !groupedActions.recentlyCompleted.isEmpty {
                                VStack(spacing: 12) {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showCompleted.toggle()
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            SectionHeaderView(
                                                title: "RECENTLY COMPLETED",
                                                count: groupedActions.recentlyCompleted.count,
                                                accentColor: .textMuted
                                            )
                                            Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.textMuted)
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    if showCompleted {
                                        ForEach(groupedActions.recentlyCompleted) { entry in
                                            NavigationLink(destination: EntryDetailView(
                                                entry: entry,
                                                onDeleted: { Task { await loadActions() } }
                                            )) {
                                                ActionCardView(
                                                    entry: entry,
                                                    onToggleComplete: { await toggleComplete(entry) }
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }
                }
                .refreshable {
                    await loadActions()
                }
            }
        }
        .task {
            await loadActions()
        }
        .alert("Error", isPresented: .init(
            get: { completionError != nil },
            set: { if !$0 { completionError = nil } }
        )) {
            Button("OK") { completionError = nil }
        } message: {
            Text(completionError ?? "")
        }
    }

    // MARK: - Section Builder

    private func actionSection(title: String, entries: [Entry], accentColor: Color) -> some View {
        VStack(spacing: 12) {
            SectionHeaderView(title: title, count: entries.count, accentColor: accentColor)

            ForEach(entries) { entry in
                NavigationLink(destination: EntryDetailView(
                    entry: entry,
                    onDeleted: { Task { await loadActions() } }
                )) {
                    ActionCardView(
                        entry: entry,
                        onToggleComplete: { await toggleComplete(entry) }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Data

    private func loadActions() async {
        isLoading = allActions.isEmpty
        errorMessage = nil

        do {
            allActions = try await supabase.fetchActions()
            isLoading = false
        } catch {
            errorMessage = "Could not load actions.\n\(error.localizedDescription)"
            isLoading = false
        }
    }

    private func toggleComplete(_ entry: Entry) async {
        let wasCompleted = entry.isCompleted
        let now = ISO8601DateFormatter().string(from: Date())

        // Optimistic update
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                if let idx = allActions.firstIndex(where: { $0.id == entry.id }) {
                    allActions[idx].completedAt = wasCompleted ? nil : now
                }
            }
        }

        do {
            try await supabase.toggleActionComplete(id: entry.id, currentlyCompleted: wasCompleted)
            Haptics.medium()
        } catch {
            // Revert on error
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if let idx = allActions.firstIndex(where: { $0.id == entry.id }) {
                        allActions[idx].completedAt = wasCompleted ? entry.completedAt : nil
                    }
                }
                completionError = "Failed to update: \(error.localizedDescription)"
            }
            Haptics.error()
        }
    }
}

// MARK: - Action Grouping Logic

struct ActionGroups {
    let pinned: [Entry]
    let overdue: [Entry]
    let today: [Entry]
    let upcoming: [Entry]
    let recentlyCompleted: [Entry]

    init(actions: [Entry]) {
        var pinned: [Entry] = []
        var overdue: [Entry] = []
        var today: [Entry] = []
        var upcoming: [Entry] = []
        var recentlyCompleted: [Entry] = []

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        for action in actions {
            // Completed within last 7 days -> recentlyCompleted
            if action.isCompleted {
                if let completed = action.parsedCompletedAt, completed >= sevenDaysAgo {
                    recentlyCompleted.append(action)
                }
                continue
            }

            // Pinned (and not completed) -> pinned, skip due date grouping
            if action.isPinned {
                pinned.append(action)
                continue
            }

            // Group by due date
            if let due = action.parsedDueDate {
                let dueStart = calendar.startOfDay(for: due)
                if dueStart < todayStart {
                    overdue.append(action)
                } else if calendar.isDateInToday(due) {
                    today.append(action)
                } else {
                    upcoming.append(action)
                }
            } else {
                upcoming.append(action)
            }
        }

        // Sort within groups
        self.pinned = pinned.sorted { ($0.pinnedAt ?? "") > ($1.pinnedAt ?? "") }
        self.overdue = overdue.sorted { ($0.dueDate ?? "") < ($1.dueDate ?? "") }
        self.today = today.sorted { $0.createdAt < $1.createdAt }
        self.upcoming = upcoming.sorted { a, b in
            switch (a.dueDate, b.dueDate) {
            case (nil, nil): return a.createdAt < b.createdAt
            case (nil, _): return false
            case (_, nil): return true
            case let (aDate?, bDate?): return aDate < bDate
            }
        }
        self.recentlyCompleted = recentlyCompleted.sorted { ($0.completedAt ?? "") > ($1.completedAt ?? "") }
    }

    var overdueCount: Int { overdue.count }
    var todayCount: Int { today.count }
    var totalActive: Int { pinned.count + overdue.count + today.count + upcoming.count }
}

// MARK: - Action Hero Header

struct ActionHeroHeader: View {
    let groups: ActionGroups

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(todayDateString().uppercased())
                .font(Typography.date)
                .tracking(1)
                .foregroundStyle(.textMetadata)

            Text("Today")
                .font(Typography.connectionHero)
                .foregroundStyle(.understoodCrimson)

            Text(tagline)
                .font(Typography.subtitle)
                .foregroundStyle(.textSecondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .background(Color.understoodBeige)
    }

    private var tagline: String {
        let hour = Calendar.current.component(.hour, from: Date())

        if groups.overdueCount > 0 && groups.todayCount == 0 {
            return "Clear the past to make room for what's next"
        }
        if groups.overdueCount == 0 && groups.todayCount == 0 {
            return "A clear slate. What matters most?"
        }
        if groups.todayCount == 1 {
            return "One intention. Full attention."
        }
        if groups.todayCount <= 3 {
            return "Focus on what moves the needle"
        }
        switch hour {
        case 5..<12: return "Morning clarity. Evening satisfaction."
        case 12..<17: return "The afternoon belongs to momentum"
        default: return "End the day with intention"
        }
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: Date())
    }
}

// MARK: - Action Card

struct ActionCardView: View {
    let entry: Entry
    let onToggleComplete: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Poster image (if entry has one)
            if let posterUrl = entry.posterImageUrl {
                AsyncImage(url: URL(string: posterUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipped()
                            .opacity(entry.isCompleted ? 0.5 : 1.0)
                    case .failure:
                        Rectangle()
                            .fill(Color.surfaceSubtle)
                            .frame(height: 160)
                    case .empty:
                        Rectangle()
                            .fill(Color.surfaceSubtle)
                            .frame(height: 160)
                            .overlay(ProgressView())
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .cornerRadius(8, corners: [.topLeft, .topRight])

                // Pin on image
                if entry.isPinned {
                    HStack {
                        Spacer()
                        Text("📌")
                            .font(.system(size: 14))
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)
                            .padding(8)
                    }
                    .offset(y: -160)
                    .frame(height: 0)
                }
            }

            // Card content
            HStack(alignment: .top, spacing: 12) {
                // Checkbox
                ActionCheckbox(
                    isCompleted: entry.isCompleted,
                    isOverdue: entry.isOverdue
                ) {
                    Task { await onToggleComplete() }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    // Headline
                    Text(entry.displayHeadline)
                        .font(Typography.listHeadline)
                        .foregroundStyle(entry.isCompleted ? .textMuted : .textPrimary)
                        .strikethrough(entry.isCompleted)
                        .lineLimit(2)

                    // Content preview
                    if !entry.contentPreview.isEmpty && entry.contentPreview != entry.displayHeadline {
                        Text(entry.contentPreview)
                            .font(Typography.info)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(2)
                    }

                    // Bottom row: category + due date
                    HStack(spacing: 8) {
                        Text(entry.category.uppercased())
                            .font(Typography.chipLabel)
                            .foregroundStyle(.textMetadata)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.surfaceChip)
                            .cornerRadius(4)

                        DueDateLabel(entry: entry)

                        if entry.isPinned && entry.posterImageUrl == nil {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.understoodCrimson)
                        }
                    }
                }
            }
            .padding(entry.posterImageUrl != nil ? 12 : 16)
        }
        .background(Color.understoodCream)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardBorderColor, lineWidth: 1)
        )
    }

    private var cardBorderColor: Color {
        if entry.isCompleted { return .borderLight }
        if entry.isOverdue { return .overdueRed.opacity(0.3) }
        return .borderLight
    }
}

// MARK: - Corner Radius Helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationStack {
        ActionsView(lifeAreaFilter: "all")
    }
}

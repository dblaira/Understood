//
//  EntryDetailView.swift
//  Understood
//
//  Created by Adam Blair on 2/25/26.
//

import SwiftUI

struct EntryDetailView: View {
    @State var entry: Entry
    let supabase = SupabaseService.shared

    @Environment(\.dismiss) private var dismiss
    @State private var selectedVersion: Int? = nil
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var currentImagePage = 0
    @State private var showLinkedCapture = false
    @State private var linkedEntryType: String = "action"
    @State private var starSpinning = false

    var onDeleted: (() -> Void)?
    var onFeaturedChanged: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Image Gallery

                if entry.hasImages {
                    ImageGalleryView(
                        images: entry.allImages,
                        currentPage: $currentImagePage
                    )
                    .padding(.horizontal, -24)
                }

                // MARK: - Action Status (for actions only)

                if entry.isAction {
                    ActionStatusBar(
                        entry: $entry,
                        onToggle: { await toggleComplete() }
                    )
                }

                // MARK: - Hero Section

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(entry.category.uppercased())
                            .font(Typography.sectionHeader)
                            .tracking(1.5)
                            .foregroundStyle(.understoodCrimson)

                        Spacer()

                        // Featured star (stories only)
                        if entry.isStory {
                            FeaturedStarButton(
                                isFeatured: entry.featured == true,
                                isSpinning: starSpinning,
                                onTap: { Task { await toggleFeatured() } }
                            )
                        }
                    }

                    Text(entry.displayHeadline)
                        .font(Typography.headline)
                        .foregroundStyle(entry.isCompleted ? .textMuted : .textPrimary)
                        .strikethrough(entry.isCompleted)

                    if let subheading = entry.subheading, !subheading.isEmpty {
                        Text(subheading)
                            .font(Typography.subheading)
                            .foregroundStyle(.textSecondary)
                    }

                    HStack(spacing: 12) {
                        Text(formatDate(entry.createdAt))
                            .font(Typography.date)
                            .foregroundStyle(.textMetadata)

                        if let mood = entry.mood, !mood.isEmpty {
                            Text(mood)
                                .font(Typography.uiMedium)
                                .foregroundStyle(.textSecondary)
                        }

                        if let metadata = entry.metadata {
                            if let energy = metadata.energy {
                                MetadataChip(label: energy)
                            }
                            if let environment = metadata.environment {
                                MetadataChip(label: environment)
                            }
                        }
                    }

                    if entry.isAction {
                        DueDateLabel(entry: entry)
                    }
                }

                Divider()
                    .foregroundStyle(.borderMedium)

                // MARK: - Content Body

                Text(stripHTML(entry.content))
                    .font(Typography.body)
                    .lineSpacing(6)
                    .foregroundStyle(Color.textPrimary.opacity(0.9))

                // MARK: - AI Versions

                if let versions = entry.versions, !versions.isEmpty {
                    Divider()
                        .foregroundStyle(.borderMedium)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("AI PERSPECTIVES")
                            .font(Typography.sectionHeader)
                            .tracking(1.5)
                            .foregroundStyle(.textMuted)

                        // Version tabs
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(versions.enumerated()), id: \.offset) { index, version in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedVersion = selectedVersion == index ? nil : index
                                        }
                                    } label: {
                                        Text(version.name)
                                            .font(Typography.uiMedium)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedVersion == index ? Color.black : Color.surfaceSubtle)
                                            .foregroundStyle(selectedVersion == index ? Color.white : Color.textSecondary)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }

                        // Selected version content — styled per voice
                        if let selected = selectedVersion, selected < versions.count {
                            let version = versions[selected]
                            let voiceName = version.name.lowercased()
                            let bodyText = stripHTML(version.body ?? version.content)

                            if voiceName.contains("literary") {
                                LiteraryVersionView(title: version.title, bodyText: bodyText)
                                    .transition(.opacity)
                            } else if voiceName.contains("news") {
                                NewsVersionView(title: version.title, bodyText: bodyText)
                                    .transition(.opacity)
                            } else if voiceName.contains("poetic") || voiceName.contains("poet") {
                                PoeticVersionView(title: version.title, bodyText: bodyText)
                                    .transition(.opacity)
                            } else {
                                HumorousVersionView(title: version.title, bodyText: bodyText)
                                    .transition(.opacity)
                            }
                        }
                    }
                } else if entry.generatingVersions == true {
                    // Loading state for versions
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Generating perspectives...")
                            .font(Typography.uiMedium)
                            .foregroundStyle(.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }

                // MARK: - Context

                if let metadata = entry.metadata {
                    if metadata.activity != nil || metadata.trigger != nil || metadata.location != nil {
                        Divider()
                            .foregroundStyle(.borderMedium)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("CONTEXT")
                                .font(Typography.sectionHeader)
                                .tracking(1.5)
                                .foregroundStyle(.textMuted)

                            HStack(spacing: 8) {
                                if let activity = metadata.activity {
                                    MetadataChip(label: activity)
                                }
                                if let trigger = metadata.trigger {
                                    MetadataChip(label: trigger)
                                }
                                if let location = metadata.location, let city = location.city {
                                    MetadataChip(label: city)
                                }
                            }
                        }
                    }
                }

                // MARK: - Water Cycle

                Divider()
                    .foregroundStyle(.borderMedium)

                WaterCycleButtons(entry: entry) { entryType in
                    linkedEntryType = entryType
                    showLinkedCapture = true
                }

                // MARK: - Delete

                Divider()
                    .foregroundStyle(.borderMedium)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Entry")
                    }
                    .font(Typography.uiMedium)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .cornerRadius(8)
                }
                .disabled(isDeleting)
            }
            .padding(24)
        }
        .background(Color.understoodCream.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Entry", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteEntry() }
            }
        } message: {
            Text("This will permanently delete this entry and cannot be undone.")
        }
        .sheet(isPresented: $showLinkedCapture) {
            CaptureView(
                sourceEntryId: entry.id,
                entryType: linkedEntryType,
                prefillCategory: entry.category,
                onSaved: {}
            )
        }
    }

    // MARK: - Actions

    private func deleteEntry() async {
        isDeleting = true
        do {
            try await supabase.deleteEntry(id: entry.id)
            await MainActor.run {
                onDeleted?()
                dismiss()
            }
        } catch {
            isDeleting = false
            print("Delete error: \(error)")
        }
    }

    private func toggleFeatured() async {
        let wasFeatured = entry.featured == true

        // Optimistic update
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                entry.featured = !wasFeatured
            }
            if !wasFeatured {
                starSpinning = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    starSpinning = false
                }
            }
        }

        do {
            try await supabase.toggleFeatured(entryId: entry.id, currentlyFeatured: wasFeatured)
            Haptics.medium()
            onFeaturedChanged?()
        } catch {
            // Revert on error
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    entry.featured = wasFeatured
                }
            }
            Haptics.error()
        }
    }

    private func toggleComplete() async {
        let wasCompleted = entry.isCompleted
        let now = ISO8601DateFormatter().string(from: Date())

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                entry.completedAt = wasCompleted ? nil : now
            }
        }

        do {
            try await supabase.toggleActionComplete(id: entry.id, currentlyCompleted: wasCompleted)
            Haptics.medium()
        } catch {
            await MainActor.run {
                entry.completedAt = wasCompleted ? entry.completedAt : nil
            }
            Haptics.error()
        }
    }

    // MARK: - Formatting

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return formatFull(date)
        }
        return formatFull(date)
    }

    private func formatFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }

    /// Strip HTML tags and convert to readable plain text
    private func stripHTML(_ html: String) -> String {
        var text = html
        let blockTags = ["</p>", "</h1>", "</h2>", "</h3>", "</h4>", "</li>", "</blockquote>", "<br>", "<br/>", "<br />"]
        for tag in blockTags {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }
        text = text.replacingOccurrences(of: "<li>", with: "\n- ", options: .caseInsensitive)
        while let range = text.range(of: "<[^>]+>", options: .regularExpression) {
            text = text.replacingCharacters(in: range, with: "")
        }
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Featured Star Button

struct FeaturedStarButton: View {
    let isFeatured: Bool
    let isSpinning: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: isFeatured ? "star.fill" : "star")
                .font(.system(size: 20))
                .foregroundStyle(isFeatured ? .understoodCrimson : .textMuted)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(
                    isSpinning ? .easeInOut(duration: 0.6) : .default,
                    value: isSpinning
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFeatured
            ? "This story is featured on your landing page. Tap to remove."
            : "Feature this story on your landing page"
        )
    }
}

// MARK: - Action Status Bar

struct ActionStatusBar: View {
    @Binding var entry: Entry
    let onToggle: () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            ActionCheckbox(
                isCompleted: entry.isCompleted,
                isOverdue: entry.isOverdue
            ) {
                Task { await onToggle() }
            }

            Text(entry.isCompleted ? "Completed" : "Mark Complete")
                .font(Typography.uiMedium)
                .fontWeight(.semibold)
                .foregroundStyle(entry.isCompleted ? .actionGreen : .textSecondary)

            Spacer()

            if entry.isCompleted {
                Button {
                    Task { await onToggle() }
                } label: {
                    Text("Undo")
                        .font(Typography.uiMedium)
                        .foregroundStyle(.textMetadata)
                }
            }
        }
        .padding(12)
        .background(entry.isCompleted ? Color.actionGreen.opacity(0.08) : Color.surfaceSubtle)
        .cornerRadius(8)
    }
}

// MARK: - Water Cycle Buttons

struct WaterCycleButtons: View {
    let entry: Entry
    let onCreateLinked: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WATER CYCLE")
                .font(Typography.sectionHeader)
                .tracking(1.5)
                .foregroundStyle(.textMuted)

            if entry.isStory {
                waterCycleButton(
                    icon: "bolt.circle.fill",
                    title: "Act on This",
                    subtitle: "Create an action from this story",
                    entryType: "action"
                )
            }

            if entry.isAction && !entry.isCompleted {
                waterCycleButton(
                    icon: "note.text.badge.plus",
                    title: "Collect Notes",
                    subtitle: "Capture notes while working on this",
                    entryType: "note"
                )
            }

            if entry.isAction && entry.isCompleted {
                waterCycleButton(
                    icon: "sparkles",
                    title: "What Changed?",
                    subtitle: "Reflect on what completing this meant",
                    entryType: "story"
                )
            }

            if entry.isNote {
                waterCycleButton(
                    icon: "bolt.circle.fill",
                    title: "Act on This",
                    subtitle: "Turn this note into an action",
                    entryType: "action"
                )
            }
        }
    }

    private func waterCycleButton(icon: String, title: String, subtitle: String, entryType: String) -> some View {
        Button {
            Haptics.light()
            onCreateLinked(entryType)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.understoodCrimson)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.uiMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(.textPrimary)
                    Text(subtitle)
                        .font(Typography.small)
                        .foregroundStyle(.textMetadata)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.textMuted)
            }
            .padding(12)
            .background(Color.surfaceSubtle)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Literary Version (Cream, Georgia serif, drop cap, decorative separator)

struct LiteraryVersionView: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section label
            Text("PERSONAL ESSAY")
                .font(Typography.chipLabel)
                .tracking(2)
                .foregroundStyle(.voiceLiteraryTitle)
                .frame(maxWidth: .infinity, alignment: .center)

            // Body with drop cap (letter floats left, text wraps below)
            if let firstChar = bodyText.first {
                DropCapText(
                    dropCap: String(firstChar),
                    remainingText: String(bodyText.dropFirst())
                )
            } else {
                Text(bodyText)
                    .font(.custom("Georgia", size: 17))
                    .lineSpacing(8)
                    .foregroundStyle(.voiceLiteraryText)
            }

            // Decorative separator
            Text("❦")
                .font(.system(size: 20))
                .foregroundStyle(.textMuted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 12)
        }
        .padding(20)
        .background(Color.voiceLiteraryBg)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Drop Cap (CSS float-left simulation)

/// Renders a large first letter with body text wrapping below it, like Vanity Fair / literary magazines.
/// The drop cap sits in the top-left and the first ~3 lines indent around it, then text continues full-width.
struct DropCapText: View {
    let dropCap: String
    let remainingText: String

    /// Drop cap metrics — sized to span exactly 3 body-text lines
    /// Body line height ≈ 25pt (17pt Georgia + 8pt lineSpacing), so 3 lines ≈ 75pt
    private let capSize: CGFloat = 82
    private let capWidth: CGFloat = 58
    private let capLineHeight: CGFloat = 82

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Drop cap letter — offset up to eat the font's built-in ascender space
            Text(dropCap)
                .font(.custom("Georgia-Bold", size: capSize))
                .foregroundStyle(.voiceLiteraryDropCap)
                .frame(width: capWidth, height: capLineHeight, alignment: .topLeading)
                .clipped()
                .offset(y: -12)

            // Body text with indented first lines wrapping around the cap
            VStack(alignment: .leading, spacing: 0) {
                // Indented portion (wraps beside the drop cap)
                Text(remainingText)
                    .font(.custom("Georgia", size: 17))
                    .lineSpacing(8)
                    .foregroundStyle(.voiceLiteraryText)
                    .padding(.leading, capWidth + 6)
                    .lineLimit(3)

                // Remaining text (full width, below the drop cap)
                let indentedChars = estimateIndentedCharCount()
                if remainingText.count > indentedChars {
                    Text(String(remainingText.dropFirst(indentedChars)))
                        .font(.custom("Georgia", size: 17))
                        .lineSpacing(8)
                        .foregroundStyle(.voiceLiteraryText)
                        .padding(.top, 2)
                }
            }
        }
    }

    /// Estimate how many characters fit in ~3 indented lines beside the wider drop cap
    private func estimateIndentedCharCount() -> Int {
        // Wider cap (58pt + 6pt gap = 64pt indent) leaves ~28 chars per line at 17pt Georgia
        // 3 indented lines × ~28 chars = ~84 chars
        min(remainingText.count, 84)
    }
}

// MARK: - News Version (Gray, bold Playfair headline, double border)

struct NewsVersionView: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section label
            Text("SPECIAL REPORT")
                .font(Typography.chipLabel)
                .tracking(2)
                .foregroundStyle(.voiceNewsTitle)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 12)

            // Headline with double border
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
                Text(title.uppercased())
                    .font(Typography.sectionTitle)
                    .fontWeight(.black)
                    .multilineTextAlignment(.center)
                    .tracking(-0.3)
                    .foregroundStyle(.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 0.5)
                    .padding(.bottom, 1)
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
            }
            .padding(.bottom, 16)

            // Body text
            Text(bodyText)
                .font(.custom("Georgia", size: 15))
                .lineSpacing(5)
                .foregroundStyle(.textPrimary)
        }
        .padding(20)
        .background(Color.voiceNewsBg)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderLight, lineWidth: 1)
        )
    }
}

// MARK: - Poetic Version (Parchment, italic centered Georgia, airy spacing)

struct PoeticVersionView: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(spacing: 16) {
            // Section label
            Text("VERSE")
                .font(Typography.chipLabel)
                .tracking(3)
                .foregroundStyle(.voicePoeticTitle)

            // Body — italic, centered, airy
            Text(bodyText)
                .font(.custom("Georgia", size: 17))
                .italic()
                .multilineTextAlignment(.center)
                .lineSpacing(12)
                .tracking(0.3)
                .foregroundStyle(.voicePoeticText)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .background(Color.voicePoeticBg)
        .cornerRadius(12)
        .shadow(color: Color(red: 0.545, green: 0.271, blue: 0.075).opacity(0.08), radius: 16, x: 0, y: 4)
    }
}

// MARK: - Humorous / Fallback Version (Light green, green left border)

struct HumorousVersionView: View {
    let title: String
    let bodyText: String

    var body: some View {
        HStack(spacing: 0) {
            // Green left border
            Rectangle()
                .fill(Color.voiceHumorousBorder)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(Typography.cardHeadline)
                    .foregroundStyle(.voiceHumorousTitle)

                Text(bodyText)
                    .font(Typography.versionBody)
                    .lineSpacing(6)
                    .foregroundStyle(.voiceHumorousText)
            }
            .padding(16)
        }
        .background(Color.voiceHumorousBg)
        .cornerRadius(12)
    }
}

// MARK: - Image Gallery

struct ImageGalleryView: View {
    let images: [EntryImage]
    @Binding var currentPage: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, entryImage in
                    AsyncImage(url: URL(string: entryImage.url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 280)
                                .clipped()
                        case .failure:
                            ZStack {
                                Color.surfaceSubtle
                                VStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.textMuted)
                                    Text("Failed to load")
                                        .font(Typography.small)
                                        .foregroundStyle(.textMuted)
                                }
                            }
                            .frame(height: 280)
                        case .empty:
                            ZStack {
                                Color.surfaceSubtle
                                ProgressView()
                                    .scaleEffect(1.2)
                            }
                            .frame(height: 280)
                        @unknown default:
                            Color.surfaceSubtle
                                .frame(height: 280)
                        }
                    }
                    .tag(index)
                }
            }
            .frame(height: 280)
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Page indicator (only for multi-image entries)
            if images.count > 1 {
                HStack(spacing: 0) {
                    Spacer()
                    Text("\(currentPage + 1) / \(images.count)")
                        .font(Typography.uiMedium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .cornerRadius(12)
                        .padding(12)
                }
            }
        }
    }
}

// MARK: - Metadata Chip

struct MetadataChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(Typography.chipLabel)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.surfaceChip)
            .cornerRadius(12)
            .foregroundStyle(.textSecondary)
    }
}

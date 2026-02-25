//
//  EntryDetailView.swift
//  Understood
//
//  Created by Adam Blair on 2/25/26.
//

import SwiftUI

struct EntryDetailView: View {
    let entry: Entry
    @State private var selectedVersion: Int? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Hero Section

                VStack(alignment: .leading, spacing: 12) {
                    // Category
                    Text(entry.category.uppercased())
                        .font(Typography.sectionHeader)
                        .tracking(1.5)
                        .foregroundStyle(.understoodCrimson)

                    // Headline
                    Text(entry.headline)
                        .font(Typography.headline)
                        .foregroundStyle(.textPrimary)

                    // Subheading
                    if let subheading = entry.subheading, !subheading.isEmpty {
                        Text(subheading)
                            .font(Typography.subheading)
                            .foregroundStyle(.textSecondary)
                    }

                    // Metadata row
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
                }

                Divider()
                    .foregroundStyle(.borderMedium)

                // MARK: - Content Body

                Text(stripHTML(entry.content))
                    .font(Typography.body)
                    .lineSpacing(6)
                    .foregroundStyle(.textPrimary.opacity(0.9))

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
                                            .background(selectedVersion == index ? Color.black : .surfaceSubtle)
                                            .foregroundStyle(selectedVersion == index ? .white : .textSecondary)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }

                        // Selected version content
                        if let selected = selectedVersion, selected < versions.count {
                            let version = versions[selected]

                            VStack(alignment: .leading, spacing: 12) {
                                Text(version.title)
                                    .font(Typography.cardHeadline)
                                    .foregroundStyle(.textPrimary)

                                Text(stripHTML(version.body ?? version.content))
                                    .font(Typography.versionBody)
                                    .lineSpacing(5)
                                    .foregroundStyle(.textPrimary.opacity(0.85))
                            }
                            .padding(16)
                            .background(Color.surfaceSubtle)
                            .cornerRadius(12)
                            .transition(.opacity)
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
            }
            .padding(24)
        }
        .background(Color.understoodCream.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

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
        // Replace block-level tags with newlines
        let blockTags = ["</p>", "</h1>", "</h2>", "</h3>", "</h4>", "</li>", "</blockquote>", "<br>", "<br/>", "<br />"]
        for tag in blockTags {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }
        // Add bullet for list items
        text = text.replacingOccurrences(of: "<li>", with: "\n- ", options: .caseInsensitive)
        // Remove all remaining HTML tags
        while let range = text.range(of: "<[^>]+>", options: .regularExpression) {
            text = text.replacingCharacters(in: range, with: "")
        }
        // Decode common HTML entities
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        // Clean up excess whitespace
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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

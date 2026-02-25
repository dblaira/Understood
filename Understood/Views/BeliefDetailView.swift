//
//  BeliefDetailView.swift
//  Understood
//
//  Phase 4: Single belief with connected entries timeline
//

import SwiftUI

struct BeliefDetailView: View {
    let belief: Entry
    let supabase = SupabaseService.shared

    @State private var connectedEntries: [Entry] = []
    @State private var isLoadingEntries = true
    @State private var actionFeedback: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Hero Section

                VStack(alignment: .leading, spacing: 16) {
                    // Type badge
                    if let connectionType = belief.connectionType {
                        HStack(spacing: 6) {
                            Image(systemName: iconForType(connectionType))
                                .font(.system(size: 12))
                            Text(connectionType.replacingOccurrences(of: "_", with: " ").uppercased())
                                .font(Typography.sectionHeader)
                                .tracking(1.5)
                        }
                        .foregroundStyle(.understoodCrimson)
                    }

                    // Belief text — hero treatment
                    Text(belief.headline)
                        .font(Typography.headline)
                        .foregroundStyle(.textPrimary)
                        .lineSpacing(4)

                    // Subheading
                    if let subheading = belief.subheading, !subheading.isEmpty {
                        Text(subheading)
                            .font(Typography.subheading)
                            .foregroundStyle(.textSecondary)
                    }
                }

                // MARK: - Stats Row

                HStack(spacing: 24) {
                    StatItem(label: "Surfaced", value: "—")
                    StatItem(label: "Landed", value: "—")
                    StatItem(
                        label: "Last connected",
                        value: formatRelativeDate(belief.createdAt)
                    )
                }
                .padding(16)
                .background(Color.surfaceSubtle)
                .cornerRadius(12)

                // MARK: - Actions

                HStack(spacing: 12) {
                    Button {
                        Task { await sendResponse("landed") }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: actionFeedback == "landed" ? "checkmark" : "hand.thumbsup.fill")
                                .font(.system(size: 14))
                            Text(actionFeedback == "landed" ? "Landed!" : "This Landed")
                                .font(Typography.uiMedium)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(actionFeedback == "landed" ? Color.understoodCrimson : Color.textPrimary)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                    }
                    .disabled(actionFeedback != nil)

                    Button {
                        Task { await sendResponse("snooze") }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: actionFeedback == "snooze" ? "checkmark" : "clock")
                                .font(.system(size: 14))
                            Text(actionFeedback == "snooze" ? "Snoozed" : "Not Now")
                                .font(Typography.uiMedium)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.surfaceSubtle)
                        .foregroundStyle(.textPrimary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.borderLight, lineWidth: 1)
                        )
                    }
                    .disabled(actionFeedback != nil)
                }

                Divider()
                    .foregroundStyle(.borderMedium)

                // MARK: - Connected Entries Timeline

                VStack(alignment: .leading, spacing: 16) {
                    Text("CONNECTED ENTRIES")
                        .font(Typography.sectionHeader)
                        .tracking(1.5)
                        .foregroundStyle(.textMuted)

                    if isLoadingEntries {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Loading connections...")
                                .font(Typography.small)
                                .foregroundStyle(.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else if connectedEntries.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.system(size: 24))
                                .foregroundStyle(.textMuted)
                            Text("No connected entries yet")
                                .font(Typography.subtitle)
                                .foregroundStyle(.textSecondary)
                            Text("Entries that relate to this belief will appear here")
                                .font(Typography.small)
                                .foregroundStyle(.textMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(connectedEntries) { entry in
                            NavigationLink(destination: EntryDetailView(entry: entry)) {
                                ConnectedEntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // MARK: - Belief Content

                if !belief.content.isEmpty {
                    Divider()
                        .foregroundStyle(.borderMedium)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("ORIGINAL CAPTURE")
                            .font(Typography.sectionHeader)
                            .tracking(1.5)
                            .foregroundStyle(.textMuted)

                        Text(stripHTML(belief.content))
                            .font(Typography.body)
                            .lineSpacing(6)
                            .foregroundStyle(Color.textPrimary.opacity(0.9))
                    }
                }

                Spacer().frame(height: 40)
            }
            .padding(24)
        }
        .background(Color.understoodCream.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadConnectedEntries()
        }
    }

    // MARK: - Actions

    private func sendResponse(_ action: String) async {
        guard let url = URL(string: "\(SupabaseService.apiBaseURL)/api/notifications/response") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "connectionId": belief.id,
            "action": action
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        actionFeedback = action
                    }
                }
            }
        } catch {
            print("Belief response error: \(error)")
        }
    }

    // MARK: - Data Loading

    private func loadConnectedEntries() async {
        do {
            connectedEntries = try await supabase.fetchConnectedEntries(beliefId: belief.id)
            isLoadingEntries = false
        } catch {
            isLoadingEntries = false
            print("Error loading connected entries: \(error)")
        }
    }

    // MARK: - Helpers

    private func iconForType(_ type: String) -> String {
        switch type {
        case "identity_anchor": return "shield.fill"
        case "pattern_interrupt": return "arrow.triangle.2.circlepath"
        case "validated_principle": return "checkmark.seal.fill"
        case "process_anchor": return "list.bullet.rectangle.fill"
        default: return "lightbulb.fill"
        }
    }

    private func formatRelativeDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return relativeString(date)
        }
        return relativeString(date)
    }

    private func relativeString(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            if days < 7 {
                return "\(days)d ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        }
    }

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

// MARK: - Stat Item

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Typography.uiMedium)
                .fontWeight(.semibold)
                .foregroundStyle(.textPrimary)
            Text(label)
                .font(Typography.chipLabel)
                .foregroundStyle(.textMuted)
        }
    }
}

// MARK: - Connected Entry Row

struct ConnectedEntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline dot
            VStack {
                Circle()
                    .fill(Color.understoodCrimson)
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(Color.borderLight)
                    .frame(width: 1)
            }
            .frame(width: 8)

            // Entry content
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.headline)
                    .font(Typography.uiMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)

                Text(stripHTML(entry.content))
                    .font(Typography.small)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(formatDate(entry.createdAt))
                        .font(Typography.chipLabel)
                        .foregroundStyle(.textMetadata)

                    if let mood = entry.mood, !mood.isEmpty {
                        Text(mood)
                            .font(Typography.chipLabel)
                            .foregroundStyle(.textSecondary)
                    }

                    if let metadata = entry.metadata {
                        if let energy = metadata.energy {
                            MetadataChip(label: energy)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else { return dateString }
            return formatShort(date)
        }
        return formatShort(date)
    }

    private func formatShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func stripHTML(_ html: String) -> String {
        var text = html
        while let range = text.range(of: "<[^>]+>", options: .regularExpression) {
            text = text.replacingCharacters(in: range, with: "")
        }
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

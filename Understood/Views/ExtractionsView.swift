//
//  ExtractionsView.swift
//  Understood
//
//  Morning review: structured extractions grouped by category
//

import SwiftUI

struct ExtractionsView: View {
    let supabase = SupabaseService.shared

    @State private var extractions: [Extraction] = []
    @State private var batches: [(batchId: String, createdAt: String, count: Int)] = []
    @State private var activeBatchId: String?
    @State private var isLoading = true
    @State private var isRunning = false
    @State private var runResult: ExtractionBatchResponse?
    @State private var errorMessage: String?
    @State private var expandedCategories: Set<String> = []

    /// Extractions grouped by category
    private var grouped: [(category: String, items: [Extraction])] {
        var map: [String: [Extraction]] = [:]
        for ext in extractions {
            map[ext.category, default: []].append(ext)
        }
        return map.sorted { $0.key < $1.key }.map { (category: $0.key, items: $0.value) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.understoodCream
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading extractions...")
                        .foregroundStyle(.textSecondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Summary banner
                            summaryBanner

                            // Run result feedback
                            if let result = runResult {
                                resultBanner(result)
                            }

                            // Error
                            if let error = errorMessage {
                                errorBanner(error)
                            }

                            // Empty state
                            if extractions.isEmpty && !isRunning {
                                emptyState
                            }

                            // Running state
                            if isRunning && extractions.isEmpty {
                                runningState
                            }

                            // Category groups
                            ForEach(grouped, id: \.category) { group in
                                categorySection(group.category, items: group.items)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Extractions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await runExtraction() }
                    } label: {
                        if isRunning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Extract")
                                .font(Typography.uiMedium)
                                .foregroundStyle(.understoodCrimson)
                        }
                    }
                    .disabled(isRunning)
                }
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - Summary Banner

    private var summaryBanner: some View {
        VStack(spacing: 0) {
            if !extractions.isEmpty {
                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(extractions.count)")
                            .font(Typography.sectionTitle)
                            .foregroundStyle(.textPrimary)
                        Text("EXTRACTIONS")
                            .font(Typography.sectionHeader)
                            .tracking(1.5)
                            .foregroundStyle(.textMuted)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(grouped.count)")
                            .font(Typography.sectionTitle)
                            .foregroundStyle(.textPrimary)
                        Text("CATEGORIES")
                            .font(Typography.sectionHeader)
                            .tracking(1.5)
                            .foregroundStyle(.textMuted)
                    }

                    Spacer()

                    // Expand / Collapse
                    VStack(spacing: 4) {
                        Button("Expand All") {
                            expandedCategories = Set(grouped.map(\.category))
                        }
                        .font(Typography.chipLabel)
                        .foregroundStyle(.understoodCrimson)

                        Button("Collapse") {
                            expandedCategories = []
                        }
                        .font(Typography.chipLabel)
                        .foregroundStyle(.textMuted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.understoodBeige)
            }

            // Batch picker
            if batches.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(batches, id: \.batchId) { batch in
                            Button {
                                Task { await loadBatch(batch.batchId) }
                            } label: {
                                Text("\(formatDate(batch.createdAt)) · \(batch.count)")
                                    .font(Typography.chipLabel)
                                    .foregroundStyle(batch.batchId == activeBatchId ? .white : .textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(batch.batchId == activeBatchId ? Color.textPrimary : Color.surfaceSubtle)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: - Category Section

    private func categorySection(_ category: String, items: [Extraction]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — tap to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if expandedCategories.contains(category) {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
            } label: {
                HStack {
                    Text(category.uppercased())
                        .font(Typography.categoryLabel)
                        .tracking(1.5)
                        .foregroundStyle(.understoodCrimson)

                    Text("\(items.count)")
                        .font(Typography.chipLabel)
                        .foregroundStyle(.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.surfaceSubtle)
                        .clipShape(Capsule())

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.textMuted)
                        .rotationEffect(.degrees(expandedCategories.contains(category) ? 180 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }

            if expandedCategories.contains(category) {
                VStack(spacing: 8) {
                    ForEach(items) { ext in
                        extractionCard(ext)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            Divider()
                .foregroundStyle(.borderLight)
        }
    }

    // MARK: - Extraction Card

    private func extractionCard(_ ext: Extraction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Confidence badge
            HStack(spacing: 6) {
                Circle()
                    .fill(confidenceColor(ext.confidence))
                    .frame(width: 6, height: 6)

                Text("\(confidenceLabel(ext.confidence)) (\(String(format: "%.1f", ext.confidence)))")
                    .font(Typography.chipLabel)
                    .foregroundStyle(confidenceColor(ext.confidence))
            }

            // Key-value data
            let sortedData = ext.data.sorted { $0.key < $1.key }
            FlowLayout(spacing: 12) {
                ForEach(sortedData, id: \.key) { key, value in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(key)
                            .font(Typography.chipLabel)
                            .foregroundStyle(.textMuted)
                        Text(value.displayString)
                            .font(Typography.body)
                            .foregroundStyle(.textPrimary)
                    }
                }
            }

            // Source text
            if let source = ext.sourceText, !source.isEmpty {
                Text(""\(source)"")
                    .font(Typography.info)
                    .foregroundStyle(.textSecondary)
                    .italic()
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            Rectangle()
                .fill(confidenceColor(ext.confidence))
                .frame(width: 3),
            alignment: .leading
        )
        .background(Color.white)
    }

    // MARK: - States

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.textSecondary)
            Text("No extractions yet")
                .font(Typography.cardHeadline)
                .foregroundStyle(.textPrimary)
            Text("Tap Extract to process your journal entries and discover structured patterns.")
                .font(Typography.subtitle)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var runningState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            ProgressView()
                .controlSize(.large)
                .tint(.understoodCrimson)
            Text("Extracting...")
                .font(Typography.cardHeadline)
                .foregroundStyle(.textPrimary)
            Text("Processing entries through Claude Opus. This may take a minute.")
                .font(Typography.info)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func resultBanner(_ result: ExtractionBatchResponse) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Extraction complete")
                .font(Typography.uiMedium)
                .foregroundStyle(.textPrimary)
            Text("\(result.totalEntriesProcessed) entries processed · \(result.totalExtractionsFound) extractions · \(result.categoriesFound.count) categories")
                .font(Typography.info)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.green.opacity(0.08))
        .overlay(
            Rectangle().fill(Color.green.opacity(0.4)).frame(height: 1),
            alignment: .bottom
        )
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(Typography.info)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.red.opacity(0.06))
    }

    // MARK: - Helpers

    private func confidenceLabel(_ c: Double) -> String {
        if c >= 0.9 { return "explicit" }
        if c >= 0.6 { return "implied" }
        return "inferred"
    }

    private func confidenceColor(_ c: Double) -> Color {
        if c >= 0.9 { return .green }
        if c >= 0.6 { return .orange }
        return .gray
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: iso) else { return iso }
            return shortDate(date)
        }
        return shortDate(date)
    }

    private func shortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        do {
            batches = try await supabase.fetchExtractionBatches()
            if let first = batches.first {
                activeBatchId = first.batchId
                extractions = try await supabase.fetchExtractions(batchId: first.batchId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadBatch(_ batchId: String) async {
        activeBatchId = batchId
        expandedCategories = []
        do {
            extractions = try await supabase.fetchExtractions(batchId: batchId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runExtraction() async {
        isRunning = true
        errorMessage = nil
        runResult = nil
        do {
            let result = try await supabase.runExtraction()
            runResult = result
            if result.batchId != nil {
                await loadData()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isRunning = false
    }
}

// MARK: - Flow Layout (wrapping horizontal layout for key-value pairs)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposableSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposableSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposableSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxHeight = max(maxHeight, y + rowHeight)
        }

        return (CGSize(width: maxWidth, height: maxHeight), positions)
    }
}

#Preview {
    ExtractionsView()
}

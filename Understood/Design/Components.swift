//
//  Components.swift
//  Understood
//
//  Reusable design system components
//

import SwiftUI

// MARK: - Skeleton Loading

struct SkeletonEntryRow: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.surfaceSubtle)
                .frame(width: 70, height: 12)

            // Headline
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.surfaceSubtle)
                .frame(height: 20)

            // Subheading
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.surfaceSubtle)
                .frame(width: 200, height: 14)

            // Date
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.surfaceSubtle)
                .frame(width: 80, height: 10)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .opacity(shimmer ? 0.4 : 1.0)
        .animation(
            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: shimmer
        )
        .onAppear { shimmer = true }
    }
}

struct SkeletonFeed: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonEntryRow()
                Divider()
                    .foregroundStyle(.borderLight)
            }
        }
    }
}

struct SkeletonImageEntryRow: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Image placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.surfaceSubtle)
                .frame(height: 200)

            // Category
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.surfaceSubtle)
                .frame(width: 70, height: 12)

            // Headline
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.surfaceSubtle)
                .frame(height: 20)

            // Date
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.surfaceSubtle)
                .frame(width: 100, height: 10)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .opacity(shimmer ? 0.4 : 1.0)
        .animation(
            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: shimmer
        )
        .onAppear { shimmer = true }
    }
}

// MARK: - Category Badge

struct CategoryBadge: View {
    let category: String

    var body: some View {
        Text(category.uppercased())
            .font(Typography.categoryLabel)
            .tracking(1.5)
            .foregroundStyle(.understoodCrimson)
    }
}

// MARK: - Pressable Card Modifier

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func pressable() -> some View {
        buttonStyle(PressableStyle())
    }
}

// MARK: - Slide-Up Appearance

struct SlideUpModifier: ViewModifier {
    @State private var appeared = false

    let delay: Double

    func body(content: Content) -> some View {
        content
            .offset(y: appeared ? 0 : 20)
            .opacity(appeared ? 1.0 : 0)
            .animation(
                .easeOut(duration: 0.4).delay(delay),
                value: appeared
            )
            .onAppear { appeared = true }
    }
}

extension View {
    func slideUp(delay: Double = 0) -> some View {
        modifier(SlideUpModifier(delay: delay))
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.understoodCrimson)
                .font(.system(size: 16))

            Text(message)
                .font(Typography.small)
                .foregroundStyle(.textPrimary)

            Spacer()

            if let onRetry {
                Button("Retry") {
                    onRetry()
                }
                .font(Typography.uiMedium)
                .foregroundStyle(.understoodCrimson)
            }
        }
        .padding(12)
        .background(Color.understoodCrimson.opacity(0.08))
        .cornerRadius(8)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.textMuted)

            Text(title)
                .font(Typography.emptyState)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(Typography.body)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let onAction {
                Button {
                    onAction()
                } label: {
                    Text(actionTitle)
                        .font(Typography.uiMedium)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.understoodCrimson)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding(32)
    }
}

// MARK: - Flow Layout (wrapping horizontal layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
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

// MARK: - Action Checkbox

struct ActionCheckbox: View {
    let isCompleted: Bool
    let isOverdue: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isCompleted {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.actionGreen)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isOverdue ? Color.overdueRed : Color.borderMedium, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Due Date Label

struct DueDateLabel: View {
    let entry: Entry

    var body: some View {
        if entry.isCompleted, let completed = entry.parsedCompletedAt {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                Text("Completed \(formatShortDate(completed))")
                    .font(Typography.chipLabel)
            }
            .foregroundStyle(.actionGreen)
        } else if entry.isOverdue, let due = entry.parsedDueDate {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                Text("Overdue: \(formatShortDate(due))")
                    .font(Typography.chipLabel)
            }
            .foregroundStyle(.overdueRed)
        } else if let due = entry.parsedDueDate {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                Text("Due: \(formatShortDate(due))")
                    .font(Typography.chipLabel)
            }
            .foregroundStyle(.textMetadata)
        }
    }

    private func formatShortDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }
}

// MARK: - Section Header

struct SectionHeaderView: View {
    let title: String
    var count: Int? = nil
    var accentColor: Color = .textMetadata

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(Typography.sectionHeader)
                .tracking(1.5)
                .foregroundStyle(accentColor)

            if let count, count > 0 {
                Text("\(count)")
                    .font(Typography.chipLabel)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accentColor)
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }
}

// MARK: - AI Generating Spinner

struct AIGeneratingView: View {
    let message: String
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundStyle(.understoodCrimson)
                .rotationEffect(.degrees(rotation))
                .animation(
                    .linear(duration: 2).repeatForever(autoreverses: false),
                    value: rotation
                )
                .onAppear { rotation = 360 }

            Text(message)
                .font(Typography.small)
                .foregroundStyle(.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

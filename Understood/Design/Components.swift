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

// MARK: - Metadata Chip

struct MetadataChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(Typography.chipLabel)
            .foregroundStyle(.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.surfaceChip)
            .cornerRadius(4)
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

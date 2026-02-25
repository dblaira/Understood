//
//  NotificationPromptView.swift
//  Understood
//
//  Phase 5: Pre-permission screen before system notification prompt
//

import SwiftUI

struct NotificationPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 64))
                .foregroundStyle(.understoodCrimson)

            // Title
            VStack(spacing: 8) {
                Text("Stay Connected")
                    .font(Typography.headline)
                    .foregroundStyle(.textPrimary)
                Text("to Your Beliefs")
                    .font(Typography.headline)
                    .foregroundStyle(.textPrimary)
            }

            // Feature descriptions
            VStack(spacing: 16) {
                PromptFeatureRow(
                    icon: "sparkles",
                    text: "Get notified when the AI finds patterns in your entries"
                )
                PromptFeatureRow(
                    icon: "arrow.triangle.2.circlepath",
                    text: "Revisit beliefs at the right moment to reinforce growth"
                )
                PromptFeatureRow(
                    icon: "hand.thumbsup.fill",
                    text: "Respond with \"This Landed\" or \"Not Now\" to train your feed"
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button {
                    isRequesting = true
                    Task {
                        let _ = await NotificationService.shared.requestPermission()
                        dismiss()
                    }
                } label: {
                    Text("Enable Notifications")
                        .font(Typography.uiMedium)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.understoodCrimson)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .disabled(isRequesting)

                Button {
                    dismiss()
                } label: {
                    Text("Maybe Later")
                        .font(Typography.uiMedium)
                        .foregroundStyle(.textMuted)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.understoodCream.ignoresSafeArea())
    }
}

// MARK: - Feature Row

struct PromptFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.understoodCrimson)
                .frame(width: 24)

            Text(text)
                .font(Typography.body)
                .foregroundStyle(.textSecondary)

            Spacer()
        }
    }
}

#Preview {
    NotificationPromptView()
}

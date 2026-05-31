//
//  SettingsView.swift
//  Understood
//
//  Lightweight in-app settings surface opened from the full-screen menu.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings")
                            .font(.custom("PlayfairDisplay-Regular", size: 42))
                            .foregroundStyle(.textPrimary)

                        Text("Keep capture dependable and your saved thoughts easy to retrieve.")
                            .font(Typography.subtitle)
                            .foregroundStyle(.textSecondary)
                    }
                    .padding(.top, 16)

                    settingsSection("Capture") {
                        settingsRow(
                            icon: "photo.on.rectangle",
                            title: "Images",
                            subtitle: "Photos attached to entries are saved with the note and shown in the feed."
                        )

                        settingsRow(
                            icon: "square.and.pencil",
                            title: "Editing",
                            subtitle: "Open any entry to revise the title, body, life area, and images."
                        )
                    }

                    settingsSection("Account") {
                        Button {
                            Haptics.warning()
                            dismiss()
                            onSignOut()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 17, weight: .medium))
                                    .frame(width: 28)

                                Text("Sign Out")
                                    .font(Typography.subtitle)
                                    .foregroundStyle(.understoodCrimson)

                                Spacer()
                            }
                            .padding(.vertical, 14)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .background(Color.understoodCream.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.surfaceSubtle)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(Typography.sectionHeader)
                .tracking(1.5)
                .foregroundStyle(.textMuted)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .background(Color.surfaceSubtle)
            .cornerRadius(8)
        }
    }

    private func settingsRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.understoodCrimson)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.subtitle)
                    .foregroundStyle(.textPrimary)

                Text(subtitle)
                    .font(Typography.small)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
    }
}

#Preview {
    SettingsView(onSignOut: {})
}

//
//  Typography.swift
//  Understood
//
//  Design system typography presets
//  Uses system serif (Bodoni-like) until custom fonts are bundled in Phase 6
//

import SwiftUI

enum Typography {
    // MARK: - Serif (Headlines)

    /// Login/splash title — 48pt light serif
    static let hero = Font.system(size: 48, weight: .light, design: .serif)

    /// Entry detail headline — 32pt regular serif
    static let headline = Font.system(size: 32, weight: .regular, design: .serif)

    /// Feed row / card headline — 20pt regular serif
    static let cardHeadline = Font.system(size: 20, weight: .regular, design: .serif)

    /// Card headline light — 20pt light serif (for post-capture sheet)
    static let cardHeadlineLight = Font.system(size: 20, weight: .light, design: .serif)

    /// Empty state title — 34pt light serif
    static let emptyState = Font.system(size: 34, weight: .light, design: .serif)

    // MARK: - Sans-Serif (Body + UI)

    /// Body text — 16pt regular
    static let body = Font.system(size: 16, weight: .regular)

    /// Subheading — 17pt regular
    static let subheading = Font.system(size: 17, weight: .regular)

    /// Capture text editor — 17pt regular
    static let editor = Font.system(size: 17)

    /// Version body — 15pt regular
    static let versionBody = Font.system(size: 15, weight: .regular)

    /// UI text (buttons, pills) — 13pt medium
    static let uiMedium = Font.system(size: 13, weight: .medium)

    /// Mood/secondary info — 13pt regular
    static let info = Font.system(size: 13)

    /// Subtitle / supporting text — 15pt regular
    static let subtitle = Font.system(size: 15)

    // MARK: - Metadata (Small + Uppercase)

    /// Category label — 11pt semibold, pair with .tracking(1.5) and .uppercased()
    static let categoryLabel = Font.system(size: 11, weight: .semibold)

    /// Section header — 11pt bold, pair with .tracking(1.5) and .uppercased()
    static let sectionHeader = Font.system(size: 11, weight: .bold)

    /// Chip label — 11pt semibold
    static let chipLabel = Font.system(size: 11, weight: .semibold)

    /// Date/metadata — 12pt medium
    static let date = Font.system(size: 12, weight: .medium)

    /// Caption — system caption size
    static let caption = Font.caption

    /// Small error/info — 13pt regular
    static let small = Font.system(size: 13)
}

//
//  Typography.swift
//  Understood
//
//  Design system typography presets
//  Playfair Display for headlines, Inter for body/UI
//

import SwiftUI

enum Typography {

    // MARK: - Helpers

    /// Playfair Display variable font — applies weight axis via SwiftUI modifier
    private static func playfair(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        Font.custom("PlayfairDisplay-Regular", size: size).weight(weight)
    }

    /// Inter static fonts — mapped by weight
    private static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold:
            name = "Inter-Bold"
        case .semibold:
            name = "Inter-SemiBold"
        case .medium:
            name = "Inter-Medium"
        default:
            name = "Inter-Regular"
        }
        return Font.custom(name, size: size)
    }

    // MARK: - Serif (Headlines — Playfair Display)

    /// Login/splash title — 48pt bold Playfair Display
    static let hero = playfair(size: 48)

    /// Entry detail headline — 32pt bold Playfair Display
    static let headline = playfair(size: 32)

    /// Section title — 28pt bold Playfair Display
    static let sectionTitle = playfair(size: 28)

    /// Feed row / card headline — 20pt bold Playfair Display
    static let cardHeadline = playfair(size: 20)

    /// Card headline light - 20pt semibold Playfair Display (post-capture sheet)
    static let cardHeadlineLight = playfair(size: 20, weight: .semibold)

    /// Empty state title — 34pt semibold Playfair Display
    static let emptyState = playfair(size: 34, weight: .semibold)

    // MARK: - Serif (Quotes — Georgia)

    /// Connection hero title — 48pt Playfair Display, regular weight (matches web clamp min)
    static let connectionHero = playfair(size: 48, weight: .regular)

    /// Belief quote text — 24pt Georgia, regular weight (matches web mobile)
    static let beliefQuote = Font.custom("Georgia", size: 24).weight(.regular)

    /// List headline — 19pt Georgia Bold (legible at small size, editorial feel)
    static let listHeadline = Font.custom("Georgia-Bold", size: 19)

    // MARK: - Sans-Serif (Body + UI — Inter)

    /// Body text — 16pt Inter
    static let body = inter(size: 16)

    /// Subheading — 17pt Inter
    static let subheading = inter(size: 17)

    /// Capture text editor — 17pt Inter
    static let editor = inter(size: 17)

    /// Version body — 15pt Inter
    static let versionBody = inter(size: 15)

    /// UI text (buttons, pills) — 13pt Inter Medium
    static let uiMedium = inter(size: 13, weight: .medium)

    /// Mood/secondary info — 13pt Inter
    static let info = inter(size: 13)

    /// Subtitle / supporting text — 15pt Inter
    static let subtitle = inter(size: 15)

    // MARK: - Metadata (Small + Uppercase — Inter)

    /// Category label — 11pt Inter SemiBold, pair with .tracking(1.5) and .uppercased()
    static let categoryLabel = inter(size: 11, weight: .semibold)

    /// Section header — 11pt Inter Bold, pair with .tracking(1.5) and .uppercased()
    static let sectionHeader = inter(size: 11, weight: .bold)

    /// Chip label — 11pt Inter SemiBold
    static let chipLabel = inter(size: 11, weight: .semibold)

    /// Date/metadata — 12pt Inter Medium
    static let date = inter(size: 12, weight: .medium)

    /// Caption — system caption size
    static let caption = Font.caption

    /// Small error/info — 13pt Inter
    static let small = inter(size: 13)
}

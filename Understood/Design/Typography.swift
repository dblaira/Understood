//
//  Typography.swift
//  Understood
//
//  Design system typography presets
//  Bodoni Moda for headlines, Inter for body/UI
//

import SwiftUI

enum Typography {

    // MARK: - Helpers

    /// Bodoni Moda variable font — use weight parameter for light/regular/bold
    private static func bodoni(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Variable font: "BodoniModa-Regular" is the PostScript base name
        // SwiftUI handles variable font weight axis via Font.custom + weight modifier
        Font.custom("BodoniModa-Regular", size: size)
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

    // MARK: - Serif (Headlines — Bodoni Moda)

    /// Login/splash title — 48pt light Bodoni Moda
    static let hero = bodoni(size: 48, weight: .light)

    /// Entry detail headline — 32pt Bodoni Moda
    static let headline = bodoni(size: 32)

    /// Section title — 28pt Bodoni Moda
    static let sectionTitle = bodoni(size: 28)

    /// Feed row / card headline — 20pt Bodoni Moda
    static let cardHeadline = bodoni(size: 20)

    /// Card headline light — 20pt light Bodoni Moda
    static let cardHeadlineLight = bodoni(size: 20, weight: .light)

    /// Empty state title — 34pt light Bodoni Moda
    static let emptyState = bodoni(size: 34, weight: .light)

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

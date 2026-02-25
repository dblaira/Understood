//
//  Colors.swift
//  Understood
//
//  Design system color definitions
//  Uses `ShapeStyle where Self == Color` so shorthand like
//  .understoodCrimson works in .foregroundStyle() contexts.
//

import SwiftUI

extension ShapeStyle where Self == Color {
    // MARK: - Brand Colors

    /// Understood cream background — #F5F0E8
    static var understoodCream: Color { Color(red: 0.96, green: 0.94, blue: 0.91) }

    /// Understood crimson accent — #DC143C
    static var understoodCrimson: Color { Color(red: 0.86, green: 0.08, blue: 0.24) }

    // MARK: - Text Colors

    /// Primary text — pure black
    static var textPrimary: Color { Color(red: 0, green: 0, blue: 0) }

    /// Secondary text — black at 60% opacity
    static var textSecondary: Color { Color(red: 0, green: 0, blue: 0, opacity: 0.6) }

    /// Tertiary/muted text — black at 45% opacity
    static var textMuted: Color { Color(red: 0, green: 0, blue: 0, opacity: 0.45) }

    /// Metadata text (dates, counts) — black at 50% opacity
    static var textMetadata: Color { Color(red: 0, green: 0, blue: 0, opacity: 0.5) }

    // MARK: - UI Colors

    /// Light border/separator — black at 8% opacity
    static var borderLight: Color { Color(red: 0, green: 0, blue: 0, opacity: 0.08) }

    /// Medium border/separator — black at 15% opacity
    static var borderMedium: Color { Color(red: 0, green: 0, blue: 0, opacity: 0.15) }

    /// Subtle surface (chips, inactive pills) — black at 5% opacity
    static var surfaceSubtle: Color { Color(red: 0, green: 0, blue: 0, opacity: 0.05) }

    /// Chip/badge background — black at 10% opacity
    static var surfaceChip: Color { Color(red: 0, green: 0, blue: 0, opacity: 0.1) }
}

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

    /// Understood background — pure white
    static var understoodCream: Color { Color.white }

    /// Understood crimson accent — #DC143C
    static var understoodCrimson: Color { Color(red: 0.86, green: 0.08, blue: 0.24) }

    /// Warm beige for section backgrounds — #E8E2D8 (matches web app)
    static var understoodBeige: Color { Color(red: 0.91, green: 0.89, blue: 0.85) }

    /// Sandy brown frame color used by the bottom tab bar
    static var sandyBrown: Color { Color(red: 0.80, green: 0.70, blue: 0.58) }

    /// Green for completed actions — #22C55E
    static var actionGreen: Color { Color(red: 0.133, green: 0.773, blue: 0.369) }

    /// Red for overdue actions — #EF4444
    static var overdueRed: Color { Color(red: 0.937, green: 0.267, blue: 0.267) }

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

    // MARK: - Voice-Specific Colors (AI Perspectives)

    /// Literary — cream background #FAF9F6
    static var voiceLiteraryBg: Color { Color(red: 0.98, green: 0.98, blue: 0.96) }
    /// Literary — saddle brown title #8B4513
    static var voiceLiteraryTitle: Color { Color(red: 0.545, green: 0.271, blue: 0.075) }
    /// Literary — dark red drop cap #8B0000
    static var voiceLiteraryDropCap: Color { Color(red: 0.545, green: 0, blue: 0) }
    /// Literary — body text #2C2C2C
    static var voiceLiteraryText: Color { Color(red: 0.173, green: 0.173, blue: 0.173) }

    /// News — light gray background #F1F1F1
    static var voiceNewsBg: Color { Color(red: 0.945, green: 0.945, blue: 0.945) }
    /// News — gray title #6B7280
    static var voiceNewsTitle: Color { Color(red: 0.42, green: 0.45, blue: 0.50) }

    /// Poetic — parchment background #F4EBD0
    static var voicePoeticBg: Color { Color(red: 0.957, green: 0.922, blue: 0.816) }
    /// Poetic — warm brown title #8B7355
    static var voicePoeticTitle: Color { Color(red: 0.545, green: 0.451, blue: 0.333) }
    /// Poetic — muted brown body text #5C4B37
    static var voicePoeticText: Color { Color(red: 0.361, green: 0.294, blue: 0.216) }

    /// Humorous — light green background #F0F9F1
    static var voiceHumorousBg: Color { Color(red: 0.941, green: 0.976, blue: 0.945) }
    /// Humorous — dark green title #2E7D32
    static var voiceHumorousTitle: Color { Color(red: 0.180, green: 0.490, blue: 0.196) }
    /// Humorous — dark green body text #1B5E20
    static var voiceHumorousText: Color { Color(red: 0.106, green: 0.369, blue: 0.125) }
    /// Humorous — green border #4CAF50
    static var voiceHumorousBorder: Color { Color(red: 0.298, green: 0.686, blue: 0.314) }
}

//
//  HeaderButtons.swift
//  Understood
//
//  High-contrast controls for the sandy navigation header.
//

import SwiftUI

struct HeaderPillButton: View {
    let title: String
    var isEnabled = true

    var body: some View {
        Text(title)
            .font(Typography.uiMedium)
            .fontWeight(.bold)
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.48))
            .padding(.horizontal, 18)
            .frame(height: 46)
            .background(Color.black.opacity(isEnabled ? 0.9 : 0.42))
            .clipShape(Capsule())
    }
}

struct HeaderIconButton: View {
    let systemName: String
    var isEnabled = true

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.48))
            .frame(width: 52, height: 52)
            .background(Color.black.opacity(isEnabled ? 0.9 : 0.42))
            .clipShape(Circle())
    }
}

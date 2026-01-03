//
//  ViralityBadge.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

struct ViralityBadge: View {
    let score: Int
    let level: ClipSuggestion.ViralityLevel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.caption)

            Text("\(score)")
                .font(.system(.caption, design: .rounded, weight: .bold))

            Text(level.rawValue)
                .font(.system(.caption2, design: .rounded, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Virality score \(score), \(level.rawValue) potential")
    }

    private var backgroundColor: Color {
        switch level {
        case .viral:
            Color.red.opacity(0.15)
        case .high:
            Color.orange.opacity(0.15)
        case .medium:
            Color.yellow.opacity(0.15)
        case .low:
            Color.gray.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch level {
        case .viral:
            .red
        case .high:
            .orange
        case .medium:
            .yellow
        case .low:
            .secondary
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ViralityBadge(score: 95, level: .viral)
        ViralityBadge(score: 78, level: .high)
        ViralityBadge(score: 62, level: .medium)
        ViralityBadge(score: 35, level: .low)
    }
    .padding()
}

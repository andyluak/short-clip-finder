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

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 5) {
            // Animated flame for viral clips
            Image(systemName: level == .viral ? "flame.fill" : "flame")
                .font(.system(size: 12, weight: .semibold))
                .symbolEffect(.bounce, options: .repeating.speed(0.5), value: isAnimating && level == .viral)
                .foregroundStyle(flameGradient)

            Text("\(score)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text(level.rawValue)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(backgroundGradient)
        .foregroundStyle(foregroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderGradient, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: level == .viral ? 4 : 2, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Virality score \(score), \(level.rawValue) potential")
        .onAppear {
            isAnimating = true
        }
    }

    private var flameGradient: LinearGradient {
        switch level {
        case .viral:
            LinearGradient(
                colors: [Color(hex: "FF3366"), Color(hex: "FF6B35")],
                startPoint: .bottom,
                endPoint: .top
            )
        case .high:
            LinearGradient(
                colors: [Color(hex: "FF6B35"), Color(hex: "FFA500")],
                startPoint: .bottom,
                endPoint: .top
            )
        case .medium:
            LinearGradient(
                colors: [Color(hex: "FFB81C"), Color(hex: "FFD700")],
                startPoint: .bottom,
                endPoint: .top
            )
        case .low:
            LinearGradient(
                colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.4)],
                startPoint: .bottom,
                endPoint: .top
            )
        }
    }

    private var backgroundGradient: LinearGradient {
        switch level {
        case .viral:
            LinearGradient(
                colors: [Color(hex: "FF3366").opacity(0.2), Color(hex: "FF6B35").opacity(0.15)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .high:
            LinearGradient(
                colors: [Color(hex: "FF6B35").opacity(0.18), Color(hex: "FFA500").opacity(0.12)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .medium:
            LinearGradient(
                colors: [Color(hex: "FFB81C").opacity(0.15), Color(hex: "FFD700").opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .low:
            LinearGradient(
                colors: [Color.gray.opacity(0.12), Color.gray.opacity(0.08)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var borderGradient: LinearGradient {
        switch level {
        case .viral:
            LinearGradient(
                colors: [Color(hex: "FF3366").opacity(0.5), Color(hex: "FF6B35").opacity(0.3)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .high:
            LinearGradient(
                colors: [Color(hex: "FF6B35").opacity(0.4), Color(hex: "FFA500").opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .medium:
            LinearGradient(
                colors: [Color(hex: "FFB81C").opacity(0.3), Color(hex: "FFD700").opacity(0.15)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .low:
            LinearGradient(
                colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var shadowColor: Color {
        switch level {
        case .viral: Color(hex: "FF3366").opacity(0.3)
        case .high: Color(hex: "FF6B35").opacity(0.25)
        case .medium: Color(hex: "FFB81C").opacity(0.2)
        case .low: Color.clear
        }
    }

    private var foregroundColor: Color {
        switch level {
        case .viral: Color(hex: "FF3366")
        case .high: Color(hex: "FF6B35")
        case .medium: Color(hex: "B8860B") // Darker gold for readability
        case .low: .secondary
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        ViralityBadge(score: 95, level: .viral)
        ViralityBadge(score: 78, level: .high)
        ViralityBadge(score: 62, level: .medium)
        ViralityBadge(score: 35, level: .low)
    }
    .padding(24)
    .background(Color(.windowBackgroundColor))
}

//
//  Theme.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

// MARK: - ClipFinder Theme

/// ClipFinder's design system - "Editorial Precision"
/// Inspired by: Linear, Raycast, Arc Browser
/// Dark-mode native, type-first hierarchy, purposeful motion
enum Theme {
    // MARK: - Corner Radius

    enum CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 9999
    }

    // MARK: - Typography

    enum Typography {
        /// Display Large - 42pt bold, tight tracking
        static let displayLarge = Font.system(size: 42, weight: .bold)
        /// Display Medium - 28pt semibold
        static let displayMedium = Font.system(size: 28, weight: .semibold)
        /// Title - 20pt semibold
        static let title = Font.system(size: 20, weight: .semibold)
        /// Headline - 16pt semibold
        static let headline = Font.system(size: 16, weight: .semibold)
        /// Body - 14pt regular
        static let body = Font.system(size: 14, weight: .regular)
        /// Caption - 12pt regular
        static let caption = Font.system(size: 12, weight: .regular)
        /// Small - 11pt regular
        static let small = Font.system(size: 11, weight: .regular)
        /// Tiny - 10pt regular
        static let tiny = Font.system(size: 10, weight: .regular)
        /// Monospace - 12pt
        static let mono = Font.system(size: 12, design: .monospaced)
        /// Mono small - 11pt
        static let monoSmall = Font.system(size: 11, design: .monospaced)
        /// Badge - rounded bold
        static let badge = Font.system(size: 12, weight: .bold, design: .rounded)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }

    // MARK: - Animation

    enum Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }

    // MARK: - Shadows

    enum Shadow {
        static let subtle = ShadowStyle(
            color: Color.black.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )

        static let medium = ShadowStyle(
            color: Color.black.opacity(0.15),
            radius: 8,
            x: 0,
            y: 4
        )

        static let glow = ShadowStyle(
            color: Color.cfAccent.opacity(0.4),
            radius: 12,
            x: 0,
            y: 0
        )
    }

    // MARK: - Gradients (minimal use)

    enum Gradient {
        /// Accent gradient for special buttons
        static let accent = LinearGradient(
            colors: [.cfAccent, .cfAccentHover],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Subtle background gradient
        static let subtle = LinearGradient(
            colors: [
                Color.cfAccent.opacity(0.05),
                Color.cfAccent.opacity(0.02)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Warm gradient (legacy compatibility - maps to accent)
        static let warm = accent

        /// Primary gradient (legacy compatibility - maps to accent)
        static let primary = accent
    }
}

// MARK: - Shadow Style Helper

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Color Extension

extension Color {
    // MARK: - Primary Accent (Amber)

    /// Accent - Warm amber (#F59E0B)
    static let cfAccent = Color(hex: "F59E0B")

    /// Accent Hover - Darker amber (#D97706)
    static let cfAccentHover = Color(hex: "D97706")

    // MARK: - Semantic Colors

    /// Success - Emerald (#10B981)
    static let cfSuccess = Color(hex: "10B981")

    /// Warning - Amber (#F59E0B)
    static let cfWarning = Color(hex: "F59E0B")

    /// Error - Red (#EF4444)
    static let cfError = Color(hex: "EF4444")

    // MARK: - Surface Colors (Zinc palette)

    /// Surface - Base background (#18181B)
    static let cfSurface = Color(light: .init(hex: "FAFAFA"), dark: .init(hex: "18181B"))

    /// Surface Elevated - Cards, panels (#27272A)
    static let cfSurfaceElevated = Color(light: .init(hex: "F4F4F5"), dark: .init(hex: "27272A"))

    /// Surface Hover - Interactive hover state (#3F3F46)
    static let cfSurfaceHover = Color(light: .init(hex: "E4E4E7"), dark: .init(hex: "3F3F46"))

    // MARK: - Text Colors

    /// Text Primary - High contrast (#FAFAFA / #18181B)
    static let cfTextPrimary = Color(light: .init(hex: "18181B"), dark: .init(hex: "FAFAFA"))

    /// Text Secondary - Medium contrast (#A1A1AA / #71717A)
    static let cfTextSecondary = Color(light: .init(hex: "71717A"), dark: .init(hex: "A1A1AA"))

    /// Text Muted - Low contrast (#71717A / #52525B)
    static let cfTextMuted = Color(light: .init(hex: "A1A1AA"), dark: .init(hex: "71717A"))

    // MARK: - Border Colors

    /// Border - Standard borders (#3F3F46 / #E4E4E7)
    static let cfBorder = Color(light: .init(hex: "E4E4E7"), dark: .init(hex: "3F3F46"))

    /// Border Subtle - Subtle separators (#27272A / #F4F4F5)
    static let cfBorderSubtle = Color(light: .init(hex: "F4F4F5"), dark: .init(hex: "27272A"))

    // MARK: - Virality Score Colors

    /// Viral tier - Hot red (#EF4444)
    static let cfViralHot = Color(hex: "EF4444")

    /// High tier - Amber (#F59E0B)
    static let cfViralHigh = Color(hex: "F59E0B")

    /// Medium tier - Emerald (#10B981)
    static let cfViralMedium = Color(hex: "10B981")

    /// Low tier - Gray (#6B7280)
    static let cfViralLow = Color(hex: "6B7280")

    // MARK: - Legacy Compatibility (for gradual migration)

    /// Legacy coral - now maps to accent
    static let cfCoral = cfAccent

    /// Legacy teal - now maps to success
    static let cfTeal = cfSuccess

    /// Legacy orange - now maps to warning
    static let cfOrange = cfWarning

    // MARK: - Initializers

    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
            case .darkAqua:
                return NSColor(dark)
            default:
                return NSColor(light)
            }
        }))
    }

    // Note: init(hex: String) is defined in ViralityBadge.swift

    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply a theme shadow style
    func themeShadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

// MARK: - Keyboard Hint Component

struct KeyboardHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(Theme.Typography.tiny)
                .fontWeight(.medium)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.cfSurfaceHover)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Text(label)
                .font(Theme.Typography.small)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Phase Step Component

struct PhaseStep: View {
    let number: Int
    let label: String
    let isComplete: Bool
    let isActive: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(circleColor)
                    .frame(width: 32, height: 32)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                } else {
                    Text("\(number)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isActive ? .black : .secondary)
                }
            }

            Text(label)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive || isComplete ? .primary : .secondary)
        }
    }

    private var circleColor: Color {
        if isComplete { return .cfSuccess }
        if isActive { return .cfAccent }
        return .cfSurfaceElevated
    }
}

// MARK: - Phase Connector Component

struct PhaseConnector: View {
    let isActive: Bool

    var body: some View {
        Rectangle()
            .fill(isActive ? Color.cfAccent : Color.cfBorder)
            .frame(width: 40, height: 2)
    }
}

// MARK: - Legacy Gradient Badge (for compatibility)

struct GradientBadge: View {
    let score: Int
    let level: ClipSuggestion.ViralityLevel

    init(score: Int, level: ClipSuggestion.ViralityLevel) {
        self.score = score
        self.level = level
    }

    var body: some View {
        ViralityBadge(score: score, level: level)
    }
}

// MARK: - Legacy Button Style (for compatibility)

struct GradientButtonStyle: ButtonStyle {
    var gradient: LinearGradient
    var isDisabled: Bool

    init(gradient: LinearGradient = Theme.Gradient.accent, isDisabled: Bool = false) {
        self.gradient = gradient
        self.isDisabled = isDisabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundColor(isDisabled ? .secondary : .black)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(isDisabled ? Color.cfSurfaceHover : Color.cfAccent)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(isDisabled ? 0.6 : (configuration.isPressed ? 0.9 : 1.0))
            .animation(Theme.Animation.fast, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GradientButtonStyle {
    static var gradient: GradientButtonStyle {
        GradientButtonStyle()
    }

    static func gradient(_ gradient: LinearGradient) -> GradientButtonStyle {
        GradientButtonStyle(gradient: gradient)
    }

    static func gradient(disabled: Bool) -> GradientButtonStyle {
        GradientButtonStyle(isDisabled: disabled)
    }
}

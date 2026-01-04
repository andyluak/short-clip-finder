//
//  Theme.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

// MARK: - ClipFinder Theme

/// ClipFinder's design system - a cohesive visual identity matching the app icon's warm-cool gradient
enum Theme {
    // MARK: - Corner Radius

    enum CornerRadius {
        /// Extra small: 4pt - chips, tags
        static let xs: CGFloat = 4
        /// Small: 6pt - badges, small buttons
        static let sm: CGFloat = 6
        /// Medium: 8pt - cards, inputs
        static let md: CGFloat = 8
        /// Large: 12pt - panels, sheets
        static let lg: CGFloat = 12
        /// Extra large: 16pt - modals, large cards
        static let xl: CGFloat = 16
        /// Full: 9999pt - pills, circular elements
        static let full: CGFloat = 9999
    }

    // MARK: - Shadows

    enum Shadow {
        /// Subtle shadow for hover states
        static let subtle = ShadowStyle(
            color: Color.black.opacity(0.08),
            radius: 4,
            x: 0,
            y: 2
        )

        /// Medium shadow for floating elements
        static let medium = ShadowStyle(
            color: Color.black.opacity(0.12),
            radius: 8,
            x: 0,
            y: 4
        )

        /// Strong shadow for modals, dropdowns
        static let strong = ShadowStyle(
            color: Color.black.opacity(0.16),
            radius: 16,
            x: 0,
            y: 8
        )

        /// Glow effect using primary color
        static let glow = ShadowStyle(
            color: Color.cfCoral.opacity(0.4),
            radius: 12,
            x: 0,
            y: 0
        )
    }

    // MARK: - Typography

    enum Typography {
        /// Large title - SF Pro Display Bold 28pt
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .default)
        /// Title 1 - SF Pro Display Semibold 22pt
        static let title1 = Font.system(size: 22, weight: .semibold, design: .default)
        /// Title 2 - SF Pro Display Semibold 18pt
        static let title2 = Font.system(size: 18, weight: .semibold, design: .default)
        /// Title 3 - SF Pro Display Medium 16pt
        static let title3 = Font.system(size: 16, weight: .medium, design: .default)
        /// Headline - SF Pro Display Medium 14pt
        static let headline = Font.system(size: 14, weight: .medium, design: .default)
        /// Body - SF Pro Text Regular 14pt
        static let body = Font.system(size: 14, weight: .regular, design: .default)
        /// Callout - SF Pro Text Regular 13pt
        static let callout = Font.system(size: 13, weight: .regular, design: .default)
        /// Caption - SF Pro Text Regular 12pt
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        /// Caption 2 - SF Pro Text Regular 11pt
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)

        /// Rounded variant for numbers and badges
        static let badgeNumber = Font.system(.caption, design: .rounded, weight: .bold)
        /// Rounded variant for score displays
        static let scoreDisplay = Font.system(size: 20, weight: .bold, design: .rounded)
    }

    // MARK: - Gradients

    enum Gradient {
        /// Primary gradient: Coral to Teal (matching app icon)
        static let primary = LinearGradient(
            colors: [.cfCoral, .cfTeal],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Warm gradient: Coral to Orange
        static let warm = LinearGradient(
            colors: [.cfCoral, .cfOrange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Cool gradient: Teal to Blue
        static let cool = LinearGradient(
            colors: [.cfTeal, .cfBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Viral gradient: Hot Pink to Orange
        static let viral = LinearGradient(
            colors: [.cfViralHotPink, .cfViralOrange],
            startPoint: .leading,
            endPoint: .trailing
        )

        /// High potential gradient: Orange to Yellow
        static let high = LinearGradient(
            colors: [.cfViralOrange, .cfViralYellow],
            startPoint: .leading,
            endPoint: .trailing
        )

        /// Subtle background gradient for cards
        static let cardBackground = LinearGradient(
            colors: [
                Color.cfCoral.opacity(0.05),
                Color.cfTeal.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Mesh-like ambient background
        static let ambient = LinearGradient(
            colors: [
                Color.cfCoral.opacity(0.08),
                Color.cfTeal.opacity(0.04),
                Color.cfCoral.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
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
    // MARK: - Primary Palette (from app icon)

    /// Coral - Primary accent color (#FF6B35)
    static let cfCoral = Color(light: .init(hex: 0xFF6B35), dark: .init(hex: 0xFF7F50))

    /// Teal - Secondary accent color (#4ECDC4)
    static let cfTeal = Color(light: .init(hex: 0x4ECDC4), dark: .init(hex: 0x5FD9D1))

    /// Orange - Warm accent (#FF8C42)
    static let cfOrange = Color(light: .init(hex: 0xFF8C42), dark: .init(hex: 0xFFA05A))

    /// Blue - Cool accent (#2E86AB)
    static let cfBlue = Color(light: .init(hex: 0x2E86AB), dark: .init(hex: 0x4A9DC4))

    // MARK: - Virality Colors

    /// Hot Pink - Viral tier (#FF3366)
    static let cfViralHotPink = Color(light: .init(hex: 0xFF3366), dark: .init(hex: 0xFF4D7A))

    /// Viral Orange - High tier (#FF6B35)
    static let cfViralOrange = Color(light: .init(hex: 0xFF6B35), dark: .init(hex: 0xFF7F50))

    /// Viral Yellow - Medium tier (#FFD23F)
    static let cfViralYellow = Color(light: .init(hex: 0xFFD23F), dark: .init(hex: 0xFFDA5C))

    // MARK: - Semantic Colors

    /// Success color - matches Teal
    static let cfSuccess = cfTeal

    /// Warning color - matches Viral Orange
    static let cfWarning = cfViralOrange

    /// Error color - matches Hot Pink
    static let cfError = cfViralHotPink

    // MARK: - Background Colors

    /// Card background with subtle gradient tint
    static let cfCardBackground = Color(light: .white, dark: .init(hex: 0x1E1E1E))

    /// Elevated surface background
    static let cfElevatedBackground = Color(light: .init(hex: 0xFAFAFA), dark: .init(hex: 0x2A2A2A))

    /// Subtle tinted background
    static let cfTintedBackground = Color(light: .init(hex: 0xFFF5F2), dark: .init(hex: 0x2D2420))

    // MARK: - Initializers for Adaptive Colors

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

// MARK: - View Extensions for Shadows

extension View {
    /// Apply a theme shadow style
    func themeShadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

// MARK: - Gradient Button Modifier

struct GradientButtonStyle: ButtonStyle {
    var gradient: LinearGradient
    var isDisabled: Bool

    init(gradient: LinearGradient = Theme.Gradient.primary, isDisabled: Bool = false) {
        self.gradient = gradient
        self.isDisabled = isDisabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(isDisabled ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(gradient))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(isDisabled ? 0.6 : (configuration.isPressed ? 0.9 : 1.0))
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
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

// MARK: - Gradient Badge Component

struct GradientBadge: View {
    let score: Int
    let level: ClipSuggestion.ViralityLevel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.caption)

            Text("\(score)")
                .font(Theme.Typography.badgeNumber)

            Text(level.rawValue)
                .font(.system(.caption2, design: .rounded, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(badgeGradient)
        )
        .themeShadow(shadowStyle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Virality score \(score), \(level.rawValue) potential")
    }

    private var badgeGradient: LinearGradient {
        switch level {
        case .viral:
            Theme.Gradient.viral
        case .high:
            Theme.Gradient.high
        case .medium:
            LinearGradient(
                colors: [.cfViralYellow, .cfViralYellow.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .low:
            LinearGradient(
                colors: [Color.secondary.opacity(0.6), Color.secondary.opacity(0.4)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var shadowStyle: ShadowStyle {
        switch level {
        case .viral:
            ShadowStyle(color: .cfViralHotPink.opacity(0.4), radius: 4, x: 0, y: 2)
        case .high:
            ShadowStyle(color: .cfViralOrange.opacity(0.3), radius: 3, x: 0, y: 2)
        case .medium:
            ShadowStyle(color: .cfViralYellow.opacity(0.3), radius: 2, x: 0, y: 1)
        case .low:
            ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
        }
    }
}

// MARK: - Gradient Text Modifier

struct GradientTextModifier: ViewModifier {
    var gradient: LinearGradient

    func body(content: Content) -> some View {
        content
            .foregroundStyle(gradient)
    }
}

extension View {
    func gradientForeground(_ gradient: LinearGradient = Theme.Gradient.primary) -> some View {
        modifier(GradientTextModifier(gradient: gradient))
    }
}

// MARK: - Previews

#Preview("Theme Colors") {
    VStack(spacing: 20) {
        // Primary palette
        HStack(spacing: 12) {
            colorSwatch(.cfCoral, name: "Coral")
            colorSwatch(.cfTeal, name: "Teal")
            colorSwatch(.cfOrange, name: "Orange")
            colorSwatch(.cfBlue, name: "Blue")
        }

        // Virality colors
        HStack(spacing: 12) {
            colorSwatch(.cfViralHotPink, name: "Hot Pink")
            colorSwatch(.cfViralOrange, name: "Viral Orange")
            colorSwatch(.cfViralYellow, name: "Viral Yellow")
        }
    }
    .padding()
}

#Preview("Gradients") {
    VStack(spacing: 16) {
        gradientSwatch(Theme.Gradient.primary, name: "Primary")
        gradientSwatch(Theme.Gradient.warm, name: "Warm")
        gradientSwatch(Theme.Gradient.cool, name: "Cool")
        gradientSwatch(Theme.Gradient.viral, name: "Viral")
        gradientSwatch(Theme.Gradient.high, name: "High")
    }
    .padding()
}

#Preview("Gradient Buttons") {
    VStack(spacing: 16) {
        Button("Get Started") {}
            .buttonStyle(GradientButtonStyle())

        Button("Export Clips") {}
            .buttonStyle(GradientButtonStyle(gradient: Theme.Gradient.warm))

        Button("Disabled State") {}
            .buttonStyle(GradientButtonStyle(isDisabled: true))
            .disabled(true)
    }
    .padding()
}

#Preview("Gradient Badges") {
    VStack(spacing: 12) {
        GradientBadge(score: 95, level: .viral)
        GradientBadge(score: 78, level: .high)
        GradientBadge(score: 62, level: .medium)
        GradientBadge(score: 35, level: .low)
    }
    .padding()
}

// Helper views for previews
private func colorSwatch(_ color: Color, name: String) -> some View {
    VStack(spacing: 4) {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: 60, height: 60)
        Text(name)
            .font(.caption)
    }
}

private func gradientSwatch(_ gradient: LinearGradient, name: String) -> some View {
    HStack {
        Text(name)
            .font(.caption)
            .frame(width: 60, alignment: .leading)
        RoundedRectangle(cornerRadius: 8)
            .fill(gradient)
            .frame(height: 32)
    }
}

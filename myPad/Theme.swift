import SwiftUI

// MARK: - Studio Design System
//
// Warm, editorial palette for a high-end interior design practice.
// Typography uses serif headings + SF body for a magazine-like feel.

// MARK: - Color Palette

extension Color {
    /// Warm amber-gold accent — for interactive elements.
    static let studioAccent = Color(red: 0.78, green: 0.62, blue: 0.24)   // #C89E3D

    /// Rich warm brown — for titles and headings.
    static let studioBrown = Color(red: 0.44, green: 0.28, blue: 0.14)     // #704824

    /// Deep charcoal for primary text.
    static let studioText = Color(red: 0.18, green: 0.17, blue: 0.16)     // #2E2B29

    /// Warm ivory for card backgrounds.
    static let studioCard = Color(red: 0.98, green: 0.97, blue: 0.95)     // #FAF8F2

    /// Subtle warm surface for backgrounds.
    static let studioSurface = Color(red: 0.97, green: 0.96, blue: 0.94)  // #F7F5F0

    /// Muted warm secondary text.
    static let studioSecondary = Color(red: 0.55, green: 0.50, blue: 0.42) // #8C806B

    /// Subtle divider.
    static let studioDivider = Color(red: 0.90, green: 0.88, blue: 0.84)   // #E6E0D6

    // Status colors — sophisticated, not primary
    static let studioProposed = Color(red: 0.60, green: 0.56, blue: 0.48)   // warm taupe
    static let studioApproved = Color(red: 0.42, green: 0.55, blue: 0.35)   // muted sage
    static let studioRejected = Color(red: 0.58, green: 0.28, blue: 0.24)   // muted brick
    static let studioOrdered = Color(red: 0.65, green: 0.45, blue: 0.28)    // warm bronze
    static let studioDelivered = Color(red: 0.35, green: 0.40, blue: 0.55)   // slate blue
    static let studioInstalled = Color(red: 0.25, green: 0.45, blue: 0.42)   // deep teal
}

// MARK: - Font Styles

extension Font {
    /// Serif heading (New York) — elevated editorial display text.
    static func studioHeading(size: CGFloat = 23) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    /// Serif subheading (New York) — compact card/list titles.
    static func studioSubheading(size: CGFloat = 18) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    /// Serif body (New York) — for descriptions and notes.
    static func studioBody(size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    /// Sans-serif caption — for metadata, labels, pills and supporting text.
    static func studioCaption(size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
}

// MARK: - Card Style

struct StudioCard: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.studioCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.studioDivider.opacity(0.55), lineWidth: 0.5)
            }
            .shadow(color: Color.studioBrown.opacity(0.045), radius: 8, y: 3)
    }
}

extension View {
    func studioCard(padding: CGFloat = 16, cornerRadius: CGFloat = 14) -> some View {
        modifier(StudioCard(padding: padding, cornerRadius: cornerRadius))
    }
}

// MARK: - Studio Button Style

struct StudioButtonStyle: ButtonStyle {
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.studioCaption(size: 13))
            .fontWeight(.semibold)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(prominent ? Color.studioAccent : Color.studioSecondary.opacity(0.18))
            .foregroundStyle(prominent ? Color.white : Color.studioAccent)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - White Bubble Button Style

/// A clean white bubble button with a soft shadow, used for floating actions
/// that need to pop against warm-ivory backgrounds.
struct WhiteBubbleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.studioCaption(size: 14))
            .fontWeight(.semibold)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(Color.studioAccent)
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Noise Texture

/// Generates a subtle noise image once, then tiles it as a multiply overlay
/// to give flat surfaces a microtexture — like fine art paper or linen.
struct NoiseOverlay: View {
    private static let noiseImage: UIImage = {
        let size = 128
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let c = ctx.cgContext
            // Fill base with mid-grey so multiply blend darkens slightly
            c.setFillColor(UIColor(white: 0.5, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: size, height: size))
            // Sprinkle noise — each pixel gets a tiny random offset
            for y in stride(from: 0, to: size, by: 2) {
                for x in stride(from: 0, to: size, by: 2) {
                    let r = CGFloat.random(in: 0.45...0.55)
                    c.setFillColor(UIColor(white: r, alpha: 1).cgColor)
                    c.fill(CGRect(x: x, y: y, width: 2, height: 2))
                }
            }
        }
    }()

    var body: some View {
        Image(uiImage: Self.noiseImage)
            .resizable(resizingMode: .tile)
            .blendMode(.multiply)
            .opacity(0.35)
            .allowsHitTesting(false)
            .drawingGroup()          // rasterise to single layer — avoids per-tile GPU overhead
    }
}

// MARK: - Studio Background Modifier

struct StudioBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Color.studioSurface
                .ignoresSafeArea()
            NoiseOverlay()
                .ignoresSafeArea()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    /// Warm ivory surface with subtle noise microtexture.
    func studioBackground() -> some View {
        modifier(StudioBackground())
    }
}

// MARK: - Status Tag

extension Color {
    static func forStatus(_ status: String) -> Color {
        switch status {
        case "proposed": return .studioProposed
        case "client_approved": return .studioApproved
        case "rejected": return .studioRejected
        case "ordered": return .studioOrdered
        case "delivered": return .studioDelivered
        case "installed": return .studioInstalled
        default: return .studioSecondary
        }
    }
}
import SwiftUI

struct AppTheme {
    // Spacing
    static let spacingSmall: CGFloat = 8
    static let spacing: CGFloat = 12
    static let spacingLarge: CGFloat = 16
    static let cornerRadiusSmall: CGFloat = 10
    static let cornerRadius: CGFloat = 14
    static let cornerRadiusLarge: CGFloat = 18

    // Gradients
    static let brandGradient = LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let subtleBrand = LinearGradient(colors: [Color.blue.opacity(0.14), Color.purple.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.cornerRadiusLarge

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
    }
}

extension View {
    func glass(cornerRadius: CGFloat = AppTheme.cornerRadiusLarge) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}

struct PrimaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(AppTheme.brandGradient)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct ToastView: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text(text)
                .font(.subheadline).bold()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}



import SwiftUI

extension View {
    func innerShadow<S: Shape>(using shape: S, color: Color = .white.opacity(0.05), width: CGFloat = 4, blur: CGFloat = 20) -> some View {
        return self
            .overlay(
                shape
                    .stroke(color, lineWidth: width)
                    .blur(radius: blur)
                    .offset(x: width, y: width)
                    .mask(shape.fill(LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]), startPoint: .topLeading, endPoint: .bottomTrailing)))
            )
            .overlay(
                shape
                    .stroke(color, lineWidth: width)
                    .blur(radius: blur)
                    .offset(x: -width, y: -width)
                    .mask(shape.fill(LinearGradient(gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.6)]), startPoint: .topLeading, endPoint: .bottomTrailing)))
            )
    }
    
    func innerShadowBackground() -> some View {
        self
            .background(Color.primaryBackground)
            .overlay(
                // Subtle inner shadow effect
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .blur(radius: 20)
                    .offset(x: 2, y: 2)
                    .blendMode(.overlay)
            )
    }
}
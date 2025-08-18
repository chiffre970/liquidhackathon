import SwiftUI

struct FloatingActionButton: View {
    let title: String?
    let icon: String
    let action: () -> Void
    var isActive: Bool = false
    var showTitle: Bool = true
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Layer 1: Base layer (outer border and main background)
                // This is handled by the button container itself via UnifiedButtonStyle
                
                // Layer 2: Upper Highlight - positioned inside top area
                // Matches .unified__highlight-upper from Condor
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color(hex: "#D0E8FF").opacity(0.2), lineWidth: 1.5)
                    .blur(radius: 0.45)
                    .padding(.top, 2.5)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 5)
                
                // Layer 3: Lower Highlight - extends outside and clips naturally
                // Uses negative padding to extend beyond button bounds
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color(hex: "#D0E8FF").opacity(0.2), lineWidth: 1.5)
                    .blur(radius: 0.45)
                    .padding(.top, -3)
                    .padding(.horizontal, -2)
                    .padding(.bottom, -1)
                
                // Layer 4: Inner Fill - much darker blue
                // Very dark navy blue, almost black
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(hex: "#0A1628")) // Much darker blue, almost black
                        .padding(4)
                    
                    // Inset shadow effect
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.03)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(4)
                        .blendMode(.plusLighter)
                }
                .allowsHitTesting(false)
                
                // Layer 5: Text/Content layer - on top of everything
                // Matches .unified__text from Condor
                HStack(spacing: showTitle && title != nil ? 12 : 0) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .symbolEffect(.pulse, isActive: isActive)
                        .foregroundColor(isActive ? Color.red : Color.white)
                    
                    if showTitle, let title = title {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isActive ? Color.red : Color.white)
                    }
                }
                .zIndex(4)
            }
            .frame(height: 56) // Taller height  
        }
        .frame(maxWidth: .infinity) // Full width like search bar
        .padding(.horizontal, 16) // Match search bar horizontal padding
        .buttonStyle(UnifiedButtonStyle(isActive: isActive, isPressed: isPressed))
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// Custom button style to handle the base layer styling
// Matches the Condor .unified-element base styling
struct UnifiedButtonStyle: ButtonStyle {
    let isActive: Bool
    let isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                // Layer 1: Base layer with border and background
                // Dark background with subtle border
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(hex: "#1A1A2E")) // Slightly bluish dark background
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color(hex: "#2A2A3E"), lineWidth: 1)
                    )
            )
            // No shadow/glow - removed per request
            .scaleEffect(configuration.isPressed || isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed || isPressed)
    }
}
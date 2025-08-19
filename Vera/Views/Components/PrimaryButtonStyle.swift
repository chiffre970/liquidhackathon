import SwiftUI

struct FloatingActionButton: View {
    let title: String?
    let icon: String
    let action: () -> Void
    var isActive: Bool = false
    var showTitle: Bool = true
    var isAnalyzing: Bool = false
    
    @State private var isPressed = false
    @State private var textOpacity: Double = 1.0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Layer 1: Base layer (outer border and main background)
                // This is handled by the button container itself via UnifiedButtonStyle
                
                // Layer 2: Upper Highlight - positioned inside top area
                // Matches .unified__highlight-upper from Condor
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                    .blur(radius: 0.45)
                    .padding(.top, 4)
                    .padding(.horizontal, 5)
                    .padding(.bottom, 7)
                
                // Layer 3: Lower Highlight - positioned at bottom edge
                // Cuts off around the middle of the side curves
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                    .blur(radius: 0.45)
                    .padding(.top, -5)      // Extends above to cut off at side curve midpoint
                    .padding(.horizontal, -1)  // padding from edges
                    .padding(.bottom, 0)  // Flush with bottom edge (no gap)
                    .mask(RoundedRectangle(cornerRadius: 26)) // Mask to button shape to clip overflow
                
                // Layer 4: Inner Fill - much darker blue
                // Very dark navy blue, almost black
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(hex: "#101928")) // Inner fill color
                        .padding(4)
                    
                    // Inset shadow effect
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.05),
                                    Color.white.opacity(0.05)
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
                HStack(spacing: showTitle && title != nil && !icon.isEmpty ? 12 : 0) {
                    if !icon.isEmpty {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .symbolEffect(.pulse, isActive: isActive)
                            .foregroundColor(isActive ? Color.red : Color.white)
                    }
                    
                    if showTitle, let title = title {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isAnalyzing ? Color.secondaryText : (isActive ? Color.red : Color.white))
                            .opacity(isAnalyzing ? textOpacity : 1.0)
                    }
                }
                .zIndex(4)
            }
            .frame(height: 56) // Taller height  
        }
        .frame(maxWidth: .infinity) // Full width like search bar
        .padding(.horizontal, 16) // Match search bar horizontal padding
        .buttonStyle(UnifiedButtonStyle(isActive: isActive, isAnalyzing: isAnalyzing, isPressed: isPressed))
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            if isAnalyzing {
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    textOpacity = 0.3
                }
            }
        }
        .onChange(of: isAnalyzing) { newValue in
            if newValue {
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    textOpacity = 0.3
                }
            } else {
                withAnimation(.default) {
                    textOpacity = 1.0
                }
            }
        }
    }
}

// Custom button style to handle the base layer styling
// Matches the Condor .unified-element base styling
struct UnifiedButtonStyle: ButtonStyle {
    let isActive: Bool
    var isAnalyzing: Bool = false
    let isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                // Layer 1: Base layer with gradient border and background
                // Dark background with gradient border
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(hex: "#242F41")) // Much darker main fill
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "#475562"), // Top color (50% darker)
                                        Color(hex: "#333E48")  // Bottom color (50% darker)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
            )
            // No shadow/glow - removed per request
            .scaleEffect((configuration.isPressed || isPressed) && !isActive && !isAnalyzing ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: (configuration.isPressed || isPressed) && !isActive && !isAnalyzing)
    }
}
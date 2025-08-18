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
            HStack(spacing: showTitle && title != nil ? 12 : 0) {
                Image(systemName: icon)
                    .font(.title2)
                    .symbolEffect(.pulse, isActive: isActive)
                
                if showTitle, let title = title {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, showTitle ? 24 : 20)
            .padding(.vertical, showTitle ? 16 : 14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: isActive ? 
                        [Color.red, Color.red.opacity(0.8)] : 
                        [Color.blue, Color.blue.opacity(0.8)]
                    ),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(color: .black.opacity(0.15), radius: isPressed ? 5 : 10, x: 0, y: isPressed ? 2 : 5)
            .shadow(color: (isActive ? Color.red : Color.blue).opacity(0.3), radius: isPressed ? 10 : 20, x: 0, y: isPressed ? 5 : 10)
        }
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }, perform: {})
        .simultaneousGesture(TapGesture().onEnded { _ in
            action()
        })
    }
}
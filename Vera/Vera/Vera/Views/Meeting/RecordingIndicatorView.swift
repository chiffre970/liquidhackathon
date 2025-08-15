import SwiftUI

struct RecordingIndicatorView: View {
    let duration: TimeInterval
    
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Text("Recording")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            Text(formatDuration(duration))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.red.opacity(0.1))
        )
        .onAppear {
            isAnimating = true
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
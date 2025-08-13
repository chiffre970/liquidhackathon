import SwiftUI

struct RecordingIndicatorView: View {
    let duration: TimeInterval
    let isPaused: Bool
    
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isPaused ? Color.orange : Color.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(
                        isPaused ? .none : Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Text(isPaused ? "Paused" : "Recording")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isPaused ? .orange : .red)
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
            if !isPaused {
                isAnimating = true
            }
        }
        .onChange(of: isPaused) { oldValue, newValue in
            isAnimating = !newValue
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
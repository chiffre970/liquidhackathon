import SwiftUI

struct ParticleOrbView: View {
    @Binding var isRecording: Bool
    var audioLevel: Float
    
    @State private var particles: [Particle] = []
    @State private var animationTimer: Timer?
    
    let particleCount = 50
    let orbSize: CGFloat = 200
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                particle.color.opacity(0.8),
                                particle.color.opacity(0.3),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: particle.size / 2
                        )
                    )
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .blur(radius: isRecording ? 1 : 2)
                    .animation(.easeInOut(duration: particle.animationDuration), value: particle.position)
            }
            
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: orbSize / 2
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .scaleEffect(isRecording ? 1.1 + CGFloat(audioLevel * 0.3) : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isRecording)
                .animation(.easeInOut(duration: 0.1), value: audioLevel)
        }
        .frame(width: orbSize * 2, height: orbSize * 2)
        .onAppear {
            initializeParticles()
            startAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
        }
    }
    
    private func initializeParticles() {
        particles = (0..<particleCount).map { _ in
            Particle(
                position: randomPosition(),
                color: randomColor(),
                size: CGFloat.random(in: 20...60),
                animationDuration: Double.random(in: 3...8)
            )
        }
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            updateParticles()
        }
    }
    
    private func updateParticles() {
        for i in particles.indices {
            particles[i].position = randomPosition()
            
            if isRecording {
                let audioInfluence = CGFloat(audioLevel * 50)
                particles[i].position.x += CGFloat.random(in: -audioInfluence...audioInfluence)
                particles[i].position.y += CGFloat.random(in: -audioInfluence...audioInfluence)
            }
        }
    }
    
    private func randomPosition() -> CGPoint {
        let angle = Double.random(in: 0...(2 * .pi))
        let radius = CGFloat.random(in: 30...orbSize)
        
        return CGPoint(
            x: orbSize + radius * CGFloat(cos(angle)),
            y: orbSize + radius * CGFloat(sin(angle))
        )
    }
    
    private func randomColor() -> Color {
        let colors: [Color] = [
            Color(red: 1.0, green: 0.41, blue: 0.71),
            Color(red: 0.58, green: 0.44, blue: 0.86),
            Color(red: 0.25, green: 0.41, blue: 0.88),
            Color(red: 0.86, green: 0.08, blue: 0.24)
        ]
        return colors.randomElement() ?? colors[0]
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var color: Color
    var size: CGFloat
    var animationDuration: Double
}
import SwiftUI

// MARK: - Empty Library View
// Animated empty state view for first-time users or when library is empty.
// Features SF Symbol animation and engaging call-to-action.

struct EmptyLibraryView: View {
    @State private var isAnimating = false
    @State private var pulseAnimation = false
    @State private var rotationAngle: Double = 0
    
    let onImportTapped: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 32) {
                Spacer()
                
                // Animated Music Icon
                ZStack {
                    // Background pulse circle
                    Circle()
                        .fill(Color.accentGreen.opacity(0.1))
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0.3 : 0.6)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                    
                    // Secondary pulse circle
                    Circle()
                        .fill(Color.accentGreen.opacity(0.08))
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulseAnimation ? 1.4 : 1.1)
                        .opacity(pulseAnimation ? 0.0 : 0.4)
                        .animation(
                            .easeInOut(duration: 2.5)
                            .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                    
                    // Main music icon
                    VStack(spacing: 8) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.accentGreen)
                            .scaleEffect(isAnimating ? 1.1 : 0.9)
                            .rotationEffect(.degrees(rotationAngle))
                            .animation(
                                .spring(response: 1.2, dampingFraction: 0.8)
                                .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                        
                        // Small floating notes
                        HStack(spacing: 16) {
                            Image(systemName: "music.note")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.accentGreen.opacity(0.7))
                                .offset(y: isAnimating ? -8 : 8)
                                .animation(
                                    .easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(0.3),
                                    value: isAnimating
                                )
                            
                            Image(systemName: "music.note")
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(.accentGreen.opacity(0.5))
                                .offset(y: isAnimating ? 8 : -8)
                                .animation(
                                    .easeInOut(duration: 1.8)
                                    .repeatForever(autoreverses: true)
                                    .delay(0.6),
                                    value: isAnimating
                                )
                        }
                    }
                }
                .frame(width: 200, height: 200)
                
                // Text Content
                VStack(spacing: 16) {
                    Text("Your Music Library is Empty")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text("Import your favorite songs from files, cloud storage, or Apple Music to get started")
                        .font(.body)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .lineLimit(3)
                }
                .opacity(isAnimating ? 1.0 : 0.8)
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                
                // Import Button
                Button(action: onImportTapped) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                        
                        Text("Import Your Music")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.accentGreen, .accentGreen.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .accentGreen.opacity(0.3), radius: 8, x: 0, y: 4)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(
                        .spring(response: 0.8, dampingFraction: 0.6)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Quick tips
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.accentGreen.opacity(0.7))
                        
                        Text("Tip: Files are streamed from cloud storage - no local space needed!")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color.secondaryBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .opacity(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
        }
        .background(Color.primaryBackground.ignoresSafeArea())
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Start main animation
        withAnimation {
            isAnimating = true
        }
        
        // Start pulse animation
        withAnimation {
            pulseAnimation = true
        }
        
        // Start rotation animation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
}

// MARK: - Preview
struct EmptyLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyLibraryView {
            print("Import tapped")
        }
        .preferredColorScheme(.dark)
    }
}
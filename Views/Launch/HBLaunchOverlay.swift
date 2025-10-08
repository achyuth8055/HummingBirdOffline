import SwiftUI
import Combine

struct HBLaunchOverlay: View {
    @ObservedObject var model = LaunchProgressModel.shared

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.primaryBackground], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.secondaryBackground)
                        .frame(width: 84, height: 84)
                    Image(systemName: "music.note")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.accentGreen)
                }
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                .scaleEffect(model.done ? 0.96 : 1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.85), value: model.done)

                Text("HummingBirdOffline")
                    .font(.title3.weight(.bold))

                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondaryBackground).frame(height: 6)
                    Capsule()
                        .fill(Color.accentGreen)
                        .frame(width: max(6, CGFloat(model.progress) * 220), height: 6)
                        .animation(.easeOut(duration: 0.25), value: model.progress)
                }
                .frame(width: 220)

                Text("\(Int(model.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
        .opacity(model.done ? 0 : 1)
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: model.done)
        .allowsHitTesting(!model.done)
        .task { LaunchProgressModel.shared.startTimeout() }
    }
}

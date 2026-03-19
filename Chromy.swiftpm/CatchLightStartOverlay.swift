import SwiftUI
import UIKit

struct CatchLightStartOverlay: View {
    let onStart: () -> Void
    private var isCompactPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) <= 430
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.40), Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                Text("Welcome kiddo")
                    .font(.system(size: isCompactPhone ? 42 : 56, weight: .black, design: .default))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .shadow(color: .white.opacity(0.25), radius: 12)

                Text("Use your finger to move around the forest")
                    .font(.system(size: isCompactPhone ? 23 : 30, weight: .bold, design: .default))
                    .foregroundStyle(.white.opacity(0.96))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
                    .padding(.top, 6)

                Button(action: onStart) {
                    Text("Play")
                        .font(.system(size: isCompactPhone ? 21 : 24, weight: .heavy, design: .default))
                        .foregroundStyle(.white)
                        .padding(.horizontal, isCompactPhone ? 28 : 34)
                        .padding(.vertical, isCompactPhone ? 9 : 10)
                        .background(Color.black.opacity(0.72))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.95), lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }

                Spacer()
            }
        }
    }
}

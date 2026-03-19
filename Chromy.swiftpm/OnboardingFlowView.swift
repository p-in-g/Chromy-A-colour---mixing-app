import SwiftUI

struct OnboardingFlowView: View {
    let page: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    private var pageTitle: String {
        switch page {
        case 0: return "WELCOME KIDDO"
        case 1: return "How to move"
        case 2: return "Before it fades"
        default: return "Mix the spell"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.47, blue: 0.78), Color(red: 0.04, green: 0.24, blue: 0.46)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    Button("Skip", action: onSkip)
                        .font(.system(size: 26, weight: .heavy, design: .default))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                Text(pageTitle)
                    .font(.system(size: 56, weight: .black, design: .default))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)

                pageContent
                    .padding(.horizontal, 24)

                Spacer()

                HStack {
                    PageDots(current: page)
                    Spacer()
                    Button(action: onNext) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case 0:
            VStack(spacing: 18) {
                Text("You are SPARKY the SORCERER!!")
                    .font(.system(size: 44, weight: .heavy, design: .default))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
        case 1:
            VStack(spacing: 26) {
                VStack(spacing: 10) {
                    Text("Move your finger to move around the forest")
                        .font(.system(size: 34, weight: .heavy, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    InfinityFingerAnimation()
                }

                VStack(spacing: 10) {
                    Text("Double tap to jump")
                        .font(.system(size: 34, weight: .heavy, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    DoubleTapFingerAnimation()
                }
            }
        case 2:
            VStack(spacing: 14) {
                Text("Choose your spell before the colours fade")
                    .font(.system(size: 34, weight: .heavy, design: .default))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                FadingColorsPreviewCard()
            }
        default:
            VStack(spacing: 14) {
                Text("Mix the colours by choosing the target")
                    .font(.system(size: 34, weight: .heavy, design: .default))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                MixingFlowPreviewCard()
            }
        }
    }
}

private struct PageDots: View {
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { idx in
                Circle()
                    .fill(idx == current ? Color.white : Color.white.opacity(0.35))
                    .frame(width: idx == current ? 12 : 9, height: idx == current ? 12 : 9)
            }
        }
    }
}

private struct InfinityFingerAnimation: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * 1.2
            let x = CGFloat(sin(t)) * 68
            let y = CGFloat(sin(t * 2)) * 18

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.25))

                Image(systemName: "infinity")
                    .font(.system(size: 62, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))

                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(.white)
                    .offset(x: x, y: y)
            }
            .frame(height: 140)
        }
    }
}

private struct DoubleTapFingerAnimation: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.25))

            Circle()
                .stroke(Color.white.opacity(0.80), lineWidth: 2)
                .frame(width: pulse ? 88 : 40, height: pulse ? 88 : 40)
                .opacity(pulse ? 0 : 1)

            Circle()
                .stroke(Color.white.opacity(0.66), lineWidth: 2)
                .frame(width: pulse ? 62 : 32, height: pulse ? 62 : 32)
                .opacity(pulse ? 0 : 1)

            Image(systemName: "hand.tap.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
                .scaleEffect(pulse ? 0.95 : 1.08)
        }
        .frame(height: 120)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

private struct FadingColorsPreviewCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.12, green: 0.75, blue: 0.95), Color(red: 0.10, green: 0.55, blue: 0.80)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.gray.opacity(0.45))

            VStack(spacing: 8) {
                Text("Colours will go out in 10 sec")
                    .font(.system(size: 24, weight: .black, design: .default))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Capsule())

                Spacer()

                HStack(spacing: 20) {
                    MiniTree()
                    MiniTree()
                    MiniTree()
                }
                .padding(.bottom, 18)
            }
            .padding(.top, 14)
        }
        .frame(height: 260)
        .shadow(color: .black.opacity(0.3), radius: 12)
    }
}

private struct MixingFlowPreviewCard: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.30))
                .overlay {
                    VStack(spacing: 10) {
                        Text("Choose Spell")
                            .font(.system(size: 22, weight: .black, design: .default))
                            .foregroundStyle(.white)
                        Circle()
                            .fill(LinearGradient(colors: [.mint, .blue], startPoint: .top, endPoint: .bottom))
                            .frame(width: 70, height: 70)
                        HStack(spacing: 8) {
                            Capsule().fill(Color.orange).frame(width: 62, height: 26)
                            Capsule().fill(Color.cyan).frame(width: 62, height: 26)
                        }
                    }
                    .padding(12)
                }

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.30))
                .overlay {
                    VStack(spacing: 10) {
                        Text("Sorcerer's Lab")
                            .font(.system(size: 22, weight: .black, design: .default))
                            .foregroundStyle(.white)
                        HStack(spacing: 10) {
                            Circle().fill(.white).frame(width: 60, height: 60)
                            Circle().fill(.purple).frame(width: 60, height: 60)
                        }
                        Capsule()
                            .fill(Color.yellow)
                            .frame(width: 120, height: 30)
                    }
                    .padding(12)
                }
        }
        .frame(height: 260)
        .shadow(color: .black.opacity(0.3), radius: 12)
    }
}

private struct MiniTree: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.green.opacity(0.90)).frame(width: 34, height: 26)
            Rectangle().fill(Color.green.opacity(0.80)).frame(width: 54, height: 20)
            Rectangle().fill(Color(red: 0.40, green: 0.20, blue: 0.08)).frame(width: 12, height: 30)
        }
    }
}

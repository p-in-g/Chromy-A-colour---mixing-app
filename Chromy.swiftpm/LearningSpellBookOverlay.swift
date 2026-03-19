import SwiftUI
import UIKit

struct LearningLab: View {
    let practicedTargetNames: Set<String>
    let onPractice: (String) -> Void
    let onClose: () -> Void

    @State private var sourceColors: [Color?] = [nil, nil]
    @State private var selectedSourceIndex = 0

    private let entries: [LearningFormulaEntry] = [
        .init(targetName: "Sunny-Spark (Orange)", color: .orange, formulaComponents: ["Red", "Yellow"]),
        .init(targetName: "Violet-Lark (Violet)", color: .purple, formulaComponents: ["Red", "Blue"]),
        .init(targetName: "Emerald-Wisp (Green)", color: .green, formulaComponents: ["Blue", "Yellow"]),
        .init(targetName: "Ember Flame (Red-Orange)", color: Color(red: 0.93, green: 0.33, blue: 0.12), formulaComponents: ["Red", "Orange"]),
        .init(targetName: "Sunrise Glow (Yellow-Orange)", color: Color(red: 0.96, green: 0.66, blue: 0.12), formulaComponents: ["Yellow", "Orange"]),
        .init(targetName: "Spring Spark (Yellow-Green)", color: Color(red: 0.62, green: 0.78, blue: 0.18), formulaComponents: ["Yellow", "Green"]),
        .init(targetName: "Ocean Whisper (Blue-Green)", color: Color(red: 0.14, green: 0.66, blue: 0.62), formulaComponents: ["Blue", "Green"]),
        .init(targetName: "Twilight Mist (Blue-Purple)", color: Color(red: 0.40, green: 0.34, blue: 0.88), formulaComponents: ["Blue", "Purple"]),
        .init(targetName: "Mystic Bloom (Red-Purple)", color: Color(red: 0.68, green: 0.22, blue: 0.56), formulaComponents: ["Red", "Purple"])
    ]

    private let palette: [Color] = [
        .red,
        .yellow,
        .blue,
        .orange,
        .green,
        .purple
    ]
    private let labTargets: [(name: String, color: Color)] = [
        ("Ember Flame (Red-Orange)", Color(red: 0.93, green: 0.33, blue: 0.12)),
        ("Sunrise Glow (Yellow-Orange)", Color(red: 0.96, green: 0.66, blue: 0.12)),
        ("Spring Spark (Yellow-Green)", Color(red: 0.62, green: 0.78, blue: 0.18)),
        ("Ocean Whisper (Blue-Green)", Color(red: 0.14, green: 0.66, blue: 0.62)),
        ("Twilight Mist (Blue-Purple)", Color(red: 0.40, green: 0.34, blue: 0.88)),
        ("Mystic Bloom (Red-Purple)", Color(red: 0.68, green: 0.22, blue: 0.56)),
        ("Sunny-Spark (Orange)", Color(red: 0.96, green: 0.56, blue: 0.10)),
        ("Violet-Lark (Violet)", Color(red: 0.54, green: 0.30, blue: 0.82)),
        ("Emerald-Wisp (Green)", Color(red: 0.14, green: 0.66, blue: 0.34))
    ]

    private var current: LearningFormulaEntry {
        entries.first(where: { !practicedTargetNames.contains($0.targetName) }) ?? entries[0]
    }

    private var mixedColor: Color {
        guard let first = sourceColors[0], let second = sourceColors[1] else { return .clear }
        return averagedColor(first, second)
    }
    private var hasMixedColor: Bool {
        sourceColors[0] != nil && sourceColors[1] != nil
    }

    var body: some View {
        GeometryReader { geo in
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let isCompactLayout = geo.size.width < 700 || geo.size.height < 500
            let orbSize = (isPhone && isCompactLayout)
                ? min(92, max(70, (geo.size.width - 220) / 3))
                : isCompactLayout
                ? min(104, max(76, (geo.size.width - 90) / 3))
                : min(154, max(90, (geo.size.width - 64) / 3))
            let paletteSize: CGFloat = isCompactLayout ? 44 : 52

            ZStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.92), Color(red: 0.12, green: 0.08, blue: 0.18).opacity(0.96)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                LearningTinyStarsBackground()
                    .allowsHitTesting(false)

                VStack(spacing: isCompactLayout ? 10 : 16) {
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: isCompactLayout ? 36 : 44, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 8)

                    Text("Learn basic colours")
                        .font(.system(size: isCompactLayout ? 28 : 34, weight: .heavy, design: .default))
                        .foregroundStyle(.white.opacity(0.95))

                    Spacer(minLength: isCompactLayout ? 0 : 8)

                    if isPhone && isCompactLayout {
                        HStack(alignment: .center, spacing: 6) {
                            sourceCrystal(index: 0, orbSize: orbSize)
                            sourceCrystal(index: 1, orbSize: orbSize)
                            PracticeCrystal(
                                color: sourceColors[0] != nil && sourceColors[1] != nil ? mixedColor : nil,
                                title: "Mixed",
                                isSelected: false,
                                subtitle: sourceColors[0] != nil && sourceColors[1] != nil ? "Ready" : "Result",
                                orbSize: orbSize
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        HStack(alignment: .center, spacing: isCompactLayout ? 8 : 12) {
                            sourceCrystal(index: 0, orbSize: orbSize)
                            sourceCrystal(index: 1, orbSize: orbSize)
                            PracticeCrystal(
                                color: sourceColors[0] != nil && sourceColors[1] != nil ? mixedColor : nil,
                                title: "Mixed Colour",
                                isSelected: false,
                                subtitle: sourceColors[0] != nil && sourceColors[1] != nil ? "Ready" : "Mix Result",
                                orbSize: orbSize
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        Spacer(minLength: isCompactLayout ? 8 : 16)

                        HStack(spacing: 12) {
                            Button("Reset Crystal Colours") {
                                sourceColors = [nil, nil]
                                selectedSourceIndex = 0
                            }
                            .font(.system(size: isPad ? 30 : 24, weight: .heavy, design: .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, isPad ? 34 : 24)
                            .padding(.vertical, isPad ? 16 : 12)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())

                            Button("Find Yourself") {
                                guard hasMixedColor else { return }
                                onPractice(nearestLabTargetName(for: mixedColor))
                            }
                            .font(.system(size: isPad ? 30 : 24, weight: .heavy, design: .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, isPad ? 34 : 24)
                            .padding(.vertical, isPad ? 16 : 12)
                            .background(Color.orange.opacity(0.82))
                            .clipShape(Capsule())
                            .disabled(!hasMixedColor)
                            .opacity(hasMixedColor ? 1.0 : 0.45)
                        }
                    }

                    Spacer(minLength: isPhone && isCompactLayout ? 4 : 0)

                    Text("Palette")
                        .font(.system(size: isCompactLayout ? 18 : 22, weight: .bold, design: .default))
                        .foregroundStyle(.white)

                    if isPhone && isCompactLayout {
                        HStack(spacing: 10) {
                            Button("Reset") {
                                sourceColors = [nil, nil]
                                selectedSourceIndex = 0
                            }
                            .font(.system(size: 15, weight: .heavy, design: .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(width: 116)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())

                            HStack(spacing: 8) {
                                ForEach(Array(palette.enumerated()), id: \.offset) { _, color in
                                    Button {
                                        applyPaletteColor(color)
                                    } label: {
                                        Circle()
                                            .fill(color)
                                            .frame(width: paletteSize, height: paletteSize)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white.opacity(0.92), lineWidth: 2)
                                            )
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)

                            Button("Practice") {
                                guard hasMixedColor else { return }
                                onPractice(nearestLabTargetName(for: mixedColor))
                            }
                            .font(.system(size: 15, weight: .heavy, design: .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(width: 116)
                            .background(Color.orange.opacity(0.82))
                            .clipShape(Capsule())
                            .disabled(!hasMixedColor)
                            .opacity(hasMixedColor ? 1.0 : 0.45)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        if isPad {
                            HStack(spacing: 10) {
                                ForEach(Array(palette.enumerated()), id: \.offset) { _, color in
                                    Button {
                                        applyPaletteColor(color)
                                    } label: {
                                        Circle()
                                            .fill(color)
                                            .frame(width: paletteSize, height: paletteSize)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white.opacity(0.92), lineWidth: 2)
                                            )
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Array(palette.enumerated()), id: \.offset) { _, color in
                                        Button {
                                            applyPaletteColor(color)
                                        } label: {
                                            Circle()
                                                .fill(color)
                                                .frame(width: paletteSize, height: paletteSize)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white.opacity(0.92), lineWidth: 2)
                                                )
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, isCompactLayout ? 8 : 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private func sourceCrystal(index: Int, orbSize: CGFloat) -> some View {
        PracticeCrystal(
            color: sourceColors[index],
            title: index == 0 ? "Colour 1" : "Colour 2",
            isSelected: selectedSourceIndex == index,
            subtitle: sourceColors[index] == nil ? "Tap to select" : "Selected",
            orbSize: orbSize
        )
        .onTapGesture {
            selectedSourceIndex = index
        }
    }

    private func applyPaletteColor(_ color: Color) {
        sourceColors[selectedSourceIndex] = color
        selectedSourceIndex = selectedSourceIndex == 0 ? 1 : 0
    }

    private func averagedColor(_ first: Color, _ second: Color) -> Color {
        let a = rgbComponents(from: UIColor(first))
        let b = rgbComponents(from: UIColor(second))
        return Color(red: (a.r + b.r) * 0.5, green: (a.g + b.g) * 0.5, blue: (a.b + b.b) * 0.5)
    }

    private func rgbComponents(from color: UIColor) -> (r: Double, g: Double, b: Double) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    private func nearestLabTargetName(for color: Color) -> String {
        let pick = rgbComponents(from: UIColor(color))
        let nearest = labTargets.min { a, b in
            let da = distance(pick, rgbComponents(from: UIColor(a.color)))
            let db = distance(pick, rgbComponents(from: UIColor(b.color)))
            return da < db
        }
        return nearest?.name ?? current.targetName
    }

    private func distance(_ a: (r: Double, g: Double, b: Double), _ b: (r: Double, g: Double, b: Double)) -> Double {
        let dr = a.r - b.r
        let dg = a.g - b.g
        let db = a.b - b.b
        return sqrt((dr * dr) + (dg * dg) + (db * db))
    }
}

private struct LearningTinyStarsBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for i in 0..<85 {
                    let seed = Double(i) * 0.713
                    let x = CGFloat((sin(seed * 11.0) + 1) * 0.5) * size.width
                    let y = CGFloat((cos(seed * 7.3) + 1) * 0.5) * size.height
                    let twinkle = (sin((t * 2.0) + seed * 2.4) + 1) * 0.5
                    let r = CGFloat(0.7 + (twinkle * 1.4))
                    let alpha = 0.08 + (twinkle * 0.22)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                        with: .color(Color.white.opacity(alpha))
                    )
                }
            }
        }
    }
}

private struct PracticeCrystal: View {
    let color: Color?
    let title: String
    let isSelected: Bool
    let subtitle: String
    let orbSize: CGFloat
    @State private var shimmer = false

    var body: some View {
        let compact = orbSize <= 104
        let innerSize: CGFloat = orbSize * 0.95
        let coreSize: CGFloat = orbSize * 0.82

        return VStack(spacing: compact ? 6 : 10) {
            ZStack {
                Circle()
                    .fill((color ?? Color.white.opacity(0.08)).opacity(color == nil ? 0.45 : 0.96))
                    .frame(width: orbSize, height: orbSize)

                Circle()
                    .stroke(
                        isSelected
                        ? Color.yellow.opacity(0.98)
                        : (color ?? .white).opacity(color == nil ? 0.52 : 0.92),
                        lineWidth: isSelected ? 4 : 3
                    )
                    .frame(width: orbSize, height: orbSize)

                if let color {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.34), color.opacity(0.04), .clear],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 64
                            )
                        )
                        .frame(width: innerSize, height: innerSize)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: coreSize, height: coreSize)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.45), lineWidth: 1.5)
                        )
                        .opacity(shimmer ? 1.0 : 0.55)
                }
            }
            .shadow(color: (color ?? .white).opacity(0.25), radius: 10)

            Text(title)
                .font(.system(size: compact ? 13 : 16, weight: .heavy, design: .default))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .frame(maxWidth: orbSize + 16)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: compact ? 11 : 13, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.86))
                .frame(maxWidth: orbSize + 16)
                .lineLimit(1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

private struct LearningFormulaEntry {
    let targetName: String
    let color: Color
    let formulaComponents: [String]
}

import AudioToolbox
import AVFoundation
import SwiftUI
import UIKit

struct SorcerersLabFlowView: View {
    let onClose: () -> Void
    let onCastSpell: (Color, String) -> Void
    let excludedTargetNames: Set<String>
    let preferredTargetName: String?

    @State private var target: SorcerersLabTarget
    @State private var sourceColors: [Color?] = [nil, nil]
    @State private var captureIndex: Int?
    @State private var mixOverrideColor: Color?
    @State private var mixDropTrigger = 0
    @State private var mixDropColor: Color = .clear
    @State private var showConfetti = false

    init(
        onClose: @escaping () -> Void,
        onCastSpell: @escaping (Color, String) -> Void,
        excludedTargetNames: Set<String> = [],
        preferredTargetName: String? = nil
    ) {
        self.onClose = onClose
        self.onCastSpell = onCastSpell
        self.excludedTargetNames = excludedTargetNames
        self.preferredTargetName = preferredTargetName
        if let preferredTargetName,
           let target = SorcerersLabPalette.target(named: preferredTargetName) {
            _target = State(initialValue: target)
        } else {
            _target = State(initialValue: SorcerersLabPalette.randomTarget(excluding: excludedTargetNames))
        }
    }

    private var bothFilled: Bool {
        sourceColors.allSatisfy { $0 != nil }
    }

    private var hasMixAvailable: Bool {
        bothFilled
    }

    private var isApproxMatch: Bool {
        bothFilled && matchDistance < castMatchThreshold
    }

    private var castMatchThreshold: Double {
        target.name.contains("Mystic Bloom") ? 0.28 : 0.20
    }

    private var capturedMixColor: Color {
        guard let c1 = sourceColors[0], let c2 = sourceColors[1] else { return .clear }
        let a = rgbComponents(from: UIColor(c1))
        let b = rgbComponents(from: UIColor(c2))
        return Color(red: (a.r + b.r) * 0.5, green: (a.g + b.g) * 0.5, blue: (a.b + b.b) * 0.5)
    }

    private var mixedColor: Color {
        bothFilled ? (mixOverrideColor ?? capturedMixColor) : .clear
    }

    private var matchDistance: Double {
        guard bothFilled else { return 1 }
        let mix = rgbComponents(from: UIColor(mixedColor))
        let targetRGB = rgbComponents(from: UIColor(target.color))
        let dr = mix.r - targetRGB.r
        let dg = mix.g - targetRGB.g
        let db = mix.b - targetRGB.b
        return sqrt((dr * dr) + (dg * dg) + (db * db))
    }

    var body: some View {
        GeometryReader { geo in
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            let iphonePaletteRailWidth: CGFloat = 102
            let iphonePaletteRailGap: CGFloat = 10
            let paletteReservedWidth: CGFloat = (isPhone && hasMixAvailable) ? (iphonePaletteRailWidth + iphonePaletteRailGap) : 0
            let horizontalPadding: CGFloat = isPhone ? 14 : 18
            let orbSpacing: CGFloat = isPhone ? 8 : 12
            let maxOrbWidth = (geo.size.width - (horizontalPadding * 2) - (orbSpacing * 3) - paletteReservedWidth) / 4
            let phoneOrbCap: CGFloat = geo.size.height < 760 ? 96 : 104
            let orbSize = isPhone
                ? min(phoneOrbCap, max(60, maxOrbWidth))
                : min(154, max(72, maxOrbWidth))
            let isCompactHeight = geo.size.height < 560

            ZStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.92), Color(red: 0.12, green: 0.08, blue: 0.18).opacity(0.96)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                TinyStarsBackground()
                    .allowsHitTesting(false)

                VStack(spacing: isCompactHeight ? 10 : 16) {
                    ZStack {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: isCompactHeight ? 34 : 44, weight: .semibold))
                                .opacity(0)
                            Spacer()
                            Text("Sorcerer's Lab")
                                .font(.system(size: isCompactHeight ? 30 : 38, weight: .black, design: .default))
                                .foregroundStyle(.white)
                            Spacer()
                            Button(action: onClose) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: isCompactHeight ? 36 : 44, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.95))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                    Text("What makes the target colour??")
                        .font(.system(size: isCompactHeight ? 22 : 26, weight: .heavy, design: .default))
                        .foregroundStyle(.white.opacity(0.94))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)

                    Spacer(minLength: 0)

                    HStack(alignment: .top, spacing: orbSpacing) {
                        crystalButton(index: 0, orbSize: orbSize)
                        crystalButton(index: 1, orbSize: orbSize)
                        mixCrystal(orbSize: orbSize)
                        crystalTarget(orbSize: orbSize)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.leading, paletteReservedWidth)
                    .frame(maxWidth: .infinity)

                    Button("Cast Spell") {
                        castSpell()
                    }
                    .font(.system(size: isCompactHeight ? (isPad ? 20 : 16) : 20, weight: .heavy, design: .default))
                    .foregroundStyle(.white)
                    .padding(.horizontal, isCompactHeight ? 18 : 24)
                    .padding(.vertical, isCompactHeight ? 9 : 11)
                    .background(isApproxMatch ? Color.green.opacity(0.86) : Color.white.opacity(0.20))
                    .clipShape(Capsule())
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .disabled(!isApproxMatch)
                    .opacity(isApproxMatch ? 1.0 : 0.55)

                    HStack(spacing: 12) {
                        Button("Reset Crystals") {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                sourceColors = [nil, nil]
                            }
                        }
                        .font(.system(size: isCompactHeight ? 15 : 18, weight: .heavy, design: .default))
                        .foregroundStyle(.white)
                        .padding(.horizontal, isCompactHeight ? 14 : 20)
                        .padding(.vertical, isCompactHeight ? 9 : 10)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                        .disabled(!sourceColors.contains(where: { $0 != nil }))

                        Button("Close Lab") { onClose() }
                            .font(.system(size: isCompactHeight ? 15 : 18, weight: .heavy, design: .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, isCompactHeight ? 14 : 20)
                            .padding(.vertical, isCompactHeight ? 9 : 10)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                    }

                    Spacer(minLength: isCompactHeight ? 4 : 10)
                }

                if isPhone, hasMixAvailable {
                    let safePaletteHeight = max(220, geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom)
                    iphoneFixPaletteSection
                        .padding(.leading, max(8, geo.safeAreaInsets.leading + 6))
                        .padding(.top, geo.safeAreaInsets.top + 6)
                        .frame(height: safePaletteHeight, alignment: .top)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if hasMixAvailable && UIDevice.current.userInterfaceIdiom != .phone {
                fixPaletteSection
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
            }
        }
        .overlay {
            if showConfetti {
                MagicStarsOverlay()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: sourceSignature) {
            mixOverrideColor = nil
            evaluateMixResult()
        }
        .fullScreenCover(isPresented: Binding(
            get: { captureIndex != nil },
            set: { shown in if !shown { captureIndex = nil } }
        )) {
            if let idx = captureIndex {
                FindColourCaptureView(
                    onCancel: { captureIndex = nil },
                    onInfuse: { color in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            sourceColors[idx] = color
                        }
                        captureIndex = nil
                    }
                )
            }
        }
    }

    private func crystalButton(index: Int, orbSize: CGFloat) -> some View {
        VStack(spacing: 8) {
            Button {
                captureIndex = index
            } label: {
                CrystalOrb(
                    color: sourceColors[index],
                    isTarget: false,
                    label: sourceColors[index].map { friendlyCapturedName(for: $0) } ?? "Find the colour",
                    showCameraPrompt: sourceColors[index] == nil,
                    orbSize: orbSize
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func crystalTarget(orbSize: CGFloat) -> some View {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let targetLabel: String
        if isPhone {
            targetLabel = "\(displayTargetName(from: target.name))\n(Target)"
        } else {
            targetLabel = target.name
        }
        return CrystalOrb(color: target.color, isTarget: true, label: targetLabel, orbSize: orbSize)
    }

    private func mixCrystal(orbSize: CGFloat) -> some View {
        ZStack(alignment: .top) {
            CrystalOrb(
                color: bothFilled ? mixedColor : nil,
                isTarget: false,
                label: "Your Mix",
                mixingColors: bothFilled ? [sourceColors[0] ?? .clear, sourceColors[1] ?? .clear] : [],
                orbSize: orbSize
            )
            PaletteDropView(
                color: mixDropColor,
                trigger: mixDropTrigger
            )
            .offset(y: -24)
        }
    }

    private var sourceSignature: String {
        sourceColors.map { color in
            guard let color else { return "nil" }
            let rgb = rgbComponents(from: UIColor(color))
            return "\(Int(rgb.r * 255))-\(Int(rgb.g * 255))-\(Int(rgb.b * 255))"
        }
        .joined(separator: "|")
    }

    private func evaluateMixResult() {
        guard bothFilled else {
            mixOverrideColor = nil
            return
        }
    }

    private var fixPaletteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fix your colour")
                .font(.system(size: 20, weight: .heavy, design: .default))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(SorcerersLabPalette.fixColors.enumerated()), id: \.offset) { _, palette in
                        Button {
                            applyPaletteColor(palette.color)
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(palette.color)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.9), lineWidth: 2)
                                    )
                                Text(palette.name)
                                    .font(.system(size: 11, weight: .bold, design: .default))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineLimit(1)
                            }
                            .frame(width: 66)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var iphoneFixPaletteSection: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Fix your colour")
                .font(.system(size: 15, weight: .heavy, design: .default))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(SorcerersLabPalette.fixColors.enumerated()), id: \.offset) { _, palette in
                        Button {
                            applyPaletteColor(palette.color)
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(palette.color)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.8)
                                    )
                                Text(palette.name)
                                    .font(.system(size: 9, weight: .bold, design: .default))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .lineLimit(1)
                            }
                            .frame(width: 64)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 102)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 10)
        .padding(.horizontal, 7)
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func applyPaletteColor(_ color: Color) {
        guard bothFilled else { return }
        let currentMix = UIColor(mixedColor)
        let injected = UIColor(color)
        let a = rgbComponents(from: currentMix)
        let b = rgbComponents(from: injected)
        let next = Color(
            red: (a.r * 0.70) + (b.r * 0.30),
            green: (a.g * 0.70) + (b.g * 0.30),
            blue: (a.b * 0.70) + (b.b * 0.30)
        )

        withAnimation(.easeInOut(duration: 0.2)) {
            mixOverrideColor = next
        }
        AudioServicesPlaySystemSound(1104)
        mixDropColor = color
        mixDropTrigger += 1
    }

    private func castSpell() {
        guard bothFilled, isApproxMatch else { return }
        let castColor = mixedColor
        let castTargetName = target.name
        showConfetti = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 780_000_000)
            withAnimation(.easeOut(duration: 0.25)) {
                showConfetti = false
            }
            onCastSpell(castColor, castTargetName)
        }
    }

    private func friendlyCapturedName(for color: Color) -> String {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let h = Double(hue) * 360.0
        let s = Double(saturation)
        let b = Double(brightness)

        if b < 0.18 { return "Black" }
        if s < 0.12 && b > 0.85 { return "White" }
        if s < 0.16 { return "Gray" }

        switch h {
        case 0..<15, 345...360:
            return "Red"
        case 15..<35:
            return "Red-Orange"
        case 35..<50:
            return "Orange"
        case 50..<68:
            return "Yellow-Orange"
        case 68..<95:
            return "Yellow"
        case 95..<150:
            return "Yellow-Green"
        case 150..<185:
            return "Green"
        case 185..<210:
            return "Blue-Green"
        case 210..<250:
            return "Blue"
        case 250..<285:
            return "Blue-Purple"
        case 285..<320:
            return "Purple"
        default:
            return "Red-Purple"
        }
    }

    private func displayTargetName(from targetName: String) -> String {
        if let openParen = targetName.firstIndex(of: "(") {
            return targetName[..<openParen].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return targetName
    }
}

private struct TinyStarsBackground: View {
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

private struct CrystalOrb: View {
    let color: Color?
    let isTarget: Bool
    let label: String
    var mixingColors: [Color] = []
    var showCameraPrompt: Bool = false
    var orbSize: CGFloat = 154

    @State private var shimmer = false

    var body: some View {
        let innerSize: CGFloat = orbSize * 0.95
        let coreSize: CGFloat = orbSize * 0.82
        let mixSize: CGFloat = orbSize * 0.82
        let verticalSpacing: CGFloat = orbSize < 110 ? 6 : 10

        VStack(spacing: verticalSpacing) {
            ZStack {
                Circle()
                    .fill((color ?? Color.white.opacity(0.08)).opacity(isTarget ? 0.98 : (color == nil ? 0.45 : 0.96)))
                    .frame(width: orbSize, height: orbSize)

                Circle()
                    .stroke((color ?? .white).opacity(isTarget ? 0.98 : (color == nil ? 0.52 : 0.92)), lineWidth: isTarget ? 4 : 3)
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
                }

                if !isTarget, mixingColors.count == 2, let color {
                    CrystalFluidMixView(colorA: mixingColors[0], colorB: mixingColors[1], mixColor: color)
                        .frame(width: mixSize, height: mixSize)
                        .clipShape(Circle())
                }

                if color == nil {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: coreSize, height: coreSize)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.45), lineWidth: 1.5)
                        )
                        .opacity(shimmer ? 1.0 : 0.55)

                    if showCameraPrompt {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: max(18, orbSize * 0.16), weight: .black))
                            .foregroundStyle(.white)
                    }
                }
            }
            .shadow(color: (color ?? .white).opacity(isTarget ? 0.66 : 0.25), radius: isTarget ? 22 : 10)

            Text(label)
                .font(.system(size: label == "Find the spell" ? max(12, orbSize * 0.08) : max(14, orbSize * 0.10), weight: .heavy, design: .default))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: orbSize + 16)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

private struct PaletteDropView: View {
    let color: Color
    let trigger: Int

    @State private var yOffset: CGFloat = -26
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.7

    var body: some View {
        Circle()
            .fill(color.opacity(opacity > 0 ? 0.95 : 0))
            .frame(width: 16, height: 16)
            .scaleEffect(scale)
            .offset(y: yOffset)
            .onChange(of: trigger) {
                run()
            }
            .onAppear {
                if trigger > 0 { run() }
            }
    }

    private func run() {
        yOffset = -26
        opacity = 1
        scale = 0.85
        withAnimation(.easeIn(duration: 0.30)) {
            yOffset = 18
            scale = 1.1
        }
        withAnimation(.easeOut(duration: 0.20).delay(0.28)) {
            opacity = 0
            scale = 0.75
        }
    }
}

private struct CrystalFluidMixView: View {
    let colorA: Color
    let colorB: Color
    let mixColor: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let cycle = 3.8
            let phase = (t.truncatingRemainder(dividingBy: cycle)) / cycle
            let firstReveal = clamped(phase / 0.30)
            let secondReveal = clamped((phase - 0.34) / 0.30)
            let blendReveal = clamped((phase - 0.68) / 0.22)

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(colorA.opacity(0.88 * firstReveal))
                        .frame(width: geo.size.width * 0.74, height: geo.size.height * 0.56)
                        .offset(x: -geo.size.width * 0.10, y: geo.size.height * 0.18 - (geo.size.height * 0.30 * firstReveal))
                        .blur(radius: 7)

                    Circle()
                        .fill(colorB.opacity(0.88 * secondReveal))
                        .frame(width: geo.size.width * 0.74, height: geo.size.height * 0.56)
                        .offset(x: geo.size.width * 0.10, y: geo.size.height * 0.18 - (geo.size.height * 0.30 * secondReveal))
                        .blur(radius: 7)

                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    colorA.opacity(0.95),
                                    mixColor.opacity(0.95),
                                    colorB.opacity(0.95),
                                    mixColor.opacity(0.95),
                                    colorA.opacity(0.95)
                                ],
                                center: .center,
                                angle: .degrees((t * 110).truncatingRemainder(dividingBy: 360))
                            )
                        )
                        .frame(width: geo.size.width * 0.92, height: geo.size.height * 0.92)
                        .scaleEffect(0.85 + (0.15 * blendReveal))
                        .opacity(0.16 + (0.65 * blendReveal))
                        .blur(radius: 4)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

private struct MagicStarsOverlay: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for i in 0..<42 {
                    let seed = Double(i) * 0.91
                    let x = CGFloat((sin(seed * 7.7 + t * 0.7) + 1) * 0.5) * size.width
                    let y = CGFloat((cos(seed * 5.1 + t * 0.8) + 1) * 0.5) * size.height
                    let pulse = CGFloat((sin(t * 5.6 + seed * 1.9) + 1) * 0.5)
                    let radius = 4 + (pulse * 7)
                    let alpha = 0.35 + (pulse * 0.60)
                    let color = [Color.white, Color.yellow, Color.cyan, Color.pink, Color.mint][i % 5]

                    var star = Path()
                    star.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    context.fill(star, with: .color(color.opacity(alpha)))

                    var glow = Path()
                    glow.addEllipse(in: CGRect(x: x - (radius * 2.3), y: y - (radius * 2.3), width: radius * 4.6, height: radius * 4.6))
                    context.fill(glow, with: .color(color.opacity(alpha * 0.12)))
                }
            }
        }
    }
}

private struct FindColourCaptureView: View {
    @Environment(\.openURL) private var openURL

    let onCancel: () -> Void
    let onInfuse: (Color) -> Void

    @State private var sampledColor: Color = .black
    @State private var isValid = false
    @State private var permissionDenied = false
    @State private var hasLiveSample = false
    @State private var flash = false
    @State private var cameraRefreshID = UUID()

    var body: some View {
        GeometryReader { geo in
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            let circleSize: CGFloat = isPhone ? min(156, max(118, geo.size.height * 0.30)) : 230

            ZStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.95), Color(red: 0.10, green: 0.11, blue: 0.16).opacity(0.96)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if isPhone {
                    VStack(spacing: 0) {
                        HStack {
                            Button(action: onCancel) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 44, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.95))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 14)

                        Text("Find the Colour")
                            .font(.system(size: 40, weight: .black, design: .default))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.62)
                            .lineLimit(1)
                            .padding(.top, 6)

                        Text("Cover the circle with the colour")
                            .font(.system(size: 14, weight: .bold, design: .default))
                            .foregroundStyle(.white.opacity(0.90))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 6)

                        ZStack {
                            if !permissionDenied {
                                CameraSamplerView(
                                    sampledColor: $sampledColor,
                                    isValid: $isValid,
                                    permissionDenied: $permissionDenied,
                                    hasLiveSample: $hasLiveSample
                                )
                                .id(cameraRefreshID)
                                .frame(width: circleSize, height: circleSize)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .fill(sampledColor.opacity(0.22))
                                )
                            } else {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: circleSize, height: circleSize)
                            }

                            Circle()
                                .stroke(isValid ? Color.green : Color.red.opacity(0.9), lineWidth: 5)
                                .frame(width: circleSize, height: circleSize)
                                .scaleEffect(isValid ? 1.0 : 1.02)
                                .animation(isValid ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isValid)

                            Circle()
                                .stroke(Color.white.opacity(0.88), lineWidth: 2)
                                .frame(width: 56, height: 56)
                        }
                        .padding(.top, 10)

                        Spacer()

                        HStack(spacing: 14) {
                            Button("Retry Camera") {
                                retryCamera()
                            }
                            .font(.system(size: 17, weight: .heavy, design: .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.20))
                            .clipShape(Capsule())

                            Spacer(minLength: 0)

                            Button {
                                guard canInfuse else { return }
                                withAnimation(.easeOut(duration: 0.12)) { flash = true }
                                AudioServicesPlaySystemSound(1519)
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 140_000_000)
                                    withAnimation(.easeOut(duration: 0.2)) { flash = false }
                                    onInfuse(sampledColor)
                                }
                            } label: {
                                Text("Infuse Crystal")
                                    .font(.system(size: 17, weight: .heavy, design: .default))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(canInfuse ? Color.green.opacity(0.85) : Color.white.opacity(0.20))
                                    .clipShape(Capsule())
                            }
                            .disabled(!canInfuse || permissionDenied)
                            .opacity((!canInfuse || permissionDenied) ? 0.65 : 1.0)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, max(14, geo.safeAreaInsets.bottom + 6))
                    }
                } else {
                    VStack {
                        HStack {
                            Button(action: onCancel) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 44, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.95))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 12)

                        Spacer()

                        Text("Find the Colour")
                            .font(.system(size: 42, weight: .black, design: .default))
                            .foregroundStyle(.white)

                        Text("Cover the circle with the colour")
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .foregroundStyle(.white.opacity(0.92))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 22)
                            .padding(.top, 4)

                        ZStack {
                            if !permissionDenied {
                                CameraSamplerView(
                                    sampledColor: $sampledColor,
                                    isValid: $isValid,
                                    permissionDenied: $permissionDenied,
                                    hasLiveSample: $hasLiveSample
                                )
                                .id(cameraRefreshID)
                                .frame(width: circleSize, height: circleSize)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .fill(sampledColor.opacity(0.22))
                                )
                            } else {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: circleSize, height: circleSize)
                            }

                            Circle()
                                .stroke(isValid ? Color.green : Color.red.opacity(0.9), lineWidth: 5)
                                .frame(width: circleSize, height: circleSize)
                                .scaleEffect(isValid ? 1.0 : 1.02)
                                .animation(isValid ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isValid)

                            Circle()
                                .stroke(Color.white.opacity(0.88), lineWidth: 2)
                                .frame(width: 56, height: 56)
                        }
                        .padding(.top, 8)

                        if permissionDenied {
                            VStack(spacing: 10) {
                                Text("Camera access is required to find colours.")
                                    .font(.system(size: 18, weight: .bold, design: .default))
                                    .foregroundStyle(.yellow)
                                    .multilineTextAlignment(.center)

                                Button(permissionActionTitle) {
                                    handlePermissionAction()
                                }
                                .font(.system(size: 17, weight: .heavy, design: .default))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.22))
                                .clipShape(Capsule())
                            }
                            .padding(.top, 10)
                        }

                        Button {
                            guard canInfuse else { return }
                            withAnimation(.easeOut(duration: 0.12)) { flash = true }
                            AudioServicesPlaySystemSound(1519)
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 140_000_000)
                                withAnimation(.easeOut(duration: 0.2)) { flash = false }
                                onInfuse(sampledColor)
                            }
                        } label: {
                            Text("Infuse Crystal")
                                .font(.system(size: 24, weight: .heavy, design: .default))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .background(canInfuse ? Color.green.opacity(0.85) : Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        .disabled(!canInfuse || permissionDenied)
                        .padding(.top, 18)

                        Spacer()
                    }
                }

                if flash {
                    Color.white.opacity(0.45).ignoresSafeArea()
                }
            }
        }
        .onChange(of: isValid) {
            if isValid {
                AudioServicesPlaySystemSound(1104)
            }
        }
    }

    private var permissionActionTitle: String {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            return "Allow Camera"
        case .denied, .restricted:
            return "Open Settings"
        case .authorized:
            return "Retry Camera"
        @unknown default:
            return "Open Settings"
        }
    }

    private var canInfuse: Bool {
        isValid && hasLiveSample
    }

    private func retryCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionDenied = false
            hasLiveSample = false
            cameraRefreshID = UUID()
        default:
            handlePermissionAction()
        }
    }

    private func handlePermissionAction() {
        guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else {
            permissionDenied = true
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            permissionDenied = false
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    permissionDenied = !granted
                    if granted {
                        cameraRefreshID = UUID()
                    }
                }
            }
        case .authorized:
            permissionDenied = false
            hasLiveSample = false
            cameraRefreshID = UUID()
        case .denied, .restricted:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        @unknown default:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        }
    }
}

private struct CameraSamplerView: UIViewRepresentable {
    @Binding var sampledColor: Color
    @Binding var isValid: Bool
    @Binding var permissionDenied: Bool
    @Binding var hasLiveSample: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            sampledColor: $sampledColor,
            isValid: $isValid,
            permissionDenied: $permissionDenied,
            hasLiveSample: $hasLiveSample
        )
    }

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        context.coordinator.attachPreview(to: view)
        context.coordinator.start()
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        Task { @MainActor in
            context.coordinator.updateOrientation(for: uiView)
        }
    }

    static func dismantleUIView(_ uiView: CameraPreviewView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        private let sampledColor: Binding<Color>
        private let isValid: Binding<Bool>
        private let permissionDenied: Binding<Bool>
        private let hasLiveSample: Binding<Bool>
        private let session = AVCaptureSession()
        private let queue = DispatchQueue(label: "camera.sampler.queue")
        private let output = AVCaptureVideoDataOutput()
        private var orientationObserver: NSObjectProtocol?

        private var configured = false

        init(
            sampledColor: Binding<Color>,
            isValid: Binding<Bool>,
            permissionDenied: Binding<Bool>,
            hasLiveSample: Binding<Bool>
        ) {
            self.sampledColor = sampledColor
            self.isValid = isValid
            self.permissionDenied = permissionDenied
            self.hasLiveSample = hasLiveSample
        }

        @MainActor
        func attachPreview(to view: CameraPreviewView) {
            view.previewLayer.videoGravity = .resizeAspectFill
            view.previewLayer.session = session
            updateOrientation(for: view)
            if orientationObserver == nil {
                orientationObserver = NotificationCenter.default.addObserver(
                    forName: UIDevice.orientationDidChangeNotification,
                    object: nil,
                    queue: .main
                ) { [weak self, weak view] _ in
                    guard let self, let view else { return }
                    Task { @MainActor in
                        self.updateOrientation(for: view)
                    }
                }
            }
        }

        @MainActor
        func updateOrientation(for view: CameraPreviewView) {
            guard let scene = view.window?.windowScene else { return }
            let angle = rotationAngle(for: scene.interfaceOrientation)

            if let previewConnection = view.previewLayer.connection,
               previewConnection.isVideoRotationAngleSupported(angle) {
                previewConnection.videoRotationAngle = angle
            }

            if let outputConnection = output.connection(with: .video),
               outputConnection.isVideoRotationAngleSupported(angle) {
                outputConnection.videoRotationAngle = angle
            }
        }

        @MainActor
        private func rotationAngle(for orientation: UIInterfaceOrientation) -> CGFloat {
            switch orientation {
            case .portrait:
                return 90
            case .portraitUpsideDown:
                return 270
            case .landscapeLeft:
                // Interface orientation is opposite camera sensor rotation in landscape.
                return 180
            case .landscapeRight:
                return 0
            default:
                return 90
            }
        }

        func start() {
            guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else {
                DispatchQueue.main.async {
                    self.permissionDenied.wrappedValue = true
                }
                return
            }

            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                DispatchQueue.main.async {
                    self.permissionDenied.wrappedValue = false
                }
                configureIfNeeded()
                let session = SendableSession(raw: self.session)
                queue.async {
                    session.raw.startRunning()
                }
            case .notDetermined:
                DispatchQueue.main.async {
                    self.permissionDenied.wrappedValue = true
                }
            default:
                DispatchQueue.main.async {
                    self.permissionDenied.wrappedValue = true
                }
            }
        }

        func stop() {
            let session = SendableSession(raw: self.session)
            queue.async {
                if session.raw.isRunning {
                    session.raw.stopRunning()
                }
            }
            if let orientationObserver {
                NotificationCenter.default.removeObserver(orientationObserver)
                self.orientationObserver = nil
            }
        }

        private func configureIfNeeded() {
            guard !configured else { return }
            configured = true

            session.beginConfiguration()
            session.sessionPreset = .high

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input) else {
                DispatchQueue.main.async {
                    self.permissionDenied.wrappedValue = true
                }
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                return
            }
            session.addOutput(output)
            session.commitConfiguration()
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

            let ptr = base.assumingMemoryBound(to: UInt8.self)
            let cx = width / 2
            let cy = height / 2
            let radius = 6
            let x0 = max(0, cx - radius)
            let x1 = min(width - 1, cx + radius)
            let y0 = max(0, cy - radius)
            let y1 = min(height - 1, cy + radius)

            var rSum = 0.0
            var gSum = 0.0
            var bSum = 0.0
            var count = 0.0
            var bins: [Int: (count: Int, rSum: Double, gSum: Double, bSum: Double)] = [:]

            for y in y0...y1 {
                let row = y * bytesPerRow
                for x in x0...x1 {
                    let offset = row + (x * 4)
                    let bRaw = Double(ptr[offset + 0])
                    let gRaw = Double(ptr[offset + 1])
                    let rRaw = Double(ptr[offset + 2])
                    bSum += bRaw
                    gSum += gRaw
                    rSum += rRaw
                    count += 1

                    let rQ = Int((rRaw / 255.0) * 7.0)
                    let gQ = Int((gRaw / 255.0) * 7.0)
                    let bQ = Int((bRaw / 255.0) * 7.0)
                    let key = (rQ << 6) | (gQ << 3) | bQ
                    if var bin = bins[key] {
                        bin.count += 1
                        bin.rSum += rRaw
                        bin.gSum += gRaw
                        bin.bSum += bRaw
                        bins[key] = bin
                    } else {
                        bins[key] = (count: 1, rSum: rRaw, gSum: gRaw, bSum: bRaw)
                    }
                }
            }

            guard count > 0 else { return }
            let dominant = bins.max { a, b in a.value.count < b.value.count }?.value
            let dominantCount = Double(dominant?.count ?? 0)
            let dominanceRatio = dominantCount / count

            let sampledRRaw = dominant?.rSum ?? rSum
            let sampledGRaw = dominant?.gSum ?? gSum
            let sampledBRaw = dominant?.bSum ?? bSum
            let sampledCount = Double(dominant?.count ?? Int(count))

            let r = (sampledRRaw / sampledCount) / 255.0
            let g = (sampledGRaw / sampledCount) / 255.0
            let b = (sampledBRaw / sampledCount) / 255.0
            let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
            let valid = isColorBrightAndClear(color, dominance: dominanceRatio)

            DispatchQueue.main.async {
                self.sampledColor.wrappedValue = Color(uiColor: color)
                self.isValid.wrappedValue = valid
                self.hasLiveSample.wrappedValue = true
            }
        }

        private func isColorBrightAndClear(_ color: UIColor, dominance: Double) -> Bool {
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &alpha)
            let chroma = max(r, g, b) - min(r, g, b)
            return brightness > 0.22 && saturation > 0.08 && chroma > 0.05 && dominance > 0.30
        }
    }
}

extension CameraSamplerView.Coordinator: @unchecked Sendable {}

private struct SendableSession: @unchecked Sendable {
    let raw: AVCaptureSession
}

private final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private enum SorcerersLabPalette {
    static let targets: [SorcerersLabTarget] = [
        SorcerersLabTarget(name: "Ember Flame (Red-Orange)", color: Color(red: 0.93, green: 0.33, blue: 0.12)),
        SorcerersLabTarget(name: "Sunrise Glow (Yellow-Orange)", color: Color(red: 0.96, green: 0.66, blue: 0.12)),
        SorcerersLabTarget(name: "Spring Spark (Yellow-Green)", color: Color(red: 0.62, green: 0.78, blue: 0.18)),
        SorcerersLabTarget(name: "Ocean Whisper (Blue-Green)", color: Color(red: 0.14, green: 0.66, blue: 0.62)),
        SorcerersLabTarget(name: "Twilight Mist (Blue-Purple)", color: Color(red: 0.40, green: 0.34, blue: 0.88)),
        SorcerersLabTarget(name: "Mystic Bloom (Red-Purple)", color: Color(red: 0.68, green: 0.22, blue: 0.56)),
        SorcerersLabTarget(name: "Sunny-Spark (Orange)", color: Color(red: 0.96, green: 0.56, blue: 0.10)),
        SorcerersLabTarget(name: "Violet-Lark (Violet)", color: Color(red: 0.54, green: 0.30, blue: 0.82)),
        SorcerersLabTarget(name: "Emerald-Wisp (Green)", color: Color(red: 0.14, green: 0.66, blue: 0.34))
    ]

    static func randomTarget(excluding names: Set<String>) -> SorcerersLabTarget {
        let pool = targets.filter { !names.contains($0.name) }
        if let pick = pool.randomElement() { return pick }
        return targets.randomElement() ?? SorcerersLabTarget(name: "Orange", color: .orange)
    }

    static func target(named name: String) -> SorcerersLabTarget? {
        targets.first(where: { $0.name == name })
    }

    static let fixColors: [SorcerersLabFixColor] = [
        SorcerersLabFixColor(name: "Red", color: .red),
        SorcerersLabFixColor(name: "Orange", color: .orange),
        SorcerersLabFixColor(name: "Yellow", color: .yellow),
        SorcerersLabFixColor(name: "Green", color: .green),
        SorcerersLabFixColor(name: "Cyan", color: .cyan),
        SorcerersLabFixColor(name: "Blue", color: .blue),
        SorcerersLabFixColor(name: "Purple", color: .purple),
        SorcerersLabFixColor(name: "Pink", color: .pink),
        SorcerersLabFixColor(name: "White", color: .white)
    ]
}

private struct SorcerersLabTarget {
    let name: String
    let color: Color
}

private struct SorcerersLabFixColor {
    let name: String
    let color: Color
}

private struct RGBTriplet {
    let r: Double
    let g: Double
    let b: Double
}

private func rgbComponents(from color: UIColor) -> RGBTriplet {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    return RGBTriplet(r: r, g: g, b: b)
}

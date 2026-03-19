import AudioToolbox
import AVFoundation
import Darwin
import SwiftData
import SwiftUI
import UIKit

@available(iOS 17.0, *)
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpellBookRecord.date) private var spellBookRecords: [SpellBookRecord]

    @StateObject private var feedback = GameFeedbackController()
    @StateObject private var colorEngine = ColorDecayEngine()

    @State private var hasStarted = false
    @State private var isWalking = false

    @State private var worldOffsetX: CGFloat = 0
    @State private var worldOffsetZ: CGFloat = 0
    @State private var jumpTrigger: Int = 0
    @State private var zoomLevel: CGFloat = 1.0
    @State private var pinchBaseZoom: CGFloat = 1.0
    @State private var moveInputX: CGFloat = 0
    @State private var moveInputZ: CGFloat = 0
    @State private var speedBoost: CGFloat = 1.0

    @State private var restMessage = ""
    @State private var didShowChasePrompts = false
    @State private var chasePromptTask: Task<Void, Never>?
    @State private var delaySpellPromptForScriptedColorless = false
    @State private var delayedSpellPromptTask: Task<Void, Never>?
    @State private var didBootstrap = false
    @State private var showExitAlert = false
    @State private var hasMovementStarted = false
    @State private var showTouchCursor = false
    @State private var touchCursorPoint: CGPoint = .zero
    @State private var showSpellPrompt = false
    @State private var showSorcerersLab = false
    @State private var showLearningSpellBook = false
    @State private var practiceTargetName: String?
    @State private var showForestMoodPrompt = false
    @State private var forestMoodMessage = ""
    @State private var forestMoodTitle = ""
    @State private var forestMoodColor: Color = .white
    @State private var showSpellBook = false
    @State private var selectedSpellBookRecordID: UUID?
    @State private var shouldEndGameAfterSpellBookClose = false
    @State private var showPlayAgainPrompt = false
    @State private var hasUnlockedSpellChoices = false

    private let movementSpeedX: CGFloat = 30
    private let movementSpeedZ: CGFloat = 28
    private var isCompactLandscapePhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) <= 430
    }

    private let moveTick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private var isWorldInputLocked: Bool {
        colorEngine.showAlert || colorEngine.showReplayPrompt || showSpellPrompt || showSorcerersLab || showLearningSpellBook || showSpellBook || showForestMoodPrompt || showPlayAgainPrompt
    }

    var body: some View {
        ZStack {
            if !showSpellPrompt {
                EnvironmentView(
                    offsetX: worldOffsetX,
                    offsetZ: worldOffsetZ,
                    spellOrbs: spellBookRecords.map { EnvironmentSpellOrb(id: $0.id, color: $0.color) },
                    isSaturated: true,
                    jumpTrigger: jumpTrigger,
                    zoomLevel: zoomLevel,
                    sunColor: colorEngine.activeSunColor,
                    sunBrightness: colorEngine.colorLevel,
                    guideLightActive: hasStarted && !showSorcerersLab,
                    onWorldTap: nil
                )
                .saturation(pow(colorEngine.colorLevel, 2.2))
                .brightness(-(1 - colorEngine.colorLevel) * 0.20)
                .contrast(1 - (1 - colorEngine.colorLevel) * 0.18)
                .overlay(colorEngine.activeSunColor.opacity(0.10))
                .overlay(
                    Color.black.opacity(pow(1 - colorEngine.colorLevel, 1.2) * 0.44)
                )
                .animation(.easeInOut(duration: 0.4), value: colorEngine.colorLevel)
                .animation(.easeInOut(duration: 0.4), value: colorEngine.activeSunColor)
                .contentShape(Rectangle())
                .simultaneousGesture(worldDragGesture)
                .simultaneousGesture(doubleTapJumpGesture)
                .simultaneousGesture(zoomGesture)

            }

            if showSpellPrompt {
                SpellPromptOverlay(
                    onLearn: {
                        withAnimation(.easeInOut(duration: 0.34)) {
                            showSpellPrompt = false
                            showLearningSpellBook = true
                        }
                        colorEngine.showAlert = false
                        colorEngine.showSunsetEvent = false
                    },
                    onMake: {
                        withAnimation(.easeInOut(duration: 0.34)) {
                            showSpellPrompt = false
                        }
                        practiceTargetName = nil
                        colorEngine.showAlert = false
                        colorEngine.showSunsetEvent = false
                        showSorcerersLab = true
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.34)) {
                            showSpellPrompt = false
                        }
                        colorEngine.showAlert = false
                        colorEngine.showSunsetEvent = false
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }

            if showSorcerersLab {
                SorcerersLabFlowView(
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSorcerersLab = false
                            showSpellPrompt = true
                        }
                        practiceTargetName = nil
                    },
                    onCastSpell: { castColor, targetName in
                        practiceTargetName = nil
                        handleCastSpell(color: castColor, targetName: targetName)
                    },
                    excludedTargetNames: completedTargetNames,
                    preferredTargetName: practiceTargetName
                )
                .transition(.opacity)
            }

            if showLearningSpellBook {
                LearningLab(
                    practicedTargetNames: completedTargetNames,
                    onPractice: { targetName in
                        practiceTargetName = targetName
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showLearningSpellBook = false
                            showSorcerersLab = true
                        }
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showLearningSpellBook = false
                            showSpellPrompt = true
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }

            if showForestMoodPrompt {
                ForestMoodPromptView(
                    title: forestMoodTitle,
                    message: forestMoodMessage,
                    color: forestMoodColor
                )
                    .transition(.opacity.combined(with: .scale))
            }

            if showSpellBook {
                SpellBookOverlay(
                    records: spellBookRecords,
                    selectedRecordID: $selectedSpellBookRecordID,
                    onUpdateMemoryImage: { record, image in
                        record.updateMemoryImage(image)
                        try? modelContext.save()
                    },
                    onDeleteRecord: { record in
                        modelContext.delete(record)
                        try? modelContext.save()
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showSpellBook = false
                            showForestMoodPrompt = false
                        }
                        if shouldEndGameAfterSpellBookClose {
                            shouldEndGameAfterSpellBookClose = false
                            endGameAfterSpellBookClose()
                        }
                    }
                )
                .transition(.opacity)
            }

            if !hasStarted && !showSpellPrompt && !showSorcerersLab && !showPlayAgainPrompt {
                CatchLightStartOverlay {
                    beginCatchTheLight()
                }
                .transition(.opacity)
            }

            if showPlayAgainPrompt {
                SparkAgainOverlay(
                    onYes: {
                        showPlayAgainPrompt = false
                        restartGame(showSpellPromptOnStart: true)
                    },
                    onNo: {
                        exit(0)
                    }
                )
            }

            if !restMessage.isEmpty && !colorEngine.showReplayPrompt && !showSpellPrompt {
                Text(restMessage)
                    .font(.system(size: isCompactLandscapePhone ? 24 : 32, weight: .heavy, design: .default))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, isCompactLandscapePhone ? 10 : 12)
                    .background(Color.black.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: isCompactLandscapePhone ? -70 : -110)
                    .transition(.opacity)
            }

            if showTouchCursor && hasStarted && !isWorldInputLocked && !showSpellPrompt {
                TouchCursorView()
                    .position(touchCursorPoint)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if !showSpellPrompt {
                VStack {
                    HStack {
                        if hasStarted && !showSorcerersLab && !showLearningSpellBook && !showSpellBook && !showForestMoodPrompt && !showPlayAgainPrompt {
                            BackToExitButton {
                                showExitAlert = true
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, isCompactLandscapePhone ? 10 : 18)
                    .padding(.horizontal, 18)
                    Spacer()
                    HStack {
                        Spacer()
                        if hasStarted && !spellBookRecords.isEmpty && !showSorcerersLab && !showSpellPrompt && !showLearningSpellBook {
                            Button {
                                selectedSpellBookRecordID = spellBookRecords.last?.id
                                withAnimation(.easeInOut(duration: 0.24)) {
                                    showSpellBook = true
                                    showForestMoodPrompt = false
                                }
                            } label: {
                                SpellBookDockButton(isCompact: isCompactLandscapePhone)
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, isCompactLandscapePhone ? 10 : 18)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .onReceive(moveTick) { _ in
            guard hasStarted else { return }
            guard !isWorldInputLocked else { return }
            if hasMovementStarted {
                colorEngine.update(delta: 1.0 / 60.0)
            }
            let driveX = clamp(moveInputX, min: -1.0, max: 1.0)
            let driveZ = clamp(moveInputZ, min: -1.0, max: 1.0)
            if abs(driveX) > 0.01 || abs(driveZ) > 0.01 {
                worldOffsetX += driveX * movementSpeedX
                let boostedForwardZ = driveZ > 0 ? (driveZ * speedBoost) : driveZ
                worldOffsetZ += boostedForwardZ * movementSpeedZ
            }
            isWalking = abs(driveX) > 0.02 || abs(driveZ) > 0.02
            if speedBoost > 1.0 {
                speedBoost = max(1.0, speedBoost - 0.018)
            }
        }
        .onDisappear {
            chasePromptTask?.cancel()
            chasePromptTask = nil
            delayedSpellPromptTask?.cancel()
            delayedSpellPromptTask = nil
            feedback.stopWalkingLoop()
            feedback.stopAmbientLoop()
        }
        .onAppear {
            guard !didBootstrap else { return }
            didBootstrap = true
        }
        .onChange(of: isWalking) {
            isWalking ? feedback.startWalkingLoop() : feedback.stopWalkingLoop()
        }
        .onChange(of: hasMovementStarted) {
            if hasMovementStarted, hasStarted, !didShowChasePrompts {
                showChasePrompts()
            }
        }
        .onChange(of: colorEngine.showAlert) {
            if colorEngine.showAlert { feedback.playColorAlert() }
        }
        .onChange(of: colorEngine.showSunsetEvent) {
            if colorEngine.showSunsetEvent {
                feedback.playSunsetShift()
            }
        }
        .onChange(of: colorEngine.showAlert) {
            if colorEngine.showAlert {
                hasMovementStarted = false
                moveInputX = 0
                moveInputZ = 0
                isWalking = false
                if delaySpellPromptForScriptedColorless {
                    delaySpellPromptForScriptedColorless = false
                    delayedSpellPromptTask?.cancel()
                    delayedSpellPromptTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_700_000_000)
                        guard !Task.isCancelled else { return }
                        if colorEngine.showAlert {
                            showSpellPrompt = true
                        }
                    }
                } else {
                    showSpellPrompt = true
                }
            } else {
                delayedSpellPromptTask?.cancel()
                delayedSpellPromptTask = nil
                showSpellPrompt = false
            }
        }
        .onChange(of: isWorldInputLocked) {
            if isWorldInputLocked {
                moveInputX = 0
                moveInputZ = 0
                isWalking = false
                showTouchCursor = false
                speedBoost = 1.0
            }
        }
        .alert("Do you want to leave the forest", isPresented: $showExitAlert) {
            Button("No", role: .cancel) {}
            Button("Yes", role: .destructive) {
                exit(0)
            }
        }
    }

    private var worldDragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                guard hasStarted, !isWorldInputLocked else { return }
                hasMovementStarted = true
                touchCursorPoint = value.location
                if !showTouchCursor {
                    withAnimation(.easeOut(duration: 0.12)) {
                        showTouchCursor = true
                    }
                }
                let inputX = clamp(-value.translation.width / 90.0, min: -1.0, max: 1.0)
                let inputZ = clamp(-value.translation.height / 90.0, min: -1.0, max: 1.0)
                moveInputX = inputX
                moveInputZ = inputZ
                isWalking = abs(inputX) > 0.02 || abs(inputZ) > 0.02
            }
            .onEnded { _ in
                guard hasStarted else { return }
                moveInputX = 0
                moveInputZ = 0
                isWalking = false
                withAnimation(.easeOut(duration: 0.18)) {
                    showTouchCursor = false
                }
            }
    }

    private var doubleTapJumpGesture: some Gesture {
        TapGesture(count: 2).onEnded {
            guard hasStarted, !isWorldInputLocked else { return }
            jumpTrigger += 1
            speedBoost = 2.6
            feedback.playJump()
            feedback.playDashBoost()
        }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                guard hasStarted, !isWorldInputLocked else { return }
                zoomLevel = clamp(pinchBaseZoom * scale, min: 0.75, max: 1.9)
            }
            .onEnded { scale in
                guard hasStarted, !isWorldInputLocked else { return }
                let previous = pinchBaseZoom
                pinchBaseZoom = zoomLevel
                if zoomLevel > previous + 0.02 || scale > 1.02 {
                    feedback.playZoomIn()
                } else if zoomLevel < previous - 0.02 || scale < 0.98 {
                    feedback.playZoomOut()
                }
            }
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(value, max))
    }

    private func beginCatchTheLight() {
        withAnimation(.easeInOut(duration: 0.24)) {
            hasStarted = true
        }
        hasUnlockedSpellChoices = false
        didShowChasePrompts = false
        restMessage = ""
        chasePromptTask?.cancel()
        chasePromptTask = nil
        delayedSpellPromptTask?.cancel()
        delayedSpellPromptTask = nil
        delaySpellPromptForScriptedColorless = false
        colorEngine.start()
        feedback.playDayMusic()
        feedback.startAmbientLoop()
    }

    private var completedTargetNames: Set<String> {
        Set(spellBookRecords.compactMap { $0.targetName })
    }

    private func handleCastSpell(color: Color, targetName: String) {
        let mood = forestMood(forTargetName: targetName)
        let cleanName = displayTargetName(from: targetName)
        forestMoodMessage = mood
        forestMoodTitle = cleanName
        forestMoodColor = color
        let newRecord = SpellBookRecord(moodMessage: mood, targetName: targetName, color: color)
        modelContext.insert(newRecord)
        try? modelContext.save()
        selectedSpellBookRecordID = newRecord.id

        withAnimation(.easeInOut(duration: 0.24)) {
            showSorcerersLab = false
            showForestMoodPrompt = true
        }
        colorEngine.sparkWorldAgain()
        colorEngine.showAlert = false
        feedback.playMixSuccess()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.easeInOut(duration: 0.30)) {
                showForestMoodPrompt = false
                shouldEndGameAfterSpellBookClose = true
                showSpellBook = true
            }
        }
    }

    private func endGameAfterSpellBookClose() {
        moveInputX = 0
        moveInputZ = 0
        isWalking = false
        hasMovementStarted = false
        showTouchCursor = false
        speedBoost = 1.0
        showSorcerersLab = false
        showLearningSpellBook = false
        showSpellPrompt = false
        showForestMoodPrompt = false
        colorEngine.showAlert = false
        colorEngine.showSunsetEvent = false
        colorEngine.showReplayPrompt = false
        hasStarted = false
        feedback.stopWalkingLoop()
        feedback.stopAmbientLoop()
        withAnimation(.easeInOut(duration: 0.2)) {
            showPlayAgainPrompt = true
        }
    }

    private func restartGame(showSpellPromptOnStart: Bool = false) {
        hasUnlockedSpellChoices = false
        didShowChasePrompts = false
        chasePromptTask?.cancel()
        chasePromptTask = nil
        delayedSpellPromptTask?.cancel()
        delayedSpellPromptTask = nil
        delaySpellPromptForScriptedColorless = false
        colorEngine.start()
        restMessage = ""
        hasMovementStarted = false
        moveInputX = 0
        moveInputZ = 0
        isWalking = false
        showTouchCursor = false
        speedBoost = 1.0
        withAnimation(.easeInOut(duration: 0.24)) {
            hasStarted = true
            showSpellPrompt = showSpellPromptOnStart
        }
        feedback.playDayMusic()
        feedback.startAmbientLoop()
    }

    private func showChasePrompts() {
        didShowChasePrompts = true
        chasePromptTask?.cancel()
        chasePromptTask = Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.2)) {
                restMessage = "How beautiful the world is with colours."
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                restMessage = ""
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                restMessage = "But what if the world is colourless??"
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            delaySpellPromptForScriptedColorless = true
            hasUnlockedSpellChoices = true
            colorEngine.triggerImmediateColorless()
            withAnimation(.easeInOut(duration: 0.2)) {
                restMessage = ""
            }
        }
    }

    private func displayTargetName(from targetName: String) -> String {
        if let openParen = targetName.firstIndex(of: "(") {
            return targetName[..<openParen].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return targetName
    }

    private func forestMood(forTargetName targetName: String) -> String {
        let map: [String: String] = [
            "Ember Flame (Red-Orange)": "You made the world Energetic !",
            "Sunrise Glow (Yellow-Orange)": "You made the world Happy !",
            "Spring Spark (Yellow-Green)": "World feels Lively !",
            "Ocean Whisper (Blue-Green)": "World is Relaxed !",
            "Twilight Mist (Blue-Purple)": "Magical powers in the World!",
            "Mystic Bloom (Red-Purple)": "Power-packed world!!",
            "Sunny-Spark (Orange)": "World is Cheerful !!",
            "Violet-Lark (Violet)": "Mystery in the World !",
            "Emerald-Wisp (Green)": "World is Calm!!"
        ]
        return map[targetName] ?? "You made the world Happy !"
    }

}

private struct ForestMoodPromptView: View {
    let title: String
    let message: String
    let color: Color
    @State private var rise = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            color
                .opacity(pulse ? 0.78 : 0.62)
                .ignoresSafeArea()
                .overlay(
                    RadialGradient(
                        colors: [Color.white.opacity(0.22), .clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: 420
                    )
                )
                .animation(.easeInOut(duration: 0.55), value: pulse)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 38, weight: .black, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 24, weight: .heavy, design: .default))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 3)
            .offset(y: rise ? -8 : 8)
            .opacity(rise ? 1 : 0.70)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                rise = true
            }
            withAnimation(.easeInOut(duration: 0.70).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct SpellBookDockButton: View {
    let isCompact: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.30, green: 0.19, blue: 0.13))
                .frame(width: isCompact ? 70 : 86, height: isCompact ? 56 : 68)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(red: 0.66, green: 0.45, blue: 0.30), lineWidth: 2.2)
                )

            Image(systemName: "sun.max.fill")
                .font(.system(size: isCompact ? 24 : 30, weight: .black))
                .foregroundStyle(Color(red: 0.95, green: 0.76, blue: 0.36))
        }
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        .scaleEffect(pulse ? 1.05 : 0.95)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct StartCard: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Color Hunt")
                .font(.system(size: 48, weight: .heavy, design: .default))
                .foregroundStyle(.white)
            Text("Learn color theory.\nMix sunlight to spark the world.")
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.96))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
            Button(action: onStart) {
                Text("Start")
                    .font(.system(size: 34, weight: .heavy, design: .default))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 46)
                    .padding(.vertical, 11)
                    .background(Color(red: 0.98, green: 0.47, blue: 0.24))
                    .clipShape(Capsule())
            }
        }
        .padding(26)
        .background(
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.47, blue: 0.67).opacity(0.92), Color(red: 0.04, green: 0.35, blue: 0.58).opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(20)
    }
}

private struct StoryIntroCard: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Text("Welcome to the Spark Land")
                .font(.system(size: 56, weight: .heavy, design: .default))
                .foregroundStyle(.white)

            Text("You are SPARKY the SORCERER.\nMove your fingers to walk around.\nWhen it gets dark choose the magic spell.")
                .font(.system(size: 30, weight: .bold, design: .default))
                .foregroundStyle(.white.opacity(0.96))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .lineSpacing(6)

            Button(action: onStart) {
                Text("Start")
                    .font(.system(size: 30, weight: .heavy, design: .default))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 44)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.98, green: 0.47, blue: 0.24))
                    .clipShape(Capsule())
            }
        }
        .padding(34)
        .background(
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.36, blue: 0.56).opacity(0.94), Color(red: 0.04, green: 0.22, blue: 0.39).opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(12)
    }
}

private struct BackToExitButton: View {
    let action: () -> Void
    private var isCompactLandscapePhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) <= 430
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.system(size: isCompactLandscapePhone ? 17 : 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: isCompactLandscapePhone ? 32 : 38, height: isCompactLandscapePhone ? 32 : 38)
            .background(Color.black.opacity(0.45))
            .clipShape(Circle())
        }
    }
}

private struct BadgeCollectButtonOverlay: View {
    let onCollect: () -> Void
    @State private var pulse = false

    var body: some View {
        VStack {
            Spacer()
            Button(action: onCollect) {
                Text("Collect Badge")
                    .font(.system(size: 28, weight: .heavy, design: .default))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.98, green: 0.64, blue: 0.20), Color(red: 0.88, green: 0.46, blue: 0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.82), lineWidth: 2)
                    )
                    .shadow(color: Color.orange.opacity(0.62), radius: 14)
                    .scaleEffect(pulse ? 1.08 : 0.94)
            }
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.15).ignoresSafeArea())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct SparkAgainOverlay: View {
    let onYes: () -> Void
    let onNo: () -> Void
    private var isCompactLandscapePhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) <= 430
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: isCompactLandscapePhone ? 12 : 16) {
                Text("Play again?")
                    .font(.system(size: isCompactLandscapePhone ? 28 : 34, weight: .heavy, design: .default))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)

                HStack(spacing: 12) {
                    Button(action: onNo) {
                        Text("No")
                            .font(.system(size: isCompactLandscapePhone ? 20 : 24, weight: .heavy, design: .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, isCompactLandscapePhone ? 20 : 24)
                            .padding(.vertical, isCompactLandscapePhone ? 8 : 10)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.85), lineWidth: 1.2)
                            )
                    }

                    Button(action: onYes) {
                        Text("Yes")
                            .font(.system(size: isCompactLandscapePhone ? 20 : 24, weight: .heavy, design: .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, isCompactLandscapePhone ? 20 : 26)
                            .padding(.vertical, isCompactLandscapePhone ? 8 : 10)
                            .background(Color(red: 0.94, green: 0.45, blue: 0.18))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(isCompactLandscapePhone ? 18 : 24)
            .background(Color.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 20)
        }
    }
}

private struct SpellPromptOverlay: View {
    let onLearn: () -> Void
    let onMake: () -> Void
    let onClose: () -> Void
    private var isCompactLandscapePhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) <= 430
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.16).ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: isCompactLandscapePhone ? 36 : 44, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.96))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()

                Text("Oh No! The colours are gone!!")
                    .font(.system(size: isCompactLandscapePhone ? 28 : 40, weight: .black, design: .default))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("Help bringing the colours back!")
                    .font(.system(size: isCompactLandscapePhone ? 20 : 28, weight: .heavy, design: .default))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                HStack(spacing: isCompactLandscapePhone ? 16 : 26) {
                    SpellCircleButton(
                        systemImage: "pencil",
                        text: "Learn",
                        phase: 0.0,
                        isCompact: isCompactLandscapePhone,
                        action: onLearn
                    )

                    SpellCircleButton(
                        systemImage: "wand.and.stars",
                        text: "Cast Spell",
                        phase: 1.7,
                        isCompact: isCompactLandscapePhone,
                        action: onMake
                    )
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct SpellCircleButton: View {
    let systemImage: String
    let text: String
    let phase: Double
    let isCompact: Bool
    let action: () -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let y = CGFloat(sin((t * 1.8) + phase) * 4.0)
            let pulse = 1.0 + CGFloat(sin((t * 1.4) + phase) * 0.015)

            Button(action: action) {
                VStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.system(size: isCompact ? 30 : 40, weight: .bold))
                        .foregroundStyle(.white)
                    Text(text)
                        .font(.system(size: isCompact ? 15 : 18, weight: .heavy, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                }
                .frame(width: isCompact ? 145 : 190, height: isCompact ? 145 : 190)
                .background(Color.black.opacity(0.80))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 3))
                .offset(y: y)
                .scaleEffect(pulse)
            }
            .buttonStyle(GrowOnPressButtonStyle())
            .hoverEffect(.lift)
        }
    }
}

private struct GrowOnPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.06 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct TouchCursorView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.20))
                .frame(width: 42, height: 42)
            Circle()
                .stroke(Color.white.opacity(0.92), lineWidth: 2)
                .frame(width: 30, height: 30)
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 8, height: 8)
        }
    }
}

@MainActor
final class GameFeedbackController: ObservableObject {
    private var stepTimer: Timer?
    private var ambientEngine: AVAudioEngine?
    private var ambientPlayer: AVAudioPlayerNode?
    private var ambientBuffer: AVAudioPCMBuffer?
    private var ambientPrepared = false

    func playStartTap() { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); AudioServicesPlaySystemSound(1156) }
    func playJump() { HapticsEngine.shared.pop(); UIImpactFeedbackGenerator(style: .rigid).impactOccurred(); AudioServicesPlaySystemSound(1103) }
    func playZoomIn() { UIImpactFeedbackGenerator(style: .light).impactOccurred(); AudioServicesPlaySystemSound(1519) }
    func playZoomOut() { UIImpactFeedbackGenerator(style: .soft).impactOccurred(); AudioServicesPlaySystemSound(1520) }
    func playColorAlert() { UINotificationFeedbackGenerator().notificationOccurred(.warning); AudioServicesPlaySystemSound(1113) }
    func playColorChosen() { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); AudioServicesPlaySystemSound(1519) }
    func playDashBoost() { UIImpactFeedbackGenerator(style: .light).impactOccurred(); AudioServicesPlaySystemSound(1117) }
    func playMixSuccess() { UINotificationFeedbackGenerator().notificationOccurred(.success); AudioServicesPlaySystemSound(1025) }
    func playClapCelebration() {
        AudioServicesPlaySystemSound(1157)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            AudioServicesPlaySystemSound(1157)
            try? await Task.sleep(nanoseconds: 120_000_000)
            AudioServicesPlaySystemSound(1025)
        }
    }
    func playMixRetry() { UINotificationFeedbackGenerator().notificationOccurred(.warning); AudioServicesPlaySystemSound(1107) }
    func playColorBoom() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        AudioServicesPlaySystemSound(1110)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            AudioServicesPlaySystemSound(1157)
        }
    }

    func playDayMusic() {
        AudioServicesPlaySystemSound(1023)
    }

    func startAmbientLoop() {
        prepareAmbientLoopIfNeeded()
        guard let ambientEngine, let ambientPlayer, let ambientBuffer else { return }
        if !ambientEngine.isRunning {
            try? ambientEngine.start()
        }
        guard !ambientPlayer.isPlaying else { return }
        ambientPlayer.scheduleBuffer(ambientBuffer, at: nil, options: [.loops], completionHandler: nil)
        ambientPlayer.play()
    }

    func stopAmbientLoop() {
        ambientPlayer?.stop()
        ambientEngine?.stop()
    }

    func playSunsetShift() {
        AudioServicesPlaySystemSound(1034)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 240_000_000)
            AudioServicesPlaySystemSound(1113)
        }
    }

    func startWalkingLoop() {
        stopWalkingLoop()
        AudioServicesPlaySystemSound(1104)
        stepTimer = Timer.scheduledTimer(withTimeInterval: 0.26, repeats: true) { _ in
            AudioServicesPlaySystemSound(1104)
        }
    }

    func stopWalkingLoop() {
        stepTimer?.invalidate()
        stepTimer = nil
    }

    private func prepareAmbientLoopIfNeeded() {
        guard !ambientPrepared else { return }
        ambientPrepared = true

        let sampleRate = 44_100.0
        let durationSeconds = 4.0
        let totalFrames = AVAudioFrameCount(sampleRate * durationSeconds)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            ambientPrepared = false
            return
        }

        buffer.frameLength = totalFrames
        let twoPi = Double.pi * 2.0
        let f1 = 132.0
        let f2 = 198.0
        let f3 = 264.0
        if let channel = buffer.floatChannelData?[0] {
            for i in 0..<Int(totalFrames) {
                let t = Double(i) / sampleRate
                let s1 = sin(twoPi * f1 * t) * 0.030
                let s2 = sin(twoPi * f2 * t) * 0.020
                let s3 = sin(twoPi * f3 * t) * 0.012
                channel[i] = Float(s1 + s2 + s3)
            }
        }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        player.volume = 0.12
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        ambientEngine = engine
        ambientPlayer = player
        ambientBuffer = buffer
    }
}

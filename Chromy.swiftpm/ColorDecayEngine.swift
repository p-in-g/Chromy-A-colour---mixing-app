import SwiftUI
import UIKit

@MainActor
final class ColorDecayEngine: ObservableObject {
    @Published var colorLevel: CGFloat = 1.0
    @Published var secondsUntilFade: Int = 0
    @Published var showAlert = false
    @Published var showReplayPrompt = false
    @Published var showSunsetEvent = false

    @Published var activeSunColor = Color(red: 1.0, green: 0.92, blue: 0.45)

    private var isRunning = false
    private let fadeTriggerLevel: CGFloat = 0.12
    private var decayPerSecond: CGFloat {
        // iPhone needs longer runway so the scripted "colourless" prompt appears before full fade.
        let duration: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 11.0 : 7.0
        return (1.0 - fadeTriggerLevel) / duration
    }

    func start() {
        isRunning = true
        colorLevel = 1.0
        secondsUntilFade = Int(((1.0 - fadeTriggerLevel) / decayPerSecond).rounded())
        showAlert = false
        showReplayPrompt = false
        showSunsetEvent = false
        activeSunColor = Color(red: 1.0, green: 0.92, blue: 0.45)
    }

    func update(delta: CGFloat) {
        guard isRunning else { return }
        guard !showReplayPrompt else { return }

        colorLevel = max(0.12, colorLevel - decayPerSecond * delta)
        updateCountdown()

        if colorLevel <= fadeTriggerLevel && !showAlert {
            showSunsetEvent = true
            showAlert = true
            secondsUntilFade = 0
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                self.showSunsetEvent = false
            }
        }
    }

    func sparkWorldAgain() {
        colorLevel = 1.0
        secondsUntilFade = Int(((1.0 - fadeTriggerLevel) / decayPerSecond).rounded())
        showAlert = false
        showReplayPrompt = false
        showSunsetEvent = false
    }

    func triggerImmediateColorless() {
        guard isRunning, !showAlert else { return }
        colorLevel = fadeTriggerLevel
        secondsUntilFade = 0
        showSunsetEvent = true
        showAlert = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            self.showSunsetEvent = false
        }
    }

    private func updateCountdown() {
        let remaining = max(0, colorLevel - fadeTriggerLevel)
        secondsUntilFade = Int((remaining / decayPerSecond).rounded())
    }
}

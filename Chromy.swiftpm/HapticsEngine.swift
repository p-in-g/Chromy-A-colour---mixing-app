import CoreHaptics
import Foundation

@MainActor
final class HapticsEngine {
    static let shared = HapticsEngine()

    private var engine: CHHapticEngine?

    private init() {
        prepare()
    }

    func pop() {
        play(intensity: 0.55, sharpness: 0.75, duration: 0.08)
    }

    func buzz() {
        play(intensity: 0.85, sharpness: 0.30, duration: 0.12)
    }

    func dropThud() {
        play(intensity: 0.95, sharpness: 0.22, duration: 0.16)
    }

    func proximityWhirr(closeness: CGFloat) {
        let c = max(0, min(1, closeness))
        let intensity = Float(0.22 + 0.68 * c)
        let sharpness = Float(0.18 + 0.52 * c)
        let duration = 0.07 + 0.09 * Double(c)
        play(intensity: intensity, sharpness: sharpness, duration: duration)
    }

    private func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            engine = nil
        }
    }

    private func play(intensity: Float, sharpness: Float, duration: Double) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if engine == nil { prepare() }
        guard let engine else { return }

        let i = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let s = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [i, s], relativeTime: 0, duration: duration)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            try? engine.start()
        }
    }
}

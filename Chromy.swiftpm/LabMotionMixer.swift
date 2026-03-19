import AVFoundation
import Combine
import CoreMotion
import Foundation

@MainActor
final class LabMotionMixer: ObservableObject {
    private let motion = CMMotionManager()
    private var onShake: (() -> Void)?
    private var isMonitoring = false
    private var lastShakeTime: TimeInterval = 0

    private var sloshPlayer: AVAudioPlayer?

    func start(onShake: @escaping () -> Void) {
        self.onShake = onShake
        guard !isMonitoring else { return }
        isMonitoring = true
        prepareSloshAudio()

        guard motion.isAccelerometerAvailable else { return }
        motion.accelerometerUpdateInterval = 0.05
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z
            let magnitude = sqrt(x * x + y * y + z * z)
            if magnitude > 1.75 {
                let now = Date().timeIntervalSince1970
                if now - self.lastShakeTime > 0.33 {
                    self.lastShakeTime = now
                    self.playSlosh()
                    self.onShake?()
                }
            }
        }
    }

    func stop() {
        motion.stopAccelerometerUpdates()
        isMonitoring = false
        onShake = nil
        sloshPlayer?.stop()
    }

    private func prepareSloshAudio() {
        guard sloshPlayer == nil else { return }
        guard let url = Bundle.main.url(forResource: "slosh", withExtension: "wav") else { return }
        do {
            sloshPlayer = try AVAudioPlayer(contentsOf: url)
            sloshPlayer?.prepareToPlay()
            sloshPlayer?.volume = 0.6
        } catch {
            sloshPlayer = nil
        }
    }

    private func playSlosh() {
        guard let sloshPlayer else { return }
        sloshPlayer.currentTime = 0
        sloshPlayer.play()
    }
}

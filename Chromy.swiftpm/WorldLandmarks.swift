import CoreGraphics

enum WorldLandmarks {
    static let homeX: CGFloat = 4.0
    static let homeZ: CGFloat = -6.0

    static func playerPosition(offsetX: CGFloat, offsetZ: CGFloat) -> (x: CGFloat, z: CGFloat) {
        (-offsetX / 220.0, -offsetZ / 220.0)
    }

    static func distanceToHome(offsetX: CGFloat, offsetZ: CGFloat) -> CGFloat {
        let p = playerPosition(offsetX: offsetX, offsetZ: offsetZ)
        let dx = p.x - homeX
        let dz = p.z - homeZ
        return sqrt(dx * dx + dz * dz)
    }

    static func offsetsNearHome() -> (x: CGFloat, z: CGFloat) {
        (-homeX * 220.0, -homeZ * 220.0)
    }
}

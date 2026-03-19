import SceneKit
import SwiftUI
import UIKit
import QuartzCore

struct EnvironmentSpellOrb: Identifiable {
    let id: UUID
    let color: Color
}

struct EnvironmentView: View {
    let offsetX: CGFloat
    let offsetZ: CGFloat
    let spellOrbs: [EnvironmentSpellOrb]
    let isSaturated: Bool
    let jumpTrigger: Int
    let zoomLevel: CGFloat
    let sunColor: Color
    let sunBrightness: CGFloat
    let guideLightActive: Bool
    let onWorldTap: (() -> Void)?

    var body: some View {
        ZStack {
            SceneKitEnvironmentView(
                offsetX: offsetX,
                offsetZ: offsetZ,
                spellOrbs: spellOrbs,
                isSaturated: isSaturated,
                jumpTrigger: jumpTrigger,
                zoomLevel: zoomLevel,
                sunColor: sunColor,
                sunBrightness: sunBrightness,
                guideLightActive: guideLightActive,
                onWorldTap: onWorldTap
            )
            .ignoresSafeArea()

            if !isSaturated {
                Color.black.opacity(0.22).ignoresSafeArea()
            }
        }
    }
}

private struct SceneKitEnvironmentView: UIViewRepresentable {
    let offsetX: CGFloat
    let offsetZ: CGFloat
    let spellOrbs: [EnvironmentSpellOrb]
    let isSaturated: Bool
    let jumpTrigger: Int
    let zoomLevel: CGFloat
    let sunColor: Color
    let sunBrightness: CGFloat
    let guideLightActive: Bool
    let onWorldTap: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        view.rendersContinuously = true
        view.antialiasingMode = isPhone ? .none : .multisampling2X
        view.preferredFramesPerSecond = isPhone ? 30 : 45
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.scene = Self.makeScene(
            isSaturated: isSaturated,
            sunColor: UIColor(sunColor),
            coordinator: context.coordinator
        )
        context.coordinator.onWorldTap = onWorldTap

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSceneTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onWorldTap = onWorldTap

        if coordinator.currentSaturation != isSaturated {
            uiView.scene = Self.makeScene(
                isSaturated: isSaturated,
                sunColor: UIColor(sunColor),
                coordinator: coordinator
            )
            coordinator.currentSaturation = isSaturated
        }

        let worldX = Float(offsetX / 220.0)
        let worldZ = Float(offsetZ / 220.0)
        coordinator.worldNode?.position.x = worldX
        coordinator.worldNode?.position.z = worldZ

        let playerX = -worldX
        let playerZ = -worldZ
        coordinator.ensureGroundAround(playerX: playerX, playerZ: playerZ, isSaturated: isSaturated)
        coordinator.updateSpellOrbs(spellOrbs)
        coordinator.updateZoom(zoomLevel: zoomLevel)
        coordinator.updateSun(color: UIColor(sunColor), brightness: sunBrightness, scene: uiView.scene)
        coordinator.updateGuideLight(active: guideLightActive, playerX: playerX, playerZ: playerZ, scene: uiView.scene)

        if coordinator.lastJumpTrigger != jumpTrigger {
            coordinator.lastJumpTrigger = jumpTrigger
            coordinator.performJump()
        }
    }

    static func makeScene(
        isSaturated: Bool,
        sunColor: UIColor,
        coordinator: Coordinator
    ) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = Coordinator.skyColor(isSaturated: isSaturated, sunColor: sunColor, brightness: 1.0)
        scene.fogStartDistance = 10
        scene.fogEndDistance = 42
        scene.fogColor = Coordinator.fogColor(isSaturated: isSaturated, sunColor: sunColor, brightness: 1.0)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 68
        cameraNode.position = SCNVector3(0, 2.5, 9.2)
        cameraNode.look(at: SCNVector3(0, 1.1, -7.0))
        scene.rootNode.addChildNode(cameraNode)
        coordinator.cameraNode = cameraNode

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = isSaturated ? 980 : 600
        ambient.light?.color = isSaturated ? UIColor.white : UIColor(white: 0.84, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = isSaturated ? 1520 : 640
        sun.eulerAngles = SCNVector3(-0.95, 0.4, 0.0)
        scene.rootNode.addChildNode(sun)
        coordinator.sunLightNode = sun

        let sunOrb = SCNNode(geometry: SCNSphere(radius: 1.0))
        sunOrb.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.92, blue: 0.45, alpha: 1)
        sunOrb.geometry?.firstMaterial?.emission.contents = UIColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1)
        sunOrb.position = SCNVector3(10, 8, -18)
        scene.rootNode.addChildNode(sunOrb)
        coordinator.sunNode = sunOrb

        let sunGlow = SCNNode(geometry: SCNSphere(radius: 1.45))
        sunGlow.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
        sunGlow.geometry?.firstMaterial?.emission.contents = UIColor(red: 1.0, green: 0.9, blue: 0.45, alpha: 1)
        sunGlow.geometry?.firstMaterial?.transparency = 0.35
        sunGlow.position = SCNVector3(10, 8, -18)
        scene.rootNode.addChildNode(sunGlow)
        coordinator.sunGlowNode = sunGlow

        let sunAura = SCNNode(geometry: SCNSphere(radius: 2.4))
        sunAura.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
        sunAura.geometry?.firstMaterial?.emission.contents = UIColor(red: 1.0, green: 0.9, blue: 0.45, alpha: 1)
        sunAura.geometry?.firstMaterial?.transparency = 0.20
        sunAura.position = SCNVector3(10, 8, -18)
        scene.rootNode.addChildNode(sunAura)
        coordinator.sunAuraNode = sunAura

        let sunHaloInner = SCNNode(geometry: SCNSphere(radius: 3.8))
        sunHaloInner.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
        sunHaloInner.geometry?.firstMaterial?.emission.contents = UIColor(red: 1.0, green: 0.9, blue: 0.45, alpha: 1)
        sunHaloInner.geometry?.firstMaterial?.transparency = 0.11
        sunHaloInner.position = SCNVector3(10, 8, -18)
        scene.rootNode.addChildNode(sunHaloInner)
        coordinator.sunHaloInnerNode = sunHaloInner

        let sunHaloOuter = SCNNode(geometry: SCNSphere(radius: 5.4))
        sunHaloOuter.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
        sunHaloOuter.geometry?.firstMaterial?.emission.contents = UIColor(red: 1.0, green: 0.9, blue: 0.45, alpha: 1)
        sunHaloOuter.geometry?.firstMaterial?.transparency = 0.05
        sunHaloOuter.position = SCNVector3(10, 8, -18)
        scene.rootNode.addChildNode(sunHaloOuter)
        coordinator.sunHaloOuterNode = sunHaloOuter

        let world = SCNNode()
        scene.rootNode.addChildNode(world)
        coordinator.worldNode = world
        coordinator.currentSaturation = isSaturated
        coordinator.resetProceduralState()
        addClouds(to: world, isSaturated: isSaturated)
        addBirds(to: world, isSaturated: isSaturated)
        addHome(to: world, isSaturated: isSaturated)

        return scene
    }

    static func addClouds(to world: SCNNode, isSaturated: Bool) {
        for i in 0..<16 {
            let cloud = SCNNode()
            let color1 = isSaturated ? UIColor(white: 0.96, alpha: 0.95) : UIColor(white: 0.86, alpha: 0.9)
            let color2 = isSaturated ? UIColor(white: 0.99, alpha: 0.95) : UIColor(white: 0.9, alpha: 0.9)
            let color3 = isSaturated ? UIColor(white: 0.93, alpha: 0.92) : UIColor(white: 0.82, alpha: 0.88)

            let block1 = SCNBox(width: 2.4, height: 0.32, length: 0.65, chamferRadius: 0)
            block1.firstMaterial?.diffuse.contents = color1
            let block1Node = SCNNode(geometry: block1)
            cloud.addChildNode(block1Node)

            let block2 = SCNBox(width: 1.5, height: 0.28, length: 0.65, chamferRadius: 0)
            block2.firstMaterial?.diffuse.contents = color2
            let block2Node = SCNNode(geometry: block2)
            block2Node.position = SCNVector3(0.7, 0.2, 0)
            cloud.addChildNode(block2Node)

            let block3 = SCNBox(width: 1.0, height: 0.22, length: 0.65, chamferRadius: 0)
            block3.firstMaterial?.diffuse.contents = color3
            let block3Node = SCNNode(geometry: block3)
            block3Node.position = SCNVector3(-0.95, 0.14, 0)
            cloud.addChildNode(block3Node)

            cloud.position = SCNVector3(Float(-24 + i * 3), Float(5.8 + Double.random(in: -0.6...1.0)), Float(-6 - i * 2))
            cloud.scale = SCNVector3(0.85 + Float(Double.random(in: 0.0...0.4)), 0.85 + Float(Double.random(in: 0.0...0.3)), 1)
            world.addChildNode(cloud)
        }
    }

    static func addBirds(to world: SCNNode, isSaturated: Bool) {
        let birdColor: UIColor = isSaturated ? UIColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1) : UIColor(white: 0.35, alpha: 1)
        for flock in 0..<5 {
            let flockNode = SCNNode()
            for j in 0..<3 {
                let bird = SCNNode()
                let wing = SCNBox(width: 0.26, height: 0.03, length: 0.08, chamferRadius: 0)
                wing.firstMaterial?.diffuse.contents = birdColor

                let left = SCNNode(geometry: wing)
                left.position = SCNVector3(-0.12, 0, 0)
                left.eulerAngles = SCNVector3(0, 0, 0.55)
                bird.addChildNode(left)

                let right = SCNNode(geometry: wing)
                right.position = SCNVector3(0.12, 0, 0)
                right.eulerAngles = SCNVector3(0, 0, -0.55)
                bird.addChildNode(right)

                let leftUp = SCNAction.rotateTo(x: 0, y: 0, z: 0.15, duration: 0.16, usesShortestUnitArc: true)
                let leftDown = SCNAction.rotateTo(x: 0, y: 0, z: 0.55, duration: 0.16, usesShortestUnitArc: true)
                left.runAction(.repeatForever(.sequence([leftUp, leftDown])))

                let rightUp = SCNAction.rotateTo(x: 0, y: 0, z: -0.15, duration: 0.16, usesShortestUnitArc: true)
                let rightDown = SCNAction.rotateTo(x: 0, y: 0, z: -0.55, duration: 0.16, usesShortestUnitArc: true)
                right.runAction(.repeatForever(.sequence([rightUp, rightDown])))

                bird.position = SCNVector3(Float(j) * 0.6, Float(Double.random(in: -0.08...0.08)), Float(Double.random(in: -0.1...0.1)))
                flockNode.addChildNode(bird)
            }

            flockNode.position = SCNVector3(Float(-18 + flock * 5), Float(6.6 + Double.random(in: -0.3...1.2)), Float(-18 - flock * 4))
            flockNode.eulerAngles = SCNVector3(0, Float(Double.random(in: -0.3...0.3)), 0)
            world.addChildNode(flockNode)

            let drift = SCNAction.moveBy(
                x: CGFloat(48),
                y: CGFloat(Double.random(in: -0.5...0.5)),
                z: CGFloat(Double.random(in: -3.5...3.5)),
                duration: 13.5 + Double(flock)
            )
            drift.timingMode = SCNActionTimingMode.linear
            let reset = SCNAction.moveBy(
                x: CGFloat(-48),
                y: CGFloat(Double.random(in: -0.35...0.35)),
                z: CGFloat(Double.random(in: -2.0...2.0)),
                duration: 0
            )
            let swayUp = SCNAction.rotateBy(x: 0, y: 0.05, z: 0, duration: 1.1)
            let swayDown = SCNAction.rotateBy(x: 0, y: -0.05, z: 0, duration: 1.1)
            flockNode.runAction(.repeatForever(.sequence([drift, reset])))
            flockNode.runAction(.repeatForever(.sequence([swayUp, swayDown])))
        }
    }

    static func addHome(to world: SCNNode, isSaturated: Bool) {
        let home = SCNNode()
        home.position = SCNVector3(Float(WorldLandmarks.homeX), -0.32, Float(WorldLandmarks.homeZ))

        let base = SCNBox(width: 2.1, height: 1.4, length: 1.8, chamferRadius: 0)
        base.firstMaterial?.diffuse.contents = isSaturated
        ? UIColor(red: 0.93, green: 0.82, blue: 0.62, alpha: 1)
        : UIColor(white: 0.68, alpha: 1)
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, 0.7, 0)
        home.addChildNode(baseNode)

        let roof = SCNPyramid(width: 2.5, height: 1.0, length: 2.2)
        roof.firstMaterial?.diffuse.contents = isSaturated
        ? UIColor(red: 0.78, green: 0.34, blue: 0.24, alpha: 1)
        : UIColor(white: 0.52, alpha: 1)
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(0, 1.9, 0)
        home.addChildNode(roofNode)

        let door = SCNBox(width: 0.45, height: 0.75, length: 0.04, chamferRadius: 0)
        door.firstMaterial?.diffuse.contents = UIColor(red: 0.40, green: 0.24, blue: 0.12, alpha: 1)
        let doorNode = SCNNode(geometry: door)
        doorNode.position = SCNVector3(0, 0.34, 0.92)
        home.addChildNode(doorNode)

        let chimney = SCNBox(width: 0.28, height: 0.75, length: 0.28, chamferRadius: 0)
        chimney.firstMaterial?.diffuse.contents = isSaturated
        ? UIColor(red: 0.55, green: 0.50, blue: 0.52, alpha: 1)
        : UIColor(white: 0.5, alpha: 1)
        let chimneyNode = SCNNode(geometry: chimney)
        chimneyNode.position = SCNVector3(0.62, 2.2, -0.2)
        home.addChildNode(chimneyNode)

        world.addChildNode(home)
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var worldNode: SCNNode?
        var cameraNode: SCNNode?
        var sunLightNode: SCNNode?
        var sunNode: SCNNode?
        var sunGlowNode: SCNNode?
        var sunAuraNode: SCNNode?
        var sunHaloInnerNode: SCNNode?
        var sunHaloOuterNode: SCNNode?
        var currentSaturation = true
        var lastJumpTrigger = 0
        var onWorldTap: (() -> Void)?
        private var lastSunColor: UIColor?
        private var guideLightNode: SCNNode?
        private var guideGlowNode: SCNNode?
        private var guideAuraNode: SCNNode?
        private var guideHaloNode: SCNNode?
        private var guideMoveStart = SCNVector3Zero
        private var guideMoveTarget = SCNVector3Zero
        private var guideMoveProgress: Float = 1
        private var guideMoveDuration: Float = 1.6
        private var lastGuideUpdateTime: CFTimeInterval = 0

        private let chunkSize: Float = 14
        private var generatedChunkKeys: Set<String> = []
        private var loadedChunkNodes: [String: SCNNode] = [:]
        private var spellOrbNodes: [UUID: SCNNode] = [:]
        private var jumpInProgress = false

        @objc
        func handleSceneTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            onWorldTap?()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        func resetProceduralState() {
            generatedChunkKeys.removeAll()
            loadedChunkNodes.removeAll()
            spellOrbNodes.removeAll()
        }

        func updateSpellOrbs(_ orbs: [EnvironmentSpellOrb]) {
            guard let worldNode else { return }
            let ids = Set(orbs.map(\.id))

            for (id, node) in spellOrbNodes where !ids.contains(id) {
                node.removeFromParentNode()
                spellOrbNodes.removeValue(forKey: id)
            }

            for orb in orbs {
                if let existing = spellOrbNodes[orb.id] {
                    recolorSpellOrb(existing, to: UIColor(orb.color))
                    continue
                }
                let node = makeSpellOrbNode(for: orb)
                spellOrbNodes[orb.id] = node
                worldNode.addChildNode(node)
            }
        }

        private func makeSpellOrbNode(for orb: EnvironmentSpellOrb) -> SCNNode {
            let root = SCNNode()
            let c = UIColor(orb.color)
            let seed = seedFromUUID(orb.id)
            let x = -34.0 + (noise(seed: seed, offset: 1) * 68.0)
            let z = -34.0 + (noise(seed: seed, offset: 2) * 68.0)
            let y = 1.2 + (noise(seed: seed, offset: 3) * 1.8)
            root.position = SCNVector3(Float(x), Float(y), Float(z))

            let core = SCNNode(geometry: SCNSphere(radius: 0.22))
            core.geometry?.firstMaterial?.diffuse.contents = c
            core.geometry?.firstMaterial?.emission.contents = c.withAlphaComponent(0.75)
            root.addChildNode(core)

            let glow = SCNNode(geometry: SCNSphere(radius: 0.42))
            glow.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
            glow.geometry?.firstMaterial?.emission.contents = c.withAlphaComponent(0.85)
            glow.geometry?.firstMaterial?.transparency = 0.38
            root.addChildNode(glow)

            let up = SCNAction.moveBy(x: 0, y: 0.28, z: 0, duration: 1.2 + noise(seed: seed, offset: 4))
            up.timingMode = .easeInEaseOut
            let down = SCNAction.moveBy(x: 0, y: -0.28, z: 0, duration: 1.2 + noise(seed: seed, offset: 5))
            down.timingMode = .easeInEaseOut
            root.runAction(.repeatForever(.sequence([up, down])))
            root.runAction(.repeatForever(.rotateBy(x: 0, y: 0.8, z: 0, duration: 4.0)))

            return root
        }

        private func recolorSpellOrb(_ root: SCNNode, to color: UIColor) {
            guard let core = root.childNodes.first else { return }
            core.geometry?.firstMaterial?.diffuse.contents = color
            core.geometry?.firstMaterial?.emission.contents = color.withAlphaComponent(0.75)
            if root.childNodes.count > 1 {
                let glow = root.childNodes[1]
                glow.geometry?.firstMaterial?.emission.contents = color.withAlphaComponent(0.85)
            }
        }

        private func seedFromUUID(_ uuid: UUID) -> UInt64 {
            var value: UInt64 = 1469598103934665603
            for byte in uuid.uuidString.utf8 {
                value ^= UInt64(byte)
                value &*= 1099511628211
            }
            return value
        }

        private func noise(seed: UInt64, offset: UInt64) -> Double {
            let x = seed &+ (offset &* 0x9E3779B97F4A7C15)
            let v = x ^ (x >> 30) ^ (x >> 54)
            return Double(v % 10_000) / 10_000.0
        }

        func updateZoom(zoomLevel: CGFloat) {
            guard let camera = cameraNode?.camera else { return }
            let clamped = max(0.75, min(1.9, zoomLevel))
            let baseFOV: CGFloat = 68
            camera.fieldOfView = Double(max(34, min(84, baseFOV / clamped)))
        }

        func updateSun(color: UIColor, brightness: CGFloat, scene: SCNScene?) {
            let b = max(0.12, min(1.0, brightness))
            let changedColor = hasSunColorChanged(to: color)

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.45

            sunNode?.geometry?.firstMaterial?.diffuse.contents = color
            sunNode?.geometry?.firstMaterial?.emission.contents = color.withAlphaComponent(1.0)
            sunNode?.scale = SCNVector3(0.78 + Float(0.40 * b), 0.78 + Float(0.40 * b), 0.78 + Float(0.40 * b))

            sunGlowNode?.geometry?.firstMaterial?.emission.contents = color.withAlphaComponent(0.95)
            sunGlowNode?.geometry?.firstMaterial?.transparency = 0.22 + CGFloat(0.55 * b)
            sunGlowNode?.scale = SCNVector3(0.85 + Float(0.85 * b), 0.85 + Float(0.85 * b), 0.85 + Float(0.85 * b))

            sunAuraNode?.geometry?.firstMaterial?.emission.contents = color.withAlphaComponent(0.72)
            sunAuraNode?.geometry?.firstMaterial?.transparency = 0.08 + CGFloat(0.34 * b)
            sunAuraNode?.scale = SCNVector3(0.92 + Float(1.10 * b), 0.92 + Float(1.10 * b), 0.92 + Float(1.10 * b))

            sunHaloInnerNode?.geometry?.firstMaterial?.emission.contents = color.withAlphaComponent(0.45)
            sunHaloInnerNode?.geometry?.firstMaterial?.transparency = 0.05 + CGFloat(0.22 * b)
            sunHaloInnerNode?.scale = SCNVector3(0.9 + Float(1.25 * b), 0.9 + Float(1.25 * b), 0.9 + Float(1.25 * b))

            sunHaloOuterNode?.geometry?.firstMaterial?.emission.contents = color.withAlphaComponent(0.26)
            sunHaloOuterNode?.geometry?.firstMaterial?.transparency = 0.03 + CGFloat(0.14 * b)
            sunHaloOuterNode?.scale = SCNVector3(0.92 + Float(1.55 * b), 0.92 + Float(1.55 * b), 0.92 + Float(1.55 * b))

            sunLightNode?.light?.intensity = CGFloat(640 + 1300 * b)
            scene?.background.contents = Self.skyColor(isSaturated: currentSaturation, sunColor: color, brightness: b)
            scene?.fogColor = Self.fogColor(isSaturated: currentSaturation, sunColor: color, brightness: b)
            SCNTransaction.commit()

            if changedColor {
                runSunBurst()
            }
            lastSunColor = color
        }

        private func runSunBurst() {
            guard let sunGlowNode, let sunAuraNode else { return }
            let pulseUp = SCNAction.scale(by: 1.24, duration: 0.34)
            pulseUp.timingMode = .easeOut
            let pulseDown = SCNAction.scale(by: 0.82, duration: 0.42)
            pulseDown.timingMode = .easeInEaseOut
            sunGlowNode.runAction(.sequence([pulseUp, pulseDown]))

            let auraUp = SCNAction.scale(by: 1.34, duration: 0.36)
            auraUp.timingMode = .easeOut
            let auraDown = SCNAction.scale(by: 0.74, duration: 0.52)
            auraDown.timingMode = .easeInEaseOut
            sunAuraNode.runAction(.sequence([auraUp, auraDown]))

            if let sunHaloInnerNode {
                let h1Up = SCNAction.scale(by: 1.16, duration: 0.40)
                h1Up.timingMode = .easeOut
                let h1Down = SCNAction.scale(by: 0.86, duration: 0.56)
                h1Down.timingMode = .easeInEaseOut
                sunHaloInnerNode.runAction(.sequence([h1Up, h1Down]))
            }

            if let sunHaloOuterNode {
                let h2Up = SCNAction.scale(by: 1.22, duration: 0.44)
                h2Up.timingMode = .easeOut
                let h2Down = SCNAction.scale(by: 0.82, duration: 0.62)
                h2Down.timingMode = .easeInEaseOut
                sunHaloOuterNode.runAction(.sequence([h2Up, h2Down]))
            }
        }

        private func hasSunColorChanged(to newColor: UIColor) -> Bool {
            guard let lastSunColor else { return true }
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            lastSunColor.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            newColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            let d = abs(r1 - r2) + abs(g1 - g2) + abs(b1 - b2)
            return d > 0.08
        }

        static func skyColor(isSaturated: Bool, sunColor: UIColor, brightness: CGFloat) -> UIColor {
            if !isSaturated {
                let g = 0.58 + 0.14 * brightness
                return UIColor(white: g, alpha: 1)
            }
            let base = UIColor(red: 0.62, green: 0.82, blue: 1.0, alpha: 1)
            let mixed = blend(base, sunColor, amount: 0.28)
            return adjustBrightness(mixed, factor: 0.90 + 0.30 * brightness)
        }

        static func fogColor(isSaturated: Bool, sunColor: UIColor, brightness: CGFloat) -> UIColor {
            if !isSaturated {
                let g = 0.66 + 0.10 * brightness
                return UIColor(white: g, alpha: 1)
            }
            let base = UIColor(red: 0.84, green: 0.92, blue: 1.0, alpha: 1)
            let mixed = blend(base, sunColor, amount: 0.20)
            return adjustBrightness(mixed, factor: 0.96 + 0.22 * brightness)
        }

        private static func blend(_ a: UIColor, _ b: UIColor, amount: CGFloat) -> UIColor {
            var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
            var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
            a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
            b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
            let t = max(0, min(1, amount))
            return UIColor(
                red: ar + (br - ar) * t,
                green: ag + (bg - ag) * t,
                blue: ab + (bb - ab) * t,
                alpha: aa + (ba - aa) * t
            )
        }

        private static func adjustBrightness(_ color: UIColor, factor: CGFloat) -> UIColor {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return UIColor(
                red: max(0, min(1, r * factor)),
                green: max(0, min(1, g * factor)),
                blue: max(0, min(1, b * factor)),
                alpha: a
            )
        }

        func ensureGroundAround(playerX: Float, playerZ: Float, isSaturated: Bool) {
            guard let worldNode else { return }
            let centerCX = Int(floor(playerX / chunkSize))
            let centerCZ = Int(floor(playerZ / chunkSize))
            let loadRadius = 2
            let keepRadius = 3

            for cx in (centerCX - loadRadius)...(centerCX + loadRadius) {
                for cz in (centerCZ - loadRadius)...(centerCZ + loadRadius) {
                    let key = "\(cx)_\(cz)"
                    guard !generatedChunkKeys.contains(key) else { continue }
                    generatedChunkKeys.insert(key)
                    let chunk = makeChunk(cx: cx, cz: cz, isSaturated: isSaturated)
                    loadedChunkNodes[key] = chunk
                    worldNode.addChildNode(chunk)
                }
            }

            // Unload far chunks to avoid unbounded node growth and frame drops over time.
            let staleKeys = generatedChunkKeys.filter { key in
                let parts = key.split(separator: "_")
                guard parts.count == 2,
                      let cx = Int(parts[0]),
                      let cz = Int(parts[1]) else {
                    return true
                }
                return abs(cx - centerCX) > keepRadius || abs(cz - centerCZ) > keepRadius
            }

            for key in staleKeys {
                generatedChunkKeys.remove(key)
                if let node = loadedChunkNodes.removeValue(forKey: key) {
                    node.removeFromParentNode()
                }
            }
        }

        func performJump() {
            guard let cameraNode, !jumpInProgress else { return }
            jumpInProgress = true

            let up = SCNAction.moveBy(x: 0, y: 0.55, z: 0, duration: 0.12)
            up.timingMode = .easeOut
            let down = SCNAction.moveBy(x: 0, y: -0.55, z: 0, duration: 0.20)
            down.timingMode = .easeIn
            let done = SCNAction.run { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.jumpInProgress = false
                }
            }

            cameraNode.runAction(.sequence([up, down, done]), forKey: "jump")
        }

        func updateGuideLight(active: Bool, playerX: Float, playerZ: Float, scene: SCNScene?) {
            guard let scene else { return }

            if !active {
                removeGuideLight()
                return
            }

            ensureGuideLightExists(in: scene, playerX: playerX, playerZ: playerZ)

            let now = CACurrentMediaTime()
            if lastGuideUpdateTime == 0 { lastGuideUpdateTime = now }
            let dt = Float(max(0, min(0.08, now - lastGuideUpdateTime)))
            lastGuideUpdateTime = now

            guideMoveProgress += dt / max(0.45, guideMoveDuration)
            if guideMoveProgress >= 1 {
                guideMoveStart = guideMoveTarget
                guideMoveTarget = randomGuideTarget(playerX: playerX, playerZ: playerZ)
                guideMoveProgress = 0
                guideMoveDuration = Float.random(in: 1.0...2.2)
            }

            let t = guideMoveProgress
            let eased = t * t * (3 - (2 * t))
            let x = guideMoveStart.x + ((guideMoveTarget.x - guideMoveStart.x) * eased)
            let y = guideMoveStart.y + ((guideMoveTarget.y - guideMoveStart.y) * eased) + (sin(Float(now) * 3.2) * 0.16)
            let z = guideMoveStart.z + ((guideMoveTarget.z - guideMoveStart.z) * eased)

            let pos = SCNVector3(x, y, z)
            guideLightNode?.position = pos
            guideGlowNode?.position = pos
            guideAuraNode?.position = pos
            guideHaloNode?.position = pos
        }

        private func ensureGuideLightExists(in scene: SCNScene, playerX: Float, playerZ: Float) {
            guard guideLightNode == nil else { return }

            let core = SCNNode(geometry: SCNSphere(radius: 0.46))
            core.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            core.geometry?.firstMaterial?.emission.contents = UIColor.white

            let glow = SCNNode(geometry: SCNSphere(radius: 1.05))
            glow.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
            glow.geometry?.firstMaterial?.emission.contents = UIColor.white
            glow.geometry?.firstMaterial?.transparency = 0.68

            let aura = SCNNode(geometry: SCNSphere(radius: 1.90))
            aura.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
            aura.geometry?.firstMaterial?.emission.contents = UIColor.white
            aura.geometry?.firstMaterial?.transparency = 0.34

            let halo = SCNNode(geometry: SCNSphere(radius: 3.10))
            halo.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
            halo.geometry?.firstMaterial?.emission.contents = UIColor.white
            halo.geometry?.firstMaterial?.transparency = 0.12

            let start = randomGuideTarget(playerX: playerX, playerZ: playerZ)
            guideLightNode = core
            guideGlowNode = glow
            guideAuraNode = aura
            guideHaloNode = halo
            guideMoveStart = start
            guideMoveTarget = randomGuideTarget(playerX: playerX, playerZ: playerZ)
            guideMoveProgress = 0
            guideMoveDuration = Float.random(in: 1.0...2.2)
            lastGuideUpdateTime = CACurrentMediaTime()

            core.position = start
            glow.position = start
            aura.position = start
            halo.position = start
            scene.rootNode.addChildNode(core)
            scene.rootNode.addChildNode(glow)
            scene.rootNode.addChildNode(aura)
            scene.rootNode.addChildNode(halo)
        }

        private func removeGuideLight() {
            guideLightNode?.removeFromParentNode()
            guideGlowNode?.removeFromParentNode()
            guideAuraNode?.removeFromParentNode()
            guideHaloNode?.removeFromParentNode()
            guideLightNode = nil
            guideGlowNode = nil
            guideAuraNode = nil
            guideHaloNode = nil
            lastGuideUpdateTime = 0
        }

        private func randomGuideTarget(playerX: Float, playerZ: Float) -> SCNVector3 {
            SCNVector3(
                playerX + Float.random(in: -3.4...3.4),
                Float.random(in: 1.4...3.4),
                playerZ - Float.random(in: 4.6...9.4)
            )
        }

        private func makeChunk(cx: Int, cz: Int, isSaturated: Bool) -> SCNNode {
            let chunk = SCNNode()
            let baseX = Float(cx) * chunkSize
            let baseZ = Float(cz) * chunkSize

            let ground = SCNBox(width: CGFloat(chunkSize), height: 0.9, length: CGFloat(chunkSize), chamferRadius: 0)
            ground.firstMaterial?.diffuse.contents = isSaturated
            ? UIColor(red: 0.39, green: 0.76, blue: 0.33, alpha: 1)
            : UIColor(white: 0.46, alpha: 1)
            let groundNode = SCNNode(geometry: ground)
            groundNode.position = SCNVector3(baseX, -1.25, baseZ)
            chunk.addChildNode(groundNode)

            let trailChance = noise(cx: cx, cz: cz, n: 204)
            if trailChance > 0.26 {
                let trailCount = trailChance > 0.62 ? 4 : 2
                for i in 0..<trailCount {
                    let tx = baseX + Float((noise(cx: cx, cz: cz, n: 206 + i) - 0.5) * Double(chunkSize) * 0.9)
                    let tz = baseZ + Float((noise(cx: cx, cz: cz, n: 216 + i) - 0.5) * Double(chunkSize) * 0.9)
                    chunk.addChildNode(makeTrailNode(isSaturated: isSaturated, x: tx, z: tz, index: i))
                }
            }

            for n in 0..<2 {
                let nx = noise(cx: cx, cz: cz, n: n * 3)
                let nz = noise(cx: cx, cz: cz, n: n * 3 + 1)
                let x = baseX + Float((nx - 0.5) * Double(chunkSize))
                let z = baseZ + Float((nz - 0.5) * Double(chunkSize))
                if abs(x) < 2.5 { continue }
                chunk.addChildNode(makeTreeNode(isSaturated: isSaturated, x: x, z: z))
            }

            if noise(cx: cx, cz: cz, n: 9) > 0.66 {
                let x = baseX + Float((noise(cx: cx, cz: cz, n: 10) - 0.5) * 5.0)
                let z = baseZ + Float((noise(cx: cx, cz: cz, n: 11) - 0.5) * Double(chunkSize))
                chunk.addChildNode(makeRoadBlockNode(isSaturated: isSaturated, x: x, z: z))
            }

            for i in 0..<3 {
                let x = baseX + Float((noise(cx: cx, cz: cz, n: 20 + i) - 0.5) * Double(chunkSize))
                let z = baseZ + Float((noise(cx: cx, cz: cz, n: 24 + i) - 0.5) * Double(chunkSize))
                chunk.addChildNode(makeFlowerNode(isSaturated: isSaturated, x: x, z: z, tintIndex: i))
            }

            for i in 0..<3 {
                let x = baseX + Float((noise(cx: cx, cz: cz, n: 52 + i) - 0.5) * Double(chunkSize))
                let z = baseZ + Float((noise(cx: cx, cz: cz, n: 56 + i) - 0.5) * Double(chunkSize))
                chunk.addChildNode(makeBushNode(isSaturated: isSaturated, x: x, z: z))
            }

            for i in 0..<2 {
                let x = baseX + Float((noise(cx: cx, cz: cz, n: 62 + i) - 0.5) * Double(chunkSize))
                let z = baseZ + Float((noise(cx: cx, cz: cz, n: 66 + i) - 0.5) * Double(chunkSize))
                chunk.addChildNode(makeVineNode(isSaturated: isSaturated, x: x, z: z, index: i))
            }

            if noise(cx: cx, cz: cz, n: 31) > 0.58 {
                let x = baseX + Float((noise(cx: cx, cz: cz, n: 32) - 0.5) * Double(chunkSize))
                let z = baseZ + Float((noise(cx: cx, cz: cz, n: 33) - 0.5) * Double(chunkSize))
                chunk.addChildNode(makeMushroomNode(isSaturated: isSaturated, x: x, z: z))
            }

            if noise(cx: cx, cz: cz, n: 40) > 0.78 {
                let x = baseX + Float((noise(cx: cx, cz: cz, n: 41) - 0.5) * Double(chunkSize))
                let z = baseZ + Float((noise(cx: cx, cz: cz, n: 42) - 0.5) * Double(chunkSize))
                chunk.addChildNode(makeAnimalNode(isSaturated: isSaturated, x: x, z: z))
            }

            return chunk
        }

        private func makeTreeNode(isSaturated: Bool, x: Float, z: Float) -> SCNNode {
            let tree = SCNNode()

            let trunk = SCNBox(width: 0.42, height: 2.35, length: 0.42, chamferRadius: 0)
            trunk.firstMaterial?.diffuse.contents = isSaturated
            ? UIColor(red: 0.40, green: 0.23, blue: 0.12, alpha: 1)
            : UIColor(white: 0.34, alpha: 1)
            let trunkNode = SCNNode(geometry: trunk)
            trunkNode.position = SCNVector3(0, 0.25, 0)
            tree.addChildNode(trunkNode)

            let rootBlock = SCNBox(width: 0.72, height: 0.18, length: 0.72, chamferRadius: 0)
            rootBlock.firstMaterial?.diffuse.contents = trunk.firstMaterial?.diffuse.contents
            let rootNode = SCNNode(geometry: rootBlock)
            rootNode.position = SCNVector3(0, -0.92, 0)
            tree.addChildNode(rootNode)

            let canopy1 = SCNBox(width: 1.95, height: 0.75, length: 1.95, chamferRadius: 0)
            canopy1.firstMaterial?.diffuse.contents = isSaturated
            ? UIColor(red: 0.18, green: 0.66, blue: 0.20, alpha: 1)
            : UIColor(white: 0.52, alpha: 1)
            let canopy1Node = SCNNode(geometry: canopy1)
            canopy1Node.position = SCNVector3(0, 1.72, 0)
            tree.addChildNode(canopy1Node)

            let canopy2 = SCNBox(width: 1.42, height: 0.62, length: 1.42, chamferRadius: 0)
            canopy2.firstMaterial?.diffuse.contents = isSaturated
            ? UIColor(red: 0.22, green: 0.74, blue: 0.24, alpha: 1)
            : UIColor(white: 0.58, alpha: 1)
            let canopy2Node = SCNNode(geometry: canopy2)
            canopy2Node.position = SCNVector3(0, 2.45, 0)
            tree.addChildNode(canopy2Node)

            let canopy3 = SCNBox(width: 0.9, height: 0.52, length: 0.9, chamferRadius: 0)
            canopy3.firstMaterial?.diffuse.contents = isSaturated
            ? UIColor(red: 0.27, green: 0.80, blue: 0.29, alpha: 1)
            : UIColor(white: 0.62, alpha: 1)
            let canopy3Node = SCNNode(geometry: canopy3)
            canopy3Node.position = SCNVector3(0, 3.0, 0)
            tree.addChildNode(canopy3Node)

            for i in 0..<4 {
                let sideLeaf = SCNBox(width: 0.45, height: 0.34, length: 0.45, chamferRadius: 0)
                sideLeaf.firstMaterial?.diffuse.contents = canopy2.firstMaterial?.diffuse.contents
                let sideNode = SCNNode(geometry: sideLeaf)
                let angle = Float(i) * (.pi * 0.5)
                sideNode.position = SCNVector3(cos(angle) * 0.82, 2.15, sin(angle) * 0.82)
                tree.addChildNode(sideNode)
            }

            tree.position = SCNVector3(x, -0.32, z)
            tree.runAction(.repeatForever(.sequence([
                .rotateBy(x: 0, y: 0.04, z: 0, duration: 2.8),
                .rotateBy(x: 0, y: -0.04, z: 0, duration: 2.8)
            ])))
            return tree
        }

        private func makeRoadBlockNode(isSaturated: Bool, x: Float, z: Float) -> SCNNode {
            let block = SCNBox(width: 1.2, height: 1.0, length: 1.0, chamferRadius: 0)
            block.firstMaterial?.diffuse.contents = isSaturated
            ? UIColor(red: 0.78, green: 0.32, blue: 0.22, alpha: 1)
            : UIColor(white: 0.54, alpha: 1)
            let node = SCNNode(geometry: block)
            node.position = SCNVector3(x, -0.28, z)
            return node
        }

        private func makeTrailNode(isSaturated: Bool, x: Float, z: Float, index: Int) -> SCNNode {
            let width: CGFloat = index.isMultiple(of: 2) ? 1.2 : 0.85
            let length: CGFloat = index.isMultiple(of: 2) ? 0.65 : 1.05
            let tile = SCNBox(width: width, height: 0.06, length: length, chamferRadius: 0)
            tile.firstMaterial?.diffuse.contents = isSaturated
            ? UIColor(red: 0.67, green: 0.51, blue: 0.33, alpha: 1)
            : UIColor(white: 0.56, alpha: 1)
            let node = SCNNode(geometry: tile)
            node.position = SCNVector3(x, -0.79, z)
            node.eulerAngles = SCNVector3(0, Float(Double.random(in: -0.65...0.65)), 0)
            return node
        }

        private func makeMushroomNode(isSaturated: Bool, x: Float, z: Float) -> SCNNode {
            let mushroom = SCNNode()

            let stem = SCNBox(width: 0.14, height: 0.45, length: 0.14, chamferRadius: 0)
            stem.firstMaterial?.diffuse.contents = isSaturated
            ? UIColor(red: 0.96, green: 0.93, blue: 0.80, alpha: 1)
            : UIColor(white: 0.72, alpha: 1)
            let stemNode = SCNNode(geometry: stem)
            stemNode.position = SCNVector3(0, -0.45, 0)
            mushroom.addChildNode(stemNode)

            let cap = SCNBox(width: 0.44, height: 0.2, length: 0.44, chamferRadius: 0)
            cap.firstMaterial?.diffuse.contents = isSaturated
            ? UIColor(red: 0.88, green: 0.2, blue: 0.25, alpha: 1)
            : UIColor(white: 0.60, alpha: 1)
            let capNode = SCNNode(geometry: cap)
            capNode.position = SCNVector3(0, -0.10, 0)
            mushroom.addChildNode(capNode)

            mushroom.position = SCNVector3(x, -0.2, z)
            return mushroom
        }

        private func makeAnimalNode(isSaturated: Bool, x: Float, z: Float) -> SCNNode {
            let animal = SCNNode()

            let body = SCNBox(width: 0.9, height: 0.55, length: 0.45, chamferRadius: 0)
            body.firstMaterial?.diffuse.contents = isSaturated
            ? UIColor(red: 0.82, green: 0.72, blue: 0.62, alpha: 1)
            : UIColor(white: 0.62, alpha: 1)
            let bodyNode = SCNNode(geometry: body)
            bodyNode.position = SCNVector3(0, -0.42, 0)
            animal.addChildNode(bodyNode)

            let head = SCNBox(width: 0.34, height: 0.34, length: 0.34, chamferRadius: 0)
            head.firstMaterial?.diffuse.contents = body.firstMaterial?.diffuse.contents
            let headNode = SCNNode(geometry: head)
            headNode.position = SCNVector3(0.55, -0.33, 0)
            animal.addChildNode(headNode)

            animal.position = SCNVector3(x, 0.0, z)
            animal.eulerAngles = SCNVector3(0, Float(Double.random(in: -0.4...0.4)), 0)
            return animal
        }

        private func makeFlowerNode(isSaturated: Bool, x: Float, z: Float, tintIndex: Int) -> SCNNode {
            let flower = SCNNode()
            let colors: [UIColor] = isSaturated
            ? [
                UIColor(red: 0.98, green: 0.35, blue: 0.42, alpha: 1),
                UIColor(red: 0.96, green: 0.88, blue: 0.25, alpha: 1),
                UIColor(red: 0.32, green: 0.75, blue: 0.96, alpha: 1),
                UIColor(red: 0.93, green: 0.45, blue: 0.90, alpha: 1)
            ]
            : [UIColor(white: 0.68, alpha: 1), UIColor(white: 0.6, alpha: 1)]

            let stem = SCNBox(width: 0.05, height: 0.2, length: 0.05, chamferRadius: 0)
            stem.firstMaterial?.diffuse.contents = isSaturated
            ? UIColor(red: 0.27, green: 0.74, blue: 0.29, alpha: 1)
            : UIColor(white: 0.56, alpha: 1)
            let stemNode = SCNNode(geometry: stem)
            stemNode.position = SCNVector3(0, -0.66, 0)
            flower.addChildNode(stemNode)

            let petal = SCNBox(width: 0.16, height: 0.12, length: 0.16, chamferRadius: 0)
            petal.firstMaterial?.diffuse.contents = colors[tintIndex % colors.count]
            let petalNode = SCNNode(geometry: petal)
            petalNode.position = SCNVector3(0, -0.52, 0)
            flower.addChildNode(petalNode)

            flower.position = SCNVector3(x, 0, z)
            return flower
        }

        private func makeBushNode(isSaturated: Bool, x: Float, z: Float) -> SCNNode {
            let bush = SCNNode()
            let shades: [UIColor] = isSaturated
            ? [
                UIColor(red: 0.17, green: 0.62, blue: 0.22, alpha: 1),
                UIColor(red: 0.22, green: 0.70, blue: 0.28, alpha: 1),
                UIColor(red: 0.14, green: 0.54, blue: 0.18, alpha: 1)
            ]
            : [UIColor(white: 0.50, alpha: 1), UIColor(white: 0.58, alpha: 1)]

            for i in 0..<3 {
                let leaf = SCNBox(width: 0.52, height: 0.36, length: 0.52, chamferRadius: 0)
                leaf.firstMaterial?.diffuse.contents = shades[i % shades.count]
                let leafNode = SCNNode(geometry: leaf)
                leafNode.position = SCNVector3(Float(-0.28 + (Double(i) * 0.28)), -0.62 + Float(Double.random(in: -0.05...0.06)), Float(Double.random(in: -0.08...0.08)))
                bush.addChildNode(leafNode)
            }
            bush.position = SCNVector3(x, 0, z)
            return bush
        }

        private func makeVineNode(isSaturated: Bool, x: Float, z: Float, index: Int) -> SCNNode {
            let vine = SCNNode()
            let vineColor = isSaturated
            ? UIColor(red: 0.16, green: 0.60, blue: 0.20, alpha: 1)
            : UIColor(white: 0.52, alpha: 1)

            for i in 0..<4 {
                let segment = SCNBox(width: 0.12, height: 0.18, length: 0.12, chamferRadius: 0)
                segment.firstMaterial?.diffuse.contents = vineColor
                let segmentNode = SCNNode(geometry: segment)
                segmentNode.position = SCNVector3(Float((Double(i % 2) - 0.5) * 0.10), -0.82 + Float(Double(i) * 0.16), 0)
                vine.addChildNode(segmentNode)
            }

            let leaf = SCNBox(width: 0.24, height: 0.16, length: 0.06, chamferRadius: 0)
            leaf.firstMaterial?.diffuse.contents = isSaturated
            ? UIColor(red: 0.24, green: 0.74, blue: 0.30, alpha: 1)
            : UIColor(white: 0.60, alpha: 1)
            let leafNode = SCNNode(geometry: leaf)
            leafNode.position = SCNVector3(index.isMultiple(of: 2) ? 0.14 : -0.14, -0.36, 0)
            vine.addChildNode(leafNode)

            vine.position = SCNVector3(x, 0, z)
            return vine
        }

        private func noise(cx: Int, cz: Int, n: Int) -> Double {
            let v = sin(Double(cx * 73856093 ^ cz * 19349663 ^ n * 83492791)) * 43758.5453
            return v - floor(v)
        }
    }
}

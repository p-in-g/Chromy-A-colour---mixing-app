import SwiftUI
import SwiftData
import UIKit

final class OrientationAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .landscape
    }
}

@main
@available(iOS 17.0, *)
struct MyApp: App {
    @UIApplicationDelegateAdaptor(OrientationAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    forceLandscapeIfNeeded()
                }
        }
        .modelContainer(for: [SpellBookRecord.self])
    }

    private func forceLandscapeIfNeeded() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        guard scene.interfaceOrientation.isPortrait else { return }
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

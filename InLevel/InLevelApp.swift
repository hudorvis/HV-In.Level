import SwiftUI
import UIKit

@main
struct InLevelApp: App {
    @Environment(\.scenePhase) private var phase
    @StateObject private var motion = MotionLevelManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(motion)
                .preferredColorScheme(.dark)
                .onChange(of: phase, initial: true) { _, phase in
                    UIApplication.shared.isIdleTimerDisabled = phase == .active
                    if phase == .active { motion.start() } else { motion.stop() }
                }
                .onDisappear {
                    UIApplication.shared.isIdleTimerDisabled = false
                    motion.stop()
                }
        }
    }
}

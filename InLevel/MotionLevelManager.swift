import Foundation
import CoreMotion
import Combine
import UIKit

@MainActor
final class MotionLevelManager: ObservableObject {
    @Published private(set) var sample: Measurement?
    private let manager = CMMotionManager()
    private var filter = MotionFilter()
    private var generation = 0
    private let settings = LevelSettings()
    weak var scene: UIWindowScene?

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1 / 60
        let session = generation
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            MainActor.assumeIsolated {
                guard let self, session == self.generation else { return }
                guard let motion else { self.sample = nil; return }
                let g = motion.gravity
                self.sample = self.filter.update(Gravity(x: g.x, y: g.y, z: g.z), at: motion.timestamp)
            }
        }
    }

    func stop() {
        generation += 1
        manager.stopDeviceMotionUpdates()
        filter = MotionFilter()
        sample = nil
    }

    func capture(_ mode: MainMode) {
        guard let sample else { return }
        objectWillChange.send()
        settings.save(sample, mode: mode)
    }

    func reading(for mode: MainMode) -> LevelReading {
        guard let sample else { return .waiting }
        let screen: ScreenOrientation
        switch scene?.effectiveGeometry.interfaceOrientation {
        case .landscapeLeft: screen = .landscapeLeft
        case .landscapeRight: screen = .landscapeRight
        case .portraitUpsideDown: screen = .upsideDown
        default: screen = .portrait
        }
        if mode == .level { return LevelMath.level(sample, zero: settings.zeros[sample.pose], screen: screen) }
        return LevelMath.match(sample, reference: settings.reference ?? settings.legacy[sample.pose], screen: screen)
    }
}

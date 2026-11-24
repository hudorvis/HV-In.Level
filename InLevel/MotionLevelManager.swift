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

#if targetEnvironment(simulator) && DEBUG
    static let screenshotMode: MainMode? = {
        guard let value = ProcessInfo.processInfo.environment["INLEVEL_SCREENSHOT_MODE"] else { return nil }
        return MainMode(rawValue: value)
    }()

    private static func screenshotSample(_ degrees: Double) -> Measurement {
        let angle = LevelMath.degreesToRadians(degrees)
        return Measurement(pose: .faceUp, gravity: Gravity(x: -sin(angle), y: 0, z: -cos(angle)))
    }
#endif

    func start() {
#if targetEnvironment(simulator) && DEBUG
        if Self.screenshotMode != nil {
            sample = Self.screenshotSample(2.65)
            return
        }
#endif
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

    func reset(_ mode: MainMode) {
        objectWillChange.send()
        if mode == .level { settings.resetCalibration() }
        else { settings.resetReference() }
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
#if targetEnvironment(simulator) && DEBUG
        if Self.screenshotMode != nil {
            return LevelMath.match(sample, reference: Self.screenshotSample(1.85), screen: screen)
        }
#endif
        return LevelMath.match(sample, reference: settings.reference ?? settings.legacy[sample.pose], screen: screen)
    }
}

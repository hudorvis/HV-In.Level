import Foundation

@main
enum LevelChecks {
    static func edge(_ degrees: Double, _ pose: ContactPose = .bottom) -> Measurement {
        let r = LevelMath.degreesToRadians(degrees)
        let vector = pose.downAxis.scaled(cos(r)) - pose.rightAxis.scaled(sin(r))
        let g = Gravity(x: vector.x, y: vector.y, z: 0)
        return Measurement(pose: LevelMath.contact(for: g, previous: nil), gravity: g)
    }
    static func flat(_ degrees: Double, azimuth: Double) -> Measurement {
        let a = LevelMath.degreesToRadians(degrees), b = LevelMath.degreesToRadians(azimuth)
        return Measurement(pose: .faceUp, gravity: Gravity(x: -sin(a)*sin(b), y: -sin(a)*cos(b), z: -cos(a)))
    }
    static func close(_ actual: Double?, _ expected: Double, line: UInt = #line) {
        precondition(abs((actual ?? .infinity) - expected) < 1e-8, "Unexpected value at line " + String(line))
    }
    static func main() {
        let name = "inlevel.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(-2.0, forKey: "portraitEdgeCalibration")
        defaults.set(-3.347, forKey: "matchPortraitEdge")
        defaults.set(true, forKey: "matchPortraitEdgeSaved")
        let store = LevelSettings(defaults: defaults)
        let a = edge(5.347), b = edge(5.475)
        close(LevelMath.absoluteAngle(store.legacy[.bottom]!), 5.347)
        close(LevelMath.level(a, zero: store.zeros[.bottom], screen: .portrait).valueDegrees, 3.347)
        store.save(a, mode: .match)
        store.save(b, mode: .level)
        let loaded = LevelSettings(defaults: defaults)
        for screen in ScreenOrientation.allCases {
            let result = LevelMath.match(b, reference: loaded.reference, screen: screen)
            close(result.valueDegrees, 0.128)
            precondition(result.target != result.live && result.status == "Match Error")
            close(LevelMath.match(a, reference: b, screen: screen).valueDegrees, -0.128)
            let exact = LevelMath.match(a, reference: loaded.reference, screen: screen)
            precondition(exact.status == "Matched" && exact.target == exact.live)
            close(LevelMath.level(b, zero: loaded.zeros[b.pose], screen: screen).valueDegrees, 0)
        }
        let f = flat(34, azimuth: 90), shifted = flat(34.128, azimuth: 90)
        close(LevelMath.match(shifted, reference: f, screen: .portrait).valueDegrees, 0.128)
        close(LevelMath.level(shifted, zero: f.gravity, screen: .portrait).valueDegrees, 0.128)
        precondition(LevelMath.match(flat(34, azimuth: 0), reference: f, screen: .portrait).valueDegrees! > 40)
        precondition(LevelMath.match(f, reference: a, screen: .portrait).valueDegrees == nil)
        precondition(LevelMath.match(a, reference: nil, screen: .portrait).target == nil)
        close(LevelMath.match(edge(94), reference: a, screen: .portrait).valueDegrees, 94-5.347)
        close(LevelMath.shortestAngle(359.5), -0.5)
        close(LevelMath.slopePercent(degrees: -45), -100)
        precondition(LevelMath.slopePercent(degrees: 90) == nil)
        precondition(LevelMath.degreesText(-0.00001) == "0.000°")
        precondition(LevelMath.degreesText(0.128) == "+0.128°")
        for pose in ContactPose.allCases {
            let sample = pose.isFlat ? Measurement(pose: pose, gravity: Gravity(x: 0, y: 0, z: pose == .faceUp ? -1 : 1)) : edge(3, pose)
            var filter = MotionFilter()
            precondition(filter.update(sample.gravity, at: 10)?.pose == pose)
            precondition(filter.update(sample.gravity, at: 9) == nil)
            store.save(sample, mode: .level)
            let persisted = LevelSettings(defaults: defaults)
            close(LevelMath.level(sample, zero: persisted.zeros[pose], screen: .portrait).valueDegrees, 0)
        }
        store.save(f, mode: .match)
        precondition(LevelSettings(defaults: defaults).reference?.pose == .faceUp)

        store.resetCalibration()
        precondition(store.zeros.isEmpty)
        let reset = LevelSettings(defaults: defaults)
        precondition(reset.zeros.isEmpty && reset.reference == store.reference && reset.legacy == store.legacy)
        close(LevelMath.level(b, zero: reset.zeros[b.pose], screen: .portrait).valueDegrees, 5.475)
        reset.save(b, mode: .level)
        let recalibrated = LevelSettings(defaults: defaults)
        precondition(recalibrated.zeros.count == 1)
        close(LevelMath.level(b, zero: recalibrated.zeros[b.pose], screen: .portrait).valueDegrees, 0)
        precondition(LevelMath.match(f, reference: a, screen: .portrait).status.isEmpty)

        recalibrated.resetReference()
        let clearedReference = LevelSettings(defaults: defaults)
        precondition(recalibrated.reference == nil && recalibrated.legacy.isEmpty)
        precondition(clearedReference.reference == nil && clearedReference.legacy.isEmpty)
        precondition(clearedReference.zeros == recalibrated.zeros)

        print("Level and Match regression checks passed.")
    }
}

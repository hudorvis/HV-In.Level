import Foundation

enum LevelMath {
    static let tolerance = 0.05

    static func radiansToDegrees(_ value: Double) -> Double { value * 180 / .pi }
    static func degreesToRadians(_ value: Double) -> Double { value * .pi / 180 }

    static func shortestAngle(_ value: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: 360)
        if wrapped > 180 { return wrapped - 360 }
        if wrapped < -180 { return wrapped + 360 }
        return wrapped
    }

    static func slopePercent(degrees: Double) -> Double? {
        let r = degreesToRadians(degrees)
        guard abs(cos(r)) > 1e-10 else { return nil }
        return tan(r) * 100
    }

    static func degreesText(_ angle: Double) -> String {
        guard abs(angle) >= 0.0005 else { return "0.000°" }
        return String(format: "%+.3f°", locale: Locale(identifier: "en_US_POSIX"), angle)
    }

    static func slopeText(_ angle: Double) -> String {
        guard let slope = slopePercent(degrees: angle) else { return "Vertical" }
        guard abs(slope) >= 0.005 else { return "0.00%" }
        return String(format: "%+.2f%%", locale: Locale(identifier: "en_US_POSIX"), slope)
    }

    static func contact(for g: Gravity, previous: ContactPose?) -> ContactPose {
        let flatThreshold: Double
        switch previous {
        case nil: flatThreshold = 0.72
        case .faceUp, .faceDown: flatThreshold = 0.67
        default: flatThreshold = 0.77
        }
        if abs(g.z) >= flatThreshold { return g.z <= 0 ? .faceUp : .faceDown }

        let x = abs(g.x), y = abs(g.y)
        let useX: Bool
        switch previous {
        case .left, .right: useX = x + 0.10 >= y
        case .bottom, .top: useX = x > y + 0.10
        default: useX = x > y
        }
        if useX { return g.x < 0 ? .left : .right }
        return g.y < 0 ? .bottom : .top
    }

    // A face-up or face-down level reports the high side, opposite projected gravity.
    private static func highNormal(_ g: Gravity) -> Gravity { Gravity(x: -g.x, y: -g.y, z: abs(g.z)) }

    // Shortest rotation taking the stored normal to vertical, applied to the live normal.
    // Unlike subtracting two X/Y gravity readings this retains angular accuracy on steep slopes.
    private static func relativeNormal(_ live: Gravity, from zero: Gravity) -> Gravity {
        let axis = Gravity(x: zero.y, y: -zero.x, z: 0)
        let first = axis.cross(live)
        let second = axis.cross(first)
        let k = 1 / (1 + zero.z)
        return Gravity(x: live.x + first.x + k * second.x,
                       y: live.y + first.y + k * second.y,
                       z: live.z + first.z + k * second.z)
    }

    private static func flatPoint(_ normal: Gravity) -> LevelVector {
        let plane = LevelVector(x: normal.x, y: normal.y)
        guard plane.length > 1e-14 else { return .zero }
        let angle = radiansToDegrees(atan2(plane.length, normal.z))
        return plane.scaled(angle / plane.length)
    }

    private static func separation(_ a: Gravity, _ b: Gravity) -> Double {
        let cross = a.cross(b)
        return radiansToDegrees(atan2(hypot(hypot(cross.x, cross.y), cross.z), a.dot(b)))
    }

    static func edgeAngle(_ g: Gravity, on pose: ContactPose) -> Double {
        let right = pose.rightAxis, down = pose.downAxis
        return radiansToDegrees(atan2(-(g.x * right.x + g.y * right.y), g.x * down.x + g.y * down.y))
    }

    static func absoluteAngle(_ sample: Measurement) -> Double {
        sample.pose.isFlat ? flatPoint(highNormal(sample.gravity)).length : edgeAngle(sample.gravity, on: sample.pose)
    }

    private static func highSide(_ point: LevelVector) -> String {
        if abs(point.x) > abs(point.y) { return point.x > 0 ? "Right Side High" : "Left Side High" }
        return point.y > 0 ? "Top Edge High" : "Bottom Edge High"
    }

    static func level(_ sample: Measurement, zero: Gravity?, screen: ScreenOrientation) -> LevelReading {
        let axis = screen.project(sample.pose.rightAxis)
        let angle: Double
        let point: LevelVector
        if sample.pose.isFlat {
            let live = highNormal(sample.gravity)
            let relative = zero.map { relativeNormal(live, from: highNormal($0)) } ?? live
            point = screen.project(flatPoint(relative))
            angle = point.length
        } else {
            let offset = zero.map { edgeAngle($0, on: sample.pose) } ?? 0
            angle = shortestAngle(edgeAngle(sample.gravity, on: sample.pose) - offset)
            point = axis.scaled(angle)
        }
        let nearZero = abs(angle) < tolerance
        return LevelReading(pose: sample.pose, valueDegrees: angle, currentDegrees: angle, referenceDegrees: nil,
                            live: point, target: nil, direction: nearZero ? nil : point, railAxis: axis,
                            status: nearZero ? "Level" : highSide(point))
    }

    static func match(_ sample: Measurement, reference: Measurement?, screen: ScreenOrientation) -> LevelReading {
        let compatible = reference.map { saved in
            saved.pose == sample.pose || (!saved.pose.isFlat && !sample.pose.isFlat)
        } ?? false
        // Keep measuring about the captured edge as the handset turns through adjacent edges.
        let basis = compatible ? (reference?.pose ?? sample.pose) : sample.pose
        let axis = screen.project(basis.rightAxis)
        let live: LevelVector
        let current: Double
        if sample.pose.isFlat {
            live = screen.project(flatPoint(highNormal(sample.gravity)))
            current = live.length
        } else {
            current = edgeAngle(sample.gravity, on: basis)
            live = axis.scaled(current)
        }

        let ref = reference.map(absoluteAngle)
        guard let reference, let ref, compatible else {
            return LevelReading(pose: sample.pose, valueDegrees: nil, currentDegrees: current, referenceDegrees: ref,
                                live: live, target: nil, direction: nil, railAxis: axis,
                                status: reference?.pose.placementPrompt ?? "Set Reference")
        }

        let error: Double
        let target: LevelVector
        let plottedLive: LevelVector
        if basis.isFlat {
            let normal = highNormal(reference.gravity)
            error = separation(normal, highNormal(sample.gravity))
            target = screen.project(flatPoint(normal))
            plottedLive = live
        } else {
            error = shortestAngle(current - ref)
            target = axis.scaled(ref)
            plottedLive = axis.scaled(ref + error)
        }
        let matched = abs(error) < tolerance
        return LevelReading(pose: sample.pose, valueDegrees: error, currentDegrees: current, referenceDegrees: ref,
                            live: plottedLive, target: target, direction: matched ? nil : plottedLive - target,
                            railAxis: axis, status: matched ? "Matched" : "Match Error")
    }

    // Both markers use the same continuous scale. The second term gives fine control around
    // the saved angle without pinning distinct off-scale angles to the same point on the rim.
    static func instrumentPoint(_ point: LevelVector, reference: LevelVector?) -> LevelVector {
        func project(_ p: LevelVector, span: Double) -> LevelVector { p.scaled(1 / (p.length + span)) }
        guard let reference else { return project(point, span: 6) }
        return project(point, span: 6).scaled(0.52) + project(point - reference, span: 1.5).scaled(0.48)
    }
}

struct MotionFilter {
    private var filtered: Gravity?
    private var pose: ContactPose?
    private var lastTime: TimeInterval?

    mutating func update(_ input: Gravity, at time: TimeInterval) -> Measurement? {
        guard let g = input.unit, time.isFinite else { return nil }
        if let lastTime, time <= lastTime { return nil }
        let elapsed = lastTime.map { time - $0 } ?? 1
        // Equivalent to the original 0.18 smoothing at 60 Hz. Seed from the first real sample.
        let next: Gravity
        if elapsed < 0.35, let filtered {
            let weight = 1 - exp(-elapsed / 0.084)
            next = Gravity(x: filtered.x + weight * (g.x - filtered.x),
                           y: filtered.y + weight * (g.y - filtered.y),
                           z: filtered.z + weight * (g.z - filtered.z))
        } else {
            next = g
            pose = nil
        }
        guard let unit = next.unit else { return nil }
        let contact = LevelMath.contact(for: unit, previous: pose)
        lastTime = time
        filtered = next
        pose = contact
        return Measurement(pose: contact, gravity: unit)
    }
}

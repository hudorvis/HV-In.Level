import Foundation

enum MainMode: String, CaseIterable, Identifiable {
    case level = "Level"
    case match = "Match"
    var id: Self { self }
}

enum SecondaryMode: String, CaseIterable, Identifiable {
    case degrees = "Degrees"
    case slope = "Slope"
    case colours = "Colours"
    var id: Self { self }
}

enum PaletteChoice: String, CaseIterable, Identifiable {
    case yellowGreen = "Yellow/Green"
    case orangeBlue = "Orange/Blue"
    case magentaCyan = "Magenta/Cyan"
    var id: Self { self }
}

struct LevelVector: Equatable {
    var x: Double
    var y: Double

    static let zero = Self(x: 0, y: 0)
    static let horizontal = Self(x: 1, y: 0)
    var length: Double { hypot(x, y) }
    func scaled(_ scale: Double) -> Self { Self(x: x * scale, y: y * scale) }

    static func + (lhs: Self, rhs: Self) -> Self { Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    static func - (lhs: Self, rhs: Self) -> Self { Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
}

// Core Motion reports gravity in fixed device coordinates, with +Y towards the top of the handset.
struct Gravity: Codable, Equatable {
    var x: Double
    var y: Double
    var z: Double

    var unit: Self? {
        let length = hypot(hypot(x, y), z)
        guard length.isFinite, length > 1e-8 else { return nil }
        return Self(x: x / length, y: y / length, z: z / length)
    }

    func dot(_ b: Self) -> Double { x * b.x + y * b.y + z * b.z }

    func cross(_ b: Self) -> Self {
        Self(x: y * b.z - z * b.y, y: z * b.x - x * b.z, z: x * b.y - y * b.x)
    }
}

enum ContactPose: String, CaseIterable, Codable {
    case faceUp, faceDown, bottom, top, left, right

    var isFlat: Bool { self == .faceUp || self == .faceDown }

    // The contact normal and reading axis lie in the screen plane for an edge.
    var downAxis: LevelVector {
        switch self {
        case .bottom: return LevelVector(x: 0, y: -1)
        case .top:    return LevelVector(x: 0, y: 1)
        case .left:   return LevelVector(x: -1, y: 0)
        case .right:  return LevelVector(x: 1, y: 0)
        case .faceUp, .faceDown: return .zero
        }
    }

    var rightAxis: LevelVector { LevelVector(x: -downAxis.y, y: downAxis.x) }

    var placementPrompt: String {
        switch self {
        case .faceUp: return "Place Face Up"
        case .faceDown: return "Place Face Down"
        default: return ""
        }
    }
}

enum ScreenOrientation: CaseIterable {
    case portrait, upsideDown, landscapeLeft, landscapeRight

    // The UIKit landscape name denotes the side with the Home button.
    // All vectors here use screen +Y up. Only the drawing layer inverts Y.
    func project(_ point: LevelVector) -> LevelVector {
        switch self {
        case .portrait: return point
        case .upsideDown: return point.scaled(-1)
        case .landscapeLeft: return LevelVector(x: point.y, y: -point.x)
        case .landscapeRight: return LevelVector(x: -point.y, y: point.x)
        }
    }
}

struct Measurement: Codable, Equatable {
    let pose: ContactPose
    let gravity: Gravity
}

struct LevelReading: Equatable {
    let pose: ContactPose?
    let valueDegrees: Double?
    let currentDegrees: Double?
    let referenceDegrees: Double?
    // Absolute positions in an angular chart, already mapped to screen axes.
    let live: LevelVector?
    let target: LevelVector?
    let direction: LevelVector?
    let railAxis: LevelVector
    let status: String

    static let waiting = Self(pose: nil, valueDegrees: nil, currentDegrees: nil, referenceDegrees: nil,
                              live: nil, target: nil, direction: nil, railAxis: .horizontal, status: "Waiting For Motion")
}

final class LevelSettings {
    private let defaults: UserDefaults
    private(set) var zeros: [ContactPose: Gravity] = [:]
    private(set) var legacy: [ContactPose: Measurement] = [:]
    private(set) var reference: Measurement?
    private let matchKey = "inlevel.match.capture.v2"
    private let zeroKeyPrefix = "inlevel.zero."
    private let zeroResetKey = "inlevel.zero.didReset"
    private let legacyMatchGroups = ["Flat", "PortraitEdge", "LandscapeEdge"]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func restored(_ key: String) -> Measurement? {
            guard let data = defaults.data(forKey: key),
                  let m = try? JSONDecoder().decode(Measurement.self, from: data),
                  let g = m.gravity.unit else { return nil }
            return Measurement(pose: m.pose, gravity: g)
        }
        reference = restored(matchKey)
        let includeLegacyCalibration = !defaults.bool(forKey: zeroResetKey)
        for pose in ContactPose.allCases {
            let group = pose.isFlat ? "Flat" : (pose == .bottom || pose == .top ? "PortraitEdge" : "LandscapeEdge")
            func oldGravity(match: Bool) -> Gravity {
                if pose.isFlat {
                    let sign = pose == .faceUp ? 1.0 : -1.0
                    let x = sign * (defaults.double(forKey: "flatCalibrationX") + (match ? defaults.double(forKey: "matchFlatX") : 0))
                    let y = -sign * (defaults.double(forKey: "flatCalibrationY") + (match ? defaults.double(forKey: "matchFlatY") : 0))
                    return Gravity(x: x, y: y, z: -sign * sqrt(max(0, 1-x*x-y*y)))
                }
                let key = group == "PortraitEdge" ? "portraitEdgeCalibration" : "landscapeEdgeCalibration"
                let r = LevelMath.degreesToRadians(defaults.double(forKey: key) + (match ? defaults.double(forKey: "match" + group) : 0))
                let p = pose.downAxis.scaled(cos(r)) + pose.rightAxis.scaled(sin(r))
                return Gravity(x: p.x, y: p.y, z: 0)
            }
            zeros[pose] = restored(zeroKeyPrefix + pose.rawValue)?.gravity
                ?? (includeLegacyCalibration ? oldGravity(match: false).unit : nil)
            if defaults.bool(forKey: "match" + group + "Saved"), let g = oldGravity(match: true).unit {
                legacy[pose] = Measurement(pose: pose, gravity: g)
            }
        }
    }

    func save(_ sample: Measurement, mode: MainMode) {
        guard let data = try? JSONEncoder().encode(sample) else { return }
        if mode == .match {
            defaults.set(data, forKey: matchKey)
            reference = sample
        } else {
            defaults.set(data, forKey: zeroKeyPrefix + sample.pose.rawValue)
            zeros[sample.pose] = sample.gravity
        }
    }

    func resetCalibration() {
        // Legacy Match captures still read the original offsets to recover their reference angles.
        defaults.set(true, forKey: zeroResetKey)
        for pose in ContactPose.allCases {
            defaults.removeObject(forKey: zeroKeyPrefix + pose.rawValue)
        }
        zeros.removeAll()
    }

    func resetReference() {
        defaults.removeObject(forKey: matchKey)
        for group in legacyMatchGroups {
            defaults.removeObject(forKey: "match" + group + "Saved")
        }
        reference = nil
        legacy.removeAll()
    }
}

import SwiftUI

extension PaletteChoice {
    var left: Color {
        switch self {
        case .yellowGreen: return Color(red: 0.95, green: 0.76, blue: 0.02)
        case .orangeBlue: return Color(red: 1, green: 0.47, blue: 0.05)
        case .magentaCyan: return Color(red: 0.95, green: 0.20, blue: 0.72)
        }
    }
    var right: Color {
        switch self {
        case .yellowGreen: return Color(red: 0.15, green: 0.78, blue: 0.32)
        case .orangeBlue: return Color(red: 0.12, green: 0.55, blue: 1)
        case .magentaCyan: return Color(red: 0.05, green: 0.84, blue: 0.92)
        }
    }
}

enum InTheme {
    static let background = LinearGradient(colors: [Color(red: 0.055, green: 0.062, blue: 0.060), .black], startPoint: .top, endPoint: .bottom)
}

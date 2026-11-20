import SwiftUI

struct BrandLogo: View {
    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: -1) {
                Text("In").font(.system(size: 35, weight: .semibold, design: .rounded)).tracking(-0.8)
                Text(".").font(.system(size: 35, weight: .heavy, design: .rounded))
                    .foregroundStyle(PaletteChoice.yellowGreen.left).shadow(color: PaletteChoice.yellowGreen.left.opacity(0.72), radius: 5)
                Text("Level").font(.system(size: 35, weight: .light, design: .rounded)).tracking(-0.9)
            }.foregroundStyle(.white)
            Capsule().fill(LinearGradient(colors: [PaletteChoice.yellowGreen.left, PaletteChoice.yellowGreen.right], startPoint: .leading, endPoint: .trailing))
                .frame(width: 56, height: 2).opacity(0.88).shadow(color: PaletteChoice.yellowGreen.right.opacity(0.30), radius: 3)
        }.padding(.top, 7).padding(.bottom, 11).accessibilityElement(children: .ignore).accessibilityLabel("In.Level")
    }
}

struct SegmentedPill<Option: Identifiable & Equatable>: View {
    let options: [Option]
    @Binding var selection: Option
    var primary = false
    var swatches: ((Option) -> (Color, Color))? = nil
    let title: (Option) -> String
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { item in
                Button { selection = item } label: {
                    HStack(spacing: swatches == nil ? 0 : 4) {
                        if let pair = swatches?(item) {
                            Circle().fill(pair.0).frame(width: 6, height: 6)
                            Circle().fill(pair.1).frame(width: 6, height: 6)
                        }
                        Text(title(item))
                    }.font(.system(size: primary ? 15 : (swatches == nil ? 12 : 11), weight: selection == item ? .semibold : .regular))
                        .foregroundStyle(selection == item ? .white : .white.opacity(primary ? 0.62 : 0.60))
                        .lineLimit(1).minimumScaleFactor(0.72).frame(maxWidth: .infinity).frame(height: primary ? 38 : (swatches == nil ? 35 : 34))
                        .background { if selection == item { Capsule().fill(.white.opacity(0.14)) } }
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }.padding(3).background(Capsule().fill(.white.opacity(primary ? 0.05 : 0.045)))
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

struct BottomJoinedControl: View {
    let mode: MainMode
    let compact: Bool
    let expanded: Bool
    let available: Bool
    let palette: PaletteChoice
    let capture: () -> Void
    let fullScreen: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            action(mode == .level ? "Calibrate" : "Set Reference", "scope", palette.left, capture)
                .disabled(!available).opacity(available ? 1 : 0.45)
            Rectangle().fill(.white.opacity(0.14)).frame(width: 1, height: compact ? 26 : 34)
            action("Full Screen", "arrow.up.left.and.arrow.down.right", .white, fullScreen)
        }.font(.system(size: compact ? 13 : (expanded ? 17 : 15), weight: .medium))
            .foregroundStyle(.white.opacity(0.88)).frame(height: compact ? 48 : (expanded ? 72 : 65))
            .padding(.horizontal, compact ? 8 : 10).background(Capsule().fill(.white.opacity(0.055)))
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func action(_ text: String, _ symbol: String, _ tint: Color, _ perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: compact ? 7 : 9) {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(text).lineLimit(1).minimumScaleFactor(0.7)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

struct ReadingTextBlock: View {
    let reading: LevelReading
    let mode: MainMode
    let slope: Bool
    let palette: PaletteChoice
    let size: CGFloat
    let full: Bool

    var body: some View {
        // Reserve room for the tallest readout so text changes cannot move the circle.
        content(reservingSpace: true)
            .hidden()
            .accessibilityHidden(true)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) {
                content(reservingSpace: false)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
            }
    }

    private func content(reservingSpace: Bool) -> some View {
        let valueDegrees = reservingSpace ? nil : reading.valueDegrees
        let degrees = valueDegrees.map(LevelMath.degreesText)
        let value = slope ? valueDegrees.map(LevelMath.slopeText) : degrees
        let showStatus = mode == .match || reading.direction == nil
        let reference = mode == .match && !reservingSpace ? reading.referenceDegrees : nil
        let current = mode == .match && !reservingSpace && !full ? reading.currentDegrees : nil

        return VStack(spacing: 3) {
            Text(reservingSpace ? "0.000°" : (value ?? "—"))
                .font(.system(size: size, weight: .light, design: .rounded)).foregroundStyle(palette.right)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.45)
            if let secondary = reservingSpace ? "0.000°" : (slope ? degrees : nil) {
                Text(secondary).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            }
            if reservingSpace || showStatus {
                Text(reservingSpace ? "MATCH ERROR" : reading.status.uppercased())
                    .font(.system(size: min(18, size * 0.32), weight: .semibold))
                    .tracking(0.8).foregroundStyle(reading.valueDegrees == nil ? Color.secondary : palette.right)
            }
            if reservingSpace || reference != nil || current != nil {
                HStack(spacing: 12) {
                    if let ref = reservingSpace ? "0.000°" : reference.map(LevelMath.degreesText) {
                        Text("REF " + ref)
                    }
                    if !full, let live = reservingSpace ? "0.000°" : current.map(LevelMath.degreesText) {
                        Text("LIVE " + live)
                    }
                }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }.lineLimit(1).minimumScaleFactor(0.7)
    }
}

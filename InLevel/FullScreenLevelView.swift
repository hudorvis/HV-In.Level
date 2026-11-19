import SwiftUI

struct InstrumentStage: View {
    let reading: LevelReading
    let mode: MainMode
    let slope: Bool
    let palette: PaletteChoice
    var full = false
    var wide = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let horizontal = full && wide
            let layout = horizontal ? AnyLayout(HStackLayout(spacing: 10)) : AnyLayout(VStackLayout(spacing: 4))
            let font: CGFloat = full ? (min(size.width, size.height) >= 600 ? 82 : 58) : (size.height < 470 ? 38 : 52)
            layout {
                if horizontal { readout(font).frame(width: size.width * 0.38) }
                GeometryReader { box in
                    let side = min(box.size.width, box.size.height, full ? 1000 : 760)
                    LevelInstrumentView(reading: reading, palette: palette)
                        .frame(width: side, height: side)
                        .position(x: box.size.width / 2, y: horizontal ? box.size.height / 2 : box.size.height - side / 2)
                }
                if !horizontal { readout(font).fixedSize(horizontal: false, vertical: true) }
            }
            .frame(maxWidth: .infinity, maxHeight: horizontal ? .infinity : min(size.height, size.width + font * 2.8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func readout(_ font: CGFloat) -> some View {
        ReadingTextBlock(reading: reading, mode: mode, slope: slope, palette: palette, size: font, full: full)
    }
}

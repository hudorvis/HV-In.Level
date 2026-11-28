import SwiftUI

struct InstrumentStage: View {
    let reading: LevelReading
    let mode: MainMode
    let slope: Bool
    let palette: PaletteChoice
    let full: Bool
    let wide: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let font: CGFloat = size.height < 470 ? 38 : 52
            VStack(spacing: wide ? 0 : 4) {
                GeometryReader { box in
                    let side = min(box.size.width, box.size.height, 760)
                    LevelInstrumentView(reading: reading, palette: palette)
                        .frame(width: side, height: side)
                        .position(x: box.size.width / 2, y: box.size.height - side / 2)
                }

                ReadingTextBlock(reading: reading, mode: mode, slope: slope, palette: palette,
                                 size: font, full: full, compact: wide && size.height < 470)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: wide ? .infinity : min(size.height, size.width + font * 2.8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

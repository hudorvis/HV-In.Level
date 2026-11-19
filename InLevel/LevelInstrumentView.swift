import SwiftUI

struct LevelInstrumentView: View {
    let reading: LevelReading
    let palette: PaletteChoice
    var showLabels = true

    private let dotCount = 80

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let outerRadius = side * 0.405
            let innerRadius = side * 0.315

            ZStack {
                Canvas { context, _ in
                    drawOuterRing(context: &context, center: center, radius: outerRadius)
                }

                if reading.pose?.isFlat != false {
                    Circle().fill(Color.white.opacity(0.025))
                        .frame(width: innerRadius * 2, height: innerRadius * 2)
                        .overlay(Circle().stroke(.white.opacity(0.40), lineWidth: 1))
                    ScopeReticle(radius: innerRadius).frame(width: innerRadius * 2, height: innerRadius * 2)
                } else {
                    ZStack {
                        Capsule().fill(Color.white.opacity(0.045))
                        Capsule().stroke(.white.opacity(0.4), lineWidth: 1)
                        HStack(spacing: 0) {
                            ForEach(-5...5, id: \.self) { tick in
                                Rectangle().fill(.white.opacity(tick == 0 ? 0.8 : 0.35))
                                    .frame(width: 1, height: innerRadius * (tick == 0 ? 0.26 : 0.12))
                                    .frame(maxWidth: .infinity)
                            }
                        }.padding(.horizontal, innerRadius * 0.08)
                    }.frame(width: innerRadius * 2, height: innerRadius * 0.40)
                        .rotationEffect(.degrees(reading.railAxis.x == 0 ? 90 : 0))
                }
                if let live = reading.live {
                    bubble(innerRadius: innerRadius).offset(offset(live, radius: innerRadius))
                }
                if let target = reading.target {
                    Circle().stroke(palette.left, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .frame(width: max(12, innerRadius * 0.26), height: max(12, innerRadius * 0.26))
                        .offset(offset(target, radius: innerRadius))
                }

                if showLabels {
                    ForEach(Array(stride(from: 0, through: 315, by: 45)), id: \.self) { degrees in
                        label(for: degrees, center: center, radius: outerRadius + side * 0.047)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level instrument")
        .accessibilityValue(reading.status)
    }

    private func drawOuterRing(context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        for index in 0..<dotCount {
            let angle = Double(index) / Double(dotCount) * 2 * Double.pi - Double.pi / 2
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            let degrees = (Double(index) / Double(dotCount) * 360).truncatingRemainder(dividingBy: 360)
            let isCardinal = index % 20 == 0
            let isMajor = index % 5 == 0
            let size = min(1.3, radius / 170) * (isCardinal ? 8 : (isMajor ? 5 : 3.6))
            let color: Color
            if isCardinal {
                color = Color.white.opacity(0.50)
            } else if degrees > 180 {
                color = palette.left
            } else {
                color = palette.right
            }
            context.fill(Path(ellipseIn: CGRect(x: point.x - size/2, y: point.y - size/2, width: size, height: size)), with: .color(color))
        }

        guard let direction = reading.direction else { return }
        let angle = atan2(-direction.y, direction.x)
        let point = CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
        let activeSize = max(5, min(16, radius * 0.085))
        context.addFilter(.shadow(color: palette.right.opacity(0.72), radius: 10))
        context.fill(Path(ellipseIn: CGRect(x: point.x - activeSize/2, y: point.y - activeSize/2, width: activeSize, height: activeSize)), with: .color(.white))
    }

    @ViewBuilder
    private func bubble(innerRadius: CGFloat) -> some View {
        let bubbleSize = max(8, innerRadius * 0.18)
        ZStack {
            Circle()
                .fill(palette.right.opacity(0.18))
                .frame(width: bubbleSize * 1.7, height: bubbleSize * 1.7)
                .blur(radius: bubbleSize * 0.18)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.82), palette.right, palette.right.opacity(0.68)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: bubbleSize
                    )
                )
                .frame(width: bubbleSize, height: bubbleSize)
                .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.3))
                .shadow(color: palette.right.opacity(0.75), radius: 9)
        }
    }

    private func offset(_ input: LevelVector, radius: CGFloat) -> CGSize {
        let point = LevelMath.instrumentPoint(input, reference: reading.target)
        return CGSize(width: radius * 0.83 * CGFloat(point.x), height: -radius * 0.83 * CGFloat(point.y))
    }

    private func label(for degrees: Int, center: CGPoint, radius: CGFloat) -> some View {
        let angle = Double(degrees) * Double.pi / 180 - Double.pi / 2
        let x = center.x + radius * CGFloat(cos(angle))
        let y = center.y + radius * CGFloat(sin(angle))
        return Text("\(degrees)°")
            .font(.system(size: min(15, max(8, radius * 0.075)), weight: .regular, design: .rounded))
            .foregroundStyle(.white.opacity(0.88))
            .position(x: x, y: y)
    }
}

private struct ScopeReticle: View {
    let radius: CGFloat

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2
            var axes = Path()
            axes.move(to: CGPoint(x: center.x - r * 0.90, y: center.y))
            axes.addLine(to: CGPoint(x: center.x + r * 0.90, y: center.y))
            axes.move(to: CGPoint(x: center.x, y: center.y - r * 0.90))
            axes.addLine(to: CGPoint(x: center.x, y: center.y + r * 0.90))
            context.stroke(axes, with: .color(.white.opacity(0.78)), lineWidth: 1)

            var ticks = Path()
            for index in -6...6 where index != 0 {
                let offset = CGFloat(index) / 7 * r * 0.78
                let length: CGFloat = index % 3 == 0 ? 12 : 7
                ticks.move(to: CGPoint(x: center.x + offset, y: center.y - length/2))
                ticks.addLine(to: CGPoint(x: center.x + offset, y: center.y + length/2))
                ticks.move(to: CGPoint(x: center.x - length/2, y: center.y + offset))
                ticks.addLine(to: CGPoint(x: center.x + length/2, y: center.y + offset))
            }
            context.stroke(ticks, with: .color(.white.opacity(0.42)), lineWidth: 1)

            for index in 0..<48 {
                let a = Double(index) / 48 * 2 * Double.pi
                let isMajor = index % 6 == 0
                let outer = r * 0.91
                let inner = outer - (isMajor ? 14 : 7)
                var path = Path()
                path.move(to: CGPoint(x: center.x + inner * CGFloat(cos(a)), y: center.y + inner * CGFloat(sin(a))))
                path.addLine(to: CGPoint(x: center.x + outer * CGFloat(cos(a)), y: center.y + outer * CGFloat(sin(a))))
                context.stroke(path, with: .color(.white.opacity(isMajor ? 0.75 : 0.42)), lineWidth: isMajor ? 1.1 : 0.8)
            }

            context.fill(Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)), with: .color(.white))
            context.stroke(Path(ellipseIn: CGRect(x: center.x - 13, y: center.y - 13, width: 26, height: 26)), with: .color(.white.opacity(0.70)), lineWidth: 1)
        }
    }
}

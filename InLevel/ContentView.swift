import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var motion: MotionLevelManager
    @State private var mode = MainMode.level
    @State private var tab = SecondaryMode.degrees
    @State private var slope = false
    @State private var full = false
    @State private var notice: String?
    @State private var dismissal: Task<Void, Never>?
    @AppStorage("paletteChoice") private var palette = PaletteChoice.yellowGreen

    init() {
#if targetEnvironment(simulator) && DEBUG
        switch MotionLevelManager.screenshotScene {
        case .level, nil:
            break
        case .slope:
            _tab = State(initialValue: .slope)
            _slope = State(initialValue: true)
        case .match:
            _mode = State(initialValue: .match)
        case .colours:
            _tab = State(initialValue: .colours)
        case .fullScreen:
            _full = State(initialValue: true)
        }
#endif
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let wide = size.width > size.height && size.width >= 500 && size.height >= 300
            let expanded = min(size.width, size.height) >= 600
            let reading = motion.reading(for: mode)
            ZStack {
                InTheme.background.ignoresSafeArea()
                if full {
                    InstrumentStage(reading: reading, mode: mode, slope: slope, palette: palette, full: true, wide: wide)
                        .padding(10)
                    Color.clear.ignoresSafeArea().contentShape(Rectangle()).onTapGesture { full = false }
                        .accessibilityLabel("Exit Full Screen").accessibilityAddTraits(.isButton)
                        .accessibilityAction { full = false }
                } else if wide {
                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            header(expanded)
                            Spacer(minLength: 6)
                            bottom(true, expanded).padding(.horizontal, 10).padding(.bottom, 8)
                        }.padding(.top, 4)
                            .frame(width: size.width >= 1000 && size.height >= 650 ? min(max(size.width * 0.28, 330), 420) : min(max(size.width * 0.30, 250), 292))
                        Rectangle().fill(.white.opacity(0.08)).frame(width: 1).padding(.vertical, 18)
                        interactiveInstrument(reading).padding(5)
                    }.padding(.horizontal, 8)
                } else {
                    let minHeight: CGFloat = tab == .colours ? 524 : 475
                    if size.height < minHeight {
                        ScrollView { portrait(reading, expanded).frame(height: minHeight) }
                    } else { portrait(reading, expanded) }
                }
                if !full, let notice {
                    Text(notice).font(.caption.weight(.semibold)).padding(8)
                        .background(.black, in: Capsule()).allowsHitTesting(false)
                        .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, wide ? 58 : 88)
                }
            }
        }
        .background(SceneProbe { motion.scene = $0 })
        .statusBarHidden(full).persistentSystemOverlays(full ? .hidden : .automatic)
        .onChange(of: tab) { _, next in if next != .colours { slope = next == .slope } }
        .onChange(of: mode) { _, _ in notice = nil }
    }

    private func portrait(_ reading: LevelReading, _ expanded: Bool) -> some View {
        VStack(spacing: 0) {
            header(expanded)
            interactiveInstrument(reading).padding(8)
            bottom(false, expanded).frame(maxWidth: expanded ? 720 : 620).padding(.horizontal, 24).padding(.bottom, 22)
        }
    }

    private func interactiveInstrument(_ reading: LevelReading) -> some View {
        InstrumentStage(reading: reading, mode: mode, slope: slope, palette: palette)
            .contentShape(Rectangle())
            .onTapGesture(perform: enterFullScreen)
            .accessibilityAction(named: Text("Full Screen"), enterFullScreen)
    }

    private func enterFullScreen() {
        notice = nil
        full = true
    }

    private func header(_ expanded: Bool) -> some View {
        VStack(spacing: 0) {
            BrandLogo()
            SegmentedPill(options: MainMode.allCases, selection: $mode, primary: true) { $0.rawValue }
                .frame(maxWidth: expanded ? 620 : .infinity).padding(.horizontal, 24)
            SegmentedPill(options: SecondaryMode.allCases, selection: $tab) { $0.rawValue }
                .padding(.horizontal, 18).frame(maxWidth: expanded ? 600 : 370).padding(.top, 14)
            if tab == .colours {
                SegmentedPill(options: PaletteChoice.allCases, selection: $palette, swatches: { ($0.left, $0.right) }) { $0.rawValue }
                    .padding(.horizontal, 12).frame(maxWidth: 620).padding(.top, 9)
            }
        }
    }

    private func bottom(_ compact: Bool, _ expanded: Bool) -> some View {
        BottomJoinedControl(mode: mode, compact: compact, expanded: expanded, available: motion.sample != nil, palette: palette) {
            motion.capture(mode)
            showNotice(mode == .level ? "Level Calibrated" : "Reference Saved")
        } reset: {
            motion.reset(mode)
            showNotice(mode == .level ? "Calibration Reset" : "Reference Reset")
        }
    }

    private func showNotice(_ message: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        notice = message
        dismissal?.cancel()
        dismissal = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.35))
            if !Task.isCancelled { notice = nil }
        }
    }
}

private struct SceneProbe: UIViewRepresentable {
    let attach: (UIWindowScene?) -> Void
    final class Probe: UIView {
        var attach: ((UIWindowScene?) -> Void)?
        override func didMoveToWindow() { super.didMoveToWindow(); attach?(window?.windowScene) }
    }
    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.attach = attach
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ view: Probe, context: Context) {}
}

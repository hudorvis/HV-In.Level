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
            let wide = size.width > size.height && size.width >= 500 && size.height >= (isPad ? 330 : 300)
            let expanded = min(size.width, size.height) >= 600
            let reading = motion.reading(for: mode)
            ZStack {
                InTheme.background.ignoresSafeArea()
                if wide {
                    landscape(reading, size: size, expanded: expanded)
                } else {
                    // The instrument uses the whole window so hiding the status bar
                    // and home indicator cannot change its layout proposal.
                    let regularPhone = !isPad && size.height >= 780
                    let topInset: CGFloat = isPad ? 28 : (regularPhone ? 64 : 24)
                    let bottomInset: CGFloat = regularPhone ? 56 : (isPad ? 42 : 24)
                    let minHeight = topInset + bottomInset + (tab == .colours ? 502 : 453)
                    if size.height < minHeight {
                        ScrollView {
                            portrait(reading, expanded, topInset: topInset, bottomInset: bottomInset)
                                .frame(height: minHeight)
                        }
                    } else {
                        portrait(reading, expanded, topInset: topInset, bottomInset: bottomInset)
                    }
                }
                if full {
                    Color.clear.ignoresSafeArea().contentShape(Rectangle()).onTapGesture(perform: exitFullScreen)
                        .accessibilityHidden(true)
                }
                if !full, let notice {
                    Text(notice).font(.caption.weight(.semibold)).padding(8)
                        .background(.black, in: Capsule()).allowsHitTesting(false)
                        .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, wide ? 58 : 88)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .vertical)
        .background(SceneProbe { motion.scene = $0 })
        .statusBarHidden(full).persistentSystemOverlays(full ? .hidden : .automatic)
        .onChange(of: tab) { _, next in if next != .colours { slope = next == .slope } }
        .onChange(of: mode) { _, _ in notice = nil }
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private func landscape(_ reading: LevelReading, size: CGSize, expanded: Bool) -> some View {
        let columnWidth = size.width >= 1000 && size.height >= 650
            ? min(max(size.width * 0.28, 330), 420)
            : min(max(size.width * 0.30, 250), 292)
        return HStack(spacing: 0) {
            VStack(spacing: 0) {
                header(expanded)
                Spacer(minLength: 6)
                bottom(true, expanded).padding(.horizontal, 10).padding(.bottom, 8)
            }
            .padding(.top, isPad ? 28 : 4)
            .padding(.bottom, 20)
            .frame(width: columnWidth)
            .modifier(ControlVisibility(hidden: full))

            Rectangle().fill(.white.opacity(0.08)).frame(width: 1).padding(.vertical, 18)
                .opacity(full ? 0 : 1)
            interactiveInstrument(reading, wide: true)
                .padding(.horizontal, 5)
                .padding(.top, isPad ? 24 : 4)
                .padding(.bottom, isPad ? 24 : 12)
        }
        .padding(.horizontal, 8)
    }

    private func portrait(_ reading: LevelReading, _ expanded: Bool, topInset: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            header(expanded).modifier(ControlVisibility(hidden: full))
            interactiveInstrument(reading, wide: false).padding(8)
            bottom(false, expanded).frame(maxWidth: expanded ? 720 : 620).padding(.horizontal, 24)
                .modifier(ControlVisibility(hidden: full))
        }
        .padding(.top, topInset)
        .padding(.bottom, bottomInset)
    }

    private func interactiveInstrument(_ reading: LevelReading, wide: Bool) -> some View {
        InstrumentStage(reading: reading, mode: mode, slope: slope, palette: palette, full: full, wide: wide)
            .contentShape(Rectangle())
            .onTapGesture(perform: full ? exitFullScreen : enterFullScreen)
            .accessibilityAction(named: Text(full ? "Exit Full Screen" : "Full Screen")) {
                if full { exitFullScreen() } else { enterFullScreen() }
            }
    }

    private func exitFullScreen() {
        full = false
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

private struct ControlVisibility: ViewModifier {
    let hidden: Bool

    func body(content: Content) -> some View {
        content
            .opacity(hidden ? 0 : 1)
            .allowsHitTesting(!hidden)
            .accessibilityHidden(hidden)
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

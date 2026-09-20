import AVFoundation
import AppKit

/// The bubble: a round, borderless, always-on-top window with a camera in it.
///
/// Three settings do the work, and each is load-bearing:
///
///  - `.nonactivatingPanel` plus `canBecomeKey == false`, so clicking the bubble
///    never pulls focus out of whatever is being demonstrated. A webcam bubble
///    that steals the caret ruins the recording it exists to appear in.
///  - `.canJoinAllSpaces` with `.fullScreenAuxiliary`, so it follows the user into
///    another app's full-screen space instead of being left behind on the desktop.
///    Either one alone is not enough: the first handles Spaces, the second is the
///    only thing that gets a window over a full-screen app at all.
///  - `level = .statusBar`, which is above every ordinary window including a
///    full-screen one, and still below the menu bar's own panels.
final class BubblePanel: NSPanel {
    /// Called after a drag finishes, so the new position can be written down.
    var onMoved: (() -> Void)?

    private let bubble: BubbleView

    init(session: AVCaptureSession, size: CGFloat, origin: CGPoint?) {
        bubble = BubbleView(session: session)
        let rect = CGRect(origin: origin ?? Self.defaultOrigin(size: size),
                          size: CGSize(width: size, height: size))
        super.init(contentRect: rect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        // Excluded from window capture so screen-recording pickers and Mission
        // Control do not offer a round webcam as a shareable window.
        isExcludedFromWindowsMenu = true

        bubble.onDragEnded = { [weak self] in
            self?.clampToScreen()
            self?.onMoved?()
        }
        contentView = bubble
        setFrame(rect, display: false)
        clampToScreen()
        // Rounded here rather than left to the first layout pass. The radius is
        // otherwise zero until something lays the view out, which is one frame of
        // a square webcam before it snaps to a circle.
        bubble.radiusChanged()
    }

    /// A borderless panel is not key-eligible by default; saying so explicitly is
    /// what stops a click from activating the app behind the scenes.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Resizes about the centre, so the stone grows where it already is rather
    /// than crawling toward a corner each time the size changes.
    func resize(to size: CGFloat) {
        let centre = CGPoint(x: frame.midX, y: frame.midY)
        setFrame(CGRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size),
                 display: true)
        bubble.radiusChanged()
        clampToScreen()
        invalidateShadow()
    }

    func setMirrored(_ mirrored: Bool) { bubble.setMirrored(mirrored) }

    /// Keeps the whole bubble on some screen. Without this, a stone parked on an
    /// external display reopens off-canvas once that display is gone, and there is
    /// no way to drag back something you cannot see.
    private func clampToScreen() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        if screens.contains(where: { $0.visibleFrame.contains(frame) }) { return }

        let target = screens.first { $0.visibleFrame.intersects(frame) } ?? NSScreen.main ?? screens[0]
        let area = target.visibleFrame
        var origin = frame.origin
        origin.x = min(max(origin.x, area.minX), area.maxX - frame.width)
        origin.y = min(max(origin.y, area.minY), area.maxY - frame.height)
        setFrameOrigin(origin)
    }

    private static func defaultOrigin(size: CGFloat) -> CGPoint {
        let area = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        // Bottom-left, a margin in: out of the way of a menu bar, a Dock on the
        // right, and most slide content.
        return CGPoint(x: area.minX + 48, y: area.minY + 48)
    }
}

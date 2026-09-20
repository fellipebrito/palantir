import AVFoundation
import AppKit

/// What is actually inside the bubble: a preview layer, a circular mask, and a
/// thin rim so the stone reads as an object rather than a hole in the screen.
///
/// Deliberately AppKit and not SwiftUI. The whole view is one `CALayer` handed a
/// capture session, and it has to receive raw mouse events to be draggable while
/// the app is inactive -- both of which a hosting view makes harder than it is.
final class BubbleView: NSView {
    /// Called when a drag finishes, not while it is in progress: the position is
    /// worth writing down once, not sixty times a second.
    var onDragEnded: (() -> Void)?

    private let preview: AVCaptureVideoPreviewLayer
    private var mirrored = true

    init(session: AVCaptureSession) {
        preview = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)

        wantsLayer = true
        let host = layer ?? CALayer()
        host.masksToBounds = true
        // Dark rather than clear, so the moment between opening the stone and the
        // first frame is an unlit stone instead of a flicker of desktop.
        host.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 1).cgColor
        host.borderWidth = 2
        host.borderColor = NSColor(calibratedRed: 1, green: 0.69, blue: 0.40, alpha: 0.55).cgColor

        // resizeAspectFill: a 16:9 sensor has to cover a circle, so the sides are
        // cropped rather than letterboxed into grey bars.
        preview.videoGravity = .resizeAspectFill
        preview.masksToBounds = true
        host.addSublayer(preview)
        layer = host

        // The mirroring flag lives on the connection, and the connection does not
        // exist until the session has an input and has started. Re-applied on that
        // notification rather than assumed at construction time.
        NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionDidStartRunning, object: session, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyMirroring() }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not from a nib") }

    // MARK: - Geometry

    override func layout() {
        super.layout()
        // Implicit animation off: the layers must resize with the window in the
        // same frame, or the stone visibly wobbles on every size change.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        preview.frame = bounds
        radiusChanged()
        CATransaction.commit()
    }

    func radiusChanged() {
        let r = bounds.width / 2
        layer?.cornerRadius = r
        preview.cornerRadius = r
    }

    func setMirrored(_ mirrored: Bool) {
        self.mirrored = mirrored
        applyMirroring()
    }

    private func applyMirroring() {
        guard let connection = preview.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = mirrored
    }

    // MARK: - Dragging

    /// True because the app is never active: without this the first click on the
    /// bubble would be swallowed as an activation click and the stone would only
    /// move on the second drag.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        // Runs its own event loop and returns on mouse-up.
        window?.performDrag(with: event)
        onDragEnded?()
    }

    /// Clicks in the corners of the square frame belong to whatever is behind the
    /// stone, not to the stone. Without this the bubble is a round picture with an
    /// invisible square footprint.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let p = convert(point, from: superview)
        let r = bounds.width / 2
        let dx = p.x - bounds.midX, dy = p.y - bounds.midY
        return dx * dx + dy * dy <= r * r ? self : nil
    }
}

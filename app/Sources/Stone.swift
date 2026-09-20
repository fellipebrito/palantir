import AVFoundation
import AppKit
import Observation

/// The three sizes, named for how far you can see with one.
enum StoneSize: Int, CaseIterable, Identifiable {
    case pocket = 160
    case seeing = 240
    case orthanc = 320

    var id: Int { rawValue }
    var points: CGFloat { CGFloat(rawValue) }

    var title: String {
        switch self {
        case .pocket:  "Pocket stone"
        case .seeing:  "Seeing stone"
        case .orthanc: "Orthanc stone"
        }
    }
}

/// The stone itself: what it is looking through, how big it is, where it sits, and
/// the reasons it might be dark.
///
/// Everything the user can change survives a quit, because the alternative is
/// repositioning a bubble at the start of every recording. `UserDefaults` is the
/// whole persistence story on purpose -- five scalars do not need a store.
@MainActor
@Observable
final class Stone {
    private(set) var isShowing = false
    /// Why the stone is dark, when the reason is not simply that it was shrouded.
    /// Nil means the user shrouded it, which needs no explanation.
    private(set) var darkness: String?
    private(set) var size: StoneSize
    private(set) var isMirrored: Bool
    private(set) var deviceID: String?
    private(set) var cameras: [AVCaptureDevice] = []

    private let engine = CameraEngine()
    private var panel: BubblePanel?

    private enum Key {
        static let showing  = "stone.showing"
        static let size     = "stone.size"
        static let mirrored = "stone.mirrored"
        static let device   = "stone.device"
        static let originX  = "stone.origin.x"
        static let originY  = "stone.origin.y"
    }

    init() {
        let d = UserDefaults.standard
        size = StoneSize(rawValue: d.integer(forKey: Key.size)) ?? .seeing
        isMirrored = d.object(forKey: Key.mirrored) as? Bool ?? true
        deviceID = d.string(forKey: Key.device)
        refreshCameras()

        // A camera appearing or vanishing changes what the picker can offer, and
        // can pull the floor out from under a stone that is currently watching.
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.camerasChanged() }
            }
        }

        // Restored rather than opened by default: an app that switches a camera on
        // at login, with the green light, is an app people delete.
        if d.bool(forKey: Key.showing) { show() }
    }

    // MARK: - Showing and shrouding

    func show() {
        guard !isShowing else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            // Ask, then come back through this same path on the answer.
            darkness = "macOS has not been asked yet"
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted { self.darkness = nil; self.show() }
                    else { self.darkness = "the camera was refused" }
                }
            }
            return
        case .denied, .restricted:
            darkness = "the camera is blocked in System Settings"
            return
        @unknown default:
            darkness = "macOS would not say whether the camera is allowed"
            return
        }

        guard let device = CameraEngine.device(id: deviceID) else {
            darkness = "no camera answered"
            return
        }
        deviceID = device.uniqueID

        let panel = panel ?? makePanel()
        self.panel = panel
        panel.resize(to: size.points)
        panel.setMirrored(isMirrored)
        panel.orderFrontRegardless()

        engine.run(deviceID: device.uniqueID)
        isShowing = true
        darkness = nil
        persist()
    }

    func shroud() {
        guard isShowing else { return }
        engine.stop()
        panel?.orderOut(nil)
        isShowing = false
        darkness = nil
        persist()
    }

    func toggle() { isShowing ? shroud() : show() }

    // MARK: - What the user can change

    func resize(to size: StoneSize) {
        self.size = size
        panel?.resize(to: size.points)
        persist()
    }

    func setMirrored(_ mirrored: Bool) {
        isMirrored = mirrored
        panel?.setMirrored(mirrored)
        persist()
    }

    func use(camera: AVCaptureDevice) {
        deviceID = camera.uniqueID
        if isShowing { engine.run(deviceID: camera.uniqueID) }
        persist()
    }

    /// The camera currently being looked through, for the menu to name.
    var currentCamera: AVCaptureDevice? { CameraEngine.device(id: deviceID) }

    func refreshCameras() { cameras = CameraEngine.devices() }

    private func camerasChanged() {
        refreshCameras()
        guard isShowing else { return }
        if let device = CameraEngine.device(id: deviceID) {
            // Covers both the unplug (fall through to another camera) and the
            // plug-in of the camera that was remembered all along.
            if device.uniqueID != deviceID { deviceID = device.uniqueID; persist() }
            engine.run(deviceID: device.uniqueID)
        } else {
            shroud()
            darkness = "the camera was unplugged"
        }
    }

    // MARK: - Where it sits

    private func makePanel() -> BubblePanel {
        let d = UserDefaults.standard
        let origin: CGPoint? = d.object(forKey: Key.originX) != nil
            ? CGPoint(x: d.double(forKey: Key.originX), y: d.double(forKey: Key.originY))
            : nil
        let panel = BubblePanel(session: engine.session, size: size.points, origin: origin)
        panel.onMoved = { [weak self] in self?.persist() }
        return panel
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(isShowing, forKey: Key.showing)
        d.set(size.rawValue, forKey: Key.size)
        d.set(isMirrored, forKey: Key.mirrored)
        d.set(deviceID, forKey: Key.device)
        if let frame = panel?.frame {
            d.set(frame.origin.x, forKey: Key.originX)
            d.set(frame.origin.y, forKey: Key.originY)
        }
    }
}

import AVFoundation

/// The capture session, and the one rule that keeps it safe to touch.
///
/// Every mutation of an `AVCaptureSession` happens on one serial queue, never on
/// the main actor: `startRunning()` blocks until the device is warm, which on an
/// external camera is long enough to drop frames out of whatever is being
/// recorded. The session object itself is handed to the preview layer on the main
/// thread, which is what `AVCaptureVideoPreviewLayer` is built to expect.
///
/// That split is why this is `@unchecked Sendable` rather than an actor: the
/// compiler cannot see the queue discipline, and an actor cannot hand the session
/// to a layer that must be built on main.
final class CameraEngine: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "app.palantir.camera")
    private var input: AVCaptureDeviceInput?

    /// Cameras the stone could look through, in the order macOS reports them.
    /// Continuity and Desk View are included deliberately: an iPhone on a stand is
    /// a better webcam than anything built into a Mac.
    static func devices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera, .deskViewCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
    }

    static func device(id: String?) -> AVCaptureDevice? {
        let all = devices()
        // A remembered camera that is no longer plugged in falls back to whatever
        // is here now, rather than showing a black circle and no explanation.
        if let id, let match = all.first(where: { $0.uniqueID == id }) { return match }
        return all.first
    }

    /// Points the session at a camera and starts it. Safe to call repeatedly with
    /// the same camera; the reconfiguration is skipped.
    ///
    /// Takes an id rather than the device, because the device is not `Sendable` and
    /// this hops to the session queue. Re-resolving it there costs a dictionary
    /// lookup and keeps the concurrency checking honest.
    func run(deviceID: String) {
        queue.async { [self] in
            if input?.device.uniqueID != deviceID {
                guard let device = AVCaptureDevice(uniqueID: deviceID) else { return }
                session.beginConfiguration()
                if let input { session.removeInput(input) }
                input = try? AVCaptureDeviceInput(device: device)
                if let input, session.canAddInput(input) {
                    session.addInput(input)
                } else {
                    input = nil
                }
                session.commitConfiguration()
            }
            if input != nil, !session.isRunning { session.startRunning() }
        }
    }

    /// Stops the session and releases the camera, which is what turns the green
    /// hardware light off. Shrouding the stone has to mean the camera is actually
    /// released, not merely hidden behind a window.
    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
            session.beginConfiguration()
            if let input { session.removeInput(input) }
            input = nil
            session.commitConfiguration()
        }
    }
}

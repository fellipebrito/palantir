import AppKit
import SwiftUI

/// The About box.
///
/// Hand-built rather than `orderFrontStandardAboutPanel`, because an `LSUIElement`
/// app has no application menu to reach the standard one from, and the standard
/// one would show the bundle name `Palantir` -- the identifier spelling, without
/// its accent -- as the title.
enum AboutWindow {
    @MainActor private static var window: NSWindow?

    @MainActor
    static func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let created = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 210),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        created.titlebarAppearsTransparent = true
        created.titleVisibility = .hidden
        created.isMovableByWindowBackground = true
        created.contentView = NSHostingView(rootView: AboutView())
        created.center()
        // Released on close would dangle the reference held here; kept instead, and
        // reused on the next open.
        created.isReleasedWhenClosed = false

        window = created
        // The app is a menu bar extra and is never active, so the window would open
        // behind everything without this.
        NSApp.activate(ignoringOtherApps: true)
        created.makeKeyAndOrderFront(nil)
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .padding(.bottom, 12)
            }

            Text("Palantír")
                .font(.system(size: 17, weight: .semibold))

            Text(version)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Text("A seeing-stone for your screen. It shows only your face. Probably.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .padding(.horizontal, 28)

            Spacer(minLength: 16)

            Link("Built by Fellipe Brito", destination: URL(string: "https://fellipebrito.com")!)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 26)
        .padding(.bottom, 18)
        .frame(width: 320)
    }

    /// Read from the bundle so the About box cannot drift from what was shipped.
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }
}

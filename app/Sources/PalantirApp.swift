import SwiftUI

/// Palantír: a seeing-stone that sits on top of everything, so a screen recording
/// catches your face as well as your screen.
///
/// Menu bar only. `LSUIElement` in Info.plist removes the Dock icon and the menu
/// bar, which is what makes this feel like a utility rather than an application,
/// while leaving it findable in Spotlight because it is still a real .app. The
/// bubble is the only window with any chrome to it, and it has none.
@main
struct PalantirApp: App {
    @State private var stone = Stone()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(stone: stone)
        } label: {
            // Template SF Symbols, so they invert correctly in light and dark menu
            // bars and under Reduce Transparency without shipping two assets.
            Image(systemName: stone.isShowing ? "circle.circle.fill" : "circle.dotted")
                .accessibilityLabel(stone.isShowing ? "Palantír: the stone is watching"
                                                    : "Palantír: the stone is dark")
        }
        .menuBarExtraStyle(.window)
    }
}

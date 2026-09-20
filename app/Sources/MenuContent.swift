import AVFoundation
import SwiftUI

/// The dropdown. Status, the one action that matters, the three that shape it,
/// and the byline.
///
/// The two pickers expand in place rather than flying out as submenus. A menu bar
/// extra in `.window` style is a panel, not an `NSMenu`, which is what buys the
/// two-line status at the top -- and a panel has no submenus to fly out. Expanding
/// inline keeps every choice in one surface and one visual language.
struct MenuContent: View {
    @Bindable var stone: Stone

    @State private var sizesOpen = false
    @State private var camerasOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Circle()
                    .fill(stone.isShowing ? Color.orange : Color.secondary.opacity(0.45))
                    .frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stone.isShowing ? "The stone is watching" : "The stone is dark")
                        .font(.system(size: 13, weight: .semibold))
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 13)
            .padding(.bottom, 12)

            Divider()

            MenuRow(title: stone.isShowing ? "Shroud the stone" : "Gaze into the stone") {
                stone.toggle()
            }

            Divider()

            MenuRow(title: "Size of the stone", detail: stone.size.title, disclosed: sizesOpen) {
                sizesOpen.toggle()
            }
            if sizesOpen {
                ForEach(StoneSize.allCases) { size in
                    MenuRow(title: size.title,
                            detail: "\(Int(size.points))px",
                            checked: stone.size == size,
                            indented: true) {
                        stone.resize(to: size)
                        sizesOpen = false
                    }
                }
            }

            MenuRow(title: "Mirror the vision", checked: stone.isMirrored) {
                stone.setMirrored(!stone.isMirrored)
            }

            MenuRow(title: "Choose your stone",
                    detail: stone.currentCamera?.localizedName,
                    disclosed: camerasOpen) {
                stone.refreshCameras()
                camerasOpen.toggle()
            }
            if camerasOpen {
                if stone.cameras.isEmpty {
                    Text("No camera answered")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 9)
                } else {
                    ForEach(stone.cameras, id: \.uniqueID) { camera in
                        MenuRow(title: camera.localizedName,
                                checked: camera.uniqueID == stone.currentCamera?.uniqueID,
                                indented: true) {
                            stone.use(camera: camera)
                            camerasOpen = false
                        }
                    }
                }
            }

            Divider()

            MenuRow(title: "About Palantír") { AboutWindow.show() }
            MenuRow(title: "Cast it into the sea") { NSApplication.shared.terminate(nil) }

            Divider()

            Link("Built by Fellipe Brito", destination: URL(string: "https://fellipebrito.com")!)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .frame(width: 260)
        .onAppear { stone.refreshCameras() }
    }

    /// The one line that has to earn its place: what is true right now, and if
    /// nothing is, why not.
    private var detail: String {
        if stone.isShowing {
            let through = stone.currentCamera?.localizedName ?? "an unnamed camera"
            return "Through \(through). \(Int(stone.size.points))px."
        }
        return "Dark because \(stone.darkness ?? "it was shrouded")."
    }
}

/// One line of the panel. Extracted because there are ten of them and the padding,
/// hit area and hover behaviour have to agree across all ten.
private struct MenuRow: View {
    let title: String
    var detail: String? = nil
    var checked = false
    /// Nil for an ordinary row; true or false for a section that opens in place.
    var disclosed: Bool? = nil
    var indented = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer(minLength: 6)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .layoutPriority(-1)
                }
                if checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                }
                if let disclosed {
                    Image(systemName: disclosed ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, indented ? 26 : 14)
            .padding(.trailing, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(hovering ? Color.primary.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

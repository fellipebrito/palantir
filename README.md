# Palantír

A webcam bubble that floats above everything, so a QuickTime screen recording
catches your face as well as your screen.

Tolkien's palantíri are seeing-stones: dark spheres you look into to see
somewhere else. This one only ever shows your own face, which is either a
disappointment or a mercy.

Menu bar only. No Dock icon, no preferences window, no window chrome anywhere
except the bubble, and the bubble has none.

<!-- SCREENSHOT GOES HERE. Add docs/screenshot.png (the bubble over a real
     recording, bottom-left, with the menu open beside it) and restore:
     ![Palantír on top of a screen recording](docs/screenshot.png) -->

## What it actually does

QuickTime records your screen or your camera, never both. The usual workaround
is a second app compositing two video sources, which is a lot of machinery for
"put my face in the corner."

Palantír puts a live camera preview in a round, always-on-top window. QuickTime
records the screen, the bubble is on the screen, so the bubble is in the
recording. Nothing is composited and nothing is written to disk by this app.

- **Circular and borderless.** Clicks in the corners of its square footprint pass
  through to whatever is behind it, because the stone is round and its hit area
  should be too.
- **Above everything, in every Space.** `canJoinAllSpaces` follows you between
  desktops and `fullScreenAuxiliary` is what gets a window over a full-screen app
  at all. Both are needed; neither is sufficient.
- **Never steals focus.** A non-activating panel that refuses to become key, so
  dragging the bubble mid-demo does not take the caret out of your editor.
- **Draggable**, and it remembers where you put it.
- **Three sizes**: 160, 240 and 320 points. Resizing holds the centre, so the
  stone grows where it already is.
- **Mirrored by default**, because you are used to a mirror and your audience is
  not looking at the bubble to read your shirt.
- **Any camera**, including Continuity and Desk View. An iPhone on a stand is a
  better webcam than anything built into a Mac.
- **Shrouding releases the camera**, so the green light actually goes out rather
  than the window merely hiding.

Position, size, mirroring, chosen camera and whether the stone was open all
survive a quit, in `UserDefaults`. Five scalars do not need a store.

## Requirements

macOS 14 or later. No external dependencies: AppKit, SwiftUI and AVFoundation,
and nothing else.

[XcodeGen](https://github.com/yonaskolb/XcodeGen) generates the project file,
which is why no `.xcodeproj` is committed. It is a build tool, not a dependency
of the app.

## Running it

```sh
brew install xcodegen
cd app && xcodegen generate
xcodebuild -project Palantir.xcodeproj -scheme Palantir -configuration Release \
  -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build
open build/dd/Build/Products/Release/Palantir.app
```

`CODE_SIGNING_ALLOWED=NO` is what lets this build without the signing identity
in `project.yml`. Drop it if you have your own.

The app appears in the menu bar and nowhere else. On the first "Gaze into the
stone" macOS asks for camera access; refuse it and the menu says so rather than
showing a black circle.

## Releasing

```sh
ASC_KEY_ID=<key-id> ASC_ISSUER=<issuer-uuid> ./scripts/release.sh
```

Builds, signs with Developer ID, notarizes, staples, and writes
`dist/Palantir-<version>.dmg`. The version in the filename is read back out of
the built bundle, so the number on the DMG is the number inside it.

Notarization runs **twice**, on the `.app` and then on the DMG that carries it.
Both are needed. Notarizing only the DMG leaves the app itself without a ticket,
so dragging it to `/Applications` and then going offline gives Gatekeeper
nothing local to validate against.

Two shorter paths:

- `--no-notarize` signs with Developer ID but skips Apple entirely, for when the
  App Store Connect key is not to hand. Gatekeeper warns on a Mac that has never
  seen the app before.
- `--unsigned` skips signing too. Gatekeeper blocks it. Local testing only.

Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `app/project.yml`
before cutting one. Nothing else carries a version number: the About box reads
the bundle, and the release script reads the bundle.

## The certificate

Signed by **Bossa Nova Solutions (`AR7DXKP4VP`)** on the same Developer ID
Application certificate as Lidless. One certificate signs any number of apps, so
there is nothing to create here.

**No API key can create one, on any team, at any role.** Both certificate types
were tried against both teams and all four returned:

```
POST /v1/certificates -> 403
"This operation can only be performed by the Account Holder."
```

It is a human-in-the-portal step by design. Do not spend time automating it.

The private key lives outside this repo and never left the machine that made it,
which is the point. The certificate is worthless without it, and losing it costs
one of the five Developer ID slots the team gets. Back it up. Revoking one
invalidates every app already signed with it, so create one, keep it, do not
churn it.

Expect a one-time keychain prompt the first time `codesign` reaches for the key
on any machine. The first build fails, the second succeeds; that is the prompt,
not a bug.

## Distribution

Releases go out as **GitHub Releases**, not committed to the repo:

```sh
ASC_KEY_ID=<key-id> ASC_ISSUER=<issuer-uuid> ./scripts/release.sh
gh release create v1.0 dist/Palantir-1.0.dmg --title "Palantír 1.0" --notes "..."
```

Download the DMG, drag to Applications, open. The notarization ticket is
stapled, so it opens with no warning even on a Mac that is offline.

## The menu

| Item | What it does |
|---|---|
| Gaze into the stone | Opens the bubble |
| Shroud the stone | Closes it and releases the camera |
| Size of the stone | Pocket (160), Seeing (240), Orthanc (320) |
| Mirror the vision | Flips the preview horizontally |
| Choose your stone | Picks the camera |
| About Palantír | Version, from the bundle |
| Cast it into the sea | Quits |

## Known limits

- **It cannot sit next to the clock.** macOS places every third-party menu bar
  item to the left of the system cluster. Cmd-drag reorders among third-party
  icons; nothing moves right of the system ones.
- **The bubble is a window, so a window-scoped recording can catch it.** Recording
  a single window will not include the bubble; recording the screen will.
- The two pickers open in place instead of flying out as submenus. A menu bar
  extra in `.window` style is a panel rather than an `NSMenu`, which is what buys
  the two-line status at the top, and a panel has no submenus to fly out.

## Sibling project

[**Lidless**](https://github.com/fellipebrito/lidless) keeps a Mac awake while
the Eye is open, and closes the Eye when the lid closes. Same menu bar, same
conventions, same corner of Middle-earth.

## Licence

MIT. See [LICENSE](LICENSE).

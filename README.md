<p align="center">
  <img src="docs/pluck-icon.png" width="160" alt="Pluck app icon" />
</p>

<h1 align="center">Pluck</h1>

<p align="center">Hold-click to copy, anywhere on macOS 26.</p>

Select text in any app, press down on the selection, keep the mouse still for
~150 ms, release. The text is now on your clipboard. A Liquid Glass "✓ Copied"
pill morphs in at the bottom-center of the screen. The click's native behavior
(deselect, caret move) proceeds unchanged.

No modifier key. No floating UI. Just a gesture.

## Why

Terminals and several Linux desktops let you "select, click, copied". macOS
has never shipped an equivalent. Existing tools are either floating action
bars (PopClip), copy-on-every-select (macpaste), or clipboard history
managers. Pluck is neither.

## Install

Requires macOS 26+ (the HUD uses Apple's Liquid Glass, which is macOS 26 only).
Built with Xcode 26.

### Users

Download `Pluck-<version>.dmg` from Releases, open it, and drag Pluck
into Applications. The DMG is signed with a Developer ID and notarized
by Apple — no Gatekeeper warning.

### Developers

```sh
make install              # build, adhoc-sign, copy to /Applications, launch
make run                  # build and open from the build dir
make full-reset           # wipe TCC + UserDefaults + bundles, reinstall
make dmg                  # signed + notarized DMG release
```

`make install` signs adhoc by default, and macOS then asks for the two
permissions again after every rebuild. To keep them, sign with a stable
identity: copy `local.mk.example` to `local.mk` and name a code-signing
identity from your keychain (a self-signed one works).

The first launch walks you through two system permissions:

- **Accessibility** — so Pluck can read the selected text from the window you
  click in.
- **Input Monitoring** — so Pluck can observe (not intercept) your mouse
  events.

## Copy counter (this fork, the default)

Out of the box this fork copies nothing by itself. Copy as usual (Cmd+C,
Edit → Copy); the app does the copying, and Pluck shows "Copied 42
characters ✓" when text lands on the clipboard. macOS sends nothing when
the clipboard changes, so Pluck compares the pasteboard's change count
every 0.25 s and reads the text only when it moved. Items marked
concealed (passwords), transient or auto-generated per nspasteboard.org
are never read. This mode needs no permissions.

The gestures below (copy on select, hold to copy) are off; turn them on
in Preferences → Gesture → **Copy with gestures** (they need
Accessibility and Input Monitoring).

## Copy on select (this fork)

With **Copy on select** on (the default, Preferences → Gesture), you do
not need the hold: finish a selection with a drag or a double/triple
click and release, and the text is on your clipboard.

- The gesture counts only if it started on text: Pluck asks the
  Accessibility API what is under the press point (a text view, text
  field or web content). Moving a window by its title bar, dragging a
  file or a slider, or double-clicking a button copies nothing, even when
  some text is still selected elsewhere.
- A double/triple click copies the word or line it selected.
- Text already on the clipboard is not written again; the pill shows only
  when the clipboard changed.
- Text in web pages counts even inside lists and tables (AXList, AXRow,
  AXCell under an AXWebArea); in native apps those roles are file lists
  and tables, and a gesture on them copies nothing.
- When a gesture does not copy, watch what Pluck sees:
  `log stream --level debug --predicate 'subsystem == "md.getdesign.pluck"'`
  logs the AX roles under the press point and the focused element (never
  the selected text).
- Chromium browsers (Chrome, Edge, Brave, Arc) and Electron apps build
  their web-content accessibility tree only on request. Pluck sets
  `AXManualAccessibility` on each app when it becomes active, and reads
  web selections through `AXSelectedTextMarkerRange` when
  `AXSelectedText` is empty. The tree costs those apps memory and CPU for
  as long as they run, so it is not requested for blocklisted apps or
  while Pluck is paused.

## How it decides to fire (hold gesture)

1. You mouse-down somewhere.
2. If you drag, Pluck stays out of the way — you're selecting.
3. If you release in under 150 ms, Pluck stays out of the way — you were
   clicking normally.
4. If you hold still for 150 ms+, Pluck reads the selected text via the
   Accessibility API, writes it to the clipboard, and morphs a Liquid Glass
   pill in at the bottom-center of the active screen.
5. Your click finishes naturally: selection clears, caret moves.

If the app doesn't expose its selection via the Accessibility API (many
Electron apps, some Chromium embeds), Pluck transparently synthesizes a
Cmd+C, keeps the result if the clipboard changed, and restores the previous
clipboard otherwise.

## Configure

Menu bar → **Preferences…**

- **Hold delay** — 100–400 ms, default 150 ms.
- **Launch at login** — via `SMAppService`.
- **Blocklist** — apps where Pluck stays silent. Ships with sane defaults
  (Figma, Sketch, Photoshop, Illustrator, Blender, Unity, Unreal, Excel,
  Numbers, Xcode Interface Builder). This fork leaves Finder out, so text
  selected while renaming a file is copied.

## Develop

```sh
swift build           # compile
swift test            # unit tests
make bundle           # assemble Pluck.app (adhoc signed)
make run              # build, sign, launch
make clean            # wipe build artifacts
```

Layout:

```
Sources/Pluck/
  PluckApp.swift            # @main, MenuBarExtra + Settings scenes
  AppShell.swift            # wires engine → reader → HUD
  Engine/
    GestureStateMachine.swift   # pure state machine (testable)
    GestureEngine.swift         # CGEventTap wrapper
    AXSelectionSource.swift     # reads kAXSelectedTextAttribute
    Pasteboard.swift            # NSPasteboard abstraction
    KeystrokeSender.swift       # Cmd+C synthesis
    SelectionReader.swift       # AX → Cmd+C fallback orchestration
  HUD/
    CopiedPill.swift            # SwiftUI pill
    HUDGeometry.swift           # pure positioning math
    HUDPresenter.swift          # NSPanel lifecycle
  Prefs/
    PrefsView.swift
    Blocklist.swift
  Onboarding/
    PermissionChecks.swift
    OnboardingWindow.swift
  Resources/
    Info.plist
    entitlements.plist
Tests/PluckTests/
  GestureStateMachineTests.swift
  SelectionReaderTests.swift
  HUDGeometryTests.swift
  BlocklistTests.swift
```

## Design

`DESIGN.md` is generated from `npx getdesign@latest add apple` and drives the
look of the HUD pill, preferences window, and onboarding. It's a spec for AI
coding agents — it has no runtime role.

## How I built it

I built this with Claude Code and Codex working like a small team. One agent plans the work and
writes a spec for each piece, subagents write the code from those specs, and the two tools review
each other's changes. I approve the plan before any code gets written, I read every diff before
it's committed, and nothing ships until the tests pass. Anything that touches security or user
data I write or check line by line myself.

## License

MIT. See [LICENSE](LICENSE).

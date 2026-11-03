import AppKit
import SwiftUI

@MainActor
@Observable
final class AppShell: NSObject, NSWindowDelegate {
    let blocklist: Blocklist
    let engine: GestureEngine
    let selectionReader: SelectionReader
    let hud: HUDPresenter
    let onboardingState: OnboardingState
    let accessibilityEnabler: AccessibilityEnabler
    let clipboardWatcher: ClipboardWatcher
    private var onboardingWindow: NSWindow?
    private var defaultsObserver: NSObjectProtocol?

    /// Off by default (the user, 2026-11-03: only the pill on Cmd+C). With
    /// gestures off Pluck needs neither Accessibility nor Input Monitoring:
    /// it only watches the clipboard.
    static let gesturesEnabledKey = "pluck.gesturesEnabled"
    var gesturesEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.gesturesEnabledKey)
    }

    var isPaused: Bool {
        get { engine.isPaused }
        set { engine.isPaused = newValue }
    }

    override init() {
        let blocklist = Blocklist()
        self.blocklist = blocklist
        let engine = GestureEngine()
        self.engine = engine
        self.selectionReader = SelectionReader(blocklist: blocklist)
        self.hud = HUDPresenter()
        self.onboardingState = OnboardingState()
        self.accessibilityEnabler = AccessibilityEnabler(blocklist: blocklist,
                                                         isPaused: { engine.isPaused })
        let hud = self.hud
        self.clipboardWatcher = ClipboardWatcher(
            isPaused: { engine.isPaused },
            onCopy: { text in
                hud.show(near: CGEvent(source: nil)?.location ?? .zero, text: text)
            })
        super.init()

        let storedDelay = UserDefaults.standard.integer(forKey: "pluck.holdDelayMs")
        engine.holdDelayMs = storedDelay == 0 ? 150 : storedDelay

        engine.copyOnSelect = UserDefaults.standard.object(forKey: Self.copyOnSelectKey) as? Bool ?? true

        engine.onHoldThreshold = { [weak self] point in
            self?.handleHold(at: point)
        }
        engine.onPress = { [weak self] point in
            self?.handlePress(at: point)
        }
        engine.onSelectionEnded = { [weak self] press, release in
            self?.handleSelectionEnded(press: press, release: release)
        }
    }

    static let copyOnSelectKey = "pluck.copyOnSelect"

    /// Bumped on every mouse-down. A copy-on-select read that finishes after
    /// a newer press belongs to an obsolete gesture and is dropped, so a
    /// slow AX read never overwrites the clipboard with an older selection.
    private var gestureGeneration = 0

    func handlePress(at point: CGPoint) {
        gestureGeneration &+= 1
        // Pick up a Preferences change on the next click.
        engine.copyOnSelect = UserDefaults.standard.object(forKey: Self.copyOnSelectKey) as? Bool ?? true
    }

    func handleSelectionEnded(press: CGPoint, release: CGPoint) {
        let generation = gestureGeneration
        let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        pluckLog.debug("selection gesture ended app=\(app, privacy: .public)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Let the app publish the final selection to AX.
            try? await Task.sleep(for: .milliseconds(60))
            guard generation == self.gestureGeneration, self.engine.copyOnSelect,
                  let text = await self.selectionReader.selectionFromGesture(press: press, release: release),
                  generation == self.gestureGeneration,
                  self.selectionReader.writeIfNew(text) != nil
            else { return }
            self.clipboardWatcher.noteOwnWrite()
            self.hud.show(near: release, text: text)
        }
    }

    /// Persisted in UserDefaults so onboarding reappears on relaunch until
    /// the user has explicitly closed the window with both permissions
    /// granted. Decouples "permissions are satisfied" from "user has seen
    /// and confirmed the setup flow".
    var onboardingCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: "pluck.onboardingCompleted") }
        set { UserDefaults.standard.set(newValue, forKey: "pluck.onboardingCompleted") }
    }

    func bootstrap() {
        clipboardWatcher.start()
        // Preferences write the gestures toggle through @AppStorage.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyGesturesSetting() }
        }
        guard gesturesEnabled else { return }
        // Additive, not exclusive: engine starts whenever permissions are
        // granted, AND onboarding opens when either permissions are missing
        // OR the user has not yet confirmed setup. This makes the common
        // quit-after-granting-Input-Monitoring → relaunch flow work: the
        // engine is already live while the user clicks "Start using Pluck"
        // one last time to close the loop.
        if onboardingState.allGranted {
            startEngineIfPossible()
        }
        if !onboardingState.allGranted || !onboardingCompleted {
            showOnboarding()
        }
    }

    func handleHold(at point: CGPoint) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let currentDelay = UserDefaults.standard.integer(forKey: "pluck.holdDelayMs")
            if currentDelay > 0, currentDelay != self.engine.holdDelayMs {
                self.engine.holdDelayMs = currentDelay
            }
            if let outcome = await self.selectionReader.read(at: point) {
                self.clipboardWatcher.noteOwnWrite()
                self.hud.show(near: point, text: outcome.text)
            }
        }
    }

    func showOnboarding() {
        if let win = onboardingWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let view = OnboardingView(state: onboardingState) { [weak self] in
            self?.onboardingWindow?.close()
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Pluck"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        onboardingWindow = window
        onboardingState.beginPolling()
    }

    // Fires for any close path — red traffic light, "Skip for now", or the
    // "Start using Pluck" CTA — so we always stop polling and (if both
    // permissions are now granted) start the engine AND mark onboarding
    // confirmed. The grant is what matters; the specific button is cosmetic.
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow,
              closing === onboardingWindow else { return }
        onboardingState.stopPolling()
        onboardingWindow = nil
        if onboardingState.allGranted {
            onboardingCompleted = true
            startEngineIfPossible()
        }
    }

    private func applyGesturesSetting() {
        if gesturesEnabled, !engine.isRunning {
            startEngineIfPossible()
        } else if !gesturesEnabled, engine.isRunning {
            engine.stop()
        }
    }

    func startEngineIfPossible() {
        guard gesturesEnabled else { return }
        guard PermissionChecks.accessibilityTrusted(),
              PermissionChecks.inputMonitoringGranted() else {
            showOnboarding()
            return
        }
        do {
            try engine.start()
            accessibilityEnabler.start()
        } catch {
            NSLog("Pluck: failed to start event tap: \(error)")
        }
    }
}

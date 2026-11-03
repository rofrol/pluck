import AppKit
import ApplicationServices

/// Chromium browsers (Chrome, Edge, Brave, Arc) and Electron apps build the
/// accessibility tree of their web content only when an assistive client
/// asks for it. Without it, AX shows a bare window and Pluck finds no text.
/// Setting `AXManualAccessibility` on the application element asks for the
/// tree without the side effects of `AXEnhancedUserInterface` (which breaks
/// window animations and window managers). Other apps reject the attribute
/// as unsupported, which is harmless.
///
/// The tree costs those apps memory and CPU for the rest of their life, so
/// it is not requested for blocklisted apps or while Pluck is paused.
@MainActor
final class AccessibilityEnabler {
    /// Pids whose answer was final: enabled, or attribute unsupported.
    /// A failed request (an app still launching, whose AX server is not
    /// ready) is not recorded, so the next activation asks again.
    private var settledPIDs: Set<pid_t> = []
    private var inFlight: Set<pid_t> = []
    private var observer: NSObjectProtocol?
    private let blocklist: Blocklist
    private let isPaused: () -> Bool

    init(blocklist: Blocklist, isPaused: @escaping () -> Bool) {
        self.blocklist = blocklist
        self.isPaused = isPaused
    }

    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                if let app { self?.enable(app) }
            }
        }
        if let front = NSWorkspace.shared.frontmostApplication {
            enable(front)
        }
    }

    private func enable(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard pid > 0, pid != getpid(), !isPaused(),
              !settledPIDs.contains(pid), !inFlight.contains(pid) else { return }
        if let bundleID = app.bundleIdentifier, blocklist.contains(bundleID) { return }

        // Forget exited processes so a reused pid is asked again.
        let alive = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        settledPIDs.formIntersection(alive)

        inFlight.insert(pid)
        // AX calls are synchronous IPC and can block on a hung app.
        Task.detached(priority: .utility) { [weak self] in
            let result = AXUIElementSetAttributeValue(
                AXUIElementCreateApplication(pid),
                "AXManualAccessibility" as CFString,
                kCFBooleanTrue)
            pluckLog.debug("AXManualAccessibility pid=\(pid, privacy: .public) result=\(result.rawValue, privacy: .public)")
            await MainActor.run {
                guard let self else { return }
                self.inFlight.remove(pid)
                if result == .success || result == .attributeUnsupported {
                    self.settledPIDs.insert(pid)
                }
            }
        }
    }
}

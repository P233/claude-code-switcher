import Cocoa
import Foundation

// MARK: - Constants

/// Virtual key code for backtick (`) — used to send Ctrl+` to toggle VSCode terminal
let kVKBacktick: CGKeyCode = 50

/// Bundle ID prefixes for VSCode and forks (Cursor, Windsurf, etc.)
let vscodeBundlePrefixes = [
    "com.microsoft.VSCode",
    "com.todesktop.",
]

// MARK: - Window Helpers

func findVSCodeApps() -> [NSRunningApplication] {
    NSWorkspace.shared.runningApplications.filter { app in
        guard let id = app.bundleIdentifier else { return false }
        return vscodeBundlePrefixes.contains { id.hasPrefix($0) }
    }
}

/// Scans all windows across the given apps, returning the first (app, window) where `match(title)` is true.
func findWindow(in apps: [NSRunningApplication], matching match: (String) -> Bool) -> (NSRunningApplication, AXUIElement)? {
    for app in apps {
        let appRef = AXUIElementCreateApplication(app.processIdentifier)

        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            continue
        }

        for window in windows {
            var titleRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                  let title = titleRef as? String else {
                continue
            }

            if match(title) {
                return (app, window)
            }
        }
    }
    return nil
}

/// Activates the app, raises the window, and sends Ctrl+` to toggle the VSCode terminal.
func activateWindow(_ app: NSRunningApplication, window: AXUIElement) {
    app.activate()
    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, true as CFTypeRef)

    // Wait for the window to become focused before posting keyboard events.
    // AX activation is async; without this delay the keystroke may target the wrong window.
    usleep(300_000)
    let src = CGEventSource(stateID: .combinedSessionState)

    let keyDown = CGEvent(keyboardEventSource: src, virtualKey: kVKBacktick, keyDown: true)
    keyDown?.flags = .maskControl
    keyDown?.post(tap: .cghidEventTap)

    let keyUp = CGEvent(keyboardEventSource: src, virtualKey: kVKBacktick, keyDown: false)
    keyUp?.flags = .maskControl
    keyUp?.post(tap: .cghidEventTap)
}

// MARK: - Window Focus

func focusWindow(projectName: String) {
    let codeApps = findVSCodeApps()

    guard !codeApps.isEmpty else {
        fputs("No VSCode process found\n", stderr)
        exit(1)
    }

    // Primary match: window title contains project name
    if let (app, window) = findWindow(in: codeApps, matching: { $0.contains(projectName) }) {
        activateWindow(app, window: window)
        return
    }

    // Fallback: match the last two meaningful path segments (e.g. "GitHub/my-project")
    // against window titles. This handles cases where VSCode shows a parent directory prefix.
    let sessions = buildBaseSessionList()
    if let session = sessions.first(where: { $0.projectName == projectName }) {
        let segments = session.cwd.split(separator: "/").map(String.init).suffix(2)

        if let (app, window) = findWindow(in: codeApps, matching: { title in
            segments.contains { title.contains($0) }
        }) {
            activateWindow(app, window: window)
            return
        }
    }

    fputs("No matching window found: \(projectName)\n", stderr)
    exit(1)
}

// MARK: - Main

@main enum CCFocusMain {
    static func main() {
        let args = CommandLine.arguments

        guard args.count >= 2 else {
            fputs("Usage: cc-focus <project-name>\n", stderr)
            exit(1)
        }

        let projectName = args[1...].joined(separator: " ")
        focusWindow(projectName: projectName)
    }
}

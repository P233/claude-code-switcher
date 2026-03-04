import Cocoa
import Foundation

// MARK: - Data Models

struct CCStatus: Codable {
    let status: String
    let cwd: String
    let projectName: String?
    let sessionId: String?
    let timestamp: String?
}

struct IDELock: Codable {
    let pid: Int
    let workspaceFolders: [String]?
    let ideName: String?
    let transport: String?
}

struct Session {
    let projectName: String
    let cwd: String
    let status: String
    let sessionId: String
    let hasLock: Bool
}

// MARK: - File Reading

func readJSON<T: Codable>(_ path: String, as type: T.Type) -> T? {
    guard let data = FileManager.default.contents(atPath: path) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
}

func isProcessAlive(_ pid: Int) -> Bool {
    kill(Int32(pid), 0) == 0
}

func listFiles(in directory: String, withExtension ext: String) -> [String] {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(atPath: directory) else { return [] }
    return files
        .filter { $0.hasSuffix(".\(ext)") }
        .map { "\(directory)/\($0)" }
}

func buildSessionList() -> [Session] {
    let statusDir = "/tmp/cc-status"
    let ideLockDir = NSHomeDirectory() + "/.claude/ide"

    var sessions: [Session] = []
    var seenKeys = Set<String>()

    for path in listFiles(in: statusDir, withExtension: "json") {
        guard let s = readJSON(path, as: CCStatus.self) else { continue }
        let key = s.cwd + "|" + (s.sessionId ?? "")
        guard !seenKeys.contains(key) else { continue }
        seenKeys.insert(key)

        let name = s.projectName ?? URL(fileURLWithPath: s.cwd).lastPathComponent
        sessions.append(Session(
            projectName: name,
            cwd: s.cwd,
            status: s.status,
            sessionId: s.sessionId ?? "",
            hasLock: false
        ))
    }

    var locksByCwd: [String: IDELock] = [:]
    for path in listFiles(in: ideLockDir, withExtension: "lock") {
        guard let lock = readJSON(path, as: IDELock.self) else { continue }
        guard isProcessAlive(lock.pid) else { continue }
        if let ws = lock.workspaceFolders, let cwd = ws.first {
            locksByCwd[cwd] = lock
        }
    }

    sessions = sessions.map { s in
        Session(
            projectName: s.projectName,
            cwd: s.cwd,
            status: s.status,
            sessionId: s.sessionId,
            hasLock: locksByCwd[s.cwd] != nil
        )
    }

    let sessionCwds = Set(sessions.map { $0.cwd })
    for (cwd, _) in locksByCwd where !sessionCwds.contains(cwd) {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        sessions.append(Session(
            projectName: name,
            cwd: cwd,
            status: "not-init",
            sessionId: "",
            hasLock: true
        ))
    }

    return sessions
}

// MARK: - Window Focus

func focusWindow(projectName: String) {
    let workspace = NSWorkspace.shared
    let apps = workspace.runningApplications

    let codeApps = apps.filter { app in
        guard let name = app.localizedName else { return false }
        return name.contains("Code") || name == "Electron"
    }

    guard !codeApps.isEmpty else {
        fputs("No VSCode process found\n", stderr)
        exit(1)
    }

    // Primary match: window title contains project name
    for app in codeApps {
        let pid = app.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

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

            if title.contains(projectName) {
                app.activate()
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, true as CFTypeRef)

                usleep(300_000)
                let src = CGEventSource(stateID: .combinedSessionState)

                let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 50, keyDown: true)
                keyDown?.flags = .maskControl
                keyDown?.post(tap: .cghidEventTap)

                let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 50, keyDown: false)
                keyUp?.flags = .maskControl
                keyUp?.post(tap: .cghidEventTap)

                return
            }
        }
    }

    // Fallback: match path segments from cwd
    let sessions = buildSessionList()
    if let session = sessions.first(where: { $0.projectName == projectName }) {
        let segments = session.cwd.split(separator: "/").map(String.init).filter { $0.count > 2 }

        for app in codeApps {
            let pid = app.processIdentifier
            let appRef = AXUIElementCreateApplication(pid)

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

                for segment in segments.reversed() {
                    if title.contains(segment) {
                        app.activate()
                        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, true as CFTypeRef)
                        return
                    }
                }
            }
        }
    }

    fputs("No matching window found: \(projectName)\n", stderr)
    exit(1)
}

// MARK: - Main

let args = CommandLine.arguments

guard args.count >= 2 else {
    fputs("Usage: cc-focus <project-name>\n", stderr)
    exit(1)
}

let projectName = args[1...].joined(separator: " ")
focusWindow(projectName: projectName)

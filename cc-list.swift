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
    let runningTimestamp: String?
}

// MARK: - Status Icons

let statusIcons: [String: String] = [
    "running": "🟢",
    "idle": "🟡",
    "standby": "⚪",
]

// MARK: - File Reading

func readJSON<T: Codable>(_ path: String, as type: T.Type) -> T? {
    guard let data = FileManager.default.contents(atPath: path) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
}

func elapsedTime(since timestamp: String) -> String? {
    let formatter = ISO8601DateFormatter()
    guard let start = formatter.date(from: timestamp) else { return nil }
    let elapsed = Int(Date().timeIntervalSince(start))
    guard elapsed >= 0 else { return nil }
    if elapsed < 60 { return "\(elapsed)s" }
    let m = elapsed / 60, s = elapsed % 60
    if m < 60 { return "\(m)m \(s)s" }
    return "\(m / 60)h \(m % 60)m"
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

// MARK: - Build Session List

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
            runningTimestamp: s.status == "running" ? s.timestamp : nil
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

    // Only keep sessions whose cwd has a live IDE lock
    sessions = sessions.filter { locksByCwd[$0.cwd] != nil }

    let sessionCwds = Set(sessions.map { $0.cwd })
    for (cwd, _) in locksByCwd where !sessionCwds.contains(cwd) {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        sessions.append(Session(
            projectName: name,
            cwd: cwd,
            status: "standby",
            runningTimestamp: nil
        ))
    }

    sessions.sort { $0.projectName.localizedCaseInsensitiveCompare($1.projectName) == .orderedAscending }
    return sessions
}

// MARK: - Alfred JSON Output

func buildOutput(from sessions: [Session]) -> String {
    var items: [[String: Any]] = []

    for s in sessions {
        let icon = statusIcons[s.status] ?? "⚪"
        let runningLabel = s.runningTimestamp.flatMap(elapsedTime).map { "  \($0)" } ?? ""
        items.append([
            "title": "\(icon)  \(s.projectName)\(runningLabel)",
            "subtitle": "\(s.status) — \(s.cwd)",
            "arg": s.projectName,
            "match": "\(s.projectName) \(s.status) \(URL(fileURLWithPath: s.cwd).lastPathComponent)",
            "variables": [
                "cwd": s.cwd,
                "projectName": s.projectName,
            ],
        ])
    }

    if items.isEmpty {
        items.append([
            "title": "No active Claude Code sessions detected",
            "subtitle": "Make sure Claude Code is running and hooks are configured",
            "valid": false,
        ])
    }

    var result: [String: Any] = ["items": items]
    if sessions.contains(where: { $0.status == "running" }) {
        result["rerun"] = 1
    }

    guard let data = try? JSONSerialization.data(withJSONObject: result, options: []),
          let str = String(data: data, encoding: .utf8) else { return "{}" }
    return str
}

// MARK: - Main

print(buildOutput(from: buildSessionList()))

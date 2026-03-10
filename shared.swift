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

struct BaseSession {
    let projectName: String
    let cwd: String
    let status: String
    let timestamp: String?
}

// MARK: - File Utilities

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

/// Returns live IDE locks keyed by workspace cwd.
func loadIDELocks() -> [String: IDELock] {
    let ideLockDir = NSHomeDirectory() + "/.claude/ide"
    var locksByCwd: [String: IDELock] = [:]
    for path in listFiles(in: ideLockDir, withExtension: "lock") {
        guard let lock = readJSON(path, as: IDELock.self) else { continue }
        guard isProcessAlive(lock.pid) else { continue }
        if let ws = lock.workspaceFolders, let cwd = ws.first {
            locksByCwd[cwd] = lock
        }
    }
    return locksByCwd
}

// MARK: - Session Building

let statusDir = "/tmp/cc-status"

/// Reads status files and IDE locks, merges them into a unified session list.
/// Sessions without a live IDE lock are filtered out. IDE locks without a CC session become standby entries.
func buildBaseSessionList() -> [BaseSession] {
    let locksByCwd = loadIDELocks()

    var sessions: [BaseSession] = []
    var seenCwds = Set<String>()

    for path in listFiles(in: statusDir, withExtension: "json") {
        guard let s = readJSON(path, as: CCStatus.self) else { continue }
        guard !seenCwds.contains(s.cwd) else { continue }
        seenCwds.insert(s.cwd)

        guard locksByCwd[s.cwd] != nil else { continue }

        let name = s.projectName ?? URL(fileURLWithPath: s.cwd).lastPathComponent
        sessions.append(BaseSession(
            projectName: name,
            cwd: s.cwd,
            status: s.status,
            timestamp: s.status == "running" ? s.timestamp : nil
        ))
    }

    for (cwd, _) in locksByCwd where !seenCwds.contains(cwd) {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        sessions.append(BaseSession(
            projectName: name,
            cwd: cwd,
            status: "standby",
            timestamp: nil
        ))
    }

    sessions.sort { $0.projectName.localizedCaseInsensitiveCompare($1.projectName) == .orderedAscending }
    return sessions
}

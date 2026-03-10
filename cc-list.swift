import Foundation

// MARK: - Status Icons

let statusIcons: [String: String] = [
    "running": "🟢",
    "idle": "🟡",
    "standby": "⚪",
]

// MARK: - Elapsed Time

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

// MARK: - Alfred JSON Output

func buildOutput(from sessions: [BaseSession]) -> String {
    var items: [[String: Any]] = []

    for s in sessions {
        let icon = statusIcons[s.status] ?? "⚪"
        let runningLabel = s.timestamp.flatMap(elapsedTime).map { "  \($0)" } ?? ""
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

@main enum CCListMain {
    static func main() {
        print(buildOutput(from: buildBaseSessionList()))
    }
}

# Claude Code Switcher — Project Notes

## What This Is

Alfred workflow + two Swift CLI tools to view Claude Code session statuses and jump to the matching VSCode window. VSCode only — other IDEs untested.

## Architecture

```
CC hooks → status-writer.sh → /tmp/cc-status/*.json
                                        ↓
Alfred hotkey → cc-list → Alfred list → select → cc-focus <name> → AX API → focus window
```

Two data sources merged in `cc-list`:
- `/tmp/cc-status/*.json` — written by hooks; tracks session state and timestamps
- `~/.claude/ide/*.lock` — written by VSCode extension; tracks which workspace is open

## Key Design Decisions

**Why hooks instead of an API?** Claude Code doesn't expose an API to query session state. Hooks are the only available mechanism.

**No cache.** /tmp reads are cheap. Removing the cache keeps the code simple and makes status changes immediately visible.

**`rerun: 1` is conditional.** Only included in Alfred JSON output when at least one session is `running`. No polling when nothing is active.

**No `waiting` status.** `PermissionRequest` hook can detect when Claude is waiting for tool approval, but there is no hook event for permission approval/denial. After the user approves, the status would stay stuck on `waiting` instead of returning to `running` — only the next `UserPromptSubmit` or `Stop` would update it. This makes the status unreliable, so it's not tracked.

**`active` status removed.** `SessionStart` writes `idle` directly — "session just opened" and "waiting for input" are the same from the user's perspective.

**IDE lock gating.** Status files (`/tmp/cc-status/`) are only shown if their `cwd` has a live IDE lock. This automatically hides stale entries when VSCode windows are closed without a proper `SessionEnd` hook firing.

**No session ID display.** This tool is VSCode-focused; each project maps to one window. Session IDs only matter for multi-session-per-directory terminal usage, which isn't supported here.

## Session States

| Status | Hook | Meaning |
|--------|------|---------|
| `running` | `UserPromptSubmit` | Claude is processing |
| `idle` | `SessionStart`, `Stop` | Waiting for input |
| `standby` | — | IDE lock exists, no CC session |
| *(filtered)* | — | Status file exists but no live IDE lock |
| *(deleted)* | `SessionEnd` | File removed |

## Files

| File | Role |
|------|------|
| `shared.swift` | Shared data models, file utilities, and session-building logic |
| `cc-list.swift` | Reads status + lock files, outputs Alfred JSON |
| `cc-focus.swift` | Focuses VSCode window via Cocoa + AX API |
| `status-writer.sh` | Hook script — writes JSON to `/tmp/cc-status/` |
| `hooks-config.json` | Hook config reference for `~/.claude/settings.json` |
| `build.sh` | Compile both binaries with `swiftc` |
| `install.sh` | Full install: compile + hooks + Alfred workflow |
| `info.plist` | Alfred Workflow definition |

Compiled binaries (`cc-list`, `cc-focus`) and the packaged workflow (`Claude-Code-Switcher.alfredworkflow`) are gitignored — always built locally from source.

## Runtime Files

```
/tmp/cc-status/*.json          — status files (cleared on reboot)
~/.claude/ide/*.lock           — IDE locks (managed by CC)
~/.claude/hooks/status-writer.sh
~/.claude/settings.json
```

## When Modifying

- Compile with `./build.sh`, then repackage and reimport the Alfred Workflow via `install.sh`
- If changing the status JSON schema, update `CCStatus` in `shared.swift`
- If adding a new hook event, update `hooks-config.json` and `status-writer.sh` comment
- Keep `info.plist` Alfred readme section in sync with actual status icons/behavior

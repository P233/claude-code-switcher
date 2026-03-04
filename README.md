# Claude Code Switcher (Alfred + Swift)

View all Claude Code session statuses at a glance and jump to the corresponding VSCode window instantly.

Designed for VSCode. Other IDEs or terminal-only setups are not tested and may not work reliably.

Single compiled Swift binary — no Python/bash/jq dependencies, no persistent process, millisecond response.

## How It Works

Claude Code doesn't expose an API to query running session states. As a workaround, this tool uses Claude Code's lifecycle hooks to track state locally.

Claude Code fires lifecycle hooks as you work. Each hook calls `status-writer.sh`, which writes the current session state to `/tmp/cc-status/`. When Alfred triggers `cc-list`, it reads those files and displays the list instantly — no persistent background process. While a session is running, Alfred re-runs the script every second to keep the elapsed time live. Selecting a session calls `cc-focus`, which uses the macOS Accessibility API to find and raise the matching VSCode window.

```
CC hooks → status-writer.sh → /tmp/cc-status/
                                      ↓
Alfred hotkey → cc-list → Alfred list → select → cc-focus <name> → AX API → focus window
```

### Binaries

- `cc-list` — reads session state, outputs Alfred JSON. When a task is running, Alfred re-runs the script every second to keep the elapsed time live. Foundation only, fast startup.
- `cc-focus <name>` — focuses the matching VSCode window via Cocoa + Accessibility API.

## Requirements

- macOS
- Xcode Command Line Tools (`xcode-select --install`)
- Alfred 5 + Powerpack
- Claude Code
- Claude Code used inside VSCode

## Install

```bash
chmod +x install.sh
./install.sh
```

The installer will:
1. Compile `cc-list` and `cc-focus` from Swift source with `swiftc`
2. Install `status-writer.sh` to `~/.claude/hooks/`
3. Configure `~/.claude/settings.json` with the required hooks
4. Package and import the Alfred Workflow

### Manual Install

**Compile the binaries:**

```bash
chmod +x build.sh
./build.sh
```

**Install hooks:**

```bash
mkdir -p ~/.claude/hooks
cp status-writer.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/status-writer.sh
```

**Configure hooks:**

Merge the contents of `hooks-config.json` into `~/.claude/settings.json`.

If you already have hooks configured, merge the four events: `SessionStart`, `UserPromptSubmit`, `Stop`, `SessionEnd`.

**Package Alfred Workflow:**

```bash
zip -j Claude-Code-Switcher.alfredworkflow info.plist cc-list cc-focus
open Claude-Code-Switcher.alfredworkflow
```

## Usage

### Hotkey

Press **Cmd+`** to open the session list.

### Keyword

Type **cc** in Alfred.

### Session List

```
🟢  my-app  2m 34s              ← running, elapsed time shown
    running — /Users/you/projects/my-app

🟡  api-server                  ← idle, waiting for input
    idle — /Users/you/projects/api-server

⚪  old-project                  ← VSCode open, no CC session yet
    not-init — /Users/you/projects/old-project
```

Status icons:

| Icon | Status | Meaning |
|------|--------|---------|
| 🟢 | `running` | Claude is actively processing a prompt |
| 🟡 | `idle` | Session is open, waiting for input |
| ⚪ | `not-init` | VSCode IDE lock found, but no CC session started |

After selecting and pressing Enter:
1. The matching VSCode window is focused
2. `Ctrl+\`` is sent to open the integrated terminal panel

### Permissions

Window focusing requires Accessibility permission. macOS will prompt on first use, or add manually:

**System Settings → Privacy & Security → Accessibility → add Alfred**

## Customization

### Change Hotkey

Alfred Preferences → Workflows → Claude Code Switcher → double-click the Hotkey node.

### Disable Auto-Open Terminal

Edit the `focusWindow` function in `cc-focus.swift`, remove the key-send block (`usleep` through `keyUp`), then recompile.

### Use Binaries Without Alfred

```bash
# List all sessions (Alfred JSON format)
./cc-list

# Focus a specific project window
./cc-focus my-app
```

## Debugging

**Status files:**

```bash
ls -la /tmp/cc-status/
cat /tmp/cc-status/*.json | python3 -m json.tool
```

**IDE lock files:**

```bash
ls -la ~/.claude/ide/
cat ~/.claude/ide/*.lock | python3 -m json.tool
```

**Test list output:**

```bash
./cc-list | python3 -m json.tool
```

**Test window focus:**

```bash
./cc-focus my-app
```

## File Reference

```
cc-list.swift                       — Swift source: reads status + lock files, outputs Alfred JSON
cc-focus.swift                      — Swift source: focuses VSCode window via Cocoa + Accessibility API
build.sh                            — compile script
status-writer.sh                    — writes session status JSON on each CC lifecycle event
hooks-config.json                   — Claude Code hooks configuration reference
install.sh                          — one-step installer
info.plist                          — Alfred Workflow definition
```

After install:
```
~/.claude/hooks/status-writer.sh    — hook script (called by CC on each lifecycle event)
~/.claude/settings.json             — CC config with hooks registered
~/Library/.../workflows/.../
  ├── cc-list                       — compiled list binary
  ├── cc-focus                      — compiled focus binary
  └── info.plist                    — Workflow definition
/tmp/cc-status/*.json               — runtime status files (cleared on reboot)
~/.claude/ide/*.lock                — IDE lock files (managed by CC automatically)
```

## Known Limitations

- Window focus is at the VSCode window level; cannot target a specific terminal tab
- `/tmp/cc-status/` is cleared on macOS reboot
- If CC exits abnormally, `SessionEnd` may not fire, leaving stale status files in `/tmp/cc-status/`. These can be cleared manually with `rm /tmp/cc-status/*.json`
- IDE lock files are filtered by process liveness — stale locks from crashed sessions are automatically ignored
- Requires Xcode Command Line Tools to compile
- Requires Accessibility permission for window focus
- The hotkey in `info.plist` may need to be reassigned after import

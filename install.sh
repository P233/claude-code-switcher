#!/bin/bash
# Claude Code Switcher installer
# Compiles Swift tools + installs hooks + packages Alfred Workflow
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Claude Code Switcher Install ==="
echo ""

# 1. Compile Swift tools
echo "1) Compiling Swift tools..."
if ! command -v swiftc &>/dev/null; then
    echo -e "   ${RED}✗${NC} swiftc not found. Install Xcode Command Line Tools:"
    echo "   xcode-select --install"
    exit 1
fi

"$SCRIPT_DIR/build.sh"

# 2. Install hooks script
echo ""
echo "2) Installing hooks script..."
HOOKS_DIR="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/status-writer.sh" "$HOOKS_DIR/status-writer.sh"
chmod +x "$HOOKS_DIR/status-writer.sh"
echo -e "   ${GREEN}✓${NC} $HOOKS_DIR/status-writer.sh"

mkdir -p /tmp/cc-status
echo -e "   ${GREEN}✓${NC} /tmp/cc-status/"

# 3. Configure hooks
echo ""
echo "3) Configuring Claude Code hooks..."
SETTINGS_FILE="$HOME/.claude/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    if grep -q "status-writer.sh" "$SETTINGS_FILE" 2>/dev/null; then
        echo -e "   ${YELLOW}⚠${NC} Hooks already configured, skipping"
    else
        echo -e "   ${YELLOW}⚠${NC} Existing settings detected: $SETTINGS_FILE"
        echo ""
        echo "   Manually merge the following events into the hooks field of your settings.json:"
        echo "   SessionStart, UserPromptSubmit, Stop, SessionEnd"
        echo "   See hooks-config.json for reference."
    fi
else
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    cp "$SCRIPT_DIR/hooks-config.json" "$SETTINGS_FILE"
    echo -e "   ${GREEN}✓${NC} $SETTINGS_FILE"
fi

# 4. Package Alfred Workflow
echo ""
echo "4) Packaging Alfred Workflow..."

WORKFLOW_FILE="$SCRIPT_DIR/Claude-Code-Switcher.alfredworkflow"

zip -j "$WORKFLOW_FILE" \
    "$SCRIPT_DIR/info.plist" \
    "$SCRIPT_DIR/cc-list" \
    "$SCRIPT_DIR/cc-focus" >/dev/null 2>&1

echo -e "   ${GREEN}✓${NC} $WORKFLOW_FILE"

# 5. Install Alfred Workflow
echo ""
echo "5) Installing Alfred Workflow..."
read -p "   Open .alfredworkflow to import into Alfred now? [Y/n] " answer
answer=${answer:-Y}
if [[ "$answer" =~ ^[Yy]$ ]]; then
    open "$WORKFLOW_FILE"
    echo -e "   ${GREEN}✓${NC} Alfred import dialog opened"
else
    echo -e "   ${YELLOW}⚠${NC} Double-click $WORKFLOW_FILE to import manually later."
fi

# 6. Done
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Usage:"
echo "  Hotkey: Cmd+\` to open CC session list"
echo "  Keyword: type 'cc' in Alfred"
echo ""
echo "First-time notes:"
echo "  • If window switching doesn't work, check System Settings → Privacy & Security → Accessibility"
echo "    and make sure Alfred is authorized"
echo "  • If the hotkey doesn't work, double-click the Hotkey node in Alfred Preferences → Workflows"
echo "    to reassign it"
echo ""
echo "Test:"
echo "  1. Start a Claude Code session"
echo "  2. ls /tmp/cc-status/ to confirm status file exists"
echo "  3. Press Cmd+\` to test"

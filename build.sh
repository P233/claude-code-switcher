#!/bin/bash
# Compile cc-list and cc-focus Swift CLI tools
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED="$SCRIPT_DIR/shared.swift"

compile() {
    local name="$1" out="$2"
    shift 2
    echo "Compiling $(basename "$out")..."
    swiftc "$SHARED" "$SCRIPT_DIR/$name" -o "$out" -O "$@"
    chmod +x "$out"
    echo "  ✓ $(du -h "$out" | cut -f1)"
}

compile cc-list.swift  "$SCRIPT_DIR/cc-list"
compile cc-focus.swift "$SCRIPT_DIR/cc-focus" -framework Cocoa -framework ApplicationServices

echo "Done."

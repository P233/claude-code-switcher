#!/bin/bash
# Compile cc-list and cc-focus Swift CLI tools
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

compile() {
    local src="$1" out="$2" frameworks="${@:3}"
    echo "Compiling $(basename "$out")..."
    swiftc "$src" -o "$out" -O $frameworks
    chmod +x "$out"
    echo "  ✓ $(du -h "$out" | cut -f1)"
}

compile "$SCRIPT_DIR/cc-list.swift"  "$SCRIPT_DIR/cc-list"
compile "$SCRIPT_DIR/cc-focus.swift" "$SCRIPT_DIR/cc-focus" -framework Cocoa -framework ApplicationServices

echo "Done."

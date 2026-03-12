#!/bin/sh
# Headless simulation launcher — Linux/macOS
# Tries bundled luajit first, then system luajit, then lua5.4, then lua.
#
# Usage:
#   ./run_headless.sh [max_updates]
#
# Example — run 500 000 ticks with whatever Lua is available:
#   ./run_headless.sh 500000

SCRIPT="run_headless.lua"

# Bundled binaries (shipped alongside love/ executables)
BUNDLED_LUAJIT="./lua/luajit"
BUNDLED_LUA="./lua/lua5.4"

if   [ -x "$BUNDLED_LUAJIT" ];        then exec "$BUNDLED_LUAJIT" "$SCRIPT" "$@"
elif [ -x "$BUNDLED_LUA"    ];        then exec "$BUNDLED_LUA"    "$SCRIPT" "$@"
elif command -v luajit   >/dev/null;  then exec luajit            "$SCRIPT" "$@"
elif command -v lua5.4   >/dev/null;  then exec lua5.4            "$SCRIPT" "$@"
elif command -v lua      >/dev/null;  then exec lua               "$SCRIPT" "$@"
else
    echo "No Lua interpreter found."
    echo "Install luajit or lua5.4, or place a binary in ./lua/"
    exit 1
fi

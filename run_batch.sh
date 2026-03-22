#!/bin/sh
# Batch simulation launcher — Linux/macOS
# Runs run_batch.lua with whatever Lua interpreter is available.
#
# Usage:
#   ./run_batch.sh [batch_file.lua]

SCRIPT="run_batch.lua"

BUNDLED_LUAJIT="./lua/luajit"
BUNDLED_LUA="./lua/lua5.4"

if   [ -x "$BUNDLED_LUAJIT" ];       then exec "$BUNDLED_LUAJIT" "$SCRIPT" "$@"
elif [ -x "$BUNDLED_LUA"    ];       then exec "$BUNDLED_LUA"    "$SCRIPT" "$@"
elif command -v luajit  >/dev/null;  then exec luajit            "$SCRIPT" "$@"
elif command -v lua5.4  >/dev/null;  then exec lua5.4            "$SCRIPT" "$@"
elif command -v lua     >/dev/null;  then exec lua               "$SCRIPT" "$@"
else
    echo "No Lua interpreter found."
    echo "Install luajit or lua5.4, or place a binary in ./lua/"
    exit 1
fi

#!/bin/bash
# winshot.sh — compile-on-demand front end for winshot.c (grab an X window to PNG).
#
# This box has NO screenshot tool: no import(1), no xwd, no scrot, no ffmpeg,
# no PIL, no Tk Img.  xschem can export its own canvas (`xschem print png`) but
# nothing in the tree could photograph a Tk DIALOG, which is what most of the
# owed-ledger's `look` debts are actually about.  See the header of winshot.c.
#
# The binary is built into a cache outside the repo (nothing to gitignore, no
# src/Makefile.in edit, no ./configure re-run — see CLAUDE.md issue 0424 on why
# adding a file to src/ is not free).  It rebuilds whenever the .c is newer.
#
#   winshot.sh out.png -name "Results" -raise      # by WM_NAME substring
#   winshot.sh out.png -id 0x2400007               # by window id
#   winshot.sh out.png -root                       # whole screen
#   DISPLAY=:99 winshot.sh out.png -name xschem    # any display
#
# Exit codes come straight from winshot: 0 ok, 2 no such window, 3 X error,
# 4 write error, 1 usage, 5 build failure.
set -u
here=$(cd -- "$(dirname -- "$0")" && pwd)
cache="${XSCHEM_WINSHOT_CACHE:-$HOME/.cache/xschem-winshot}"
bin="$cache/winshot"
src="$here/winshot.c"

[ -f "$src" ] || { echo "winshot.sh: missing $src" >&2; exit 5; }
if [ ! -x "$bin" ] || [ "$src" -nt "$bin" ]; then
  mkdir -p "$cache" || exit 5
  if ! cc -O2 -Wall -o "$bin" "$src" -lX11 -lpng -lz 2>"$cache/build.log"; then
    echo "winshot.sh: build failed, see $cache/build.log" >&2
    sed -n '1,20p' "$cache/build.log" >&2
    exit 5
  fi
fi
exec "$bin" "$@"

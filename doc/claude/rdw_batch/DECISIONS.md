# RDW batch — decisions

The user handed over five items at 2026-09-05 and said they would be
unavailable for seven hours, with *"make reasonable assumptions ... and
proceed."* Everything below is therefore a **driver decision taken on the
user's behalf**, not a ruling they gave. Each one is filed as a `rule` debt in
`tests/headless/owed.sh` so they can overturn it; **a crew may not silently
change one**, and a crew that finds a decision wrong stops and says so in its
write-up.

Each entry names its cost and the alternative that was rejected.

---

**DD-1 — one cursor, and a new block clears it.** (R1)
The user asked for a cursor, singular. Clicking a second line moves it rather
than adding to it. When `rdw::push` prepends a new block the cursor is cleared,
because the line the user clicked is no longer at that index and a cursor that
silently slid onto a different row would make R2's Up/Down act on something the
user did not choose.
*Cost:* after a new dump the user must click again before Up/Down have a subject.
*Rejected:* keeping the cursor at the same screen row (it would point at
different data), and multi-select (nothing in the five items needs a range).

**DD-2 — the cursor shade is derived, never hard-coded.** (R1)
`rdw::palette` already answers for the light and dark themes, and every other
tag in the pane goes through `rdw::color`. A literal grey would be invisible in
one of the two.
*Cost:* one more role in the palette table and its fallback.
*Rejected:* a fixed `#d0d0d0`, which is the obvious thing and is wrong in dark.

**DD-3 — Up/Down act on the cursored row.** (R2)
R1's cursor is what gives the arrows a subject; that is why the user asked for
them together. With no cursor set, the buttons keep exactly today's behaviour,
so nothing that works now stops working.
*Cost:* the arrows do two different things depending on whether a row is
cursored, which must be visible in the status line.
*Rejected:* always acting on the first row (makes the cursor decorative).

**DD-4 — only lists 1 and 2 re-render the schematic.** (R2)
The user's own words: *"if applied to annotation params (1 key) or summary list
(2 key)."* The `3` list is "all available" and has no presence on the sheet, so
reordering it changes the window only.
*Cost:* none known.
*Rejected:* re-rendering on every edit (work the sheet cannot show).

**DD-5 — `Ctrl-C` writes CLIPBOARD explicitly, and a menu exists too.** (R3)
`-exportselection 1` publishes the X **PRIMARY** selection; `Ctrl-C` and a
paste into a document want **CLIPBOARD**. They are different selections and the
window currently only feeds one. A right-click Copy / Select All menu is added
alongside, so a keyboard binding that a window manager or X server eats can
never leave the user with no way to get the text out — which is the whole point
of the window.
*Cost:* one more menu.
*Rejected:* relying on Tk's default Text bindings, which is what does not work
today on the user's own server.

**DD-6 — raise, but do not activate.** (R4)
`raise_activate_toplevel` (`src/xschem.tcl:7019`) is reused for its body — it
carries issue 0054's WSLg idiom and issue 0843's `_remap_verify` recovery, and
re-deriving those would re-ship two known defects. Its **last line** is dropped:
`xschem activate_window` sets `_NET_ACTIVE_WINDOW`, which is activation, and the
user said *no need to focus*. Stealing focus while they are working on the
schematic would be worse than not raising at all.
*Cost:* on a strict EWMH window manager the raised window may not get the active
title-bar tint.
*Rejected:* calling the existing proc unchanged (takes focus).

**DD-7 — engineering notation must not blank anything.** (R5)
Values go through `op_annot::eng_or_blank`, the schematic's own proc, so the two
surfaces cannot disagree. But that proc returns **empty** for a non-finite
value, and the RDW's existing words for `nan`/`inf` (`rdw::_nonfinite_text`) and
for absent values must survive: blanking them would silently undo issue 1272,
which this branch has already paid for once. Non-numeric bodies — model-name
strings, `-` placeholders — pass through unchanged.
*Cost:* the formatter is a wrapper, not a substitution.
*Rejected:* `set v [op_annot::eng_or_blank $v]` at the call site, which is the
one-line version and loses every non-numeric value in the window.

**DD-8 — R3 is measured on the user's real X server.**
CLAUDE.md's three-server table: `$DISPLAY` is the VcXsrv/`HC-Consult` server the
user actually looks at, `:0` is WSLg's Xwayland, `:99` is Xvfb. Selection and
clipboard are precisely where servers differ, and the user named VcXsrv in the
report. A green Xvfb run is not evidence for this item.
*Cost:* one run that cannot be automated away, and a `look` debt.
*Rejected:* calling R3 done on `:99`.

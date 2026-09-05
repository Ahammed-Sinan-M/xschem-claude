# RDW batch — the Results Display Window becomes usable

Five items from the user, 2026-09-05. They are **independent** except that R2
depends on R1's cursor for its subject, so R1 lands first and R2 second; R3, R4
and R5 may run in any order.

The window is `src/rdw.tcl` (2738 lines, namespace `rdw::`). Its text pane is
`.rdw.p.t`, built in `rdw::build` (`src/rdw.tcl:1050`), `-wrap word`,
`TkFixedFont`, with tags `hdr` / `dim` / `dev` / `note` already configured from
`rdw::palette`. The button column is `.rdw.b.<id>` for
`{up down delete add save}`; `rdw::button` is the single command sink and
`rdw::button_state` is the greying table.

---

## R1 — a line cursor (issue 1337)

**The user's words:** *"clicking on any line makes the entire line a shade
darker (noticeably)."*

Clicking anywhere in the text pane puts a cursor on **that whole display line**,
drawn a noticeably darker shade of the pane's own background. One cursor at a
time. It is the subject R2's Up/Down act on.

* New tag `cursor`, configured from `rdw::palette` like the other four — it must
  work in both the light and dark palettes, so derive the shade from the pane
  background rather than hard-coding a colour. `rdw::color` is the accessor and
  `rdw::_color_fallback` is what answers when the theme has no opinion.
* The tag spans the whole line including trailing whitespace (`lineend +1c`, or
  `-background` on a tag with `-lmargin`/full-width behaviour — measure which
  actually paints the full width in this Tk).
* The pane is `-state disabled`; a click must still set the cursor. Bind on
  `<Button-1>` and compute the line from `@%x,%y`.
* **It must not fight the text selection** (R3's subject). A cursor tag and a
  `sel` tag can coexist; check the tag priority so `sel` still shows.
* `rdw::push` prepends a new block — the cursor must not silently end up on a
  different row than the user clicked. Decide and pin: a new block **clears**
  the cursor.

## R2 — Up/Down move the row, and the schematic follows (issue 1338)

**The user's words:** *"Promote/demote using Up/Down arrow should be reflected
in the Results Display Window as well as the schematic annotation - if applied
to annotation params (1 key) or summary list (2 key)."*

Two halves, and the second is the one that is missing today:

1. **In the window.** The cursored row (R1) moves up or down in the displayed
   block, so the user sees the reorder they just asked for without re-pressing
   1/2/3.
2. **On the schematic.** When the edited list is the **annotation** list (the
   one key `1` dumps) or the **summary** list (key `2`), the schematic's
   annotation is re-rendered so the new order is visible there too. The store's
   `apply` is the existing seam; find what `6` / `Ctrl-6` call to redraw and
   call the same thing. Do **not** invent a second redraw path.

The third list (key `3`, "all available") has no schematic presence, so
reordering it changes the window only.

⚠ `rdw::_apply_now` currently swallows an `apply` failure while the status line
reports success — **issue 1330, filed not fixed.** R2 is the first item that
makes that channel load-bearing. Either fix 1330 as part of this item or say
loudly in the write-up that you did not.

## R3 — select and copy (issue 1339)

**The user's words:** *"Select and then press CTRL-C doesn't work. (Using VcXsrv
for now). Double-click to start selection and then extend selection with
press-and-drag seemed to work once, but not reliably. It's only worked one
time."*

The whole point of the window is pasting into design-review documents, so this
is the item that decides whether the feature is usable at all.

* The pane already sets `-exportselection [rdw::_exportsel]` (returns 1).
  Exporting to **PRIMARY** is not the same as putting text on **CLIPBOARD**, and
  `Ctrl-C` wants CLIPBOARD. Bind `<Control-c>` (and `<Control-Insert>`,
  and `<<Copy>>`) to a proc that reads `sel.first`/`sel.last` and calls
  `clipboard clear` + `clipboard append`.
* A `-state disabled` text widget still supports selection, but **some default
  Text bindings are class-level and can be shadowed** by the toplevel binding
  added for Escape (`src/rdw.tcl:1080`) and by `rdw::_focus_handback`
  (`:1060`) — issue 1308's focus rule. Check whether the focus handback is what
  makes double-click-then-drag unreliable: a widget that loses focus mid-drag
  loses the drag.
* **Measure on the user's real X server**, not only Xvfb: `$DISPLAY` is the
  VcXsrv/`HC-Consult` server (see CLAUDE.md's three-server table), and
  `AUDIT_DISPLAY=:0` is Xwayland, which is **not** it. Selection and clipboard
  are exactly the area where the servers differ.
* Add a **Copy** affordance that does not depend on the keyboard working —
  the user should never be stuck. A right-click menu with Copy / Select All is
  the cheapest.

## R4 — raise the window when something is sent to it (issue 1340)

**The user's words:** *"When user sends info to the Results Display Window
(RDW), the RDW needs to be raised (no need to focus, just raise), just as the
Library Manager is raised when one does Ctrl-Alt-S."*

`rdw::push` is the single door every dump goes through — raise from there.

⚠ **Reuse `raise_activate_toplevel` (`src/xschem.tcl:7019`), do not write a new
raise.** It carries issue 0054's WSLg idiom (a plain `raise` is an inert no-op
on that WM once a window is mapped, so it is `wm withdraw` + `wm deiconify`),
issue 0843's deferred `_remap_verify` recovery (a dropped re-map used to lose
the window outright), and a list of dead ends that must not come back
(`-topmost` toggle, `wm iconify`, a user-set flag).

**But not its last line.** It ends with `xschem activate_window`, which sets
`_NET_ACTIVE_WINDOW` — that is activation, and the user said *no need to focus*.
Taking focus while they are working on the schematic would be worse than not
raising. Split the proc, or add an argument; do not copy the body.

## R5 — engineering notation (issue 1341)

**The user's words:** *"Display of parameters in the RDW should be using
engineering notation - just like annotation on the schematic."*

`rdw::_value_text` (`src/rdw.tcl:419`) prints the raw string today.
`op_annot::eng_or_blank` (`src/op_annot.tcl:1266`) is what the schematic uses —
it is `to_eng` with a non-finite guard.

* Use **the same proc**, so the window and the sheet cannot disagree. That is
  the whole content of "just like annotation on the schematic".
* `eng_or_blank` returns **empty** for a non-finite value. The RDW already has
  words for that case (`rdw::_nonfinite_text`, `rdw::_absent_line`) and they
  must keep working — an empty string where `nan` used to print would be a
  silent regression of issue 1272's whole point.
* Non-numeric values are real and frequent (model-name strings, `-`
  placeholders). They must pass through **unchanged**, not become blank.
* `(no value reported)` stays as it is.

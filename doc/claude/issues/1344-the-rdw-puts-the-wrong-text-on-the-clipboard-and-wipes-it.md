# 1344 — the Results Display Window puts the WRONG text on the clipboard, and wipes it

*Found by item R3's adversary (verify #5 of run `wf_2a267b11-e28`,
`doc/claude/rdw_batch/ADVERSARY_FINDINGS.md`), which **REFUTED** R3 while the
suites were green — window 134, keys 71, store 130, control 485.
Branch `fluid-editing`. Filed and fixed 2026-09-05, on top of `774f78af`.
**FIXED.**
The mechanisms item R3 (issue 1339) added are right and none of them is
reverted here; what was wrong is that two ordinary gestures in the same window
reached the clipboard through guards that could not fire.*

---

## The four defects, each driven before the fix

All four measured on this binary, twice: on `:99` (Xvfb + openbox) and on the
user's own X server, `$DISPLAY` = `172.20.160.1:0`, vendor `HC-Consult` — the
VcXsrv the batch's original report came from (ruling **DD-8**). Byte-identical
on both. Repro: `scratchpad/P1/p1_probe.tcl`, built from the adversary's
`probe_r3b.tcl` / `probe_r3c.tcl`.

### (a) The empty window wipes the clipboard

`Tools > Results Display Window` with no dumps, then right-click → Select All →
Copy. Three clicks, no simulation — the first thing a new user does.

A Tk text widget always holds one mandatory trailing newline, so on an **empty**
pane `tag add sel 1.0 end` is the two-element range `{1.0 2.0}` over a
character the user never put there. `rdw::select_all`'s `llength $r < 2` guard
therefore never fired, and `rdw::copy`'s `$txt eq {}` could not fire either
because that character is a newline.

```
PROBE A_clip_before      -> {MY-IMPORTANT-DOCUMENT-TEXT}
PROBE A_selrange         -> {1.0 2.0}
PROBE A_status_selectall -> {Selected the whole window, 1 line. ...}
PROBE A_status_copy      -> {Copied 2 lines, 1 characters, to the clipboard.}
PROBE A_clip_after       -> {<NL>}
PROBE A_VERDICT          -> {CLIPBOARD-DESTROYED}
```

Three false sentences and a destroyed clipboard. Pre-R3 the same session left
the clipboard alone, so this was **new harm from R3's own new code**.

### (b) Ctrl-C copies the pane instead of the selection, in this window's own status line

`.rdw.s.msg` is a readonly `entry` with `-exportselection 1`; a real drag
selects in it (driven with `ButtonPress-1` / `B1-Motion` / `ButtonRelease-1`),
and it is where item B5 writes the settings-file path — the single most
copy-worthy string in the window. Selecting there takes PRIMARY off the pane.
`rdw::_selection_changed` tested only `$own eq {.rdw.p.t}`, so a **local widget
of the same toplevel** was scored a foreign theft, the stale mirror was kept,
and the chord — which is on the `.rdw` bindtag that entry carries — copied the
pane.

```
PROBE B_primary     -> {/home/analog/.xschem/op_param_lists.tcl}
PROBE B_mirror      -> {1.0 1.5}
PROBE B_clip_after  -> {MCU:/}
PROBE B_VERDICT     -> {COPIED-THE-PANE-NOT-THE-SELECTION}
```

### (c) …and the same chord destroys the text being copied

`rdw::copy`'s no-selection branch calls `rdw::status`, which writes
`::rdw::statusmsg` — the `-textvariable` of the very entry holding the live
selection.

```
PROBE C_status_after -> {Copied 1 line, 5 characters, to the clipboard.}
PROBE C_VERDICT      -> {THE-COPIED-TEXT-WAS-DESTROYED}
```

The path vanished under the user's own selection.

### (d) The two counts disagree about one and the same content

`rdw::select_all` counted the **line number** of `end - 1c`; `rdw::copy`
counted the elements of `split $txt \n`. Both were wrong and they were wrong by
different amounts.

```
PROBE D_status_selectall -> {Selected the whole window, 7 lines. ...}
PROBE D_status_copy      -> {Copied 8 lines, 170 characters, to the clipboard.}
PROBE D_VERDICT          -> {COUNTS-DISAGREE}
```

The extra line in the copy is the widget's own mandatory trailing newline
riding along on to the clipboard.

### (e) A fifth face, found by the new row rather than by the report

Row CP13's part 2 (a drag covering nothing but a blank line) failed **after**
the whitespace guard landed. The pane's bindtag chain is
`.rdw.p.t Text .rdw all`, so Tk's own `bind Text <<Copy>>` runs **before** the
toplevel chord R3 added: while the pane holds the keyboard, `tk_textCopy` is a
second door on to the clipboard obeying none of `rdw::copy`'s guards. Measured:
a blank-line selection reached the clipboard through it and the refusal
`rdw::copy` then printed was true of everything except what had already
happened.

---

## The fix

`src/rdw.tcl` only. Nothing R3 built is reverted.

* **`rdw::_worth_copying`** (new, pure) — the guard is *"is there anything
  worth copying"*, not *"is the string empty"*. `$txt eq {}` was dead for every
  span this window can produce; the reachable class is a **whitespace-only**
  span, of which the empty window is one instance and a block's own trailing
  separator line is another.
* **`rdw::_copy_lines`** (new, pure) — one counter, and both sentences count
  the same string with it. A trailing newline **ends** the last line rather
  than starting an empty new one, because that is the shape the paste has.
* **`rdw::_in_window`** (new, pure) — a widget of this toplevel is not a
  foreign thief. `rdw::_selection_changed` now drops the mirror for any owner
  inside `.rdw`, and keeps it only for a genuinely foreign one (which is still
  what row CP3 drives).
* **`rdw::_sibling_selection`** (new) — the selection standing in some other
  widget of this window, `{widget text}`. `rdw::copy` consults it **between**
  the pane's live `sel` and the mirror: a mirror is not evidence about a
  selection that is standing somewhere else right now. `rdw::_selection_span`
  refuses its mirror leg outright while a sibling holds the selection, which
  closes the case `_selection_changed` cannot hear (after a theft the pane's
  `sel` is already empty, so a later drag elsewhere fires no `<<Selection>>`).
* **`rdw::_copy_report`** (new) — the copy says what it did **unless the status
  line is the thing being copied**. Writing `::rdw::statusmsg` replaces that
  entry's contents and with them the user's live selection; a receipt is worth
  less than the text it is a receipt for, and the still-standing highlight is
  the receipt. Refusals are not routed through it and always speak.
* **`rdw::select_all`** tags to `end - 1c`, never a bare `end`, and refuses
  through `_worth_copying`.
* **`rdw::build`** binds `<<Copy>>` / `<Control-Key-c>` / `<Control-Key-Insert>`
  on **`.rdw.p.t` itself**, ending in `break`. The widget tag runs first, so
  that stops both `bind Text <<Copy>>` and the toplevel binding and exactly one
  copy runs — `rdw::copy`'s. Breaking *this* class binding costs nothing;
  `<Button-1>`'s, which sets the drag anchor, is still deliberately not broken.

## A driver decision, filed as a rule debt

`1344_copy_from_the_status_line_is_silent` — when the text being copied **is**
the status line, the window says nothing and leaves the line alone. The
alternative (report the copy) destroys both the user's selection and the only
copy of the path on screen. The user can overturn it.

## The rows that would have caught each

* `tests/headless/test_rdw_keys_1245.tcl` — **CP13** (a copy of nothing must
  never touch the clipboard: the empty window through the real right-click
  menu, plus a blank-line span on a populated pane), **CP14** (the selection in
  the window's own status line — b and c, with the two last legs fencing the
  fix so a sibling cannot hijack an ordinary pane copy), **CP15** (the two
  sentences agree, and agree with the paste's real shape). Floor 71 → 74.
  All three **RED on `git show HEAD:src/rdw.tcl`**, restored by `cp` with
  `md5sum` verified:

  ```
  RESULT: 3 FAILED (71 passed)
  FAIL: CP13 -> {1 1 {1.0 2.0} {<NL>} ...
  FAIL: CP14 -> {1 1 2 0 1 0 1 1} (exp {1 1 0 1 0 1 1 1})
  FAIL: CP15 -> {1 0 1 0 0}       (exp {1 1 1 1 1})
  ```

* `tests/headless/test_rdw_window_1245.tcl` — section **CY**: CY1
  (`_worth_copying`), CY2 (`_copy_lines`), CY3 (`_in_window`), CY4 (structural,
  the call sites and the pane binding). Floor 127 → 131. Every behavioural row
  above is behind the keys suite's `have_tk` guard, so a machine with no
  display runs none of them; these four are pure and run on **both** arms.
  All four RED on HEAD (`4 FAILED (134 passed)`).

## Suites

| suite | arm | before | after |
|---|---|---|---|
| `test_rdw_window_1245` | `--nogui` | ALL PASS (134) | **ALL PASS (138)** |
| `test_rdw_keys_1245` | `:99` | ALL PASS (71) | **ALL PASS (74)**, 3 runs |
| `test_op_param_store_1245` | `--nogui` | ALL PASS (130) | **ALL PASS (130)** |
| `test_op_annot` (control) | `--nogui` | ALL PASS (485) | **ALL PASS (485)** |
| `test_rdw_keys_1245` | `$DISPLAY` (VcXsrv) | — | 7 FAILED (67 passed) |
| `test_rdw_keys_1245` | `:0` (Xwayland) | 13 FAILED (61) | 10–11 FAILED (63–64) |

The `$DISPLAY` reds are **SD2 + SD3b** (issue **1332**, the `after 100` arming
flake, which the adversary saw fire on 2 of 2 runs on this server) and
**RA1..RA5** (issue **1343**, item R4's raise, filed NOT FIXED and proved
pre-existing there). **All fifteen CP rows pass on that server, the three new
ones included** — which is ruling DD-8 paid for this repair.

The `:0` reds are the same RA1..RA6 plus F1 / V3 / V7 / D1, all of them present
**byte-identically on `git show HEAD:src/rdw.tcl`** (that run's 13 = these 10
plus the three new rows correctly red). **F3 is a flake there** — three runs of
the fixed tree gave 11 / 10 / 11, F3 red in two of them and green in the other,
and it is green on `:99` and on `$DISPLAY`. All fifteen CP rows pass on `:0`
too, so the copy behaves the same on **all three X servers on this machine**;
the suite's own `:0` debt stays open for the ten reds that are not this
repair's.

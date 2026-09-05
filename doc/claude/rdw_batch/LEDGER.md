# RDW batch — ledger

Baseline taken 2026-09-05 at `a5e15dda`, every suite asserted to have printed a
RESULT line:

| suite | baseline | how |
|---|---|---|
| `test_rdw_window_1245` | ALL PASS (109) | `--nogui` |
| `test_rdw_keys_1245` | ALL PASS (41) | `:99` |
| `test_op_param_store_1245` | ALL PASS (130) | `--nogui` |
| `test_annot_declutter_1244` | ALL PASS (134) | `:99` |
| `test_op_annot` *(control)* | ALL PASS (485) | `--nogui` |
| `test_ase_core` | **1 red** (C11) | the `untitled~` phantom, issue 0609 |
| `test_op_dump_altshow` | **1 red** (H1) | the same phantom |

**Acceptance is a name+status diff, never a count.** The two reds above are one
pre-existing environmental cause and are not to be made green by deleting the
user's files.

## Items

| item | issue | subject | state |
|---|---|---|---|
| R1 | 1337 | the line cursor | **DONE** 2026-09-05 |
| R2 | 1338 | Up/Down move the row and the sheet follows | **DONE** 2026-09-05 |
| R4 | 1340 | raise the window when something is sent to it | **DONE** 2026-09-05 |
| R5 | 1341 | engineering notation | **DONE** 2026-09-05 |
| R3 | 1339 | select and copy | not started |

Order is deliberate: R2 needs R1's cursor for its subject; R3 is last because it
is the only one that cannot be finished without a run on the user's real X
server (DD-8).

## Rows

<!-- crews append here, one row per item -->

### R1 — issue 1337, the line cursor — DONE 2026-09-05

**What the user can now do:** click any line in the Results Display Window and
that whole line shades a step darker, to the right edge. It is the row Delete /
Add / Up / Down already acted on — R1 did not mint a second cursor, it made the
existing one visible — so item R2 has a subject the user can see.

**Files:** `src/rdw.tcl` (the only file under `src/`),
`tests/headless/test_rdw_window_1245.tcl` (section CU + CU16 + CU17, floor 109 → 116),
`tests/headless/test_rdw_keys_1245.tcl` (section CU, floor 41 → 51),
`doc/claude/issues/1337-the-rdw-target-row-is-invisible.md`,
`doc/claude/issues/NUMBERING.md`.

**Name+status diff, taken against a `git worktree` at `077bdfe4` carrying the
same test files** (so the baseline ran the same rows, not fewer):

| suite | how | before | after | rows that moved |
|---|---|---|---|---|
| `test_rdw_window_1245` | `--nogui` | 7 FAILED (108) | **ALL PASS (116)** | CU1 CU2 CU3 CU4 CU5 CU16 FAIL→ok; M1 FAIL→ok *(worktree artifact: no generated `src/Makefile` there; `grep -c rdw.tcl src/Makefile` = 2 in the real tree)*; CU17 added after that diff |
| `test_rdw_window_1245` | `:99` | — | **ALL PASS (128)** | the display arm's 121 pre-existing rows unmoved |
| `test_rdw_keys_1245` | `:99` | 9 FAILED (42) | **ALL PASS (51)** | CU6…CU14 FAIL→ok; CU15 was already green |
| `test_op_param_store_1245` | `--nogui` | ALL PASS (130) | **ALL PASS (130)** | none |
| `test_op_annot` *(control)* | `--nogui` | ALL PASS (485) | **ALL PASS (485)** | none |
| `test_annot_declutter_1244` | `:99` | ALL PASS (134) | **ALL PASS (134)** | none |

Every suite printed a RESULT line; no cell above is an empty grep. The keys
suite was run three times consecutively (51/51/51) — no issue-1332 flake seen.

**Two rows the RED pass did not write, added by the implementing pass** for the
inputs its five do not feed: **CU16**, a theme answering a Tk colour *name*
rather than hex (the `--nogui` arm cannot read one at all and must fall back
rather than raise or answer `black`); and **CU17**, the stale-target sweep on
the arm with **no Tk**. CU17 is the sharper of the two: `rdw::render_pane`
returns early without a display, so moving the sweep one line lower reds CU17
alone while the whole `:99` keys suite — CU14 included — stays **ALL PASS
(51)**. Measured, as a sabotage on a copy, restore verified by `md5sum`.

**Decisions relied on:** DD-1 (one cursor; `rdw::push` clears it) and DD-2 (the
shade is derived, never hard-coded) — both honoured as written, neither found
wrong. `rdw::keep_latest` also clears, and a click on empty space does not: DD-1
is silent on both, so they are on **rule debt 1337** with the new button
sentence.

**Also fixed, by construction: issue 1324.** `rdw::_target_line` no longer reads
the pane's `insert` mark, so the widget and `::rdw::targetrow` cannot disagree —
measured 0/0 where 1324 measured 9/3 — and the pane now shows which row is
targeted, which was 1324's own recommended fix.

**Not fixed, said loudly:** issue **1330** (`rdw::_apply_now` swallows an
`apply` failure) is untouched; it becomes load-bearing at R2, not here. Issue
**1331** likewise untouched.

**Look debt:** `the_RDW_line_cursor_shade`, updated in place (not re-filed) with
the measured shades and seven things to judge. **Suites green, please look** —
a shade of grey is not something a count can accept.

---

### R2 — issue 1338, Up/Down move the row and the sheet follows — DONE 2026-09-05

**What the user can now do:** click a parameter row in the Results Display
Window, press **Up** or **Down**, and the row moves *in the window* as well as
on the schematic — and the cursor follows the row, so a second press moves the
same parameter again instead of whatever slid under the old line number.

**⚠ PLAN.md's premise is half wrong and the write-up says so.** PLAN.md called
the SCHEMATIC half "the one that is missing today" and told the implementer to
"find what `6` / `Ctrl-6` call to redraw and call the same thing". Measured at
HEAD `27122ca4`: the sheet ALREADY followed — `effective` moves, `shown` is
rewritten for both type tokens, `op_annot::text M1` answers in the new order and
`xschem get annot_overlay_flushes` goes **+1**. What was missing was the
**window**. And `xschem annotate_op` (what `6` calls) **RELOADS THE RAW**
(`src/op_annot.tcl:1570,1591`), so calling it would destroy a 1-point op — it is
the wrong seam, and there was no second redraw path to add.

**Files:** `src/rdw.tcl` (the only file under `src/`),
`tests/headless/test_rdw_window_1245.tcl` (section RE, floor 116 → 124, plus
`b5_lists_reset`), `tests/headless/test_rdw_keys_1245.tcl` (section RD, floor
51 → 53), `tests/headless/test_op_param_store_1245.tcl` (row BE1's driving
lines), `doc/claude/issues/1338-updown-move-the-store-but-not-the-window.md`,
`doc/claude/issues/NUMBERING.md`.

**Name+status diff** (RED state = this tree with the two test files and `src/`
untouched, re-measured here, not taken on trust):

| suite | how | RED | after | rows that moved |
|---|---|---|---|---|
| `test_rdw_window_1245` | `--nogui` | 5 FAILED (119) | **ALL PASS (124)** | RE1 RE2 RE4 RE5 RE6 FAIL→ok. RE0 RE3 RE7 green throughout. None of the 116 pre-existing rows moved status. |
| `test_rdw_window_1245` | `:99` | 5 FAILED (131) | **ALL PASS (136)** | the same five |
| `test_rdw_keys_1245` | `:99` | 1 FAILED (52) | **ALL PASS (53)** | RD1 FAIL→ok; RD2 green throughout |
| `test_op_param_store_1245` | `--nogui` | ALL PASS (130) | **ALL PASS (130)** | none *(BE1 went red mid-change and is explained below)* |
| `test_op_annot` *(control)* | `--nogui` | ALL PASS (485) | **ALL PASS (485)** | none |
| T1 `tclsh run_regression.tcl` | solo | — | **0 counted failures** | baseline is zero and it is at zero |

Every suite printed a RESULT line; no cell is an empty grep. All five suites run
twice, identical; no issue-1332 flake seen.

**The implementation, in one paragraph.** The pane's row order is NOT the list's
row order — `rdw::format_answer` emits `devices` pairs, then `nonfinite`, then
`absent` — so the obvious "swap the two adjacent display lines" is wrong and row
RE1 reds it. A block is **re-slotted**: `rdw::_reslot_block` re-fills the rows
the list DECLARES, in the list's order, into the slots those declared rows
already occupied, one maximal run of parameter rows at a time (that run IS one
primitive, which is what stops a value crossing a `  <rawdev>` sub-header and
landing under a device that never published it). `rdw::_reorder_shown` does that
to every block whose subject resolves to the edited class and answers the pane
line the cursored row moved to; `rdw::button`'s up/down arm re-points the cursor
**before** `render_pane`, because `render_pane` paints the shading on its way
out.

**Issue 1330 is FIXED here, not deferred.** `rdw::_apply_now` was three bare
`catch`es and a bare `return {}`; it now answers `{}` on success and a sentence
on failure — a raise quoted, a `_say` read as the store's own worded report —
and **both** `rdw::button` call sites (up/down and delete/add) append it.
Measured: an ordinary accepted press adds nothing to `said` across both applies,
so no existing success sentence moved.

**Two test fixtures were stale, and the staleness IS the feature working.**
Neither row's assertion changed; both are per-row RESET helpers that reset the
store and not the pane, which was sufficient only while an accepted reorder left
`::rdw::blocks` byte-identical.

* `b5_lists_reset` (window suite) now rebuilds the blocks. Without it BT8's Up
  moved `gm` to line 9 and **nine** later rows (BT10 BT13 BT14 BT16 BT17 BT21
  BT25 BT26 BT27) edited the wrong parameter. This is issue **1312**'s own
  defect one layer out — that paragraph is already in the proc, about a
  descriptor an earlier row wrote — and a store reset with no pane reset also
  leaves the two DISAGREEING, which is the state R2 exists to prevent. Section
  RE's `re_reset` was written this way from the start.
* Row **BE1** (store suite) re-`set_row 11`'d before its second Up press,
  because until now `gds` stayed on line 11. The cursor follows the ROW now, so
  the second press landed on `gm` and produced `{ids gm gds}` — the row's own
  expectation is what caught it. It is cursored once and pressed twice now,
  which is the user's actual gesture.

**Decisions relied on:** DD-3 (Up/Down act on R1's cursored row) and DD-4 (only
lists 1 and 2 re-render the schematic) — both honoured as written, neither found
wrong. DD-4 needed no new gate: list 3 is refused before any of this.

**The E question, answered and overrulable:** neither DD-3 nor DD-4 says whether
an OLDER block of the edited class follows. It does, because the store is
class-wide and the alternative shows one class list in two orders at once. Rule
debt `1338_R2_every_block_of_the_class_follows` (`--eyes`), now carrying a
`read:` path to the new issue file. Overruling deletes row RE5 and nothing else.

**Still not fixed, said loudly:** issue **1331** (the narrow arm's refusal for a
symbol path containing a space) is untouched — it is not on R2's path.

**Look debt:** `1338 R2: the row moves under your eyes`. **Suites green, please
look** — a row moving and a shade landing on it is not something a count can
accept.

---

### R4 — issue 1340, raise the window when something is sent to it — DONE 2026-09-05

**What the user can now do:** send a dump to the Results Display Window while it
is behind the schematic — key `1`, `2`, `3` or a pick-mode click — and the window
comes to the front by itself, the way the Library Manager does on Ctrl-Alt-S.
The keyboard stays on the canvas, so bare `1`/`2`/`3`/`4` and the command mode's
Escape keep working without clicking back first.

**Files:** `src/rdw.tcl`, `src/xschem.tcl` (the two under `src/`),
`tests/headless/test_rdw_keys_1245.tcl` (section RA, `:99`, floor 53 → 59),
`tests/headless/test_rdw_window_1245.tcl` (section RH + RH3, both arms, floor 124 → 127),
`doc/claude/issues/1340-the-rdw-does-not-raise-when-something-is-sent-to-it.md`,
`doc/claude/issues/NUMBERING.md`.

⚠ **`src/xschem.tcl` is not on R4's PLAN.md file list, and the edit is
unavoidable.** DD-6 says to reuse `raise_activate_toplevel`'s body and drop only
its last line, *by splitting the proc or adding an argument, never by copying the
body* — and that proc lives there. Nothing else in `src/xschem.tcl` was touched.

**Name+status diff, every suite asserted to have printed a RESULT line.** The
baseline was RE-MEASURED, not taken from this file's header: the header's 109 and
41 are stale, because R1 and R2 landed after it was written.

| suite | how | before | after | rows that moved |
|---|---|---|---|---|
| `test_rdw_keys_1245` | `:99` | 4 FAILED (55) | **ALL PASS (59)** | RA1 RA2 RA3 RA4 FAIL→ok; RA5 RA6 already green; the 53 pre-existing rows unmoved |
| `test_rdw_window_1245` | `--nogui` | ALL PASS (126) | **ALL PASS (127)** | RH3 added by the implementing pass |
| `test_rdw_window_1245` | `:99` | ALL PASS (138) | **ALL PASS (139)** | RH3 added |
| `test_op_param_store_1245` | `--nogui` | ALL PASS (130) | **ALL PASS (130)** | none |
| `test_op_annot` *(control)* | `--nogui` | ALL PASS (485) | **ALL PASS (485)** | none |

Because the split touches a proc fourteen other windows call, every suite that
names `raise_activate_toplevel` or `_remap_verify` was run too, on `:99`:
`test_remap_verify` **ALL PASS**, `test_ase_plot` **ALL PASS (150)**,
`test_wave_sigbrowser_i11` **ALL PASS (74)**, `i12` **ALL PASS (126)**,
`test_wave_viewer_geometry` **ALL PASS**. `test_ase_window` is **1 FAILED (227)**
before *and* after — row W7, *"simulator produced output before Stop"*, measured
red on the HEAD sources restored into the tree by `git show HEAD:… >` with the
restore verified by `md5sum`. Unrelated to the raise.

The keys suite was run **five** times after the fix, ALL PASS 59 each time —
issue 1332's SD flake did not appear.

**T1 is at ZERO, run solo** (issue 0990) after the change: `tclsh
run_regression.tcl`, exit 0, **57 cases all `Total num fail: 0`**, zero lines
matching `FAIL$` / `GOLD?` / `RESULT?` / `^FATAL`, and zero `exit 127` or
`couldn't execute "xschem"`. The only non-zero lines are the three documented
`NOGOLD` notices (`create_save`, `open_close`, `netlisting` have no committed
baseline).

**What was actually wrong:** `rdw::push` said nothing to the window manager at
all. `rdw::open` does raise, but only on the `rdw::show`/`rdw::key` route, and
its plain `raise` is **an inert no-op on the server the user reported from**
(issue 0054: that WM applies stacking only at map time).

**What changed:** `raise_activate_toplevel` split in two. The body — issue 0054's
`wm withdraw` + `wm deiconify` re-map, the north-west creep note, issue 0843's
deferred `_remap_verify` — becomes `raise_toplevel`. **The `xschem
activate_window` line MOVED, it was not deleted**: `raise_activate_toplevel`
keeps its name, its two guards and that line, and delegates the body, so the
Library Manager, the CIW, `create_instance`, `copy_form`, `save_as_form`, the
wave viewer, ASE and `alt2_toggle_view` are unmoved. `rdw::push` calls the other
half, through `rdw::_raise`, behind `rdw::have_tk` **and** `winfo exists .rdw` —
`rdw::open` stays the one constructor and a push into a closed window stays a
store push.

**THE THING DD-6 DID NOT ANTICIPATE, and it is a user-visible decision:** the
re-map takes the keyboard. Measured on `:99`/openbox, keyboard parked on the
canvas first — plain `raise`: no re-map, focus stays on `.drw`; `wm withdraw` +
`wm deiconify`: really re-mapped, **focus moves to `.rdw` and stays there**. A WM
grants focus to a newly mapped toplevel. So the faithful DD-6 implementation
takes the keyboard off the schematic on every dump, which the user forbade in the
same sentence as the request. Fixed by arming the **existing** one-shot hand-back
(`rdw::_arm_focus_handback`, issue 1306) before the re-map — it declined to arm
for an already-mapped window, correctly until now, and a new `remapping`
argument tells it a map really is coming. Rule debt
`1340_R4_the_remap_hands_the_keyboard_back` (`--eyes`).

**Decisions relied on:** DD-6, honoured as written and **not** found wrong — the
split is implementable exactly as it says, and a prototype of it scores ALL PASS
59. Its *stated cost* is incomplete (see above), which is what the new rule debt
records; the ruling itself stands.

**Teeth, each sabotage on a COPY, restored by `cp` and verified with `md5sum`:**
un-forcing the arm reds RA1 RA2 (on `focus` = `.rdw`); a plain `raise` instead of
`raise_toplevel` reds RA2 RA3 RA4; **re-deriving `raise_activate_toplevel` as
`raise $top` + the activation reds RH3 and nothing else** — the keys suite stays
ALL PASS 59. That last variant is why the implementing pass added **RH3**: RH1
and RH2 fence what the split must not *do*, and neither says the two halves are
still *joined*, which is the regression this item actually creates.

**The first open does not flicker, measured** (the obvious worry about raising
from `push`): probed with a `<Map>`/`<Unmap>` counter armed inside `rdw::build`
itself, the first-of-session open+dump gives `Map=1 Unmap=0`, because `.rdw` is
not yet mapped when `push` runs and `raise_toplevel` takes its plain-deiconify
arm. A second dump into that window gives `Map=1 Unmap=1`. Both end with `focus`
on `.drw` and the one-shot spent.

⚠ **What `:99` cannot judge, said out loud.** The `wm geometry` legs have no
teeth here: measured against a prototype with the geometry restore DELETED, the
suite still scores ALL PASS 59, because openbox puts the window back by itself.
And `:99` cannot reproduce the reported defect at all — a plain `raise` is green
here and inert there — so the Map/Unmap and `_remap_verify` receipts are a
**proxy**, not the thing.

**Still not fixed, said loudly:** issue **1331** (the narrow arm's refusal for a
symbol path containing a space) is untouched — it is not on R4's path. Issue
**1330** belongs to R2's channel and NUMBERING.md records it **FIXED by 1338**,
but `doc/claude/issues/1330-*.md` still opens *"Status: FILED, NOT FIXED"* — R2's
residue, left for its owner rather than edited from here, and flagged so the next
reader is not misled by whichever of the two they happen to open first.

**Look debt:** `the_RDW_raise_behaviour`, updated in place with the counts, the
focus finding, the creep question and the pick-mode cost. **Suites green, please
look** — a raised window on VcXsrv is a pixel judgement no count can make, and
`:99` provably cannot reproduce the defect that was reported.

---

### R5 — issue 1341, engineering notation — DONE 2026-09-05

**What the user can now do:** read the Results Display Window and the schematic
side by side and see **the same number in the same notation** — `id : 11.1u` in
the pane where the sheet says `id = 11.1u`, instead of the raw `1.11e-05` the
window used to print. It is not a lookalike: the window now formats through
`op_annot::eng_or_blank`, *the sheet's own proc*, so the two surfaces cannot
drift and the user's own `ev_precision` reaches both.

**Files:** `src/rdw.tcl` (the only file under `src/` — one proc,
`rdw::_value_text`), `tests/headless/test_rdw_window_1245.tcl` (new section EN,
plus sixteen existing goldens re-measured), `tests/headless/test_op_param_store_1245.tcl`
(row BE0's two rendered lines),
`doc/claude/issues/1341-rdw-parameter-values-printed-raw-not-in-engineering-notation.md`,
`doc/claude/issues/NUMBERING.md`.

**Name+status diff, RE-MEASURED here, not taken on trust.** The RED state was
reproduced by restoring the pre-R5 proc body into `src/rdw.tcl` (a `cp` copy
taken first; restore verified by `md5sum` — `dbf54238604b7b2a90aa22d67fa924ab`
before and after), running all five suites, then restoring. Every cell below
printed a real RESULT line; none is an empty grep.

| suite | how | RED | after | rows that moved |
|---|---|---|---|---|
| `test_rdw_window_1245` | `--nogui` | 21 FAILED (113) | **ALL PASS (134)** | F1 F3 F4 F5 F7 F8 F14 F15 Q1 Q3 Q4 Q6 K8 BT0 RE4 (goldens) + EN1 EN2 EN4 EN5 EN6 EN7 FAIL→ok. EN3 green throughout, deliberately. |
| `test_rdw_window_1245` | `:99` | 21 FAILED (125) | **ALL PASS (146)** | the same twenty-one |
| `test_op_param_store_1245` | `--nogui` | 1 FAILED (129) | **ALL PASS (130)** | BE0 FAIL→ok |
| `test_rdw_keys_1245` | `:99` | ALL PASS (59) | **ALL PASS (59)** | none |
| `test_op_annot` *(control)* | `--nogui` | ALL PASS (485) | **ALL PASS (485)** | none |
| `test_annot_declutter_1244` | `:99` | — | **ALL PASS (134)** | none |
| T1 `tclsh run_regression.tcl` | solo | — | **0 counted failures** | 57 cases all `Total num fail: 0`, exit 0, no `exit 127` |

**The change, in full** — one proc, four arms, ruling **DD-7**'s wrapper and not
its rejected one-liner:

```tcl
proc rdw::_value_text {v} {
    if {[string trim $v] eq {}} { return {(no value reported)} }
    if {![string is double -strict $v]} { return [rdw::_oneline $v] }
    set e {NOFMT}
    catch {set e [::op_annot::eng_or_blank $v]}
    if {$e eq {NOFMT}} { return [rdw::_oneline $v] }
    if {$e ne {}} { return [rdw::_oneline $e] }
    return [rdw::_nonfinite_text $v]
}
```

Nothing else under `src/` moved, and the three reasons PLAN.md gives all held:
`rdw::_row_param` matches only the name before the colon (EN1's last leg reads
every parameter name back out of the re-formatted block, so R2's Up/Down, the
re-slot and the cursor are unaffected); the column width is computed from
parameter **names** only, so alignment did not move; `_reslot_block` /
`_reorder_shown` reuse already-rendered lines.

**`string is double -strict` is doing two jobs.** It splits the non-finite arm
from the verbatim arm, and it is a **second** lock on the safety gate
`eng_or_blank` already carries: `to_eng` is `uplevel #0 expr [join $args]`, so a
value that reached it unguarded would evaluate **at global scope**, on a string
that came out of a raw file. `src/rdw.tcl` names `eng_or_blank` and names
`to_eng` **zero** times, and row EN2's structural leg counts both in the
comment-stripped file.

**The sharpest input, measured on this binary:** `to_eng 1e400` returns the
string **`infT`** — a plausible-looking engineering number that is not a number,
and it would paste into a design review as one. `1e400` passes
`string is double -strict`; `eng_or_blank`'s `_finite` catches it and answers
`{}`, which is how it reaches the `(did not converge)` arm. EN4's fourth leg is
that value.

**One row the RED pass did not write, added by the implementing pass: EN7.** The
crew brief asks for the input most likely to break the change and whether any row
would see it. The answer was a value **outside `to_eng`'s SI ladder**, and none
did. Measured at `ev_precision` 4: `1e-321` → `9.98e-304a`, `1e20` → `1e+08T`,
`0x10` → `16`, `0b101` → `5`, `+5` → `5`, `5.` → `5`, `.5` → `0.5`. Two read
oddly and one silently rebases a hex literal — and **none of it is this item's
doing**: the *sheet* prints the same thing. So EN7 asks for the **equality** with
`eng_or_blank` plus the two invariants that must survive whatever `to_eng`
answers (never blanked, never `(did not converge)`), rather than pinning
`9.98e-304a` as a literal — which would fence a libm denormal this item does not
own and would red on the day someone improves the ladder, at which point both
surfaces move together. EN7 is red before the change too, and reds in the RED
run above.

**The NOFMT sentinel is not decoration.** `catch` leaves it in place only when
the call **raised** — an `op_annot` that never loaded — and that arm falls back
to the raw text. Answering `(did not converge)` there would invent a
non-convergence for a number the simulator computed perfectly well. Measured by
renaming `eng_or_blank` away in a live interpreter: `1.11e-05` → `1.11e-05`,
`nan` → `nan`, both back the moment it is renamed home. Its cost is in the
comment: in that arm (unreachable as shipped — `src/xschem.tcl:16780` sources
`op_annot.tcl` before `:16821` sources `rdw.tcl`) a `nan` prints raw again,
exactly as it did before this item, because telling it apart without the sheet's
proc means a second spelling of "is this finite" in this file — the drift the
item exists to remove.

**Decisions relied on:** **DD-7**, honoured as written and **not** found wrong —
the wrapper is exactly what it describes, its rejected one-liner is sabotage
variant SB-ONELINER and reds EN2 EN3 EN4, and the blank it forbids is EN4.

**The E question, recorded not decided:** DD-7 forbids the blank and invariant I3
forbids the raw `nan`, so the third option — the window's own
`(did not converge)`, which PLAN.md's R5 bullet names — was the crew's choice,
and it is **a behaviour change beyond notation**. Rule debt
`1341_nonfinite_in_the_devices_bucket` (`--eyes`), with all three options and the
note that (a) is lossy: `nan`, `inf` and an overflowing literal all read the
same. Overruling it moves row EN4 and nothing else.

**Still not fixed, said loudly:** issue **1331** (the narrow arm's refusal for a
symbol path containing a space) is untouched — R5 changes no status line. Issue
**1330** is R2's and is fixed in the code; its own issue file still opens
*"Status: FILED, NOT FIXED"*, which is stale — recorded here and in the 1341
write-up rather than edited from this item, the same way R4's row recorded it.

**Look debt:** `the_RDW_engineering_notation`, updated **in place** (one debt for
one formatter, not a second filing) with the counts, the ragged-value-column
question and the lossy-nonfinite caveat. **Suites green, please look** — whether
the numbers read the same as the schematic's is a judgement about a number's
shape, and no count makes it.

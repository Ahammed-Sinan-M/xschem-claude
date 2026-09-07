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
| R3 | 1339 | select and copy | **DONE** 2026-09-05 |

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


### R3 — issue 1339, select and copy — DONE 2026-09-05

**What the user can now do:** select any part of a dump and press `Ctrl-C`
**from anywhere in the window** — the pane, any of the five buttons, the
toplevel itself — and get exactly that text on the CLIPBOARD; keep the selection
when VcXsrv's clipboard bridge takes the X PRIMARY selection out from under it,
which is what made the gesture "work one time"; double-click a word, **let go**,
and press-and-drag to grow the selection with the word intact; right-click for
**Copy** / **Select All** when a chord is eaten; and, when a `Ctrl-C` has nothing
to copy, keep the clipboard they were about to paste into **and be told so**.

**Files:** `src/rdw.tcl` (the only file under `src/`),
`tests/headless/test_rdw_keys_1245.tcl` (section CP, floor 59 → 71 — CP1…CP11
from the RED pass, CP12 added by the implementing pass),
`doc/claude/issues/1339-select-and-ctrl-c-do-not-copy.md` (the reserved number
had no file),
`doc/claude/issues/1343-the-rdw-raise-does-not-work-on-the-users-vcxsrv-server.md`,
`doc/claude/issues/NUMBERING.md`, `doc/claude/rdw_batch/LEDGER.md`.

**Name+status diff.** Every cell printed a real RESULT line. The brief's
baseline numbers were stale (R1/R2/R4/R5 had already raised them) and were
**re-measured here, not taken on trust**:

| suite | how | before | after | rows that moved |
|---|---|---|---|---|
| `test_rdw_keys_1245` | `:99` | 5 FAILED (65 passed) | **ALL PASS (71)** | CP2 CP3 CP4 CP5 CP6 FAIL→ok; CP12 added |
| `test_rdw_keys_1245` | **`$DISPLAY`, the user's VcXsrv** | 11 FAILED (60 passed) | **5 FAILED (66 passed)** | CP2 CP3 CP4 CP5 CP6 CP12 FAIL→ok; **RA1…RA5 red before and after, byte-identically** — see below |
| `test_rdw_window_1245` | `--nogui` | ALL PASS (134) | **ALL PASS (134)** | none |
| `test_rdw_window_1245` | `:99` | ALL PASS (146) | **ALL PASS (146)** | none |
| `test_op_param_store_1245` | `--nogui` | ALL PASS (130) | **ALL PASS (130)** | none |
| `test_annot_declutter_1244` | `:99` | ALL PASS (134) | **ALL PASS (134)** | none |
| `test_op_annot` *(control)* | `--nogui` | ALL PASS (485) | **ALL PASS (485)** | none |

Four consecutive `:99` runs of the keys suite, all `ALL PASS (71)`.

**RULING DD-8 IS PAID, and it found something.** `$DISPLAY` =
`172.20.160.1:0`, vendor string `HC-Consult` — the VcXsrv the user actually
looks at, *not* `AUDIT_DISPLAY=:0`, which is WSLg's Xwayland. **Every row of
section CP passes there**, including CP3's theft and CP6's extend. Five rows of
section **RA** — item R4's raise — fail there, and they fail **byte-identically
with this item's `src/rdw.tcl` replaced by `git show HEAD:src/rdw.tcl`**
(restored by `cp`, `md5sum` verified), so they are pre-existing and are not R3's.
Filed as **1343**, with a `look` debt: issue 1340 is closed FIXED on a `:99`
number and its own suite debt names `:0`, and neither is the user's screen. That
is DD-8's argument applied to R4, and nobody had applied it.

**THE LITERAL READING OF DD-5 IS A NO-OP ON THIS BUILD, and implementing it
would have shipped green-and-wrong.** `event info <<Copy>>` already answers
`<Control-Key-c> <Key-F16> <Control-Lock-Key-C> <Meta-Key-w> <Lock-Meta-Key-W>
<Control-Key-Insert>` — both sequences DD-5 names — and with the keyboard in the
pane a real `Ctrl-C` **already copied**. DD-5 is honoured in its *purpose* (all
three sequences are bound, and the menu exists) and its prescription is
deliberately not the mechanism. Three real mechanisms, each driven before a line
was written: the copy rode a **class** binding and died the moment the keyboard
left `.rdw.p.t` — which `rdw::_arm_focus_handback` arranges after **every**
dump; a `-exportselection 1` text widget **deletes its own `sel` tag** when
another client takes PRIMARY (`tag ranges sel` empty, `get sel.first sel.last`
raising, `tk_textCopy`'s catch swallowing it so the clipboard is never written);
and `bind Text <1>` re-anchors on the press, cutting the double-clicked word in
half 5/5.

**The discriminator is the one honest one, and it was measured rather than
guessed.** A theft and a deliberate deselect both arrive as one `<<Selection>>`
with `tag ranges sel` empty, so the event cannot tell them apart. Reading
`selection own` **inside** the handler: user clicks elsewhere → `.rdw.p.t`;
script `tag remove sel` → `.rdw.p.t`; another client takes PRIMARY → that client
or empty. Tk does not release the selection when the tag is merely emptied, so
"the pane still owns PRIMARY" *is* "the user gave it up". The query is local —
`selection own` never makes an X round trip to a foreign owner, which inside an
event handler could block for the selection timeout.

**The extend needed no Tk internals.** The rejected shape was `break` on the
press plus a hand-written re-anchor, which means writing `tk::Priv(selectMode)`
and the widget's private anchor mark from this file — in the one binding whose
existing comment records what breaking that class binding costs. What shipped is
a **union after the fact**: `rdw::pane_click` (widget tag, *before* the class
binding) records the standing selection only if the press landed **inside** it,
and a `<B1-Motion>` on the `.rdw` tag — the first place a binding can see what
the class binding decided — unions the drag's own answer with it. With nothing
armed the proc is a no-op and the pane behaves exactly as before, which is why
CP7's three "already works" legs are unchanged code paths.

**CP12 is the crew brief's question, and its first draft was VACUOUS.** The
input most likely to break the fix is namespace state holding **text indices**:
Tk clamps a stale index rather than refusing it, so a remembered span left
standing across a repaint copies whatever slid under those numbers. Written the
obvious way — push over a *live* selection — it passed with
`rdw::_forget_selection` commented out of `render_pane` (**ALL PASS 71**),
because the repaint's own `delete 1.0 end` fires `<<Selection>>` and the mirror
already listens. Driven from the **post-theft** state, where `sel` is already
empty and no event fires, it reds correctly and hands the user `MCU:/` from the
**new** block off a span into the old one. The sabotage ran on a copy;
`md5sum`-verified restore both times.

**Decisions relied on:** **DD-5**, honoured in purpose and **found wrong as
written** — its prescription is already true on this build and fixes none of the
three defects; recorded here and in the 1339 write-up rather than implemented
literally. **DD-8**, paid in full, and it produced issue 1343.

**The E question, recorded not decided:** rows CP5 and CP4 require the window to
**say** that a `Ctrl-C` with nothing selected copied nothing, and to say
something different on success. The user asked only that copy work. Rule debt
`1339_R3_copy_says_what_it_did` (`--eyes`), which also names the cost: every
`Ctrl-C` overwrites whatever the status line was showing, including item B5's
saved-settings path. Overruling it moves CP5 legs 3–6 and CP4 leg 6 and no
source behaviour but the wording.

**CP10 is green and was not spent.** `-exportselection 0` is the one-line fix
for CP3 and costs select-then-middle-click paste, which `rdw::_exportsel`'s own
comment calls the user's stated reason the window exists. The mirror keeps both.

**Still not fixed, said loudly:** issue **1331** (the narrow arm refuses a symbol
path containing a space and offers no *"Choose every device of class X
instead"*) is untouched — R3 adds status sentences but changes no refusal path.
Issue **1330** is R2's and is fixed in the code; its own issue file still opens
*"Status: FILED, NOT FIXED"*, which is stale — the fourth item in a row to
record that here rather than edit another item's file. **Somebody should just
fix that line.** And issue **1332**'s `after 100` flake in section SD was not
seen in any of the eight runs taken here, and was not fixed.

**Look debts:** `1339_R3_select_and_copy` — **suites green on `:99` AND on the
user's own VcXsrv, please look**: the post-theft highlight is now drawn by a tag
of the window's own and must still *read* as a selection; the right-click menu
is new; and the double-click-then-drag gesture is the one they said worked once.
`1343_rdw_raise_on_your_own_server` — please watch a dump arrive on your own
screen, and press `Ctrl-Alt-S` for the Library Manager, because if that does not
raise either then 1343 is issue 0054's and older than this batch.

### P1 — issue 1344, the wrong text on the clipboard — REPAIR, DONE 2026-09-05

*Repairing item R3 (issue 1339) after its adversary REFUTED it. Nothing R3 built
is reverted: the toplevel chord, the PRIMARY-theft mirror, the right-click menu
and the double-click-then-drag union all stand, and the adversary's own verdict
was that the mechanisms are right.*

**What the user can now rely on:** the Results Display Window never touches the
clipboard unless it has something to put there. Opening it from `Tools` with no
dumps and choosing Select All → Copy leaves the document text they were about to
paste exactly where it was, and says so instead of claiming it copied two lines
of nothing. A selection made **anywhere in that window** is the selection
`Ctrl-C` copies — including the settings-file path in its own status line, which
now survives the copy rather than being overwritten by a receipt for itself. And
Select All and the Copy that follows it give the **same** number of lines, which
is the number the paste really is.

**Files:** `src/rdw.tcl`,
`tests/headless/test_rdw_keys_1245.tcl` (CP13, CP14, CP15; floor 71 → 74),
`tests/headless/test_rdw_window_1245.tcl` (section CY: CY1..CY4; floor 127 → 131),
`doc/claude/issues/1344-the-rdw-puts-the-wrong-text-on-the-clipboard-and-wipes-it.md`,
`doc/claude/issues/NUMBERING.md`.

**The four defects, each driven before the change and after it** (probe
`scratchpad/P1/p1_probe.tcl`, run on `:99` **and** on the user's own VcXsrv,
byte-identical on both):

| # | before | after |
|---|---|---|
| a — the empty window | clipboard `MY-IMPORTANT-DOCUMENT-TEXT` → `<NL>`; *"Selected the whole window, 1 line."* then *"Copied 2 lines, 1 characters"* | selection range `{}`, *"There is nothing in the window to select yet."*, clipboard **preserved** |
| b — the status line's own selection | PRIMARY `/home/analog/.xschem/op_param_lists.tcl`, clipboard `MCU:/` (the pane), mirror `{1.0 1.5}` still standing | clipboard **is the path**, mirror `{}` |
| c — the text being copied | status → *"Copied 1 line, 5 characters"*, the path gone | status still **is** the path, the entry's selection still present |
| d — the two counts | select_all `7`, copy `8`, paste really `6` | **6 and 6**, and the phantom newline is off the clipboard |

**And a fifth, found by the row rather than by the report.** CP13's blank-span
half stayed red after the whitespace guard landed: the pane's bindtags are
`.rdw.p.t Text .rdw all`, so Tk's own `bind Text <<Copy>>` runs **before** R3's
toplevel chord and is a second door on to the clipboard obeying none of
`rdw::copy`'s guards. Fixed by binding the chord on the pane itself with a
`break`, which is the only way `rdw::copy` is the one copy its comment says it
is.

**Name+status diff** (baseline re-asserted on this tree before any change, every
suite confirmed to have printed a RESULT line):

| suite | how | before | after | rows that moved |
|---|---|---|---|---|
| `test_rdw_window_1245` | `--nogui` | ALL PASS (134) | **ALL PASS (138)** | CY1 CY2 CY3 CY4 added |
| `test_rdw_keys_1245` | `:99` | ALL PASS (71) | **ALL PASS (74)**, 3 runs | CP13 CP14 CP15 added |
| `test_op_param_store_1245` | `--nogui` | ALL PASS (130) | **ALL PASS (130)** | none |
| `test_op_annot` *(control)* | `--nogui` | ALL PASS (485) | **ALL PASS (485)** | none |
| `test_rdw_keys_1245` | `$DISPLAY` (VcXsrv) | — | 7 FAILED (67 passed) | SD2 SD3b (issue **1332**) + RA1..RA5 (issue **1343**) — **all fifteen CP rows pass there**, the three new ones included |
| `test_rdw_keys_1245` | `:0` (Xwayland) | 13 FAILED (61) | 10–11 FAILED (63–64) | RA1..RA6 + F1 V3 V7 D1, all present byte-identically on HEAD's `rdw.tcl`; F3 is a flake there (11/10/11 over three runs of the same tree). **All fifteen CP rows pass on `:0` as well**, so the copy behaves identically on all three X servers on this machine |

**RED before green, both suites, against `git show HEAD:src/rdw.tcl`** (swapped
in by `cp`, restored by `cp`, `md5sum` verified identical afterwards —
`92bb2c03e6662526abf287fc63938e36`):

```
keys   :99   RESULT: 3 FAILED (71 passed)
             CP13 -> {1 1 {1.0 2.0} {<NL>} ...
             CP14 -> {1 1 2 0 1 0 1 1}  (exp {1 1 0 1 0 1 1 1})
             CP15 -> {1 0 1 0 0}        (exp {1 1 1 1 1})
window --nogui  RESULT: 4 FAILED (134 passed)   CY1 CY2 CY3 CY4
```

**Why four of the rows are in the `--nogui` suite.** Every behavioural row above
is behind the keys suite's `have_tk` guard, so a machine with no display runs
**none** of them. The three decisions the fix turns on are pure functions, and
CY1..CY3 fence them on both arms; CY4 holds the call sites, because a predicate
nobody consults passes while the window goes on wiping the clipboard.

**Decisions relied on:** **DD-5** (the copy has a keyboard-free door — the
right-click menu is now the door row CP13 drives the empty window through) and
**DD-8**, paid in full: the four defects were driven, and the repair confirmed,
on `$DISPLAY` = `172.20.160.1:0` / `HC-Consult`, not only on `:99`.

**A driver decision, recorded not decided:** when the text being copied **is**
the status line, the window says nothing and leaves the line alone. Reporting
the copy would destroy both the user's selection and the only copy of the path
on screen — a receipt is worth less than the text it is a receipt for, and the
still-standing highlight is the receipt. Rule debt
`1344_copy_from_the_status_line_is_silent`. Overruling it changes one proc
(`rdw::_copy_report`) and CP14's leg 6.

**Still not fixed, said loudly.** Issue **1330**'s file still opens *"Status:
FILED, NOT FIXED"* although R2 fixed the code — now the **sixth** item in a row
to record that instead of editing one line in another item's file. Issue
**1331** untouched. Issue **1332** not fixed, and it is no longer "once in 134
runs": it fired on the `$DISPLAY` run here as it did on both of the adversary's,
so **any future `$DISPLAY` count for this suite is unusable until it is fixed by
polling**. Issue **1343** untouched — RA1..RA5 still red on the user's server.
And two costs the adversary recorded and did not fix are still live: after a
PRIMARY theft the highlight cannot be put down by an ordinary click, and a drag
that starts inside a standing selection can only grow it. Both are look debts,
neither is this repair's subject.

**Look debt:** `1344_rdw_copy_after_repair` — **suites green on `:99` and on
your own VcXsrv, please look**: open the window with no dumps and try Select All
→ Copy with something you care about on the clipboard; then select the saved
settings path in the status line and press `Ctrl-C`, which should now hand you
the path and leave it on screen.

---

## REPAIR P2 — issue 1345, the window said "(did not converge)" when its own formatter merely declined

*Adversary finding #4 (item R5). **CONFIRMED and REPAIRED.** Item R5's
mechanism is right and nothing of it is reverted: the window still formats
through `op_annot::eng_or_blank`, the schematic's own proc. What was wrong is
that it read that proc's EMPTY answer as a verdict about the circuit.*

**Driven before the change, twice.** Headless, all eight values the shipped
precision menu accepts without validation (`-1 2.5 abc 4x +4 0x4 6. 6.0`):
every finite measured value printed `(did not converge)`. And in the live pane
on `:99`, the adversary's own two-block session, reproduced against
`git show HEAD:src/rdw.tcl` swapped in by `cp` and restored by `cp`
(`md5sum` verified):

```
BEFORE   id : (did not converge)   gm : (did not converge)   vth : (did not converge)
         id : 11.1u                gm : 1m                   vth : 0.75

AFTER    id : 1.11e-05             gm : 0.001                vth : 0.75
         id : 11.1u                gm : 1m                   vth : 0.75
```

**The fix.** `rdw::_value_text` asks `op_annot::_finite` — the predicate
`eng_or_blank` gates on itself, so no second opinion about what non-finite
means enters this file — and asks it **before** it chooses the words. Once
finiteness is settled, an empty answer can only be the formatter declining, and
the fallback is the raw text: unformatted but **true**. That also subsumes the
old `NOFMT` sentinel.

**Name+status diff** (baseline re-asserted on this tree against
`git show HEAD:` for all three edited files before any change; every suite
confirmed to have printed a RESULT line):

| suite | how | before | after | rows that moved |
|---|---|---|---|---|
| `test_rdw_window_1245` | `--nogui` | ALL PASS (138) | **ALL PASS (141)** | EN8 EN9 EN10 added; EN6 rewritten |
| `test_rdw_window_1245` | `:99` | ALL PASS (150) | **ALL PASS (153)** | same three |
| `test_rdw_window_1245` | `:0` (Xwayland) | — | **ALL PASS (153)** | — |
| `test_rdw_keys_1245` | `:99` | ALL PASS (74) | **ALL PASS (74)** | none |
| `test_op_param_store_1245` | `--nogui` | ALL PASS (130) | **ALL PASS (130)** | none — `ev_precision` pinned, no rows added |
| `test_op_annot` *(control)* | `--nogui` | ALL PASS (485) | **ALL PASS (485)** | none |
| T1 `run_regression.tcl` | solo | 0 counted | **0 counted** | none |

**RED before green**, against `git show HEAD:src/rdw.tcl`:
`RESULT: 2 FAILED (139 passed)` — **EN8** and **EN10**. EN9 was green before and
after, and saying so is the point: it fences the *fix*, not the code.

**Three sabotages, all caught** (on a copy; restore `md5sum`-verified):
`SB-OWNPREDICATE` (a `regexp {^[-+]?(nan|inf)}` of this file's own instead of
`op_annot::_finite`) → **EN4 + EN10**; `SB-BLANK` (the declined-formatter
fallback returns `{}`) → **EN8**; `SB-WORDS` (it returns
`(no value reported)`) → **EN8**.

**The other two findings, judged.**

* **`to_eng` rebases numeric literals** (`010 -> 8`, `007 -> 7`, `0x10 -> 16`,
  `0b101 -> 5`, measured; `08`/`09` are not doubles and take the verbatim arm).
  **Comment corrected, code not hardened.** The paragraph at `src/rdw.tcl:455`
  said the double gate stopped a value reaching `uplevel #0 expr` — true only
  for NON-numeric strings. Hardening in `rdw.tcl` would print `10` where the
  sheet prints `8`, which is the disagreement **DD-7** forbids, and `to_eng` is
  the whole tree's formatter. Row **EN9** pins the agreement and the five
  measured values, so a one-sided hardening reds rather than drifts.
* **The `1341_nonfinite_in_the_devices_bucket` rule debt describes a DEAD arm**
  — confirmed, and now **measured** rather than read. Stubbing
  `xschem raw value` and restoring it: all ten spellings of a non-finite
  (`nan -nan NaN inf -inf Inf INF Infinity 1e400 1e309`) route to the
  `nonfinite` bucket through `op_annot::raw_class`, which the one and only
  registrant uses; `format_answer` renders that bucket directly, never through
  `_value_text`. The one reachable way to fire the arm *was this bug*, so it
  now has no live producer at all. **Said so in `doc/claude/issues/1341-...md`**
  so the user is not asked to rule on nothing.

**EN6's fragility was never EN6's alone.** The adversary flagged that EN6
asserted `$EN6_SAVE == 4`, hard-depending on the very preference the row is
about. Measured with `--preinit 'set ev_precision N'` (which lands before
`xschemrc`'s `set_ne`, reproducing a user rc): at **6**, `test_rdw_window_1245`
red **1** row (EN6) and `test_op_param_store_1245` red **6** (D1 D2 D4 D6 D8
D10); at **2**, the window suite red **11** (F1 F3 F8 F14 F15 F19 Q1 Q6 K8 EN1
EN2). Both suites now **state the precision they measure at** and put the
reader's own value back before the verdict, and **EN6 drives 4 and 6 itself and
asserts neither is the shipped value**. After: **ALL PASS at default, 6, 2, -1
and `abc`**, both suites.

**Not fixed, said loudly.** `test_op_annot` — this batch's **control** — has
the same latent fragility, **7 rows** (S5 S10 S16 S17 K10 K11 XR4) red at
`ev_precision 6`. Pre-existing, not item R5's doing, and editing the control
would compromise the one signal the batch measures acceptance against. Also
still standing and untouched by this repair: issue **1330**'s file still opens
*"Status: FILED, NOT FIXED"* while the code is fixed (now the **seventh** item
to record that rather than edit another item's file), issue **1331**, issue
**1332** (the keys suite's `after 100` flake), and issue **1343** (RA1..RA5 red
on the user's own VcXsrv).

**A test defect this repair's own row caught, worth remembering.** EN8's first
green run reported a mismatch that was its own doing: the expected value was
built with `expr {$s eq {} ? $v : $s}`, and **`expr` numifies the branch it
takes** — `1.11e-05` came back as `1.11e-5`. A string comparison's golden must
never be built by `expr`. Fixed to an `if`, and the reason is written into the
row.

**Rule debt** `1345_window_prints_what_the_sheet_blanks` — and it **answers**
the adversary's open question
`1341_R5_the_window_says_did_not_converge_when_the_formatter_fails`; the two
should be read and cleared together. The decision taken on the user's behalf:
when the value is finite and the formatter cannot render it, the window prints
the **raw number** where the schematic prints a **blank** for the same row. The
alternatives are the false statement just removed, or a blank whose existing
footnote would then lie about a measured value. Its second half is upstream and
deliberately not fixed here: the precision dialog validates nothing, and
`to_eng` does not always even raise — measured at precision `4x`, `to_eng 0`
answers the string **`0000g`**, and the sheet prints that too.

**No look debt.** Nothing changed on a healthy setup — every existing golden is
byte-identical, and the only visible difference needs a deliberately broken
`ev_precision`. The format itself is still owed an eyeball on the standing look
debt `the_RDW_engineering_notation`, unchanged by this repair.

---

## P3 — issue 1332: the keys suite's modal driver polls, so `$DISPLAY` is measurable again

**Subject:** `tests/headless/test_rdw_keys_1245.tcl`, section SD only (rows
SD1, SD2, SD3b converted; SD5, SD6, SD7 added; floor 74 → 77). **No `src/`
file touched** — this is a test defect, and the adversaries said so.

**Why it mattered more than "once in 134 runs".** VERIFY #5 measured it firing
on **2 of 2 runs on the user's own VcXsrv**, which made every future `$DISPLAY`
count for this suite unusable — and `$DISPLAY` is the only server that can
settle issue **1343** (item R4's raise). Reproduced here: **SD2 on 1 of 4**
pre-fix VcXsrv runs, giving VERIFY #5's exact shape `7 FAILED (67 passed)`.

**Driven before it was touched, deterministically, twice.** A scratchpad probe
wrapped `rdw::scope_dialog_build` and spun the **event loop** (a busy-wait
proves nothing — no timer fires while Tcl is out of the loop). The repo file was
never mutated; `md5sum` verified.

* **Shape A, known** — delay 300 ms *before* the build:
  fixed `after 100` → `{0 0 0 {} 0 0 {}}` **in 5004 ms**, byte-identical to
  issue 1332's own recorded tuple; poll → the expected tuple in 315 ms.
* **Shape B, NOT in the filing, and the one that hurts** — delay 200 ms *after*
  the build, before `focus -force $w`: the toplevel **already exists**, so a
  poll on `winfo exists` alone would have shipped the bug intact. Tk redirects a
  key event to the **display's focus window**, so SD2's Escape lands on `.drw`
  and **ends the user's canvas command mode**: `run1 0` (exp 1), then the full
  5 s deadman. Poll → `run1 1` in 205 ms.

**The fix.** `sd_arm` / `sd_poll_modal` / `sd_disarm` re-arm on `after 5` until
`[winfo exists .rdw.scope]` **AND** `[grab current] ne {}`. That pair is exact,
not lucky: `rdw::scope_dialog` runs `grab set` then `focus -force` with **no
event loop between them and `tkwait window`**, so a driver that sees a grab is
inside `tkwait` on a dialog that is fully modal and already holds the keyboard.
Budget 900 × 5 ms = 4.5 s, **inside** the unchanged 5 s deadman, so a poll that
never finds its dialog gives up instead of driving a later row's toplevel. **The
delay was not widened** — the issue file and the crew brief both forbid it.

**A second latent flake removed on the way past.** Both timers are now cancelled
when the row ends. They were not: SD1's 5 s deadman stayed armed while SD3b's
dialog was up, one `catch {destroy .rdw.scope}` from cancelling a dialog another
row was mid-drive.

**RED before green**, on a **copy** whose `sd_arm` was reverted to `after 100`
(copy deleted, repo file `md5sum`-verified unchanged):

```
FAIL SD5 -> {0 0 0 {} 0 {} 1 0 1 0}
FAIL SD6 -> {1 CANCELLED 0 .drw 0 {} 1 0 1 0}
FAIL SD7 -> {CANCELLED 1 0 1 CANCELLED 1 1 0 {} 1}
RESULT: 3 FAILED (74 passed)
```

**SD1, SD2 and SD3b passed in that same sabotaged run** — the old rows cannot
see this defect on a quiet `:99`, which is exactly why it survived 134 runs.
Each new row carries an elapsed-time leg, so a poll quietly reverted to a fixed
delay cannot pass by accident.

**Name+status diff** (every suite confirmed to have printed a RESULT line; the
`--nogui` arm of the keys suite still says `RESULT: SKIP`, not an empty cell):

| suite | how | before | after | rows that moved |
|---|---|---|---|---|
| `test_rdw_keys_1245` | `:99` | ALL PASS (74) | **ALL PASS (77) × 12/12** | SD5 SD6 SD7 added; SD1 SD2 SD3b converted, all still green |
| `test_rdw_keys_1245` | `:99`, **6-way spinner + concurrent `test_op_annot` on the same display** | **SD3b fired 2 of 13** | **SD rows 0 of 13** | issue 1332's own acceptance clause |
| `test_rdw_keys_1245` | **`$DISPLAY`, the user's VcXsrv** | **SD2 fired 1 of 4** (`7 FAILED`) | **`5 FAILED (72 passed)` × 7, SD rows 0 of 7** | the 5 are **RA1..RA5 = issue 1343**, not this |
| `test_rdw_window_1245` | `--nogui` | ALL PASS (141) | **ALL PASS (141)** | none |
| `test_op_param_store_1245` | `--nogui` | ALL PASS (130) | **ALL PASS (130)** | none |
| `test_op_annot` *(control)* | `--nogui` | ALL PASS (485) | **ALL PASS (485)** | none |
| T1 `run_regression.tcl` | solo | 0 counted | **0 counted** | none; no `exit 127` / `couldn't execute` |

**Reported clean, not fixed, as instructed.** On `$DISPLAY` the suite now sits
steady at `5 FAILED (72 passed)` and the five are **RA1 RA2 RA3 RA4 RA5**, issue
**1343**, item R4's — untouched here. One run in seven also flaked **CU7**,
pre-existing and unrelated.

**Other rows of this suite flake under a 6-way CPU spinner, in BOTH arms
identically** — F1 F3 F4 B2 B3 B4 B5 V2 D1 CP1 RA1 RA2 RA3 RA6, measured
**interleaved** pre/post (seven pairs, same machine, same minute) so it is
demonstrably not this change's doing. Not issue 1332, not fixed here, and
**filed as issue 1346** with the interleaved table, so it is not lost: quiet the
suite is 12/12 green, and under crew load it is noisy in a dozen places that
have nothing to do with the modal — which is where a real regression hides.

**Faster, as a side effect.** The same drive lands in 17 ms under the poll
against 107 ms under the fixed timer, so the three converted rows give back more
than the new ones cost.

**Still open, unchanged and said out loud:** `test_ase_bus_bits_0159.tcl:258`
(BB34/BB35) still uses the fixed-delay idiom the SD rows copied from — another
item's file, not measured flaking, not touched. Issue **1330**'s file still
opens *"Status: FILED, NOT FIXED"* while the code is fixed (now the **eighth**
item to record that rather than edit another item's file), and issues **1331**
and **1343** stand.

**No look debt.** Nothing user-visible changed — this is a test-harness repair,
and the only thing a human could look at is a suite log.

---

## P4 — issues 1347/1348/1349: the summary half of R2's subject line, said out loud, and three orders the window got wrong

**Subject:** `src/rdw.tcl` (`rdw::_write_key` and `rdw::_drawn_note` added,
`rdw::_edit`, `rdw::_reorder_shown` and both arms of `rdw::button` changed),
`tests/headless/test_rdw_window_1245.tcl` (section RE, rows **RE8 RE9 RE10
RE11** added; floor 141 → 145, `:99` 153 → 157). Issue **1330**'s file header
corrected. Issues **1347 1348 1349 1350** filed, `NUMBERING.md` updated.

**Every defect was DRIVEN AND SHOWN before anything was changed**, on the
shipped R2 (`0122c9a7`), with a standalone rebuild of section RE's own fixture
(`…/scratchpad/p4/`). Receipts below are that run's output.

### 1. The summary half of the user's own subject line (issue 1347)

The user asked for the reorder to be *"reflected in the Results Display Window
as well as the schematic annotation — **if applied to annotation params (1 key)
or summary list (2 key)**"*. Driven, cursor on M1's `gds`, `set_list summary`,
two accepted Ups:

```
store summary     ids gm gds  ->  gds ids gm
the pane          ids gds gm  ->  gds ids gm     moved
op_annot::text M1 "id  =\ngm  =\ngds =\n"  ->  IDENTICAL
annot_overlay_flushes                       +2
status line       "Up: moved gds up in the summary list for class p4cls."
```

**It is structural and older than R2.** `op_param_lists::_show_set`
(`src/op_param_lists.tcl:1746`) filters the annotation+summary union by the
**annotation** list's labels, in union order, and `_save_set` lays the union out
annotation-first — so every drawn row takes its position from list 1 and the
summary list's order can never reach `op_annot::text`. Before R2 the two
surfaces agreed because both stood still; R2 moved one of them.

**What was fixed is the false sentence, not the mechanism.** `rdw::_drawn_note`,
on the summary reorder arm only, beside DD-16's `_sheet_note`:

> `Up: moved gds up in the summary list for class p4cls. The schematic draws the annotation list, so what it draws did not move - press 1 and reorder there to change the sheet.`

The pane still follows the summary order, because that half **is** what the user
asked for on list 2. Delete and Add on the summary list are untouched: they
promise nothing about drawn order, so nothing they say is false.

**Whether list 2 should reach the sheet at all is the USER's** — it needs a rule
for combining two orders and reopens DD-6's "shown is derived by filtering".
**Rule debt `1347_R2_summary_order_on_the_sheet`**, options (a) say it (shipped)
/ (b) make list 2 drive the sheet / (c) stop re-slotting the pane.

### 2. The fence measured the wrong thing (issue 1347, row RE8)

Row **RE7** golds `annot_overlay_flushes >= 1`. Measured **+2** for the two
presses above **while the drawn string was byte-identical** —
`op_annot::register` bumps `::op_annot::gen` on any re-register. RE7's own title
is true (the schematic IS asked to re-render) and it is **left exactly as it
is**; a counter simply cannot see that the answer came back the same.

Row **RE8** golds the STRING `op_annot::text` puts on the sheet, both legs, with
the counter read on both — so the row says out loud that the counter cannot tell
the two presses apart:

```
annotation leg   labels  id gm gds -> id gds gm   text moved   flush +1
summary    leg   labels  id gm gds -> id gm gds   IDENTICAL    flush +1
                 pane    ids gds gm -> gds ids gm  == the store
                 sentence says something did not happen
```

### 3. A flavor reorder re-slotted a block it never reached (issue 1348)

Driven with a flavor entry on M1's cell only, one accepted Up:

```
status  "…moved gds up in the annotation list for cells matching …/p4n.sym of class p4cls."
class annotation list  ids gm gds -> ids gm gds   (unmoved, correctly)
flavor list            ids gm gds -> ids gds gm
M1's block             ids gds gm -> ids gds gm
M2's block             gm  ids    -> ids gm       <- NOBODY ASKED
```

`rdw::_reorder_shown` re-slotted every block of the edited **class** rather than
every block the **write** reached. Fixed by `rdw::_write_key`, **one** builder
of the `{<scope> <key>}` an edit writes at, used by `_edit` for the write and by
`_reorder_shown` for the test — two builders for one narrowing being invariant
I1's drift, which defect A6 of item B5-2 already cost this feature once.

The same guard fixes the other side: a **broad** write over a device a flavor
entry shadows no longer re-slots that device's block, so the pane stops
contradicting `rdw::_shadow_why`'s own sentence printed beneath it (row RE11).

### 4. Delete and Add abandoned the property R2 had just taught (issue 1349)

```
Up on gds       store ids gds gm   pane ids gds gm    agree
Delete gds (1)  store ids gm       pane ids gds gm
Add    gds (3)  store ids gm gds   pane ids gds gm    DISAGREE, nothing said
```

The comment justifying that arm argued about **membership** — "a re-slot could
neither add the new row nor remove the deleted one" — and both halves are true
and neither is about **order**: `rdw::_reslot_block` is a strict permutation
over exactly the rows the run published AND the list declares. The arm now
re-slots with the key the dialog's scope resolves to, and row **RE10** golds
BOTH the order agreeing and the pane's row SET being unchanged from the first
press to the last, so the old comment's worry is fenced rather than argued away.

### 5. NOT fixed, and it is an E question — issue 1350

RE5's own title says *"the window never shows one class list in two different
orders at once"*. **A new dump breaks it**, because `rdw::push` does not
re-slot:

```
two Ups     store gds ids gm     M1's block gds ids gm
push M1     block 0 (NEWEST)  ids gds gm   <- raw order
            block 3 (oldest)  gds ids gm   <- the store's order
```

Both fixes change a decision the batch already took. Re-slotting in `push` was
**measured to red row RE0's own control** (it golds the M1 block at
`{ids gds gm}`; the seed order is `ids gm gds`) — that is a decision about what
the window IS, not a repair. Overruling the other way deletes RE5. Filed as
**1350** with all three options; **rule debt
`1350_R2_does_a_new_dump_follow_the_store`**. The existing debt
`1338_R2_every_block_of_the_class_follows` covers "an older dump re-orders under
you" and not "and the newest one then disagrees with it", which is why it is
separate.

### RED before green

The four new rows were driven against the shipped `src/rdw.tcl` restored from
`HEAD` over the working file, then restored by `cp` with **`md5sum` verified
identical** before any number below was taken:

```
FAIL: RE8 …    FAIL: RE9 …    FAIL: RE10 …    FAIL: RE11 …
RESULT: 4 FAILED (141 passed)
```

and `ALL PASS (145)` with the fix. **No pre-existing row moved in either
direction in that sabotaged run** — the 141 that passed are the 141 that passed
before, which is also the measurement that says these four are the only rows in
the suite that can see any of this.

### Name+status diff

Every suite below is asserted to have printed a RESULT line.

| suite | how | before | after | rows that moved |
|---|---|---|---|---|
| `test_rdw_window_1245` | `--nogui` | ALL PASS (141) | **ALL PASS (145)** | RE8 RE9 RE10 RE11 added; nothing else moved |
| `test_rdw_window_1245` | `:99` | ALL PASS (153) | **ALL PASS (157)** | the same four |
| `test_rdw_keys_1245` | `:99` | ALL PASS (77) | **ALL PASS (77)** | none |
| `test_op_param_store_1245` | `--nogui` | ALL PASS (130) | **ALL PASS (130)** | none |
| `test_op_annot` *(control)* | `--nogui` | ALL PASS (485) | **ALL PASS (485)** | none |

### Issue 1330's header, fixed rather than re-recorded

The code fix landed with R2 and the file still opened *"Status: FILED, NOT
FIXED"*. **Four crews in a row wrote that down instead of editing one line.** It
now reads FIXED, names row RE6 as the fence, and carries the lesson: a status
line is read by everyone and re-derived by nobody.

### No look debt

Nothing new is drawn. The one thing a human sees is a status sentence, and its
wording rides the standing rule debt `1245_B3_window_wording` like every other
sentence in this window; the decision behind it is on `1347_R2_summary_order_on_the_sheet`.

---

## Round 3 — the repair round's own adversaries (issue 1351)

The repair round put four crews on the four confirmed defects. Their adversaries
came back **REFUTED, HOLDS_WITH_CAVEAT, REFUTED, REFUTED** — every suite green
throughout, again. What follows is what the driver fixed from those reports and
what it deliberately did not.

### The shared cause, and why it gets one number

Each of the four is **a fix's own new failure mode, invisible to the rows that
shipped with the fix.** Issue 1332's fix introduced three; issue 1344's
introduced one. That is the batch's oldest lesson arriving for the third time:
a suite proves the defect it was written about and nothing else.

### Fixed here

| # | what | fenced by |
|---|---|---|
| A | `KX_FLOOR` was never raised for SD5–SD7, so the guard had three rows of slack over the three rows that fence issue 1332 itself | the floor, 74 → 81 across this commit |
| B | `sd_poll_modal` waited on a bare `[grab current] ne {}` — every grab the application holds, not the dialog's | **SD8** |
| C | `sd_arm` overwrote its predecessor's timer handles instead of cancelling them, turning a one-shot stray timer into a self-re-arming chain that lives across rows | **SD9** |
| D | the give-up was a poll count that measured **6.0–6.5 s at load average 54**, past the 5 s deadman it was documented as sitting inside | **SD10** |
| E | `rdw::status` replaced the status entry's text and left the user's selection **indices** standing over the new sentence, so the next Ctrl-C silently copied a slice of a refusal message | **CP16** |

**Every one proved by a sabotage that reds exactly it**, each applied to the repo
file and restored by `cp` from a gold copy with the md5 verified afterwards
(`9d9d5f2090343ff10faebb55c70ed9fc` for the suite,
`17339010560a05d7e57d0e972b61bccf` for `src/rdw.tcl`), `git status --short`
empty after each.

### Acceptance

| suite | how | before | after | rows that moved |
|---|---|---|---|---|
| `test_rdw_keys_1245` | `:99` | ALL PASS (77) | **ALL PASS (81)** | SD8 SD9 SD10 CP16 added; nothing else moved |
| `test_rdw_keys_1245` | `$DISPLAY` (VcXsrv) | 5 FAILED (72) | **5 FAILED (76)** | the same four added; the five reds are RA1–RA5, issue **1343** |
| `test_rdw_window_1245` | `--nogui` | ALL PASS (145) | ALL PASS (145) | none |
| `test_rdw_window_1245` | `:99` | ALL PASS (157) | ALL PASS (157) | none |
| `test_op_param_store_1245` | `--nogui` | ALL PASS (130) | ALL PASS (130) | none |
| `test_op_annot` *(control)* | `--nogui` | ALL PASS (485) | ALL PASS (485) | none |

Three consecutive `:99` runs at 81. Every count read off a printed RESULT line.

### NOT fixed, and why

Everything else the adversaries found needs a **ruling**, and guessing at a
ruling is the move this batch exists to avoid. They are in the user's queue:

- `1344_the_status_line_receipt_goes_stale` — the receipt keeps the **previous**
  sentence rather than going silent, so the line can contradict the clipboard.
- `1344_two_highlights_after_a_status_line_drag` — two selection-coloured
  regions in one window, and the pane's highlight disagreeing with Ctrl-C.
- `1349_the_pane_order_flips_between_lists_on_Add`,
  `1349_Delete_and_Add_now_wipe_the_pane_selection` — item P4's adversary.
- Issue **1343** — item R4's raise on the user's own VcXsrv. Needs their screen.
- New rule debt **1351**, because fix E is a *third* answer to the question
  `1344_the_status_line_receipt_goes_stale` already asks.

Two more, reported and off this batch's path: `bind Entry <<Copy>>` is a second
clipboard door on the status entry, and — found by P2's adversary — `input_line`
(`src/xschem.tcl:14146-14152`) runs its typed text through `eval`, so typing
`7 ; set ::INJECTED yes` into **Simulation > Set netlist / graph / annotation
precision** sets the precision *and* executes the second command. That is
arbitrary Tcl from a shipped menu, shared by every `input_line` caller. Not this
batch's file, not touched, and it wants its own number.

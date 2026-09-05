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
| R4 | 1340 | raise the window when something is sent to it | not started |
| R5 | 1341 | engineering notation | not started |
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

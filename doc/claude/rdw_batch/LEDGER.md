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
| R2 | 1338 | Up/Down move the row and the sheet follows | not started |
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


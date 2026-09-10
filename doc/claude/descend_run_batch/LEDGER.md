# LEDGER — descend_run_batch

Baseline taken 2026-09-08 at HEAD `19f8e351`, binary rebuilt (`make -C src`
reported "Nothing to be done" — the last two commits were Tcl only).

## Baseline, `--nogui`, by name and status

| suite | status | checks |
|---|---|---|
| test_ase_core | ALL PASS | 203 |
| test_ase_window | ALL PASS | 32 |
| test_op_annot | ALL PASS | 485 |
| test_ase_final | ALL PASS | 82 |
| test_op_dump_altshow | ALL PASS | 70 |
| test_descend_doors_1228 | ALL PASS | 31 |
| test_descend_fidelity | ALL PASS | — |
| test_descend_preserve | ALL PASS | — |
| test_raw_read_failure_0306 | ALL PASS | 63 |
| test_op_param_store_1245 | ALL PASS | 165 |
| test_annot_declutter_1244 | ALL PASS (on `:99`; no banner under `--nogui`) | 134 |

`test_ase_window` is 245 on `:99` and 32 under `--nogui`; the 32 is the headless
subset, not a regression.

**Floors are RAISED when rows are added and NEVER lowered.**

## Items

| item | file(s) | status | receipt |
|---|---|---|---|
| A — round trip + `ase::netlist` | `src/ase.tcl`, `tests/headless/test_ase_core.tcl` | **DONE** — 6 new procs at `src/ase.tcl:5989-6175`, `netlist_in_place`/`netlist` split at `:6356`/`:6390`; rows RT0–RT12 | `receipts/01-item-A-round-trip.md` |
| B — the door | `src/ase_window.tcl`, `tests/headless/test_ase_window.tcl` | **DONE** — one predicate swapped in two places (`ase::ui::do_run`, `src/ase_window.tcl:7228`), one sentence; rows R1–R14 | `receipts/02-item-B-the-door.md` |
| C — pinning + end-to-end rows | `tests/headless/test_op_annot.tcl` (+ the bench end-to-end row) | **NOT IN THE WORKING TREE at item D's write-up (2026-09-08).** `git status` shows only `src/ase.tcl`, `src/ase_window.tcl`, `test_ase_core.tcl`, `test_ase_window.tcl` modified; `test_op_annot.tcl` is untouched and `tests/headless/test_ase_core.tcl:2859` still says "the end-to-end byte-identity row is item C's". The `cmp`-identical netlist was measured **by hand** by crew A, not by a committed row. **Do not read the closed 0643 as meaning C landed.** | *(none yet)* |
| D — write-up, 0643, 1393, 1394 | docs, `owed.sh` | **DONE** — 0643 closed FIXED; issues 1393 and 1394 minted and recorded in `NUMBERING.md` (tail → 1395); `doc/claude/specs/ase_l.md` new section at `:625`; 2 rule debts + 1 look debt added | `receipts/04-item-D-writeup.md` |

## Floors after this batch — RAISED, by name

| suite | arm | before | after |
|---|---|---|---|
| `test_ase_core` | `--nogui` | 203 | **216** |
| `test_ase_core` | `:99` | 203 | **216** |
| `test_ase_window` | `--nogui` | 32 | **49** |
| `test_ase_window` | `:99` | 245 | **267** |

Unchanged and re-run green by the crews: `test_ase_final` 82,
`test_ase_final_gf180` 35, `test_ase_persist` 34, `test_ase_view` 32,
`test_op_dump_altshow` 70, `test_op_annot` 485.

## Debts this batch leaves

| kind | id / subject | what it is |
|---|---|---|
| rule | **0643** | the two refusal tails (crew B's B-1 / B-2) — user-visible words nobody ratified |
| rule | **1393** | the `annot_ensure_loaded` level hole stays UNBUILT — a judgement, not a fact |
| look | ascend/re-descend flicker | drawcount delta 1 is evidence, not eyes; needs the user's own screen |
| — | **item C** | still owed, above |
| — | issue **1394** | pre-existing modal hang, filed not fixed |

---

## Closing audit — `full_audit.sh`, 2026-09-08, dev display `:99` (openbox live)

The run was killed by the harness at **293 of ~449** suites, so this is a partial
audit and is recorded as one. Every non-PASS in those 293 is attributed:

| suite | verdict | attribution |
|---|---|---|
| `test_altf5_ciw` | pre-existing | issue **0846**. Bisected this session: PASS at `eec684ff`, FAIL at `cc92d0b6` — the CIW-font commit whose own A/B was invalid because 0846's issue file was committed *in* it, so "restore from HEAD" restored the post-change files. 0846's two candidate causes also settled: cause (1), and the raise is DEFERRED ~1 s. |
| `test_ase_core` | pre-existing | row **C11** vs issue **0609**. C11 is a GLOBAL `file exists $repo/untitled~.sch` check and `full_audit.sh:64` cds to `$REPO`, where 80-odd earlier suites leak. **FAIL in 13 of 13 recorded op_param audits**, uncaused until now. **ALL PASS (224) standalone, both arms.** |
| `test_op_dump_altshow` | pre-existing | row **H1**, the same defect with a wider glob (`untitled*`, which also catches `untitled~.sym`). **ALL PASS (70) standalone, and measured to leave NOTHING behind** — it was reporting another suite's leftover. Did not exist when the 13 audits were taken. |
| `test_cadence_drag` | pre-existing | FAIL in 13/13 recorded audits; in the merge-5 known-15. |
| `test_cosim_golden_e2e` | pre-existing | FAIL in 13/13 recorded audits. |
| `test_lib_manager_gui` | pre-existing | FAIL in 13/13; known-15. |
| `test_lib_sweep` | pre-existing | FAIL in 13/13; known-15. |
| `test_rotate_stretch_short_0104` | pre-existing | FAIL in 13/13; known-15. |

**Zero new red names.** The two that are not in the merge-5 list were both run
standalone on a cleaned repo root and are green.

## T1

`cd tests && tclsh run_regression.tcl`, **solo**: **0 counted failures**, no
`couldn't execute`, no `exit 127`. A concurrent `run_regression.tcl` was live in
a DIFFERENT repo at the time; `open_close.tcl:37` builds `$workroot` as the
relative `"$testname/results/.work"`, so the two cannot collide (issue 0990 is
about two runs in ONE tree).

## Final floors

| suite | arm | before | after |
|---|---|---|---|
| `test_ase_core` | `--nogui` / `:99` | 203 / 203 | **224 / 224** |
| `test_ase_window` | `--nogui` / `:99` | 32 / 245 | **49 / 267** |
| `test_op_annot` | `--nogui` | 485 | 485 |
| `test_ase_final` · `_gf180` · `persist` · `view` | `--nogui` | 82 · 35 · 34 · 32 | unchanged |
| `test_op_dump_altshow` | `--nogui` | 70 | 70 |
| `test_annot_declutter_1244` | `:99` | 134 | 134 |

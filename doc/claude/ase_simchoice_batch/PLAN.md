# Plan

Four crews. A must land before B and C, because both consume A's API.

| crew | scope | files |
|---|---|---|
| **A** | the core split | `src/ase.tcl`, `tests/headless/test_ase_simreg_0931.tcl`, `test_ase_core.tcl` |
| **B** | the dialog and the dirty/prompt path | `src/ase_window.tcl`, `test_ase_simdlg_0937.tcl`, `test_ase_window.tcl` |
| **C** | persistence and the quit prompt, proved | `test_ase_persist.tcl`, a new suite if the rows do not fit |
| **D** | issue 1395, NUMBERING, help text, spec | `doc/claude/`, the one help block in `src/xschem.tcl` |

Order: A + D in parallel; then B + C in parallel; then the lead verifies.

## The twelve fixes

1. `ase::sim_default` beside `ase::sim_use` — installation default vs what is in force. (A)
2. New ASE-L state key `sim_entry`, in `omit_if_empty` so 104 committed `.state` files stay byte-identical. (A)
3. Three-value encoding — `{}` / `none` / `{name <entry>}`, one decoder shared by both. (A)
4. `sim_register` / `sim_unregister` write the conf immediately, through every door, gated on `sim_origin eq session`. (A)
5. `sim_clear` deliberately does not write — teardown is not a choice. (A)
6. The in-force combobox stops writing to disk; it sets the state key. (B)
7. Dirty means dirty — marker, explicit save, quit prompt. (B, proved by C)
8. The run applies the running session's `sim_entry` before resolving. (A, exercised by C)
9. A failed save is reported at the door that made it, the CIW included. (A mints, B renders)
10. `sim_write_body` writes `sim_default`, never `sim_use`. (A)
11. Docs: `xschem.tcl:4935`, `ase_window.tcl:4473`/`:4649`, `specs/ase_l.md`. (D, and B for its own file)
12. Issue 1395 + NUMBERING advanced in the same commit; floors raised in five suites. (D, all)

## Acceptance

* Every touched suite green with floors RAISED, never lowered; report before/after per suite.
* The 104 committed `.state` files still round-trip byte-identically.
* A measured end-to-end on the user's own gesture shape: register from the CIW -> file on disk;
  change the in-force choice -> session dirty, nothing on disk; quit -> prompt.
* `run_regression.tcl` **solo** (issue 0990), T1 at ZERO counted failures.

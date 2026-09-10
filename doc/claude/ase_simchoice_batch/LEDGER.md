# Ledger

| # | fix | crew | status |
|---|---|---|---|
| 1 | `ase::sim_default` beside `ase::sim_use` | A | **done**, lead-reviewed |
| 2 | `sim_entry` state key, `omit_if_empty` | A | **done**, lead-reviewed |
| 3 | three-value encoding + shared decoder | A | **done**, lead-reviewed |
| 4 | register/unregister persist through every door, origin-gated | A | **done**, lead-reviewed |
| 5 | `sim_clear` deliberately does not write | A | **done**, lead-reviewed |
| 6 | in-force combobox sets state, not disk | B | **done** |
| 7 | dirty marker, explicit save, quit prompt | B / C | C **done** (B1-B8, Q1-Q7, `test_ase_simchoice_1395`); B dispatched |
| 8 | run applies the running session's choice | A | **done**, lead-reviewed |
| 9 | failed save reported at the door that made it | A / B | **done** — one sentence, rows S8 / S11 |
| 10 | `sim_write_body` writes the default | A | **done**, lead-reviewed |
| 11 | docs: help text, spec, door comments | D / B | **done** |
| 12 | issue 1395 + NUMBERING + floors | D / all | 1395 filed, NUMBERING -> 1396 |

## Floors — raised, never lowered

| suite | before | after |
|---|---|---|
| `test_ase_core` | 224 | **230** |
| `test_ase_simreg_0931` | 95 | **111** |
| `test_ase_simdlg_0937` | 48 / 5 | **55 / 5** |
| `test_ase_persist` | 34 / 137 | **44 / 147** (headless / display+ngspice) |
| `test_ase_window` | 267 | 267 (unmoved, deliberately) |
| `test_ase_simchoice_1395` | NEW | **31** |
| `test_ase_simchoice_1395` (NEW, crew C) | — | **31**, same on both arms |

## Debts incurred

* `rule` — DECISIONS D5, the two-window shared `sim_use`. Filed against 1395 once
  crew D mints the number. Clears only when the user says so.

## Hazard crew A found, and what closes it

Making `ase::sim_register` a writer made every suite that registers a stub a
potential writer of the user's own `~/.xschem/ase_simulators`. Fourteen suites
register; seven had no isolation. Crew A added the `ase::sim_autosave` seam and
isolated all seven by hand. **Crew C's lint row L1 of
`tests/headless/test_ase_simchoice_1395.tcl` now stops the eighth**: it scans
every `tests/headless/test_*.tcl` for the first uncommented call to a registry
writer (`ase::sim_register` / `ase::sim_unregister`) and reds, naming the file
and the line, unless a `set ::USER_CONF_DIR` redirect, a
`set ::ase::sim_autosave 0` or a `test_sim_registry_isolate` call comes first.
The user's file was verified byte-identical (md5 `d66a9afd1a3bf1a32ae1112c3ea88558`,
336 bytes, mtime 2026-09-08 18:03:24) after crew A landed.

## Open question for the user (do NOT invent an answer)

Nothing in a session can change `ase::sim_default`. After the first-ever
registration the installation default is pinned, so issue 0932's "hand control
back to my PATH, as the default" gesture — made from the CIW with no ASE-L
session open — has no home but a hand edit of the conf file. Wants either a
"make this the default" gesture or a ruling that the pinned default is right.

## Lead verification, 2026-09-08

Suites, on the dev display (:99, openbox 3.6.1), all ALL PASS:
`test_ase_simreg_0931` 111, `test_ase_simdlg_0937` 55, `test_ase_core` 230,
`test_ase_persist` 147, `test_ase_simchoice_1395` 31, `test_ase_window` 267.

**T1 (`run_regression.tcl`, run SOLO per issue 0990): ZERO counted failures**,
zero launch failures.

End-to-end on the user's own ruling, measured by the lead independently of every
crew, `::USER_CONF_DIR` redirected to a scratch directory:

```
conf file before any registration              absent
after two ase::sim_register (CIW door)         ON DISK
  file names both entries                      1
session dirty before the choice                0
session dirty after picking ng-b               1
conf mtime moved?                              no
conf still names the DEFAULT not the pick      ng-a  (correct)
prompt_all_on_quit ->                          1
  ask_save_close FIRED?                        YES (correct)
dirty after explicit Session > Save            0
choice on reload from disk                     entry ng-b
conf mtime STILL unmoved by the save           no
```

`~/.xschem/ase_simulators` verified md5 `d66a9afd1a3bf1a32ae1112c3ea88558`,
336 bytes, mtime 2026-09-08 18:03:24 — before the batch, after every crew, and
after T1.

## Debts recorded (the user's queue)

* `rule 1395` — the two-window shared `ase::sim_use` (DECISIONS D5).
* `rule 1395-default` — nothing in a session can change `ase::sim_default`.
* `look` — the Setup > Simulators gesture on the user's own screen, six things
  to judge.
* `suite` — `test_ase_simdlg_0937` on `:0`, deduped onto the existing entry.

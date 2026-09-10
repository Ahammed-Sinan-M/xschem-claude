# Ledger — ASE-L UX batch

## ⚠ INCIDENT 2026-09-09 13:38 — an audit agent ran the user's bench and destroyed its raw file

**What happened.** During the twelve-lens UX audit (workflow `wf_5fe86bd2-40c`, 13:08–13:43),
one of the eleven auditor agents drove `Netlist and Run` on the user's real
`sky130_tests_ase/tb_bandgap` bench. The lead's brief told the agents they could verify
findings against the live binary and did **not** forbid a simulation run. That is the
lead's error, not the agent's.

**What it cost.** ASE-L's run directory for that bench is `~/.xschem/simulations` — the
directory the standing rule protects — because `ase::rundir` with an empty `rundir` key
returns `set_netlist_dir 0` (`src/ase.tcl:4819`), one global directory for every state of
every cell. The run therefore wrote over the user's own artifacts and was then killed when
the agent's xschem process exited:

| file | before | after |
|---|---|---|
| `tb_bandgap_ase.raw` | 20502-point transient, from the user's 09:55 run | **GONE.** ngspice creates the raw at start; the process died mid-run and left none |
| `tb_bandgap_ase.log` | the full run — `VBG = 1.177085e+00`, `START = 1.803088e+00`, `i(VCC) = 2.895431e-05`, `=== exit 0 after 8.12 s ===` | a 356-byte header stub with no ngspice output and no exit line |
| `tb_bandgap.spice` | 14862 bytes, 09:55 | rewritten 13:38:41 (same netlister, same design — content expected identical, mtime moved) |
| `tb_bandgap_ase.spice` | 09:55 | rewritten 13:38:42 |

**What survived.** `tb_bandgap_ase.opinfo` (280 253 bytes, 09:55) is untouched — the OP
annotation data is intact. Nothing in the repo working tree was modified. The user's
`~/.xschem/ase_simulators` is byte-identical (`670992081b2f182c2c8f20854169d84e`,
mtime 09:55:19, unmoved). No committed `.state` file moved.

**Recovery.** The raw is a generated artifact and is not in git. The only way back is to
press `Netlist and Run` on that bench again — about eight seconds — which writes to the
same directory. That is the user's call, not the assistant's.

**The screenshot of the old log survives** as evidence of what was there:
`doc/claude/ase_l_ux_batch/shots/logwin.png`.

**Rule tightened for every crew from here.** `CREW_BRIEF.md` already forbids touching
`~/.xschem`. It now has to say the part that was implicit and therefore missed: *a
simulation run IS a write to `~/.xschem/simulations`, because that is where ASE-L's run
directory resolves.* No crew runs a simulation on a bench under `sky130A/`. Probes that
need a run use a scratch library and an explicit `rundir`.

**This is also finding F5's cost, made concrete.** `PLAN.md` Stage F5 proposes keying
`ase::rundir` on lib/cell/view. Had that landed, the agent's run would have written to
`ngspice_state1`'s own directory and the damage would have been confined to the state it
was driving.

---

## Baseline, recorded before crew A started

```
437a3add                          git HEAD
670992081b2f182c2c8f20854169d84e  ~/.xschem/ase_simulators (332 bytes, mtime 09:55:19)
f3ed38843b612c6f269b09304ae1d3de  sky130A/.../tb_bandgap/debug_st1/tb_bandgap.state
f85cfd79f6ff9ad4bdae1fb87b755a73  sky130A/.../tb_bandgap/ngspice_state1/tb_bandgap.state
104                               committed .state files
```

## Item 1 — Save State confirm  (issue 1396)

| | |
|---|---|
| status | **DONE** |
| commit | `5fb8f465` fix(1396): Save State asked nothing before it destroyed an existing state |
| T1 | **0 counted failures, 0 launch failures, 0 `exit -1`, 0 NODISPLAY arms** — run solo in the foreground, full parallelism, scratch `HOME` plus `XSCHEM_DEVDISPLAY_DIR` |
| ledger | rule **1396** (the sentence, the untitled-session rule S-3, unwritable-fails-silently), rule **1397** (the geometry eviction), look `ase_l_1396_overwrite_confirm` |

The UX audit and the thirteen closed look debts went in first, as `66992a1d`, so this
commit's citations resolve.

**Crew.** A1 implement, A2 pin, then two adversaries in parallel.

**What the adversaries found, and what the lead did with it.**

| # | finding | disposition |
|---|---|---|
| 1 | `test_ase_savestate_adopt` regressed to 6 FAIL **and hung for 300 s** — its Part B drives an untitled session's real menu Save-As onto a view Part A created, so the new confirm fires and the form stays up behind it forever | **FIXED.** Wait-and-press added, floor 26 → 27, `ALL PASS (27 checks)` |
| 2 | The gate was real for the mouse and theatre for the keyboard: the Save-As form submits on `<Return>`, `ase::ui::confirm` focuses OK and binds `<Return>` to proceed, so Return raised the popup and Return destroyed the file | **FIXED.** `ase::ui::confirm_safe_default`, at the destructive caller and not in the shared confirm. Pinned by G8c; sabotaged, and the sabotage reds `Return wrote NOTHING` — the file dies |
| 3 | Escape on the Save-As form orphaned the confirm: form gone, destructive button still live and still writing. Re-opening the form was the same defect twice, a form naming one view above a confirm naming another | **FIXED.** `ase::ui::confirm_owned_by` binds the form's `<Destroy>`. Pinned by G8c, both spellings |
| 4 | Three `:321-335` citations stale the day they land, plus `:5460` and `~:3016` | **FIXED.** Line ranges replaced by section names — a section survives an edit, a line range does not |
| 5 | S-6 claimed an unwritable target "fails through the existing error path"; driven at 0444, there is no such path — it fails **silently** | **CORRECTED** in DECISIONS.md, and recorded on the ledger as part of rule 1396 |
| 6 | The confirm is not `wm transient` and lands ~1100 px away (measured 3/3 on openbox) | **RECORDED**, not fixed: pre-existing for every ASE-L dialog, PLAN.md Stage 2 owns it. In issue 1396 and in the look debt |
| 7 | Overwriting a state open in another window says nothing about that window | **RECORDED** in issue 1396 |
| 8 | On a legacy FLAT library the resolver answers `<cell>.sym` for any non-schematic view, so the predicate says "exists" for a view that does not | **RECORDED** in issue 1396 |
| 9 | Suite runs had rewritten the user's real `~/.xschem/geometry`, evicting 50 of 101 entries | **FILED as issue 1397** + rule debt. Every run from here goes through a scratch `HOME`, measured to give the identical check count and leave the file byte-identical |

**Suites, all on `:99` with openbox 3.6.1 live, under a scratch `HOME`:**

```
test_ase_dialogs          ALL PASS (215)   floor 176 -> 215   / 37 --nogui (was 21)
test_ase_savestate_adopt  ALL PASS  (27)   floor  26 ->  27
test_ase_window           ALL PASS (267)   unmoved
test_ase_persist          ALL PASS (147)   unmoved
test_ase_core             ALL PASS (230)   unmoved
test_ase_final            ALL PASS  (82)   unmoved
test_ase_interact         ALL PASS  (64)   unmoved
test_ase_launch           ALL PASS  (44)   unmoved
test_ase_plot             ALL PASS (151)   unmoved
test_ase_simchoice_1395   ALL PASS  (31)   unmoved
test_ase_simdlg_0937      ALL PASS  (55)   unmoved
```

**Sabotage, both new procs, restored by `cp` from a pristine copy and md5-compared —
no `git checkout/restore/stash/clean` at any point:**

```
confirm_safe_default -> no-op   5 FAILED (210 passed)   incl. "Return wrote NOTHING"
confirm_owned_by     -> no-op   2 FAILED (213 passed)   both orphan rows
```

## Operational notes from item 1, for whoever runs T1 next

**`run_regression.tcl` at full parallelism was killed for memory on this box.**
`test_njobs` (`tests/test_utility.tcl:65`) is CPUs − 4 with "no user-facing knob by
design" — 16 concurrent xschem processes on 20 CPUs and 15.7 GB. The first solo run died
mid-`open_close` with the system low on memory; nothing had failed. `taskset -c 0-7` in
front of `tclsh` is the external knob: `nproc` honours the affinity mask, so the harness
computes 4 jobs instead of 16 without the harness being touched.

**A scratch `HOME` hides the dev display from the harness.** The first T1 came back
`Total num fail: 0` with a `NODISPLAY: ... THIS ARM VERIFIED NOTHING` line for every GUI
suite, because `devdisplay.sh`, `gui_gate.sh`, `xvfb_arm.sh` and `spawn_reaper.sh` all
resolve their state dir under `$HOME`. A clean zero that verified half of what it looked
like it did. Export `XSCHEM_DEVDISPLAY_DIR=$HOME_REAL/.claude/xschem_dev_display`
alongside the scratch `HOME`. Written into issue 1397, which proposes the scratch `HOME`
as a fix and would otherwise have proposed a trap.

## Item 2 — font and theme derivation  (issue 1398)

| | |
|---|---|
| status | built, attacked, repaired, suites green, T1 clean |
| T1 | **0 counted failures, 0 launch failures, 0 `exit -1`, 0 NODISPLAY arms** |

**Crew.** B1 implement, B2 pin, then three adversaries in parallel: pixels, downstream
consumers, and the displays that are not `:99`.

**What the adversaries found, and what the lead did with it.**

| # | finding | disposition |
|---|---|---|
| 1 | Owning `-foreground` without `-readonlybackground`/`-disabledbackground` made the dark scheme WORSE: the Simulators row editor's readonly `Name:` field went 12.635:1 → **1.662:1**, in the very scheme the change exists to fix | **FIXED**, then fixed again — `table` restored the contrast but made a readonly field look editable, so it takes `disabledbg`: 14.877:1, identical in both schemes |
| 2 | Deriving the widths traded the ratchet for an overflow: `Save Options` left the viewport below 740 px, 30% of the Outputs pane unreachable at 560×360, and `build_pane` never had a horizontal scrollbar | **FIXED.** Gridded horizontal bar, shown only on a change of state |
| 3 | The narrowed combobox glob desynchronised the waveform viewer: with the knob set, the entry scaled and its popdown did not | **FIXED** — and the lead's first fix broke the ASE-L window's own popdowns, because every ASE-L dialog IS a toplevel. Root path component, not `winfo toplevel` |
| 4 | The live knob rescaled the fonts and left the columns: **6 of 11 headings clipped** after one mutation, the anti-clip floor itself stale | **FIXED.** `retune_columns`, guarded on a real change of font metric |
| 5 | `ase::font_size` returned the raw string, permanently defeating the `_mkfont` no-op guard | **FIXED**, one line |
| 6 | A runtime `tk scaling` call splits realized from unrealized fonts | **RECORDED** in issue 1398. No shipped path does it |
| 7 | Nothing clamps the window's natural size to the screen; at scaling 4.0 it asks for 2099×1160 on a 1920×1080 screen | **RECORDED** in issue 1398. Pre-existing, made wider by the derived columns |
| 8 | The implementer's `apply_theme` perf figures were unreproducible | **CORRECTED** — head-to-head it is ~2.1× FASTER, a stronger result than claimed |
| 9 | `test_wave_sigbrowser_0312` red (BF21a, BF24a) on the display arm | **FILED as issue 1399** after proving it pre-existing against a shadow tree; it is not in T1's case list |

**Suites, `:99`, openbox 3.6.1, scratch `HOME` + real `XSCHEM_DEVDISPLAY_DIR`:**

```
test_ase_window          ALL PASS (295)   floor 267 -> 295  / 49 -> 56 --nogui
test_ase_dialogs         ALL PASS (215)   test_ase_core        ALL PASS (230)
test_ase_persist         ALL PASS (147)   test_ase_final       ALL PASS  (82)
test_ase_interact        ALL PASS  (64)   test_ase_launch      ALL PASS  (44)
test_ase_plot            ALL PASS (151)   test_ase_savestate_adopt ALL PASS (27)
test_ase_simreg_0931     ALL PASS (111)   test_ase_simcaps_0948 ALL PASS (110)
test_ase_simchoice_1395  ALL PASS  (31)   test_ase_simdlg_0937 ALL PASS  (55)
test_calc_skeleton       ALL PASS (545)   test_calc_widgets    ALL PASS (244)
test_rdw_window_1245     ALL PASS (267)   test_wave_sigsearch  ALL PASS (250)
test_wave_sigbrowser_0312   2 FAILED (67 passed)  <- PRE-EXISTING, issue 1399
```

**One red that was mine and was litter, not a regression:** `test_ase_core` C11 caught an
empty `untitled~.sch` dropped in the repo root by this session's own probe launches
(issue 0609's row, doing exactly its job). Removed; 230 ALL PASS.

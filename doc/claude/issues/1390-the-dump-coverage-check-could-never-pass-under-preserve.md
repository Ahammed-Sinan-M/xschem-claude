# 1390 — the dump coverage check could never pass under `preserve`

**Filed** 2026-09-08, item C of the ASE-L run-guard batch
(`doc/claude/ase_run_guard_batch/CREW_BRIEF.md`).
**Status** FIXED. One rule debt (the fold is unconditional and does not consult
the run's case mode — §5 states the alternatives that were refused and why, and
the choice is the user's to ratify).
**Files** `src/ase.tcl` (`ase::op_report_missing_dump`),
`tests/headless/test_op_dump_altshow.tcl` (section **Y**, rows Y6–Y10).

## 1. What the user saw

Their 14:07 run on 2026-09-08 printed, as a red `#!` line in the CIW:

> This run collected device numbers into `tb_bandgap_ase.opinfo`, but only **0
> of the 78** devices your schematic asks about are in it, so the rest of the
> rows will be blank.

The annotation on that run was **perfect**. Nothing was missing, nothing was
blank, and the sentence was wrong in every clause that carries a number. This
is not a hypothetical: it fired on the user's own bench, on a good run, and it
fires on **every** run of that bench.

## 2. The defect, in one line

`ase::op_report_missing_dump` built its `have` set from the dump's block
headers **verbatim** and compared it against `devs`, which
`op_annot::devpath` lowercases on every path out (`op_annot::_lower`,
`op_annot.tcl:590`, deliberately and by measurement). The user's
`ngspice-ver50` is registered `-casemode preserve` (`~/.xschem/ase_simulators`
line 4), so `show all >` writes

    M.x1.x23.XM2.Msky130_fd_pr__pfet_01v8:

and the exact-case compare matched nothing at all. **Under `preserve` the
check could never pass.**

## 3. Measured, 2026-09-08, this tree, binary current

Driven directly through `ase::op_report_missing`, one device, same file, same
everything but the spelling of the block header:

| dump header | verdict, before the fix | after |
|---|---|---|
| `m.x1.x23.xm2.msky130_fd_pr__pfet_01v8` | *(silence)* | *(silence)* |
| `M.x1.x23.XM2.Msky130_fd_pr__pfet_01v8` | **`op_dump_partial`** | *(silence)* |
| `q.other.qpnp` (genuinely absent) | `op_dump_partial` | `op_dump_partial` |

**And the numbers were never in doubt.** Merge a `preserve`-cased dump, then
ask for it in the schematic's own lowercase spelling:

    exact query     -> 1.37276e-12
    lowercase query -> 1.37276e-12

Rung 2 of `save.c`'s one lookup ladder (`raw_lookup_name`, `save.c:4175`:
exact spelling first, then the case-folded alias) does the work. So this was
purely a **diagnostic that lies** — the data behind it was correct throughout,
which is what makes it worse than a silent failure rather than better: it sends
a user to look for a fault that is not there. The user's own action log line 64
shows them going to `Outputs > Save All…` because of a related false diagnosis
(issue 1392).

## 4. The fix

`ase::op_report_missing_dump` now runs the C ladder's own shape, in Tcl:

* the **exact** spelling first, so an all-lowercase dump answers on rung 1 and
  is byte for byte what it always was;
* then the **case-folded alias**;
* **O(names + devs)**, one pass to build the two tables and one to consult
  them — the same complexity contract `ase::op_report_missing`'s own comment
  states for the raw-side comparison it sits beside.

Two dump headers that differ only in case **decline**. That is `save.c`'s
policy and not a second one: `raw_build_fold_table` (`save.c:4111`) stores `-1`
for exactly this and the fuzzy rung then refuses rather than guess
(DECISIONS.md **D2**). This table poisons the folded key and the device counts
as missing. Byte-identical repeats are not a collision there and cannot arise
here at all — `op_annot::opdump_devices` de-duplicates its own headers.

**The sentence itself is untouched.** The wording is ratified; the comparison
was what was broken, and the fold does not falsify a clause of it — *"those
devices are spelled differently in the deck than on the sheet"* is still what a
surviving miss means, now that a case-only difference is no longer one.

## 5. RULING — the fold is unconditional, and does not consult the case mode

`distinguish` is the one mode where a fold is not free: `raw_case_mode_parse`
(`save.c:2731`) maps `preserve` to case_sensitive **0** and **only**
`distinguish` to 1. So this is stated rather than assumed. Four reasons, in the
order that decided it:

1. **One side carries no case at all.** `devs` is lowercase by construction, so
   there is no case-sensitive comparison available here to be right or wrong
   about. An exact compare under `distinguish` is false on every device — which
   is today's defect unmoved, not `distinguish` honoured.

2. **The run's requested mode is the WRONG gate**, and gating on it would be a
   new false alarm one mode over. What suppresses the C fold rung is
   `Raw.case_sensitive` (`raw_fold_index`, `save.c:4161`), a property of the
   **read** — not of the mode the simulator was asked for. A `-casemode
   distinguish` run writes a mixed-case dump into a database that still folds,
   so its rows annotate exactly as `preserve`'s do, and a check gated on
   `ase::sim_casemode_requested` would print `op_dump_partial` over them.

3. **`Raw.case_sensitive` is the honest gate and cannot be asked from here.**
   This proc runs from `ase::run_done`, before this run's raw is attached; the
   database that happens to be loaded describes **another** run, and steering by
   it is what `netlist_case_mode`'s comment (`save.c:3516`) forbids in as many
   words. Nor is it reachable in practice — `grep -n 'raw read .*-case\|raw
   case 1' src/*.tcl` still finds no caller (`wave_viewer.tcl:3108`'s standing
   note, re-measured 2026-09-08). Measured both ways on this tree:

   | `xschem raw case` | lowercase query against a `preserve`-cased merged column |
   |---|---|
   | `0` (every shipped route) | `1.37276e-12` |
   | `1` (forced by script) | *(blank, column still present)* |

   So the fold rung is live on every road a user can click, and folding
   predicts the lookup that will actually run.

4. **Direction of the error.** This proc emits a WARNING, so folding can only
   make it quieter, and the one thing it quietens is a database a script
   deliberately made case-sensitive — where `op_annot`'s own blank rows are the
   evidence anyway. Not folding costs a red line on **every** good run.

### The alternatives, refused

* **Gate on `ase::sim_casemode_requested $sim`.** Refused by measurement, §5.2:
  it is a statement about the simulator's spelling, not about xschem's lookup,
  and it would fire on a healthy `distinguish` bench.
* **Gate on `xschem raw case` when a database happens to be loaded.** Refused
  by `save.c:3516`'s rule, §5.3: that database describes another run.
* **Fold, and additionally consult `xschem raw case` when the loaded database
  is this run's own raw.** Live, but more code for a route no user can reach
  today. Left undone deliberately; if item 13 of the casemode batch ever wires
  a profile's `distinguish` into the read, this is the shape to revisit.

The **rule debt** is on that choice, not on the fix: a user who runs
`distinguish` benches may want the third option.

## 6. Fences — `tests/headless/test_op_dump_altshow.tcl`, section Y

Rows are **paired**: every case-folded row has an all-lowercase twin and the two
are required to be byte-identical, because a fold that fixed `preserve` by
loosening the check for everybody would pass a one-sided row.

| row | what it pins |
|---|---|
| **Y6** | a `preserve`-cased dump covering the block's devices is **silent** (the defect), with a non-vacuity term asserting the header really is in the run's casing |
| **Y7** | the fold did not make it deaf: a `preserve`-cased dump for a device the block never asked about is still `op_dump_partial` |
| **Y8** | CONTROL, all lower case: one of two devices covered → `op_dump_partial`, and the sentence says **"only 1 of the 2 devices"** — the count, which is the half the user read |
| **Y9** | the same dump in the run's own casing says the same thing **byte for byte** |
| **Y10** | two headers differing only in case are D2's ambiguity: the device counts as missing, no guess |

**Non-vacuity, measured** rather than asserted — the rows were driven against
two rival implementations:

| implementation | Y6 (want silence) | Y10 (want `op_dump_partial`) |
|---|---|---|
| the shipped exact-only compare | **`op_dump_partial`** ✗ | — |
| a naive fold with no D2 decline | — | **silence** ✗ |
| this fix | *(silence)* ✓ | `op_dump_partial` ✓ |

## 7. Suite status

All run by hand on this tree after `make -C src` (nothing to do — the change is
pure Tcl; `git status` shows no `src/*.c` edit of mine).

| suite | arm | result |
|---|---|---|
| `test_op_dump_altshow` | `--nogui` | `RESULT: ALL PASS (70 checks)` **(65 → 70)** |
| `test_op_dump_altshow` | `--nogui`, empty `HOME` | `RESULT: ALL PASS (70 checks)` |
| `test_op_dump_altshow` | `:99` | `RESULT: ALL PASS (70 checks)` |
| `test_op_dump_altshow` | `:99`, empty `HOME` | `RESULT: ALL PASS (70 checks)` |
| `test_ase_final` | `--nogui` | `RESULT: ALL PASS (82 checks)` |
| `test_ase_final` | `--nogui`, empty `HOME` | `RESULT: ALL PASS (82 checks)` |
| `test_ase_final` | `:99` | `RESULT: ALL PASS (82 checks)` |
| `test_ase_final` | `:99`, empty `HOME` | `RESULT: ALL PASS (82 checks)` |
| `test_ase_core` | `--nogui` | `RESULT: ALL PASS (197 checks)` |
| `test_ase_optier_0963` | `--nogui` | `RESULT: ALL PASS (103 checks)` |
| `test_ase_simreg_0931` | `--nogui` | `RESULT: ALL PASS (95 checks)` |
| `test_annot_blank_cause_0909` | `--nogui` | `RESULT: ALL PASS (27 checks)` |
| `test_annot_op_behind_tran_1242` | `--nogui` | `RESULT: ALL PASS (22 checks)` |
| `test_rdw_seam_1245` | `:99` | `RESULT: ALL PASS (49 checks)` |
| `test_op_annot` | `:99` | `RESULT: ALL PASS (492 checks)` / `OVERALL: ok` |

The set is every headless suite that names `op_report_missing`, `opdump` or
`op_dump_partial` (`grep -l` over `tests/headless`), plus the four ASE/annot
suites nearest the changed road.

⚠ **`test_ase_final` reads differently under the user's `HOME` and an empty one**
(issue 1363), so it was taken both ways on both arms. `test_op_dump_altshow`
likewise, for the same reason and because it is the suite that changed.

⚠ **`test_ase_optier_0963` is a `--nogui` suite** (`full_audit.sh:161`). Run on
`:99` it hangs: measured here at 10 minutes under `timeout` without reaching its
banner, which reads exactly like a crash. It is not one — the arm is wrong.
Issue 1391 §6 records the same trap; recorded again because this item walked
into it too.

The floor was raised by five rows and never lowered: `git diff --stat` on the
suite is **77 insertions, 0 deletions**.

`run_regression.tcl` (T1) and the full audit are the driver's — this item ran
neither, per the batch's standing rules, so the diff against the branch's 15
named baseline reds belongs to the integrator's pass. No suite this item ran
moved in the red direction.

## 8. Debts

* **rule 1390** — §5's ruling. The fold is unconditional; the third alternative
  in §5 is the one a `distinguish` user might want instead. Recorded with
  `owed.sh add rule 1390`.
* **No look debt.** Nothing here is pixels: the change is a comparison whose
  entire output is a sentence, and the suites read the sentence.
* **No suite debt.** `op_report_missing_dump` has no widget, no binding and no
  window, so a `:0` run would measure nothing a `--nogui` run does not.

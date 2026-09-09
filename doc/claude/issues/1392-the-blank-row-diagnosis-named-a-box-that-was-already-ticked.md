# 1392 — the blank-row diagnosis named a box that was already ticked

**Filed** 2026-09-08, item D of the ASE-L run-guard batch
(`doc/claude/ase_run_guard_batch/CREW_BRIEF.md`).
**Status FILED, NOT FIXED — and deliberately so.** Issue 1389 (item A of the
same batch) removes the only route measured to reach this, so building the
fourth cause now would be adding a branch nobody can get to. §6 says what would
turn that judgement over.
**Files, if it is ever built** `utils/annot_mode.tcl`
(`cadence::_annot_cause` :516, `cadence::_annot_cause_msg` :559,
`cadence::_annot_remedy`), `tests/headless/test_annot_blank_cause_0909.tcl`.

## 1. What happened on the user's bench, 2026-09-08

Their rows annotated blank. `cadence::annot_mode` explained why:

> Some values are blank because the results file has no per-device
> operating-point numbers in it, such as gm, gds and vth. **Run the simulation
> again with device parameter saving turned on.**

**Device parameter saving was already on.** That is what sent them to
`Outputs > Save All…` — visible in their action log at line 64 — looking for a
tick that was already ticked, because `cadence::_annot_remedy` hands `noparams`
the menu path to it.

The real cause was two overlapping runs (issue 1389): the deck carries `set
appendwrite`, so run 2 appended its Operating Point plot to run 1's raw, and
`op_annot::opdump_autofill` then refused to merge the sidecar on its
`raw points != 1` gate. The numbers were on disk, in the `.opinfo`, complete and
correct. Nothing was unsaved.

## 2. Why the classifier could not say so

`cadence::_annot_cause` (`annot_mode.tcl:516`) has **three** answers and this
bench is none of them:

    if {[cadence::_annot_op_cards_off]} { return nocards }
    if {[cadence::_annot_devparams_present]} { return somedev }
    return noparams

* `_annot_op_cards_off` is **0** — the session that owns the sheet has
  `save_op_params` on, which is the truth.
* `_annot_devparams_present` (`:443`) scans `xschem raw list` for a name
  carrying both `@` and `[` and not starting with `i(`. The merge was refused,
  so the only device-shaped vector in the database is `.options savecurrents`'s
  `i(@m.x1.xm1.mnfet[id])` — which that proc skips on purpose. **0.**
* So the tail arm fires: `noparams`, and `noparams`'s sentence names the tick.

`noparams` is a fair name for "the results file has no device numbers in it".
It is the **remedy** that is false here, and it is false because the cause list
has no entry for *the numbers arrived and were not merged*.

## 3. Measured, 2026-09-08, this tree, binary current

Same raw file twice, differing only in how many Operating Point plots it holds,
with an identical fresh `.opinfo` sidecar beside each:

| plots in the raw | `xschem raw points` | sidecar merged | `_annot_devparams_present` | sidecar on disk |
|---|---|---|---|---|
| 1 | 1 | **yes** | 1 | yes |
| 2 | 2 | **no** | **0** | yes |

So on the two-plot file the classifier reports "the results file has no device
values like gm and vth in it" while a complete set of them sits beside it,
readable, in a file this tree wrote itself.

## 4. The honest fourth cause

> **The results file holds more than one operating point, so the device numbers
> were not merged.**

It is distinguishable without a new probe — the table above is the whole test:

* a sidecar exists beside the current raw and is **not** stale
  (`op_annot::opdump_path` + the mtime rule `op_annot::opdump_merge` already
  applies), **and**
* `xschem raw points` is not 1, which is precisely the gate
  `op_annot::opdump_autofill` refused on.

Both terms are needed. The points term alone would fire on every multi-point
sweep, where blank device rows are correct and expected (RULING D5-1: a
snapshot must not be painted flat across a sweep). The sidecar term is what
makes it "your numbers exist and did not get in" rather than "there are no
numbers".

Its remedy is **not** a tick — it is *run once and let it finish*, which is
exactly what 1389 now enforces. Whatever the wording, it must not be minted
outside `cadence::_annot_cause_msg`: RULING **D5-4**, and row V43 of
`tests/headless/test_op_annot.tcl` enforces the one-mint rule by grep.

## 5. Why it is filed and not built

Issue **1389** refuses a second launch against a live results file, and a
double launch is the only route anyone has measured into a two-plot ASE-L raw:
the deck's `set appendwrite` (issue 0929) is what appends, and `ase::run_deck`'s
pre-run `file delete` already covers every **sequential** re-run. With 1389 in,
this classification is reachable only by a raw assembled outside ASE-L
altogether — a hand-concatenated file, or another tool's output opened in the
viewer.

Adding a fourth cause today therefore buys a branch with no measured way in,
and costs a fourth sentence in a mint whose wording is **still not ratified**
(the whole `_annot_cause_msg` family is an open rule debt against issue 0909).
Two unratified sentences are worse than one.

**It is filed rather than dismissed** because the failure mode is the expensive
kind: a confident wrong direction. The user did not ignore it — they acted on
it, and the action was a dead end. If this is ever seen again, it is a defect
with an issue already written.

## 6. What would turn this over

* a two-plot ASE-L raw reproduced **with** 1389's lock in place — that would
  mean 1389 does not close the route and this cause is live;
* any other refusal path in `op_annot::opdump_autofill` reaching the same dead
  end (its type gate and its stale-sidecar gate are the candidates: both leave
  a good sidecar unmerged, and both would be classified `noparams` today);
* the `_annot_cause_msg` wording being ratified, which removes half the cost of
  adding a fourth arm.

## 7. Related

* **1389** — the double launch itself. Fixed.
* **1390** — the *other* diagnostic that lied on this same run, and the one
  that fired on **every** run rather than only this one. Fixed.
* **0909** — the blank-cause classifier and its unratified wording.
* **0975** — "a run that worked must not be told it failed". This is the same
  rule one step out: a run that failed for reason X must not be told reason Y.

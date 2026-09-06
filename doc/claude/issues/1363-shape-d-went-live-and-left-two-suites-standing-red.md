# 1363 — shape `d` went live and left two ASE suites standing red, unfiled

**Status: `test_ase_final` FIXED (issue 1364); `test_ase_core` STILL RED.**

> **2026-09-05, by issue 1364.** The measurement this file asked for was taken.
> `F16`/`F17` were **not** a stale expectation: they were the real defect —
> `op_annot::opdump_merge` had exactly one caller, in `op_annot::db_attach`, and
> `xschem annotate_op` (which is what `F16` drives, and what the user's own
> launcher buttons and menu items drive) never merged at all. Fixed in
> `update_op()`. `F12`/`F14`/`F21` were the stale expectations this file
> predicted, and `test_ase_final` is now shape-aware: **ALL PASS (81 checks)**
> under the user's registry and under a HOME with none.
>
> `test_ase_core` is **untouched**. Re-measured 2026-09-05 at the 1364 commit:
> 10 FAILED (172 passed) with the user's `ase_simulators`, **3 FAILED (179
> passed)** with a HOME carrying none — so `E1e` is registry-dependent for a
> reason that is not the tier, and `C11` / `NT17` / `NT18` survive both. Because
> those three survive either way the suite cannot reach zero by making
> `C5b`/`C6`×4/`C8` shape-aware, which is why 1364 did not do half of it.

**Original status: FILED, NOT FIXED.** Found while fixing issue 1354, which is a
different defect on the same road. Filed rather than fixed because it is outside
that item and because one of the reds (`F16`/`F17`) may be a real blank
annotation rather than a stale expectation, and telling those two apart is a
measurement someone has to take deliberately.

## Measured at HEAD `fa0eb0b0`, 2026-09-05, binary current, nothing else running

    tests/headless/test_ase_core.tcl    RESULT: 10 FAILED (172 passed)
    tests/headless/test_ase_final.tcl   RESULT:  6 FAILED  (74 passed)

Both are in `full_audit.sh`'s `nogui_tests` list, so a full audit carries them.
Neither is in `tests/run_regression.tcl`, so **T1 does not see either of them**
and T1 stays at its zero baseline while both are red.

## Attributed, not guessed: force the tier back to `c` and they go green

A wrapper that pins `ase::op_tier_force_set c` and then `source`s the suite
(`scratchpad/ITEM_1354/probe/forcec_core.tcl`, `forcec_final.tcl`):

| suite | at HEAD | with the tier forced to `c` |
|---|---|---|
| `test_ase_core` | 10 FAILED (172) | **4 FAILED (178)** |
| `test_ase_final` | 6 FAILED (74) | **ALL PASS (80 checks)** |

So **every one of `test_ase_final`'s six reds is the shape-`d` transition**, and
six of `test_ase_core`'s ten are.

### The shape-`d` casualties

`test_ase_core`: `C5b`, `C6` (×3), `C8` — all of them assert that the captured
block's `.save @dev[param]` cards appear in the rendered deck immediately above
`.control`. On shape `d` the deck carries **no such card at all** (that is row
`D1` of `test_op_dump_altshow.tcl`, asserted deliberately), so these are
shape-`c` expectations that the tree stopped meeting when the user's ngspice
started answering `altshow_op_dump 1`.

`test_ase_final`: `F12`, `F14` (×2), `F21` are the same class. **`F16` and
`F17` are not**, and they are the reason this is filed rather than dismissed:

    FAIL: F16 op_annot::text M1 renders a REAL NUMBER on all six rows
              -> {gm gds vgs vth vds} (exp {})
    FAIL: F17 no rendered value is blank, 0, 0.0, nan or inf (landmine 2)
              -> {{gm {}} {gds {}} {vgs {}} {vth {}} {vds {}}}

That is five of six annotation rows coming back **blank** on a real ngspice run
in that suite. It is very likely the suite's own flow — shape `d` puts its
numbers in the `.opinfo` sidecar and `op_annot::db_attach` is what merges them,
and `F14`'s sibling rows show the suite reading the raw directly — but "very
likely" is not a measurement, and issue 0617 exists because blank annotation
rows are exactly the failure this whole surface was built to delete.

### The four that are NOT shape `d`

`C11` (and `H1` of `test_op_dump_altshow`) fail on `untitled~.sch` /
`untitled~.sym` sitting in the repo root, dated 2026-09-04 21:24 — residue from
an earlier session, not from these runs. `E1e`, `NT17`, `NT18` are separate
pre-existing reds, untouched by the tier.

## Why it matters

CLAUDE.md: *"A standing red is a defect, not furniture — it is the one place a
real regression hides in plain sight."* These two suites went red when the deck
shape changed and nobody filed it; a full audit taken today reports both without
anything in the transcript saying why.

## What the fix has to decide

1. Do the shape-`c` rows become shape-aware (pin the tier per row, and add the
   shape-`d` leg beside it), or does the suite pin `c` globally and hand shape
   `d`'s coverage entirely to `test_op_dump_altshow`?
2. `F16`/`F17` first: measure whether a shape-`d` end-to-end run in that suite
   really leaves the sheet blank, or whether the suite simply never attaches the
   sidecar. Those are different bugs and only one of them is the user's.
3. The `untitled~` residue in the repo root is its own small thing (issues 0322,
   0353, 0609 are the family) and it currently reds three rows in two suites.

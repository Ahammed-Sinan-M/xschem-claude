# 1335 — the missing-numbers report is silent under shape d, defeated by `.options savecurrents`

**Status:** FIXED (this branch)
**Files:** `src/ase.tcl`
**Found by:** review of the `op-wcard` sibling branch, 2026-09-05

## What was wrong

`ase::op_report_missing` exists to stop a run producing blank annotation rows
silently. On a shape-`d` run with **every row blank** it returned `<silent>`.

The mechanism is `test_ase_final`'s own **F18** trap, documented in the tree.
`.options savecurrents` puts

```
1  i(@m.xm1.msky130_fd_pr__nfet_01v8[id])   current
```

in the raw with **no card present**. The reporter compares *devices*, so that
one free vector marked the device answered and the sentence never fired.

Shape `d` does not put its numbers in the raw at all — they are in the sidecar
dump — so asking the raw about them is the wrong question, and the wrong
question got a reassuring answer.

## Measured

`build-ver_50`, cell `test_nfet_final`, tier d, no reader wired (issue 1333):

```
op_report_missing verdict   <silent>
op_annot::text M1           id =  gm =  gds =  vgs =  vth =  vds =
```

Exit 0, raw good, simulator log clean, guard silent, six blank rows.

## The fix

The run record now carries **which shape the deck used**. `ase::run_deck`'s
`meta` gains `optier`, computed under render_deck's own two gates so the two
cannot disagree — the existing `opblock` says what was *asked for*, `optier`
says *how*, and they are not the same question.

`ase::op_report_missing_dump` answers the same question against the file that
would actually hold the numbers, and distinguishes two situations that are not
the same sentence:

* **no dump at all** — the folded-path run (issue 1334) and anything else that
  stopped the file being written. Exit 0, clean raw, clean log; without this
  sentence it is completely silent;
* **a dump that does not cover the devices** — something was written, but not
  for the devices this sheet names.

A dump that covers them is **silence**, deliberately: a run that worked must not
be told it failed, which is the defect issue 0975 was closed on.

Rows Y1–Y5 of `tests/headless/test_op_dump_altshow.tcl`; Y5 pins the
savecurrents trap itself so it cannot come back.

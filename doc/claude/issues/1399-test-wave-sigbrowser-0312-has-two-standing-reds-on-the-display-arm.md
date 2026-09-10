# 1399 — `test_wave_sigbrowser_0312` has two standing reds on the display arm

Found while verifying issue 1398 did not move anything downstream. **It did not** — these
two were already there, and this file exists so they stop being furniture.

## The reds

```
FAIL: BF21a wide: the bar really got the width, is FLAT — every child packed, none gridded, and the
FAIL: BF24a widened again: back to FLAT, with BAR03's pack order restored
RESULT: 2 FAILED (67 passed)
```

Display arm only. On `--nogui` the suite is `ALL PASS (20 checks)` because the BF2x group
self-skips.

## Proved pre-existing, without touching the working tree

`git stash` is forbidden here, so the committed `src/ase_window.tcl` and `src/xschem.tcl`
were extracted with `git show HEAD:` into a shadow tree and the suite run against it via
`XSCHEM_SHAREDIR`:

```
shadow (committed HEAD)  ->  2 FAILED (67 passed)   BF21a, BF24a
working tree (1398)      ->  2 FAILED (67 passed)   BF21a, BF24a
```

Identical rows, identical count, identical text.

## Why nobody noticed

**`test_wave_sigbrowser_0312` is not in `tests/run_regression.tcl`'s case list at all**, so
T1 has never covered it and T1's zero is honest. It runs under `full_audit.sh`.

## What it looks like

Both rows assert that after the signal bar is given a width it lays out FLAT — every child
packed, none gridded. The suite's own comment at `:393-397` predicts this failure mode: the
fixture asks the window manager for a toplevel width it does not get. That makes it a
candidate for the treatment `test_calc_skeleton` S12 got — force the race deterministically
rather than hoping the environment supplies it — but the diagnosis has not been done and
this file does not pretend otherwise.

Measured under **openbox 3.6.1 on Xvfb `:99`**, 1920×1080×24, `tk scaling` 1.388. Not yet
tried on `:0` (Xwayland) or on the user's own X server, where the WM negotiates differently
and the answer may differ.

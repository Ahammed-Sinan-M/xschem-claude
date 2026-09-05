# 1346 — `test_rdw_keys_1245` flakes in a dozen focus/binding rows under CPU load, in both arms

**Status: FILED, NOT FIXED.** Found while measuring issue **1332**'s fix (item
**P3**, 2026-09-05). Subject: `tests/headless/test_rdw_keys_1245.tcl`, sections
**F**, **B**, **V**, **D**, **CU** and **RA**. Not issue 1332, which is closed;
not issue **1343**, which is the standing `$DISPLAY` red.

## The shape

Issue 1332's acceptance clause asks for the SD rows to be re-measured under "a
6-way CPU spinner plus a concurrent suite on the same display". Run that way on
`:99` (openbox, 1920x1080x24, `test_op_annot` looping on the same display, load
average 4.5–7.4), the SD rows hold — and **a dozen other rows do not**:

```
F1 F3 F4  B2 B3 B4 B5  V2  D1  CP1  RA1 RA2 RA3 RA6
```

Counts ranged from `ALL PASS` to `10 FAILED (64 passed)` over thirteen runs.

## It is not the 1332 fix

Measured **interleaved**, one run of the pre-1332 file immediately followed by
one run of the fixed file, seven pairs, same machine, same minute, same load:

| pair | pre-1332 file | post-1332 file |
|---|---|---|
| 1 | F1 F3 F4 | RA2 RA3 RA6 |
| 2 | F1 | V2 |
| 3 | *(ALL PASS)* | V2 |
| 4 | RA3 CP1 | F3 F4 |
| 5 | RA3 | *(ALL PASS)* |
| 6 | F3 F4 B2 B3 B4 B5 V2 D1 RA1 RA2 | RA6 |
| 7 | F3 F4 | *(ALL PASS)* |

The same set, in both arms, in the same proportions. The 1332 change is confined
to section SD, which runs textually **after** F, B, V and D, so it cannot reach
them; the table is the receipt rather than the argument.

## Why it is worth a number

Quiet, this suite is **12/12 ALL PASS (77)** on `:99` and steady at
`5 FAILED (72 passed)` on the user's VcXsrv. So none of this is visible in a
normal run — it appears exactly when several crew agents share the box, which is
the routine condition in this tree, and it is then indistinguishable from a real
regression. `CLAUDE.md`'s own rule applies: force the race deterministically
rather than hoping the environment supplies calm.

The rows are all focus-, map- or binding-sensitive (`F` is the first-map focus
race, `B` the four binds, `V` the pick's rubber band, `RA` the raise), which is
the class most likely to be reading a state the X server has not settled yet.

## Not investigated here

Which of the fourteen share one cause, and whether any of them is a `wm`/focus
settle that should be a poll the way issue 1332's driver now is. Item P3's brief
was issue 1332 only, and editing another item's rows mid-batch is what the crew
brief forbids.

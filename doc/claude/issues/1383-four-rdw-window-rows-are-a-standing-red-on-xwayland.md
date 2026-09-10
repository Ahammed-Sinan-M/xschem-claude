# 1383 — four rows of `test_rdw_window_1245` are a standing red on `:0`, and nobody had filed it

**Branch** `fluid-editing`. **Suite** `tests/headless/test_rdw_window_1245.tcl`,
rows **SL8**, **FZ11**, **FZ17**, **FZ18**. **Found by** the `:0` suite debt of
issue 1382, paid during that item's repair pass.

## What was measured

`GUI_GATE=0 DISPLAY=:0` — Xwayland, WSLg's own server, **not** the user's real
screen (CLAUDE.md's three-server table). Ten runs in one session, on two
different states of the tree:

| tree | display | result |
|---|---|---|
| HEAD (`git show HEAD:` for both the source and the suite) | `:99` | ALL PASS (241) |
| HEAD | `:0` × 2 | **4 FAILED (237 passed)** — `SL8 FZ11 FZ17 FZ18`, both runs |
| HEAD + issue 1382 + its repair | `:99` | ALL PASS (251) |
| HEAD + issue 1382 + its repair | `:0` × 4 | **3 FAILED (248 passed)** — `SL8 FZ11 FZ17`, three runs; one run also `FZ14` |
| HEAD + issue 1382, minsize repair reverted | `:0` | 6 FAILED — the four, plus CB7 and CB9 doing their job |

So the reds **predate issue 1382 entirely**: they are there with no Close
button in the tree at all. Item A adds none of them and, incidentally, its
re-fixtured `fz_park_bottom` (which parks the BUTTON's bottom edge rather than
the window's) **fixes FZ18** on `:0`. All ten of section CB's rows pass on `:0`.

⚠ **AND ONE RUN IN TEN REPORTED `RESULT: ALL PASS (204 checks)`.** 204 is the
`--nogui` count. The `:0` client died and the suite fell back to its headless
arm, reporting a plausible green line with the wrong number in it. **A green
`:0` line from this suite is not by itself evidence** — check the check count.
That is the WSLg Xwayland instability CLAUDE.md already records (~3 client
aborts a session), arriving as a false pass rather than a crash.

## What each row answers on `:0`

```
SL8   {1 0 0 {1 1 1 1} 1 1}   exp {1 1 1 {1 1 1 1} 1 1}
FZ11  {NO-BALLOON {1 0}}      exp {{1 1} {1 0}}
FZ17  {{1 1} 0 {} 0}          exp {{1 1} 1 0 0}
FZ18  (HEAD only)             the bottom-of-screen `pos 0` case
```

* **SL8** — the window really is narrowed to 600 px (leg 1 passes), but the
  status sentence does **not** need more lines at that width and the pane
  therefore gives nothing up. That is a FONT METRIC difference between the two
  servers, not a logic difference: the row's subject (a refit that re-asks how
  many lines a sentence needs) is fine, its fixture picks a width that happens
  to straddle a wrap boundary on one server and not the other.
* **FZ11 / FZ17 / FZ18** — `NO-BALLOON`, i.e. `$w.balloon` does not exist after
  `balloon_show` + one `update`. Not a clamp failure: the tip never appears.
  This is the `<Configure>` traffic difference the tree has measured before
  (one `wm geometry` request yields **3** `<Configure>` events on `:0` against
  **1** under Xvfb, and Calculator phase 0 passed 49/49 under Xvfb while
  failing 3 checks on `:0` for exactly that reason).

## The rule this is filed under

CLAUDE.md: *"A standing red is a defect, not furniture — it is the one place a
real regression hides in plain sight"*, and its companion: *"treat a bug that
only `:0` can reproduce as a **test** defect too: the fix is to force the race
deterministically (`test_calc_skeleton` S12), not to hope an environment
supplies it."*

Both halves apply here. Two of the four are the suite leaning on an
environment: SL8 on one server's font metrics, and the FZ trio on the tip
having been mapped by the time the next `update` returns. Filed rather than
re-derived, because this tree has already paid for the other habit — issue 0689
was filed **four** times and 0690 **four** times while everybody waved the same
count through.

## Not fixed here, and why

Issue 1382's repair pass is a repair of item A, and none of these four rows is
item A's. They are recorded, measured on both states of the tree, and left for
whoever picks this up. The suite debt on `test_rdw_window_1245` is deliberately
left **standing** and now points at this file rather than at 1382.

## Where to start

* `SL8` — `tests/headless/test_rdw_window_1245.tcl:7447`. The fixture picks
  600 px by hand. Drive the width from a `font measure` of the sentence in the
  surface's own font so the wrap is forced by measurement on any server, the
  way issue 1382's `fz_park_bottom` was repaired.
* `FZ11 / FZ17 / FZ18` — `fz_tip_geom` / `fz_tip` in the same file. Both wait
  one `update` after `balloon_show`. Wait for the window to EXIST (poll with a
  bounded deadline) rather than for one event-loop turn, or force the map
  synchronously. `NO-BALLOON` is a documented signature of a real defect for
  `pos 0` tips, so the wait must not swallow that case — FZ18's comment says
  so in as many words.

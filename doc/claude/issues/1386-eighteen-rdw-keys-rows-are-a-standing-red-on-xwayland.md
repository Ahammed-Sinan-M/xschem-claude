# 1386 — eighteen rows of `test_rdw_keys_1245` are a standing red on `:0`

**Branch** `fluid-editing`. **File** `tests/headless/test_rdw_keys_1245.tcl`.
**Status: NOT FIXED — filed, not re-derived**, per CLAUDE.md's standing-red rule
and the four-times-filed history of 0689/0690. Sibling of issue **1383**, which
is the same thing one suite along.

## What was measured

The suite debt on this file (`owed.sh`, "issue 1369 moves focus behaviour; run
it once on :0") was paid on 2026-09-08 while landing issue 1384. It is red, and
it is red **at HEAD with both uncommitted RDW UX items entirely out of the
tree** — `git show HEAD:` written over `src/rdw.tcl`, `src/xschem.tcl` and this
suite, run, and the working copies restored byte-identically (md5 verified).

```
GUI_GATE=0 DISPLAY=:0   (Xwayland, NOT the user's screen)

at HEAD                    18 FAILED (72 passed)
  F1 F6 C2 B2 B3 B4 B5 V2 V3 V7 D1 RA1 RA2 RA3 RA4 RA5 RA6 KD1

with issue 1384 in tree    18 FAILED (74 passed)   run 1
  F1 F3 B2 B3 B4 B5 V2 V3 V7 D1 RA1 RA2 RA3 RA4 RA5 RA6 LK2 KD1
                           18 FAILED (74 passed)   run 2
  F1 F3 B2 B3 B4 B5 V2 V3 V7 D1 RA1 RA2 RA3 RA4 RA5 RA6 CP9 KD1

the same suite on :99      ALL PASS (92 checks), four consecutive runs
```

The **count is identical** and the two extra passes are issue 1384's own new
rows (HP1, HP2), which are green on both servers. So 1384 adds no `:0` failure
here; it only paid the debt that showed this.

## The shape of it

A stable core of **sixteen** — `F1`, `B2`–`B5`, `V2`, `V3`, `V7`, `D1`,
`RA1`–`RA6`, `KD1` — plus a rim of two that changes run to run out of
`{F3, F6, C2, LK2, CP9}`. Grouped by what they are about:

* **`B2`–`B5`** — the four bare digits and the Ctrl/Alt collateral, driven with
  `event generate .drw <Key-N>`. These are the rows that say the profile's binds
  reach C's `logic_set` and that Ctrl-1/Ctrl-3 still pick a drawing layer. Key
  delivery to a canvas that may not hold the input focus is the first thing to
  look at.
* **`F1`, `F3`/`F6`** — the first-dump-of-a-session focus race and the
  deliberate-click disarm (issues 1306, 1369). Focus grants are exactly what
  differs between a real window manager, openbox on Xvfb, and Xwayland under a
  Wayland compositor.
* **`V2`, `V3`, `V7`** — the command mode's "a click changes no selection"
  requirement and the seized-binding hand-back (issue 1304), driven through real
  press / motion / release.
* **`D1`** — the descend's suspend/resume re-latch on the canvas it lands on.
* **`RA1`–`RA6`** — the whole raise section (issue 1340). Its own look debt
  already records that `:99` **provably cannot reproduce** the defect it was
  written for and that the rows read Map/Unmap traffic as a *proxy* for stacking
  order; Xwayland's 3-`<Configure>`-per-request traffic is measured elsewhere in
  this tree and is the obvious suspect.
* **`KD1`** — the digit pressed at the focus the user's own click leaves.
* **`C2`** — see issue **1385**: it answers to the main window's width, which is
  restored per schematic file from `~/.xschem/geometry`.

## Why this is filed rather than fixed

Eighteen rows across five unrelated mechanisms is not one defect, and every one
of them needs the same diagnosis 1383's four rows need: *is the row wrong, or is
Xwayland?* CLAUDE.md's own answer to that question is that a bug only one
environment reproduces is a **test** defect too — the fix is to force the
condition deterministically, not to hope a server supplies it. That is real work
per row and it belongs to whoever owns each section, not to a status-bar hint.

What must not happen is the thing that happened to 0689/0690: a number carried
forward as furniture. **The suite debt on this file now points here**, and a
crew reporting `test_rdw_keys_1245` must say `:99 92 ALL PASS / :0 18 FAILED,
issue 1386` rather than a bare green line.

⚠ And the warning from 1383 applies to this suite too: check the **count**. A
`:0` run whose client dies falls back and can print a plausible verdict for a
different arm.

## Reproduction

```sh
GUI_GATE=0 DISPLAY=:0 ./src/xschem --pipe --nolog -q \
  --script tests/headless/test_rdw_keys_1245.tcl
```

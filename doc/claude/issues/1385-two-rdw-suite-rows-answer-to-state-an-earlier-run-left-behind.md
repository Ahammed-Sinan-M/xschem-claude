# 1385 — two RDW suite rows answer to state an earlier run left behind

**Branch** `fluid-editing`. **Files** `tests/headless/test_rdw_keys_1245.tcl`
(row C2, and C1 beside it), `tests/headless/test_rdw_window_1245.tcl` (row FZ7).
**Status: NOT FIXED — filed rather than re-derived**, per CLAUDE.md's
standing-red rule and the four-times-filed history of 0689/0690. One half is
mitigated (see below).

## What was seen

Item A of the RDW UX batch recorded `test_rdw_keys_1245 :99 90 checks, ALL PASS`
on 2026-09-07. A few hours later, on the same machine, the same display and the
same commit, it reported:

```
FAIL: C2 THE DEFAULT PATH, at a straddling pixel found at run time ...
      -> {0 0 0 0 0} (exp {1 0 1 1 0})
RESULT: 1 FAILED (89 passed)
```

reproducibly, four runs. **Both uncommitted items were then taken entirely out
of the tree** — `git show HEAD:src/rdw.tcl` and `git show HEAD:src/xschem.tcl`
written over the working copies, run, and the working copies restored
byte-identically (md5 verified) — and C2 was **still red**. It is nobody's
change.

## Case 1 — C2 (and C1) answer to the main window's width, which lives in a
## user-global file every xschem exit rewrites

C2 searches at run time for a screen pixel where the un-snapped and the
grid-snapped mouse positions resolve to **different devices** — issue 1303's
whole subject — and its first leg is `C2_FOUND`, so the author already made it
red rather than pass vacuously when the fixture stops discriminating. That leg
is what fires.

Whether such a pixel exists depends on the **zoom**, which `zoom_full` computes
from the canvas size, which comes from the main window's width. Driven with
`--preinit`, which sets `initial_geometry` and touches nothing on disk:

```
--preinit 'set initial_geometry {1110x761}'   ->  ALL PASS (90 checks)
--preinit 'set initial_geometry  {900x761}'   ->  C1 red: {M1 M1 0} exp {M1 R1 1}
--preinit 'set initial_geometry  {700x761}'   ->  C2 red: {0 0 0 0 0} exp {1 0 1 1 0}
```

Standalone at 700x761 the search scans all 442 candidate pixels: 75 of them
straddle, and in every one of the 75 the **un-snapped** answer is the empty
string, so `$_a ne {}` never holds.

**Where the width comes from, and why it moves on its own.** `set_geom`
(xschem.tcl:16108) restores a **per-schematic-file** geometry from
`$USER_CONF_DIR/geometry` — i.e. `~/.xschem/geometry` — and
`Tcl_CreateExitHandler(tclexit, 0)` (xinit.c:3199) makes **every** Tcl `exit`
run `xwin_exit()`, whose first act is
`store_geom . [xschem get current_name]` (xinit.c:1194). So:

* the suite inherits whatever width the last run of **anything** left behind,
  including the user's own interactive session;
* and **an ordinary `./src/xschem --pipe --nolog -q --script foo.tcl` writes
  `~/.xschem/geometry`** on the way out. Measured directly: the startup window
  was `700x761+372+100` for several runs and is `1110x761+0+0` now, with no
  file in the tree changed in between. C2 is green again *for the wrong reason*.

⚠ **This is a hole in CLAUDE.md's own "never touch anything under
`~/.xschem/`".** That rule is stated as if the danger were deliberate file
handling; the measured danger is a `--script` probe, which is the most-typed
command in a session and which nothing in the tree warns about. The probes
written for issue 1384 almost certainly moved this entry, and that is how the
flip was found.

**Not fixed here, because the fix needs a decision** the fixture's author should
take: pin a geometry in the C section and assert it (CLAUDE.md's own preferred
remedy — force the condition, do not hope an environment supplies it), widen the
search, or drive the pair at a fixed zoom instead of a fixed pixel. Issue 1303's
two numbers are a literal filed measurement on the shipped `cmos_inv.sch` and
someone has to re-take them under whichever shape wins. **Rule debt 1385.**

## Case 2 — FZ7 answers to where the X pointer was left by the PREVIOUS run

Same class, different mechanism, found while adding issue 1384's rows:

```
FAIL: FZ7 ... -> {{1 -1 -1 -1 1 1 1} {aA .rdw.b active 1 bottom}}
                 (exp {{1 -1 -1 -1 1 1 1} {aA .rdw.b normal 1 bottom}})
```

`active` on a Tk button means the pointer is over it. Rows FZ11, FZ17 and FZ18
warp the real X pointer on to `.rdw.b.fontsize` — they have to, `balloon_show`
refuses to draw anywhere else — and **the pointer outlives the process on a
shared display**. FZ7 runs *earlier in the file* than FZ11, so it reads the
pointer position the *previous* run left, and a run whose last warp parked the
pointer on that button reds the next run's FZ7 with nothing whatever changed.
Measured: `winfo pointerxy` came back `523 830` at startup, which is that button
with `.rdw` at `+0+0` — FZ11's second position.

**Mitigated, not fixed.** Issue 1384's new section HT also warps (row HT9, on to
`.statusbar.10`) and now parks the pointer in the corner of the screen at the
end of the section, which is after every other section in that file — so the
suite no longer leaves the pointer on a widget and FZ7 passed twice in a row
afterwards. The proper fix is for **FZ11/FZ17/FZ18** to park their own pointer,
or for FZ7 to assert its precondition instead of assuming it; both are that
section's to take.

## Why this is filed rather than fixed

A standing red is a defect, not furniture, and this one has the worst possible
shape: it is **intermittently green**, and it goes green again for a reason
unrelated to the code. Any crew that measures it on a lucky day reports ALL PASS
and carries the number forward; any crew that measures it on an unlucky day
spends an hour proving it is not theirs — which is exactly what happened here.
Both cases are one sentence of the same rule: *a row whose verdict depends on
state the suite does not set will pass again for the wrong reason.*

## Reproduction, touching nothing

```sh
DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe --nolog -q \
  --preinit 'set initial_geometry {700x761}' \
  --script tests/headless/test_rdw_keys_1245.tcl        # C2 red
DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe --nolog -q \
  --preinit 'set initial_geometry {900x761}' \
  --script tests/headless/test_rdw_keys_1245.tcl        # C1 red
DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe --nolog -q \
  --preinit 'set initial_geometry {1110x761}' \
  --script tests/headless/test_rdw_keys_1245.tcl        # ALL PASS (90/92)
```

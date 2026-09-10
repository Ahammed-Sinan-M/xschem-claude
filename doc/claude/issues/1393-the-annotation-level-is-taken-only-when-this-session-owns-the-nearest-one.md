# 1393 — the annotation level is taken only when THIS session owns the nearest one

STATUS: **OPEN — measured 2026-09-08, deliberately NOT built.** Found while
closing issue 0643 (`descend_run_batch`); recorded there in section (3) as "one
narrow hole IS real and is deliberately not closed here", and filed here so the
option set has a home. **Not reachable on the bench the user reported**, which
is the whole reason it is not built. §6 says what would turn that judgement over.

## What happens

Two ASE-L sessions are open on one hierarchy: session **P** bound to the top
cell (`tb_bandgap`), session **C** bound to a cell *inside* it (say
`bandgap_opamp`, two levels down). The user is standing at or below C's cell.
Session **P**'s post-run refresh runs — the tick on `Annotate Operating Point`,
or the automatic refresh after P's own simulation finishes — and every device
row on the sheet renders **blank**.

## Why — the mechanism, read and measured

`ase::ui::annot_ensure_loaded` (`src/ase_window.tcl:2747`) resolves the
hierarchy level it will stamp the results basis at, and it takes that level from
`ase::session_for_current` **only when the session it finds is the one being
refreshed**:

```tcl
set level {}
set s {}
catch {set s [ase::session_for_current]}
if {[llength $s] >= 2 && [lindex $s 0] eq $key} { set level [lindex $s 1] }
...
set att [::op_annot::db_attach $path $level]
```

(`src/ase_window.tcl:2782-2793`.)

`ase::session_for_current` (`src/ase.tcl:9263`) walks the hierarchy stack
**deepest-first** and returns the **nearest ancestor** session — deliberately, and
for a good reason of its own: a session bound to an intermediate cell simulates
*that* cell as its deck's top, so node names for a pick below it must be measured
from there (issue 0168, and the proc's own header says so). With the usual
single session on the top design, "nearest" and "this one" are the same session
and the guard is invisible.

With two sessions they are not. The nearest session is **C**, `[lindex $s 0]` is
C's key, `$key` is P's, the equality fails, `$level` stays `{}` — and
`op_annot::db_attach` passes nothing down, so `xschem annotate_op` leaves
`raw->level` at whatever `raw_read` stamped, which is `currsch`
(`src/scheduler.c:2540-2542` only overrides it `if(level >= 0)`).
`sch_waves_loaded()` (`src/draw.c:2853`) then resolves the basis by matching
`raw->schname` against the hierarchy stack, fails to place P's deck-absolute
paths against a basis stamped at the user's own level, and every row comes back
empty.

Measured on the same bench, two levels down inside `tb_bandgap` with the
`debug_st1` session open, showing both sides of the same door (issue 0643,
section 3):

```
op_annot::db_attach $raw 0   ->  raw_level=0   sim_sch_path='x1.x1.'   correct
op_annot::db_attach $raw {}  ->  raw_level=2   sim_sch_path=''         blank rows
```

The `{}` line is exactly what this session passes when a different session owns
the nearest level. The mechanism is measured; the two-session *configuration*
that reaches it was not built.

## Why it is NOT fixed here

1. **It is not reachable on the reported bench.** The user runs one ASE-L session
   on `tb_bandgap`. One session means `session_for_current` can only ever return
   that session, so the guard always passes and the level is always correct.
   0643's whole point was that the *reported* path already works; adding a branch
   nobody can reach would be the defect issue 1392 was just written about.
2. **The guard is not obviously wrong.** It is defending against a real thing:
   stamping P's raw at C's level would be as wrong as stamping it at `currsch`.
   The fix is not "drop the `eq $key` test", it is "ask a different question".
3. **Reproducing it needs two nested ASE-L sessions**, which no suite in the tree
   sets up today and which the batch's crews were explicitly told not to build.

## What a fix has to decide

The question `annot_ensure_loaded` should be asking is **not** *"is the nearest
session mine?"* but *"where in this window's stack does MY design sit?"* — which
is a question the tree can now answer, because `descend_run_batch` minted
`ase::stack_level {npath}` (`src/ase.tcl:6016`) for exactly it.

* **(a) `ase::stack_level [ase::ui::design_path $key]`, falling back to `{}`.**
  One line, uses the mint, answers the right question, and degrades to today's
  behaviour when the design is nowhere on the stack. Shallowest-first (DECISIONS
  D2) is the right scan here too: the session's design is its deck's TOP.
  Risk: `stack_level` and `session_for_current` would then both be consulted in
  the same proc, answering two different questions — which is correct, but is
  the kind of thing a later reader "de-duplicates".
* **(b) Keep `session_for_current` and drop only the `eq $key` test**, taking the
  nearest session's level whoever owns it. Cheapest diff, and **wrong**: it would
  stamp P's raw at C's level.
* **(c) Refuse instead of annotating.** When the nearest session is not this one,
  say so — *"session C is bound to a cell inside this hierarchy; its numbers, not
  this session's, are the ones at this level"* — rather than silently drawing
  blanks. Slowest to build, most honest, and arguably the real user-facing bug is
  the silence, not the level.

(a) and (c) are not exclusive. **This is an unratified judgement and carries a
`rule` debt on this number.**

## Acceptance, when someone builds it

- Two ASE-L sessions on one hierarchy, the inner one bound to a descendant cell;
  the outer session's refresh, taken from at or below the inner cell, annotates
  from the outer deck's basis — `sim_sch_path` deck-absolute, rows populated.
- The single-session behaviour is byte-unchanged (this is what the existing
  `test_op_annot` rows already assert; they must stay green).
- A row that reds on the shipped `eq $key` guard, so the fix is not vacuous.

## 6. What would turn the "not built" judgement over

* **A user report.** Anyone running two ASE-L sessions on one hierarchy — a
  block designer and a system designer on the same sheet is not exotic — hits
  blank rows with no sentence explaining them, which is indistinguishable from
  the failures issues 0838, 0886 and 1392 were all written about.
* **Anything that makes a second session ordinary**, e.g. per-block sessions
  driven from the library manager or a hierarchy browser.
* **Any change to `session_for_current`'s scan direction.** Its deepest-first
  walk is what makes "nearest" and "mine" differ; a future unification (which
  DECISIONS D2 already warns against for `stack_level`) would either fix this by
  accident or break it in a new way, and either deserves a row.

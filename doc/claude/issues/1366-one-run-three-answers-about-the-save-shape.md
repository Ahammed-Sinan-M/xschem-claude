# 1366 — one run asked which shape it was using three times, and told the user a different answer from the one it used

**Branch**: `fluid-editing`  **Filed**: 2026-09-05  **Status**: FIXED
**Files**: `src/ase.tcl`
**Rows**: `Z1`–`Z8` of `tests/headless/test_ase_optier_0963.tcl`; `N6` of
`tests/headless/test_op_dump_altshow.tcl` re-spelled.

## What goes wrong for the user

Commit `6a55d626` (issue 1354) made a run say which shape it used to ask for
device operating-point numbers. Its adversary refuted it: **the sentence can
now say shape `d` over a deck that is shape `c`** — i.e. tell the user the fast
path worked when it did not. The refutation drove both directions, and turned up
a third false sentence in the same run.

## The mechanism, re-derived

`ase::run_deck` asked `ase::op_save_tier` **three separate times** and pinned the
three answers to nothing:

| reader | site (pre-fix) | what it does with the answer |
|---|---|---|
| the **sentence** | `ase::op_tier_report`, `src/ase.tcl:4765` | picks one of five `sim_why` kinds and says it to the CIW |
| the **deck** | `ase::backend::ngspice::render_deck`, `:8107` | switches the physical shape of the deck it writes |
| the **record** | `meta optier`, `:4849` | travels to `ase::run_done` and is read by `ase::op_report_missing` |

**Those are the only three production readers.** A grep over the whole tree for
`op_save_tier` returns, besides them, `ase::op_tier_force_set`'s own neighbours
(comments), and four test call sites: `t_tier` (`test_op_dump_altshow.tcl:239`,
rows T1–T5/X5/X6), `o_tr` and the structural `o_body` row
(`test_ase_optier_0963.tcl:227`, `:433`), and `test_ase_final.tcl:1220`/`:1409`
(rows F11/F12/F14/F21, which ask which shape a run took so the suite can be
shape-aware). Every one of those asks the *pure decision* and must keep getting
a fresh one.

**And `ase::op_save_tier` is deliberately not a constant function.** It reads
`ase::sim_capabilities`, which

* **never remembers a `known 0` answer** — "an answer nobody worked out is never
  remembered", `src/ase.tcl:1863`, issue 0950 — so one probe timeout answers
  `unknown` this call and `dump` the next; and
* re-measures whenever `ase::cap_stale` sees the resolved binary's stamp move.

So **one** probe timeout, or **one** mtime change, between two of those three
calls is enough to make them differ. The three-way agreement was never a
property of the code; it was a property of a quiet machine.

MEASURED here, on the unmodified source at `e927cb8f`, with the decision
replaced by a stand-in answering a scripted sequence (row helper `z_flap`):

```
flap {d c d} -> calls=3 said=op_tier_dump      deck=c record=d
flap {c c d} -> calls=3 said=op_tier_perdevice deck=c record=d  report=op_dump_missing
```

## The third face, and it is the worst

With the record on `d` over a deck rendered `c`, `ase::op_report_missing` takes
its shape-`d` branch (`:4278`), finds no sidecar — **correctly**, because a
shape-`c` deck writes none — and says:

> "…The usual cause is the name of the run folder: … **Rename the run folder in
> lower case with no spaces**, or run again and xschem will ask for the numbers
> one device at a time instead."

for a folder that was already all lower case with no spaces, over a run that
worked. That is issue **0975**'s rule — *a run that worked must not be told it
failed* — broken by a route 0975 never looked down. `run_deck`'s own comment at
`:4842` claimed the record was "Computed under render_deck's own two gates so
the two cannot disagree". The **gates** were the same. The **measurement** was
not.

## The fix — an ordering and threading change, not a new policy

`ase::run_deck` **arms a pin**; the first of the three consumers to ask decides;
every later consumer in that run is handed the same answer.

* `ase::op_tier_arm` / `ase::op_tier_disarm` / `ase::op_tier_pin_state` /
  `ase::op_tier_now` (new, beside `ase::op_save_tier`).
* All three readers now go through `ase::op_tier_now $state`. **With nothing
  armed, `ase::op_tier_now` IS `ase::op_save_tier`, call for call** — which is
  what every suite that drives `render_deck` with a fixture string depends on,
  and what keeps the decision testable as a pure function.

### Which call happened first, and whether the renderer must decide

The **sentence** ran first (`:4765`, above the cosim block and above the
render). The renderer is the one whose answer becomes physical — the deck on
disk is the ground truth about what ran — but it runs **second**, after the
sentence is already out, so letting it measure would only move the disagreement,
not delete it. What makes the deck the ground truth is that it now **obeys** the
run's one answer: deck, sentence and record are the same letter by construction,
and a reader who checks the deck is checking all three.

### Where the pin's lifetime begins and ends

**Begins** at `ase::op_tier_arm`, immediately above the first consumer.
**Ends** at `ase::op_tier_disarm`, as soon as the record is taken — and on the
one statement between them that can raise, the render, whose error is re-raised
with its own message, stack and error code.

`ase::op_tier_report` moved **below** the cosim block for exactly that reason:
`ase::cosim_build` raises out of `run_deck` on a failed model build, and
everything between the arm and the disarm has to be non-raising or caught, or a
dead run would leave its answer for the next direct `render_deck` call to
inherit. (The visible side effect is that on a mixed-signal deck the `d_cosim`
build lines now print *before* the shape sentence rather than after. The shape
sentence now sits immediately above the deck it is about.)

**A re-run in the same session after the user registers a different simulator is
therefore never pinned to the old shape**: the previous run released its answer
before it returned, and this run's arm starts empty. Row **Z6** drives exactly
that through the real capability store — `altshow_op_dump 1` then `0` — and
measures `first deck=d record=d, second deck=c record=c`.

**Lazy, not eager**, and for a measured reason: `ase::op_save_tier` is not
side-effect free (on a capability cache miss it makes a scratch folder and
starts the user's simulator), so deciding at the arm would start it for runs
whose three gates ask the question zero times today. The arm costs nothing; the
first consumer that needs an answer pays, and the run then pays **once** instead
of three times.

## Two smaller defects taken in the same pass, both pre-existing

* **An empty name and a double space.** A registered simulator whose file does
  not exist leaves `ase::sim_status`'s `resolved` field empty *by design*
  (`sim_entry_kind` refuses the entry), and `op_tier_report` handed that straight
  to `sim_why`, which printed *"xschem was not able to find out anything about
  what&nbsp;&nbsp;can do"*. New `ase::sim_named_path` falls back
  `resolved` → `exe` (the path the user's own entry names) → the backend name,
  so a sentence about a simulator always names one. Row **Z8**.
* **Row `N6` could not tell its two numbers apart.** It asserted that a
  standalone `3` and a standalone `2` appeared *somewhere* in the netlist-time
  echo, so a line printing the two counts **swapped** — 2 cards covering 3
  devices, arithmetically impossible — satisfied it. Re-spelled to anchor each
  number to its own clause, with the swap asserted absent. Proved by SAB7: the
  swapped line gives `{1 1}` under the old spelling (a pass) and `{0 0 1 1}`
  under the new one (a red).

## Acceptance

Eight new rows, **all eight RED on the unmodified source** —
`RESULT: 8 FAILED (94 passed)`, red set exactly `Z1 Z2 Z3 Z4 Z5 Z6 Z7 Z8`, with
no pre-existing row changing name or status. Eight sabotages, applied to the
repo file and restored by `cp` from a gold copy with the md5 re-verified after
each:

| sabotage | red set |
|---|---|
| SAB1 `op_tier_now` never consults the pin | `Z1 Z2 Z3 Z4` |
| SAB2 the SENTENCE measures for itself | `Z1 Z2` |
| SAB3 the DECK measures for itself | `Z1 Z2` |
| SAB4 the RECORD measures for itself | `Z1 Z2` |
| SAB4b the RECORD hard-codes `d` | `Z3 Z4 Z6` + pre-existing `Q1 Q4 Q5 X3` |
| SAB5 the pin is never released at the end of a run | `Z5 Z6` + pre-existing `S10 A1 M1` |
| SAB6 the pin is not released when the renderer raises | `Z7` (and `Z8`, which the leak then poisons) |
| SAB7 the netlist line prints its two counts swapped | `N6` (in the other suite) |
| SAB8 `op_tier_report` goes back to the bare `resolved` field | `Z8` |

SAB5's three extra reds are the finding, not noise: a pin that outlives its run
corrupts rows that have nothing to do with this change, which is why the disarm
is not optional.

## What is NOT done

* **Neither suite has a `KX_FLOOR`/`RW_FLOOR`-style check-count floor**, so
  there is none to raise. Verified by grep over both files.
* The `op_dump_missing` sentence's *wording* is untouched. It is now only
  reached by a run whose deck really was shape `d`, where it is true.
* Nothing about issue 1334's folded-path guard, issue 1300's narrowing, or the
  RDW batch's live refutations.

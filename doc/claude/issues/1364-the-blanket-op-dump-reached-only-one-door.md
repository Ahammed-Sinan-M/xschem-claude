# 1364 — the blanket operating-point dump reached one door, and the user's own annotation path is the other one

**Status:** FIXED (this branch)
**Files:** `src/save.c`, `src/op_annot.tcl`, `tests/headless/test_op_dump_altshow.tcl`,
`tests/headless/test_ase_final.tcl`
**Found by:** the driver, from the user's report *"There are more serious things
broken with usage of this 'new' ngspice"*, 2026-09-05
**Supersedes the placement half of issue 1333. Fixes the `F16`/`F17` half of issue 1363.**

## What was wrong

Issue 1333 gave `op_annot::opdump_read` its first caller, through
`op_annot::opdump_merge`, in `op_annot::db_attach`. The comment it wrote beside
that call justified the placement like this:

> `db_attach` is the **one** place that puts an operating point onto a window.
> ASE-L's surface (`ase_window.tcl`) and the cadence profile
> (`utils/annot_mode.tcl`) both come through it, so one call covers both.

**That sentence was false, and its falseness was the defect.** `xschem
annotate_op` (`src/scheduler.c:2386`) is the general-purpose annotation verb and
nothing that reaches it directly comes through `db_attach`:

| door | where | reached db_attach? |
|---|---|---|
| 61 committed schematics' launcher buttons — `tclcommand="xschem annotate_op …"` | `xschem_library/examples/*.sch`, `sky130A/xschem_libs/sky130_tests/*/schematic/*.sch`, … | no |
| `Simulation > Graphs > Annotate Operating Point into schematic` (built twice, once per menubar) | `src/xschem.tcl:17421/17423`, `:17864/17866` | no |
| `Waves > Op Annotate` | same two blocks | no |
| the annotated raw carried into a new window / tab | `src/xschem.tcl:7219` (`open_sub_schematic`), `:7573` (`hi_descend`) | no |
| `cadence::_annot_tran_supply`'s second ask | `utils/annot_mode.tcl:2299` | no |
| `results::select` → `xschem raw select` | `src/results.tcl:758/760` | no |
| the cadence Alt-6 rungs — `xschem raw switch` / `xschem raw read` then `xschem update_op` | `utils/annot_mode.tcl:1177/1191/1097` | no |
| ASE-L `Results > Annotate` | `src/ase_window.tcl:2725` | **yes** |
| the cadence `6` chord | `utils/annot_mode.tcl:1424` | **yes** |

Rows `F36`–`F41` of `tests/headless/test_annot_stale_0684.tcl` say it in their
own header, and had said it since before 1333 landed: *"`Simulation > Graphs >
Annotate Operating Point into schematic`, or the waveform window's `Waves > Op
Annotate` — both a bare `xschem annotate_op`, i.e. an attach that never goes
through `op_annot::db_attach`."*

## Measured

With the user's own registry (`~/.xschem/ase_simulators` registers
`ngspice-ver50` → `ase::op_save_tier` answers `tier d reason dump`), cell
`sky130_tests/test_nfet_final`, a real run, then the door the launcher buttons
and both menu items use:

    xschem annotate_op <raw> 0 op
    op_annot::text M1  ->  id  = 409.7u
                           gm  =
                           gds =
                           vgs =
                           vth =
                           vds =

Five of six blank. **Issue 0617 restored**, on a run that exited 0 with a
perfect raw and a clean log. The one row that did appear is the accident, not
the feature: `.options savecurrents` puts `i(@dev[id])` in the raw with no card
present — `test_ase_final`'s own `F18` trap — so the ONE value that arrives by
chance is the one that survived and the feature's own five are the ones that
vanished.

    tests/headless/test_ase_final.tcl,  HOME with the user's ase_simulators : 6 FAILED (74 passed)
    tests/headless/test_ase_final.tcl,  HOME with no ase_simulators         : ALL PASS (80 checks)

Same tree, same commit, same binary. Neither answer was a code regression, which
is why the red sat unattributed until issue 1363 filed it.

## The fix — one call, in the tree's own choke point

`update_op()` (`src/save.c`) has described itself as the choke point since
RULING D5-3 was written: *"This is the choke point every 'annotate the operating
point' request funnels through: the `annotate_op` arm, both `raw switch` gates
and the bare [verb]"* — and `raw select` has joined them since. It is called
from exactly five places, all in `src/scheduler.c` (`:2544` annotate_op, `:10829`
raw switch, `:10875` raw select, `:10892` raw switch_back, `:14556` the
`update_op` verb).

So a new static `op_annot_autofill()` in `src/save.c` calls
`op_annot::opdump_autofill` from inside `update_op()`, **below its three
refusals and above its publish**:

* **below** the digital / zero-point / not-op-or-dc refusals, so a database that
  is not going to be published as an operating point is never merged into;
* **above** the publish loop, so the columns the merge adds are in `nvars` by
  the time `cursor_b_val[]` is filled and `ngspice_data_arm()` takes its view.
  Run after the loop and the numbers it supplied would publish one press late.

`op_annot::db_attach`'s own `opdump_merge` call is **removed**: it now sits
downstream of `xschem annotate_op`, which merges before it publishes, and
`op_annot::_annotated` — db_attach's own postcondition — is true only when
`annot_p >= 0`, which only `update_op()` sets. So an attach that reaches the
freshness stamp is an attach whose merge has already run. Keeping the call would
have parsed the same sidecar twice for an answer that cannot differ (36 ms on
the user's own 280 KB / 7825-parameter dump, measured).

### What the new door refuses, and why

`op_annot::opdump_autofill` carries the gate itself rather than inheriting it,
because it is a public Tcl proc:

* **op / dc only.** The dump is ONE snapshot. `gm` and `vth` move over a
  transient, so painting the snapshot flat across every time point would put a
  number nobody measured beside the thing it is drawn next to — RULING D5-1 in
  its own words. `cadence::_annot_tran_supply` reaches `xschem annotate_op
  <path> <lvl>` as its second ask, so this is a live arm and not a hypothetical.
* **one point only.** `update_op()` is deliberately one term weaker than the
  `raw switch` / `raw select` gates (issue 0862: a multi-point `.dc` sweep still
  publishes its FIRST step), while `show` reports the state at the END of the
  run — so on a sweep the merge would paint the last step's numbers flat across
  every step and publish them as the first. Blank is the honest answer there.
* **stale, unchanged.** Issue 0838's rule survives the new door verbatim: a
  sidecar older than its raw is not merged, so a previous run's numbers cannot
  be painted on. Row `W9`.
* **silent, unchanged.** Issue 0975: a run that worked must not be told it
  failed. A raw with no sidecar beside it is every run of every other shape, and
  `ase::op_report_missing` remains the one surface that speaks about a dump that
  did not arrive. Row `W10`.

### Re-entry

`op_annot::opdump_read` republishes with `xschem update_op`, which is now one of
the door's own entrances. Two latches, and both are load-bearing:

* a `static int busy` in `op_annot_autofill()` — without it the republish
  recurses;
* `::op_annot::opdump_merging`, set for the length of `opdump_read`'s
  republish — without it a caller naming a dump BY HAND would silently get the
  current raw's sidecar pulled in behind it as well, and the ordinary path would
  parse its own sidecar twice. Row `W15`.

## The fence

`tests/headless/test_op_dump_altshow.tcl`, rows `W8` … `W15`, all driven
**without `db_attach` anywhere**, so a tree that wires only the first door reds.

| row | subject | proved by |
|---|---|---|
| `W8` | `xschem annotate_op` alone merges the sidecar, and the node half survives | RED on the unmodified source |
| `W9` | the stale rule holds at the second door | SAB1 (stale check removed) → `W6 W9` |
| `W10` | no sidecar → no raise, no refusal, no invented column | SAB5 (a "remember the last dump" fallback) → `W10` |
| `W11` | a transient is never merged into | SAB2 (both type gates removed) → `W11` |
| `W12` | a second publish is idempotent, no column added | RED on the unmodified source |
| `W13` | `raw read` + `update_op` — the Alt-6 rungs' road — merges at the publish | RED on the unmodified source |
| `W14` | a multi-point dc sweep is not merged into | SAB3 (single-point gate removed) → `W14` |
| `W15` | a hand-driven `opdump_read` does not pull in the current raw's sidecar | SAB4 (latch removed) → `W15` |

`tests/headless/test_ase_final.tcl` is now **shape-aware**: `F11`/`F12`/`F14`/
`F21` ask `ase::op_save_tier` which deck the run actually built and assert that
shape's mechanism, while `F16`/`F17` — six real numbers on the sheet — are
asserted identically on both. That is what makes the suite answer the same on a
machine with the user's registry and on one without it, and it is why `F16`/
`F17` are the ONLY two rows that red when the fix is reverted:

    pre-fix source + this suite, registry HOME    : 2 FAILED (79 passed)  RED = F16 F17
    fixed  source + this suite, registry HOME     : ALL PASS (81 checks)
    fixed  source + this suite, no-registry HOME  : ALL PASS (81 checks)

## What was NOT wired, and why

* `xschem raw read` / `xschem raw_read` on their own. A read is *"load this"*,
  not *"show this"* (`utils/annot_mode.tcl:1160`), and merging at read time would
  put device columns into a database nobody has asked to annotate. Every product
  path that reads then annotates publishes afterwards, and the publish is where
  the merge is. Row `W13`'s first term is the fence: the column must be ABSENT
  after the read.
* the bare `xschem update_op` inside `op_annot::opdump_read`. Latched, above.
* transients and multi-point sweeps. Refused by name, above.

## Residue

* **The merge is re-done on every publish, by design, and it costs 36 ms on the
  user's largest real case.** `cadence::_annot_op_publish` calls `xschem
  update_op` on every `6` / `Alt-6` press, including its rung 1 ("the current
  slot IS an operating point — nothing to do"), so a press over an
  already-merged database re-parses the sidecar for an answer that cannot
  differ. It is not skippable from Tcl: "has this Raw allocation already been
  merged" is a fact only the C side can hold, and the alternative — a Tcl cache
  keyed on the raw path — would be wrong the moment `annotate_op` re-reads the
  file and builds a NEW database, which is the ordinary case. Measured 36 ms per
  pass on the user's own 280 KB / 7825-parameter dump, against the 69 MB raw
  re-read the same press already pays for.

* **The shape-`c`-after-shape-`d` hazard was driven, not reasoned about.**
  Ran shape `d` into a rundir, then MARKED the sidecar's `gm` to
  `1.23456e-09` (a value no run produces) with its mtime restored, then forced
  shape `c` into the SAME rundir and ran again. ngspice rewrote the raw and left
  the sidecar alone, so `dump 1788663893 < raw 1788663894`; the merge answered
  `stale 1` and `op_annot::text M1` rendered `gm = 503.3u` — the shape-`c` run's
  own number out of its own raw, not the marker. The stale rule holds through
  the new door on exactly the scenario that would have been worse than the bug.

* **Equal mtimes still pass**, by issue 0838's own rule ("one run writes both,
  and on a coarse filesystem clock they land on the same second"). So a shape-`c`
  run that overwrote the raw *within the same second* as an earlier shape-`d`
  run's sidecar would merge the stale one. Unchanged by this item and not
  reachable through a real ngspice run, whose wall time is seconds; recorded
  because the new door widens who could meet it.
* `tests/headless/test_ase_core.tcl` still carries the same shape-`c`
  expectations (`C5b`, `C6`×4, `C8`) and is **not** fixed here: measured
  2026-09-05 at 10 FAILED (172 passed) with the user's registry and 3 FAILED
  (179 passed) without it, and the three that survive both (`C11`, `NT17`,
  `NT18`, plus `E1e` which is registry-dependent for a reason that is not the
  tier) mean the suite cannot reach zero in this item either way. Issue 1363
  carries it.

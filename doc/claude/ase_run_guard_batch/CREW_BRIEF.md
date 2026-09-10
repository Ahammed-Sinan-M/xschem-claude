# ASE-L run-guard batch — one run at a time, tips on the strip, and a diagnostic that stops lying

Branch `fluid-editing`. Requested by the user 2026-09-08, verbatim:

> Go ahead and update ASE-L to not be able to launch new sim while one is
> already running (issue refusal text in CIW, which will be raised (but not
> focused!))
>
> And, add to batch - tooltips for the buttons in the ASE-L

Item C is not in those words. It is in the batch because it is a **live false
alarm on the user's bench right now**: their good run at 14:07 today printed
`only 0 of the 78 devices your schematic asks about are in it, so the rest of
the rows will be blank` as a red `#!` line, on a run whose annotation is
perfect. It was reported to the user and they confirmed the diagnosis.

---

## What was measured, so nobody re-derives it

The user's report was "annotates blanks and prints zilch in RDW". Root cause,
measured 2026-09-08 on their own bench:

1. **Two runs were launched, overlapping.** `/tmp/Xschem.log.1` shows two
   `xschem netlist` lines and two `This run is starting the simulator…` lines
   BEFORE either `simulation finished`. Both `Simulation > Netlist and Run`
   (`ase_window.tcl:559`) and the `N&>` strip button (`:737`) call
   `ase::ui::do_run`, a plain Tk button command — a double-click fires it twice.
   **Nothing anywhere checks whether a run is already in flight**: not
   `ase::ui::do_run` (`:7021`), not `do_run_existing` (`:7060`), not `ase::run`
   (`ase.tcl:5912`), not `ase::run_deck` (`:5956`).

2. **The deck carries `set appendwrite`** (issue 0929), so run 2 APPENDED its
   Operating Point plot to the raw run 1 had just written. The pre-run
   `file delete` at `ase.tcl:6014` only protects *sequential* runs — run 2
   deleted a file run 1 had not written yet.

        $ strings tb_bandgap_ase.raw | grep -E '^(Plotname|No\. Points|Date):'
        Date: Tue Sep  8 08:14:29  2026   Plotname: Operating Point   No. Points: 1
        Date: Tue Sep  8 08:14:29  2026   Plotname: Operating Point   No. Points: 1

   Same second, because they started together.

3. **`op_annot::opdump_autofill` (`op_annot.tcl:3849`) then refuses**, on its
   `raw points != 1` gate, and it is RIGHT to: `show all >` truncates so the
   `.opinfo` is run 2's, while `update_op()` publishes dataset 0, run 1's.
   Merging would paint run 2's `gm` beside run 1's node voltages.

   Control, same deck / same ngspice-ver50 / same schematic, only the plot
   count differing:

   | raw | `xschem raw points` | after `xschem annotate_op` |
   |---|---|---|
   | 1 dataset | 1 | **8248 vectors** — 212 devices, 7825 params merged |
   | 2 datasets | 2 | 423 vectors — nothing merged, every row blank |

**The gate is not the defect. The double launch is.** Do not touch
`opdump_autofill`'s gate.

Separately measured, and item C's subject: `ase::op_report_missing_dump`
(`ase.tcl:5650`) builds its `have` set from the dump's block headers VERBATIM
and compares against `devs`, which `op_annot::devpath` always lowercases
(`op_annot::_lower`). The user's `ngspice-ver50` is registered `-casemode
preserve` (`~/.xschem/ase_simulators:4`), so `show all` writes
`M.x1.x23.XM2.Msky130_fd_pr__pfet_01v8`. Driven directly:

    verbatim spelling  -> verdict = (silence)
    lowercase spelling -> verdict = op_dump_partial

Under `preserve` that check can never pass. The VALUES are fine — the C fold
ladder (`save.c:4175 raw_lookup_name`, rung 2) resolves the lowercase query
against the stored mixed-case name, measured `1.37276e-12` either way — so this
is purely a diagnostic that lies, and it lies on every run.

---

## Standing rules (CLAUDE.md; violating one wastes a whole item)

* `./src/xschem` with a **path**, never a bare `xschem` (the PATH one is 3.4.6
  from Jan 2025 and rewrites the user's recent-files list, issue 0924).
* Every launch carries **`--nolog`**, never `--logdir`. One exception:
  `test_ase_log_seam_0207`.
* **Never touch, move, back up or read-modify-write anything under `~/.xschem/`.**
  Reading is fine. The user's `ase_simulators`, `op_param_lists.conf` and
  `simulations/` are live data.
* Never `git checkout --` / `restore` / `stash` / `clean` against uncommitted
  work. Never `git push`, never open a PR.
* `tclsh run_regression.tcl` runs **solo** (issue 0990) — the driver owns it.
* Suites: `DISPLAY=:99 ./src/xschem --pipe --nolog -q --script tests/headless/<t>.tcl`
  (`--pipe`, or the output goes to the CIW and not to stdout).
* UI copy **terse**, acronyms **UPPERCASE** (OP, TR, DC, AC, SPICE, PDK, ASE-L,
  CIW, RDW).
* A `look` or `rule` debt clears **only** when the user says so. Record one at
  the moment it is incurred: `tests/headless/owed.sh add rule|look|suite`.
* `doc/claude/issues/NUMBERING.md` is the only numbering authority; grep the
  directory before minting and record the number in the same commit.
  **Next free is 1389.** This batch reserves:
      1389 item A   1390 item C   1391 item B   1392 item D (filed, NOT fixed)
* A floor is raised when rows are added and **never** lowered to make a run pass.
* Rebuild before any audit meant to be evidence — no harness builds.

---

## Item A — ASE-L refuses to start a second run (issue 1389)

`src/ase.tcl`, `src/ase_window.tcl`.

### The rule
While a simulation launched for a given results file is still running, a second
launch against that same results file is **refused**. The refusal text goes to
the **CIW**, and the CIW is **raised but NOT focused** — the user's own words,
with their own emphasis on the second half.

### Shape — one predicate, two consumers (invariant I1)

* **Key the lock on the RAW PATH, not on the session key and not on the
  button.** The thing that must not have two writers is the results file. Two
  ASE-L sessions on one cell, or a `Netlist and Run` racing a `Run`, are the
  same hazard as a double-click and a key on the button catches none of them.
  `[ase::backend_hook $sim raw_file] $state` is the resolver `run_deck` already
  uses at `:6014`.
* `ase::run_deck` is the **authority**: it refuses, by raising, just before
  `set id [eval execute 0 $cmd]` (`:6219`). That covers every door — the two
  UI doors, `ase::run`, `ase::run_existing`, and any script.
* The lock is **set after** the `$id == -1` check, never before: a launch that
  did not launch must not leave one.
* The lock is **cleared in `ase::run_done`** (`:6358`), at its head. Carry the
  key in `meta` (`rawlock`) so the clear uses the exact string the set used
  rather than resolving the path a second time.
* **A stale lock self-heals.** If `::execute(pipe,$id)` no longer exists the
  run is over however it ended, so the predicate answers "not in flight" and
  the lock is dropped. This is what stops a crashed `run_done` from bricking
  the button forever.
* `ase::ui::do_run` / `do_run_existing` ask the **same predicate first**, so
  they can refuse without calling `ase::ui::set_status $key fail` — the earlier
  run is still running and the status must keep saying so. Their existing
  `catch {ase::run …}` arm stays as the backstop for anything else that raises.

### The CIW raise — read this before writing it

⚠ **`raise` alone is a measured no-op under Weston/WSLg (issue 0054)** — it is
written down at `src/ciw.tcl:417`. The tree's raise-without-focus helper already
exists and is `raise_toplevel` (`xschem.tcl:7635`): withdraw + deiconify +
raise. Its sibling `raise_activate_toplevel` (`:7655`) adds
`xschem activate_window`, which is the focus, and is therefore **the wrong one
here**. Use `raise_toplevel`; do not write a third helper.

⚠ `.ciw` may not exist (`--nogui`, `--nolog`) and may be **withdrawn** rather
than destroyed — `wm protocol .ciw WM_DELETE_WINDOW {wm withdraw .ciw}`
(`ciw.tcl:435`), so a user who closed the CIW still has the widget.
`xschem::notify_ciw_visible` (`ciw.tcl:92`) is the existing predicate for
"actually in front of the user". Guard on existence, act on it, and never raise
out of a refusal path.

⚠ Refusing is not the same as reporting a failure. The refusal is a **note**,
not an `error` tag if that would recolour a still-healthy session — decide it,
state which you chose in the write-up, and record it as a rule debt if the
choice is the user's.

### Wording
Terse, and it must name the way out, which is `Simulation > Stop`. Read the
menu label from a constant rather than retyping it — the `annot_lbl_*` family
(`xschem.tcl:17727`) is the tree's precedent for exactly this, and
`ase::ui::lbl_save_op_params` (`ase_window.tcl:5339`) is the ASE-L one. If item
B mints strip-label constants, share them; the two items must not mint two.

### Fences
`tests/headless/test_ase_launch.tcl`, `test_ase_core.tcl`, and whichever suite
already drives `do_run`. Required rows, at minimum:
* a second launch against a live lock is refused, and **`execute` was not
  called** (the deck/raw are untouched);
* the refusal reaches the CIW channel;
* a stale lock (pipe gone, `run_done` never fired) does NOT refuse;
* a launch that fails (`execute` -1) leaves no lock;
* two DIFFERENT raw paths do not block each other;
* the ordinary single run is byte-identical to today — `test_ase_simreg_0931`
  row D4 pins `run_cmd` and every echo count; do not disturb it.

---

## Item B — tooltips on the ASE-L action strip (issue 1391)

`src/ase_window.tcl:726-746`. Eight buttons, every one a glyph:

    OP,TR  =  -->  X  N&>  >  !  ~

and their commands are `choose_analyses`, `add_variable_dialog`,
`output_editor`, `delete_selection`, `do_run`, `do_run_existing`, `do_stop`,
`open_viewer`. There is currently **no tooltip anywhere in `ase_window.tcl`** —
grep it, the count is zero.

* The tree has **exactly one tooltip mechanism**: `balloon`
  (`xschem.tcl:14826`). The RDW precedent is
  `catch {::balloon <w> <text> 1 0 300}` (`rdw.tcl:3226`) — pos 1, no
  motion-kill, 300 ms. Match it. `balloon_off` / `balloon_clipped` /
  `label_clipped` are for a tip whose STRING CHANGES; these strings do not, so
  do not reach for them.
* **One mint per action, shared with the menu entry.** Each strip button has a
  menu twin (`Simulation > Netlist and Run`, `Run`, `Stop`, `Tools > Waveform
  Viewer`, …). A tooltip that says something the menu does not is a second
  description of one action. Mint `ase::ui::lbl_*` constants, BUILD the menu
  entries from them, and let the tooltip name the same action. That is the
  0683/0661 discipline, and its own comment (`xschem.tcl:17714`) records the
  measured drift it prevents.
* Not every strip button has a menu twin (`=`, `-->`, `X` do not). Those get a
  tip that says what the button does, in the same voice.
* Terse, acronyms uppercase. `OP,TR` is an analyses chooser — say so without a
  sentence.
* Headless safety: `balloon` is pure Tk and the strip only exists under a GUI,
  but the suites drive `ase::ui` procs headless. Wrap in `catch` the way
  `rdw.tcl:3226` does.
* Consider the temperature entry `$top.tb.temp` (`:692`) — an unlabelled entry
  box beside a `°C` label. Decide, and say which way and why.

### Fences
`tests/headless/test_ase_window.tcl`. Read the tip back off the LIVE widget
(`bind $w <Enter>`) and compare it to the constant AND to a literal golden —
the `test_ase_window` W1t discipline, which is what stops a
constant-vs-constant tautology. One row per button; a button with no tip is a
red row, not a gap.

⚠ `test_ase_window` is one of `fluid-editing`'s 15 named baseline reds. Take
its name+status before you touch it and say what moved.

---

## Item C — the dump coverage check stops lying under `preserve` (issue 1390)

`src/ase.tcl:5650`, `ase::op_report_missing_dump`. See the measurement above.

* Compare **folded**, because the dump's own case follows the RUN's casemode
  and the annotation's device names are unconditionally lowercase. Mirror the C
  ladder's rule rather than inventing a second one: exact first, then folded —
  `save.c:4175 raw_lookup_name` is the shape, and its header block
  (`save.c:4196-4229`) is the authority on why folding the query in place is
  wrong.
* ⚠ **`distinguish` is the case where folding is not free.** Read
  `raw_case_mode_parse` (`save.c:2731`): `preserve` maps to case_sensitive **0**
  and only `distinguish` maps to 1. Decide whether this check honours that and
  say so; a fold that is right for `preserve` and wrong for `distinguish` is a
  new defect wearing the fix's clothes.
* Two names that differ only in case, both present, is the ambiguity
  `raw_build_fold_table` (`save.c:4111`) already refuses by storing -1. Do not
  build a second policy for it.
* **Do not change what the sentence says** unless the fold makes a clause
  false. The wording is ratified; the comparison is what is broken.

### Fences
`tests/headless/test_ase_final.tcl` or wherever `op_report_missing_dump` is
already driven — grep for it. Required rows: a `preserve`-cased dump with
lowercase `devs` is **silent**; a genuinely partial dump still says
`op_dump_partial`; the all-lowercase (`fold`) case is unchanged byte for byte.

⚠ `test_ase_final` reads differently under the user's HOME and an empty one
(issue 1363, fixed by 33e9627a). Run it BOTH ways.

---

## Item D — file only, do NOT fix (issue 1392)

`cadence::_annot_cause` / `_annot_cause_msg` (`utils/annot_mode.tcl:516`,
`:559`) classified this bench as `noparams` and told the user to *"Run the
simulation again with device parameter saving turned on"* — which was already
on. That is what sent them to `Outputs > Save All…`, visible in their action
log at line 64. The honest fourth cause is "the results file holds more than
one operating point, so the device numbers were not merged".

Item A makes this nearly unreachable, so it is **filed and not built**. Write
the issue with the measurement above and stop.

---

## Definition of done

* `make -C src` clean, and **rebuilt before any audit meant to be evidence**.
* Every suite you touched green on `:99`, named, with counts, run by you.
* Name+status against `fluid-editing`'s 15 named baseline reds — no new red
  names. `test_ase_window` may legitimately move (item B is in it); say which
  way and why.
* Issues 1389/1390/1391/1392 written, `NUMBERING.md` tail updated to 1393 in
  the same change.
* Debts recorded, not reported as done: the CIW **raises but does not take the
  keyboard** is a `look` debt by construction — the user put the emphasis
  there themselves and only their eyes on their own screen can settle it.

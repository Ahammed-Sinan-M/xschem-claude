# CREW_BRIEF — descend_run_batch

**Goal in one line:** `Netlist and Run` must work from anywhere inside the
design's own hierarchy, because ADE-L has no such restriction and the user asked
for it to go.

Everything below was MEASURED on 2026-09-08 at HEAD `19f8e351`, on the dev
display `:99` (openbox live), in the `sky130A` workarea. **Do not re-derive it.**
If a measurement here contradicts what you see, say so in your receipt with your
own numbers rather than quietly working around it.

---

## 0. The user's words

> I open sky130_tests_ase/tb_bandgap, then the debug_st1 state and then, Session
> Design Window so that the schematic is linked to that ASE-L and then, I descend
> into x1 and again x1. Now, I click the N&> (Netlist and Run button) in ASE-L to
> get: `ase: design is not the current schematic; open it via Session > Design
> Window first`. Where does this inane restriction come from? There is no such
> limitation in Cadence's Analog Design Environment (ADE-L), which we want be
> better than.

and, on how to pay for it:

> We want to solve the user's problem without adding cost.

---

## 1. Why the guard exists (it is not arbitrary — do not just delete it)

`global_spice_netlist()` netlists `xctx->sch[xctx->currsch]` — **the level you are
standing on** (`src/spice_netlist.c:359-373`), not the top of the stack.

```
level 0 : ** sch_path: .../tb_bandgap/schematic/tb_bandgap.sch   14862 bytes, 8 .subckt
descend x1, x1
level 2 : ** sch_path: .../bandgap_opamp/schematic/bandgap_opamp.sch  4685 bytes
```

Delete the guard without replacing it and `N&>` two levels down silently
simulates the op-amp alone — no sources, no testbench, a results file that looks
healthy. **The guard is a symptom. The fix is to make the design current for the
duration of the netlist and then put the user back.**

## 2. The round trip works, is exact, and costs 34 ms

```tcl
set nlev [xschem get currsch]
for {set i 1} {$i <= $nlev} {incr i} {
  lappend names [lindex [split [string trim [xschem get sch_path $i] .] .] end]
}
for {set i 0} {$i < $nlev} {incr i} { xschem go_back 2 }
xschem netlist -noalert $nl
foreach n $names { xschem descend -fallback -inst $n }
```

Measured on tb_bandgap, 2 levels: `sch_path` restored to `.x1.x1.`, every descend
returned 1 with an empty `descend_error`, zoom/origin identical to 15 significant
figures, **34 ms**, and the netlist is **byte-identical** (`cmp`) to one taken at
the top before descending.

**And the trip is already being made, twice, on every press of that button:**

| already happens on every `N&>` | measured |
|---|---|
| `xschem netlist` — the C netlister loads every sub-block and restores | 66 ms |
| `op_annot::save_cards` — the Tcl walk behind the 468 OP save cards, descending and returning through the whole design | 177 ms |
| **what this batch adds** | **34 ms** |

`global_spice_netlist` already calls `unselect_all`, so selection churn is
likewise already paid. **That is the "no added cost" answer, and it is the
sentence the user is owed in the write-up.**

## 3. ⚠ THE THIRD SEAM DOES NOT EXIST. The driver was wrong about it; do not fix it.

The driver first measured a bare `xschem raw read` while descended, saw
`sim_sch_path` go empty, and concluded that the results basis was broken too.
**That was the wrong door.** The annotation path passes a hierarchy level:

```
ase::ui::annot_ensure_loaded  ->  level from ase::session_for_current
  -> op_annot::db_attach $path $level
    -> xschem annotate_op $np $level
      -> scheduler.c:2540  raw->level = level ; raw->schname = sch[level]
```

Measured, standing two levels down inside tb_bandgap with the `debug_st1`
session open:

```
ase::session_for_current  ->  {... 0 ...}          (level 0 — correct)
op_annot::db_attach $raw 0  ->  raw_level=0  sim_sch_path='x1.x1.'   ✅
op_annot::db_attach $raw {} ->  raw_level=2  sim_sch_path=''         (the bare door)
```

So annotation at depth is **already right**, and `Simulation > Run` pressed while
descended does **not** annotate blanks. Item C's job is to **PIN this with a
regression row**, not to change it. If you find yourself editing `attach_dbs` or
`annotate_op`, stop and re-read this section.

One narrow hole is recorded and deliberately NOT closed here: `annot_ensure_loaded`
takes the level only when `[lindex $s 0] eq $key`, so if a *different* session
(one bound to a descendant cell) owns the nearest level, this session's refresh
passes `{}` and stamps at `currsch`. Record it in the write-up; do not build it.

## 4. The one real cost, and it is already-solved doctrine

`go_back` is not read-only. It calls `load_backup_as()` whenever a `<cell>~.sch`
sits beside the cell, and that ends in `set_modify(1)`. Measured on the shipped
`sky130_tests_ase/bandgap_opamp`, which ships with exactly such a `~`:

```
descend x1 ; go_back  ->  modified 0 -> 1   (autosave_backup 1)
descend x1 ; go_back  ->  modified 0 -> 0   (autosave_backup 0)
```

and with a `~` whose content differs, a clean 73-instance buffer came back as a
72-instance one. With `autosave_backup` **off** and a genuinely modified buffer,
descend + go_back **silently reverts the unsaved edit** (issue 0626).

`op_annot.tcl` already ships both halves — `op_annot::_park_backup` (park the
flag at 0 for a CLEAN buffer) and `op_annot::_assert_saveable` (REFUSE the
modified + `autosave_backup 0` combination). **Reuse the doctrine; do not
re-derive it, and do not call across into `op_annot::` from `ase::` if that would
create a load order you have not checked.**

⚠ **AND THERE IS ONE THING op_annot's WALK DOES NOT COVER.** op_annot descends
BELOW its entry level and comes back, so `go_back`'s own `load_backup_as`
restores its entry buffer. **This batch pops the entry level and returns by
`descend`, and `descend_schematic()` uses plain `load_schematic()` — NOT
`load_backup_as()`.** So a modified entry buffer's unsaved edits are dropped from
the buffer on the way back down (the `~` file survives on disk; the screen does
not). The verb `xschem load_backup <cellfile> [notitle]` (scheduler.c:7948,
returns 1/0) is the restore. See the decision table in PLAN.md item A.

## 5. Standing rules (the ones previous crews paid for)

* **Always give the binary a path.** `./src/xschem`, `$XSCHEM`, or
  `tests/headless/devdisplay.sh exec ./src/xschem`. A bare `xschem` is
  `/usr/local/bin/xschem` 3.4.6 and it rewrites the user's `recent_files`
  (issue 0924).
* **Every launch carries `--nolog`.** Exceptions are `test_ase_log_seam_0207`
  and `full_audit.sh`'s `logdir_tests`; if you need a log, use
  `--logdir $(mktemp -d)`. Never write into `/tmp/Xschem.log.*`.
* **Never touch, move, back up or write anything under `~/.xschem/`.** Reading is
  fine. In particular do NOT run a simulation that would overwrite
  `~/.xschem/simulations/tb_bandgap_ase.raw` — that is the user's own bench
  result and the driver's control measurement.
* **Never** `git checkout --`, `git restore`, `git stash`, `git clean`,
  `git push`, and never open a PR.
* **Run `run_regression.tcl` SOLO** (issue 0990). `exit -1` is the tell that two
  ran at once.
* **Never `pkill` anything you did not start.** A previous crew killed the SHARED
  `:99` window manager for four minutes and invalidated another agent's audit.
* **Rebuild before any audit meant as evidence.** `make -C src`. No harness
  builds.
* **Acceptance is a name-and-status diff, never a count.** The floors below are
  RAISED when rows are added and NEVER lowered.
* UI copy is terse; acronyms UPPERCASE (OP, SPICE, PDK, ASE-L, CIW, RDW).
* Anything decided on the user's behalf gets an `owed.sh add rule` entry.

## 6. How to run the bench by hand

```sh
tests/headless/devdisplay.sh start          # idempotent, ~0.3 s
tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script <t>.tcl
```

The sky130A workarea needs its rc; sourcing it from inside a script works:

```tcl
catch {source [file join $repo sky130A cadence_style_rc]}
```

⚠ **Opening a state view makes a SECOND xschem window current.** Measured:
`ase::open_state sky130_tests_ase tb_bandgap debug_st1` leaves
`current_win_path = .x1.drw` on `untitled.sch`, so a `descend -inst x1` right
after it fails with "instance not found". Call
`ase::ui::design_window $key` first — that is what puts `.drw` back.

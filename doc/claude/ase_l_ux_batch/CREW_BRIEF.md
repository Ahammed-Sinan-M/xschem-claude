# Batch: ASE-L — Save State confirm, then the font/theme derivation

Opened 2026-09-09 on the user's instruction:

> *"let's fix the Save State thing first. I noticed that. Undo not required. Just confirm
> if overwriting an existing state. One commit for this. After that, you can do font/theme
> fix. Begin batch"*

Two items, **two commits, in this order**. Item 2 does not start until item 1 is committed.

## Standing rules every crew obeys

- **Give the binary a path.** `./src/xschem`, never a bare `xschem` (issue 0924 — the
  `PATH` one is 3.4.6 from Jan 2025 and rewrites `~/.xschem/recent_files`).
- **Every launch carries `--nolog`.** Never `--logdir`.
- **Never touch, move, back up or read-modify-write anything under `~/.xschem/`.**
  ⚠ **A SIMULATION RUN IS SUCH A WRITE.** `ase::rundir` with an empty `rundir` key returns
  `set_netlist_dir 0` (`src/ase.tcl:4819`) — `~/.xschem/simulations`, one global directory
  for every state of every cell. Running any bench under `sky130A/` overwrites the user’s
  own deck, log and `.raw`. It has already cost them one (see `LEDGER.md`). No crew runs a
  simulation on a bench under `sky130A/`; a probe that needs a run uses a scratch library
  and an explicit `rundir`.
  Reading is fine.
- **Never** `git checkout --`, `git restore`, `git stash`, `git clean` against uncommitted
  work. Never `git push`, never open a PR.
- **Run `tests/headless/run_regression.tcl` SOLO** (issue 0990 — two at once corrupt each
  other and the loser reports a `FATAL` that never happened; `exit -1` is the tell).
- **Floors are RAISED when rows are added and NEVER lowered.**
- GUI work lands on the dev display: `tests/headless/devdisplay.sh start`, then
  `DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog --script sky130A/cadence_style_rc
  --command "source <probe>.tcl"`.
- **UI copy is terse and acronyms are UPPERCASE** (MOS, SPICE, PDK, OP, ASE-L, CIW, PATH).
- **A new user-facing sentence is the USER'S ruling, not a crew's.** Mint it, ship it,
  and record `owed.sh add rule` for it. Never leave it in a write-up only.
- A pixel deliverable is never "done" on a green suite. Record `owed.sh add look` and say
  "suites green, please look".

## Item 1 — Save State must confirm before it overwrites an existing state

**The defect, verified 2026-09-09 on the live binary.** `Session > Save State` is always a
Save-As (`src/ase_window.tcl:511` → `save_state_dialog` :6327 → `save_state_ok` :6387).
Its only guard is `ase::ui::save_as_needs_confirm` (:6375), whose docstring records the
v1 decisions **D8** and **D13**:

> *"D13: overwriting a DIFFERENT existing view needs NO confirm in v1 — the spec's only
> confirm trigger is read-only + same-target."*

Measured, session `ngspice_state1` open, sibling `debug_st1` present and writable:

```
save_as_needs_confirm(-> debug_st1)      = 0     <- a DIFFERENT, EXISTING state
save_as_needs_confirm(-> ngspice_state1) = 0     <- your own; correct, that is a Save
save_as_needs_confirm(-> zz_brand_new)   = 0     <- does not exist; correct
```

So typing an existing sibling view into the Save-As form destroys it with no warning.

**D13 IS OVERRULED BY THE USER.** Undo is explicitly NOT required — a confirm is.

## Item 2 — the font and theme derivation (PLAN.md Stage 1)

Held until item 1 is committed. Scope is `doc/claude/ase_l_ux_batch/PLAN.md` Stage 1
(1a–1f): derive the named fonts from `TkDefaultFont`/`TkFixedFont` instead of naming
Arial and Courier, right the type ladder, make `apply_theme` set a foreground wherever it
sets a background, derive the treeview column policy from font metrics, narrow the
process-global combobox glob, and guard the live balloon. `preview_theme.tcl` in this
directory is a working in-memory prototype of most of it.

# 1397 — headless suites write the developer's real `~/.xschem/geometry` and evict their entries

**Found 2026-09-09** by an adversary on the issue-1396 batch, while answering "what else
moved". Not caused by that change; it has been true for as long as the suites have opened
schematics.

## What happens

`store_geom` (`src/xschem.tcl:16062`) records a per-schematic window geometry and writes
the list to `$USER_CONF_DIR/geometry`, keeping the **100 most recent entries**. Several
headless suites open schematics from their own scratch libraries without redirecting
`::USER_CONF_DIR` — `tests/headless/scratch.tcl` provides the redirect, and the suites that
call it are safe, but the ones that do not are writing the developer's real file.

Measured on this box after one session of suite runs:

```
$ wc -l < ~/.xschem/geometry
101
$ grep -cE 'scratch|/tmp/|tests/' ~/.xschem/geometry
50
```

**Half the file is scratch paths**, each naming a per-run directory
(`tests/headless/.scratch/_ase_launch_33796/aselib/nfet_clean/schematic/nfet_clean.sch`)
that no longer exists. Every one of those displaced a real entry the developer had, and
the cap makes the loss permanent: fifty of their remembered window geometries are gone.

## Why it matters more than it sounds

It is silent, it is cumulative, and it targets exactly the file whose whole purpose is to
remember something the user cannot re-derive. It is also the same family as issue 0924
(a stale `xschem` on `PATH` emptying `File > Open Recent`) and as the incident recorded in
`doc/claude/ase_l_ux_batch/LEDGER.md` (an agent's run overwriting `~/.xschem/simulations`):
the test harness reaching into `$HOME` because nothing stopped it.

## Two fixes, neither taken here

1. **Per-suite.** Every suite that opens a schematic calls the scratch helper's
   `::USER_CONF_DIR` redirect. Correct, and it is the shape already in the tree — but it is
   opt-in, so the next suite written without it reopens the hole. A lint row of the shape
   `test_ase_simchoice_1395` row L1 already uses (scan every `test_*.tcl`, red unless the
   redirect appears before the first schematic open) is what would close it for good.
2. **Harness-wide.** Run every suite under a scratch `HOME`. Measured during this batch:
   `HOME=<scratch> DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog --script
   tests/headless/test_ase_dialogs.tcl` gives the identical `ALL PASS (215 checks)` and
   leaves `~/.xschem/geometry` byte-identical. One environment variable in
   `run_suites.sh` / `full_audit.sh` / `devdisplay.sh exec` covers every suite at once,
   including ones nobody has written yet, and it needs no per-suite discipline.

Option 2 is the cheaper and the more complete of the two, and option 1's lint row is what
makes it hold. Both are the user's call.

⚠ **OPTION 2 HAS A TRAP, MEASURED THE FIRST TIME IT WAS USED.** `devdisplay.sh` keeps its
state in `${XSCHEM_DEVDISPLAY_DIR:-$HOME/.claude/xschem_dev_display}`, and so do
`gui_gate.sh:53`, `xvfb_arm.sh:98`, `spawn_reaper.sh:313` and the two gate self-tests. Move
`HOME` and the harness stops finding the live dev display — it does not fail, it **skips**:
a `run_regression.tcl` taken that way came back `Total num fail: 0` with

```
NODISPLAY: headless/test_ase_simdlg_0937 display arm NOT RUN -- the persistent dev
display is not up, so THIS ARM VERIFIED NOTHING.
```

repeated for every GUI suite. A clean zero, and every display arm silently unverified.
The suites say so out loud, which is the only reason it was caught; a reader skimming for
`Total num fail` would have banked it. **Whatever ships option 2 must export
`XSCHEM_DEVDISPLAY_DIR` alongside the scratch `HOME`**, pointing at the real state dir —
that is what the dev display is for, and it holds no user data worth protecting.

## Not recoverable

The fifty evicted entries are gone. The file was md5'd before the runs but never copied,
so there is no snapshot to restore from. The next crew snapshots rather than hashes.

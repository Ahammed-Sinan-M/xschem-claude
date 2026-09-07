# 1334 — a mixed-case run folder silently loses the operating-point dump, and the probe cannot see it

**Status:** FIXED (this branch)
**Files:** `src/ase.tcl`
**Found by:** review of the `op-wcard` sibling branch, 2026-09-05

## What was wrong

ngspice case-folds the **whole** `show >` redirect target, directory component
included, and exits 0 having written nothing when the folded directory is
absent. `op_annot::opdump_path` lowercases the path itself so that the asking
and reading sides agree — but agreeing on a path ngspice cannot write to only
makes the failure consistent, not survivable.

**The probe cannot detect it.** Capability deck C asks with a *relative* target,
`show all > probe_c.txt`, which has no directory to fold. So a probe that
watched the printer work says nothing whatever about the path the real deck will
use.

## Measured

`build-ver_50`, same cell, only the run directory changed:

| rundir | probe | tier | exit | raw | `.opinfo` | annotation |
|---|---|---|---|---|---|---|
| `lower_ok` | 1 | d | 0 | good | written | five values |
| `MixedCase` | 1 | d | 0 | good | ***never written*** | **five blank** |

**Control, same `MixedCase` directory, per-device shape on 45.2: all five rows
annotate.** So this is not a hazard the older shape shares — it is a regression
shape `d` introduces.

Bare ngspice, both builds:
```
show all > MixedCase/Up.opinfo    -> exit 0, nothing written, no stderr
```

## Not fixed here, and deliberately

A **space** in the run directory also breaks the redirect (ngspice splits on it
and creates a junk file named after the first word). It is refused by the same
predicate, but it is **not this feature's bug**: measured control, the shipped
per-device shape on 45.2 in a directory with a space fails to write the raw at
all. That is a pre-existing ASE-L defect, orthogonal, and not filed here.

## The fix

`ase::op_dump_reachable_dir` is a **pure string predicate** — no filesystem —
because the hazard is decided by the spelling of the path and nothing else,
which is what lets the guard run before the run directory exists.
`ase::op_dump_dir` reads the directory without creating it (`set_netlist_dir 2`,
the read-only spelling; `ase::rundir`'s own fallback is `0`, which mkdirs, and
`ase::op_tier_report` calls this path just to *describe* a run).

New guard **G3b**, above G3a, with its own reason token `dumppath` — because
`c unsafe` would say the shorter way is risky when what is actually true is that
this run folder's *name* defeats the redirect. It gets its own
`op_tier_perdevice` sentence naming the remedy.

After: `MixedCase` selects `tier c reason dumppath` and annotates all five rows.

Rows X1–X6 of `tests/headless/test_op_dump_altshow.tcl`.

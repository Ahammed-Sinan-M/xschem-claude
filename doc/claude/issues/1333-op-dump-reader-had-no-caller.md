# 1333 — the blanket operating-point dump shipped with no caller, and shape d annotated nothing

**Status:** FIXED (this branch) — **but its PLACEMENT was wrong and is superseded by issue 1364.**

> **2026-09-05.** The sentence below — *"`db_attach` is the one place that puts
> an operating point onto a window"* — is FALSE, and it was load-bearing. It is
> why the merge never reached `xschem annotate_op`, and therefore never reached
> the 61 committed schematics' launcher buttons, either `Annotate Operating
> Point into schematic` menu item, `Waves > Op Annotate`, the raw carried into a
> new window, `results::select`, or the cadence Alt-6 rungs. Issue **1364**
> moves the merge into `update_op()`, the tree's own choke point, and deletes
> the `db_attach` call this issue added. Everything else here — the stale rule,
> the "merge, do not replace" shape, the measurement table — stands.
**Files:** `src/op_annot.tcl`, `src/ase.tcl`
**Found by:** review of the `op-wcard` sibling branch before cherry-pick, 2026-09-05

## What was wrong

`op_annot::opdump_read` was defined, documented and covered by 33 passing
checks, and **nothing in the tree called it**:

```
$ git grep -n opdump_read -- src/
src/op_annot.tcl:3661:proc op_annot::opdump_read {path} {
```

That is not a missing convenience. Shape `d` **replaces** the per-device save
cards rather than adding to them — it emits `.save all` and no `.save @dev[param]`
at all — so with nothing reading the dump the raw carried node voltages and zero
device parameters, and the dump sat on disk unread.

## Measured

Cell `sky130_tests/test_nfet_final`, same script, only the simulator changed:

| binary | probe | tier | `.save @` cards | raw vars | annotation |
|---|---|---|---|---|---|
| `/usr/bin/ngspice` 45.2 | `altshow_op_dump 0` | c | 6 | 13 | gm gds vgs vth vds = **value** |
| `build-ver_50` (has `10276f993`) | `altshow_op_dump 1` | **d** | 0 | 8 | **all six absent** |

`op_annot::text M1` rendered `id =  gm =  gds =  vgs =  vth =  vds =` — issue
**0617 verbatim**, the defect the whole operating-point annotation feature was
built to remove. Upgrading to the binary the feature is *designed for* turned
five working rows into five blank ones.

## The fix, and why it is where it is

`op_annot::opdump_merge` is called from `op_annot::db_attach`, not from a run
callback. Two measured reasons:

* `xschem raw add` raises **"No raw file loaded"** unless a database is already
  on the window, so the merge cannot happen when the run finishes — only when
  one is attached;
* `db_attach` is the **one** place that puts an operating point onto a window.
  ASE-L's surface (`ase_window.tcl:2725`) and the cadence profile
  (`utils/annot_mode.tcl`) both come through it, so one call covers both.

A **stale** sidecar is not merged, for issue 0838's reason word for word: a
number painted onto a schematic carries no provenance, so one left by an earlier
run is indistinguishable from a live one. Equal mtimes pass — one run writes
both files and a coarse filesystem clock lands them on the same second.

The merge is `catch`-wrapped. The raw's node half is good and every shape but
`d` has all its numbers in it, so a sidecar that will not parse must not turn a
working attach into a refusal; issue 1335's reporter is the surface that speaks
about a dump that did not arrive.

## After

Same cell, `build-ver_50`, through `db_attach` with no hand call:

```
ANNOTATION after db_attach   id:value gm:value gds:value vgs:value vth:value vds:value
```

**6/6 against shape c's 5/6** — the dump supplies `id` under the bare
`@m...[id]` spelling that shape c only ever gets as `i(@m...[id])` from
`.options savecurrents`.

Rows W1–W7 of `tests/headless/test_op_dump_altshow.tcl`.

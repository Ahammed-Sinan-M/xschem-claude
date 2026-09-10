# 1394 — a zero-instance child schematic turns a later `xschem netlist` into a modal that hangs a scripted run

STATUS: **OPEN — PRE-EXISTING DEFECT, reproduced at HEAD `19f8e351` with no
`ase::` code in the picture at all.** Found 2026-09-08 by crew A of the
`descend_run_batch` while building a two-level test fixture, and **filed against
the batch only because the batch is what walked into it** — nothing in
`descend_run_batch` (items A, B, C) causes it, and it does **not** reproduce on
the real `sky130_tests_ase/tb_bandgap` bench the batch was measured on, whose
descended netlist is byte-identical to the top one. Do not attribute this to the
descend/round-trip work.

## What happens

On a hand-written two-level fixture whose **child schematic has zero
instances**:

```tcl
xschem load  <parent>.sch
xschem descend -inst x1        ;# the child, 0 instances
xschem go_back 2
xschem netlist -noalert <file> ;# <-- modal appears; a scripted run hangs here forever
```

A `tk_messageBox` pops with **"Please Set netlisting mode (Options menu)"** and
the script never returns. `-noalert` does **not** suppress it (see below), so
every headless-but-`has_x` harness — `devdisplay.sh exec`, a `:0` run, a GUI
suite — stops dead with no output, no `FAIL`, and no banner. Under `--nogui`
(`has_x` 0) the modal is skipped and the netlist is silently written in the
wrong mode instead, which is the quieter half of the same defect.

## Citations — VERIFIED against the source, not copied

Each of these was re-read in the tree before being written here.

**1. The modal, and why `-noalert` cannot reach it — `src/scheduler.c:9157-9170`.**
The netlist dispatcher is a plain if/else chain on `xctx->netlist_type`, and the
message box is its **`else`**:

```c
if(xctx->netlist_type == CAD_SPICE_NETLIST)        err = global_spice_netlist(hier_netlist, alert);
else if(xctx->netlist_type == CAD_VHDL_NETLIST)    err = global_vhdl_netlist(hier_netlist, alert);
else if(xctx->netlist_type == CAD_VERILOG_NETLIST) err = global_verilog_netlist(hier_netlist, alert);
else if(xctx->netlist_type == CAD_SPECTRE_NETLIST) err = global_spectre_netlist(hier_netlist, alert);
else if(xctx->netlist_type == CAD_TEDAX_NETLIST)   global_tedax_netlist(hier_netlist, alert);
else
  if(has_x) tcleval("tk_messageBox -type ok -parent [xschem get topwindow] "   /* :9167 */
                    "-message {Please Set netlisting mode (Options menu)}");   /* :9169 */
```

`alert` — the flag `-noalert` clears at `src/scheduler.c:9089` — is passed to the
five `global_*_netlist()` back ends and **is not consulted on this arm**. So the
`netlist [-noalert]` documented at `src/scheduler.c:9047` cannot suppress it, by
construction. ✅ VERIFIED, exact lines.

**2. The type gets moved aside for a zero-instance file — `src/save.c:6469`.**
Inside `load_schematic()`, under `if(reset_undo)`:

```c
if(!strcmp(tclresult(), "SYMBOL") || xctx->instances == 0) {   /* :6469 */
  if(xctx->netlist_type != CAD_SYMBOL_ATTRS) xctx->save_netlist_type = xctx->netlist_type;
  xctx->netlist_type = CAD_SYMBOL_ATTRS;
  set_tcl_netlist_type();
  xctx->loaded_symbol = 1;
}
```

✅ VERIFIED, exact line. `CAD_SYMBOL_ATTRS` is **5** (`src/xschem.h:229`), and
5 is not one of the five formats the dispatcher tests for (SPICE 1, VHDL 2,
VERILOG 3, TEDAX 4, SPECTRE 6 — `src/xschem.h:225-230`). So a `netlist_type`
left at `CAD_SYMBOL_ATTRS` falls straight through to the modal. That much is
airtight: **descending into a zero-instance schematic is sufficient to arm the
defect; the only question is what disarms it again.**

**3. ⚠ CREW A's STATED CAUSE — "the parent reload does not put it back" — IS
NOT CONFIRMED BY READING, and this issue says so rather than repeating it.**
The very next lines are a restore, and they run on the same `reset_undo` path
`go_back` uses:

```c
} else {                                    /* src/save.c:6474-6480 */
  if(xctx->loaded_symbol) {
    xctx->netlist_type = xctx->save_netlist_type;
    set_tcl_netlist_type();
  }
  xctx->loaded_symbol = 0;
}
```

and `go_back` does reach it: `src/actions.c:6505-6506`,
`if(from_embedded_sym || !load_backup_as(filename, set_title)) load_schematic(1, filename, set_title, 1);`
— `reset_undo` 1, and the parent has instances, so on a straight reading the
`else` fires and `netlist_type` comes back. **The reproduction is measured; the
step that defeats this restore is not established.** Two candidates, in order:

* **(a) `save_netlist_type` can legitimately hold a value that is not a format.**
  `alloc_xschem_data()` initialises it to **0** for every context —
  `src/xinit.c:913`, and that function runs per window and per tab
  (`src/xinit.c:1002, 1060, 1605, 2089, 2242, 3662`), not once per process. Zero
  is not a `CAD_*` value either, so any restore that fires before
  `save_netlist_type` has ever been given a real type writes 0 into
  `netlist_type` and lands on the identical `else`. The stash at `:6470` is
  itself conditional (`if(xctx->netlist_type != CAD_SYMBOL_ATTRS)`), so a second
  zero-instance load in a row does not refresh it.
* **(b) the reload took a different path** — an early `return 0` in
  `load_schematic()` (there are several; one is at `src/save.c:6414`, the empty
  filename arm) or the `load_backup_as()` branch, which loads the `~` file and
  then rewrites the identity — so the `reset_undo` block ran against a different
  name, or did not run.

**Whoever fixes this must settle (3) first.** A `dbg(0, ...)` of
`netlist_type` / `save_netlist_type` / `loaded_symbol` / `instances` on both
sides of the `descend` and both sides of the `go_back` costs one build and turns
the whole thing from a hypothesis into a line number.

## Blast radius, and why it is worse than it looks

* **A scripted run hangs, silently.** No exit code, no banner, no `FAIL` —
  `banner_complete` never fires and `banner_died` never fires either, so a
  harness reading the log (`tests/banner_rule.tcl`, `run_suites.sh`,
  `full_audit.sh`) sees a case that simply never ended. That is the one shape
  CLAUDE.md's banner rule cannot classify.
* **It is armed by an ordinary act.** Descending into a not-yet-drawn child cell
  is what a designer does all day, and an empty schematic is the normal state of
  one. Nothing tells the user the netlist mode changed under them.
* **`--nogui` gets the quiet variant**: `has_x` is 0, the modal is skipped, and
  `xschem netlist` returns having written nothing useful in `CAD_SYMBOL_ATTRS`
  mode.

## What the batch did about it, short of a fix

Crew A did not have permission to touch `doc/claude/issues/`, so it is filed
here by item D. In the meantime (receipt
`doc/claude/descend_run_batch/receipts/01-item-A-round-trip.md` §4(d)):

* the RT rows drive the round trip with a **probe** rather than a netlist;
* row **RT11** stubs `ase::netlist_in_place`;
* the RT child fixture is given **one instance** as insurance.

Those are workarounds in the test, not a fix, and they should be reverted when
this is closed.

## Acceptance

- A regression row that loads a parent, descends into a zero-instance child,
  returns, and asserts `xschem get netlist_type` is the mode it started in.
- The same row, extended: `xschem netlist -noalert <f>` after the round trip
  produces a netlist of the parent, with no modal, under `has_x` **and** under
  `--nogui`.
- Independently of the round trip: **`-noalert` should suppress this message
  box too**, or the message box should not be modal on a scripted `netlist`.
  Today it is neither, and that is what turns a wrong mode into a hang.
- The RT-row workarounds above are removed and the rows still pass.

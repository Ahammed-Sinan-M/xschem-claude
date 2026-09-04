# ASE-L: the transistor operating-point probe — clicking a transistor BODY in
# Select On Design queues ngspice internal device parameters (gm, id, cgs, vth …),
# the gm/ID design quantities.  Spec: doc/claude/specs/ase_l_device_params.md.
#
# Until now a device click hit the "v1 queues source currents only" notice and
# queued nothing: only wires/net labels (voltages) and vsource/ammeter bodies
# (currents) were pickable.  ase_l.md deferred device currents because the names
# "depend on subcircuit internals invisible to the schematic click".  That turned
# out to be over-cautious — the name IS derivable, and this file pins the
# derivation against BOTH the engine and ngspice's own measured spelling.
#
# THE FOUR NAMING FORMS, each MEASURED against ngspice-47 + sky130A before a line
# of this feature was written (spec receipt §1):
#
#   top-level primitive   M1       ->  @m1[gm]
#   top-level PDK subckt  XM1      ->  @m.xm1.msky130_fd_pr__nfet_01v8[gm]
#   nested primitive      X1/M2    ->  @m.x1.m2[gm]
#   nested PDK subckt     X1/XM1   ->  @m.x1.xm1.msky130_fd_pr__nfet_01v8[gm]
#
# The fixture reproduces all four SHAPES with a local `dp_pdkfet.sym` standing in
# for the PDK device (spiceprefix=X, `@pinlist dpfoundry__@model`), so the suite
# does not need sky130A installed to pin the derivation.
#
# THE ASYMMETRY THIS FILE EXISTS TO PROTECT (spec receipt §3).  The deck spelling
# and the raw spelling genuinely differ, and both were measured:
#   * `.save @m.xm1.m…[id]`     saves the vector;
#   * `.save i(@m.xm1.m…[id])`  is ACCEPTED and then SILENTLY DROPS it — the run
#     succeeds, the raw simply lacks the vector, no diagnostic anywhere;
#   * the raw NAMES that same vector `i(@m.xm1.m…[id])`, and `v(@…[vth])` for a
#     voltage-typed parameter, while conductances/capacitances/charges come back
#     BARE.
# So sod_expr must emit the bare form (deck) and plot_map_expr must hand the
# viewer the wrapped one (raw).  A regression that "simplifies" those into one
# spelling loses either the save or the trace, silently, which is exactly the
# failure mode the whole ase_l case-mode batch was written about.
#
# Legs (DP*):
#   DP01-DP08  the pure helpers, with NOTHING loaded (join/expr/raw/table).
#   DP10-DP15  sod_expr + sod_qualify: the devparam kind takes no wrap and no
#              re-qualification.
#   DP20-DP25  derivation against the LOADED fixture, all four forms.
#   DP30-DP36  the dialog: build, tick, All/None, OK, Cancel.
#   DP40-DP46  queueing: outputs rows, dedupe/merge, the deck-vs-raw bridge, and
#              bus expansion keeping its hands off `[gm]`.
#   DP50-DP53  the OTHER entry point -- Add/Edit Output > "From Design…": the
#              flavor it derives from that dialog's checkboxes, and the
#              both-zero coercion. Integration is test_ase_interact I6c.
#
# No simulator is launched and none is needed.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_devparam.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
## call a possibly-missing proc without aborting the file
proc pcall {script} {
  if {[catch {uplevel #0 $script} r]} { return "ERR: $r" }
  return $r
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here   [file normalize [file dirname [info script]]]
set fixdir [file join $here fixtures ase_devparam]
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$fixdir:$XSCHEM_LIBRARY_PATH"

# --- DP01-DP08  the pure helpers, NOTHING loaded -------------------------------
# Purity first, the test_ase_interact H1 / 0161 HP1 convention: this group runs
# before any `xschem load`, so a helper that reached for the engine fails here.

check "DP01 devparam_join with no path is the bare device" \
  [pcall {ase::ui::devparam_join {} m1}] {@m1}
check "DP02 devparam_join hoists the device letter in front of the path" \
  [pcall {ase::ui::devparam_join {xm1.} msky130_fd_pr__nfet_01v8}] \
  {@m.xm1.msky130_fd_pr__nfet_01v8}
check "DP02b ... and a nested primitive takes the same hoist" \
  [pcall {ase::ui::devparam_join {x1.} m2}] {@m.x1.m2}
check "DP03 devparam_join of nothing is nothing (never a bare @)" \
  [pcall {ase::ui::devparam_join {x1.} {}}] {}

check "DP04 devparam_expr brackets the parameter" \
  [pcall {ase::ui::devparam_expr {@m1} gm}] {@m1[gm]}
check "DP04b devparam_expr on an empty base yields nothing to queue" \
  [pcall {ase::ui::devparam_expr {} gm}] {}

## DP05-DP07: the measured raw-name mapping, one assertion per branch so a
## regression names the type it broke.
check "DP05 (MEASURED) a current-typed parameter is WRAPPED i() in the raw" \
  [pcall {ase::ui::devparam_raw {@m.xm1.mfoo[id]}}] {i(@m.xm1.mfoo[id])}
check "DP06 (MEASURED) a voltage-typed parameter is wrapped v() — vth included" \
  [pcall {ase::ui::devparam_raw {@m1[vth]}}] {v(@m1[vth])}
check "DP06b ... and vdsat, which names no terminal pair, still folds to v()" \
  [pcall {ase::ui::devparam_raw {@m1[vdsat]}}] {v(@m1[vdsat])}
check "DP07 (MEASURED) a conductance comes back BARE" \
  [pcall {ase::ui::devparam_raw {@m1[gm]}}] {@m1[gm]}
check "DP07b ... a capacitance too" \
  [pcall {ase::ui::devparam_raw {@m1[cgs]}}] {@m1[cgs]}
check "DP07c ... and a charge" \
  [pcall {ase::ui::devparam_raw {@m1[qg]}}] {@m1[qg]}
check "DP07d a non-@ expression passes through devparam_raw untouched" \
  [pcall {ase::ui::devparam_raw {v(mid)}}] {v(mid)}

## The table gates the whole feature: sod_click asks "is this type covered?" by
## testing it non-empty, so a type falling out of it silently disables the pick.
check_true "DP08 nmos has a parameter table" \
  [expr {[llength [ase::ui::devparam_table nmos]] > 0}]
check_true "DP08b pmos has one too" \
  [expr {[llength [ase::ui::devparam_table pmos]] > 0}]
check "DP08c a subcircuit has NONE — a plain X instance is not a device pick" \
  [pcall {ase::ui::devparam_table subcircuit}] {}
check "DP08d nor does a vsource, which keeps its own i() arm" \
  [pcall {ase::ui::devparam_table vsource}] {}
## the gm/ID quantities the user actually came for
foreach p {gm id cgs vth gds vdsat} {
  check_true "DP08e devparam_all nmos offers $p" \
    [expr {[lsearch -exact [ase::ui::devparam_all nmos] $p] >= 0}]
}
## and the ones ngspice REFUSED on BSIM4 must NOT be offered (spec receipt §2)
foreach p {is ig ib gmb ron beta} {
  check "DP08f devparam_all nmos does NOT offer $p (BSIM4: no such parameter)" \
    [expr {[lsearch -exact [pcall {ase::ui::devparam_all nmos}] $p] >= 0}] 0
}

# --- DP10-DP15  sod_expr / sod_qualify take the devparam kind ------------------

check "DP10 sod_expr does NOT wrap a devparam expression" \
  [pcall {ase::ui::sod_expr devparam {@m1[gm]} fold}] {@m1[gm]}
check "DP11 ... and folds it under fold, like every other kind" \
  [pcall {ase::ui::sod_expr devparam {@M.XM1.MFoo[GM]} fold}] {@m.xm1.mfoo[gm]}
check "DP12 ... while preserve keeps the schematic's case" \
  [pcall {ase::ui::sod_expr devparam {@M.XM1.MFoo[GM]} preserve}] {@M.XM1.MFoo[GM]}
check "DP13 the voltage/current kinds are untouched by the new arm" \
  [pcall {ase::ui::sod_expr voltage MID fold}] {v(mid)}
check "DP13b ... current too" \
  [pcall {ase::ui::sod_expr current V1 fold}] {i(v1)}

## sod_qualify must be IDENTITY here: devparam_base already folded the hierarchy
## in structurally, and a second pass would prepend a second path.
check "DP14 sod_qualify is identity for devparam (no double-qualification)" \
  [pcall {ase::ui::sod_qualify devparam {@m.x1.m2[gm]} 0}] {@m.x1.m2[gm]}
check "DP15 ... even at a non-zero base level" \
  [pcall {ase::ui::sod_qualify devparam {@m.x1.m2[gm]} 2}] {@m.x1.m2[gm]}

# --- DP20-DP25  derivation against the loaded fixture --------------------------

xschem load [file join $fixdir dp_top.sch]
check_true "DP20 fixture: dp_top loaded" \
  [expr {[file tail [xschem get schname]] eq {dp_top.sch}}]
check "DP20b fixture: M1 is a primitive nmos symbol" \
  [pcall {xschem getprop instance M1 cell::type}] {nmos}
check "DP20c fixture: M2 is an nmos symbol too (the stand-in PDK device)" \
  [pcall {xschem getprop instance M2 cell::type}] {nmos}
check "DP20d fixture: M2 carries spiceprefix X, so it netlists as XM2" \
  [pcall {xschem translate M2 {@spiceprefix@name}}] {XM2}

check "DP21 devparam_subckt reads the callee off the symbol's own format" \
  [pcall {ase::ui::devparam_subckt M2}] {dpfoundry__dpfet_01v8}
check "DP21b a primitive has no @pinlist callee to read" \
  [pcall {ase::ui::devparam_subckt M1}] {nmos}

check "DP22 (FORM 1) a top-level primitive derives the bare device" \
  [pcall {ase::ui::devparam_base M1 0}] {@m1}
check "DP23 (FORM 2) a top-level PDK device reaches INSIDE its subckt" \
  [pcall {ase::ui::devparam_base M2 0}] {@m.xm2.mdpfoundry__dpfet_01v8}
check "DP23b ... and the full expression is what ngspice would be asked for" \
  [pcall {ase::ui::devparam_expr [ase::ui::devparam_base M2 0] gm}] \
  {@m.xm2.mdpfoundry__dpfet_01v8[gm]}

## descend one level: the names must be measured from the SESSION's design level
## (issue 0168's rule), which is what makes a descended pick match the deck.
xschem unselect_all; xschem select instance x1; xschem descend
check_true "DP24 fixture: descended one level" [expr {[xschem get currsch] == 1}]
check "DP24b (FORM 3) a nested primitive picks up the instance path" \
  [pcall {ase::ui::devparam_base M3 0}] {@m.x1.m3}
check "DP25 (FORM 4) a nested PDK device stacks path AND subckt" \
  [pcall {ase::ui::devparam_base M4 0}] {@m.x1.xm4.mdpfoundry__dpfet_01v8}
## at/above its own level a pick adds no path — the baselvl guard
check "DP25b a pick measured from ITS OWN level adds no path" \
  [pcall {ase::ui::devparam_base M3 1}] {@m3}
xschem go_back
check_true "DP25c fixture: back at the top" [expr {[xschem get currsch] == 0}]

# --- DP30-DP36  the dialog -----------------------------------------------------
# Driven WITHOUT the modal tkwait, the bus_dialog / ask_save_close convention:
# build at a deterministic path, poke the widgets, call _done directly.

set dlg [pcall {ase::ui::devparam_dialog_build {} M1 {@m1} nmos}]
check_true "DP30 the dialog builds" [expr {[winfo exists $dlg]}]
check "DP30b it opens with the DERIVED name in the editable field" \
  [pcall {$dlg.bf.e get}] {@m1}
check "DP31 nothing is ticked when it opens" \
  [pcall {ase::ui::devparam_dialog_selected nmos}] {}

ase::ui::devparam_dialog_set $dlg nmos 1
check "DP32 All ticks every parameter" \
  [pcall {llength [ase::ui::devparam_dialog_selected nmos]}] \
  [pcall {llength [ase::ui::devparam_all nmos]}]
ase::ui::devparam_dialog_set $dlg nmos 0
check "DP32b None clears them again" \
  [pcall {ase::ui::devparam_dialog_selected nmos}] {}

## the gm/ID pick, spread across three different groups — the case the grouped
## checkbutton layout exists for
set ::ase::ui::devparam_chk(gm)  1
set ::ase::ui::devparam_chk(id)  1
set ::ase::ui::devparam_chk(cgs) 1
check "DP33 selection comes back in TABLE order, never hash order" \
  [pcall {ase::ui::devparam_dialog_selected nmos}] {id gm cgs}
ase::ui::devparam_dialog_done $dlg nmos 1
## expected as a `list`, not a bare string: every element contains brackets, and
## Tcl brace-quotes those when a list is flattened to a string. Writing the
## expectation as a list keeps the assertion about the LIST, not its spelling.
check "DP34 OK returns the full expressions, in that order" \
  [pcall {set ::ase::ui::devparam_dialog_result}] \
  [list {@m1[id]} {@m1[gm]} {@m1[cgs]}]
check_true "DP34b ... and the dialog is gone" [expr {![winfo exists $dlg]}]

## Cancel is a no-op even with things ticked — the bus_dialog contract
set dlg [pcall {ase::ui::devparam_dialog_build {} M1 {@m1} nmos}]
set ::ase::ui::devparam_chk(gm) 1
ase::ui::devparam_dialog_done $dlg nmos 0
check "DP35 Cancel queues nothing, however much was ticked" \
  [pcall {set ::ase::ui::devparam_dialog_result}] {}

## the EDITABLE field is the escape hatch for a PDK whose inner device is not
## spelled `m`+subckt: whatever the user types is what gets queued
set dlg [pcall {ase::ui::devparam_dialog_build {} M2 {@m.xm2.mdpfoundry__dpfet_01v8} nmos}]
$dlg.bf.e delete 0 end
$dlg.bf.e insert 0 {@m.xm2.mcustom}
ase::ui::devparam_dialog_set $dlg nmos 0
set ::ase::ui::devparam_chk(gm) 1
ase::ui::devparam_dialog_done $dlg nmos 1
check "DP36 an EDITED device field is what the expression is built from" \
  [pcall {set ::ase::ui::devparam_dialog_result}] [list {@m.xm2.mcustom[gm]}]

# --- DP40-DP45  queueing and the deck/raw bridge -------------------------------

## sod_merge is the queue step every pick shares; a devparam row is an ordinary
## output row, which is what makes it show up in the Outputs pane and the deck.
set rows {}
lassign [pcall {ase::ui::sod_merge {} {@m1[gm]} {save 1 plot 0}}] rows st
check "DP40 a devparam pick appends an ordinary output row" $st {added}
check "DP40b ... carrying the bare DECK spelling as its expr" \
  [pcall {dict get [lindex $rows 0] expr}] {@m1[gm]}
check "DP40c ... with the To-Be-Saved flavor's flags" \
  [list [pcall {dict get [lindex $rows 0] save}] [pcall {dict get [lindex $rows 0] plot}]] \
  {1 0}
## To Be Plotted on the same expression ORs the plot flag in rather than
## duplicating the row
lassign [pcall {ase::ui::sod_merge $rows {@m1[gm]} {save 1 plot 1}}] rows2 st2
check "DP41 re-picking it To Be Plotted merges, not duplicates" $st2 {merged}
check "DP41b ... one row still" [pcall {llength $rows2}] 1
check "DP41c ... now flagged for both" \
  [list [pcall {dict get [lindex $rows2 0] save}] [pcall {dict get [lindex $rows2 0] plot}]] \
  {1 1}
lassign [pcall {ase::ui::sod_merge $rows2 {@m1[gm]} {save 1 plot 1}}] rows3 st3
check "DP42 an identical re-queue writes nothing" $st3 {nochange}

## THE BRIDGE.  The row holds the deck spelling; the viewer must be handed the
## raw one.  These two assertions are the pair that must never collapse.
check "DP43 the DECK gets the bare spelling (the only one .save accepts)" \
  [pcall {dict get [lindex $rows3 0] expr}] {@m1[gm]}
check "DP44 the VIEWER gets the raw spelling — bare for a conductance" \
  [pcall {ase::ui::plot_map_expr {@m1[gm]}}] {@m1[gm]}
check "DP44b ... and WRAPPED for a current, which is where they diverge" \
  [pcall {ase::ui::plot_map_expr {@m.xm1.mfoo[id]}}] {i(@m.xm1.mfoo[id])}
check "DP44c ... and for a voltage" \
  [pcall {ase::ui::plot_map_expr {@m1[vth]}}] {v(@m1[vth])}
check "DP45 plot_map_expr's existing arms are untouched: the -i(v1) shape" \
  [pcall {ase::ui::plot_map_expr {-i(v1)}}] {i(v1) -1 *}
check "DP45b ... and a plain vector still passes through" \
  [pcall {ase::ui::plot_map_expr {v(mid)}}] {v(mid)}

## bus expansion must not mistake `[gm]` for a bus subscript and shred the row
check "DP46 bus expansion leaves a devparam row alone" \
  [pcall {llength [ase::expand_bus_outputs [list [dict create name {} expr {@m1[gm]} save 1 plot 0]]]}] 1
check "DP46b ... expr intact" \
  [pcall {dict get [lindex [ase::expand_bus_outputs [list [dict create name {} expr {@m1[gm]} save 1 plot 0]]] 0] expr}] \
  {@m1[gm]}

# --- DP50-DP53  the OTHER entry point: Add/Edit Output > "From Design…" -------
# `output_editor_from_design` is the second door onto the same pick mode (the
# first being the Outputs menu). It computes the flavor from the Add/Edit Output
# dialog's Save/Plot checkboxes, closes that dialog, and arms select_on_design
# in the DEFAULT `outputs` mode -- so a transistor body click through this door
# must reach the device probe exactly as it does through the menu.
#
# select_on_design is STUBBED here to capture what it is handed: these legs own
# the flavor arithmetic (including the both-zero coercion), and the integration
# -- a real From Design click landing a real device row -- is test_ase_interact
# I6c, which has a real session and a real sky130 nfet.
set ::sod_armed {}
proc ase::ui::select_on_design {key flavor {mode outputs} {do_raise 1}} {
  set ::sod_armed [list $key $flavor $mode]
  return 1
}

set ::ase::ui::edchk(k,save) 1
set ::ase::ui::edchk(k,plot) 0
ase::ui::output_editor_from_design k
check "DP50 From Design arms the pick mode with the dialog's Save flavor" \
  [lindex $::sod_armed 1] {save 1 plot 0}
check "DP50b ... in `outputs` mode, so sod_click writes session outputs" \
  [lindex $::sod_armed 2] {outputs}

set ::ase::ui::edchk(k,save) 1
set ::ase::ui::edchk(k,plot) 1
ase::ui::output_editor_from_design k
check "DP51 save+plot both ticked come through as both" \
  [lindex $::sod_armed 1] {save 1 plot 1}

## the coercion: BOTH unticked would make a row render_deck emits nothing for
set ::ase::ui::edchk(k,save) 0
set ::ase::ui::edchk(k,plot) 0
ase::ui::output_editor_from_design k
check "DP52 both unticked coerces save to 1 (a row with neither is dead)" \
  [lindex $::sod_armed 1] {save 1 plot 0}

## a plot-only row is NOT coerced -- only the both-zero case is
set ::ase::ui::edchk(k,save) 0
set ::ase::ui::edchk(k,plot) 1
ase::ui::output_editor_from_design k
check "DP53 plot-only is left alone (only both-zero is coerced)" \
  [lindex $::sod_armed 1] {save 0 plot 1}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]

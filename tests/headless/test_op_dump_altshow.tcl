# tests/headless/test_op_dump_altshow.tcl — the blanket operating-point dump.
#
# ============================================================================
# WHAT IS UNDER TEST
# ============================================================================
# Two halves of one road, and they must agree on a spelling neither of them
# owns alone:
#
#   ASKING   ase.tcl's render_deck shape `d`, which puts two lines inside
#            `.control` and NAMES NO DEVICE ANYWHERE:
#                op
#                set altshow
#                show all > <rawroot>.opinfo
#   READING  op_annot::opdump_read, which parses that file and MERGES it into
#            the already-loaded results database with `xschem raw add`, then
#            republishes with `xschem update_op`.
#
# ⚠ THE ORDER IS THE POINT, AND IT IS THE ONE THING A REFACTOR WILL BREAK.
# `show` reports whatever CKT state is CURRENT — it is not a stored plot. The
# dump must therefore follow `op` and precede every other analysis. The other
# shapes' `save` requests must PRECEDE their analysis, so the two travel in
# different carriers (optier_ctl vs optier_post) and land in different places.
# Row D3 is what stops someone merging them back into one and silently dumping
# an unsolved circuit at exit 0.
#
# ⚠ THE PATH IS LOWERCASED ON PURPOSE. ngspice case-folds a `show >` redirect
# target, directory component included, and exits 0 when the folded directory
# does not exist. Asking side and reading side therefore derive the path from
# ONE proc, op_annot::opdump_path. Row P2 pins that; delete the fold and a
# mixed-case simulation directory produces a green run and no data.
# ============================================================================

set fail 0
set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch op_dump_altshow]
set T_OLDPWD [pwd]

# ============================================================================
# P — THE PATH, DERIVED ONCE
# ============================================================================
check {P1 opdump_path replaces the raw's extension with .opinfo} \
  [::op_annot::opdump_path /a/b/CellName_ase.raw] {/a/b/cellname_ase.opinfo}

check {P2 opdump_path LOWERCASES the whole path, directory included, because ngspice case-folds the redirect target and then exits 0 having written nothing} \
  [::op_annot::opdump_path /Sim/RunDir/Cell.raw] {/sim/rundir/cell.opinfo}

check {P3 the request is exactly two lines, names no device, and asks the wide question so resistors and capacitors are not silently dropped} \
  [::op_annot::opdump_request /x/y/z.raw] \
  {{set altshow} {show all > /x/y/z.opinfo}}

# ============================================================================
# D — THE DECK SHAPE
# ============================================================================
set NL "** sch_path: /zz.sch\n**.subckt zzcell\nV1 a 0 1\n**.ends\n.end\n"
set BLK ".save all\n.save @m.xz1.mzmod\[id\]\n.save @m.xz1.mzmod\[gm\]\n"

proc d_state {} {
  global scratch
  set st [ase::state_default]
  dict set st design [dict create lib zzlib cell zzcell view schematic]
  dict set st rundir [file join $scratch orun]
  dict set st analyses {{type op enabled 1} {type dc enabled 0}
                        {type ac enabled 0} {type tran enabled 1 step 1n stop 5n}}
  dict set st save_op_params 1
  return $st
}
proc d_control {deck} {
  set out {} ; set inb 0
  foreach l [split $deck "\n"] {
    set t [string trim $l]
    if {$t eq {.control}} { set inb 1 ; continue }
    if {$t eq {.endc}} { break }
    if {$inb && $t ne {}} { lappend out $t }
  }
  return $out
}
ase::op_cards_put $NL $BLK
set RENDER [ase::backend_hook ngspice render_deck]
ase::op_tier_force_set d
set DECK [$RENDER [d_state] $NL]
set CTL  [d_control $DECK]

check {D1 shape d puts NO per-device .save card in the deck at all} \
  [regexp -all -line {^\.save @} $DECK] 0

check {D2 shape d emits the deck-level `.save all` that carries the node half for free} \
  [regexp -all -line {^\.save all$} $DECK] 1

set i_op   [lsearch -exact $CTL {op}]
set i_alt  [lsearch -exact $CTL {set altshow}]
set i_show [lsearch -glob  $CTL {show all > *}]
check_true {D3 the dump follows `op` IMMEDIATELY -- show reads live CKT state, so anything between the solve and the dump silently reports the wrong analysis} \
  [expr {$i_op >= 0 && $i_alt == $i_op + 1 && $i_show == $i_op + 2}]

check_true {D4 the requested path is the one opdump_read will look in} \
  [string match "show all > [::op_annot::opdump_path [file join $scratch orun zzcell_ase.raw]]" \
                [lindex $CTL $i_show]]

check_true {D5 no `save` REQUEST line rides along -- shape d asks for nothing per device} \
  [expr {[lsearch -glob $CTL {save all @*}] < 0}]

# The contrast row: the same state on the shipped per-device shape.
ase::op_tier_force_set c
set CTLC [d_control [$RENDER [d_state] $NL]]
check_true {D6 CONTRAST shape c names devices in a `save` request BEFORE op, which is why the two shapes cannot share one carrier} \
  [expr {[lsearch -glob $CTLC {save all @m.xz1.mzmod*}] >= 0 &&
         [lsearch -glob $CTLC {save all @m.xz1.mzmod*}] < [lsearch -exact $CTLC {op}]}]
ase::op_tier_force_set {}

# ============================================================================
# R — THE READER, AND THE THREE SILENT FAILURES IT REFUSES TO PASS ON
# ============================================================================
set DUMP [file join $scratch d.opinfo]
set fh [open $DUMP w]
puts $fh "m.x1.xm1.mnfet:"
puts $fh "    model              = x1.xm1:nshort_model.42"
puts $fh "    id                 = 5.33333e-05"
puts $fh "    gm                 = 0.000266667"
puts $fh "    vdsat              = -"
puts $fh "q.x1.xq1.qpnp:"
puts $fh "    vbe                = 0.773303"
puts $fh "v5:"
puts $fh "    pulse              = 1.81071"
puts $fh "    pulse              = 0"
puts $fh "    pulse              = 2.5e-05"
close $fh

check_true {R1 G1 a MISSING dump raises rather than returning empty -- ngspice exits 0 when `show >` cannot write, so a green run proves nothing} \
  [catch {::op_annot::opdump_read [file join $scratch nosuch.opinfo]}]

set EMPTY [file join $scratch e.opinfo]
close [open $EMPTY w]
check_true {R2 an EMPTY dump raises} [catch {::op_annot::opdump_read $EMPTY}]

set LEG [file join $scratch legacy.opinfo]
set fh [open $LEG w]
puts $fh "     device m.x1.x23.xm2.msky130_ m.x1.x23.xm1.msky130_"
puts $fh "         id       2.1e-12       3.4e-12"
close $fh
set legrc [catch {::op_annot::opdump_read $LEG} legmsg]
check_true {R3 G3 the LEGACY (non-altshow) layout is detected and refused -- its names are truncated to 21 chars and unusable} $legrc
check_true {R4 and the refusal names the remedy, including that `set altshow=1` does NOT work because the variable is read as CP_BOOL} \
  [expr {[string match {*set altshow*} $legmsg] && [string match {*altshow=1*} $legmsg]}]

# The happy path needs a database to merge into. A one-point op raw is enough.
set RAW [file join $scratch n.raw]
set fh [open $RAW w]
puts $fh "Title: t"
puts $fh "Plotname: Operating Point"
puts $fh "Flags: real"
puts $fh "No. Variables: 2"
puts $fh "No. Points: 1"
puts $fh "Variables:"
puts $fh "\t0\tv(vbg)\tvoltage"
puts $fh "\t1\tv(vcc)\tvoltage"
puts $fh "Values:"
puts $fh "0\t1.2"
puts $fh "\t1.8"
close $fh
set readrc [catch {xschem raw read $RAW} rr]
check_true {R5 the node-only raw loads as an operating point} \
  [expr {$readrc == 0 && [xschem raw sim_type] eq {op}}]
set nbefore [xschem raw vars]
set D [::op_annot::opdump_read $DUMP]

check {R6 every device block is counted} [dict get $D devices] 3
check {R7 only NUMERIC bodies are injected -- the model string and the `-` placeholder are declined, not stored} \
  [dict get $D params] 4
check {R8 and the declined lines are COUNTED rather than silently dropped, which is what a throwaway parser does} \
  [dict get $D skipped] 2
check {R9 a vector parameter repeats ONE key per coefficient; FIRST wins and the rest are counted, so a coefficient is never stored as if it were the parameter} \
  [dict get $D dups] 2

check_true {R10 the merge ADDS to the loaded database rather than replacing it -- the node half must survive} \
  [expr {[xschem raw vars] == $nbefore + 4}]

check {R11 a device parameter now resolves through the UNCHANGED op_annot accessor, via _wrap_alts' bare spelling (issue 0963)} \
  [::op_annot::raw_or_blank {@m.x1.xm1.mnfet[id]}] {5.33333e-05}
check {R12 a BIPOLAR resolves too -- a class the per-device shape never emitted a single card for} \
  [::op_annot::raw_or_blank {@q.x1.xq1.qpnp[vbe]}] {0.773303}
check {R13 and the node voltages that were already there are untouched} \
  [::op_annot::raw_or_blank {v(vbg)}] {1.2}
check {R14 a declined parameter is BLANK, never a fabricated zero} \
  [::op_annot::raw_or_blank {@m.x1.xm1.mnfet[vdsat]}] {}

catch {xschem raw clear}

cd $T_OLDPWD
check_true {H1 HYGIENE the suite left the cwd where it found it and made no untitled* in the repo root} \
  [expr {[pwd] eq $T_OLDPWD &&
         [llength [glob -nocomplain -directory $repo -tails untitled*]] == 0}]

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }

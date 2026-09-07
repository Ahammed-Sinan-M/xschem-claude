# test_sim_plain_run.tcl — THE PLAIN Simulate PATH COMPOSED FROM THE REGISTRY.
# Issue 0506, then the `annotate` merge, then issue 1238. Spec:
# doc/claude/specs/simulator_profiles.md section 18.
#
# WHAT THIS IS. Issue 0506 taught `proc simulate` — stock xschem's own Simulation
# menu, the button most users press — to compose its command from the simulator
# the user configured, so that the executable and the case mode the Test button
# had MEASURED reached the run instead of stopping at the dialog. Without it a
# user could register a case-capable ngspice, set Case=preserve, press Test, read
# "delivers fold preserve distinguish", press Simulate, and get a different
# binary at `fold`.
#
# ⚠ THE COMPOSER'S STORE MOVED AT THE `annotate` MERGE AND THE COMPOSER WENT WITH
# IT. `fluid-editing` hung the exe and the case mode off a `sim()` PROFILE ROW;
# `annotate` retired that store for the ASE-L simulator REGISTRY, and eighteen of
# this file's checks (CS200–CS217 and CS221's simulate half) went with the procs
# they drove. Issue **1238** brings the composer back reading the registry — the
# user's ruling, option 1 of three — and these checks come back with it, driving
# the new procs rather than the retired ones.
#
# WHAT CHANGED IN THE CHECKS THEMSELVES, and it is one thing: the old store was
# PER-ROW, so setting an `exe` on the shipped `mpirun … Xyce` row meant "this
# row's simulator is this program" and DECLINING it was the right answer to
# report. The registry is ONE IN-FORCE ENTRY for the `ngspice` backend; it says
# nothing whatever about a Xyce row, so a Xyce row now composes as `none` —
# untouched and unremarked — and CS203's substance (a literal first word that is
# a WRAPPER, not the simulator) is driven by a non-Xyce `mpirun` template
# instead. CS203b pins the new Xyce answer so the change cannot rot back.
#
# THE LOAD-BEARING CHECKS, and why:
#   CS200   THE COMPATIBILITY CONTRACT, and it carries a configured half in the
#           SAME assertion so it cannot pass by the feature being absent. Stock
#           xschem — `ase.tcl` sourced, NOTHING registered, no session anywhere —
#           must compose BYTE-IDENTICALLY. That is most of issue 1238's contract.
#   CS202/  THE TWO TEMPLATE SHAPES THAT MUST BE DECLINED, named individually
#   CS203   because each defeats a different one of the three conditions: row 0's
#           first word is a VARIABLE, a wrapper's is a literal that is NOT the
#           simulator. These are the rows simulator_profiles.md section 10's ban
#           was written about.
#   CS210/  UNPLACEABLE. This was a real defect in 0506's first revision: row 0
#   CS211   had its exe correctly declined and the flags appended anyway,
#           producing `xterm -e {ngspice ...} -D casemode=preserve` — flags for
#           the TERMINAL, two levels out from the simulator. The measurement that
#           licenses appending is about a DIRECT invocation and says nothing
#           about a wrapped one.
#   CS215   ...and an unplaceable mode is REPORTED at tag `error`. A silent drop
#           would be this issue's own defect one layer along.
#   CS222   the same rule for the registry's own extra ARGS, which this path does
#           not place and therefore must not swallow.
#   CS228/  THE PLACEMENT TEST READS THE STRING THAT RUNS. The repair round took
#   CS228b  it on the RAW template, so a `|` arriving through `proc simulate`'s
#           own `subst` -- `$env(NGPOST)`, `$terminal`, a `$::name` from a simrc
#           -- was invisible to it and visible to `open "|$args"`. Measured
#           reproducing the whole defect, note and all, on the shipped procs.
#   CS229/  AND IT HAS A QUOTING MODEL, because Tcl has one. A `|` inside quotes
#   CS229b/ or braces is not a stage separator, so answering `pipeline` there lost
#   CS229c  the case mode on a well-formed row (`-c "run | wrdata out"`).
#   CS225b  THE ORDER of the two unplaceable reasons, driven by a row that moves
#           when the order moves. CS225 -- the row the order used to be claimed
#           on -- does not move, measured.
#   CS218/  THE Tcl BRIDGE C CALLS. `sim_netlist_casemode` is what
#   CS219   netlist_case_mode() (src/save.c) asks, and it must fall back to the
#           global floor when nothing answers.
#   CS220   THE C WIRE, observed through behaviour rather than asserted: the
#           netlist-time collision warning is silent under `distinguish` (C2), so
#           moving the registered simulator's mode must silence it. Nothing else
#           in this file can tell whether netlist_case_mode() really moved.
#   CS221   THE WHOLE POINT, end to end: a schematic net `EN`, netlisted,
#           SIMULATED through `proc simulate`, and read back as `v(EN)`. Skipped
#           (not failed) when no case-capable ngspice is present.
#
# Run TRUE HEADLESS from the repo root (needs no display):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_sim_plain_run.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
set nskip 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } \
  else { puts "FAIL: $name $detail"; incr fail }
}
proc eqcheck {name got want} {
  check $name [expr {$got eq $want}] "(got '$got' want '$want')"
}
proc skip {name why} { global nskip; puts "skip: $name ($why)"; incr nskip }
# every call goes through this: a proc that does not exist yet must FAIL a
# check, never abort the file with no RESULT line
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}
proc dg {d k} {
  if {[catch {dict get $d $k} v]} { return "NO:$k" }
  return $v
}
proc wfile {path content} {
  set f [open $path w] ; puts $f $content ; close $f
}

set scratch [test_scratch sim_plain_run]
set ::netlist_dir $scratch

# A case-capable ngspice, if this machine has one. Everything that needs a real
# process is guarded on it; everything else is a pure function and always runs.
set NGCASE {}
foreach c [list /home/analog/dev/ngspice/build-ver_50/src/ngspice \
                /home/qflow/dev/ngspice_test/build-ver_50/src/ngspice] {
  if {[file executable $c]} { set NGCASE $c ; break }
}
# A binary that certainly exists, for the exe-plan checks, which never run it.
set NGANY [lindex [auto_execok ngspice] 0]
if {$NGANY eq {}} { set NGANY $NGCASE }

if {[catch {

set_sim_defaults
set ROW0 $sim(spice,0,cmd)
set ROW1 $sim(spice,1,cmd)
set ROW2 $sim(spice,2,cmd)
set ROW3 $sim(spice,3,cmd)
set ROW4 $sim(spice,4,cmd)

proc compose {tool raw} { return [pcall sim_compose_cmd $tool $raw $raw] }

# ⚠ `ase::sim_clear` IS NOT HOUSEKEEPING HERE, IT IS THE FIRST LINE OF EVERY
# CASE. xschem.tcl calls `ase::sim_load_conf` at startup, so a developer's own
# ~/.xschem/ase_simulators is in force by the time this file runs (issue 1377).
# Every check below states its own registry, from empty.
proc reset_rows {} {
  global sim
  catch {unset sim}
  set_sim_defaults
  catch {ase::sim_clear}
  set ::sim_case_mode fold
}
proc reg {name path args} {
  return [pcall eval [list ase::sim_register $name $path] $args]
}

# --- CS200 the compatibility contract, both halves in one assertion ------------
# The unconfigured half is issue 1238's hard constraint 1: stock xschem, ase.tcl
# sourced, nothing registered, no session anywhere.
reset_rows
set unconf [dg [compose spice $ROW2] cmd]
reg ngc $NGANY -casemode preserve
set conf [dg [compose spice $ROW2] cmd]
eqcheck CS200-unconfigured-is-byte-identical-and-configured-is-not \
  "unconf=<[expr {$unconf eq $ROW2}]> conf_differs=<[expr {$conf ne $ROW2}]>" \
  {unconf=<1> conf_differs=<1>}

# --- the exe plan -------------------------------------------------------------
reset_rows
reg ngc $NGANY
eqcheck CS201-exe-applied-when-first-word-tail-matches \
  [dg [compose spice $ROW2] exe_status] applied
# the FULL registered path, at word 0 -- not merely "the tail appears somewhere",
# which the untouched template already satisfies
eqcheck CS201b-the-applied-path-is-the-registered-one \
  [lindex [dg [compose spice $ROW2] cmd] 0] $NGANY

# CS201c: a path with a space must survive `eval execute $st $cmd`, which
# re-parses the composed string as a Tcl command line. `[list $exe]` braces it;
# a bare interpolation would split the simulator into two words and run neither.
set spacedir [file join $scratch {exe dir}]
file mkdir $spacedir
set spaced [file join $spacedir ngspice]
catch {file delete $spaced}
if {[catch {file link -symbolic $spaced $NGANY}]} { catch {file copy -force $NGANY $spaced} }
if {[file executable $spaced]} {
  reset_rows
  reg ngc $spaced
  eqcheck CS201c-a-path-with-a-space-stays-one-word \
    "w0=<[lindex [dg [compose spice $ROW2] cmd] 0]> n=<[llength [dg [compose spice $ROW2] cmd]]>" \
    "w0=<$spaced> n=<[llength $ROW2]>"
} else {
  skip CS201c-a-path-with-a-space-stays-one-word {could not create a spaced-path executable}
}

reset_rows
reg ngc $NGANY
eqcheck CS202-row0-variable-first-word-is-declined \
  "st=<[dg [compose spice $ROW0] exe_status]> cmd_unchanged=<[expr {[dg [compose spice $ROW0] cmd] eq $ROW0}]>" \
  {st=<declined> cmd_unchanged=<1>}

# CS202b: THE RAW/SUBSTITUTED SPLIT, and the only row that pins the plan's refusal
# of a first word carrying `$`. CS202 above passes on the tail test alone
# (`file tail {$terminal}` is `$terminal`, which matches nothing), so it cannot
# see that rule at all. Here `file tail {$SIMDIR/ngspice}` IS `ngspice`: the tail
# test says yes, and the ONLY thing standing between the composer and a corrupted
# command line is the literal test. The corruption is not hypothetical -- the
# decision is taken on the RAW template and the edit is applied to the
# SUBSTITUTED one, so a variable holding a path with a space in it turns one word
# into two and the composer would replace the wrong half of it.
reset_rows
reg ngc $NGANY
set VARW {$SIMDIR/ngspice -b "$N"}
set SUBW {/opt/a b/ngspice -b "$N"}
set d [pcall sim_compose_cmd spice $VARW $SUBW]
eqcheck CS202b-a-variable-first-word-whose-tail-matches-is-still-declined \
  "st=<[dg $d exe_status]> cmd_unchanged=<[expr {[dg $d cmd] eq $SUBW}]>" \
  {st=<declined> cmd_unchanged=<1>}

# CS203: the wrapper shape, which is what the shipped `mpirun` row used to prove
# before the store became a per-backend registry. A literal first word that is
# not the simulator declines, and so does every `nice`/`time`/`flatpak-spawn`.
reset_rows
reg ngc $NGANY
set MPI {mpirun /opt/parallel/ngspice "$N"}
eqcheck CS203-a-wrapper-literal-first-word-is-declined \
  "st=<[dg [compose spice $MPI] exe_status]> cmd_unchanged=<[expr {[dg [compose spice $MPI] cmd] eq $MPI}]>" \
  {st=<declined> cmd_unchanged=<1>}

# CS203b: an `ngspice` registry entry has NOTHING TO SAY about a Xyce row, so
# the shipped Xyce rows are `none` -- untouched AND unremarked. Reporting a
# declined exe there would be a sentence about a program the user never pointed
# at that row, on every press of Simulate.
reset_rows
reg ngc $NGANY -casemode preserve
eqcheck CS203b-a-Xyce-row-is-not-the-ngspice-registrys-business \
  "r3=<[dg [compose spice $ROW3] exe_status]> r4=<[dg [compose spice $ROW4] exe_status]>\
 r4_unchanged=<[expr {[dg [compose spice $ROW4] cmd] eq $ROW4}]>" \
  {r3=<none> r4=<none> r4_unchanged=<1>}

reset_rows
eqcheck CS204-nothing-registered-is-none-not-declined \
  [dg [compose spice $ROW2] exe_status] none

# CS204b: an entry whose program has gone since it was registered resolves to
# `ok 0`. It carries an `entry` name, but no program -- so it yields no exe and
# the command line does not move.
reset_rows
set gone [file join $scratch ngspice]
catch {file delete $gone}
if {[catch {file link -symbolic $gone $NGANY}]} { catch {file copy -force $NGANY $gone} }
if {[file executable $gone]} {
  reg ngc $gone
  file delete -force $gone
  eqcheck CS204b-an-entry-whose-program-is-gone-yields-no-exe \
    "st=<[dg [compose spice $ROW2] exe_status]> cmd_unchanged=<[expr {[dg [compose spice $ROW2] cmd] eq $ROW2}]>" \
    {st=<none> cmd_unchanged=<1>}
} else {
  skip CS204b-an-entry-whose-program-is-gone-yields-no-exe {could not create a throw-away executable}
}

# --- the flags ----------------------------------------------------------------
reset_rows
reg ngc $NGANY -casemode preserve
eqcheck CS205-non-fold-request-emits-mode-and-casemodewrite \
  [dg [compose spice $ROW2] flags] {-D casemode=preserve -D casemodewrite}

reset_rows
reg ngc $NGANY -casemode fold
eqcheck CS206-a-fold-request-emits-nothing \
  "flags=<[dg [compose spice $ROW2] flags]> st=<[dg [compose spice $ROW2] flag_status]>" \
  {flags=<> st=<none>}

# CS213: `casemodewrite` never travels alone and never for `fold`. It is what
# makes the raw self-describing (ngspice stamps `Option: casemode=` only when it
# is set), i.e. what lets item 3's header source — mode source 2 — ever fire on a
# file we caused to be written.
reset_rows
reg ngc $NGANY -casemode distinguish
set fl [dg [compose spice $ROW2] flags]
check CS213-casemodewrite-rides-with-the-mode-never-alone \
  [expr {[lsearch -exact $fl casemodewrite] > 0 && [lsearch -glob $fl casemode=*] > 0}] \
  "(flags '$fl')"

reset_rows
reg ngc $NGANY -casemode preserve
eqcheck CS207-a-Xyce-row-never-gets-an-ngspice-flag \
  "r3=<[dg [compose spice $ROW3] flags]> r4=<[dg [compose spice $ROW4] flags]>" \
  {r3=<> r4=<>}

reset_rows
reg ngc $NGANY -casemode preserve
if {[info exists sim(verilog,0,cmd)]} {
  eqcheck CS208-a-non-spice-tool-never-gets-the-flag \
    [dg [compose verilog $sim(verilog,0,cmd)] flags] {}
  eqcheck CS208b-a-non-spice-tool-keeps-its-row-verbatim \
    "st=<[dg [compose verilog $sim(verilog,0,cmd)] exe_status]>\
 unchanged=<[expr {[dg [compose verilog $sim(verilog,0,cmd)] cmd] eq $sim(verilog,0,cmd)}]>" \
    {st=<none> unchanged=<1>}
} else {
  skip CS208-a-non-spice-tool-never-gets-the-flag {no verilog tool configured}
  skip CS208b-a-non-spice-tool-keeps-its-row-verbatim {no verilog tool configured}
}

reset_rows
reg ngc $NGANY -casemode preserve
set d [compose spice {ngspice -b -D casemode=distinguish -r "$n.raw" "$N"}]
eqcheck CS209-a-hand-written-casemode-in-the-template-wins \
  "st=<[dg $d flag_status]> flags=<[dg $d flags]> once=<[regexp -all {casemode=} [dg $d cmd]]>" \
  {st=<template> flags=<> once=<1>}

# --- placement: the defect 0506's first revision shipped ----------------------
reset_rows
reg ngc $NGANY -casemode preserve
set d [compose spice $ROW0]
eqcheck CS210-a-wrapped-template-is-unplaceable-and-is-not-appended-to \
  "st=<[dg $d flag_status]> cmd_unchanged=<[expr {[dg $d cmd] eq $ROW0}]>" \
  {st=<unplaceable> cmd_unchanged=<1>}

reset_rows
set ::sim_case_mode preserve
set sh {sh -c "ngspice -b '$N'"}
set d [compose spice $sh]
eqcheck CS211-a-shell-wrapper-naming-ngspice-is-still-unplaceable \
  "st=<[dg $d flag_status]> cmd_unchanged=<[expr {[dg $d cmd] eq $sh}]>" \
  {st=<unplaceable> cmd_unchanged=<1>}

# CS212: the convenience route -- nothing registered, but the user moved the
# GLOBAL floor, which the C netlister already honours (sim_netlist_casemode). The
# deck is written in that mode, so the run must ask for it too.
reset_rows
set ::sim_case_mode preserve
set d [compose spice $ROW1]
eqcheck CS212-a-bare-ngspice-first-word-takes-the-flags-with-no-exe-registered \
  "st=<[dg $d flag_status]> exe=<[dg $d exe_status]>" \
  {st=<appended> exe=<none>}

# --- the report ---------------------------------------------------------------
proc tags {d} {
  set t {}
  foreach l [pcall sim_compose_report $d] { lappend t [lindex $l 0] }
  return $t
}
reset_rows
eqcheck CS217-a-configuration-nobody-touched-says-nothing \
  [tags [compose spice $ROW2]] {}

reset_rows
reg ngc $NGANY -casemode preserve
eqcheck CS216-a-successful-append-is-a-note \
  [tags [compose spice $ROW2]] note

reset_rows
reg ngc $NGANY
eqcheck CS214-a-declined-exe-is-an-error-not-a-note \
  [tags [compose spice $MPI]] error

reset_rows
set ::sim_case_mode preserve
eqcheck CS215-an-unplaceable-mode-is-an-error-not-a-note \
  [tags [compose spice $ROW0]] error

# CS222: this path composes the registry's EXE and CASE MODE and nothing else,
# so a registered `-args` list does not reach the command line. That is a thing
# the user configured and is not getting, which is exactly what CS215's rule says
# must be said out loud rather than swallowed.
reset_rows
reg ngc $NGANY -args {-r other.raw}
set d [compose spice $ROW2]
eqcheck CS222-registered-args-this-path-cannot-place-are-reported \
  "st=<[dg $d args_status]> args=<[dg $d args]> tags=<[tags $d]>" \
  "st=<dropped> args=<-r other.raw> tags=<error>"

# --- CS223 THE PIPELINE HOLE (issue 1238, repair round) -----------------------
# `sim_cmd_takes_flags` answered "yes" for any template whose FIRST word is the
# simulator. `proc execute` does `open "|$args"`, and Tcl's pipeline parser gives
# TRAILING words to the LAST STAGE -- so on a piped row the flags went to `tee`,
# and the report said "Case mode: appending -D casemode=preserve" about a pipe.
#
# MEASURED 2026-09-07, Tcl 8.6, through `open "|..."` exactly as `proc execute`
# does it, with two argv-echoing shell scripts A and B:
#   `A one | B two -D casemode=preserve`   -> B_ARGV[3]: two -D casemode=preserve
#   `A one |& B two -D casemode=preserve`  -> B_ARGV[3]: two -D casemode=preserve
#   `A one -D casemode=preserve`           -> A_ARGV[3]: one -D casemode=preserve
#   `A one & -D casemode=preserve`         -> A_ARGV[4]: one & -D casemode=preserve
#   `A one|B two -D casemode=preserve`     -> A_ARGV[4]: one|B two -D casemode=...
# The last two are why the rule is WORD-level and why `&` is in it: a `|` or `|&`
# WORD is a stage separator, a GLUED `a|b` is one literal argument (so the flags
# do reach the simulator, alongside a word the user's own row already broke), and
# a non-final `&` stops backgrounding the run and is handed on as a stray argv.
reset_rows
reg ngc $NGANY -casemode preserve
set PIPE {ngspice -b -r "$n.raw" "$N" | tee sim.log}
set d [compose spice $PIPE]
eqcheck CS223-a-pipeline-template-does-not-take-the-flags \
  "st=<[dg $d flag_status]> why=<[dg $d flag_reason]>\
 on_cmd=<[regexp {casemode} [dg $d cmd]]>" \
  {st=<unplaceable> why=<pipeline> on_cmd=<0>}

reset_rows
reg ngc $NGANY -casemode preserve
set PIPE2 {ngspice -b "$N" |& tee sim.log}
eqcheck CS223b-the-|&-separator-counts-too \
  "st=<[dg [compose spice $PIPE2] flag_status]> why=<[dg [compose spice $PIPE2] flag_reason]>" \
  {st=<unplaceable> why=<pipeline>}

# CS223c: the CONTROL that the rule is Tcl's rule and not a substring hunt. A
# glued `a|b` is ONE argument to Tcl (measured above), so the flags do land on
# the simulator's argv; the row is broken by its own author, not by us, and
# declining here would be a second bug wearing the first one's clothes.
# ⚠ WHICH ARM ANSWERS THIS ROW, stated because it is not the obvious one: this
# template's `"$N"|tee` is NOT a well-formed Tcl list element, so
# `sim_cmd_run_words` falls back to its whitespace scan and the answer comes from
# there. CS229/CS229b drive the LIST arm. Not measured: what `open` does with
# this exact string -- `eval execute $st $cmd` raises on it before `open` sees it.
reset_rows
reg ngc $NGANY -casemode preserve
set GLUED {ngspice -b "$N"|tee sim.log}
eqcheck CS223c-a-glued-pipe-is-not-a-tcl-pipeline \
  "st=<[dg [compose spice $GLUED] flag_status]> why=<[dg [compose spice $GLUED] flag_reason]>" \
  {st=<appended> why=<>}

# CS223d: THE HALF THAT ALREADY WORKED AND MUST KEEP WORKING. Word 0 of a
# pipeline IS the first stage's program (measured: A_ARGV carries the leading
# words), so the registered EXE is still applied to a piped row. Only the
# trailing FLAGS are unplaceable.
reset_rows
reg ngc $NGANY -casemode preserve
set d [compose spice $PIPE]
eqcheck CS223d-a-pipeline-still-gets-the-registered-exe-at-word-0 \
  "st=<[dg $d exe_status]> w0=<[lindex [dg $d cmd] 0]> tail=<[lrange [dg $d cmd] end-2 end]>" \
  "st=<applied> w0=<$NGANY> tail=<| tee sim.log>"

# CS223e: and it is SAID, at tag `error`, in a sentence about the PIPELINE --
# not the old one, which claimed the command does not start with the simulator
# when on a piped row it does.
reset_rows
reg ngc $NGANY -casemode preserve
set rep [pcall sim_compose_report [compose spice $PIPE]]
eqcheck CS223e-the-pipeline-is-reported-as-a-pipeline \
  "tags=<[tags [compose spice $PIPE]]> says_pipe=<[regexp -nocase {pipe} [lindex [lindex $rep 0] 1]]>\
 says_startswith=<[regexp -nocase {starts with} [lindex [lindex $rep 0] 1]]>" \
  {tags=<error> says_pipe=<1> says_startswith=<0>}

# CS224: a template whose LAST word is `&` -- measured above: appending makes the
# `&` a literal argv word AND stops the run being backgrounded.
reset_rows
reg ngc $NGANY -casemode preserve
set BG {ngspice -b -r "$n.raw" "$N" &}
eqcheck CS224-a-backgrounded-template-does-not-take-the-flags \
  "st=<[dg [compose spice $BG] flag_status]> why=<[dg [compose spice $BG] flag_reason]>" \
  {st=<unplaceable> why=<background>}

# CS225: ROW 0'S REASON IS THE FIRST WORD, AND IT IS NOT A PIPELINE. Row 0 is
# `$terminal -e {ngspice ... || sh}` -- a variable first word AND a shell `||`
# inside braces. Both facts point the same way here, so this row pins the ANSWER,
# not the order that produces it: `||` is not a Tcl stage separator, and after the
# close-out round the word scan reads Tcl's own quoting, so the braced `||` is not
# even a candidate. CS225b is the row that pins the ORDER.
#
# ⚠ RENAMED in the close-out round. It was
# `CS225-the-first-word-reason-outranks-the-pipeline-reason`, and that name was a
# claim this row cannot test: swapping the two arms in `sim_compose_cmd` left it
# GREEN (measured 2026-09-07 -- ALL PASS 47, not one row moved).
reset_rows
set ::sim_case_mode preserve
eqcheck CS225-row0-is-a-first-word-refusal-not-a-pipeline-one \
  "st=<[dg [compose spice $ROW0] flag_status]> why=<[dg [compose spice $ROW0] flag_reason]>" \
  {st=<unplaceable> why=<word>}

# CS225c: THE WORD ARM'S SENTENCE ITSELF, which until the close-out round said
# "there is nowhere to put -D casemode= where the simulator would see it". That
# is FALSE on the commonest shape that reaches this arm: on `cat "$N" | ngspice
# -b` the simulator is the pipeline's LAST stage, so trailing words DO reach it
# -- measured through the real `open "|$args"` path with an argv-echoing stub.
# The sentence now says xschem cannot TELL where the flags belong, which is true
# on every shape that gets here.
#
# ⚠ THIS ROW EXISTS BECAUSE NOTHING MOVED WHEN THE WORDING CHANGED. The whole
# suite stayed ALL PASS across the edit (measured 2026-09-07), so the user-facing
# sentence was regressible in silence -- the same gap the 0960 close-out found on
# its own advice clause. A sentence with no row is a sentence that can come back.
reset_rows
reg ngc $NGANY -casemode preserve
set CATPIPE {cat "$N" | ngspice -b}
## The report carries MORE THAN ONE line here -- the exe refusal comes first and
## the case-mode one second -- so this joins them all. Reading only line 0 is how
## this row first went red against a sentence that was already correct.
set CS225CSAY {}
foreach l [pcall sim_compose_report [compose spice $CATPIPE]] {
  append CS225CSAY [lindex $l 1] " "
}
eqcheck CS225c-the-first-word-refusal-says-xschem-cannot-tell-not-that-there-is-nowhere \
  "why=<[dg [compose spice $CATPIPE] flag_reason]> nowhere=<[regexp -nocase {nowhere} $CS225CSAY]>\
 names=<[regexp {'cat'} $CS225CSAY]> cannot=<[regexp -nocase {cannot tell where} $CS225CSAY]>" \
  {why=<word> nowhere=<0> names=<1> cannot=<1>}

# CS225b: THE ORDER OF THE TWO REASONS, PINNED BY A ROW THAT MOVES WHEN THE ORDER
# MOVES AND ONLY THEN. `cat "$N" | ngspice -b` is BOTH: its first word is not the
# simulator, and it is a real Tcl pipeline. The two reasons mint different
# sentences, and on THIS shape only the first-word one is true -- the last stage
# of that pipeline IS the simulator, so "trailing words go to its LAST stage, not
# to the simulator" would be a false statement on the user's screen.
# MEASURED 2026-09-07: swapping ONLY the two elseif arms of `sim_compose_cmd`
# turns this row's `why` from `word` into `pipeline`; nothing else in this file
# moves.
reset_rows
set ::sim_case_mode preserve
set CATPIPE {cat "$N" | ngspice -b}
eqcheck CS225b-the-first-word-reason-outranks-the-pipeline-reason \
  "st=<[dg [compose spice $CATPIPE] flag_status]> why=<[dg [compose spice $CATPIPE] flag_reason]>" \
  {st=<unplaceable> why=<word>}

# --- CS226 THE Xyce GATE READS WORDS, NOT THE WHOLE STRING --------------------
# `sim_registry_row_asks` matched `[xX]yce` against the ENTIRE template, so an
# ngspice row whose raw or log path merely CONTAINS the word lost the registry
# silently -- exe_status none, flag_status none, mode {} -- which is issue 1238's
# own defect. The gate now reads the LEADING RUN OF NON-OPTION WORDS (the
# program, and the program a wrapper hands on) and stops at the first option, so
# an argument path THAT FOLLOWS AN OPTION can never gate a row off.
#
# ⚠ THIS COMMENT SAID "an argument path can never gate a row off", FULL STOP,
# AND THAT IS FALSE -- corrected in the close-out round. An argument INSIDE the
# leading non-option run is still read as a program word; the scan has no way
# to tell it from a wrapper's payload. MEASURED 2026-09-07 on the shipped
# procs with ngspice registered at -casemode preserve:
#
#   ngspice /home/u/xyce          -> words {ngspice /home/u/xyce}  asks 0
#                                    exe none  flag none  mode {}
#   ngspice "$N" /home/u/xyce     -> same
#   ngspice -b -r "/home/u/xyce/out.raw" "$N"  -> words {ngspice}   asks 1
#                                    exe applied  flag appended  mode preserve
#
# That first shape is the registered simulator SILENTLY not applied -- CS226's
# own defect one notch narrower. It is NOT FIXED and NO ROW DRIVES IT: CS226
# and CS226b below are both option-preceded, which is the half the rule really
# covers. Left for the driver because narrowing the scan is a design call.
reset_rows
reg ngc $NGANY -casemode preserve
set XPATH {ngspice -b -r "/home/u/xyce/out.raw" "$N"}
set d [compose spice $XPATH]
eqcheck CS226-an-xyce-in-an-argument-path-does-not-gate-the-row-off \
  "exe=<[dg $d exe_status]> flag=<[dg $d flag_status]> mode=<[dg $d mode]>" \
  {exe=<applied> flag=<appended> mode=<preserve>}

reset_rows
reg ngc $NGANY -casemode preserve
set XLOG {ngspice -b -o /var/log/xyce/run.log "$N"}
eqcheck CS226b-an-xyce-in-a-log-path-does-not-gate-the-row-off \
  "exe=<[dg [compose spice $XLOG] exe_status]> flag=<[dg [compose spice $XLOG] flag_status]>" \
  {exe=<applied> flag=<appended>}

# CS226c: the wrapper shape the gate must still catch, beyond the shipped
# `mpirun` row CS203b pins -- the scan walks the leading non-option words.
reset_rows
reg ngc $NGANY -casemode preserve
set NICEX {nice /opt/Xyce/bin/Xyce "$N"}
eqcheck CS226c-a-wrapped-xyce-is-still-none \
  "exe=<[dg [compose spice $NICEX] exe_status]> flag=<[dg [compose spice $NICEX] flag_status]>\
 tags=<[tags [compose spice $NICEX]]>" \
  {exe=<none> flag=<none> tags=<>}

# CS226e: THE SCAN STOPS AT THE FIRST OPTION, and that is the tightest part of
# the rule. `file tail` alone is not enough: an option's VALUE can be a path
# whose last component is literally `xyce`, and gating an ngspice row off on that
# is the very defect CS226 is about, one notch narrower.
reset_rows
reg ngc $NGANY -casemode preserve
set XVAL {ngspice -b -r /tmp/xyce "$N"}
eqcheck CS226e-an-option-value-named-xyce-does-not-gate-the-row-off \
  "exe=<[dg [compose spice $XVAL] exe_status]> flag=<[dg [compose spice $XVAL] flag_status]>" \
  {exe=<applied> flag=<appended>}

# CS226d: THE LIMIT OF THE GATE, PINNED SO IT CANNOT BE MIS-QUOTED. The gate
# recognises a row that SPELLS xyce in a program word. A Xyce row spelled through
# a variable that does not end in the name is NOT recognised: it is DECLINED, and
# the user does get an error line on every press of Simulate. That is the honest
# rule -- "no error line for Xyce users" holds only for a literally-spelled xyce.
reset_rows
reg ngc $NGANY -casemode preserve
set XVAR {$XYCE_HOME/bin/simulator "$N"}
eqcheck CS226d-a-xyce-row-spelled-through-a-variable-is-declined-not-none \
  "exe=<[dg [compose spice $XVAR] exe_status]> tags=<[tags [compose spice $XVAR]]>" \
  {exe=<declined> tags=<error error>}

# CS226f: THE ONE `file` CALL THAT RAISES. MEASURED 2026-09-07, Tcl 8.6:
# `file tail ~xschem_no_such_user_1238` -> ERROR, `user "..." doesn't exist`
# (a tilde followed by a PATH does not raise -- `file tail ~nosuch/bin/Xyce` is
# `Xyce` -- only a bare `~name` does). `sim_compose_cmd` is called from
# `proc simulate` with NO catch around it, so a raise there aborts Simulate with
# a Tcl error and no run. The gate's word scan made this reachable from more
# words than before; the exe plan's own `file tail` on word 0 could already do
# it. Both are guarded, and this row drives WORD 0 -- the worse of the two.
reset_rows
reg ngc $NGANY -casemode preserve
set TILDE {~xschem_no_such_user_1238 -b "$N"}
set d [pcall sim_compose_cmd spice $TILDE $TILDE]
eqcheck CS226f-a-bare-tilde-user-word-does-not-abort-the-composer \
  "raised=<[string match ERR:* $d]> st=<[dg $d exe_status]>\
 unchanged=<[expr {[dg $d cmd] eq $TILDE}]>" \
  {raised=<0> st=<declined> unchanged=<1>}

# CS226g: the SECOND route to the same raise, and the one with NOTHING
# REGISTERED. `sim_cmd_takes_flags` reaches its own `file tail` only when the exe
# plan said `none` -- i.e. exactly the stock user who moved the global floor.
reset_rows
set ::sim_case_mode preserve
set TILDE2 {~xschem_no_such_user_1238 -b "$N"}
set d [pcall sim_compose_cmd spice $TILDE2 $TILDE2]
eqcheck CS226g-the-unregistered-route-to-the-tilde-raise-is-guarded-too \
  "raised=<[string match ERR:* $d]> st=<[dg $d flag_status]>" \
  {raised=<0> st=<unplaceable>}

# --- CS227 STOCK, NOTHING REGISTERED, THE GLOBAL FLOOR MOVED ------------------
# THE UNDISCLOSED HALF OF THE COMPATIBILITY CONTRACT. CS200 pins stock xschem at
# the SHIPPED floor (`fold`): byte-identical, silent. This row pins the OTHER
# stock configuration -- nothing registered, the global Case floor moved off
# `fold` -- where the composer now does something `proc simulate` never did
# before issue 1238: it appends to rows 1 and 2, and it puts an ERROR LINE on
# row 0, WHICH IS THE SHIPPED DEFAULT ROW. Whether that is right is a user call;
# it is on the owed ledger as rule `1238` (this comment said
# `1238_floor_only_append` until the close-out round; no such id was ever filed --
# `owed.sh list` carries `1238`, `1238_args_placement` and
# `1238_composer_sentences`). This row exists so the answer is stated rather than
# discovered.
reset_rows
set ::sim_case_mode preserve
set st {}
for {set i 0} {$i < 5} {incr i} {
  set d [compose spice $sim(spice,$i,cmd)]
  lappend st "$i:[dg $d flag_status]/[tags $d]"
}
eqcheck CS227-nothing-registered-with-the-floor-moved-is-not-silent \
  $st {0:unplaceable/error 1:appended/note 2:appended/note 3:none/ 4:none/}

# --- CS228 THE PIPELINE THAT ARRIVES THROUGH THE `subst` ----------------------
# THE SECOND ROUTE INTO THE HOLE CS223 CLOSED, AND CS223 COULD NOT SEE IT.
# `proc simulate` calls `sim_compose_cmd $tool $sim(...,cmd) $cmd` where `$cmd`
# is the template AFTER `subst -nobackslashes`. The repair round took the
# placement decision on the RAW template, so a `|` that is spelled by a VARIABLE
# -- `$env(NGPOST)`, `$terminal`, a `$::name` a user set in their simrc, all of
# which resolve in `proc simulate`'s scope -- was invisible to the test while
# being perfectly visible to `open "|$args"`.
#
# MEASURED 2026-09-07 on the tree as found, registry = ngspice at
# `-casemode preserve`:
#   raw = ngspice -b -r "$n.raw" "$N" $env(NGPOST)
#   sub = ngspice -b -r /tmp/x.raw /tmp/x.spice | tee sim.log
#   -> flag_status=appended, and
#      cmd = /usr/bin/ngspice ... | tee sim.log -D casemode=preserve -D casemodewrite
#      REPORT note: "Case mode: appending -D casemode=preserve -D casemodewrite"
# i.e. byte for byte the defect the repair round claimed to close, with the same
# note claiming the flags went to the simulator while they went to `tee`'s argv.
#
# THE EXE DECISION STILL READS THE RAW TEMPLATE and must keep doing so -- that is
# the only string in which `$terminal` is distinguishable from what it expands to
# (CS202b). The PLACEMENT decision reads the composed, substituted string,
# because that is the string `eval execute $st $cmd` hands to `open "|..."`.
reset_rows
reg ngc $NGANY -casemode preserve
set SUBRAW {ngspice -b -r "$n.raw" "$N" $env(NGPOST)}
set SUBSUB {ngspice -b -r /tmp/x.raw /tmp/x.spice | tee sim.log}
set d [pcall sim_compose_cmd spice $SUBRAW $SUBSUB]
eqcheck CS228-a-pipe-that-arrives-through-the-subst-is-still-a-pipeline \
  "st=<[dg $d flag_status]> why=<[dg $d flag_reason]>\
 on_cmd=<[regexp {casemode} [dg $d cmd]]>" \
  {st=<unplaceable> why=<pipeline> on_cmd=<0>}

# CS228b: and the CIW is told the truth about it. On the tree as found this said
# `note` / "appending", about a `tee` two words along.
reset_rows
reg ngc $NGANY -casemode preserve
set d [pcall sim_compose_cmd spice $SUBRAW $SUBSUB]
set rep [pcall sim_compose_report $d]
eqcheck CS228b-the-substituted-pipeline-is-reported-not-noted \
  "tags=<[tags $d]> says_pipe=<[regexp -nocase {pipe} [lindex [lindex $rep 0] 1]]>\
 says_appending=<[regexp -nocase {appending} [lindex [lindex $rep 0] 1]]>" \
  {tags=<error> says_pipe=<1> says_appending=<0>}

# --- CS229 THE TEST HAS A QUOTING MODEL, BECAUSE Tcl HAS ONE ------------------
# THE MIRROR OF CS223c, AND IT WAS OPEN. The repair round's comment said "the
# rule is Tcl's rule, word for word", and it was not: the scan was
# `regexp -all -inline` over whitespace, with no quoting model at all, so a `|`
# inside a QUOTED or BRACED argument answered `pipeline` and the registered case
# mode was silently lost on a WELL-FORMED row -- with the user told "this command
# is a pipeline, so trailing words go to its LAST stage" about a command that has
# exactly one stage.
#
# MEASURED 2026-09-07, Tcl 8.6, through `open "|$args"` with `args` collected
# exactly as `proc execute` collects it (a LIST; `eval execute $st $cmd` splits
# the string, `"|$args"` re-serialises it, `open` splits it again with LIST
# rules):
#   A one "a | b" -D casemode=preserve -D casemodewrite
#     -> A_N=6  A_ARGV[2]=<a | b> A_ARGV[3]=<-D> A_ARGV[4]=<casemode=preserve>
#   A one {a | b} -D casemode=preserve -D casemodewrite   -> identical
#   A -b deck -c "run | wrdata out v(a)" -D casemode=preserve
#     -> A_N=6  A_ARGV[4]=<run | wrdata out v(a)> A_ARGV[5]=<-D>
# So the flags DO reach the simulator on all three, and the shape is not
# hypothetical: `-c "run | wrdata out"` is how an ngspice control line is spelled.
reset_rows
reg ngc $NGANY -casemode preserve
set QPIPE {ngspice -b -r "$n.raw" "$N" -c "run | wrdata out v(a)"}
set d [compose spice $QPIPE]
eqcheck CS229-a-pipe-inside-a-quoted-argument-is-not-a-tcl-pipeline \
  "st=<[dg $d flag_status]> why=<[dg $d flag_reason]>\
 on_cmd=<[regexp {casemode=preserve} [dg $d cmd]]>" \
  {st=<appended> why=<> on_cmd=<1>}

reset_rows
reg ngc $NGANY -casemode preserve
set BPIPE {ngspice -b "$N" -c {run | wrdata out}}
eqcheck CS229b-a-pipe-inside-a-braced-argument-is-not-one-either \
  "st=<[dg [compose spice $BPIPE] flag_status]> why=<[dg [compose spice $BPIPE] flag_reason]>" \
  {st=<appended> why=<>}

# CS229c: THE DISCRIMINATOR. CS229 and CS229b only say "do not call THIS a
# pipeline", and a model that answers that by giving up early passes both while
# going blind to a real stage further along. This row carries both on one line: a
# `|` inside `-c "..."` AND a genuine trailing stage.
# MEASURED (sabotage, 2026-09-07): a scan that BREAKS at the first grouped word
# -- `if {[llength $w] > 1} { break }` -- keeps CS229 and CS229b green and reds
# this row (with CS223c as collateral, whose template is not a valid list).
# NOT MEASURED: a model that strips quoted text and then rescans the remainder.
# It is not obviously caught by this row -- the trailing `| tee` survives the
# strip -- so do not cite CS229c against that shape.
reset_rows
reg ngc $NGANY -casemode preserve
set MIXED {ngspice -b -c "run | wrdata out" "$N" | tee sim.log}
eqcheck CS229c-a-quoted-pipe-does-not-hide-a-real-one-on-the-same-line \
  "st=<[dg [compose spice $MIXED] flag_status]> why=<[dg [compose spice $MIXED] flag_reason]>" \
  {st=<unplaceable> why=<pipeline>}

# --- the Tcl bridge C calls ---------------------------------------------------
reset_rows
set ::sim_case_mode fold
eqcheck CS218-the-bridge-falls-back-to-the-global-floor \
  [pcall sim_netlist_casemode spice] fold
set ::sim_case_mode preserve
eqcheck CS218b-the-floor-is-the-fallback-not-a-constant \
  [pcall sim_netlist_casemode spice] preserve
set ::sim_case_mode fold
reg netl /bin/sh -casemode distinguish
eqcheck CS219-the-registered-simulator-outranks-the-floor \
  [pcall sim_netlist_casemode spice] distinguish
# ⚠ A NETLIST TYPE WITH NO CASE QUESTION ANSWERS NOTHING, NOT AN ERROR, and
# `{}` is what save.c reads as "keep the floor". A raise here would take the
# netlist down with it: this proc is called from the netlister, and stock xschem
# netlists with ase.tcl sourced, nothing registered and no session anywhere.
eqcheck CS219b-a-non-spice-netlist-type-answers-nothing-not-an-error \
  [pcall sim_netlist_casemode verilog] {}
reset_rows

# --- CS220 the C wire, observed through behaviour -----------------------------
# netlist_case_mode() is C and has no Tcl accessor. What it drives is item 14's
# collision warning, which C2 makes SILENT under `distinguish`. So: netlist a
# schematic whose nets collide, twice, moving only the registered simulator's
# casemode.
wfile [file join $scratch pr_coll.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 -190 200 -190 {}
N 0 -190 0 -130 {}
N 200 -130 200 -90 {}
C {devices/vsource} 0 -100 0 0 {name=V1 value=1.5}
C {devices/gnd} 0 -70 0 0 {name=l1 lab=0}
C {devices/res} 200 -160 0 0 {name=R1 value=1k}
C {devices/res} 200 -60 0 0 {name=R2 value=1k}
C {devices/gnd} 200 -30 0 0 {name=l2 lab=0}
C {devices/lab_pin} 100 -190 0 0 {name=p1 lab=Out}
C {devices/lab_pin} 200 -110 0 0 {name=p2 lab=OUT}}

proc ncoll {} {
  set n 0
  foreach ln [split [xschem get infowindow_text] \n] {
    if {[string match {*differ only in case*} $ln]} { incr n }
  }
  return $n
}
reset_rows
set ::sim_case_mode fold
xschem load [file join $scratch pr_coll.sch]
xschem netlist
set n_fold [ncoll]
reg coll /bin/sh -casemode distinguish
xschem netlist
set n_dist [ncoll]
reset_rows
check CS220-netlist_case_mode-really-reads-the-registered-simulator \
  [expr {$n_fold > 0 && $n_dist == 0}] \
  "(fold warned $n_fold times, distinguish warned $n_dist)"

# --- CS221 the whole point, end to end ----------------------------------------
wfile [file join $scratch pr_en.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 -190 200 -190 {}
N 0 -190 0 -130 {}
N 200 -130 200 -90 {}
C {devices/vsource} 0 -100 0 0 {name=V1 value=1.5}
C {devices/gnd} 0 -70 0 0 {name=l1 lab=0}
C {devices/res} 200 -160 0 0 {name=R1 value=1k}
C {devices/res} 200 -60 0 0 {name=R2 value=1k}
C {devices/gnd} 200 -30 0 0 {name=l2 lab=0}
C {devices/lab_pin} 100 -190 0 0 {name=p1 lab=EN}
C {devices/lab_pin} 200 -110 0 0 {name=p2 lab=OUT}
C {devices/code_shown} 460 -190 0 0 {name=STIMULI only_toplevel=false value=".tran 1n 10n
"}}

reset_rows
xschem load [file join $scratch pr_en.sch]
xschem netlist
set deck [file join $scratch pr_en.spice]
set nl {}
if {[file exists $deck]} { set f [open $deck] ; set nl [read $f] ; close $f }
check CS221a-the-netlister-emits-the-schematic-spelling \
  [expr {[string match {*V1 EN 0*} $nl] && ![string match {*V1 en 0*} $nl]}] \
  "(deck names EN verbatim)"

if {$NGCASE eq {}} {
  skip CS221-EN-survives-schematic-to-viewer {no case-capable ngspice on this machine}
} else {
  reg ngc $NGCASE -casemode preserve
  set sim(spice,default) 2
  set sim(spice,2,fg) 1
  catch {file delete [file join $scratch pr_en.raw]}
  simulate
  set names {} ; set mode {} ; set src {}
  if {![catch {xschem raw read [file join $scratch pr_en.raw] tran}]} {
    set names [split [xschem raw list] \n]
    set mode [xschem raw casemode]
    set src [xschem raw casemode -source]
    xschem raw clear
  }
  eqcheck CS221-EN-survives-schematic-to-viewer \
    "vEN=<[expr {[lsearch -exact $names {v(EN)}] >= 0}]>\
 ven=<[expr {[lsearch -exact $names {v(en)}] >= 0}]> mode=<$mode> src=<$src>" \
    {vEN=<1> ven=<0> mode=<preserve> src=<header>}
}
catch {ase::sim_clear}

} err]} {
  puts "FATAL: $err"
  puts "  $::errorInfo"
  incr fail
}

catch {test_scratch_drop $scratch}
puts "----"
puts "test_sim_plain_run: $npass passed, $fail failed, $nskip skipped"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks, $nskip skipped)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]

# THE BOUNDARY BETWEEN THE ENVIRONMENT AND THE STATE (issue 1395).
#
# The user's ruling of 2026-09-08, verbatim
# (doc/claude/ase_simchoice_batch/CREW_BRIEF.md):
#
#   "Yes, registering a simulator (so that future Xschems see the 'new'
#    simulator instance) is something that can make it to disk right away as
#    soon as done. But, registering a simulator is not part of the simulator
#    state that accompanies a test-bench cell in the library manager.
#    *Whether* the 'new' simulator just registered gets assigned as 'the one to
#    use' is an option that is part of the ASE-L state. If changed, that results
#    in dirtiness. User must explicitly save and, if user initiates an Xschem
#    shutdown, then she must get a warning and a prompt to save."
#
# Two things live on two sides of one line, and the shipped tree had each of
# them on the wrong side. This file measures the line itself, end to end, from
# the outside -- nothing here reads the source to decide whether the behaviour
# is right, except the one row whose subject IS a source file (section L).
#
#   L1-L4  THE LINT. Registering now WRITES ~/.xschem/ase_simulators, so a
#          headless suite that registers a stub without isolating itself
#          replaces the developer's real list with `/bin/sh`. Seven suites were
#          in exactly that position on the day the writer landed and were fixed
#          by hand; this row is what stops the eighth.
#   B1-B8  THE BOUNDARY, with ::USER_CONF_DIR redirected into scratch: what
#          reaches the conf file, what dirties a session, and what a run
#          resolves through.
#   Q1-Q7  THE QUIT PROMPT, headless. `ase::ui::close_request` and
#          `ase::ui::prompt_all_on_quit` are driven purely by
#          `ase::session_dirty`, so once the choice is a state key the warning
#          and the save prompt follow for free -- measured here rather than
#          read off the source, and with no Tk widget anywhere.
#
# NO DISPLAY IS REQUIRED and none is used: every row is pure Tcl over the
# public ase:: API plus three recorded shims in section Q. It therefore runs
# identically on full_audit's default arm and under `--nogui`.
#
# ⚠ THIS SUITE REGISTERS SIMULATORS, AND ITS SUBJECT IS THE SAVING, so it does
# NOT call `test_sim_registry_isolate` -- that helper clears the autosave seam
# and would opt the writer out of the very rows below. It redirects
# ::USER_CONF_DIR into its own scratch dir instead, BEFORE the first
# registration, exactly as test_ase_simreg_0931 does. The developer's own
# ~/.xschem is never read, written, renamed or backed up.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --nogui --script tests/headless/test_ase_simchoice_1395.tcl
#
# FLOOR, raised and never lowered: 31 checks, on either arm (nothing here is
# display-conditional, so the two counts are the same number). Raise it when
# rows are added.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# recent-files gate (issue 0119)
set no_recent_files 1

set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch ase_simchoice]

## ⚠ THE REDIRECT COMES FIRST, ABOVE EVERY OTHER LINE THAT COULD REGISTER.
## This is the isolation section L below scans every other suite for, and the
## reason it has to be here rather than further down is the reason the row is
## ordered at all: `ase::sim_register` writes at the moment it is called, so an
## isolation line placed AFTER the first call has already lost the file.
set ::USER_CONF_DIR [file join $scratch conf]
file mkdir $::USER_CONF_DIR
set CONF [ase::sim_conf_file]

## ...and start from an empty registry. `src/xschem.tcl` calls
## ase::sim_load_conf at startup, so whatever is in the developer's real list is
## already in MEMORY by the time this line runs (issue 1377). Clearing memory is
## both sufficient and the only safe move -- the file is not touched.
catch {ase::sim_clear}
catch {ase::sim_caps_clear}
set ::ASE_SIMULATORS {}
set ::ASE_SIMULATOR  {}

if {[catch {

# --- helpers -----------------------------------------------------------------
proc slurp {p} {
  if {![file exists $p]} { return {NOFILE} }
  set f [open $p r] ; set d [read $f] ; close $f ; return $d
}
proc conf_lines {} { return [split [string trimright [slurp $::CONF] "\n"] "\n"] }
proc conf_glob {pat} { return [lsearch -inline -glob [conf_lines] $pat] }
proc conf_mtime {} {
  if {![file exists $::CONF]} { return NOFILE }
  return [file mtime $::CONF]
}
## a runnable stub. The registry only ever *starts* these in a run, and no row
## here runs one, but ase::sim_register validates the file, so it has to be a
## real executable or every registration below reports ok 0 for the wrong reason.
proc stub {name} {
  set p [file join $::scratch $name]
  set f [open $p w] ; puts $f "#!/bin/sh" ; puts $f "exit 0" ; close $f
  file attributes $p -permissions 0755
  return $p
}
## a state file + a registered session on it, ready to dirty
proc mksession {key {entry {}}} {
  set p [file join $::scratch [string map {/ _} $key].state]
  ase::state_save $p [ase::state_default]
  ase::session_open $key $p
  if {$entry ne {}} {
    ase::session_update $key [ase::sim_choice_set [ase::session_state $key] entry $entry]
  }
  return $p
}

set A [stub ng-alpha]
set B [stub ng-beta]
set G [stub ng-gamma]

# =============================================================================
# SECTION L -- THE LINT. A SUITE THAT REGISTERS MUST ISOLATE ITSELF FIRST.
# =============================================================================
# ⚠ WHY THIS ROW EXISTS, AND WHAT IS AT RISK IF IT GOES.
#
# `ase::sim_register` used to write nothing at all. As of the 2026-09-08 ruling
# it persists the registry at the moment the registry changes -- that is the
# whole point of the "registering is environment" half -- and its target is
# $::USER_CONF_DIR/ase_simulators, which for a suite that redirects nothing is
# THE DEVELOPER'S OWN ~/.xschem/ase_simulators. That file is not test data. On
# this box it holds exactly one entry, `ngspice-ver50`, pointing at a build the
# user made themselves and cannot get back from any repository.
#
# Fourteen files under tests/headless/ mention `ase::sim_register`; thirteen of
# them CALL it (the fourteenth is scratch.tcl, which only writes about it).
# SEVEN of the thirteen redirected nothing on the day the writer landed, and
# every one of those seven registers a STUB -- `/bin/sh`, a two-line shell
# script, a file that is deliberately not executable. One `full_audit.sh` run
# would have replaced the user's real entry with those. All seven were fixed by
# hand -- four of them at once, by teaching scratch.tcl's shared helper to clear
# the seam. Nothing stopped the eighth, and "remember to isolate" is precisely
# the discipline this tree has already watched fail (see the header of
# test_selflog_grep_guard.tcl).
#
# WHAT COUNTS AS ISOLATED, and why there are three spellings rather than one:
#   * `set ::USER_CONF_DIR <scratch>`   -- the writer still runs, but into a
#     scratch file. This is what a suite whose SUBJECT is the saving must use
#     (this file, test_ase_simreg_0931, test_ase_simdlg_0937): it keeps the real
#     writer under test.
#   * `set ::ase::sim_autosave 0`       -- the test seam. The writer does not
#     run at all. For a suite that needs a registry but has no interest in the
#     file.
#   * `test_sim_registry_isolate`       -- scratch.tcl's shared helper, which
#     clears the seam among other things. THREE suites are isolated by this and
#     by nothing else (test_ase_core, test_ase_optier_0963, test_ase_sod_case),
#     so a row that did not recognise the helper would red three green suites
#     and be reverted within the hour. L3 keeps that branch honest.
#
# ⚠ ORDER IS THE WHOLE RULE. The isolation must come BEFORE the first call,
# because the first call is when the file is written. A suite that redirects
# ::USER_CONF_DIR on the line *after* its first `ase::sim_register` has already
# overwritten the real list. L2 measures that case explicitly.

proc lint_read {p} { set f [open $p r] ; set d [read $f] ; close $f ; return $d }

## The scan, over one file. Returns the line number of the first UNCOMMENTED
## call to a registry WRITER (`ase::sim_register` / `ase::sim_unregister`, the
## two procs that call ase::sim_touch) that is not preceded by an isolation
## line, or 0 when the file is clean or never registers.
##
## Comment lines are dropped whole: a `#` in column 1 (after indentation) is
## the only comment shape a Tcl script has at statement level, and this tree's
## suites carry paragraphs of prose naming both `ase::sim_register` and
## `test_sim_registry_isolate` -- a naive scan would read the prose as code in
## both directions and be wrong twice.
proc lint_file {path} {
  set n 0
  set iso 0
  foreach line [split [lint_read $path] "\n"] {
    incr n
    set t [string trimleft $line]
    if {[string index $t 0] eq {#}} { continue }
    if {[string first {set ::USER_CONF_DIR}     $t] >= 0} { set iso 1 }
    if {[string first {set ::ase::sim_autosave} $t] >= 0} { set iso 1 }
    if {[string first {test_sim_registry_isolate} $t] >= 0} { set iso 1 }
    if {[string first {ase::sim_register}   $t] >= 0 ||
        [string first {ase::sim_unregister} $t] >= 0} {
      if {$iso} { return 0 }
      return $n
    }
  }
  return 0
}
## ...and over a list of files. The answer NAMES THE FILE, because the whole
## value of this row is that the next author reads the failure text and knows
## what to add and where.
proc lint_scan {files} {
  set bad {}
  foreach p $files {
    set n [lint_file $p]
    if {$n} {
      lappend bad "[file tail $p]:$n registers a simulator with no ::USER_CONF_DIR\
redirect, no `set ::ase::sim_autosave 0` and no test_sim_registry_isolate above\
it -- it would write the user's own ~/.xschem/ase_simulators"
    }
  }
  return $bad
}

set L_FILES [lsort [glob -nocomplain [file join $here test_*.tcl]]]
## L1 THE ROW ITSELF. The second element is the non-vacuity guard the shape of
## this scan always needs: a glob that matched nothing also scans clean.
check "L1 SOURCE-GREP no headless suite registers a simulator before isolating itself from the user's own ~/.xschem/ase_simulators" \
  [list [lint_scan $L_FILES] [expr {[llength $L_FILES] >= 300}]] {{} 1}

## L2 THE DETECTOR'S OWN EVIDENCE. A detector that finds nothing is not
## evidence until it has been shown to find something, and to find it for the
## right reason. Five fixtures, written here as DATA: the bare offender, one for
## each accepted spelling, and the two ways a suite can LOOK isolated and not
## be -- the isolation below the call, and the isolation in a comment. The last
## two are not hypothetical shapes; they are what a hurried author actually
## writes.
proc lint_fixture {tag body} {
  set p [file join $::scratch lintfix_$tag.tcl]
  set f [open $p w] ; puts $f $body ; close $f
  return $p
}
set LF(bare)    [lint_fixture bare      "ase::sim_register zz /bin/sh\n"]
set LF(conf)    [lint_fixture conf      "set ::USER_CONF_DIR /tmp/zz\nase::sim_register zz /bin/sh\n"]
set LF(seam)    [lint_fixture seam      "catch {set ::ase::sim_autosave 0}\nase::sim_register zz /bin/sh\n"]
set LF(helper)  [lint_fixture helper    "test_sim_registry_isolate\nase::sim_register zz /bin/sh\n"]
set LF(late)    [lint_fixture late      "ase::sim_register zz /bin/sh\nset ::USER_CONF_DIR /tmp/zz\n"]
set LF(comment) [lint_fixture comment   "# test_sim_registry_isolate is called by the helper below\nase::sim_register zz /bin/sh\n"]
set LF(unreg)   [lint_fixture unreg     "ase::sim_unregister ngspice-ver50\n"]
set LF(none)    [lint_fixture none      "puts {this suite never registers anything}\n"]
check "L2 the detector really detects: an unisolated registration is caught, each of the three isolations is accepted, and neither a LATE redirect nor one that is only a COMMENT is mistaken for isolation" \
  [list [lint_file $LF(bare)] [lint_file $LF(conf)] [lint_file $LF(seam)] \
        [lint_file $LF(helper)] [lint_file $LF(late)] [lint_file $LF(comment)] \
        [lint_file $LF(unreg)] [lint_file $LF(none)]] \
  {1 0 0 0 1 2 1 0}
## ...and the failure text names the file, which is the row's whole product.
check_true "L2 the failure text names the offending file" \
  [expr {[string first [file tail $LF(bare)] [lindex [lint_scan [list $LF(bare)]] 0]] >= 0}]

## L3 THE HELPER BRANCH, KEPT HONEST. Three real suites are isolated by
## `test_sim_registry_isolate` and by nothing else. If the row stopped
## recognising the helper it would red those three, and if the tree stopped
## having any it would mean the branch is dead code nobody would notice
## breaking. Measured by re-running the scan with the helper spelling removed
## from the accepted set: the same tree must then produce at least three
## offenders, all of which are green under the real rule.
proc lint_file_nohelper {path} {
  set n 0 ; set iso 0
  foreach line [split [lint_read $path] "\n"] {
    incr n
    set t [string trimleft $line]
    if {[string index $t 0] eq {#}} { continue }
    if {[string first {set ::USER_CONF_DIR}     $t] >= 0} { set iso 1 }
    if {[string first {set ::ase::sim_autosave} $t] >= 0} { set iso 1 }
    if {[string first {ase::sim_register}   $t] >= 0 ||
        [string first {ase::sim_unregister} $t] >= 0} {
      if {$iso} { return 0 }
      return $n
    }
  }
  return 0
}
set L3ONLY {}
foreach p $L_FILES {
  if {[lint_file $p] == 0 && [lint_file_nohelper $p] != 0} { lappend L3ONLY [file tail $p] }
}
## Deliberately NOT an exact set: the row's claim is that the branch carries
## real weight, not that the tree has exactly three of these forever. A crew
## adding a fourth helper-only suite must not red an inventory it never read.
set L3WANT {test_ase_core.tcl test_ase_optier_0963.tcl test_ase_sod_case.tcl}
set L3MISS {}
foreach f $L3WANT { if {[lsearch -exact $L3ONLY $f] < 0} { lappend L3MISS $f } }
check "L3 the shared-helper route is load-bearing: at least three suites are isolated by test_sim_registry_isolate and by nothing else, so a row that stopped recognising it would red them" \
  [list $L3MISS [expr {[llength $L3ONLY] >= 3}]] {{} 1}

## L4 AND THE HELPER REALLY DOES IT. L1 accepts a one-word call; this is the
## measurement that makes accepting it legitimate. `test_sim_registry_isolate`
## clears the autosave seam, so a suite that calls it registers into memory and
## writes nothing at all.
set L4WAS $::ase::sim_autosave
set ::ase::sim_autosave 1
test_sim_registry_isolate
check "L4 test_sim_registry_isolate clears the autosave seam, which is what makes it count as isolation" \
  $::ase::sim_autosave 0
set ::ase::sim_autosave $L4WAS
check "L4 ...and this suite is back to the live writer, because measuring it is its subject" \
  $::ase::sim_autosave 1

# =============================================================================
# SECTION B -- THE BOUNDARY, END TO END
# =============================================================================
# ⚠ EVERY ROW BELOW IS A `BEFORE` AND AN `AFTER` OF THE SAME FILE, because the
# claim being measured is always about what did or did not reach the disk. The
# mtime is the instrument: a writer that rewrote byte-identical content would
# still move it, so `mtime unchanged` really does mean `not written`, which
# `size unchanged` and `content unchanged` do not.

## B1 REGISTERING WRITES AT ONCE, WITH NO SAVE AND NO DIALOG. Typed the way the
## CIW types it: `ase::sim_register` as a command, nothing else. Before this
## batch the ONLY production caller of the writer was the Simulators dialog's
## commit, so a registration made from the Command window survived exactly as
## long as the process -- issue 1370's own comment already recorded that this
## user's `ngspice-ver50` entry was created through that door.
set B1BEFORE [file exists $CONF]
set B1R1 [ase::sim_register ng-alpha $A]
set B1AFTER1 [file exists $CONF]
set B1R2 [ase::sim_register ng-beta $B]
check "B1 registering from the Command window reaches the disk at once -- no explicit save, no dialog" \
  [list $B1BEFORE $B1R1 $B1AFTER1 $B1R2 [file exists $CONF]] {0 1 1 1 1}
check "B1 ...and the file names both entries and the program each one points at" \
  [list [expr {[conf_glob "ase::sim_register ng-alpha $A *"] ne {}}] \
        [expr {[conf_glob "ase::sim_register ng-beta $B *"] ne {}}] \
        [llength [ase::sim_list]]] {1 1 2}

## B2 ...AND IT DOES NOT DIRTY A SESSION. The other half of the user's first
## sentence: registering "is not part of the simulator state that accompanies a
## test-bench cell". A session that is open while a simulator is registered has
## nothing to save.
mksession L/C/b2
check "B2 an open session is clean before, during and after a registration -- registering is environment, not state" \
  [list [ase::session_dirty L/C/b2] \
        [ase::sim_register ng-gamma $G] [ase::session_dirty L/C/b2] \
        [llength [ase::sim_list]] \
        [ase::sim_unregister ng-gamma] [ase::session_dirty L/C/b2] \
        [llength [ase::sim_list]]] \
  {0 1 0 3 1 0 2}

## B3 THE ORIGIN GATE. `ase::sim_load_conf` SOURCES the file, so every line in
## it is a real `ase::sim_register` call -- and every one of those now calls the
## writer. Without the `sim_origin` gate the reader would rewrite the file it is
## in the middle of reading, once per line. This is landmine 1 of the batch
## brief and it is the one that would have been silent.
set B3M [conf_mtime] ; set B3S [file size $CONF]
after 1100
set B3RC [ase::sim_load_conf]
check "B3 reading the saved list does not rewrite it: sim_load_conf sources ase::sim_register lines and the origin gate stops each one writing back" \
  [list $B3RC [expr {[conf_mtime] eq $B3M}] [expr {[file size $CONF] == $B3S}] \
        [llength [ase::sim_list]]] {1 1 1 2}

## B4 TEARDOWN IS NOT A CHOICE. `ase::sim_clear` deliberately does not persist:
## a mutation that expresses a user's choice reaches disk, a teardown does not.
## An autosave here is the one way an autosave-at-the-mutation design can DESTROY
## data -- a suite's reset, or a stray line in somebody's script, would blank the
## user's real saved list. What it clears is memory; the file keeps every entry,
## which is the difference between forgetting and deleting.
set B4M [conf_mtime] ; set B4S [file size $CONF]
after 1100
ase::sim_clear
set B4EMPTY [llength [ase::sim_list]]
set B4STILL [list [expr {[conf_mtime] eq $B4M}] [file exists $CONF] \
                  [expr {[file size $CONF] == $B4S}]]
ase::sim_load_conf
check "B4 sim_clear forgets the registry without deleting it: memory empties, the file is not touched, and the next read brings every entry back" \
  [list $B4EMPTY $B4STILL [llength [ase::sim_list]] [ase::sim_selected]] \
  {0 {1 1 1} 2 ng-alpha}

## B5 THE CHOICE DIRTIES, AND GOES NOWHERE NEAR THE FILE. The second half of
## the ruling: "*Whether* the 'new' simulator just registered gets assigned as
## 'the one to use' is an option that is part of the ASE-L state. If changed,
## that results in dirtiness."
set B5M [conf_mtime]
set B5D0 [ase::session_dirty L/C/b2]
after 1100
ase::session_update L/C/b2 \
  [ase::sim_choice_set [ase::session_state L/C/b2] entry ng-beta]
check "B5 changing the session's simulator makes it dirty, and moves nothing on disk" \
  [list $B5D0 [ase::session_dirty L/C/b2] \
        [ase::sim_choice_of [ase::session_state L/C/b2]] \
        [expr {[conf_mtime] eq $B5M}]] \
  {0 1 {entry ng-beta} 1}
## the difference really IS the choice and nothing else, so B5 cannot be passing
## because something unrelated moved in the state dict.
check "B5 ...and the choice is the ONLY difference between the session and its saved copy" \
  [expr {[dict remove [ase::session_state L/C/b2] sim_entry] eq
         [dict remove [dict get $::ase::sessions L/C/b2 saved] sim_entry]}] 1

## B6 EXPLICIT SAVE, AND IT COMES BACK. "User must explicitly save."
ase::session_save L/C/b2
set B6LINE [lsearch -inline -glob \
  [split [string trim [slurp [ase::session_path L/C/b2]]] "\n"] {sim_entry *}]
## a SECOND session opened on the same file: the choice survives the process's
## memory, not just this session's dict.
ase::session_open L/C/b2fresh [ase::session_path L/C/b2]
check "B6 an explicit save clears the dirty mark, writes the choice into the state file, and a session opened fresh on that file has it" \
  [list [ase::session_dirty L/C/b2] $B6LINE \
        [ase::sim_choice_of [ase::session_state L/C/b2fresh]] \
        [ase::session_load L/C/b2] \
        [ase::sim_choice_of [ase::session_state L/C/b2]] \
        [ase::session_dirty L/C/b2]] \
  {0 {sim_entry {name ng-beta}} {entry ng-beta} 1 {entry ng-beta} 0}

## B7 THE RULING IN ONE SCREEN. The session is running ng-beta; the machine's
## own file says ng-alpha, because the choice never belonged there. Before this
## batch `ase::sim_write_body` wrote `ase::sim_use` -- the entry in force -- so
## a choice gesture landed in the environment file whether anyone saved or not.
set B7M [conf_mtime]
ase::sim_apply_choice [ase::session_state L/C/b2]
check "B7 the installation file names the DEFAULT while the session runs a different entry -- a choice gesture cannot leak into the environment" \
  [list [ase::sim_in_force_choice] [ase::sim_default_choice] \
        [conf_glob {ase::sim_select *}] [expr {[conf_mtime] eq $B7M}]] \
  {{entry ng-beta} {entry ng-alpha} {ase::sim_select ng-alpha} 1}

## B8 AND THE RUN FOLLOWS THE RUNNING SESSION. `ase::sim_apply_choice` sits in
## `ase::run_deck`, the one body all three run doors share, so whichever session
## is being RUN decides which program starts. Three applications in a row, the
## third going back to the first, so the row cannot pass on a one-way latch;
## then the two fall-through arms -- a state with no opinion runs the
## installation default, and `none` runs the program on the PATH.
proc b8 {st} {
  set applied [ase::sim_apply_choice $st]
  set s [ase::sim_status ngspice]
  return [list $applied [dict get $s entry] [dict get $s source]]
}
set B8A [ase::sim_choice_set [ase::state_default] entry ng-alpha]
set B8B [ase::sim_choice_set [ase::state_default] entry ng-beta]
check "B8 the run resolves through the running session's choice: two states naming two entries answer their own entry, both times and back again" \
  [list [b8 $B8A] [b8 $B8B] [b8 $B8A]] \
  [list {{entry ng-alpha} ng-alpha registry} {{entry ng-beta} ng-beta registry} \
        {{entry ng-alpha} ng-alpha registry}]
check "B8 ...a state with no choice of its own runs the installation default, and `none` runs the program on the PATH" \
  [list [b8 [ase::state_default]] \
        [b8 [ase::sim_choice_set [ase::state_default] path]]] \
  [list {{entry ng-alpha} ng-alpha registry} {{path {}} {} path}]

# =============================================================================
# SECTION Q -- THE WARNING AND THE PROMPT ON SHUTDOWN, HEADLESS
# =============================================================================
# "...and if user initiates an Xschem shutdown, then she must get a warning and
# a prompt to save."
#
# `ase::ui::close_request` and `ase::ui::prompt_all_on_quit` (src/ase_window.tcl)
# are driven by `ase::session_dirty` and by nothing else, so making the choice a
# schema key is the whole implementation of that sentence. THE CLAIM IS MEASURED
# HERE RATHER THAN READ OFF THE SOURCE: a structural grep of those two procs
# would say only that the word appears in them, and the two procs are being
# edited in the same batch as this file.
#
# ⚠ NO Tk, NO WIDGET, NO DISPLAY. Three procs are shimmed and RESTORED, and the
# restoration is asserted: `ask_save_close` (which posts the modal dialog),
# `save_state_modal` (which posts the Save-As dialog) and `ase::ui::close`
# (which tears a real window down). The window registry `ase::ui::wins` is given
# fake toplevel paths, which is all either proc reads it for. What is left under
# measurement is exactly the decision logic.
rename ase::ui::ask_save_close   q_o_ask
rename ase::ui::close            q_o_close
rename ase::ui::save_state_modal q_o_modal
proc ase::ui::ask_save_close {key} { lappend ::q_asked $key ; return $::q_answer }
proc ase::ui::save_state_modal {key} { lappend ::q_saved $key ; return $::q_modal }
proc ase::ui::close {key} {
  lappend ::q_closed $key
  catch {dict unset ::ase::ui::wins $key}
  return 1
}
set ::q_answer cancel ; set ::q_modal 1 ; set ::q_n 0
proc q_reset {} { set ::q_asked {} ; set ::q_closed {} ; set ::q_saved {} }
proc q_session {key {entry {}}} {
  mksession $key $entry
  dict set ::ase::ui::wins $key .qfake[incr ::q_n]
  return $key
}
proc q_open {key} { return [expr {[dict exists $::ase::ui::wins $key] ? 1 : 0}] }
set ::ase::ui::wins [dict create]
q_reset

## Q1 A CLEAN SESSION IS CLOSED WITHOUT A WORD. The negative control for
## everything below: if close_request asked here, "it asks when dirty" would be
## worth nothing.
q_session L/C/q1
check "Q1 a clean session closes with no warning and no prompt" \
  [list [ase::session_dirty L/C/q1] [ase::ui::close_request L/C/q1] \
        $::q_asked $::q_closed [q_open L/C/q1]] \
  {0 {} {} L/C/q1 0}

## Q2 DIRTY BY THE CHOICE ALONE -> THE WARNING, AND CANCEL REALLY CANCELS.
q_reset ; set ::q_answer cancel
q_session L/C/q2 ng-beta
set Q2ONLY [expr {[dict remove [ase::session_state L/C/q2] sim_entry] eq
                  [dict remove [dict get $::ase::sessions L/C/q2 saved] sim_entry]}]
ase::ui::close_request L/C/q2
check "Q2 a session dirty ONLY because the simulator was changed gets the prompt, and Cancel leaves the window standing" \
  [list [ase::session_dirty L/C/q2] $Q2ONLY $::q_asked $::q_closed [q_open L/C/q2]] \
  {1 1 L/C/q2 {} 1}
q_reset ; set ::q_answer no
ase::ui::close_request L/C/q2
check "Q2 ...and No closes it, discarding the change" \
  [list $::q_asked $::q_closed [q_open L/C/q2]] {L/C/q2 L/C/q2 0}

## Q3 YES -> SAVE, AND A CANCELLED SAVE ABORTS THE CLOSE. The user asked for a
## prompt TO SAVE; a Yes whose Save-As the user then cancels must not throw the
## work away anyway.
q_reset ; set ::q_answer yes ; set ::q_modal 0
q_session L/C/q3 ng-beta
ase::ui::close_request L/C/q3
check "Q3 Yes offers the save, and a save the user cancels leaves the window standing" \
  [list $::q_saved $::q_closed [q_open L/C/q3]] {L/C/q3 {} 1}
q_reset ; set ::q_modal 1
ase::ui::close_request L/C/q3
check "Q3 ...and a save that completes closes it" \
  [list $::q_saved $::q_closed [q_open L/C/q3]] {L/C/q3 L/C/q3 0}

## Q4 THE GATE IS session_dirty AND NOTHING ELSE, IN BOTH DIRECTIONS. Same
## session, same registry, same choice in the state -- SAVED, and the prompt is
## gone. Then the choice cleared back to "no opinion", and the prompt is gone
## again, because the state matches its saved copy once more.
q_reset ; set ::q_answer cancel
q_session L/C/q4 ng-alpha
set Q4D1 [ase::session_dirty L/C/q4]
ase::session_save L/C/q4
set Q4D2 [ase::session_dirty L/C/q4]
ase::ui::close_request L/C/q4
check "Q4 saving the choice stops the prompt: the same session, the same choice, nothing asked" \
  [list $Q4D1 $Q4D2 $::q_asked $::q_closed] {1 0 {} L/C/q4}
q_reset
q_session L/C/q4b ng-alpha
set Q4D3 [ase::session_dirty L/C/q4b]
ase::session_update L/C/q4b [ase::sim_choice_set [ase::session_state L/C/q4b] unset]
set Q4D4 [ase::session_dirty L/C/q4b]
ase::ui::close_request L/C/q4b
check "Q4 ...and so does putting the choice back: dirtiness follows the value, not the fact that it was touched" \
  [list $Q4D3 $Q4D4 $::q_asked $::q_closed] {1 0 {} L/C/q4b}

## Q5-Q7 THE SHUTDOWN SWEEP. `ase::ui::prompt_all_on_quit` is what xschem's own
## quit calls; it returns 0 to ABORT the quit.
set ::ase::ui::wins [dict create]
q_reset ; set ::q_answer cancel
q_session L/C/q5
check "Q5 quitting with only clean sessions open proceeds, and asks nobody" \
  [list [ase::ui::prompt_all_on_quit] $::q_asked $::q_closed] {1 {} {}}

q_reset
q_session L/C/q6 ng-beta
check "Q6 a session dirty by the simulator choice is warned about on quit, and Cancel ABORTS the quit" \
  [list [ase::ui::prompt_all_on_quit] $::q_asked $::q_closed] {0 L/C/q6 {}}
q_reset ; set ::q_answer no
check "Q6 ...and No lets the quit proceed, closing it" \
  [list [ase::ui::prompt_all_on_quit] $::q_asked $::q_closed] {1 L/C/q6 L/C/q6}

q_reset ; set ::q_answer cancel
check "Q7 with nothing dirty left the sweep is silent again -- the clean session from Q5 is still open and is still not asked about" \
  [list [ase::ui::prompt_all_on_quit] $::q_asked $::q_closed [q_open L/C/q5]] \
  {1 {} {} 1}

## RESTORE, AND PROVE IT. A rename that left a shim in place would poison every
## later suite in a shared interpreter and, worse, would make the rows above
## look like they had run against the product.
foreach {q_orig q_name} {q_o_ask ase::ui::ask_save_close \
                         q_o_close ase::ui::close \
                         q_o_modal ase::ui::save_state_modal} {
  rename $q_name {}
  rename $q_orig $q_name
}
check "Q every shim restored, by name and by body" \
  [list [info procs q_o_ask] [info procs q_o_close] [info procs q_o_modal] \
        [expr {[string first {ase::session_dirty} [info body ase::ui::close_request]] >= 0}]] \
  {{} {} {} 1}

# =============================================================================
# THE PROMISE THIS WHOLE FILE MAKES
# =============================================================================
## Everything above wrote into $scratch and into $::USER_CONF_DIR, which is
## inside it. This is the row that says so: the conf file this suite has been
## writing all along is under the scratch dir and is NOT the developer's.
check "Z the conf file this suite wrote is inside its own scratch dir, and is not the one under \$HOME" \
  [list [string first [file normalize $scratch] [file normalize $CONF]] \
        [expr {[file normalize $CONF] eq
               [file normalize [file join ~ .xschem ase_simulators]]}] \
        [expr {[string first [file normalize [file join ~ .xschem]] \
                             [file normalize $CONF]] >= 0}]] \
  {0 0 0}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# --- cleanup + verdict -------------------------------------------------------
catch {ase::sim_clear}
test_scratch_drop $scratch
check "cleanup: scratch removed" [file exists $scratch] 0
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]

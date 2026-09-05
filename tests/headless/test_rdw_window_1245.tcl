# tests/headless/test_rdw_window_1245.tcl — item B3 of
# doc/claude/op_param_batch/PLAN.md (feature 1245, the Results Display Window).
# Spec: doc/claude/specs/op_param_lists.md §4.2 B1/B2/B3/B7 and §5.1 Q6/Q10.
# Rulings: doc/claude/op_param_batch/DECISIONS.md — D-3, D-4, D-5 and driver
# decision DD-1, whose corollary ("a caller that renders the pairs silently
# reads as a COMPLETE list") is this item's central rendering obligation.
#
# ============================================================================
# WHAT IS UNDER TEST
# ============================================================================
# B3 adds THE WINDOW and nothing else — no keys, no button behaviour, no C:
#
#   src/rdw.tcl, namespace rdw::, three layers so the RENDERER is testable
#   with no Tk at all:
#     pure     rdw::_cadence_path  rdw::format_answer  rdw::block_text
#              rdw::button_state   rdw::_rowdevs
#     context  rdw::header  rdw::sim  rdw::dump_devpath  rdw::dump  rdw::status
#     Tk       rdw::have_tk  open  close  build  push  render_pane  set_list
#              rdw::inert   rdw::palette  rdw::color
#   src/Makefile.in — rdw.tcl in /local/install_shares (ONE list, TWO generated
#              lines: the issue 0424 receipt, `grep -c rdw.tcl src/Makefile` 0->2)
#   src/xschem.tcl — the bare `source $XSCHEM_SHAREDIR/rdw.tcl` and the ONE
#              main-menubar Tools entry "Results Display Window".
#
# ⚠ THE BUTTONS ARE INERT IN THIS ITEM. The column, the greying and a
# test-drivable path to each button are B3's; reorder / delete / add / save
# behaviour and the two scope dialogs are B5's. No row below asserts a
# behaviour, and rows W4/S1 fence the boundary from the other side.
#
# ============================================================================
# THE ONE SENTENCE EACH
# ============================================================================
# WHAT THE WINDOW SAYS: what THIS run's currently selected raw slot actually
# holds and actually computed for exactly this device path, which primitive
# each number belongs to, which columns the simulator did not compute, which
# ones came back non-finite, that the list is not everything the device has,
# and — when there is nothing — WHICH of the five silences this is.
# WHAT IT DOES NOT SAY: that the run converged (an empty `nonfinite` bucket is
# not proof: the same NaN in an ASCII raw arrives as a finite 0 and lands in
# `devices` — src/save.c, deliberate, issue 1272 still open), what parameters
# the device HAS, or anything at all about a slot that is not the current one.
#
# ============================================================================
# THE THREE RENDERING OBLIGATIONS, ALL RULED, NONE OPTIONAL
# ============================================================================
# 1. `complete` 0 MUST BE VISIBLE (DD-1's corollary)          rows F2 F3 F11 Q1
# 2. `nonfinite` renders "(did not converge)", NEVER a blank
#    and NEVER the raw `nan`/`inf` text (rule debt
#    1245_B1_nonfinite_render option (b); invariant I3)       rows F4 F5 Q3
# 3. the four non-`ok` states are FOUR DIFFERENT SENTENCES,
#    and `ok`-with-nothing is a FIFTH                         rows F9 F10 F11 Q2
#
# ============================================================================
# THE UNION IS THIS ITEM'S SHARPEST TRAP, AND IT IS MEASURED
# ============================================================================
# Driven against the landed seam on this binary, 2026-09-03:
#   an all-`dims=0` device  -> devices {} absent {{@m.x1.m9 id} {@m.x1.m9 vth}}
#                              nonfinite {} complete 0 state ok
#   a binary NaN/Inf device -> devices {} absent {}
#                              nonfinite {{@m.x1.m8 id nan} {@m.x1.m8 vth inf}}
#                              complete 0 state ok
# A renderer that walks `dict keys [dict get $ans devices]` prints an EMPTY
# block for a real, named, non-converged device. So the row set is the UNION of
# the rawdev names in all THREE buckets, first-appearance order across
# devices -> absent -> nonfinite. Rows F6 and Q3 are the fence.
#
# ============================================================================
# THE BLOCK FORMAT THIS SUITE LOCKS (goldens, not eyeballing)
# ============================================================================
#   line 1   <inst>:<sch_path trimmed of dots, dots -> slashes, leading />
#            i.e. Q6's already-taken default: M2B:/xdut/xbg/xamp1
#   line 2   op_annot::devpath's OWN string, verbatim — the one a user pastes
#            into ngspice.  OMITTED when it is empty (state no_devpath).
#   line 3   the incompleteness sentence — ONLY in state ok, complete 0, with a
#            non-empty union — or, in every other case, the ONE state sentence.
#   then     per primitive of the union, a sub-header "  <rawdev>", SUPPRESSED
#            only when there is exactly one primitive and its name equals line 2
#   then     "    %-*s : %s", the width being the longest param name in the
#            block capped at 24, RIGHT-TRIMMED so a blank value leaves no
#            trailing space.  Rows are devices pairs first (raw-file order),
#            then nonfinite, then absent.
#            ⚠ THE VALUE IS ENGINEERING NOTATION SINCE ITEM R5 (issue 1341):
#            it goes through `op_annot::eng_or_blank`, the proc that puts the
#            sheet's own annotation on the canvas, so the two surfaces cannot
#            disagree.  Every golden below carries `11.1u`, not `1.11e-05`.
#            Section EN is where that is fenced, including the three things the
#            formatter must NOT swallow: a non-numeric value, a non-finite one,
#            and the window's three existing words.
#   then     the blank-value footnote, ONLY when `absent` is non-empty
#   then     ONE empty separator line.
# Data NEVER becomes a format spec and nothing is subst'ed or eval'ed, so a `%`
# or a `[` in a device path or a parameter name passes through verbatim (H4).
#
# ============================================================================
# BOTH ARMS ARE REAL. A SUITE THAT ONLY EVER RUNS --nogui PASSES WHILE THE
# WINDOW IS BROKEN.
# ============================================================================
# Sections M N H F Q S run on BOTH arms and are the majority of the checks;
# only section W (the widgets) is guarded and self-skips headless. The headless
# arm is therefore NOT a vacuous skip — it proves the file loads, defines its
# procs, constructs nothing, and renders every one of the five seam keys.
#   headless:  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_rdw_window_1245.tcl
#   display :  GUI_GATE=0 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_rdw_window_1245.tcl
# ⚠ Never a bare `./src/xschem --script` (it inherits $DISPLAY, the user's real
# Windows X server) and never a bare `xschem` on PATH (3.4.6, issue 0924).
# full_audit.sh selects by GLOB (:393); this file joins NONE of its three named
# lists and full_audit.sh is NOT edited — row M3 says so. The denominator moves
# 380 -> 381; diff the baseline by NAME AND STATUS, never by count.
#
# ============================================================================
# WHICH ROWS ARE RED BEFORE B3 LANDS
# ============================================================================
# Measured against the unmodified tree (HEAD fdae015b, src/xschem built
# 2026-09-03 12:09): `src/rdw.tcl` does not exist, `::rdw` is not a namespace,
# `grep -c rdw.tcl src/Makefile` is 0, and no menubar carries "Results Display
# Window". Every row that names a rdw:: proc therefore answers NOPROC and every
# row that reads the file answers NOFILE.
#   GREEN BEFORE THE CHANGE — controls, fences and hygiene, NONE of them
#   evidence for B3; each says only that B3 broke nothing:
#     S0    the machinery B3 builds on is live (the seam, the ONE name builder)
#     M3    registration is by glob and full_audit.sh is not edited
#     W0    the synthesised-keystroke mechanism itself works (so W2 cannot pass
#           vacuously by delivering nothing)  [display arm only]
#     S2    HYGIENE, no untitled* created
#   EVERYTHING ELSE IS RED, for exactly one reason each: the namespace, the
#   file, the Makefile lines and the menu entry do not exist yet.
#
# MEASURED BEFORE THE CHANGE, 2026-09-03, both arms, exit 1 both times:
#     --nogui                     29 FAILED (3 passed)
#     dev display :99, openbox    37 FAILED (5 passed)
# The extra eight on the display arm are section W, which the headless arm
# skips; the extra green is W0.
#
# ⚠ EVERY GOLDEN WAS RUN AGAINST A SCRATCH PROTOTYPE of rdw.tcl (the plan's own
# algorithm, outside the repo) BEFORE THIS FILE WAS FINISHED. The prototype
# scores 28 passed / 4 failed headless and 38 passed / 4 failed on :99, and the
# four are exactly the rows a prototype outside the repo CANNOT reach — M1 and
# M2 (they read src/Makefile and src/xschem.tcl), N2 and S1 (they read
# src/rdw.tcl itself). All four were hand-verified against the prototype file
# instead: it sources cleanly into a bare interp and defines rdw::open there,
# and it names none of the forbidden tokens. So a red row here is a statement
# about the tree, not about an unreachable golden.
#
# NINE SABOTAGE VARIANTS WERE RUN AGAINST THAT PROTOTYPE AND EVERY ONE WAS
# CAUGHT (rows beyond the four above):
#   row set built from `devices` alone, not the union   -> F6 Q3
#   the incompleteness line thrown away                 -> H4 F1 F2 F4 F5 F6
#                                                          F7 F8 Q1 Q3 Q4
#   the incompleteness line printed unconditionally     -> F3 F9 F10 F11 Q2
#   nonfinite rendered as a blank, like absent          -> F4 F5 F6 Q3
#   one "Nothing found for this device." for all states -> F9 F10 Q2
#   the pane built -state normal                        -> W2
#   -exportselection 0                                  -> W2b
#   newest dump appended BELOW instead of on top        -> W3 W3b
#   button_state flattened to `normal` for every pair   -> F13 W4
# ⚠ TWO PREDICTIONS THE MEASUREMENT REFUTED, recorded rather than quietly
# dropped: the union sabotage does NOT red F5 (F5's device is present in
# `devices` too, so it never needs the union — F6 and Q3 are the union's only
# fence), and the newest-on-top sabotage does NOT red W1b (its reopen leg only
# asks that the stored dumps came back, not in which order).
#
# ⚠ EVERY GOLDEN BELOW WAS MEASURED, NOT GUESSED, in two ways: the five-key
# answer dicts were driven out of the LANDED seam on this binary (see the union
# block above), and the expected block text was run against a scratch prototype
# of rdw.tcl (the plan's own algorithm, outside the repo) which scores ALL PASS.
# A red row here is a statement about the tree, not about an unreachable golden.

# ============================================================================
# ITEM B2a — THE ROWS ADDED AFTER B3's ADVERSARY FOUND THREE DEFECTS IN B3's OWN
# CODE AND SUITE, AND WHICH OF THEM ARE RED BEFORE B2a LANDS
# ============================================================================
# ⚠ ALL THREE ARE LATENT TODAY. Nothing sets `::rdw::sim` (item B5 is the first
# thing that will), no third-party backend exists, and a `dc` slot needs a raw
# nobody has loaded. So `make` and a green suite prove NOTHING here — every
# behavioural row below was written to RED on the code as B3 shipped it, run
# red, and only then fixed.
#   1282  F14 Q6   a DC sweep, and a THREE-POINT operating point that save.c
#                  itself renames `dc`, rendered as operating points with the
#                  word `dc` nowhere on screen (ruling DD-5, option (a))
#         Q7 Q8    "no such simulator" and "registered with no op_param_set
#                  hook" collapsed into ONE sentence
#   1284  F17      a malformed `devices` value rendered the FIFTH SILENCE — a
#                  statement about the RAW, and false
#         F18      a malformed VALUE, a malformed `absent` bucket and a
#                  malformed `nonfinite` bucket each RAISED out of the pure
#                  renderer (the last two measured while planning B2a and NOT
#                  in the issue)
#         F19      a value-less pair and an empty-string value rendered
#                  byte-identically to an absent column, and inherited a
#                  footnote that was false about them
#         F20      a newline in a value made one pair into two lines, the
#                  second unindented and untagged
#
# ⚠ THREE ROWS BELOW ARE **GREEN BEFORE B2a**, AND SAYING SO IS THE POINT.
# Issue 1283 is filed against THIS SUITE, which was ALL PASS 32/42 with eight
# of eight sabotage variants caught. These are the gaps BEHIND that number, and
# each one's red-before proof is a SABOTAGE RUN, never the shipped tree:
#   Q1b  REWRITTEN. It was titled "newest first" and pushed exactly ONE block,
#        then asserted it was at index 0 — true under either ordering. Reversing
#        `rdw::_insert_index` to `end` passed ALL 32 headless checks and red
#        only W3/W3b on `:99`, so "newest dump on top" had NO HEADLESS WITNESS.
#   F16  the union's cross-bucket order, which rdw.tcl's own comment promises
#        and no row held: reversing `rdw::_rowdevs` passed all 32 headless AND
#        all 42 display checks.
#   Q9   the inert-button message: making `rdw::status` a no-op passed the full
#        32-check headless run, because only W4b — inside the Tk-guarded
#        section — asserted it.
# A green count is a statement about the FENCE, not about the code. That is now
# three items old on this branch, and this block is where it is written down.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- locations (cwd-independent) --------------------------------------------
set here [file normalize [file dirname [info script]]]      ;# tests/headless
set repo [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch rdw_window]
set RW_AUDIT [file join $here full_audit.sh]
set RW_MK    [file join $repo src Makefile]
set RW_MKIN  [file join $repo src Makefile.in]
set RW_XTCL  [file join $repo src xschem.tcl]
## The file under test. Kept in ONE variable so the RED agent's prototype run
## can point the structural rows at a scratch copy; the shipped value is the
## tree's own.
set RW_FILE  [file join $repo src rdw.tcl]

## Anything this session might be tempted to write goes to the scratch dir.
set ::netlist_dir $scratch

## ⚠ THE SUITE STATES THE PRECISION IT MEASURES AT -- ISSUE 1345.  Sixteen
## goldens in this file spell out engineered numbers (11.1u, 1m, 1f, 12u), and
## `set_ne ev_precision 4` (src/xschem.tcl:18540) is only a DEFAULT: a
## ~/.xschem/xschemrc carrying `set ev_precision 2` reds ELEVEN rows -- F1 F3
## F8 F14 F15 F19 Q1 Q6 K8 EN1 EN2 -- with nothing whatever wrong in the tree
## (MEASURED with `--preinit 'set ev_precision 2'`; at 6 it was EN6 alone).
## Inheriting the reader's own preference to check goldens about a formatter
## that HONOURS that preference is the fragility item R5's adversary found, so
## the suite pins it and puts it back.  Row EN6, whose subject IS the
## preference, drives 4 and 6 itself and asserts neither is the shipped value.
set RW_EVP_SAVE [expr {[info exists ::ev_precision] ? $::ev_precision : {NOVAR}}]
set ::ev_precision 4

## Taken BEFORE anything below can write a file (hygiene row S2).
set S2_ROOT0 [lsort [glob -nocomplain -directory $repo -tails untitled*]]

# ============================================================================
# THE ANSWER DISCIPLINE — AN ABSENT WINDOW MUST NEVER SATISFY A GOLDEN
# ============================================================================
# Copied from rs_ans/rs_body (tests/headless/test_rdw_seam_1245.tcl:150-230),
# themselves from dc_ans (test_annot_declutter_1244.tcl:227). Two rules this
# batch has already paid for:
#   * a row must be able to FIRE in the RED state. A bare call to a proc that
#     does not exist raises, and a raise at global level under --pipe stops
#     Tcl_AppInit DEAD — the file dies mid-run with `ok` lines and NO verdict
#     (item A2's lesson 6). Every call below goes through a wrapper.
#   * "invalid command name ..." must not be able to satisfy a row expecting
#     the empty string.
proc rw_nocomment {t} {
  set out {}
  foreach l [split $t "\n"] { if {[regexp {^\s*#} $l]} continue ; lappend out $l }
  return [join $out "\n"]
}
proc rw_body {cmd} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {info body $cmd} b]} { return "RAISED:$b" }
  return [rw_nocomment $b]
}
proc rw_count {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}
proc rw_has {hay needle} { return [expr {[string first $needle $hay] >= 0 ? 1 : 0}] }
proc rw_slurp {path} {
  if {![file isfile $path]} { return {} }
  set fd [open $path r] ; set d [read $fd] ; close $fd ; return $d
}
## Call any proc without letting it abort the suite.
proc rw_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
## A widget/Tk expression that must not abort the suite either.
proc rw_w {args} {
  set rc [catch {uplevel #0 $args} r]
  if {$rc} { return "ERR:$r" }
  return $r
}
proc rw_bad {v} { return [expr {$v eq {NOPROC} || [string match {RAISED:*} $v]
                                || [string match {ERR:*} $v] ? 1 : 0}] }
## The block, and the paste shape, for one answer+context. ONE door, so a row
## that reds says which half is missing.
proc rw_block {ans ctx} { return [rw_ans ::rdw::format_answer $ans $ctx] }
proc rw_text  {ans ctx} {
  set b [rw_block $ans $ctx]
  if {[rw_bad $b]} { return $b }
  return [rw_ans ::rdw::block_text $b]
}
## Join golden lines. `{}` is an empty line; the block's own trailing separator
## makes the text end in a newline.
proc rw_lines {args} { return [join $args "\n"] }
## Just the tags of a block, in order — the shape row F12 and the tag rows use.
proc rw_tags {ans ctx} {
  set b [rw_block $ans $ctx]
  if {[rw_bad $b]} { return $b }
  set out {} ; foreach e $b { lappend out [lindex $e 0] } ; return $out
}

# ============================================================================
# THE SEVEN SENTENCES — SPELLED ONCE, ASSERTED EVERYWHERE
# ============================================================================
# All user-visible prose, all on rule debt 1245_B3_window_wording. They are
# literals here on purpose: this suite is where the wording is locked, and a
# drift of one character is a change to what a designer reads, not a typo.
set RW_INC  {Not a complete list: these are the operating-point columns this run saved for this device, not everything the device has.}
set RW_ABSN {A blank value means the raw names that column but the simulator did not compute it.}
set RW_NF   {(did not converge)}
set RW_NORAW    {No simulation results are loaded. Run a simulation, or load a raw file, then ask again.}
set RW_NOTANNOT {Operating-point results are loaded but nothing has been published from them yet. Annotate them first (Waves > Op Annotate, or key 6), then ask again.}
proc RW_OKEMPTY   {dp}   { return "This run's raw holds no operating-point columns for $dp. Only parameters the deck explicitly saved appear here." }
proc RW_NODEVPATH {inst} { return "$inst has no operating-point descriptor, so there is no device path to ask about. A PDK registers one with op_annot::register." }
proc RW_NOTOP     {sty}  { return "The loaded results are a $sty analysis, not an operating point. Nothing was read from them: load the operating-point results and ask again. (An OP+TRAN run writes both to one file, and reading the transient makes it the current one.)" }

# ============================================================================
# FIVE MORE SENTENCES, ALL ITEM B2a's, ALL ON THE SAME RULE DEBT
# ============================================================================
# ⚠ RW_ANALYSIS IS NOT DD-5's QUOTED SPECIMEN, AND THE MEASUREMENT THAT MOVED
# IT IS save.c's OWN. Ruling DD-5 proposes "these numbers come from the `dc`
# analysis at its first point, not from a standalone operating point". That
# asserts something FALSE for a case save.c creates itself: save.c:1073 and
# :1120 both rewrite a MULTI-POINT `Operating Point` plot's sim_type to `dc`,
# so a user who ran nothing but an operating point can be shown a sentence
# telling them they ran a sweep. MEASURED on this binary: a three-point
# `Plotname: Operating Point` raw answers `xschem raw sim_type` = dc (row Q6).
# DD-5's DECISION — render it, and name the analysis — is NOT refuted and is
# implemented; only its specimen wording is. The sentence below names what the
# LOADED RESULTS CALL THEMSELVES rather than what the user ran, which is true
# in both cases and asserts nothing stronger. The exact wording is on the owed
# ledger as a rule debt for the user.
proc RW_ANALYSIS {sty} { return "These numbers come from the first point of results xschem reports as a $sty analysis, not as a standalone operating point. A $sty sweep's first point is one sweep step, and xschem also reports a multi-point operating point as $sty." }

## Issue 1284: a backend's answer dict is not trusted input, it is whatever a
## backend hands over. A malformed one must not fall into the FIFTH SILENCE,
## which is a statement about the RAW and would be false — the run may have
## saved plenty; it is the answer that could not be read. So it gets its own
## sentence, and that sentence names the backend, because the remedy is there.
proc RW_FLAW {sim} { return "The $sim operating-point reader answered in a shape this window could not read, so nothing is shown for this device. This is a fault in that reader's answer, not a statement about the run." }

## Issue 1282 part 2: "not registered" and "registered but declaring no
## op_param_set hook" are DIFFERENT FACTS WITH DIFFERENT REMEDIES, and this
## feature's whole obligation 3 is that different silences get different
## sentences. ase::backend_hook already mints two distinct errors (ase.tcl:550
## "unknown simulator" and :553 "unknown hook", both re-read on this tree); the
## window collapsed them into one.
proc RW_NOSIM    {s} { return "No simulator named $s is registered, so there is nothing to ask for this device. Check the name, or register a backend for it with ase::register_backend." }
proc RW_NOREADER {s} { return "Simulator $s is registered but declares no operating-point reader - the op_param_set hook - so this window has nothing to show for it. A backend adds that hook to publish operating-point columns." }

## Issue 1284 (c) and section 3. A value-less pair and an empty-string value
## both rendered BYTE-IDENTICALLY to an absent column, so the one honest
## distinction the renderer makes — "the raw names this column but nothing was
## computed" — was lost, and the per-block blank footnote was then FALSE about
## them. Words, in the same family as `(did not converge)`, keep the blank
## glyph meaning exactly one thing.
set RW_NOVAL {(no value reported)}

# ============================================================================
# THE FIXTURE MINTERS — COPIED VERBATIM FROM THE SEAM'S SUITE
# ============================================================================
# rs_mkraw / rs_mkraw_bin / rs_annot, tests/headless/test_rdw_seam_1245.tcl:265,
# :302 and :325, renamed. NOTHING in the builders is changed; B3 adds only the
# renderer-shaped FIXTURES the seam suite had no reason to write.
#
# ⚠ NO SIMULATOR IS NEEDED OR WANTED. A suite that needs a simulator is a suite
# that will rot; every number below is a byte this file wrote.
## ⚠ THE OPTIONAL POINT COUNT IS ITEM B2a's, AND IT IS NOT A CONVENIENCE.
## src/save.c:1073 and :1120 both carry
##   if(raw->npoints[...] > 1 && !strcmp(sim_type, "op")) sim_type = "dc";
## so a MULTI-POINT `Operating Point` plot is renamed `dc` BY THE READER, and
## row Q6 needs a raw that reproduces it. Every existing call passes no count
## and still writes a one-point plot, byte for byte as before.
proc rw_mkraw {path plots {npoints 1}} {
  set f [open $path w]
  puts -nonewline $f "Title: B3 rdw window fixture\nDate: Mon Jan 1 00:00:00 2026\n"
  foreach spec $plots {
    set pname [lindex $spec 0] ; set pairs [lindex $spec 1] ; set types [lindex $spec 2]
    puts -nonewline $f "Plotname: $pname\nFlags: real\n"
    puts -nonewline $f "No. Variables: [expr {[llength $pairs]/2}]\nNo. Points: $npoints\nVariables:\n"
    set k 0
    foreach {v val} $pairs {
      set ty [lindex $types $k]
      if {$ty eq {}} { set ty voltage }
      puts -nonewline $f "\t$k\t$v\t$ty\n" ; incr k
    }
    puts -nonewline $f "Values:\n"
    for {set pt 0} {$pt < $npoints} {incr pt} {
      set k 0
      foreach {v val} $pairs {
        if {$k == 0} { puts -nonewline $f "$pt\t$val\n" } else { puts -nonewline $f "\t$val\n" }
        incr k
      }
    }
  }
  close $f
}
## ⚠ THE BINARY MINTER IS NOT A CONVENIENCE — IT IS THE ONLY FIXTURE THAT CAN
## CARRY A NON-FINITE. src/save.c's fast my_atof() path never parsed the words
## `nan`/`inf`, so an ASCII raw carrying either reads back as a confident 0 and
## the defect is INVISIBLE: the seam's own suite was green at 37/37 with a seam
## that returned `nan` as a VALUE. Row Q3 needs this one.
proc rw_mkraw_bin {path pairs types} {
  set f [open $path w]
  fconfigure $f -translation binary
  puts -nonewline $f "Title: B3 rdw window binary fixture\nDate: Mon Jan 1 00:00:00 2026\n"
  puts -nonewline $f "Plotname: Operating Point\nFlags: real\n"
  puts -nonewline $f "No. Variables: [expr {[llength $pairs]/2}]\nNo. Points: 1\nVariables:\n"
  set k 0
  foreach {v val} $pairs {
    set ty [lindex $types $k]
    if {$ty eq {}} { set ty voltage }
    puts -nonewline $f "\t$k\t$v\t$ty\n" ; incr k
  }
  puts -nonewline $f "Binary:\n"
  foreach {v val} $pairs {
    switch -exact -- $val {
      NAN     { puts -nonewline $f [binary format H* 000000000000f87f] }
      INF     { puts -nonewline $f [binary format H* 000000000000f07f] }
      default { puts -nonewline $f [binary format d $val] }
    }
  }
  close $f
}
proc rw_annot {f} {
  catch {xschem raw clear}
  catch {xschem annotate_op $f 0}
  catch {update idletasks}
}

# ============================================================================
# THE FIXTURES
# ============================================================================
# ⚠ EVERY ANSWER DICT BELOW WAS DRIVEN OUT OF THE LANDED SEAM ON THIS BINARY,
# 2026-09-03, against these very raws — they are transcripts, not inventions.
# The six F_SIX values round-trip byte-identically through the raw reader.
set F_SIX {
  v(in)              1.5
  i(@m.x1.m1[id])    1.11e-05
  i(@m.x1.m1[is])    0
  v(@m.x1.m1[vth])   0.75
  @m.x1.m1[gm]       0.001
  v(@m.x1.m1[vds])   1.25
  v(@m.x1.m1[vgs])   0.5
}
set T_SIX {voltage current current voltage notype voltage voltage}
set SIX_PAIRS {{id 1.11e-05} {is 0} {vth 0.75} {gm 0.001} {vds 1.25} {vgs 0.5}}

## THE ALL-ABSENT DEVICE: every column dims=0. Measured answer `devices {}`
## with a populated `absent`, in state ok — the union trap's first half.
set F_ALLABS {v(in) 1.5 i(@m.x1.m9[id]) 0 v(@m.x1.m9[vth]) 0}
set T_ALLABS {voltage {current dims=0} {voltage dims=0}}

## THE ALL-NON-FINITE DEVICE, binary because it must be. Measured answer
## `devices {}` with a populated `nonfinite` — the union trap's second half.
set F_ALLNF {v(in) 1.5 i(@m.x1.m8[id]) NAN v(@m.x1.m8[vth]) INF}
set T_ALLNF {voltage current voltage}

## THE MIXED DEVICE: a NaN, two finites and a genuinely computed zero on one
## device. The zero is not padding — a cut-off transistor has id = 0 and that
## is a measurement (issue 1259's other half, 1272's acceptance row 3).
set F_MIX {v(in) 1.5 i(@m.x1.m1[id]) NAN v(@m.x1.m1[vth]) 0.75 @m.x1.m1[gm] 0.001 i(@m.x1.m1[is]) 0}
set T_MIX {voltage current voltage notype current}

## RULING D-3, five primitives from one XR1, three element letters, two depths,
## and TWO of them publishing a parameter spelled `i` — the measurement that
## refuted the flat {param value} shape. @r.xr10... is the decoy.
set F_XR1 {
  v(net1)                1.5
  i(@r.xr1.x0.rend1[i])  1e-06
  i(@r.xr1.x0.rend2[i])  2e-06
  i(@c.xr1.x0.xc0.c0[c]) 1e-15
  i(@c.xr1.x0.xc1.c0[c]) 2e-15
  i(@b.xr1.x0.brbody[i]) 4e-06
  i(@r.xr10.x0.rend1[i]) 8e-06
}
set F_TRAN {time 0.0 v(in) 1.5 v(out) 0.5 i(v1) -0.001}

set R_SIX    [file join $scratch six.raw]
set R_ALLABS [file join $scratch allabs.raw]
set R_ALLNF  [file join $scratch allnf.raw]
set R_MIX    [file join $scratch mix.raw]
set R_XR1    [file join $scratch xr1.raw]
set R_TRAN   [file join $scratch tran.raw]
set R_TWO    [file join $scratch two.raw]

rw_mkraw     $R_SIX    [list [list {Operating Point} $F_SIX $T_SIX]]
rw_mkraw     $R_ALLABS [list [list {Operating Point} $F_ALLABS $T_ALLABS]]
rw_mkraw_bin $R_ALLNF  $F_ALLNF $T_ALLNF
rw_mkraw_bin $R_MIX    $F_MIX   $T_MIX
rw_mkraw     $R_XR1    [list [list {Operating Point} $F_XR1 {}]]
rw_mkraw     $R_TRAN   [list [list {Transient Analysis} $F_TRAN {}]]
## Q10's file: ONE raw holding an Operating Point plot and THEN a Transient
## Analysis plot, which is what an ordinary OP+TRAN run writes.
rw_mkraw     $R_TWO    [list [list {Operating Point} $F_SIX $T_SIX] \
                             [list {Transient Analysis} $F_TRAN {}]]

## A context dict is {header devpath simtype instname sim}. Spelled through one
## helper so twenty rows cannot drift into twenty shapes.
##
## ⚠ THE FIFTH KEY IS ITEM B2a's (issue 1284). A malformed answer gets a
## sentence that NAMES THE BACKEND that produced it, so the renderer has to be
## told which one that was; `rdw::dump_devpath` sets it for the live path and
## rows F17/F18 pass it explicitly. Defaulting it keeps every existing caller's
## arity, and no row below asserts the contents of a ctx, so nothing moves.
proc rw_ctx {hdr dp {sty op} {inst M1} {sim ngspice}} {
  return [dict create header $hdr devpath $dp simtype $sty instname $inst \
                      sim $sim]
}
## An answer dict, five keys, in the seam's own order.
proc rw_ansd {devices absent nonfinite complete state} {
  return [dict create devices $devices absent $absent nonfinite $nonfinite \
                      complete $complete state $state]
}

set live_tk [expr {[info exists ::has_x] && [info commands winfo] ne {}}]

# ============================================================================
# SECTION S — THE CONTROL, THE STRUCTURAL FENCES AND HYGIENE
# ============================================================================
# S0 is the ONLY row here that is green before B3, and it is evidence for
# nothing but "the seam and the one name builder are still live".

check {S0 CONTROL the machinery B3 builds on is live: the ONE dispatch, the ONE name builder, and the seam hook this window renders} \
  [list [expr {[llength [info commands ::ase::backend_hook]] ? 1 : 0}] \
        [expr {[llength [info commands ::op_annot::devpath]] ? 1 : 0}] \
        [expr {[llength [info commands ::ase::backend_names]] ? 1 : 0}] \
        [expr {![catch {ase::backend_hook ngspice op_param_set} p] && [llength [info commands $p]] ? 1 : 0}]] \
  {1 1 1 1}

# ============================================================================
# SECTION M — THE BUILD RECEIPT, THE MENU, THE REGISTRATION
# ============================================================================
# ⚠ ISSUE 0424 IS LIVE FOR THIS ITEM. src/Makefile and src/config.h are
# GENERATED, gitignored and have NO self-regeneration rule, so a tracked-correct
# Makefile.in sits beside a stale generated Makefile and `make` never notices.
# It is INVISIBLE in-tree (XSCHEM_SHAREDIR resolves to src/) and FATAL once
# installed: 0424 lost op_annot.tcl that way and the installed binary
# SEGFAULTED AT STARTUP with 275 in-tree checks green. M1 asserts the two
# generated lines BY NAME rather than as a count, so "2" cannot be reached by
# two install lines and no uninstall line.
# RED before B3: M1 M2.  GREEN before B3: M3.

set M_MK [rw_slurp $RW_MK]
set M_INST 0 ; set M_RM 0 ; set M_LINES 0
foreach l [split $M_MK "\n"] {
  if {[rw_has $l {install -f rdw.tcl}]} { incr M_INST }
  if {[rw_has $l {rm "$(XSHAREDIR)"/rdw.tcl}]} { incr M_RM }
  if {[rw_has $l {rdw.tcl}]} { incr M_LINES }
}
## ⚠ THE THIRD LEG COUNTS *LINES*, WHICH IS WHAT `grep -c` COUNTS, AND THIS
## ROW USED TO COUNT SUBSTRING OCCURRENCES AND WAS UNSATISFIABLE BY ANY
## CORRECT MAKEFILE. Measured 2026-09-03 on the generated src/Makefile:
##   $(SCCBOX) install -f rdw.tcl  "$(XSHAREDIR)"/rdw.tcl
##   $(SCCBOX) rm "$(XSHAREDIR)"/rdw.tcl
## scconfig's install template names the file on BOTH sides of the copy, so
## every shipped helper appears THREE times as a substring and on TWO lines --
## op_param_lists.tcl (B2's, landed) and results.tcl measure 3 and 2 likewise.
## `grep -c rdw.tcl src/Makefile` -- the receipt CLAUDE.md and the item brief
## both name -- is 2 because grep counts matching LINES. The first two legs
## already pin WHICH two lines, so "2" cannot be reached by two install lines
## and no uninstall line, which is the whole point of asserting by name.
check {M1 the 0424 receipt, by NAME not by count: src/Makefile carries exactly one generated install line for rdw.tcl and exactly one uninstall line, so grep -c is 2 for the right reason} \
  [list $M_INST $M_RM $M_LINES] \
  {1 1 2}

## The Tools entry is found BY LABEL, never by index — every suite in this tree
## that reads the main menubar does the same (test_lib_manager_launch:52,
## test_nh_editor_discover:55, test_create_instance:80), which is why one more
## entry disturbs none of them. ⚠ It must be the MAIN menubar: the ASE session
## window's Tools menu is golded as an exact two-item list by
## tests/headless/test_ase_window.tcl:464, a suite that already carries a
## baseline red where a second is easy to misread.
set M_MKIN [rw_slurp $RW_MKIN]
set M_XTCL [rw_slurp $RW_XTCL]
set M_MENU 0 ; set M_CMD {}
if {$live_tk && [rw_w winfo exists .menubar.tools] eq {1}} {
  set n [rw_w .menubar.tools index end]
  if {![rw_bad $n]} {
    for {set i 0} {$i <= $n} {incr i} {
      if {[rw_w .menubar.tools entrycget $i -label] eq {Results Display Window}} {
        set M_MENU 1 ; set M_CMD [rw_w .menubar.tools entrycget $i -command]
      }
    }
  }
} else {
  ## Under --nogui build_widgets{} never runs (xschem.tcl:19110/:19120 gate it
  ## on has_x), so the menubar cannot be inspected. The SOURCE is asserted
  ## instead, on both arms, and the live widget only where there is one.
  set M_MENU {no-Tk} ; set M_CMD {no-Tk}
}
check {M2 the two src/xschem.tcl edits: rdw.tcl is in Makefile.in's ONE install_shares list, xschem.tcl sources it, and the MAIN menubar Tools menu carries the entry wired to rdw::open} \
  [list [rw_has $M_MKIN {rdw.tcl}] \
        [rw_has $M_XTCL {source $XSCHEM_SHAREDIR/rdw.tcl}] \
        [rw_has $M_XTCL {-label "Results Display Window"}] \
        [rw_has $M_XTCL {rdw::open}] \
        [expr {$live_tk ? $M_MENU : 1}] \
        [expr {$live_tk ? [rw_has $M_CMD {rdw::open}] : 1}]] \
  {1 1 1 1 1 1}

set M_ME  [file rootname [file tail [info script]]]
set M_TXT [rw_slurp $RW_AUDIT]
check {M3 registered by glob, and full_audit.sh is NOT edited: this suite is in none of nogui_tests / logdir_tests / nolog_tests} \
  [list [string match {test_*} $M_ME] \
        [expr {[regexp {mapfile -t files < <\(ls "\$HERE"/test_\*\.tcl \| sort\)} $M_TXT] ? 1 : 0}] \
        [expr {[string first $M_ME $M_TXT] >= 0 ? 1 : 0}]] \
  {1 1 0}

# ============================================================================
# SECTION N — THE NAMESPACE, AND SURVIVING --nogui BY NOT BEING CONSTRUCTED
# ============================================================================
# Acceptance says the window must survive --nogui by CONSTRUCTING NOTHING. The
# 18th bare `source` at xschem.tcl:16749-16815 is UNGUARDED, so a single Tk
# command executed at source time in rdw.tcl aborts startup (issue 0663's
# mechanism, exit 1 with the guard and historically 139 without).
# RED before B3: N1 N2 N3.

## ⚠ `inert` BECAME `button`, BY ITEM B5, AND THE COUNT IS UNCHANGED. This row
## is the fifth golden B5's own deliverable falsifies (S1, K11, W4b and Q9 are
## the others): `rdw::inert` said "the button column is built but not wired yet
## (item B5 wires it)", and B5 wired it. `rdw::button` is the proc that replaced
## it - THE one command all five widgets carry - so the list still names the
## button column's command sink and the section still counts sixteen.
set N_PROCS {}
foreach p {have_tk open close build push render_pane set_list button status
           header sim dump dump_devpath format_answer block_text button_state} {
  lappend N_PROCS [expr {[llength [info procs ::rdw::$p]] ? 1 : 0}]
}
check {N1 the namespace and its sixteen procs exist, and NOTHING has been constructed: .rdw does not exist before the first rdw::open} \
  [list [namespace exists ::rdw] $N_PROCS \
        [expr {$live_tk ? [rw_w winfo exists .rdw] : {no-winfo}}]] \
  [list 1 {1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1} [expr {$live_tk ? 0 : {no-winfo}}]]

## THE NON-BRITTLE PROOF, AND IT RUNS ON BOTH ARMS. A fresh `interp create`
## slave has neither `winfo` nor `xschem` (measured on this binary), so a file
## that executes ANY Tk or any `xschem` command at source time cannot load into
## one. A grep for `toplevel` would be brittle; this is the behaviour itself.
set N2_I [interp create]
set N2_RC [catch {$N2_I eval [list source $RW_FILE]} N2_ERR]
set N2_NS 0 ; set N2_OPEN 0
if {!$N2_RC} {
  catch {set N2_NS   [$N2_I eval {namespace exists ::rdw}]}
  catch {set N2_OPEN [$N2_I eval {llength [info procs ::rdw::open]}]}
}
catch {interp delete $N2_I}
check {N2 src/rdw.tcl sources cleanly into a bare interp that has neither winfo nor xschem, and defines rdw::open there: no Tk and no xschem command runs at source time} \
  [list $N2_RC $N2_NS $N2_OPEN] {0 1 1}

## rdw::open must be safe to CALL headless too — B4 will reach it from a key
## binding, and this suite's own headless arm calls it.
set N3_OPEN [rw_ans ::rdw::open]
set N3_CLOSE [rw_ans ::rdw::close]
check {N3 have_tk answers the arm it is on, and under --nogui rdw::open returns {} and constructs nothing rather than raising} \
  [list [rw_ans ::rdw::have_tk] \
        [expr {$live_tk ? 1 : [expr {$N3_OPEN eq {} ? 1 : 0}]}] \
        [expr {$live_tk ? 1 : [expr {$N3_CLOSE eq {} ? 1 : 0}]}]] \
  [list [expr {$live_tk ? 1 : 0}] 1 1]
if {$live_tk} { rw_ans ::rdw::close }

# ============================================================================
# SECTION H — THE HEADER. SPEC QUESTION Q6's ALREADY-TAKEN DEFAULT.
# ============================================================================
# The user asked for `M2B:/xdut/xbg/xamp1`. THE TREE HAS THREE SPELLINGS AND
# NONE IS THAT ONE, measured on this binary:
#   xschem get sch_path      .xdut.xbg.xamp1.   (leading AND trailing dot)
#   xschem get sim_sch_path  xdut.xbg.xamp1.    (strips every level above the
#                                                raw's load point)
#   the raw's own            @m.x1.x1.xm2.msky130_fd_pr__nfet_01v8
# The default is already taken (spec §5.1 Q6, `look` debt open): mint the
# cadence spelling from sch_path, and put the raw's own path on a second,
# dimmer line, because that is the string a user pastes into ngspice.
# ⚠ AT THE TOP SHEET `sch_path` IS `.` AND THE TRIM YIELDS THE EMPTY STRING.
# The header degenerates to `M1:/` — an edge nobody has ruled, locked here so
# it cannot drift silently.
# RED before B3: H1 H2 H3 H4.

check {H1 the Q6 spelling: sch_path's leading AND trailing dots go, dots become slashes, the path stays rooted, and a % or a [ in a segment passes through verbatim} \
  [list [rw_ans ::rdw::_cadence_path {.xdut.xbg.xamp1.}] \
        [rw_ans ::rdw::_cadence_path {.}] \
        [rw_ans ::rdw::_cadence_path {}] \
        [rw_ans ::rdw::_cadence_path {.a%b.c[d].}] \
        [rw_ans ::rdw::_cadence_path {xdut.xbg.}]] \
  [list /xdut/xbg/xamp1 / / {/a%b/c[d]} /xdut/xbg]

## INVARIANT I1, BEHAVIOURALLY: line 2 is op_annot::devpath's OWN string, byte
## for byte, INCLUDING the empty string for an instance no descriptor claims.
## B3 builds no @-prefixed raw name of its own, ever. Measured consequence of
## building one by hand instead: a bare `xr1.` answers `devices {} state ok`,
## byte-identical to "unknown device" — the wrong-answer-wearing-a-healthy-state
## that returned item B1 [F].
check {H2 rdw::header is {cadence-line devpath-line}: at the top sheet it degenerates to M1:/ and line 2 is BYTE-EQUAL to op_annot::devpath, empty string included} \
  [list [rw_ans ::rdw::header M1] \
        [rw_ans ::rdw::header M2B]] \
  [list [list {M1:/} [rw_ans ::op_annot::devpath M1]] \
        [list {M2B:/} [rw_ans ::op_annot::devpath M2B]]]

## ⚠ WHOLE-LINE `#` COMMENTS ARE STRIPPED FIRST, so a raw name quoted in the
## prose above a proc is prose and not a second builder. A TRAILING `;# ...
## @m.x1.m1 ...` on a CODE line reds this row: say it in a comment line of its
## own, the way this file does.
set H3_B [rw_body ::rdw::header]
set H3_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]
check {H3 STRUCTURAL invariant I1, one name builder: rdw::header calls op_annot::devpath, and rdw.tcl builds no raw device name of its own anywhere - no @m./@r./@c. literal and no i(/v( literal} \
  [list [rw_has $H3_B {op_annot::devpath}] \
        [rw_count $H3_F {@m.}] [rw_count $H3_F {@r.}] [rw_count $H3_F {@c.}] \
        [rw_count $H3_F {i(}] [rw_count $H3_F {v(}]] \
  {1 0 0 0 0 0}

set H4_ANS [rw_ansd [dict create {@m.x%1.m1} [list [list {v%s[x]} {2%3}]]] {} {} 0 ok]
set H4_CTX [rw_ctx {M%1:/a[0]/b} {@m.x%1.m1} op {M%1}]
check {H4 a % and a [ in the device path, the header and a parameter name all render VERBATIM: no data becomes a format spec and nothing is subst'ed or eval'ed} \
  [rw_text $H4_ANS $H4_CTX] \
  [rw_lines {M%1:/a[0]/b} {@m.x%1.m1} $RW_INC {    v%s[x] : 2%3} {}]

# ============================================================================
# SECTION F — THE RENDERER. THE PURE LAYER, DRIVEN WITH HAND-BUILT ANSWERS.
# ============================================================================
# Every answer dict here is a transcript of the landed seam (see the header),
# so a row that reds is a statement about the renderer and never about the
# seam. No Tk, no `xschem`, no raw: these rows run identically on both arms.
# RED before B3: every row in this section.

set F_CTX1 [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1]
set F_ANS1 [rw_ansd [dict create {@m.x1.m1} $SIX_PAIRS] {} {} 0 ok]

check {F1 THE PASTE SHAPE: header, dim devpath, the honesty line, then six aligned rows in raw-file order and one separator - the exact text a user copies into a design-review document} \
  [rw_text $F_ANS1 $F_CTX1] \
  [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
            {    id  : 11.1u} {    is  : 0} {    vth : 0.75} \
            {    gm  : 1m} {    vds : 1.25} {    vgs : 0.5} {}]

check {F2 DD-1's corollary: complete 0 prints the incompleteness sentence, exactly ONCE per block, and it is a `note` line rather than a value row} \
  [list [rw_count [rw_text $F_ANS1 $F_CTX1] $RW_INC] \
        [rw_tags $F_ANS1 $F_CTX1]] \
  [list 1 {hdr dim note {} {} {} {} {} {} {}}]

## ⚠ THIS ROW IS A CONTROL AND MUST NOT BE VACUOUS. `[rw_count NOPROC ...]` is
## 0 too, so the count alone would be GREEN before B3 exists and would prove
## nothing at all. The whole block is asserted instead: the same six rows as F1,
## one line shorter.
set F3_T [rw_text [rw_ansd [dict create {@m.x1.m1} $SIX_PAIRS] {} {} 1 ok] $F_CTX1]
check {F3 CONTROL complete 1 prints NO incompleteness sentence - an unconditional honesty line would be indistinguishable from an honest one and would survive the wildcard ngspice} \
  [list [rw_count $F3_T $RW_INC] $F3_T] \
  [list 0 [rw_lines {M1:/xdut/xbg} {@m.x1.m1} \
                    {    id  : 11.1u} {    is  : 0} {    vth : 0.75} \
                    {    gm  : 1m} {    vds : 1.25} {    vgs : 0.5} {}]]

## OBLIGATION 2. A non-converged operating point is a RESULT a designer wants
## told, not a gap and not a number. Driver default, rule debt
## 1245_B1_nonfinite_render option (b); invariant I3 forbids the raw text.
set F4_ANS [rw_ansd [dict create {@m.x1.m1} {{vth 0.75} {gm 0.001} {is 0}}] \
                    {} {{@m.x1.m1 id nan}} 0 ok]
set F4_T [rw_text $F4_ANS $F_CTX1]
check {F4 a nonfinite column renders `(did not converge)` and the block contains neither `nan` nor `inf` anywhere; the finite rows and the genuine zero are untouched} \
  [list $F4_T [rw_count $F4_T {nan}] [rw_count $F4_T {inf}]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    vth : 0.75} {    gm  : 1m} {    is  : 0} \
                  {    id  : (did not converge)} {}] 0 0]

## INVARIANT I3 for the other bucket: a missing vector renders BLANK — not 0,
## not NaN, not the previous run's number. A bare blank after a colon reads as
## a bug, so the block carries ONE footnote saying what a blank means, and the
## footnote appears EXACTLY when `absent` is non-empty.
set F5_ANS [rw_ansd [dict create {@m.x1.m1} {{gm 0.001}}] \
                    {{@m.x1.m1 ib}} {{@m.x1.m1 vth nan}} 0 ok]
check {F5 an absent column renders a BLANK value with no trailing space, is textually distinct from a nonfinite one, and the blank-value footnote rides exactly once - while F1/F4, with no absent, carry none} \
  [list [rw_text $F5_ANS $F_CTX1] \
        [rw_count [rw_text $F_ANS1 $F_CTX1] $RW_ABSN] \
        [rw_count $F4_T $RW_ABSN]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    gm  : 1m} {    vth : (did not converge)} {    ib  :} \
                  $RW_ABSN {}] 0 0]

## THE UNION RULE. Both halves measured against the landed seam: an all-dims=0
## device and a binary NaN device BOTH answer `devices {}` in state ok. A
## renderer that walks `dict keys [dict get $ans devices]` prints an EMPTY
## block for a real, named, non-converged device.
set F6_ABS [rw_ansd {} {{@m.x1.m9 id} {@m.x1.m9 vth}} {} 0 ok]
set F6_NF  [rw_ansd {} {} {{@m.x1.m8 id nan} {@m.x1.m8 vth inf}} 0 ok]
check {F6 THE UNION: a device present ONLY in `absent`, and a device present ONLY in `nonfinite`, each still get a full row set - the empty `devices` dict is not an empty answer} \
  [list [rw_text $F6_ABS [rw_ctx {M9:/} {@m.x1.m9} op M9]] \
        [rw_text $F6_NF  [rw_ctx {M8:/} {@m.x1.m8} op M8]]] \
  [list [rw_lines {M9:/} {@m.x1.m9} $RW_INC {    id  :} {    vth :} $RW_ABSN {}] \
        [rw_lines {M8:/} {@m.x1.m8} $RW_INC \
                  {    id  : (did not converge)} {    vth : (did not converge)} {}]]

## RULING D-3. Two of these five primitives BOTH publish a parameter spelled
## `i`; without the per-primitive sub-header the two numbers cannot be told
## apart, which is exactly why the seam's return shape was amended from a flat
## {param value} list to the five-key dict.
set F7_ANS [rw_ansd [dict create {@r.xr1.x0.rend1} {{i 1e-06}} \
                                 {@r.xr1.x0.rend2} {{i 2e-06}} \
                                 {@c.xr1.x0.xc0.c0} {{c 1e-15}} \
                                 {@c.xr1.x0.xc1.c0} {{c 2e-15}} \
                                 {@b.xr1.x0.brbody} {{i 4e-06}}] {} {} 0 ok]
check {F7 D-3: five primitives from one XR1 print five sub-headers in raw-file order, and the two columns both spelled `i` are attributed to DIFFERENT primitives} \
  [rw_text $F7_ANS [rw_ctx {XR1:/} {@r.xr1} op XR1]] \
  [rw_lines {XR1:/} {@r.xr1} $RW_INC \
            {  @r.xr1.x0.rend1} {    i : 1u} \
            {  @r.xr1.x0.rend2} {    i : 2u} \
            {  @c.xr1.x0.xc0.c0} {    c : 1f} \
            {  @c.xr1.x0.xc1.c0} {    c : 2f} \
            {  @b.xr1.x0.brbody} {    i : 4u} {}]

check {F8 the sub-header is suppressed ONLY when there is exactly one primitive whose name equals line 2; one primitive under a BROADER request still names itself} \
  [list [rw_count [rw_text $F_ANS1 $F_CTX1] {  @m.x1.m1}] \
        [rw_text [rw_ansd [dict create {@m.x1.m1} {{id 1.11e-05}}] {} {} 0 ok] \
                 [rw_ctx {M1:/} {@m.x1} op M1]]] \
  [list 0 [rw_lines {M1:/} {@m.x1} $RW_INC {  @m.x1.m1} {    id : 11.1u} {}]]

## THE FIFTH SILENCE. state ok with nothing in any bucket is the COMMON case
## under measured rule R1 (gm/gds/vth exist only if the deck saved them;
## `save all` does not include them), and it is neither an error nor a
## rendering bug. Saying nothing at all would be indistinguishable from one.
check {F9 state ok with an EMPTY union prints the fifth sentence, naming the devpath, and NOT the incompleteness line - which would say the same thing twice} \
  [rw_text [rw_ansd {} {} {} 0 ok] $F_CTX1] \
  [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_OKEMPTY {@m.x1.m1}] {}]

## OBLIGATION 3. The four non-ok states otherwise all arrive as the same empty
## list. `not_op` in particular means the user is looking at a TRANSIENT — say
## so and say what to do; none of the five may say "nothing found".
set F10_NORAW  [rw_text [rw_ansd {} {} {} 0 no_raw]        $F_CTX1]
set F10_NOTOP  [rw_text [rw_ansd {} {} {} 0 not_op]        [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} tran M1]]
set F10_NOTANN [rw_text [rw_ansd {} {} {} 0 not_annotated] $F_CTX1]
set F10_NODP   [rw_text [rw_ansd {} {} {} 0 no_devpath]    [rw_ctx {M1:/xdut/xbg} {} op M1]]
set F10_OKE    [rw_text [rw_ansd {} {} {} 0 ok]            $F_CTX1]
set F10_ALL [list $F10_NORAW $F10_NOTOP $F10_NOTANN $F10_NODP $F10_OKE]
check {F10 FIVE pairwise-distinct sentences: not_op names the loaded analysis AND the remedy, not_annotated names the annotate step, no_devpath explains the missing descriptor, and none of the five says "nothing found"} \
  [list $F10_NORAW $F10_NOTOP $F10_NOTANN $F10_NODP \
        [llength [lsort -unique $F10_ALL]] \
        [rw_count [join $F10_ALL "\n"] {nothing found}]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_NORAW {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_NOTOP tran] {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_NOTANNOT {}] \
        [rw_lines {M1:/xdut/xbg} [RW_NODEVPATH M1] {}] \
        5 0]

## ⚠ NON-VACUITY LEG, same trap as F3: two zero counts over five NOPROC strings
## are also {0 0}. The third leg says the five blocks were really rendered.
check {F11 no non-ok block carries the incompleteness sentence or the blank-value footnote - "this is what the run saved" under "no results are loaded" is nonsense} \
  [list [rw_count [join $F10_ALL "\n"] $RW_INC] \
        [rw_count [join $F10_ALL "\n"] $RW_ABSN] \
        [expr {[rw_bad $F10_NORAW] || [rw_bad $F10_NOTOP] || [rw_bad $F10_NOTANN]
               || [rw_bad $F10_NODP] || [rw_bad $F10_OKE] ? {NOT-RENDERED} : 1}]] \
  {0 0 1}

set F12_B [rw_body ::rdw::format_answer]
check {F12 a genuinely computed 0 renders as 0 and not as a blank (absence is not zero); and STRUCTURAL, format_answer touches no xschem, no winfo and no widget} \
  [list [rw_has [rw_text $F_ANS1 $F_CTX1] {    is  : 0}] \
        [rw_count $F12_B {xschem }] [rw_count $F12_B {winfo}] [rw_count $F12_B {.rdw}]] \
  {1 0 0 0}

check {F13 the button table IS spec 4.2 B7, as data: Add greyed on the annotation list, Delete greyed on `all`, everything else normal, and the default list is `annotation`} \
  [list [rw_ans ::rdw::button_state up annotation] [rw_ans ::rdw::button_state down annotation] \
        [rw_ans ::rdw::button_state delete annotation] [rw_ans ::rdw::button_state add annotation] \
        [rw_ans ::rdw::button_state save annotation] \
        [rw_ans ::rdw::button_state delete summary] [rw_ans ::rdw::button_state add summary] \
        [rw_ans ::rdw::button_state delete all] [rw_ans ::rdw::button_state add all] \
        [rw_ans ::rdw::button_state save all] \
        [expr {[info exists ::rdw::listkind] ? $::rdw::listkind : {NOVAR}}]] \
  {normal normal normal disabled normal normal normal disabled normal normal annotation}

# ============================================================================
# F14-F15 — THE SIXTH STATE: `ok` WITH NUMBERS, FROM AN ANALYSIS THAT IS NOT AN
# OPERATING POINT (issue 1282 part 1, ruling DD-5)
# ============================================================================
# The seam's allow-list is `{op dc}`, not `{op}` — ase.tcl:8803, copied
# DELIBERATELY from update_op()'s own guard in src/save.c so that the window
# and the on-sheet annotation agree about what counts as an operating point.
# So a raw whose current slot is a DC transfer characteristic answers `ok` with
# real point-0 numbers, and B3's window presented them as an operating point:
# MEASURED, sim_type = dc, state = ok, and the block said "operating-point"
# twice and `dc` ZERO TIMES. A DC sweep's point 0 is the first step of the
# sweep, not the circuit's quiescent point, and pasting that block into a
# design-review document under a heading that says "operating point" is exactly
# the plausible-wrong-number failure invariant I3 and ruling D5-1 exist to
# prevent. `ctx` already carried `simtype` and `_state_sentence` already read
# it; only the `not_op` arm used it.
#
# RULING DD-5, option (a) of the three issue 1282 lists: KEEP RENDERING IT AND
# NAME THE ANALYSIS. Option (c), refusing `dc`, is forbidden — it would
# contradict the allow-list B1 copied from the C on purpose, and it would red
# row G3b of tests/headless/test_rdw_seam_1245.tcl, a cross-language fence that
# counts save.c's own op/dc strcmps.
#
# ⚠ F15 IS THE CONTROL AND IT IS NOT OPTIONAL. The gate is
# `$sty ne {} && $sty ne "op"`: the empty half matters because a hand-built ctx
# and a failed `xschem raw sim_type` both produce {}, and an unconditional
# sentence would be indistinguishable from an honest one — the same trap F3
# carries for the incompleteness line. F15 asserts the WHOLE BLOCK, not a count
# of zero, because a count over a NOPROC string is zero too.
# RED BEFORE B2a: F14 and Q6. GREEN BEFORE B2a: F15.
set F14_CTX [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} dc M1]
set F14_T [rw_text $F_ANS1 $F14_CTX]
check {F14 a state-ok block whose analysis is NOT an operating point carries one extra sentence naming it, between the device path and the incompleteness line, as a `note` and not a value row - so the word `dc` is on screen instead of nowhere} \
  [list $F14_T [rw_tags $F_ANS1 $F14_CTX] \
        [expr {[rw_count $F14_T {dc}] >= 1 ? 1 : 0}]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_ANALYSIS dc] $RW_INC \
                  {    id  : 11.1u} {    is  : 0} {    vth : 0.75} \
                  {    gm  : 1m} {    vds : 1.25} {    vgs : 0.5} {}] \
        {hdr dim note note {} {} {} {} {} {} {}} 1]

set F15_OPBLOCK [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                          {    id  : 11.1u} {    is  : 0} {    vth : 0.75} \
                          {    gm  : 1m} {    vds : 1.25} {    vgs : 0.5} {}]
check {F15 CONTROL a state-ok block whose simtype IS `op`, and one whose simtype is EMPTY, carry no analysis sentence at all - asserted as the whole block, because a bare count of zero is also zero over a string that was never rendered} \
  [list [rw_text $F_ANS1 $F_CTX1] \
        [rw_text $F_ANS1 [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} {} M1]]] \
  [list $F15_OPBLOCK $F15_OPBLOCK]

# ============================================================================
# F16 — THE UNION'S ORDER, AND THE COLUMN ORDER INSIDE ONE DEVICE
# (issue 1283 gap B — A FENCE THAT WAS MISSING, NOT A DEFECT)
# ============================================================================
# ⚠ THIS ROW IS GREEN BEFORE B2a AND PROVES NOTHING ABOUT TODAY'S CODE. It is
# here because src/rdw.tcl's own comment promises the row set is built in
# "first-appearance order across devices -> absent -> nonfinite" and NO ROW HELD
# THAT PROMISE: reversing `rdw::_rowdevs` so the absent/nonfinite devices come
# first passed ALL 32 headless AND ALL 42 display checks. Its red-before proof
# is therefore the SABOTAGE, not the shipped tree — B1's lesson one item on: a
# green count is a statement about the FENCE.
#
# The second half was measured while filing 1283 and is also unasserted
# anywhere: COLUMN ORDER WITHIN A DEVICE IS BUCKET ORDER, NOT RAW-FILE ORDER —
# measured values, then non-finite, then absent. That groups the blanks
# together, which reads better, but it is stated nowhere, so a later crew
# cannot tell the design from the accident. One mixed answer closes both halves:
# three devices, one in each bucket, and one device carrying all three kinds.
set F16_ANS [rw_ansd [dict create {@m.x1.mA} {{id 1} {gm 2}}] \
                     {{@m.x1.mB ib} {@m.x1.mA ib}} \
                     {{@m.x1.mC gds nan} {@m.x1.mA vth nan}} 0 ok]
set F16_CTX [rw_ctx {MX:/} {@m.x1} op MX]
check {F16 the union is built devices -> absent -> nonfinite in first-appearance order, and within ONE device the columns are the measured ones, then the non-finite ones, then the absent ones - the promise rdw.tcl's own comment makes and no row held} \
  [list [rw_ans ::rdw::_rowdevs $F16_ANS] [rw_text $F16_ANS $F16_CTX]] \
  [list {@m.x1.mA @m.x1.mB @m.x1.mC} \
        [rw_lines {MX:/} {@m.x1} $RW_INC \
                  {  @m.x1.mA} {    id  : 1} {    gm  : 2} \
                  {    vth : (did not converge)} {    ib  :} \
                  {  @m.x1.mB} {    ib  :} \
                  {  @m.x1.mC} {    gds : (did not converge)} \
                  $RW_ABSN {}]]

# ============================================================================
# F17-F20 — A BACKEND'S ANSWER DICT MUST NOT MAKE THIS WINDOW LIE, BLANK OR
# RAISE (issue 1284)
# ============================================================================
# ⚠ THIS IS THE ONE OF THE NINE THE USER'S OWN FUTURE DEPENDS ON. It is
# UNREACHABLE through the shipped ngspice backend — that backend builds
# `devices` with `dict set` and gates every value through
# `op_annot::raw_class`'s `string is double -strict` — and REACHABLE by any
# third-party backend the D-5 seam exists to admit. Ruling D-5 records that the
# user IS BUILDING A CUSTOM NGSPICE that will supply a wildcard operating-point
# save, and the seam exists precisely to admit it, so the first backend to
# exercise these shapes will be the user's own. `rdw::format_answer` treated the
# five-key dict as TRUSTED INPUT; it is whatever a backend hands it.
#
# FOUR SHAPES MEASURED ON THIS BINARY, plus two more found while planning:
#   (a) F17  a malformed `devices` value -> `_rowdevs`'s dict-level catch
#            swallows it, the union comes back empty, and the window renders the
#            FIFTH SILENCE: "This run's raw holds no operating-point columns for
#            <dp>". That is a STATEMENT ABOUT THE RAW and it is FALSE — the
#            backend answered, and its answer was unreadable. This is the
#            wrong-answer-wearing-a-healthy-state shape that returned item B1
#            [F] (issue 1272), one layer out.
#   (b) F18  a malformed per-device VALUE -> UNCAUGHT RAISE out of the pure
#            renderer that every row of this suite and every widget path calls.
#            `_rowdevs` catches at the dict level; nothing caught the
#            `foreach {p v}` over a value. In the Tk path it surfaces as a
#            background error and the pane paints nothing.
#            ⚠ AND TWO MORE, MEASURED WHILE PLANNING B2a AND NOT IN THE ISSUE:
#            a malformed `absent` bucket and a malformed `nonfinite` bucket each
#            RAISE the same way, from the un-caught `foreach` inside _rowdevs
#            and from the two bucket walks in format_answer.
#   (c) F19  a value-less pair renders BYTE-IDENTICALLY to an absent column and
#            without the footnote that says what a blank means, so the
#            renderer's one honest distinction is lost. Section 3 of the issue
#            is the reachable twin: the footnote is per BLOCK, so an
#            empty-string value in a block that has any absent column inherits a
#            footnote that is FALSE about it. Rendering both as words closes
#            (c) and section 3 in one move and leaves F5's "the footnote rides
#            exactly once" golden where it is.
#   (d) F20  a newline inside a value makes ONE PAIR become TWO LINES, the
#            second unindented and carrying NO TAG, breaking the
#            one-pair-one-line model `block_text` and `render_pane` share. A
#            device NAME and a parameter NAME do it too.
# ALL FOUR RED BEFORE B2a: F17 renders the fifth silence, F18 RAISES three
# times, F19 renders two blanks indistinguishable from the absent one, F20
# renders nine lines for a seven-entry block.
set F1718_CTX [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1 zzsim]
## a well-formed dict whose `devices` VALUE is not a well-formed list
set F17_BADDEV "@m.x1.m1 \{\{id 1"
set F17_ANS [dict create devices $F17_BADDEV absent {} nonfinite {} \
                         complete 0 state ok]
set F17_T [rw_text $F17_ANS $F1718_CTX]
check {F17 a malformed `devices` value gets its OWN sentence, naming the backend that produced it, instead of falling into the fifth silence - which is a claim about the RAW and would be false} \
  [list [rw_bad $F17_T] $F17_T \
        [rw_count $F17_T [RW_OKEMPTY {@m.x1.m1}]] \
        [rw_tags $F17_ANS $F1718_CTX]] \
  [list 0 [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_FLAW zzsim] {}] 0 {hdr dim note {}}]

set F18_V [dict create devices [dict create {@m.x1.m1} "\{\{id 1"] \
                       absent {} nonfinite {} complete 0 state ok]
set F18_A [rw_ansd [dict create {@m.x1.m1} {{id 1}}] "\{\{@m.x1.m1 ib" {} 0 ok]
set F18_N [rw_ansd [dict create {@m.x1.m1} {{id 1}}] {} "\{\{@m.x1.m1 gm nan" 0 ok]
set F18_TV [rw_text $F18_V $F1718_CTX]
set F18_TA [rw_text $F18_A $F1718_CTX]
set F18_TN [rw_text $F18_N $F1718_CTX]
set F18_FLAW [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_FLAW zzsim] {}]
check {F18 a malformed per-device VALUE, a malformed `absent` bucket and a malformed `nonfinite` bucket each return a block instead of RAISING out of the pure renderer every row and every widget path calls, and each carries the malformed-answer sentence} \
  [list [rw_bad $F18_TV] [rw_bad $F18_TA] [rw_bad $F18_TN] \
        $F18_TV $F18_TA $F18_TN] \
  [list 0 0 0 $F18_FLAW $F18_FLAW $F18_FLAW]

set F19_ANS [rw_ansd [dict create {@m.x1.m1} {{id} {gm {}} {vds 1.25}}] \
                     {{@m.x1.m1 ib}} {} 0 ok]
set F19_T [rw_text $F19_ANS $F1718_CTX]
check {F19 a value-less pair and an empty-string value both render as WORDS, textually distinct from the blank an absent column gets - so the blank keeps exactly one meaning and the per-block footnote, which rides exactly once, stays true of the only row it is about} \
  [list $F19_T [rw_count $F19_T $RW_ABSN]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  "    id  : $RW_NOVAL" "    gm  : $RW_NOVAL" \
                  {    vds : 1.25} {    ib  :} $RW_ABSN {}] 1]

set F20_ANS [rw_ansd [dict create "@m.x1.mA\nX" \
                       [list [list "id\ty" "1.5\nINJECTED"] [list gm "2\r3"]]] \
                     {} {} 0 ok]
set F20_CTX [rw_ctx {M1:/} {@m.x1} op M1 zzsim]
set F20_B [rw_block $F20_ANS $F20_CTX]
set F20_T [rw_text  $F20_ANS $F20_CTX]
check {F20 a newline, a carriage return and a tab inside a value, inside a parameter name and inside a DEVICE name all collapse to one space: the block has exactly one line per entry, and no unindented untagged line appears in the middle of it} \
  [list [expr {[rw_bad $F20_B] ? {NOT-RENDERED} : [llength $F20_B]}] \
        [expr {[rw_bad $F20_T] ? {NOT-RENDERED} : [llength [split $F20_T "\n"]]}] \
        [rw_count $F20_T "\n\n"] [rw_count $F20_T "\r"] [rw_count $F20_T "\t"] \
        $F20_T] \
  [list 7 7 0 0 0 \
        [rw_lines {M1:/} {@m.x1} $RW_INC {  @m.x1.mA X} \
                  {    id y : 1.5 INJECTED} {    gm   : 2 3} {}]]

# ============================================================================
# F21-F26 — ITEM B2a-2: A NON-`ok` STATE IS A COMPLETE AND LEGAL ANSWER ON ITS
# OWN, AND A MALFORMED-INPUT PATH MAY NEVER ACCUSE AN INNOCENT BACKEND
# (issue 1284, whose first fix was REFUTED)
# ============================================================================
# F17/F18 above are sound and stay: a PRESENT bucket that cannot be walked IS a
# flaw in the backend's answer and deserves a sentence naming the backend.
# What they could not see is what the SAME predicate does to an answer that is
# not malformed at all.
#
# THE ADVERSARY'S OWN MEASUREMENT, REPRODUCED HERE AS THE RED. A third-party
# backend's perfectly legal minimal refusal `{state no_raw}` renders:
#   HEAD    -> No simulation results are loaded. Run a simulation, or load a
#              raw file, then ask again.
#   PATCHED -> The zzsim operating-point reader answered in a shape this window
#              could not read ...
# and MEASURED WHILE WRITING THIS SUITE, the blast radius is WIDER than the
# issue says: `{state not_annotated}`, `{state not_op}` and `{state no_devpath}`
# do it too. All four correct, actionable sentences become one false accusation
# against a backend that did nothing wrong.
#
# TWO CAUSES, AND A FIX NEEDS BOTH:
#   ORDER    `_answer_flaw` runs at rdw.tcl:370, ELEVEN lines BEFORE the
#            `$state ne {ok}` branch at :381. Reordering alone still leaves a
#            legal `{state ok devices {...}}` unvalidated in the wrong
#            direction.
#   SHAPE    `_answer_flaw` opens
#              if {[catch {dict keys [dict get $ans devices]} devs]} { return 1 }
#            so an ABSENT `devices` key is malformed BY CONSTRUCTION. Narrowing
#            alone still lets `{state no_raw}` reach `_flaw_line`.
# So: check the state FIRST; validate shape ONLY for an answer whose state is
# `ok`, and there only for a bucket that is PRESENT. `devices`, `absent`,
# `nonfinite` and `complete` are required only when `state` is `ok`.
#
# ⚠ THIS IS EXACTLY THE CLASS RULING D-5 EXISTS TO ADMIT. The user is building
# a custom ngspice and it will be the first backend to occupy it; a window that
# greets a correct minimal answer with a complaint about the backend sends its
# author hunting a bug that is in this file.
#
# F21 F22 F23 F25 F26 ARE RED BEFORE B2a-2. F24 IS A FENCE and is GREEN BEFORE
# AND AFTER — it is the half of 1284 that F17/F18 got right, held still so the
# narrowing cannot quietly discard it.
## The sixth sentence, and the one HEAD renders for a state it does not know.
## Spelled here because a state name a backend invents must reach the screen.
proc RW_UNKSTATE {s} { return "The operating-point reader answered with a state this window does not know: '$s'." }
set F21_CTX [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} tran M1 zzsim]
set F21_TAB [list no_raw        $RW_NORAW \
                  not_annotated $RW_NOTANNOT \
                  not_op        [RW_NOTOP tran] \
                  no_devpath    [RW_NODEVPATH M1]]
set F21_GOT {} ; set F21_EXP {}
foreach {_s _sent} $F21_TAB {
  ## the MINIMAL legal refusal — one key, which is all a refusal has to carry
  set _min [rw_text [dict create state $_s] $F21_CTX]
  ## the SAME state delivered as the seam's full five-key dict
  set _ful [rw_text [rw_ansd {} {} {} 0 $_s] $F21_CTX]
  set _gold [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $_sent {}]
  lappend F21_GOT [list $_s $_min $_ful [rw_count $_min [RW_FLAW zzsim]]]
  lappend F21_EXP [list $_s $_gold $_gold 0]
}
check {F21 THE ADVERSARY'S OWN INPUT: each of the four non-`ok` states delivered as a MINIMAL one-key answer renders its OWN state sentence, byte-identical to the same state delivered as a full five-key dict, and not one of the four names the backend - a non-`ok` state is a complete and legal answer on its own} \
  $F21_GOT $F21_EXP

## A REFUSAL MAKES NO DATA CLAIM, so nothing may walk its data keys — even when
## one is present and garbage. The state is the whole answer.
set F22_ANS [dict create state no_raw devices "\{\{id 1"]
set F22_T [rw_text $F22_ANS $F21_CTX]
check {F22 a non-`ok` state is legal even when a data key IS present and malformed: `{state no_raw devices <garbage>}` still renders the no_raw sentence, because a refusal makes no claim about data and nothing may walk it} \
  [list [rw_bad $F22_T] $F22_T [rw_count $F22_T [RW_FLAW zzsim]]] \
  [list 0 [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_NORAW {}] 0]

## AN ABSENT BUCKET IS EMPTY, NOT MALFORMED. `{state ok}` is the legal minimum
## for an answer that found nothing, and it must reach the FIFTH SILENCE — the
## sentence naming the device path — not an accusation.
set F23_ANS [dict create state ok]
set F23_T [rw_text $F23_ANS $F21_CTX]
check {F23 `{state ok}` with every data key ABSENT renders the FIFTH SILENCE naming the device path, not the malformed-answer sentence - an absent bucket is EMPTY, and a backend answering the legal minimum is not a backend at fault} \
  [list [rw_bad $F23_T] $F23_T [rw_count $F23_T [RW_FLAW zzsim]]] \
  [list 0 [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_OKEMPTY {@m.x1.m1}] {}] 0]

## THE SHAPE HALF SURVIVES THE NARROWING. A bucket that is PRESENT and cannot
## be walked is still a flaw, in all three buckets, and so is the MIXED case —
## no `devices` key at all beside a malformed `absent`, where the narrowing
## must not let the absent key excuse the malformed one.
## FENCE — GREEN BEFORE AND AFTER.
set F24_D [dict create devices "@m.x1.m1 \{\{id 1" absent {} nonfinite {} \
                       complete 0 state ok]
set F24_A [dict create devices {} absent "\{\{@m.x1.m1 ib" nonfinite {} \
                       complete 0 state ok]
set F24_N [dict create devices {} absent {} nonfinite "\{\{@m.x1.m1 gm nan" \
                       complete 0 state ok]
set F24_MIX [dict create state ok absent "\{\{@m.x1.m1 ib"]
set F24_FLAW [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_FLAW zzsim] {}]
check {F24 FENCE under `state ok` a PRESENT but un-walkable `devices`, `absent` or `nonfinite` still gets the flaw sentence naming the backend, and so does the MIXED case of no `devices` key at all beside a malformed `absent` - the narrowing may not discard the half of 1284 that was right} \
  [list [rw_text $F24_D $F21_CTX] [rw_text $F24_A $F21_CTX] \
        [rw_text $F24_N $F21_CTX] [rw_text $F24_MIX $F21_CTX]] \
  [list $F24_FLAW $F24_FLAW $F24_FLAW $F24_FLAW]

## AN ANSWER WITH NO READABLE `state` IS ITSELF MALFORMED — including one that
## is not a dict at all — and gets the sentence naming the backend, because the
## remedy is there. HEAD instead defaults to `set state unknown`, inventing a
## state name the backend never sent and rendering a sentence that blames the
## window for the backend's omission. A state that IS present but unrecognised
## is a different fact and keeps its own sentence, naming the state.
set F25_NOSTATE [dict create devices {} absent {} nonfinite {} complete 0]
set F25_NOTDICT {a b c}
set F25_WEIRD   [dict create state sideways]
set F25_TN [rw_text $F25_NOSTATE $F21_CTX]
set F25_TD [rw_text $F25_NOTDICT $F21_CTX]
set F25_TW [rw_text $F25_WEIRD   $F21_CTX]
check {F25 an answer with NO `state` key, and one that is not a dict at all, each get the flaw sentence naming the backend - while an answer whose `state` is PRESENT but unrecognised gets the sentence naming THAT state, and the two are pairwise distinct} \
  [list $F25_TN $F25_TD $F25_TW \
        [expr {$F25_TN eq $F25_TW ? 1 : 0}]] \
  [list $F24_FLAW $F24_FLAW \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_UNKSTATE sideways] {}] 0]

## STRUCTURAL, AND IT IS THE ONLY ROW THAT CAN STOP A LATER EDIT FROM REOPENING
## THIS. The ORDER is half the defect, and an order is not visible in any
## output once the shape check has been narrowed — a future `_answer_flaw` that
## quietly went back to treating an absent key as malformed would be caught by
## F21/F23, but one that merely moved back above the state branch would not, so
## long as the narrowing held. The call the state is read through comes FIRST.
set F26_B  [rw_body ::rdw::format_answer]
set F26_PS [string first {_answer_state} $F26_B]
set F26_PF [string first {_answer_flaw}  $F26_B]
check {F26 STRUCTURAL in `rdw::format_answer`'s own body the state is read through `_answer_state` BEFORE `_answer_flaw` is consulted, so a later edit cannot silently restore the ordering that caused the regression} \
  [list [expr {$F26_PS >= 0 ? 1 : 0}] [expr {$F26_PF >= 0 ? 1 : 0}] \
        [expr {($F26_PS >= 0 && $F26_PF >= 0 && $F26_PS < $F26_PF) ? 1 : 0}]] \
  {1 1 1}

# ============================================================================
# F27-F28 — ITEM B2d: THE TWO SHAPES ISSUE 1284 SECTION 5 LEFT OPEN, AND THEY
# ARE STILL OPEN IN THE PRESERVED FIX
# ============================================================================
# ⚠ THESE TWO ARE RED AGAINST **BOTH** SHIPPED STATES — against HEAD, which
# raises or lies about every shape F17-F20 name, AND against the preserved
# B2a-2 fix itself, which closes those four and leaves these two. Issue 1284's
# own ACCEPT row says "1284 FIXED", so lifting the preserved hunks and stopping
# there ships the issue half done. MEASURED on a scratch copy carrying the
# preserved fix and nothing else, 2026-09-04:
#     nonfinite {{@m.x1.m1 gm}}   (two fields, NO text)  ->  "    gm : (did not converge)"
#     devices   {{{} 1.5}}        (a nameless pair)      ->  "     : 1.5"
#
# WHY EACH IS A FLAW AND NOT A TOLERATED RENDER:
#   F27  `rdw::_nonfinite_text` DISCARDS its argument (src/rdw.tcl:177) and
#        returns the words unconditionally, so an entry carrying no evidence at
#        all still makes the window ASSERT that a column did not converge. That
#        is obligation 2 turned inside out: the words exist to say what the raw
#        actually holds, and here the raw was never quoted. The seam's contract
#        is a `{<rawdev> <param> <text>}` TRIPLE (item B1's re-do), so a
#        two-field entry is an answer that does not meet it, not a short form.
#        `_answer_flaw`'s shared `llength $e < 2` gate lets it through because
#        `absent` and `nonfinite` were checked at the same width; they are not
#        the same width. The bucket's own arity is the predicate the implement
#        agent must name (`rdw::_bucket_width`), so this row has a sabotage
#        handle of its own and does not have to borrow F17's.
#   F28  a pair whose parameter NAME is empty, or is nothing but whitespace,
#        renders a value under no name — "a blank row that means nothing", in
#        `_answer_flaw`'s OWN comment, which is the reason it rejects a
#        one-element absent entry. The predicate was arity, and arity is the
#        wrong question: F19's value-less `{id}` has arity 1 and a perfectly
#        good name, and must keep rendering `(no value reported)`. The question
#        is whether the entry NAMES a parameter (`rdw::_named`), asked of the
#        devices pair's own first field and of an absent/nonfinite entry's
#        SECOND field.
#
# ⚠ NEITHER IS REACHABLE THROUGH THE SHIPPED BACKEND, AND THAT IS THE POINT
# ruling D-5 makes: `ase::op_param_split` returns {} for an empty parameter and
# `ase::op_param_set` always emits a nonfinite TRIPLE, so no live path moves.
# The user is building a custom ngspice; the first backend to occupy these
# shapes will be their own, and a window that prints "(did not converge)" about
# a column nobody reported would send its author hunting a convergence problem
# that does not exist.
#
# Both rows carry their CONTROL in the same check, because a predicate that
# rejects everything would satisfy the red half alone.
set F27_BAD2 [rw_ansd [dict create {@m.x1.m1} {{id 1.5}}] {} \
                      [list [list {@m.x1.m1} gm]] 0 ok]
set F27_BAD1 [rw_ansd [dict create {@m.x1.m1} {{id 1.5}}] {} \
                      [list [list {@m.x1.m1}]] 0 ok]
set F27_GOOD [rw_ansd [dict create {@m.x1.m1} {{id 1.5}}] {} \
                      [list [list {@m.x1.m1} gm nan]] 0 ok]
set F27_T2 [rw_text $F27_BAD2 $F1718_CTX]
set F27_T1 [rw_text $F27_BAD1 $F1718_CTX]
set F27_TG [rw_text $F27_GOOD $F1718_CTX]
set F27_FLAW [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_FLAW zzsim] {}]
check {F27 a `nonfinite` entry that carries no text field gets the malformed-answer sentence instead of making the window assert non-convergence on no evidence - while a well-formed {rawdev param text} triple still renders the words, so the bucket's arity is the predicate and not the words} \
  [list [rw_bad $F27_T2] [rw_bad $F27_T1] [rw_bad $F27_TG] \
        $F27_T2 $F27_T1 \
        [rw_count $F27_T2 $RW_NF] [rw_count $F27_T1 $RW_NF] \
        $F27_TG] \
  [list 0 0 0 $F27_FLAW $F27_FLAW 0 0 \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    id : 1.5} "    gm : $RW_NF" {}]]

set F28_DEV [rw_ansd [dict create {@m.x1.m1} [list [list {} 1.5] [list id 2]]] \
                     {} {} 0 ok]
set F28_WS  [rw_ansd [dict create {@m.x1.m1} [list [list "\n\t " 1.5] [list id 2]]] \
                     {} {} 0 ok]
set F28_ABS [rw_ansd [dict create {@m.x1.m1} {{id 2}}] \
                     [list [list {@m.x1.m1} {}]] {} 0 ok]
set F28_NF  [rw_ansd [dict create {@m.x1.m1} {{id 2}}] {} \
                     [list [list {@m.x1.m1} {} nan]] 0 ok]
set F28_GOOD [rw_ansd [dict create {@m.x1.m1} [list [list vgs 1.5] [list id 2]]] \
                      {{@m.x1.m1 ib}} {{@m.x1.m1 gm nan}} 0 ok]
set F28_TD [rw_text $F28_DEV  $F1718_CTX]
set F28_TW [rw_text $F28_WS   $F1718_CTX]
set F28_TA [rw_text $F28_ABS  $F1718_CTX]
set F28_TN [rw_text $F28_NF   $F1718_CTX]
set F28_TG [rw_text $F28_GOOD $F1718_CTX]
check {F28 a parameter NAME that is empty or nothing but whitespace - in `devices`, in `absent` and in `nonfinite` - gets the malformed-answer sentence rather than a value belonging to no parameter, while the same three entries carrying real names render exactly as before: the question is whether the entry names a parameter, not how many fields it has} \
  [list [rw_bad $F28_TD] [rw_bad $F28_TW] [rw_bad $F28_TA] [rw_bad $F28_TN] \
        $F28_TD $F28_TW $F28_TA $F28_TN \
        [rw_count $F28_TD { : 1.5}] \
        [rw_bad $F28_TG] $F28_TG] \
  [list 0 0 0 0 \
        $F27_FLAW $F27_FLAW $F27_FLAW $F27_FLAW 0 0 \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    vgs : 1.5} {    id  : 2} "    gm  : $RW_NF" \
                  {    ib  :} $RW_ABSN {}]]

# ============================================================================
# F29 — ITEM B2d, THE ADVERSARY'S REFUTATION: THE FIFTH KEY IS A LINE INJECTOR
# ============================================================================
# ⚠ RED AGAINST HEAD **AND** AGAINST THE PRESERVED FIX, AND IT IS THE BATCH'S
# OWN RECURRING LESSON landing on this very section. F20 fences a newline, a CR
# and a tab inside a VALUE, a PARAMETER NAME and a DEVICE NAME — the three
# fragments `rdw::_oneline` was applied to. F25 fences the unrecognised-state
# arm, with the newline-free word `sideways`. The two rows cross the whole
# class except at their intersection, and the intersection is where the hole
# was: `_state_sentence`'s default arm echoes the backend's own `state`
# verbatim, so an answer as small as
#     devices {} absent {} nonfinite {} complete 0 state "weird\n    id : 1e-5"
# rendered FOUR block entries as FIVE lines of paste text — the extra line a
# correctly indented, correctly formatted operating-point row that NO BUCKET
# EVER CARRIED. MEASURED on the fixed tree 2026-09-04: 4 entries, 5 lines of
# `block_text`, 7 lines in the real Tk pane on :99. Three counts for one block,
# and the shipped comment at src/rdw.tcl:370 states the one-line rule as
# absolute. It is the LIE half of issue 1284's own title, reached through the
# answer dict AFTER the fix, and invariant I3's harm exactly: on the clipboard
# an injected row is indistinguishable from a measured one.
#
# THE SAME ESCAPE EXISTED AT FOUR MORE SITES, all fenced below because one row
# per site is what stops the next author reopening the one nobody wrote down:
# `_flaw_line`'s backend name, the `dim` device-path line and the fifth
# silence's `$dp`, and the `no_devpath` sentence's instance name. A fifth,
# dump_devpath's "could not answer: $ans", interpolates a CAUGHT TCL ERROR and
# so is multi-line by nature; it is covered by the same fix and reached through
# `rdw::_refusal`.
#
# ⚠ THE PREDICATE IS STRUCTURAL, NOT A GOLDEN. `block_text` joins the entries
# with a newline, so the block carries one line per entry IF AND ONLY IF
# `llength $blk` equals the split of its own text — which is the one-pair-one-
# line model `block_text` and `render_pane` share, asserted as an identity
# rather than as a count that would have to be updated whenever a row moves.
# The goldens ride alongside so a fix that flattened the block by DELETING the
# sentence could not pass.
proc rw_onelines {ans ctx} {
  set b [rw_block $ans $ctx]
  if {[rw_bad $b]} { return $b }
  set t [rw_ans ::rdw::block_text $b]
  if {[rw_bad $t]} { return $t }
  return [expr {[llength $b] == [llength [split $t "\n"]] ? 1 : 0}]
}

set F29_INJ  "weird\n    id  : 1.11e-05\r    vth : 0.45\tgm : 2"
set F29_FLAT {weird     id  : 1.11e-05     vth : 0.45 gm : 2}
set F29_CTX  [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1 zzsim]

## (a) the refutation itself: an unrecognised state whose text carries rows.
set F29_A  [rw_ansd {} {} {} 0 $F29_INJ]
## (b) the backend NAME the flaw sentence quotes, from ctx. No `state` key, so
##     the flaw arm is what fires.
set F29_BC [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1 "zz\n    id : 4.2e-3"]
set F29_B  [dict create devices {} absent {} nonfinite {} complete 0]
## (c) the device path, which is BOTH line 2 and the fifth silence's subject.
set F29_CC [rw_ctx {M1:/xdut/xbg} "@m.x1.m1\n    id : 9.9" op M1 zzsim]
set F29_C  [rw_ansd {} {} {} 0 ok]
## (d) the instance name, which is the schematic's and not the backend's.
set F29_DC [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op "M1\n    id : 7.7" zzsim]
set F29_D  [dict create state no_devpath]
## THE CONTROL, in the same check: a healthy answer keeps its bytes and its
## own entries-equal-lines identity, so a renderer that flattened everything
## could not satisfy the red half alone.
set F29_G  [rw_ansd [dict create {@m.x1.m1} {{id 1.5}}] {{@m.x1.m1 ib}} {} 0 ok]

check {F29 no fragment of a backend answer or of the context can put a SECOND line inside one block entry: the unrecognised-state echo, the flaw sentence's backend name, the device-path line and the no_devpath instance name each collapse to one line, so the block's entry count and its paste text's line count stay identical - an injected row would be indistinguishable from a measured one on the clipboard} \
  [list [rw_onelines $F29_A $F29_CTX] [rw_onelines $F29_B $F29_BC] \
        [rw_onelines $F29_C $F29_CC]  [rw_onelines $F29_D $F29_DC] \
        [rw_onelines $F29_G $F29_CTX] \
        [rw_text $F29_A $F29_CTX] [rw_text $F29_B $F29_BC] \
        [rw_text $F29_C $F29_CC]  [rw_text $F29_D $F29_DC] \
        [rw_text $F29_G $F29_CTX]] \
  [list 1 1 1 1 1 \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_UNKSTATE $F29_FLAT] {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_FLAW {zz     id : 4.2e-3}] {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1     id : 9.9} \
                  [RW_OKEMPTY {@m.x1.m1     id : 9.9}] {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} \
                  [RW_NODEVPATH {M1     id : 7.7}] {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    id : 1.5} {    ib :} $RW_ABSN {}]]

# ============================================================================
# SECTION Q — END TO END THROUGH THE SEAM, AND SPEC QUESTION Q10 AS AN ASSERTION
# ============================================================================
# ⚠ Q10 IS ANSWERED YES AND IS ASSERTED HERE, NOT ASKED. Item B1 measured it
# with a real ngspice: a deck with `.op` then `.tran` writes ONE file holding
# TWO plots, `xschem raw read` lands on the Operating Point and returns real
# device numbers. DECISIONS.md asks for it as the RDW suite's first check; this
# is that check, on a fixture so it cannot rot. Two caveats B1 measured and
# this suite does not depend on: on the `.control`+`write` writer the second
# `write` overwrites the first without `set appendwrite`, and once the tran
# slot is READ it becomes current, at which point `raw list` answers about the
# transient.
# RED before B3: Q1 Q2 Q3.

rw_annot $R_TWO
set Q1_ST {} ; catch {set Q1_ST [xschem raw sim_type]}
set Q1_CTX [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} $Q1_ST M1]
set Q1_BLK [rw_ans ::rdw::dump_devpath {@m.x1.m1} $Q1_CTX]
set Q1_TXT [expr {[rw_bad $Q1_BLK] ? $Q1_BLK : [rw_ans ::rdw::block_text $Q1_BLK]}]
check {Q1 Q10 ASSERTED: one raw holding an Operating Point plot AND a Transient plot lands on the OP, and the window renders its six real numbers with the honesty line - the RDW IS reachable after an ordinary OP+TRAN run} \
  [list $Q1_ST $Q1_TXT] \
  [list op [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
            {    id  : 11.1u} {    is  : 0} {    vth : 0.75} \
            {    gm  : 1m} {    vds : 1.25} {    vgs : 0.5} {}]]

## The block is PUSHED, and the store is namespace state that works headless —
## the pane is a projection of it, never the other way round.
##
## ⚠ REWRITTEN BY ITEM B2a (issue 1283 gap A). AS B3 SHIPPED IT THIS ROW WAS
## TITLED "newest first" AND PUSHED EXACTLY ONE BLOCK, then asserted that block
## was at index 0 — which is TRUE UNDER EITHER ORDERING. Measured: sabotaging
## `rdw::_insert_index` from `1.0` to `end`, which flips both the pane insert
## and the prepend in `rdw::push`, passed ALL 32 HEADLESS CHECKS and reds only
## on `:99`, in the two widget rows W3 and W3b. So the accept row "newest dump
## on top" had NO HEADLESS WITNESS AT ALL, and every `--nogui` run and
## full_audit.sh's own nogui leg would have passed with the store reversed. A
## SECOND, DISTINCT block is what makes the assertion mean what its name says.
##
## ⚠ THIS ROW IS GREEN BEFORE B2a — it is a missing FENCE, not a defect — so
## its red-before proof is the SB-OLDEST-ON-TOP sabotage, which must now red
## the --nogui arm and not only the display one.
## ⚠ TWO TERMS OF THIS ROW MOVED FOR ITEM B5-a (issue 1322), AND THE GOLDEN
## DID NOT. `rdw::push` now stamps the block's SUBJECT into the header entry as
## a third element, so `[lindex [lindex $blocks 0] 0]` is `{hdr MQ1B:/ <dict>}`
## for a resolvable instance. This row passed at HEAD only because its fixture
## happens to hold no instance named MQ1B — green by accident — so it now
## compares the header entry's TAG and TEXT, which is what it was ever about.
## ⚠ AND THE `eq $Q1_BLK` TERM IS A CONSTRAINT ON THE FIX, not a detail:
## `rdw::dump_devpath` (rdw.tcl:749-750) pushes `$blk` and returns `$blk`, not
## push's answer. Once push stamps, it must return `[rdw::push $blk]` or the
## value handed back is not the value stored and this term reds.
set Q1B_N0 [expr {[info exists ::rdw::blocks] ? [llength $::rdw::blocks] : -1}]
set Q1B_NEW [rw_ans ::rdw::push \
  [rw_block [rw_ansd [dict create {@m.x1.mq1b} {{id 42}}] {} {} 0 ok] \
            [rw_ctx {MQ1B:/} {@m.x1.mq1b} op MQ1B]]]
check {Q1b the dump is pushed onto ::rdw::blocks, NEWEST FIRST, on BOTH arms: a SECOND distinct push lands at index 0 and the first one is now at index 1 - the store is namespace state and the pane is only its projection} \
  [list [expr {[info exists ::rdw::blocks] ? 1 : 0}] \
        [expr {$Q1B_N0 == 1 ? 1 : $Q1B_N0}] \
        [expr {[rw_bad $Q1B_NEW] ? {NOT-PUSHED} : 1}] \
        [expr {[llength $::rdw::blocks] == $Q1B_N0 + 1 ? 1 : 0}] \
        [expr {[lindex $::rdw::blocks 0] eq $Q1B_NEW ? 1 : 0}] \
        [expr {[lindex $::rdw::blocks 1] eq $Q1_BLK ? 1 : 0}] \
        [lrange [lindex [lindex $::rdw::blocks 0] 0] 0 1]] \
  {1 1 1 1 1 1 {hdr MQ1B:/}}

## THE FOUR SILENCES, END TO END. Each is produced by driving the real seam
## into that state, so the row asserts the renderer AND the state plumbing.
proc rw_dumptext {devpath ctx} {
  set b [rw_ans ::rdw::dump_devpath $devpath $ctx]
  if {[rw_bad $b]} { return $b }
  return [rw_ans ::rdw::block_text $b]
}

catch {xschem raw clear}
set Q2_NORAW [rw_dumptext {@m.x1.m1} $F_CTX1]
catch {xschem raw clear}
catch {xschem raw read $R_SIX op}
set Q2_NOTANN [rw_dumptext {@m.x1.m1} $F_CTX1]
catch {xschem raw clear}
catch {xschem raw read $R_TRAN tran}
set Q2_STY {} ; catch {set Q2_STY [xschem raw sim_type]}
set Q2_NOTOP [rw_dumptext {@m.x1.m1} [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} $Q2_STY M1]]
set Q2_NODP [rw_dumptext {} [rw_ctx {M1:/xdut/xbg} {} $Q2_STY M1]]
check {Q2 THE FOUR SILENCES END TO END, each driven into the real seam: no raw at all, a raw read but never annotated, a TRANSIENT slot, and an instance with no descriptor - four different sentences and not one number} \
  [list $Q2_STY $Q2_NORAW $Q2_NOTANN $Q2_NOTOP $Q2_NODP] \
  [list tran \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_NORAW {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_NOTANNOT {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_NOTOP tran] {}] \
        [rw_lines {M1:/xdut/xbg} [RW_NODEVPATH M1] {}]]

## THE UNION TRAP, THROUGH THE REAL SEAM RATHER THAN A HAND-BUILT DICT. The
## dims=0 raw and the BINARY NaN raw both make the seam answer `devices {}` in
## state ok, and both name a real device the user is looking at.
rw_annot $R_ALLABS
set Q3_ABS [rw_dumptext {@m.x1.m9} [rw_ctx {M9:/} {@m.x1.m9} op M9]]
rw_annot $R_ALLNF
set Q3_NF [rw_dumptext {@m.x1.m8} [rw_ctx {M8:/} {@m.x1.m8} op M8]]
rw_annot $R_MIX
set Q3_MIX [rw_dumptext {@m.x1.m1} $F_CTX1]
check {Q3 the two devices the seam answers with an EMPTY `devices` dict still render in full - the dims=0 one as blanks with the footnote, the BINARY NaN/Inf one as `(did not converge)` with no `nan` anywhere - and a mixed device keeps its genuine zero} \
  [list $Q3_ABS $Q3_NF [rw_count "$Q3_ABS$Q3_NF$Q3_MIX" {nan}] $Q3_MIX] \
  [list [rw_lines {M9:/} {@m.x1.m9} $RW_INC {    id  :} {    vth :} $RW_ABSN {}] \
        [rw_lines {M8:/} {@m.x1.m8} $RW_INC \
                  {    id  : (did not converge)} {    vth : (did not converge)} {}] \
        0 \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    vth : 0.75} {    gm  : 1m} {    is  : 0} \
                  {    id  : (did not converge)} {}]]

## D-3 end to end: ONE request, FIVE primitives out of the real seam, and the
## decoy @r.xr10... excluded by the segment-boundary rule.
rw_annot $R_XR1
set Q4_TXT [rw_dumptext {@r.xr1} [rw_ctx {XR1:/} {@r.xr1} op XR1]]
check {Q4 D-3 end to end: one XR1 request resolves through the seam to five primitives in raw-file order, each labelled, and the xr10 decoy is nowhere in the block} \
  [list $Q4_TXT [rw_count $Q4_TXT {xr10}]] \
  [list [rw_lines {XR1:/} {@r.xr1} $RW_INC \
                  {  @r.xr1.x0.rend1} {    i : 1u} \
                  {  @r.xr1.x0.rend2} {    i : 2u} \
                  {  @c.xr1.x0.xc0.c0} {    c : 1f} \
                  {  @c.xr1.x0.xc1.c0} {    c : 2f} \
                  {  @b.xr1.x0.brbody} {    i : 4u} {}] 0]

## rdw::sim resolves the BACKEND; the seam is never called by its proc name.
## Behaviourally identical today, which is precisely why row S1 is structural:
## the whole point of the seam is that nothing above it changes when the user's
## wildcard ngspice arrives.
check {Q5 rdw::sim resolves the one registered backend rather than naming a proc, and an explicit ::rdw::sim override wins - the door B4 and B5 drive} \
  [list [rw_ans ::rdw::sim] [ase::backend_names]] \
  [list ngspice ngspice]

# ============================================================================
# Q6 — RULING DD-5 END TO END, ON TWO RAWS THAT BOTH ANSWER `dc`
# ============================================================================
# The first is an ordinary DC transfer characteristic, which is what issue 1282
# is about. THE SECOND IS THE ONE THAT MOVED THE WORDING: save.c:1073 and :1120
# both carry `if(raw->npoints[...] > 1 && !strcmp(sim_type, "op")) sim_type =
# "dc";`, so a MULTI-POINT `Operating Point` plot is renamed `dc` by the reader
# and a user who ran nothing but an operating point lands in this arm too.
# MEASURED on this binary: a three-point `Plotname: Operating Point` raw answers
# `xschem raw sim_type` = dc. That is why RW_ANALYSIS names what the loaded
# results CALL THEMSELVES rather than what the user ran (see the wording block),
# and it is also why option (c) - refusing `dc` - would have been wrong on its
# own terms and not only forbidden by DD-5: it would refuse a real operating
# point. test_op_annot's row T26 is a three-point Operating Point that must keep
# publishing, so the C is not moving either.
# RED BEFORE B2a: measured sim_type=dc, block-mentions-dc=0, both raws.
set R_DC  [file join $scratch dcsweep.raw]
set R_OP3 [file join $scratch op3point.raw]
rw_mkraw $R_DC  [list [list {DC transfer characteristic} $F_SIX $T_SIX]]
rw_mkraw $R_OP3 [list [list {Operating Point} $F_SIX $T_SIX]] 3
rw_annot $R_DC
set Q6_STY1 {} ; catch {set Q6_STY1 [xschem raw sim_type]}
set Q6_T1 [rw_dumptext {@m.x1.m1} [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} $Q6_STY1 M1]]
rw_annot $R_OP3
set Q6_STY2 {} ; catch {set Q6_STY2 [xschem raw sim_type]}
set Q6_T2 [rw_dumptext {@m.x1.m1} [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} $Q6_STY2 M1]]
set Q6_WANT [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_ANALYSIS dc] $RW_INC \
                      {    id  : 11.1u} {    is  : 0} {    vth : 0.75} \
                      {    gm  : 1m} {    vds : 1.25} {    vgs : 0.5} {}]
check {Q6 DD-5 end to end through the real seam: a DC transfer characteristic AND a three-point Operating Point (which save.c itself renames `dc`) both answer ok with real point-0 numbers, and both blocks now NAME the analysis instead of presenting it as an operating point} \
  [list $Q6_STY1 $Q6_STY2 $Q6_T1 $Q6_T2] \
  [list dc dc $Q6_WANT $Q6_WANT]

# ============================================================================
# Q7-Q8 — TWO DIFFERENT REFUSALS, TWO DIFFERENT SENTENCES (issue 1282 part 2)
# ============================================================================
# `rdw::dump_devpath` had ONE `catch {ase::backend_hook $s op_param_set}` arm
# producing ONE sentence - "Simulator X has no operating-point reader" - for TWO
# different facts with two different remedies: NO SUCH BACKEND, and a backend
# that registered without the (deliberately non-required) `op_param_set` hook.
# `ase::backend_hook` already mints two distinct errors for them (ase.tcl:550
# "unknown simulator" and :552 "unknown hook"), so no new information is needed,
# only a caller that asks which case it is. ITEM B5 IS THE FIRST THING THAT SETS
# `::rdw::sim`, so the split has to exist before B5, not after.
#
# ⚠ Q8 REGISTERS A SECOND BACKEND AND MUST RESTORE `::ase::backends`. Row Q5
# above asserts `ase::backend_names` is exactly {ngspice}, and `rdw::sim`
# returns the single registered backend when there is exactly one - so a second
# one left behind would change what Q5 and the seam suite assert. The
# save-and-restore and the five-hook registration are copied verbatim from
# tests/headless/test_rdw_seam_1245.tcl:505-514, whose row S3 exists to keep
# `op_param_set` OFF the required-hook list precisely so this case is reachable.
# BOTH RED BEFORE B2a: measured, an unregistered name produced
# "Simulator nosuchsim has no operating-point reader, so this window has nothing
# to show for it." - the registered-but-no-reader sentence, for the other fact.
set Q7_OLDSIM {} ; catch {set Q7_OLDSIM $::rdw::sim}
set ::rdw::sim zznosuchsim
set Q7_T [rw_dumptext {@m.x1.m1} [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1 zznosuchsim]]
set ::rdw::sim {}
check {Q7 a name no backend registered says exactly that, names it, and gives the remedy - it does NOT say the simulator has no operating-point reader, which is a different fact with a different fix} \
  [list $Q7_T [rw_count $Q7_T {has no operating-point reader}] \
        [rw_count $Q7_T {op_param_set}]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_NOSIM zznosuchsim] {}] 0 0]

set Q8_SAVED {} ; catch {set Q8_SAVED $::ase::backends}
set Q8_REG [rw_ans ::ase::register_backend zzb2a5 [dict create \
  render_deck  [rw_ans ::ase::backend_hook ngspice render_deck] \
  run_cmd      [rw_ans ::ase::backend_hook ngspice run_cmd] \
  log_file     [rw_ans ::ase::backend_hook ngspice log_file] \
  result_probe [rw_ans ::ase::backend_hook ngspice result_probe] \
  raw_file     [rw_ans ::ase::backend_hook ngspice raw_file]]]
set ::rdw::sim zzb2a5
set Q8_T [rw_dumptext {@m.x1.m1} [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1 zzb2a5]]
set ::rdw::sim {}
if {$Q8_SAVED ne {}} { set ::ase::backends $Q8_SAVED }
if {$Q7_OLDSIM ne {}} { set ::rdw::sim $Q7_OLDSIM }
check {Q8 a backend registered with the five required hooks and NO op_param_set says THAT instead, names the hook a backend has to add, is a different sentence from Q7's - and the second backend is put back, so ase::backend_names is {ngspice} again} \
  [list $Q8_REG $Q8_T [rw_has $Q8_T {op_param_set}] \
        [expr {$Q7_T ne $Q8_T ? 1 : 0}] \
        [ase::backend_names]] \
  [list zzb2a5 [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_NOREADER zzb2a5] {}] 1 1 ngspice]

# ============================================================================
# Q9 — THE INERT-BUTTON MESSAGE, HEADLESS (issue 1283 gap C)
# ============================================================================
# ⚠ GREEN BEFORE B2a, AND THAT IS THE POINT. `rdw::status` was split precisely
# so the inert path is drivable with no widget (`::rdw::statusmsg` is set
# whether or not one exists), but the ONLY row asserting that an inert button
# SAYS anything is W4b, inside the Tk-guarded section. Measured: making
# `rdw::status` a no-op passes the FULL 32-check headless run. Its red-before
# proof is the sabotage, not the shipped tree. W4b on the display arm is the
# twin this row is copied from.
## ⚠ REWRITTEN BY ITEM B5, THE HEADLESS TWIN OF W4b. It used to drive
## `rdw::inert`, which B5 DELETES - a proc that says "item B5 wires it" after
## item B5 wired it is a lie, and this row would have kept that lie golden. The
## point of the row is unchanged and is issue 1283 gap C's: the "the button
## said something" obligation must have a witness with NO WIDGET ANYWHERE, or
## making rdw::status a no-op passes the whole headless run.
## The two presses below are both REFUSALS - no dump has been pushed at this
## point in the file, and Delete is greyed on list 3 - which is deliberate:
## a refusal is the case where a silent button is most damaging, and neither
## press can reach the store or write a file.
## ⚠ IT MUST NOT TOUCH ::rdw::blocks. Row W1b, further down the display arm,
## asserts that the stored dumps SURVIVE a close and are repainted, and it reads
## a device name out of them; a row that emptied the store here would red W1b
## from three hundred lines away. Both presses below are GREYING refusals, which
## depend on the list identity alone - no target row, no subject, no store, no
## file - so they say what they say whatever is in the pane.
## ⚠ NOT `expr {[info exists v] ? $v : annotation}` - the list identity is a
## WORD and expr evaluates a bare word as an operand, raising "invalid
## bareword". The same trap is recorded at k_listkind and in the keys suite.
set Q9_LK0 annotation
if {[info exists ::rdw::listkind]} { set Q9_LK0 $::rdw::listkind }
set Q9_NB0 [expr {[info exists ::rdw::blocks] ? [llength $::rdw::blocks] : -1}]
rw_ans ::rdw::set_list all
rw_ans ::rdw::status {}
rw_ans ::rdw::button delete
set Q9_M1 [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]
rw_ans ::rdw::status {}
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::button add
set Q9_M2 [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]
rw_ans ::rdw::status {}
rw_ans ::rdw::set_list $Q9_LK0
## ⚠ AND TWO OF ITS TERMS ARE POSITIVE CLAIMS ABOUT THE REASON (item B5-a).
## MEASURED: with `rdw::button_state` forced to return `normal` - the greying
## deleted - EVERY term of the row as this patch first wrote it still passed.
## Both presses fall through to the ordinary "nothing has been dumped into this
## window yet" refusal, which is non-empty, names its own button, differs from
## its sibling, touches no store and clears; and `not wired yet` appears in
## neither, because the string it was written to exclude is gone from the file.
## A fence built entirely out of NEGATIVES cannot tell the sentence it is about
## from any other sentence. HEAD's own Q9 carried a positive claim about the
## reason - `[rw_has $Q9_M1 {B5}]` - and this rewrite dropped it; the two terms
## below put that kind of claim back, over the sentence `rdw::button` actually
## emits for a greyed press, and they name the LIST each button was greyed on
## so the two are not the same assertion twice. The `not wired yet` negatives
## are kept beside them: they fence a different fact.
check {Q9 a greyed button that is invoked anyway SAYS SO in the window's own status line with no widget anywhere: Delete on list 3 names itself AND says it is greyed on the `all` list, Add on list 1 says it is greyed on the `annotation` list, neither claims the column is unwired, the two sentences differ, the store is untouched, the variable is clearable - and rdw::inert is gone} \
  [list [expr {$Q9_M1 ne {} && $Q9_M1 ne {NOVAR} ? 1 : 0}] \
        [rw_has $Q9_M1 {Delete}] \
        [rw_has $Q9_M1 {greyed on the all list}] \
        [expr {[string first {not wired yet} $Q9_M1] < 0 ? 1 : 0}] \
        [expr {$Q9_M2 ne {} && $Q9_M2 ne {NOVAR} ? 1 : 0}] \
        [rw_has $Q9_M2 {Add}] \
        [rw_has $Q9_M2 {greyed on the annotation list}] \
        [expr {[string first {not wired yet} $Q9_M2] < 0 ? 1 : 0}] \
        [expr {$Q9_M1 ne $Q9_M2 ? 1 : 0}] \
        [expr {[info exists ::rdw::blocks] ? [llength $::rdw::blocks] : -1}] \
        [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}] \
        [llength [info commands ::rdw::inert]]] \
  [list 1 1 1 1 1 1 1 1 1 $Q9_NB0 {} 0]

# ============================================================================
# SECTION W — THE WIDGETS. DISPLAY ARM ONLY, AND IT IS NOT OPTIONAL.
# ============================================================================
# ⚠ A SUITE THAT ONLY EVER RUNS --nogui WILL PASS WHILE THE WINDOW IS BROKEN.
# These rows run under `GUI_GATE=0 tests/headless/devdisplay.sh exec ...` (:99,
# openbox live) and self-skip headless. `-exportselection 1` takes the X
# PRIMARY selection away from whatever held it (measured), so the window is
# CLOSED at the end of the section — test_calc_skeleton's own hygiene.
# RED before B3: W1 W2 W3 W4.  GREEN before B3: W0 (it measures Tk, not B3).

if {!$live_tk} {
  puts "W section skipped (no DISPLAY) -- sections M N H F Q S ran on this arm"
} elseif {[catch {

## W0 IS WHAT STOPS W2 PASSING VACUOUSLY. "Drive a keystroke and prove the
## buffer is unchanged" is satisfied perfectly by delivering no keystroke at
## all, and bare `event generate` key delivery is a known ~1-in-5 flake in this
## tree (test_calc_skeleton:1368). So the SAME delivery is aimed at an ordinary
## editable text first: if the control does not change, the mechanism is dead
## and this row says so instead of W2 quietly passing.
catch {destroy .rdwctl}
toplevel .rdwctl
text .rdwctl.t -width 24 -height 3
pack .rdwctl.t
update idletasks
set W0_TRIES 0
while {$W0_TRIES < 12 && [string trim [rw_w .rdwctl.t get 1.0 end]] eq {}} {
  incr W0_TRIES
  catch {focus -force .rdwctl.t}
  catch {event generate .rdwctl.t <Key-x> -when now}
  catch {update}
}
check {W0 CONTROL the synthesised-keystroke mechanism itself is live: the same delivery W2 uses really does put a character into an ordinary editable text} \
  [string trim [rw_w .rdwctl.t get 1.0 end]] x
set W0_N [expr {$W0_TRIES < 3 ? 3 : $W0_TRIES}]

# --- W1 the window's life ----------------------------------------------------
set W1_OPEN [rw_ans ::rdw::open]
catch {update idletasks}
set W1_KIDS [llength [rw_w winfo children .]]
set W1_OPEN2 [rw_ans ::rdw::open]
catch {update idletasks}
## ⚠ THE TITLE GAINED THE LIST'S NAME (issue 1355) AND THIS GOLDEN MOVED WITH
## IT.  It is the ONE golden row the chrome cost, measured: the chrome LABEL
## moves none at all, on either arm.  The title is read through the same
## `rdw::_title` accessor the window uses, so this row asserts that the window
## really titles itself from the identity in force and not that some literal
## happens to match -- row LX6 is where the literal is golded, once.
check {W1 singleton: open builds .rdw titled for the list identity in force, a second open RAISES the same toplevel rather than building a second, and WM_DELETE_WINDOW is rdw::close} \
  [list $W1_OPEN [rw_w winfo exists .rdw] [rw_w winfo class .rdw] \
        [rw_w wm title .rdw] $W1_OPEN2 \
        [llength [rw_w winfo children .]] \
        [rw_w wm protocol .rdw WM_DELETE_WINDOW]] \
  [list .rdw 1 Toplevel [rw_ans ::rdw::_title $::rdw::listkind] .rdw $W1_KIDS rdw::close]

catch {wm iconify .rdw} ; catch {update}
rw_ans ::rdw::open
catch {update}
set W1_STATE [rw_w wm state .rdw]
rw_ans ::rdw::close
catch {update idletasks}
set W1_GONE [rw_w winfo exists .rdw]
## DECISION 6: the dumps are the artifact the feature exists to produce (the
## user's words: paste them into design-review documents). They are namespace
## state, not window state, and a stray click on the window's X must not cost
## an hour of them. Rule debt 1245_B3_dumps_survive_close.
set W1_NB [expr {[info exists ::rdw::blocks] ? [llength $::rdw::blocks] : -1}]
rw_ans ::rdw::open
catch {update idletasks}
set W1_PANE [rw_w .rdw.p.t get 1.0 end]
check {W1b iconify then open leaves it normal, close destroys it, the stored dumps SURVIVE the close, and a reopen paints them again} \
  [list $W1_STATE $W1_GONE [expr {$W1_NB > 0 ? 1 : 0}] \
        [expr {[info exists ::rdw::blocks] && [llength $::rdw::blocks] == $W1_NB ? 1 : 0}] \
        [rw_has $W1_PANE {@r.xr1.x0.rend1}]] \
  {normal 0 1 1 1}

# --- W2 read-only AND copyable: the reason this window exists ----------------
## The user's own framing: the text must be selectable and copyable so it can be
## pasted into design-review documents, and READ-ONLY because nobody may type
## into a record of a simulation.
set W2_BEFORE [rw_w .rdw.p.t get 1.0 end]
rw_w .rdw.p.t insert end {TYPED BY A TEST}
rw_w .rdw.p.t delete 1.0 1.5
set W2_AFTER_API [rw_w .rdw.p.t get 1.0 end]
foreach seq {<Key-x> <Key-Return> <Key-BackSpace> <Key-Delete> <<Paste>>} {
  for {set i 0} {$i < $W0_N} {incr i} {
    catch {focus -force .rdw.p.t}
    catch {event generate .rdw.p.t $seq -when now}
  }
  catch {update}
}
set W2_AFTER_KEY [rw_w .rdw.p.t get 1.0 end]
check {W2 READ-ONLY: the pane is -state disabled, and neither the widget API nor five real keystrokes (x Return BackSpace Delete Paste) change one byte of the buffer} \
  [list [rw_w .rdw.p.t cget -state] \
        [expr {$W2_AFTER_API eq $W2_BEFORE ? 1 : 0}] \
        [expr {$W2_AFTER_KEY eq $W2_BEFORE ? 1 : 0}]] \
  {disabled 1 1}

catch {event generate .rdw.p.t <<SelectAll>> -when now}
catch {update}
set W2_SEL {} ; catch {set W2_SEL [.rdw.p.t get sel.first sel.last]}
set W2_OWN [rw_w selection own -selection PRIMARY]
set W2_PRIM {} ; catch {set W2_PRIM [selection get -selection PRIMARY]}
catch {clipboard clear}
catch {event generate .rdw.p.t <<Copy>> -when now}
catch {update}
set W2_CLIP {} ; catch {set W2_CLIP [clipboard get]}
check {W2b COPYABLE: -exportselection is 1, a select-all really owns the X PRIMARY selection, `selection get` hands back the pane's own text, and Ctrl-C puts it on the clipboard - the whole reason this window is not a CIW dump} \
  [list [rw_w .rdw.p.t cget -exportselection] \
        [expr {[string length $W2_SEL] > 40 ? 1 : 0}] \
        [rw_has $W2_SEL {@r.xr1.x0.rend1}] \
        $W2_OWN \
        [expr {$W2_PRIM eq $W2_SEL ? 1 : 0}] \
        [expr {$W2_CLIP eq $W2_SEL ? 1 : 0}]] \
  [list 1 1 1 .rdw.p.t 1 1]

# --- W3 newest on top, and the pane really scrolls ---------------------------
rw_ans ::rdw::push [rw_block [rw_ansd [dict create {@m.x1.mA} {{id 1}}] {} {} 0 ok] \
                              [rw_ctx {MA:/} {@m.x1.mA} op MA]]
rw_ans ::rdw::push [rw_block [rw_ansd [dict create {@m.x1.mB} {{id 2}}] {} {} 0 ok] \
                              [rw_ctx {MB:/} {@m.x1.mB} op MB]]
catch {update idletasks}
set W3_FIRST [string trim [rw_w .rdw.p.t get 1.0 1.end]]
set W3_IDXA [string first {MA:/} [rw_w .rdw.p.t get 1.0 end]]
set W3_IDXB [string first {MB:/} [rw_w .rdw.p.t get 1.0 end]]
check {W3 NEWEST DUMP ON TOP: the second push is the FIRST block in the store and the FIRST line in the pane, and the older one is pushed below it} \
  [list $W3_FIRST \
        [expr {[info exists ::rdw::blocks] && [llength $::rdw::blocks] > 0
               && [lrange [lindex [lindex $::rdw::blocks 0] 0] 0 1] eq {hdr MB:/} ? 1 : 0}] \
        [expr {$W3_IDXB >= 0 && $W3_IDXA > $W3_IDXB ? 1 : 0}]] \
  {MB:/ 1 1}

set W3_BIG {}
for {set i 0} {$i < 200} {incr i} { lappend W3_BIG [list p$i $i] }
rw_ans ::rdw::push [rw_block [rw_ansd [dict create {@m.x1.mbig} $W3_BIG] {} {} 0 ok] \
                              [rw_ctx {MBIG:/} {@m.x1.mbig} op MBIG]]
catch {update}
set W3_YV [rw_w .rdw.p.t yview]
check {W3b a dump longer than the pane really scrolls: the vertical view spans less than the whole buffer and the scrollbar is mapped} \
  [list [expr {[llength $W3_YV] == 2 && [lindex $W3_YV 1] < 0.9 ? 1 : 0}] \
        [rw_w winfo ismapped .rdw.p.ys]] \
  {1 1}

# --- W4 the button column, greyed per spec 4.2 B7, and INERT -----------------
## ⚠ B5 WIRES THESE. B3 builds the column, the greying and a test-drivable path
## to each button, and nothing else. Decision 1 (rule debt
## 1245_B3_add_greyed_on_list1): Add on the annotation list is GREYED, not
## absent — the column keeps a constant shape as the user switches lists, and
## an absent button moves the other four under the pointer.
set W4_MISS {}
foreach {id label} {up Up down Down delete Delete add Add save Save} {
  set w .rdw.b.$id
  if {[rw_w winfo exists $w] ne {1}} { lappend W4_MISS $id=MISSING ; continue }
  if {[rw_w winfo class $w] ne {Button}} { lappend W4_MISS $id=[rw_w winfo class $w] }
  if {[rw_w $w cget -text] ne $label} { lappend W4_MISS $id=[rw_w $w cget -text] }
}
set W4_STATES {}
foreach kind {annotation summary all} {
  rw_ans ::rdw::set_list $kind
  catch {update idletasks}
  set row {}
  foreach id {up down delete add save} {
    lappend row [rw_w .rdw.b.$id cget -state]
    if {[rw_w .rdw.b.$id cget -state] ne [rw_ans ::rdw::button_state $id $kind]} {
      lappend W4_MISS $kind/$id=WIDGET-DISAGREES-WITH-TABLE
    }
  }
  lappend W4_STATES $row
}
check {W4 the five buttons exist with the spec's labels, and the widget greying follows spec 4.2 B7 across all three lists AND agrees with the pure table: Add greyed on the annotation list, Delete greyed on `all`} \
  [list $W4_MISS $W4_STATES] \
  [list {} [list {normal normal normal disabled normal} \
                 {normal normal normal normal normal} \
                 {normal normal disabled normal normal}]]

## ⚠ REWRITTEN BY ITEM B5. This row used to assert that every enabled button was
## INERT and said so, naming the literal `B5`. B5 is the item that wires them,
## so the golden it locked is now a statement B5's own deliverable must falsify.
## THE OBLIGATION DOES NOT LAPSE WITH THE INERTNESS - it sharpens: an enabled
## button that DOES something and says nothing is exactly as indistinguishable
## from a broken one as an inert one was (calc::inert's own reason,
## calculator.tcl:607). So the row now asserts the same three things about a
## WIRED column: each enabled button routes to rdw::button and nothing else,
## each one still writes a status line, and it no longer claims it is unwired.
## ⚠ IT PRESSES Up AND Delete, NEVER Save. `conf_path project` is
## `[pwd]/.xschem/...` and this suite runs at the repo root; a Save here would
## drop a settings file on the developer's tree (hard rule 6). Section BT owns
## the Save press and `cd`s first.
## ⚠ THE TWO PRESSES ARE BOTH REFUSALS, AND THE TARGET IS PINNED TO LINE 1 SO
## THEY STAY THAT WAY. Section W runs BEFORE section BT, so the scope dialog
## here is the REAL one; a Delete or an Add that reached a valid parameter row
## would raise a modal with nobody to click it and HANG the suite - issue 0803,
## the item's single largest risk. Line 1 is a block header, so both buttons
## refuse before any dialog, any store call or any file. They are told apart by
## the rule this row exists to hold: EVERY message rdw::button writes NAMES THE
## BUTTON IT CAME FROM, which is rdw::inert's own obligation surviving the
## wiring.
rw_ans ::rdw::set_list summary
rw_ans ::rdw::set_row 1
catch {update idletasks}
set W4_CMDS {}
foreach id {up down delete add save} {
  lappend W4_CMDS [rw_has [rw_w .rdw.b.$id cget -command] "rdw::button $id"]
}
rw_ans ::rdw::status {}
rw_w .rdw.b.up invoke
set W4_MSG1 [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]
rw_ans ::rdw::status {}
rw_w .rdw.b.add invoke
set W4_MSG2 [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]
rw_ans ::rdw::status {}
check {W4b every ENABLED button routes to rdw::button and SAYS what happened in the window's own status line, each message NAMES ITS OWN BUTTON so two of them are never the same sentence, no button still claims it is not wired yet, and no scope dialog was raised - a modal nobody can click is issue 0803} \
  [list $W4_CMDS \
        [expr {$W4_MSG1 ne {} && $W4_MSG1 ne {NOVAR} ? 1 : 0}] \
        [rw_has $W4_MSG1 {Up}] \
        [expr {$W4_MSG2 ne {} && $W4_MSG2 ne {NOVAR} ? 1 : 0}] \
        [rw_has $W4_MSG2 {Add}] \
        [expr {[string first {not wired yet} $W4_MSG1] < 0 ? 1 : 0}] \
        [expr {[string first {not wired yet} $W4_MSG2] < 0 ? 1 : 0}] \
        [expr {$W4_MSG1 ne $W4_MSG2 ? 1 : 0}] \
        [rw_w winfo exists .rdw.scope] \
        [llength [info commands ::rdw::inert]]] \
  {{1 1 1 1 1} 1 1 1 1 1 1 1 0 0}

## HYGIENE: hand the X PRIMARY selection back and leave no toplevel behind.
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::close
catch {destroy .rdwctl}
catch {update idletasks}
check {W5 the section leaves nothing behind: .rdw and the control toplevel are both destroyed, so the next suite's selection assertions are not looking at this one's PRIMARY} \
  [list [rw_w winfo exists .rdw] [rw_w winfo exists .rdwctl]] {0 0}

} wbig]} {
  check "W SECTION RAISED (a Tk error is a FAIL, not a silent exit-0 banner)" $wbig {}
}

# ============================================================================
# SECTION P — ISSUE 1303: THE UNSNAPPED MOUSE PAIR EXISTS
# ============================================================================
# Until 2026-09-04 `scheduler.c` exposed ONLY `mousex_snap`/`mousey_snap`, while
# every C click path reads the UNSNAPPED `xctx->mousex`/`mousey`. So a Tcl
# canvas pick had no way to resolve the point the user's own click resolved: it
# had to snap, and snapping moves the point up to half a grid step in each axis
# -- exactly the distance that crosses an instance boundary, because instance
# bbox edges are not on grid.
#
# MEASURED on the shipped cmos_inv.sch, one pixel apart:
#     exact   175.175 -199.612  ->  M1
#     snapped 180     -200      ->  R1
# Swept over every instance bbox on that sheet: 23725 points, 1513 (6.4%) miss
# the device entirely, 129 (0.5%) resolve to a DIFFERENT device -- silently.
# That is invariant I3's failure one object out: a results window headed `R1`
# for a click on `M1`, with nothing on screen saying which happened.
#
# ⚠ THE SNAPPED PAIR IS NOT REPLACED AND MUST NOT BE. It is correct for
# everything that PLACES or MOVES geometry -- that is what snapping is for.
# "What is under the pointer" is a different question. P2 holds both.
# RED before the accessor landed: P1, P2.

check {P1 the UNSNAPPED mouse pair is askable from Tcl at all, which it was not before issue 1303} \
  [list [catch {xschem get mousex} p_x] [catch {xschem get mousey} p_y] \
        [expr {[string is double -strict $p_x] ? 1 : 0}] \
        [expr {[string is double -strict $p_y] ? 1 : 0}]] \
  {0 0 1 1}

check {P2 and the SNAPPED pair still answers too, because placing geometry still wants it} \
  [list [catch {xschem get mousex_snap} p_sx] [catch {xschem get mousey_snap} p_sy] \
        [expr {[string is double -strict $p_sx] ? 1 : 0}] \
        [expr {[string is double -strict $p_sy] ? 1 : 0}]] \
  {0 0 1 1}

# ============================================================================
# SECTION N — 1298 AND 1297: THE DOOR OWNS THE ANALYSIS, AND THE ARTICLE AGREES
# ============================================================================
# 1298. `rdw::dump_devpath` is THE SEAM'S ONLY DOOR and the entry point items B4
# and B5 call with contexts they build themselves. Ruling DD-5's "name the
# analysis" sentence was put into the ctx by `rdw::dump` ALONE, so any other
# caller got a DC sweep rendered as an operating point again -- the defect 1282
# was filed and fixed for, walking straight back in through the door the fix did
# not cover. The door now fills `simtype` in the same way it already fills
# `sim`, so DD-5 is a property of the SEAM rather than of one caller.
#
# ⚠ AN EXPLICIT `simtype` IN THE CTX STILL WINS, and `{}` still means "say
# nothing". Both matter: the suite hand-builds contexts, and `_analysis_line`
# deliberately stays silent for `{}` because a failed `xschem raw sim_type` and
# a hand-built ctx produce the same empty string -- a sentence that fired on
# those would be indistinguishable from an honest one.
#
# 1297. The analysis kind comes from the simulator, so `"a $sty analysis"` read
# **"a op analysis"** for the one kind this whole window exists to talk about.
# RED before the fix: ND1, ND3.

## ⚠ THE CONTEXT IS BUILT WITHOUT `simtype`, WHICH IS THE WHOLE ROW. Every
## other context in this file goes through `rw_ctx`, which supplies one -- so
## every existing row exercises the caller that already gets it right, and
## none of them could have seen 1298. Items B4 and B5 build their own.
rw_annot $R_DC
set ND_CTX [dict create header {M1:/xdut/xbg} devpath {@m.x1.m1} instname M1 \
                        sim ngspice]
set ND_T [rw_dumptext {@m.x1.m1} $ND_CTX]
check {ND1 the DOOR names the analysis, so a caller that builds its own context cannot lose ruling DD-5} \
  [expr {[string first [RW_ANALYSIS dc] $ND_T] >= 0 ? 1 : 0}] 1

## An explicit simtype must still win over the door's own read, or every
## hand-built context in this file changes meaning.
set ND_T2 [rw_dumptext {@m.x1.m1} [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1]]
check {ND2 an EXPLICIT simtype in the context still wins over the door's own read} \
  [expr {[string first [RW_ANALYSIS dc] $ND_T2] >= 0 ? 1 : 0}] 0

check {ND3 the article agrees with the analysis kind, so the one word this window exists for is not "a op"} \
  [list [rdw::_article op] [rdw::_article ac] [rdw::_article dc] \
        [rdw::_article tran] [rdw::_article noise]] \
  {an an a a a}

check {ND4 and the not_op refusal uses it, so the sentence reads "an op analysis" and never "a op analysis"} \
  [expr {[string match {*a op *} [rdw::format_answer [rw_ansd {} {} {} 0 not_op] \
            [dict create header H devpath D instname M1 simtype op]]] ? 1 : 0}] 0

# ============================================================================
# SECTION K — ITEM B4: THE KEYS. THE HALF THAT NEEDS NO Tk, ON BOTH ARMS.
# ============================================================================
# ⚠ Never `git checkout --` / `git restore` / `git stash` / `git clean` this
# file to make some patch apply: rows K12..K15 are in no patch, and destroying
# uncommitted work that way cost an earlier agent in this batch ~99 verified
# lines. The sibling suite tests/headless/test_rdw_keys_1245.tcl says the same.
# B4 makes this window reachable from the keyboard: bare 1 / 2 / 3 / 4 in the
# cadence profile only (ruling D-2; stock xschem keeps logic_set). The BINDINGS
# and the verb-noun COMMAND MODE cannot live here — src/cadence_style_rc dies
# at its first `bind` under --nogui — so they are in the sibling suite
# tests/headless/test_rdw_keys_1245.tcl, :99 only. What CAN and MUST run on
# both arms is everything the keys do once the event has arrived: the list
# identity, the noun-verb grammar, the refusals, the store trim, and the
# structural fences over the pick.
#
# Measured on this binary 2026-09-04: `xschem select instance`, `xschem select
# wire`, `xschem selection`, `xschem getprop instance <index> name`, `xschem
# instance_at` and `xschem update_all_sym_bboxes` ALL work under --nogui, so
# none of these rows needs a display and none of them is a display row in
# disguise.
#
# THE CONTRACT (the sibling suite's header carries it in full):
#   rdw::key <annotation|summary|all|refresh>   rdw::_selected_instance
#   rdw::show <inst>   rdw::keep_latest   rdw::_ciw <msg>
#   rdw::pick_start / pick_click / pick_release / pick_end
#   rdw::pick_suspend / pick_resume   rdw::_refresh_pick_gate / rdw::_pick_at
#   cmdmode::register rdw_pick rdw::pick_suspend rdw::pick_resume, at SOURCE
#   time (safe: cmdmode.tcl is pure Tcl and is sourced BEFORE rdw.tcl)
#
# ⚠ THE REFUSAL WORDING IS NOT LOCKED BYTE-FOR-BYTE HERE, AND THAT IS
# DELIBERATE. B3 minted seven user-visible sentences and they are on rule debt
# 1245_B3_window_wording, unratified; B4 mints two more (more than one selected,
# and a selection that is not an instance) and PLAN forbids rewording B3's ad
# hoc. So rows K6/K7/K8 fence the SHAPE the user asked for — "refuse with short
# message in CIW" — one line, pairwise distinct, naming the action to take, and
# NOT double-booked against the window's own sentence. The prose itself goes on
# the same rule debt for the user to rule on.
#
# RED BEFORE B4: K1 K2 K3 K4 K5 K6 K7 K8 K9 K10 K11 — every one for the same
# single reason, that none of the procs above exists. GREEN BEFORE B4: K0, the
# fixture's own control.

## The fixture. A PRIVATE symbol type so no shipped symbol and no PDK
## registration is disturbed, one device that HAS numbers, one that has no
## descriptor at all, and a wire — the four answers rdw::_selected_instance
## has to tell apart.
##
## ⚠ THE DEVPATH TEMPLATE IS ESCAPED AND THAT IS NOT A TYPO. `devpath
## {@m.@path@name}` looks healthy and is measurably wrong: `xschem translate`
## swallows the leading `@m.` and yields `m1`, so ase::op_param_split returns
## the empty list and the seam answers `state ok` with an EMPTY union — the
## fifth silence over a device that has numbers. `{\@m.@path@name}` yields
## `@m.m1` and is gf180_procs.tcl:129's own spelling.
## test_annot_declutter_1244.tcl:1560 registers the UNESCAPED form; do not copy
## that line.
set K_SYM [file join $scratch b4k.sym]
set fd [open $K_SYM w]
puts $fd {v {xschem version=3.4.5 file_version=1.2}
G {}
K {type=b4kdev
format="@spiceprefix@name @pinlist @model"
template="name=M1 model=b4kn spiceprefix=X"
}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
B 5 -22.5 -12.5 -17.5 -7.5 {name=d dir=inout}
T {@name} 0 -40 0 0 0.2 0.2 {}}
close $fd

set K_SCH [file join $scratch b4k.sch]
set fd [open $K_SCH w]
puts $fd "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
N 600 -400 800 -400 {}
C \{$K_SYM\} 300 -300 0 0 \{name=M1\}
C \{$K_SYM\} 300 -120 0 0 \{name=M2\}
C \{devices/res\} 700 -100 0 0 \{name=R1
value=10\}"
close $fd

set fd [open [file join $scratch library.defs] w]
puts $fd "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $fd
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

catch {xschem raw clear}
xschem load $K_SCH
catch {update idletasks}
catch {op_annot::register b4kdev \
  [list devpath {\@m.@path@name} params {{zid zid 0} {zgm zgm 1}}]}
set K_PAIRS {}
foreach d {M1 M2} vi {1.11e-05 2.22e-05} vg {3.33e-04 4.44e-04} {
  catch {lappend K_PAIRS [::op_annot::vector $d zid] $vi [::op_annot::vector $d zgm] $vg}
}
set K_RAW [file join $scratch b4k.raw]
rw_mkraw $K_RAW [list [list {Operating Point} $K_PAIRS {}]]
rw_annot $K_RAW
catch {xschem update_all_sym_bboxes}

## The refusal channel, observed. ciw_echo is DEFINED under --nogui and
## silently does nothing without the widget, so a row that did not stub it
## would assert nothing at all (the rename idiom is
## test_sod_pick_no_select_0204.tcl:139).
set ::K_CIW {}
if {[llength [info commands ciw_echo]]} { rename ciw_echo k_ciw_echo_real }
proc ciw_echo {msg args} { lappend ::K_CIW $msg }

proc k_reset {} { set ::rdw::blocks {} ; set ::K_CIW {} ; catch {xschem unselect_all} }
proc k_nblocks {} {
  if {![info exists ::rdw::blocks]} { return -1 }
  return [llength $::rdw::blocks]
}
proc k_top_hdr {} {
  if {![info exists ::rdw::blocks] || ![llength $::rdw::blocks]} { return NO-BLOCK }
  return [lindex [lindex [lindex $::rdw::blocks 0] 0] 1]
}
## ⚠ NOT `expr {[info exists v] ? $v : {NO-VAR}}`: the list identity is a WORD
## and expr evaluates a bare word as an operand — `annotation` raises "invalid
## bareword". Measured while writing this file.
proc k_listkind {} {
  if {![info exists ::rdw::listkind]} { return NO-VAR }
  return $::rdw::listkind
}
## A block with a known header, for the store rows.
proc k_blk {name} {
  set dp "@m.[string tolower $name]"
  return [rw_block [rw_ansd [dict create $dp {{id 1}}] {} {} 0 ok] \
                   [rw_ctx "$name:/" $dp op $name]]
}

check {K0 CONTROL the fixture is what section K says it is: two devices the ONE name builder resolves and annotates, one instance with no descriptor at all, and a wire - so every row below is about B4 and not about a fixture that missed} \
  [list [rw_ans ::op_annot::devpath M1] [rw_ans ::op_annot::devpath M2] \
        [rw_ans ::op_annot::devpath R1] \
        [expr {[llength $K_PAIRS] == 8 ? 1 : 0}] \
        [xschem instance_at 300 -300] \
        [lindex [rw_w xschem select_at 700 -400] 0]] \
  {@m.m1 @m.m2 {} 1 M1 wire}
xschem unselect_all

# --- K1 K2  key 4: the store trim, and which end is new ----------------------
k_reset
rw_ans ::rdw::status {}
set K1_EMPTY [rw_ans ::rdw::keep_latest]
set K1_N0 [k_nblocks]
set K1_S0 $::rdw::statusmsg
rw_ans ::rdw::status {}
set K1_B [k_blk KONE]
rw_ans ::rdw::push $K1_B
set K1_ONE [rw_ans ::rdw::keep_latest]
check {K1 key 4 on an EMPTY store and on a one-block store changes nothing, raises nothing, and NAMES WHAT IT DID in the window's own status line - a control that silently does nothing cannot be told from a broken one} \
  [list [rw_bad $K1_EMPTY] $K1_N0 [expr {$K1_S0 ne {} ? 1 : 0}] \
        [rw_bad $K1_ONE] [k_nblocks] [k_top_hdr] \
        [expr {$::rdw::statusmsg ne {} ? 1 : 0}]] \
  {0 0 1 0 1 KONE:/ 1}

k_reset
foreach n {KA KB KC} { rw_ans ::rdw::push [k_blk $n] }
set K2_N0 [k_nblocks]
set K2_TOP0 [k_top_hdr]
rw_ans ::rdw::keep_latest
check {K2 three distinct blocks, key 4 leaves exactly ONE and it is the NEWEST - asserted by that block's own header text, never by index alone - and STRUCTURAL its body reads rdw::_insert_index, the same accessor rdw::push uses, so the store and the pane cannot disagree about which end is new} \
  [list $K2_N0 $K2_TOP0 [k_nblocks] [k_top_hdr] \
        [rw_has [rw_body ::rdw::keep_latest] {_insert_index}]] \
  {3 KC:/ 1 KC:/ 1}

# --- K3  the four answers of the selection reader ----------------------------
## ⚠ COPIES cadence::one_instance_selected's MEASUREMENT, NOT ITS CALL.
## rdw.tcl is installed and sourced by stock xschem; utils/cadence_nav.tcl is
## neither, so a cross-call would make an installed helper depend on a profile
## file that may not be there. The measurement is `xschem get lastsel` then the
## row TYPE — never `llength [xschem selected_set]`, which throws on an
## instance name holding an unbalanced brace (issue 0388) and which filters
## wires away entirely, so a single selected WIRE would read as "nothing
## selected" and the key would arm the pick mode over a live selection.
xschem unselect_all
set K3_NONE [rw_ans ::rdw::_selected_instance]
xschem select instance M1
set K3_ONE [rw_ans ::rdw::_selected_instance]
xschem select instance M2
set K3_MANY [rw_ans ::rdw::_selected_instance]
xschem unselect_all
xschem select wire 0
set K3_WIRE [rw_ans ::rdw::_selected_instance]
set K3_LASTSEL [xschem get lastsel]
xschem unselect_all
check {K3 rdw::_selected_instance's four answers, including the trap a count-only test passes: ONE selected WIRE has lastsel 1 and is NOT an instance, and the name comes from getprop on the row's own index} \
  [list $K3_NONE $K3_ONE $K3_MANY $K3_WIRE $K3_LASTSEL] \
  [list {none {}} {one M1} {many {}} {notinst {}} 1]

# --- K4 K5  the list identity, and the one key that does not touch it --------
xschem unselect_all
xschem select instance M1
rw_ans ::rdw::set_list annotation
set K4 {}
foreach k {annotation summary all} {
  rw_ans ::rdw::key $k
  lappend K4 [k_listkind] [rw_ans ::rdw::button_state add [k_listkind]] \
             [rw_ans ::rdw::button_state delete [k_listkind]]
}
check {K4 keys 1/2/3 move the list identity through rdw::set_list - B3's ONE setter - and the button table follows in step across all three lists, so no second list-identity variable is minted} \
  [list $K4 [rw_has [rw_body ::rdw::key] {set_list}]] \
  [list {annotation disabled normal summary normal normal all normal disabled} 1]

k_reset
xschem select instance M1
rw_ans ::rdw::key summary
rw_ans ::rdw::key annotation
rw_ans ::rdw::key summary
set K5_N0 [k_nblocks]
rw_ans ::rdw::key refresh
xschem unselect_all
check {K5 key 4 is the ONLY one of the four that leaves the list identity alone: pressed straight after key 2 the list is still summary, and the store it just trimmed holds one block} \
  [list $K5_N0 [k_listkind] [k_nblocks]] \
  [list 3 summary 1]

# --- K6 K7 K8  the refusals, and the channel that must NOT be double-booked --
xschem unselect_all
xschem select instance M1
xschem select instance M2
set ::K_CIW {}
set K6_MANYR [rw_ans ::rdw::key annotation]
set K6_MANY [lindex $::K_CIW 0]
xschem unselect_all
xschem select wire 0
set ::K_CIW {}
set K6_NIR [rw_ans ::rdw::key annotation]
set K6_NI [lindex $::K_CIW 0]
xschem unselect_all
proc k_oneline {s} { return [expr {[string first "\n" $s] < 0 && [string trim $s] ne {} ? 1 : 0}] }
check {K6 the two key-level refusals - more than one selected, and a single selection that is not an instance - are pairwise distinct, ONE line each, name the action to take, and go to the CIW, which is where the user asked for them} \
  [list [rw_bad $K6_MANYR] [rw_bad $K6_NIR] \
        [k_oneline $K6_MANY] [k_oneline $K6_NI] \
        [expr {$K6_MANY ne $K6_NI ? 1 : 0}] \
        [string match -nocase {*select*} $K6_MANY] \
        [string match -nocase {*select*} $K6_NI]] \
  {0 0 1 1 1 1 1}

k_reset
xschem select instance M1
xschem select instance M2
set K7_SEL0 [xschem selection]
set ::K_CIW {}
rw_ans ::rdw::key annotation
set K7_SEL1 [xschem selection]
xschem unselect_all
check {K7 a key-level refusal pushes NO block and leaves xschem selection BYTE-IDENTICAL - the refusal path may touch neither the store nor the user's selection} \
  [list [expr {$K7_SEL0 ne {} ? 1 : 0}] [k_nblocks] \
        [expr {$K7_SEL1 eq $K7_SEL0 ? 1 : 0}] [llength $::K_CIW]] \
  {1 0 1 1}

k_reset
xschem select instance M1
rw_ans ::rdw::key annotation
set K8_N1 [k_nblocks]
set K8_H1 [k_top_hdr]
set K8_T1 [rw_ans ::rdw::block_text [lindex $::rdw::blocks 0]]
set K8_C1 [llength $::K_CIW]
k_reset
xschem select instance R1
rw_ans ::rdw::key annotation
set K8_N2 [k_nblocks]
set K8_T2 [rw_ans ::rdw::block_text [lindex $::rdw::blocks 0]]
set K8_C2 [llength $::K_CIW]
xschem unselect_all
check {K8 THE TWO CHANNELS ARE NOT DOUBLE-BOOKED: one instance selected pushes exactly ONE block whose header names it, with its numbers and ZERO CIW lines, and an instance with NO descriptor still pushes a BLOCK carrying B3's locked no_devpath sentence and ZERO CIW lines - the window speaks whenever a device resolved} \
  [list $K8_N1 $K8_H1 [rw_has $K8_T1 {zid : 11.1u}] $K8_C1 \
        $K8_N2 [k_top_hdr] [rw_has $K8_T2 [RW_NODEVPATH R1]] $K8_C2] \
  [list 1 {M1:/} 1 0 1 {R1:/} 1 0]

# --- K9  the headless safety, and the contract registration ------------------
## ⚠ THE pick_start LEG IS A CONSTANT ON THE DISPLAY ARM AND SAYS SO. On :99
## the mode really does arm, which is the sibling suite's whole section V; here
## the question is only that a key pressed with no Tk at all arms nothing and
## raises nothing. The suspend arm's leg runs on BOTH arms and matters on both:
## once registered it runs on EVERY descend in EVERY profile forever, so "0 and
## no damage when there is nothing to release" is a permanent obligation.
k_reset
set K9_KEY [rw_ans ::rdw::key annotation]
set K9_PS [expr {$live_tk ? 0 : [rw_ans ::rdw::pick_start]}]
rw_ans ::rdw::pick_end
set K9_SUS [rw_ans ::rdw::pick_suspend]
set K9_REG [expr {[lsearch -exact [rw_ans ::cmdmode::registered] rdw_pick] >= 0 ? 1 : 0}]
check {K9 the --nogui safety and the cmdmode registration in one row: key 1 with nothing selected raises nothing and arms no mode when have_tk is 0, the suspend arm returns 0 and damages nothing when no mode is live, and cmdmode carries rdw_pick beside ase_sod - green on the headless arm proving it was registered at SOURCE time with no Tk} \
  [list [rw_bad $K9_KEY] $K9_PS $K9_SUS $K9_REG] \
  {0 0 0 1}

# --- K10 K11  the structural fences over the pick ----------------------------
## `xschem instance_at` is READ-ONLY and `xschem select_at` is the mutating
## twin. Measured on this binary at one instance bbox centre: instance_at
## answers the instance and leaves `xschem selection` empty with lastsel 0,
## while select_at at the SAME point answers `poly 0 2 698` and sets lastsel 1
## — it does not merely select, it selects a DIFFERENT OBJECT. That is the
## sharpest argument there is for the brief's "do not use select_at".
set K10_PC [rw_body ::rdw::pick_click]
set K10_ORDER 0
if {![rw_bad $K10_PC]} {
  set _r [string first {_refresh_pick_gate} $K10_PC]
  set _p [string first {_pick_at} $K10_PC]
  set K10_ORDER [expr {$_r >= 0 && $_p >= 0 && $_r < $_p ? 1 : 0}]
}
set K10_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]
check {K10 STRUCTURAL the pick reads the canvas ONLY through rdw::_pick_at -> xschem instance_at, names select_at / select_object / unselect_all nowhere in the file, and rdw::pick_click calls rdw::_refresh_pick_gate BEFORE it in its own body} \
  [list [rw_has [rw_body ::rdw::_pick_at] {instance_at}] \
        [rw_has [rw_body ::rdw::_refresh_pick_gate] {update_all_sym_bboxes}] \
        [rw_count $K10_F {select_at}] [rw_count $K10_F {select_object}] \
        [rw_count $K10_F {unselect_all}] $K10_ORDER] \
  {1 1 0 0 0 1}

set K11_N 0
foreach p {::rdw::key ::rdw::show ::rdw::keep_latest ::rdw::pick_start \
           ::rdw::pick_click ::rdw::pick_end} {
  if {[llength [info commands $p]]} { incr K11_N }
}
set K11_TAGS 0
foreach p {::rdw::key ::rdw::show ::rdw::keep_latest ::rdw::pick_start \
           ::rdw::pick_click ::rdw::pick_end ::rdw::_ciw} {
  set b [rw_body $p]
  if {[rw_bad $b]} continue
  foreach t {{[list hdr } {[list dim } {[list dev } {[list note }} {
    incr K11_TAGS [rw_count $b $t]
  }
}
## ⚠ THE `op_param_lists:: == 0` TERM MOVED TO ROW BT22 (item B5). Issue 1300's
## substance is unchanged and is fenced by the six KEY procs still existing and
## by BT22's allow-list: the KEYS still select a list IDENTITY and narrow no
## CONTENT. What is no longer true is that the FILE never names the store - B5's
## button column is the store's first caller, by design.
check {K11 STRUCTURAL row S1's fence re-run over the grown file: the six key procs are all still here so keys 1/2/3 select a list IDENTITY and narrow no CONTENT (issue 1300), and no new proc builds a block line by hand - every line still goes through rdw::_line, row F29's rule} \
  [list $K11_N $K11_TAGS \
        [rw_has $K10_F {ase::backend_hook}]] \
  {6 0 1}

# --- K12  A REFUSED KEY CHANGES NOTHING --------------------------------------
## THE HOLE B4 SHIPPED, AND NO ROW SAW IT. rdw::key called rdw::set_list BEFORE
## it resolved the selection, so a key the feature then REFUSED had already
## moved ::rdw::listkind and re-greyed the button column. Rows K4 and K6/K7/K8
## between them assert that the list moves on an accepted key and that a refusal
## pushes no block and touches no selection -- and none of them asks what the
## list identity is AFTER a refusal. A refusal must change nothing at all: the
## user pressed a key, was told why it did not apply, and the window is in the
## state they left it in.
k_reset
rw_ans ::rdw::set_list annotation
set K12_LK0 [k_listkind]
set K12_BS0 {}
foreach id {up down delete add save} {
  lappend K12_BS0 [rw_ans ::rdw::button_state $id [k_listkind]]
}
xschem select instance M1
xschem select instance M2
set ::K_CIW {}
set K12_MANYR [rw_ans ::rdw::key summary]
set K12_MANY [list [llength $::K_CIW] [k_listkind] [k_nblocks]]
set K12_BS1 {}
foreach id {up down delete add save} {
  lappend K12_BS1 [rw_ans ::rdw::button_state $id [k_listkind]]
}
xschem unselect_all
## and the other refusal shape, which reaches the same door by a different arm.
k_reset
rw_ans ::rdw::set_list annotation
xschem select wire 0
set ::K_CIW {}
set K12_NIR [rw_ans ::rdw::key all]
set K12_NI [list [llength $::K_CIW] [k_listkind] [k_nblocks]]
xschem unselect_all
check {K12 A REFUSED KEY CHANGES NOTHING: with two instances selected, and again with a single WIRE selected, the key emits its one CIW line and leaves the list identity, the button table and the store exactly where they were - B4 moved the list first and refused second, so a refusal re-labelled the window with a list the user never got} \
  [list $K12_LK0 [rw_bad $K12_MANYR] $K12_MANY \
        [expr {$K12_BS1 eq $K12_BS0 ? 1 : 0}] \
        [rw_bad $K12_NIR] $K12_NI] \
  [list annotation 0 {1 annotation 0} 1 0 {1 annotation 0}]

# --- K13  STRUCTURAL, ISSUE 1303: WHICH MOUSE PAIR THE PICK READS ------------
## `xschem get mousex` / `mousey` are the UNSNAPPED pair every C click path
## reads (scheduler.c:5047 and :5051, landed 2026-09-04); `mousex_snap` /
## `mousey_snap` (:5055, :5059) are the SNAPPED pair, which is correct for
## placing and moving geometry and wrong for "what is under the pointer".
## Measured on the shipped cmos_inv.sch, one pixel apart: the exact point
## answers M1 and the snapped point answers R1.
##
## ⚠ THE RAW BODY, NOT rw_body. rw_body strips whole-line comments, and the
## point of the second half of this row is that the proc's own PROSE must not
## still say it reads the snapped pair -- a file that argues against its own
## code is how this batch has repeatedly re-derived the same fact. So the
## comment says "the snapped pair" in words and the tokens appear nowhere.
set K13_RAW [rw_w info body ::rdw::pick_click]
check {K13 STRUCTURAL (issue 1303) rdw::pick_click defaults its coordinates from the UNSNAPPED mouse pair, and the snapped spellings appear nowhere in the proc - not in its code and not in its comment, which must describe the pair it does not use in words} \
  [list [rw_bad $K13_RAW] \
        [rw_has $K13_RAW {xschem get mousex]}] [rw_has $K13_RAW {xschem get mousey]}] \
        [rw_count $K13_RAW {mousex_snap}] [rw_count $K13_RAW {mousey_snap}]] \
  {0 1 1 0 0}

# --- K14  STRUCTURAL, ISSUE 1304: THE SEIZE AND THE HAND-BACK AGREE ----------
## The seize was copied from ase::ui::select_on_design, which takes the press,
## the release and Escape and NOT <B1-Motion> -- so C's rubber band starts on
## the first motion with Button 1 held (callback.c:7250-7260) and never
## terminates, because its only terminator is the ButtonRelease the seize eats
## (callback.c:9748). Measured: an 8-step drag left twenty objects selected and
## ui_state still carrying STARTSELECT after a real ESC, against the user's own
## "This is a command mode, so clicking will not change selected set."
##
## ⚠ HARDENED BY ITEM B4-3, BECAUSE THE ROW AS B4-2 WROTE IT PASSED FOR THE
## WRONG REASON. It asked only whether each SEQUENCE NAME appeared in both
## bodies, through rw_has, which is `string first`. MEASURED on a copy by this
## item's Measure agent: replacing the seize's fourth line with
## `bind $cv <B1-Motion> {}` -- which DESTROYS the binding, i.e. restores the
## pre-1304 hole exactly -- left this row GREEN and the whole suite result
## byte-identical on both arms. A fence that is green against a seizing bind
## AND against a destroying one fences nothing, and passing for the wrong
## reason is the failure this batch has now hit six times. So the row reads the
## SCRIPT, not the name, in three independent ways:
##   TAKE     the seize's own line-anchored `bind $cv <seq> <script>` exists
##            and its script is neither empty nor the two-character string {} .
##   GIVE     pick_release writes that sequence back from a stored pick(...)
##            element, never from a literal.
##   PAIRING  the element the seize LATCHED for a sequence is the element the
##            release GIVES BACK for that same sequence.
##
## ⚠ THE PAIRING LEG IS NOT DECORATION. Measured on this tree: all four of
## .drw's predecessors are the EMPTY STRING, so a crossed restore -- Escape
## handed back the motion's predecessor and vice versa -- is byte-invisible to
## every behavioural row in the sibling suite, which compares the restored
## slots against those same empty strings. This is the only fence that sees it.
##
## ⚠ COMMENT-STRIPPED BODIES (rw_body), so a comment quoting a bind line cannot
## satisfy a leg, and the empty-brace literal is built with `format %c%c`: an
## unbalanced brace written literally in this file would make the WHOLE file
## fail `info complete` and stop loading, with no test to say so.
set K14_SZ [rw_body ::rdw::_pick_seize]
set K14_RL [rw_body ::rdw::pick_release]
set K14_MT [format %c%c 123 125]
set K14_TAKE 0 ; set K14_GIVE 0 ; set K14_PAIR 0
foreach seq {<ButtonPress-1> <ButtonRelease-1> <Key-Escape> <B1-Motion>} {
  set re_latch [string map [list SEQ $seq] {set pick\((\w+)\)\s+\[bind \$cv SEQ\]}]
  set re_take  [string map [list SEQ $seq] {^[ \t]*bind \$cv SEQ[ \t]+(.*)$}]
  set re_give  [string map [list SEQ $seq] {bind \$cv SEQ\s+\$pick\((\w+)\)}]
  set lname {} ; set gname {} ; set script {}
  catch {regexp $re_latch $K14_SZ -> lname}
  catch {regexp -line $re_take $K14_SZ -> script}
  catch {regexp $re_give $K14_RL -> gname}
  set script [string trim $script]
  if {$script ne {} && $script ne $K14_MT} { incr K14_TAKE }
  if {$gname ne {}} { incr K14_GIVE }
  if {$lname ne {} && $lname eq $gname} { incr K14_PAIR }
}
check {K14 STRUCTURAL (issue 1304) the seize takes FOUR sequences with a REAL script - not an emptied one, which destroys the binding and is the pre-1304 hole - the ONE shared hand-back gives all four back from a stored predecessor, and the element latched for a sequence is the element given back for that same sequence. B4-2 asserted only that the sequence NAMES appeared in both bodies, and stayed green under `bind $cv <B1-Motion> {}`} \
  [list [rw_bad $K14_SZ] [rw_bad $K14_RL] $K14_TAKE $K14_GIVE $K14_PAIR] {0 0 4 4 4}

# --- K15  STRUCTURAL: THE DUMP OPENS FIRST, AND DOES NOT KEEP THE KEYBOARD ---
## TWO HOLES IN ONE ROW, both invisible to every behavioural row on this arm.
##  * `rdw::show` must open BEFORE it dumps: rdw::render_pane early-returns when
##    .rdw.p.t does not exist, so a dump without an open puts the block in the
##    store and NOTHING on screen. Every dump row in both suites reads the STORE,
##    which is why deleting the open reds nothing here. The sibling suite's row
##    F2 reads the PANE; this row reads the ORDER.
##  * rdw::open must not take the keyboard. The command mode's Escape lives on
##    the CANVAS, and on the FIRST map of a session the window manager's own
##    map-time focus grant beats a synchronous focus -force -- so the hand-back
##    has to be event driven, armed by the paths that map the window and fired
##    from .rdw's own <FocusIn>. B4's row V8 was written for this and passed,
##    because the row before it had already mapped the window.
set K15_SHOW [rw_body ::rdw::show]
set K15_ORDER 0
if {![rw_bad $K15_SHOW]} {
  set _o [string first {rdw::open} $K15_SHOW]
  set _d [string first {rdw::dump} $K15_SHOW]
  set K15_ORDER [expr {$_o >= 0 && $_d >= 0 && $_o < $_d ? 1 : 0}]
}
set K15_BUILD [rw_body ::rdw::build]
check {K15 STRUCTURAL rdw::show opens the window BEFORE it dumps, rdw::open takes the keyboard nowhere, and the hand-back is event driven - a named rdw::_focus_handback bound to .rdw's own FocusIn in rdw::build, because the window manager's map-time focus grant arrives after any synchronous focus -force} \
  [list $K15_ORDER [rw_count [rw_body ::rdw::open] {focus .rdw}] \
        [expr {[llength [info commands ::rdw::_focus_handback]] ? 1 : 0}] \
        [rw_has $K15_BUILD {<FocusIn>}] [rw_has $K15_BUILD {_focus_handback}]] \
  {1 0 1 1 1}

# --- K16  STRUCTURAL, ISSUE 1306: THE HAND-BACK DECIDES ON WHERE FOCUS LANDED
## B4-2's guard was `if {$w ne {} && $w ne {.rdw}} { return 0 }` and its
## comment argued from BINDTAGS: a toplevel's name is in every child's
## bindtags, so this binding also sees the pane's own FocusIn and %W tells the
## two apart. THAT IS HALF THE MECHANISM AND THE OTHER HALF IS THE DEFECT.
## When focus crosses in from OUTSIDE the window -- `.drw` -> `.rdw.p.t`, which
## is exactly the deliberate click a user makes to select and copy a dump -- X
## ALSO delivers a separate FocusIn to the ANCESTOR `.rdw` with detail
## NotifyNonlinearVirtual, so `%W` is literally `.rdw`, the guard passes, and
## the keyboard is taken off the text. MEASURED with the defect present, on
## :99 under openbox, with the one-shot re-armed by hand:
##     after real dump : focus='.drw'       pending=0
##     after text click: focus='.drw'       pending=0   -> BOUNCED
## against the fixed code, same fixture:
##     after text click: focus='.rdw.p.t'   pending=1   -> KEPT
## The pane is what the whole window exists for -- the user's own stated use is
## pasting these dumps into design-review documents -- so a window that takes
## the keyboard away from its own text at the moment you click into it is worse
## than one that never focuses at all. Rows F3 and F4 of the sibling suite are
## the behavioural half; this row is the headless one.
##
## ⚠ AND THE FIX LINE PRINTED IN ISSUE 1306 AND IN THE ITEM BRIEF DOES NOT
## WORK. Both print `[string match .rdw* [focus]]`. Applied verbatim to a copy
## and measured three times on each arm: STILL BOUNCED, because that glob
## matches the DESCENDANT `.rdw.p.t` exactly as readily as `.rdw`. The
## discriminator that does work is the one the window manager itself supplies:
## its map-time grant lands on the TOPLEVEL (`[focus]` reads `.rdw`) while
## every deliberate landing lands on a CHILD (`[focus]` reads `.rdw.p.t`). So
## the test is the EXACT toplevel, and leg 2 keeps the refuted glob out of the
## tree for good -- describe it in words on a comment LINE, which rw_body
## strips, rather than in code or in a trailing comment.
##
## ⚠ THE ORDER LEG IS NOT COSMETIC. `focus` and `winfo` do not exist under
## --nogui; this proc survives the headless arm only because the focus_pending
## early return fires first. A landing test written ABOVE it would raise on
## every headless dump, and row N2 -- which only SOURCES the file into a bare
## interp -- would not catch it.
set K16_FH [rw_body ::rdw::_focus_handback]
set K16_IP [string first {!$focus_pending} $K16_FH]
set K16_IF [string first {[focus]} $K16_FH]
check {K16 STRUCTURAL (issue 1306) the hand-back decides on WHERE THE KEYBOARD LANDED and not on which window named the event: it reads [focus], compares it against the EXACT toplevel, contains no `string match` glob - the refuted `.rdw*` candidate matches the pane itself - reads the landing strictly BELOW the focus_pending early return so --nogui never evaluates it, and still spends the one-shot} \
  [list [rw_bad $K16_FH] \
        [rw_has $K16_FH {[focus]}] \
        [rw_count $K16_FH {string match}] \
        [rw_has $K16_FH {ne {.rdw}}] \
        [expr {$K16_IP >= 0 && $K16_IF > $K16_IP ? 1 : 0}] \
        [rw_count $K16_FH {set focus_pending 0}]] \
  {0 1 0 1 1 1}

# --- K17  STRUCTURAL, ISSUE 1305: A SUSPENDED MODE IS NOT RE-ARMED IN PLACE --
## rdw::pick_start's "already armed" guard deliberately lets a SUSPENDED mode
## fall through and take the canvas back: pressing 1/2/3/4 during
## hi_descend_pick_arm's multi-frame event-loop wait (xschem.tcl:7707) is an
## ordinary thing to do, and ruling D-2's whole premise is that those keys are
## always live. B4-2 let it fall through WITHOUT clearing pick(suspended), so
## the descend's own cmdmode::resume_all still believed the mode was suspended,
## called rdw::pick_resume, and _pick_seize ran a SECOND time on a canvas that
## was already seized -- latching THE SEIZE'S OWN SCRIPTS as the predecessors.
## MEASURED with the defect present, :99/openbox, driving suspend_all, a real
## <Key-N> on the canvas, resume_all and then a real ESC:
##     after ESC   P='rdw::pick_click; break'  R='break'
##                 E='rdw::pick_end; break'    M='break'
##     second ESC returns 0
## -- a PERMANENT seize. Every click dumps, nothing can be selected by clicking
## again for the rest of the session, <B1-Motion> is `break` so the rubber band
## is dead too, and the mode's own "press ESC to leave" cannot work. That is
## the exact inverse of the user's ruling sentence that a command mode must not
## change the selected set. Row D3 of the sibling suite is the behavioural
## half -- and the keys suite self-SKIPS under --nogui, so this row is the only
## fence issue 1305 has on the headless arm.
##
## THE FIX IS THE ISSUE'S OWN OPTION a1, AND IT IS ALREADY WRITTEN TWELVE LINES
## BELOW ITS OWN BUG: rdw::pick_resume clears the flag with
## `unset -nocomplain pick(suspended)` immediately before ITS _pick_seize, and
## ase::ui::sod_resume (ase_window.tcl:2047) ends the same way. Clearing the
## flag AS PART OF taking the canvas back is the house style, not an invention,
## and it is exactly what cmdmode's ruling D6 latch -- "exactly the first one
## to arrive wins" -- is for: the later resume then finds nothing suspended and
## returns 0.
##
## ⚠ BOTH ORDER LEGS ARE THE ROW'S POINT. BELOW the `winfo exists $cv` guard,
## so a re-arm that could NOT take a canvas leaves the suspend intact for the
## real resume; ABOVE `_pick_seize`, so the flag is gone before the seize.
## ⚠ AND LEG 4 STOPS THE OTHER "FIX". Deleting `![info exists pick(suspended)]`
## from the early-return guard also stops the double seize -- by making a
## suspended mode return 1 and never re-arm at all, silently swallowing the key
## press ruling D-2 says is always live, and destroying the re-arm-in-place
## property row V7 of the sibling suite measures.
set K17_PS [rw_body ::rdw::pick_start]
set K17_IU [string first {unset -nocomplain pick(suspended)} $K17_PS]
set K17_IW [string first {winfo exists $cv} $K17_PS]
set K17_IZ [string first {rdw::_pick_seize} $K17_PS]
check {K17 STRUCTURAL (issue 1305) rdw::pick_start clears the outstanding suspend as part of taking the canvas back - the unset sits BELOW the canvas guard and ABOVE the seize, so a re-arm that could not take a canvas leaves the suspend for the real resume - and the suspended test is still in the early-return guard, so nobody greens 1305 by deleting the fall-through and swallowing the key press instead} \
  [list [rw_bad $K17_PS] \
        [expr {$K17_IU >= 0 ? 1 : 0}] \
        [expr {$K17_IW >= 0 && $K17_IZ >= 0 && $K17_IU > $K17_IW && $K17_IU < $K17_IZ ? 1 : 0}] \
        [rw_has $K17_PS {![info exists pick(suspended)]}]] \
  {0 1 1 1}

# ============================================================================
# SECTION BS — ISSUE 1322: A BLOCK MUST CARRY WHAT IT WAS ABOUT
# ============================================================================
# THIS IS THE DEFECT THAT REVERTED ITEM B5-2, AND IT REPRODUCES AT HEAD WITH NO
# BUTTON CODE AT ALL.
#
# `rdw::header` (rdw.tcl:654) builds a block header as
# "<instname>:<cadence path>" — a RENDERING, not an identity. `rdw::push`
# (:767) is handed ONLY that rendered block and stores nothing else. Nothing in
# the tree clears `::rdw::blocks` on a schematic load (measured:
# BLOCKS_SURVIVED_THE_LOAD = 1), and `keep_latest` is its only shortener. So
# the SOLE surviving trace of which device a block is about is the header
# STRING — and item B5-3's button column re-resolves the NAME half of that
# string against WHATEVER SHEET IS OPEN.
#
# MEASURED AT HEAD 9945ad43, through the reverted patch's OWN `rdw::_subject`
# and `rdw::_edit` sourced into a HEAD session (the repo was not modified):
#   two top-level sheets, each holding an `M1` — the default template name of
#   EVERY device symbol in this tree, i.e. the ORDINARY case —
#     the block on screen is about   ncls / vn.sym
#     _subject answers               type vpdev class pcls cellname vp.sym
#     Delete's verdict               ok
#     Delete says                    "removed gm from the annotation list for
#                                     class pcls."
#     ncls keeps gm; pcls loses it — a device nobody was looking at.
#
# ⚠ THE OBVIOUS GUARD IS ALREADY REFUTED BY MEASUREMENT. Comparing the header's
# PATH half does not catch this: both sheets are top-level, `xschem get
# sch_path` is `.` on both, `rdw::_cadence_path` renders `/` on both, and
# PATHS_EQUAL = 1. THE AXIS IS SHEET IDENTITY, NOT HIERARCHY PATH. Row BS1b is
# that refutation written down so a later reviewer cannot re-propose it.
#
# ⚠ AND THE ADJACENT HOLE IS REAL. `op_param_lists::class` returns the TOKEN
# for a type nobody mapped, BY CONTRACT (op_param_lists.tcl:399-403), and an
# instance whose symbol xschem cannot find answers `op_annot::type` =
# `missing` — the placeholder systemlib/missing.sym (save.c:7281), the same one
# `descend_missing_sym` (actions.c:6049-6063) guards by name. So a `class eq {}`
# guard waves it straight through and the user reads a sentence naming a class
# no PDK ever mapped. Row BS4 closes it AT CAPTURE TIME, which is the only
# place where blank is available as an honest answer.
#
# ============================================================================
# THE CONTRACT THIS SECTION PINS
# ============================================================================
#   rdw::block_subject <block>
#       -> a dict {instname type cellname schname}, or {} when the block
#          carries no subject.  A PURE FUNCTION OF ITS ARGUMENT: it never reads
#          ::rdw::blocks, so a suite that assigns `set ::rdw::blocks {}`
#          directly — three of them do — cannot desync it.
#   rdw::push
#       captures the subject AT PUSH TIME, from the block's OWN header text and
#       the live editor, and returns the STAMPED block.  Its signature does not
#       change: every existing fixture in three suites pushes while the right
#       schematic is loaded, so they all capture the right subject with no
#       edit.
#   the stamp rides INSIDE the header entry, as a THIRD element:
#       {hdr <header text> <subject dict>}
#       so the block stays ONE FLAT LIST OF ENTRIES.  `llength $b` — which
#       rdw::_locate and the patch's BE0/BT3 use as a LINE COUNT — does not
#       move, `block_text` is byte-identical, and render_pane paints the same
#       number of lines.
#   a subject that does NOT resolve is NOT recorded: the header entry keeps its
#       two elements, the block is byte-identical to the unstamped one, and
#       block_subject answers {}.
#
# ⚠ THE CLASS IS DELIBERATELY NOT CAPTURED, AND THAT IS A DECISION, NOT AN
# OVERSIGHT. `op_param_lists::class` is a pure classmap lookup with no sheet
# dependence, so it already has exactly one home (invariant I1); only `type` is
# sheet-dependent. Capturing the class here would also make src/rdw.tcl name
# the `op_param_lists::` namespace, which rows S1 (:2451) and K11 (:2170) gold
# at ZERO occurrences — and the preserved patch moves that same term to its own
# row, so editing it here would guarantee a conflict for item B5-3. B5-3's
# `_subject` derives the class from the captured type.
#
# RED BEFORE THE FIX: BS1 BS1b BS2 BS3 BS4 BS5 (BS6 on the display arm) — every
# one for the same single reason, that `rdw::block_subject` and the capture do
# not exist, so rw_ans answers NOPROC and the header entry has two elements
# instead of three. Nothing here is red for a fixture reason: row BS0 is the
# control that says so.

set BS_DIR [file join $scratch bs1322]
file mkdir $BS_DIR
## Two PRIVATE symbol types, so no shipped symbol and no PDK registration is
## disturbed — and BOTH carry `name=M1` in their template, which is not a
## contrivance: it is what every device symbol in this tree ships.
proc bs_mksym {path type} {
  set fd [open $path w]
  puts $fd "v {xschem version=3.4.5 file_version=1.2}"
  puts $fd "G {}"
  puts $fd "K {type=$type"
  puts $fd {format="@spiceprefix@name @pinlist @model"}
  puts $fd "template=\"name=M1 model=$type spiceprefix=X\""
  puts $fd "}"
  puts $fd "V {}"
  puts $fd "S {}"
  puts $fd "E {}"
  puts $fd "L 4 -20 -20 20 -20 {}"
  puts $fd "B 5 -22.5 -12.5 -17.5 -7.5 {name=d dir=inout}"
  puts $fd "T {@name} 0 -40 0 0 0.2 0.2 {}"
  close $fd
}
proc bs_mksch {path sym} {
  set fd [open $path w]
  puts $fd "v {xschem version=3.4.5 file_version=1.2}"
  puts $fd "G {}"
  puts $fd "V {}"
  puts $fd "S {}"
  puts $fd "E {}"
  puts $fd "C \{$sym\} 300 -300 0 0 \{name=M1\}"
  close $fd
}
set BS_VN [file join $BS_DIR vn.sym]
set BS_VP [file join $BS_DIR vp.sym]
bs_mksym $BS_VN bs_ndev
bs_mksym $BS_VP bs_pdev
set BS_A    [file join $BS_DIR a.sch]
set BS_B    [file join $BS_DIR b.sch]
set BS_MISS [file join $BS_DIR miss.sch]
bs_mksch $BS_A    $BS_VN
bs_mksch $BS_B    $BS_VP
bs_mksch $BS_MISS [file join $BS_DIR nosuch.sym]
## ⚠ THE DEVPATH TEMPLATE IS ESCAPED AND THAT IS NOT A TYPO — section K's own
## comment carries the measurement.
set BS_DESC [list devpath {\@m.@path@name} params {{id ids 0} {gm gm 1}}]
catch {op_annot::register bs_ndev $BS_DESC}
catch {op_annot::register bs_pdev $BS_DESC}

## The subject, read through the ONE public door and never by poking at the
## block's shape, so a change of storage inside the header entry moves one proc
## rather than seven rows.
proc bs_subj {blk} { return [rw_ans ::rdw::block_subject $blk] }
proc bs_key {blk k} {
  set s [bs_subj $blk]
  if {[rw_bad $s]} { return $s }
  if {$s eq {}} { return NOSUBJ }
  if {[catch {dict get $s $k} v]} { return "NOKEY:$k" }
  return $v
}
proc bs_tail {blk k} {
  set v [bs_key $blk $k]
  if {[rw_bad $v] || $v eq {NOSUBJ} || [string match {NOKEY:*} $v]} { return $v }
  return [file tail $v]
}
## A body count that CANNOT pass by the proc being absent.
proc bs_bodycount {cmd needle} {
  set b [rw_body $cmd]
  if {[rw_bad $b]} { return $b }
  return [rw_count $b $needle]
}
## One dump-shaped block for an instance name and device path.
proc bs_mkblk {inst dp} {
  return [rw_block [rw_ansd [dict create $dp {{ids 1.2e-05} {gm 3.4e-05}}] \
                            {} {} 0 ok] \
                   [rw_ctx "$inst:/" $dp op $inst]]
}

catch {xschem raw clear}
set ::rdw::blocks {}
rw_ans ::rdw::close

# --- BS0  THE CONTROL. Without it every row below could be about a fixture ---
xschem load $BS_A
catch {update idletasks}
set BS_ATYPE [rw_ans ::op_annot::type M1]
set BS_ACELL [file tail [rw_ans xschem getprop instance M1 cell::name]]
set BS_ASCH  [file tail [rw_ans xschem get schname]]
set BS_AHDR  [rw_ans ::rdw::header M1]
check {BS0 CONTROL the two-sheet fixture is what section BS says it is: sheet a holds ONE instance named M1, of a private type, whose symbol is vn.sym, and the ONE name builder resolves it - so no row below can be red for a fixture reason} \
  [list $BS_ATYPE $BS_ACELL $BS_ASCH $BS_AHDR \
        [rw_ans xschem get sch_path]] \
  [list bs_ndev vn.sym a.sch {M1:/ @m.m1} .]

# --- BS1  THE TWO-SHEET REPRO, REPRODUCED AND CLOSED -------------------------
set BS_ARAW  [bs_mkblk M1 [lindex $BS_AHDR 1]]
set BS_APUSH [rw_ans ::rdw::push $BS_ARAW]
xschem load $BS_B
catch {update idletasks}
set BS_BTYPE [rw_ans ::op_annot::type M1]
set BS_BSCH  [file tail [rw_ans xschem get schname]]
set BS_STORED [lindex $::rdw::blocks 0]
check {BS1 THE TWO-SHEET REPRO, CLOSED: with two top-level sheets each holding an M1, a block dumped from a.sch still names bs_ndev / vn.sym / a.sch after b.sch is loaded - while a LIVE re-resolution of that same bare name answers bs_pdev, which is the wrong answer item B5-2 shipped} \
  [list $BS_ATYPE $BS_BTYPE [llength $::rdw::blocks] \
        [bs_key $BS_STORED instname] [bs_key $BS_STORED type] \
        [bs_tail $BS_STORED cellname] [bs_tail $BS_STORED schname]] \
  [list bs_ndev bs_pdev 1 M1 bs_ndev vn.sym a.sch]

# --- BS1b  THE PATH GUARD STAYS REFUTED, IN THE SUITE ------------------------
## Written down so a later reviewer cannot spend a pass rediscovering that
## comparing the header's path half catches nothing. The two headers are
## byte-identical; only the captured sheet separates the sheets.
set BS1B_LIVE [lindex [rw_ans ::rdw::header M1] 0]
check {BS1b THE PATH GUARD IS REFUTED BY THE FIXTURE ITSELF: the block's header and the header the OTHER sheet builds for its own M1 are BYTE-IDENTICAL, so hierarchy path separates nothing - the captured sheet identity is the only thing that does, and it names a.sch while the editor is showing b.sch} \
  [list [lindex [lindex $BS_STORED 0] 1] $BS1B_LIVE \
        [expr {[lindex [lindex $BS_STORED 0] 1] eq $BS1B_LIVE ? 1 : 0}] \
        [bs_tail $BS_STORED schname] $BS_BSCH] \
  [list {M1:/} {M1:/} 1 a.sch b.sch]

# --- BS2  THE STAMP NEVER REACHES THE PASTE OR THE LINE COUNT ----------------
check {BS2 THE STAMP IS INVISIBLE TO EVERYTHING THAT ALREADY READS A BLOCK: block_text of the stamped block is byte-identical to block_text of the same block before the push, llength is unchanged so the pane's line count and rdw::_locate's arithmetic cannot move, the header entry is still tagged hdr with its header string unchanged - and it really did gain a third element, so this row is not a statement about a stamp that was never applied} \
  [list [expr {[rw_ans ::rdw::block_text $BS_APUSH] eq
               [rw_ans ::rdw::block_text $BS_ARAW] ? 1 : 0}] \
        [expr {[llength $BS_APUSH] == [llength $BS_ARAW] ? 1 : 0}] \
        [lindex [lindex $BS_APUSH 0] 0] [lindex [lindex $BS_APUSH 0] 1] \
        [llength [lindex $BS_ARAW 0]] [llength [lindex $BS_APUSH 0]]] \
  [list 1 1 hdr {M1:/} 2 3]

# --- BS3  A RE-PUSH DOES NOT RE-STAMP AND DOES NOT RE-RESOLVE ----------------
## b.sch is still the open sheet here, so a push that re-captured would answer
## bs_pdev / vp.sym and the block would silently change what it is about.
set BS3_N0 [llength $::rdw::blocks]
set BS3_AGAIN [rw_ans ::rdw::push $BS_STORED]
check {BS3 A RE-PUSH OF AN ALREADY-STAMPED BLOCK, WHILE A DIFFERENT SHEET IS OPEN, neither re-stamps nor re-resolves: the header entry is still exactly three elements, the subject is still the FIRST capture, and the store still grew by one so the guard did not swallow the push} \
  [list [llength [lindex $BS3_AGAIN 0]] [bs_key $BS3_AGAIN type] \
        [bs_tail $BS3_AGAIN cellname] [bs_tail $BS3_AGAIN schname] \
        [expr {[llength $::rdw::blocks] == $BS3_N0 + 1 ? 1 : 0}]] \
  [list 3 bs_ndev vn.sym a.sch 1]

# --- BS4  THE ADJACENT HOLE: NOTHING IS RECORDED THAT CANNOT BE TRUSTED ------
set ::rdw::blocks {}
xschem load $BS_MISS
catch {update idletasks}
set BS4_TYPE [rw_ans ::op_annot::type M1]
set BS4_RAW  [bs_mkblk M1 {@m.m1}]
set BS4_PUSH [rw_ans ::rdw::push $BS4_RAW]
set BS4_NRAW  [bs_mkblk MNOPE {@m.mnope}]
set BS4_NPUSH [rw_ans ::rdw::push $BS4_NRAW]
check {BS4 THE ADJACENT HOLE, CLOSED AT CAPTURE TIME: an instance whose symbol xschem cannot find answers the LITERAL token `missing` and records NO subject, and a header naming an instance that does not exist at all records none either - both blocks come back byte-identical to the unstamped ones, neither raises, and no caller can be handed a class token no PDK maps} \
  [list $BS4_TYPE [bs_subj $BS4_PUSH] [llength [lindex $BS4_PUSH 0]] \
        [expr {$BS4_PUSH eq $BS4_RAW ? 1 : 0}] \
        [bs_subj $BS4_NPUSH] [llength [lindex $BS4_NPUSH 0]] \
        [expr {$BS4_NPUSH eq $BS4_NRAW ? 1 : 0}] \
        [rw_bad $BS4_PUSH] [rw_bad $BS4_NPUSH]] \
  [list missing {} 2 1 {} 2 1 0 0]

# --- BS5  ONE STRUCTURE, NOT TWO --------------------------------------------
## A PARALLEL `::rdw::subjects` LIST WOULD HAVE THREE WRITERS TO KEEP ALIGNED,
## NOT TWO: rdw::push, rdw::keep_latest AND the suites, which assign
## `set ::rdw::blocks {}` DIRECTLY (this file at :1955 and :2420, the keys suite
## at :283). A desynced parallel list answers about the wrong block while every
## existing row stays green — which is this batch's own recurring failure. The
## first leg drives exactly that assignment.
## ⚠ `rw_body` STRIPS WHOLE-LINE `#` COMMENTS AND NOTHING ELSE (row H3's rule),
## so `rdw::block_subject` may and should EXPLAIN itself in prose ABOVE its
## code — what it may not do is name the store in a TRAILING comment, which
## this row cannot tell from a read.
xschem load $BS_A
catch {update idletasks}
set ::rdw::blocks {}
rw_ans ::rdw::push [bs_mkblk M1 {@m.m1}]
set BS5_AFTER_WIPE [bs_key [lindex $::rdw::blocks 0] type]
set BS5_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]
check {BS5 STRUCTURAL ONE STRUCTURE, NOT TWO: after a direct `set ::rdw::blocks {}` - which three suites do - a fresh push still answers the right subject; rdw::block_subject is a PURE FUNCTION of the block it is handed, naming neither `blocks` nor `variable` in its body; the file declares no second store; and the four helpers the sabotage variants target all exist} \
  [list $BS5_AFTER_WIPE \
        [bs_bodycount ::rdw::block_subject {blocks}] \
        [bs_bodycount ::rdw::block_subject {variable}] \
        [expr {$BS5_F eq {NOFILE} ? {NOFILE} : [rw_count $BS5_F {variable subjects}]}] \
        [expr {[llength [info commands ::rdw::block_subject]] ? 1 : 0}] \
        [expr {[llength [info commands ::rdw::_capture_subject]] ? 1 : 0}] \
        [expr {[llength [info commands ::rdw::_stamped]] ? 1 : 0}] \
        [expr {[llength [info commands ::rdw::_subject_resolved]] ? 1 : 0}] \
        [expr {[llength [info commands ::rdw::_hdr_instname]] ? 1 : 0}]] \
  [list bs_ndev 0 0 0 1 1 1 1 1]

# --- BS6  THE DISPLAY ARM: THE STAMP IS INVISIBLE ON SCREEN TOO --------------
if {$live_tk} {
  set ::rdw::blocks {}
  rw_ans ::rdw::open
  set BS6_PUSH [rw_ans ::rdw::push [bs_mkblk M1 {@m.m1}]]
  catch {update idletasks}
  set BS6_TXT [rw_w .rdw.p.t get 1.0 end]
  set BS6_IDX [rw_w .rdw.p.t index end-1c]
  if {[string match {ERR:*} $BS6_IDX]} {
    set BS6_NLINES -1
  } else {
    set BS6_NLINES [expr {[lindex [split $BS6_IDX .] 0] - 1}]
  }
  check {BS6 THE DISPLAY ARM: render_pane paints exactly one line per block ENTRY for a stamped block - so the stamp adds no line and shifts no offset - the pane holds no brace-quoted dict and none of the subject's own words, and the pane text is byte-identical to the block's paste shape} \
    [list [llength [lindex $BS6_PUSH 0]] \
          [expr {$BS6_NLINES == [llength $BS6_PUSH] ? 1 : 0}] \
          [rw_count $BS6_TXT {instname}] [rw_count $BS6_TXT {schname}] \
          [rw_count $BS6_TXT {cellname}] [rw_count $BS6_TXT {bs_ndev}] \
          [expr {[string trimright $BS6_TXT "\n"] eq
                 [string trimright [rw_ans ::rdw::block_text $BS6_PUSH] "\n"] ? 1 : 0}]] \
    [list 3 1 0 0 0 0 1]
}

# --- section BS leaves nothing behind ----------------------------------------
rw_ans ::rdw::close
set ::rdw::blocks {}
catch {xschem raw clear}

# ============================================================================
# ROWS BT29 AND BT30 — RULING DD-16: THE CROSS-SHEET EDIT IS ALLOWED, AND THE
# STATUS LINE NAMES THE SOURCE SHEET ONLY WHEN IT DIFFERS FROM THE OPEN ONE
# ============================================================================
# ⚠ WRITTEN RED, BEFORE ANY PRODUCTION LINE OF THE CLAUSE EXISTED. Measured on
# this binary at HEAD 59ef24af: item B5-a's stamp WORKS — a block dumped on
# a.sch still answers `schname` = a.sch after b.sch is loaded, which is what
# rows BS1 and BS1b above already gold — and NOTHING READS IT. Grep the button
# column's own patch for `schname` and every hit is inside `rdw::_subject`,
# which copies the key into the dict it returns and hands it to nobody. So the
# datum DD-16 needs is present, correct, and unread.
#
# ⚠ THESE TWO ROWS BELONG TO SECTION BT AND THEY SIT HERE, IMMEDIATELY AFTER
# SECTION BS, ON PURPOSE. DD-16's subject IS the two-sheet, two-M1 repro, and
# section BS is where that fixture lives — a.sch and b.sch each holding one
# instance called M1, of two different private types. Rebuilding it a second
# time inside section BT would be two fixtures for one question, which is how
# two suites end up disagreeing about what they are measuring. The row NAMES
# stay BT29/BT30 because they are section BT's questions.
#
# WHAT DD-16 REQUIRES, IN THREE FACTS:
#   1. THE EDIT IS NOT REFUSED. The three lists are class- and flavor-level
#      settings, not sheet state, so editing the `mos` list is correct wherever
#      the user is standing.
#   2. WHEN THE STAMPED SHEET DIFFERS FROM THE OPEN ONE, THE SENTENCE SAYS SO.
#      One line, because `rdw::status` is one line (row BT20).
#   3. WHEN IT DOES NOT DIFFER — OR IS ABSENT — THE SENTENCE IS SILENT ABOUT
#      SHEETS. In the common case the source sheet IS the open one and saying so
#      is noise on every press.
#
# ⚠ FACT 3's SECOND HALF IS LOAD-BEARING AND IS NOT DECORATION. Row BT28 hands
# `rdw::_edit` a HAND-BUILT subject dict carrying instname / type / class /
# cellname AND NO `schname` KEY AT ALL, and the keys suite's SD fixtures do the
# same. Measured: `dict get $subj schname` RAISES on such a dict. A `_sheet_note`
# that reads it unguarded therefore raises from inside the decision core, which
# is a refusal the user never asked for on a path that was working — so ABSENT
# must mean DO NOT NAME THE SHEET, and BT30's second arm drives exactly that.
#
# ⚠ AND THE COMPARISON IS A PLAIN STRING COMPARE, NOT `file normalize` AND NOT
# A DEVICE+INODE IDENTITY. Both values come from the same `xschem get schname`
# accessor, so they are byte-identical whenever they name the same sheet — the
# fixture measures that directly, and it is why no BE/BT/SD row above moves.
# Issue 1327 established that `file normalize` does not resolve a path's final
# component and so establishes no file identity anyway, and `_fid` is a PRIVATE
# store verb that row BT22 golds this file must never name.
#
# BOTH ROWS ARE RED AT HEAD, AND FOR ONE REASON EACH:
#   BT29  the sentence does not name the source sheet (at HEAD, before item
#         B5's patch lands, `rdw::_subject` and `rdw::_edit` do not exist at
#         all and rw_ans answers NOPROC; after the patch and before DD-16 they
#         exist and the sentence simply carries no clause).
#   BT30  its FIRST arm is red for the same NOPROC reason today and is the
#         two-sided partner: it golds the successful sentence BYTE-FOR-BYTE
#         with no clause in it, so a `_sheet_note` that fires unconditionally
#         reds here while BT29 stays green.

set BT_DD16_OLDSCH [rw_ans xschem get schname]
proc bt_dd16_fixture {} {
  rw_ans ::op_param_lists::reset
  catch {op_annot::register bs_ndev $::BS_DESC}
  catch {op_annot::register bs_pdev $::BS_DESC}
  rw_ans ::op_param_lists::said_clear
  set ::rdw::blocks {}
  return {}
}

# --- BT29  THE CROSS-SHEET EDIT, THROUGH SECTION BS's OWN TWO-SHEET FIXTURE --
bt_dd16_fixture
xschem load $BS_A
catch {update idletasks}
rw_ans ::rdw::push [bs_mkblk M1 {@m.m1}]
set BT29_SRC  [bs_tail [lindex $::rdw::blocks 0] schname]
set BT29_SUBJ [rw_ans ::rdw::_subject 0]
xschem load $BS_B
catch {update idletasks}
set BT29_OPEN [file tail [rw_ans xschem get schname]]
set BT29_BASE [rw_ans ::op_param_lists::effective bs_ndev annotation]
set BT29_R    [rw_ans ::rdw::_edit up $BT29_SUBJ annotation governing gm]
set BT29_SAY  [lindex $BT29_R 1]
set BT29_GOT  [rw_ans ::op_param_lists::get_list class bs_ndev annotation]
## ⚠ THE SHEET IS ASSERTED BY TAIL AND BY EXCLUSION, NOT BY A WHOLE SENTENCE.
## `a.sch` is a substring of the tail and of the full path alike, so the row
## does not pre-decide how the clause spells the sheet; the SECOND term is what
## makes it sharp — the OPEN sheet's name must not appear, so a clause that
## named the wrong one of the two would red here and not merely somewhere else.
check {BT29 RULING DD-16 THROUGH THE REAL DECISION CORE: a block dumped on a.sch and edited while b.sch is open is ACCEPTED and not refused, the store really moves, and the ONE-LINE status names the SOURCE sheet a.sch and not the sheet the editor is showing} \
  [list $BT29_SRC $BT29_OPEN $BT29_BASE \
        [lindex $BT29_R 0] \
        [expr {[string first "\n" $BT29_SAY] >= 0 ? 0 : 1}] \
        [rw_has $BT29_SAY {a.sch}] [rw_has $BT29_SAY {b.sch}] \
        $BT29_GOT] \
  [list a.sch b.sch {{id ids 0} {gm gm 1}} ok 1 1 0 {{gm gm 1} {id ids 0}}]

# --- BT30  THE TWO SILENCES --------------------------------------------------
## ARM A — the sheets AGREE. The whole sentence is golded byte for byte, so a
## clause that fires unconditionally cannot hide inside a substring test.
bt_dd16_fixture
xschem load $BS_B
catch {update idletasks}
rw_ans ::rdw::push [bs_mkblk M1 {@m.m1}]
set BT30_SRC  [bs_tail [lindex $::rdw::blocks 0] schname]
set BT30_OPEN [file tail [rw_ans xschem get schname]]
set BT30_SUBJ [rw_ans ::rdw::_subject 0]
set BT30_R    [rw_ans ::rdw::_edit up $BT30_SUBJ annotation governing gm]
set BT30_SAY  [lindex $BT30_R 1]
## ARM B — NO `schname` KEY AT ALL, which is row BT28's own subject shape.
bt_dd16_fixture
set BT30_HB   [dict create instname M1 type bs_ndev class bs_ndev cellname vn.sym]
set BT30_R2   [rw_ans ::rdw::_edit up $BT30_HB annotation governing gm]
set BT30_SAY2 [lindex $BT30_R2 1]
check {BT30 THE TWO SILENCES, so DD-16's clause cannot pass by being unconditional: with the stamped sheet EQUAL to the open one an otherwise identical successful press carries no clause and its sentence is byte-identical to the plain one, and rdw::_edit handed a subject with NO schname key at all - which is exactly what row BT28 passes it - still answers ok, still says nothing about a sheet, and does not raise; the named callee rdw::_sheet_note exists, so a reviewer can neutralise this one sentence and watch one row say so} \
  [list $BT30_SRC $BT30_OPEN \
        [lindex $BT30_R 0] $BT30_SAY \
        [expr {[dict exists $BT30_HB schname] ? 1 : 0}] \
        [lindex $BT30_R2 0] $BT30_SAY2 [rw_bad $BT30_R2] \
        [expr {[llength [info commands ::rdw::_sheet_note]] ? 1 : 0}]] \
  [list b.sch b.sch \
        ok {moved gm up in the annotation list for class bs_pdev.} \
        0 \
        ok {moved gm up in the annotation list for class bs_ndev.} 0 \
        1]

# --- rows BT29/BT30 leave nothing behind -------------------------------------
bt_dd16_fixture
rw_ans ::rdw::close
if {$BT_DD16_OLDSCH ne {} && ![rw_bad $BT_DD16_OLDSCH]} {
  catch {xschem load $BT_DD16_OLDSCH}
} else {
  catch {xschem load $BS_A}
}
catch {update idletasks}
catch {xschem raw clear}

# --- section K leaves nothing behind -----------------------------------------
rw_ans ::rdw::pick_end
rw_ans ::rdw::close
set ::rdw::blocks {}
rw_ans ::rdw::set_list annotation
catch {xschem unselect_all}
catch {xschem raw clear}
catch {rename ciw_echo {}}
if {[llength [info commands k_ciw_echo_real]]} { rename k_ciw_echo_real ciw_echo }

# ============================================================================
# SECTION BT — ITEM B5: THE BUTTON COLUMN AND THE TWO SCOPE DIALOGS
# ============================================================================
# ⚠ WRITTEN RED, BEFORE ANY PRODUCTION LINE OF B5 EXISTED. Every row below was
# run against HEAD 79f163cb and every one of them failed for exactly one
# reason: the procs named in the contract do not exist, `rdw::button` is not a
# command, and `rdw::inert` still is. The ONE exception is BT0, the fixture's
# own control, which is GREEN before the change and is evidence of nothing
# except that no row below can pass vacuously.
#
# The row names are the PLAN's own (BT0 BT1 BT3 BT4 BT6 ... BT23), gaps
# included, so the sabotage table in the item's plan can name a row and mean
# this one. The gaps are not missing rows: they are numbers the plan spent on
# rows that were folded into their neighbours while writing.
#
# ============================================================================
# THE CONTRACT B5 ADDS TO src/rdw.tcl — SPELLED HERE BECAUSE THIS FILE IS
# WHERE IT IS LOCKED
# ============================================================================
#   rdw::set_row {n}          the ONE target setter. `n` is a 1-based PANE LINE
#                             number. It also moves the pane's `insert` mark
#                             when a pane exists, so the widget and the store
#                             cannot disagree about which row is targeted.
#   rdw::_target_line {}      the current target line: the pane's own `insert`
#                             line when a pane exists, the namespace variable
#                             otherwise. 0 when there is none.
#   rdw::_locate {line}       {blockindex entryindex} for a flat pane line, or
#                             {} past the end. PURE — a function of
#                             ::rdw::blocks alone, so it runs under --nogui.
#   rdw::_row_param {entry}   the RAW parameter name of a {}-tagged, non-empty
#                             block entry; {} for hdr / dim / dev / note and
#                             for the separator.
#   rdw::_hdr_instname {line} the exact inverse of rdw::header's join.
#   rdw::_subject {blockindex}  {instname type class cellname ...} for the block
#                             the cursor is in, or {}.
#   rdw::_last_row_why {...}  DD-10's predicate: {} when a Delete is allowed,
#                             else the refusal sentence.
#   rdw::_edit {...}          the pure decision core. Performs the store call
#                             and returns {ok|refused <sentence>}; touches no
#                             Tk, so every sentence is asserted on BOTH arms.
#   rdw::button {id}          THE ONE COMMAND EVERY WIDGET CARRIES. It replaces
#                             rdw::inert, which is DELETED.
#   rdw::scope_dialog {op subject listname}   -> a dict {scope narrow|broad
#                             list annotation|summary}, or {} for Cancel.
#   rdw::scope_dialog_build / rdw::scope_dialog_done   the ase::ui::bus_dialog
#                             split, so the modal never has to be reached to
#                             test the decision (issue 0803).
#   widget paths the suite drives: .rdw.scope , .rdw.scope.sc.narrow ,
#                             .rdw.scope.sc.broad , .rdw.scope.li.annotation ,
#                             .rdw.scope.li.summary , .rdw.scope.btns.ok ,
#                             .rdw.scope.btns.cancel
#
# ============================================================================
# THE SENTENCE CONTRACT — WHAT EACH REFUSAL MUST SAY, AND WHY THESE ARE
# PROPERTY ASSERTIONS AND NOT BYTE GOLDENS
# ============================================================================
# B3 minted seven user-visible sentences and B4 two more, and PLAN forbids
# rewording any of them ad hoc; all of them sit UNRATIFIED on rule debt
# 1245_B3_window_wording. B5 mints nine more. Locking nine unratified strings
# byte-for-byte would gold prose the user has never read, and the first thing
# the user's ruling would do is red nine rows that are about the CODE. So each
# row below fences the SHAPE the sentence must have — one line, non-empty,
# naming the thing the user must act on — plus the load-bearing NOUNS, and the
# prose goes on the same rule debt.
#
# THE ONE EXCEPTION IS DD-10, WHICH THE USER'S OWN RULING SPELLS. Row BT13
# asserts the ruling's clause VERBATIM as a substring, because DECISIONS.md
# writes it out and a ruling's own words are not this item's to reword.
#
# ⚠ AND ONE RULE OVER ALL OF THEM, INHERITED FROM rdw::inert AND FENCED BY ROWS
# W4b, Q9 AND BT15: EVERY MESSAGE rdw::button WRITES NAMES THE BUTTON IT CAME
# FROM. calc::inert (calculator.tcl:607) exists because a control that acts and
# says nothing cannot be told from a broken one; a control that says something
# which does not identify itself is the same failure one step further in, and
# the status line is shared by all five buttons.
#
#   no subject      contains `press 1`   (the user has not dumped anything yet)
#   no parameter row contains `parameter row`
#   Up at the top   contains `first`     Down at the bottom contains `last`
#   not in the list contains the PARAM, the CLASS and the LIST NAME
#   DD-10 annotation contains, verbatim:
#       at least one parameter must stay. To stop showing operating-point
#       values on this device, turn the annotation off instead.
#   DD-10 summary    a DIFFERENT string that does NOT carry the annotation half
#   Cancel          contains `ancel`
#   a live pick mode contains `Escape`
#   a greyed button  contains the button's own label and the list name
#
# ============================================================================
# THE FIXTURE, AND WHY IT IS BUILT RATHER THAN BORROWED
# ============================================================================
# MEASURED at HEAD 79f163cb: a bare headless launch has an EMPTY op_annot
# registry, so `op_param_lists::effective mos annotation` answers {} and every
# list row would be vacuous. Section K's b4kdev fixture has ONE symbol file for
# both of its devices, so a NARROW (cell-name) scope on M1 would also hit M2
# and BT10's "leaves its siblings alone" could not fail.
#
# So this section builds TWO symbol files with TWO type tokens mapped to ONE
# private class — the nmos/pmos shape, which is what makes a class-scope edit
# and a flavor-scope edit tell each other apart — and registers an IHP-SHAPED
# descriptor whose first triple has LABEL != PARAM ({id ids 0}).
#
# ⚠ THAT TRIPLE IS THE WHOLE POINT OF THE FIXTURE. MEASURED on this binary: the
# pane prints the RAW param, `    ids : 12u`, while the store's triple is
# `{id ids 0}`. A button column that looks its row up in the list BY LABEL
# round-trips sky130 and gf180 perfectly and silently misses IHP — the one PDK
# in the tree that distinguishes them, and this batch's own discriminator.
# Every row below therefore targets a pane row whose text says `ids`.
#
# ⚠ AND THE STACKING IS PART OF THE FIXTURE. Two blocks are pushed, M1 FIRST,
# so the M2 block is on top and every row that matters targets a line in the
# OLDER block. A button column that reads `[lindex $::rdw::blocks 0]` — the
# newest — passes every single-block row ever written.
#
# MEASURED PANE LAYOUT, driven out of rdw::format_answer on this binary:
#     1 hdr  M2:/            6 hdr  M1:/
#     2 dim  @m.m2           7 dim  @m.m1
#     3 note (incomplete)    8 note (incomplete)
#     4      ids : 9.9u   9      ids : 12u
#     5      (separator)    10      gm  : 34u
#                           11      gds : 5.6u
#                           12      vgs : 0.5
#                           13      (separator)
#
# ⚠ THIS SECTION NEVER PRESSES SAVE AT THE REPO ROOT. `conf_path project` is
# `[pwd]/.xschem/op_param_lists.conf`, and this suite runs with pwd at the repo
# root, so a Save taken here would drop a settings file on the developer's own
# tree (hard rule 6). The one row that presses Save `cd`s into the scratch tree
# first and `cd`s back; the tier behaviour itself is fenced in the STORE
# suite's section BE, which owns the isolation idiom.
# ============================================================================

set B5_SYMN [file join $scratch b5n.sym]
set B5_SYMP [file join $scratch b5p.sym]
proc b5_mksym {path type} {
  set fd [open $path w]
  puts $fd "v {xschem version=3.4.5 file_version=1.2}"
  puts $fd "G {}"
  puts $fd "K {type=$type"
  puts $fd {format="@spiceprefix@name @pinlist @model"}
  puts $fd "template=\"name=M1 model=$type spiceprefix=X\""
  puts $fd "}"
  puts $fd "V {}"
  puts $fd "S {}"
  puts $fd "E {}"
  puts $fd "L 4 -20 -20 20 -20 {}"
  puts $fd "B 5 -22.5 -12.5 -17.5 -7.5 {name=d dir=inout}"
  puts $fd "T {@name} 0 -40 0 0 0.2 0.2 {}"
  close $fd
}
b5_mksym $B5_SYMN b5ndev
b5_mksym $B5_SYMP b5pdev
set B5_SCH [file join $scratch b5.sch]
set fd [open $B5_SCH w]
puts $fd "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
C \{$B5_SYMN\} 300 -300 0 0 \{name=M1\}
C \{$B5_SYMP\} 300 -120 0 0 \{name=M2\}"
close $fd

catch {xschem raw clear}
set B5_LOAD [catch {xschem load $B5_SCH}]
catch {update idletasks}
## The IHP shape: label `id`, param `ids`, kind 0. `\@m.` is escaped for the
## reason section K's own comment gives — the unescaped form yields `m1` and
## the seam answers the fifth silence over a device that has numbers.
set B5_DESC [list devpath {\@m.@path@name} \
                  params {{id ids 0} {gm gm 1} {gds gds 1}}]
catch {op_annot::register b5ndev $B5_DESC}
catch {op_annot::register b5pdev $B5_DESC}
rw_ans ::op_param_lists::reset
rw_ans ::op_param_lists::set_class b5ndev b5cls
rw_ans ::op_param_lists::set_class b5pdev b5cls

proc b5_cell {n} {
  set c {} ; catch {set c [xschem getprop instance $n cell::name]}
  return $c
}
set B5_CELL1 [b5_cell M1]
set B5_CELL2 [b5_cell M2]
set B5_SEED  {{id ids 0} {gm gm 1} {gds gds 1}}

## The two blocks, built through the renderer so the pane layout above is the
## renderer's own and not this file's opinion of it.
proc b5_blk {inst dp pairs} {
  return [rw_block [rw_ansd [list $dp $pairs] {} {} 0 ok] \
                   [rw_ctx "$inst:/" $dp op $inst]]
}
proc b5_fixture_blocks {} {
  set ::rdw::blocks {}
  rw_ans ::rdw::push [b5_blk M1 @m.m1 {{ids 1.2e-05} {gm 3.4e-05} {gds 5.6e-06} {vgs 0.5}}]
  rw_ans ::rdw::push [b5_blk M2 @m.m2 {{ids 9.9e-06}}]
  return {}
}
## The pane as a flat list of entries, computed from the STORE and not from
## rdw::_locate — a row that read its own subject through the proc under test
## could not see that proc go wrong.
proc b5_flat {} {
  set out {}
  if {![info exists ::rdw::blocks]} { return {} }
  foreach b $::rdw::blocks { foreach e $b { lappend out $e } }
  return $out
}
proc b5_entry {ln} { return [lindex [b5_flat] [expr {$ln - 1}]] }
proc b5_say {} { return [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}] }
## Press one button and hand back what the window SAID about it. The status is
## cleared first, so a button that says nothing is distinguishable from one
## that repeated the previous message.
proc b5_press {id} {
  rw_ans ::rdw::status {}
  rw_ans ::rdw::button $id
  return [b5_say]
}
## A message that is present, ONE LINE, and names <needle>.
proc b5_ok1 {m needle} {
  if {$m eq {} || $m eq {NOVAR} || [string match {NOPROC*} $m]} { return 0 }
  if {[string first "\n" $m] >= 0} { return 0 }
  return [expr {[string first $needle $m] >= 0 ? 1 : 0}]
}
proc b5_owns {scope key ln} { return [rw_ans ::op_param_lists::owns $scope $key $ln] }
proc b5_eff {ln {cell {}}} { return [rw_ans ::op_param_lists::effective b5cls $ln $cell] }
## one key of one descriptor, without a raise: NOPROC / RAISED:... / NOKEY.
## The twin of the store suite's ol_dkey, added by item B5-2 for row BT8.
proc b5_dkey {type key} {
  set d [rw_ans ::op_annot::descriptor $type]
  if {[rw_bad $d]} { return $d }
  if {[catch {dict exists $d $key} e]} { return BADDESC }
  if {!$e} { return NOKEY }
  if {[catch {dict get $d $key} v]} { return "RAISED:$v" }
  return $v
}
proc b5_nsaid {} {
  set s [rw_ans ::op_param_lists::said]
  if {[rw_bad $s]} { return $s }
  if {[catch {llength $s} n]} { return "BADSAID:$s" }
  return $n
}
## ⚠ IT RESETS THE REGISTRY TOO, AND THAT IS NOT TIDINESS. `op_param_lists::apply`
## writes the UNION into the descriptor's `params` (ruling DD-6), and
## `op_param_lists::seed` READS THAT SAME FIELD BACK as "the PDK's own list" -
## so the first successful Delete or Add in this section reorders the seed for
## every row after it, and rows BT18 and BT21, which assert `effective` answers
## the PDK seed EXACTLY, would be reading a value an earlier row wrote. The
## store suite's twin proc `be_reset` (test_op_param_store_1245.tcl) already
## re-registers for this reason; this one did not, which made the two suites
## disagree about what a per-row reset is. Filed as issue 1312.
proc b5_lists_reset {} {
  rw_ans ::op_param_lists::reset
  rw_ans ::op_param_lists::set_class b5ndev b5cls
  rw_ans ::op_param_lists::set_class b5pdev b5cls
  catch {op_annot::register b5ndev $::B5_DESC}
  catch {op_annot::register b5pdev $::B5_DESC}
  rw_ans ::op_param_lists::said_clear
  ## ⚠ AND IT REBUILDS THE BLOCKS, FOR ISSUE 1312'S OWN REASON ONE LAYER OUT
  ## (item R2, issue 1338).  Until R2 an accepted reorder left ::rdw::blocks
  ## byte-identical, so a per-row reset that reset only the STORE was enough.
  ## It is not any more: the pane now follows the store, so the first accepted
  ## Up in this section really does move M1's rows, and every row after it that
  ## names a LINE NUMBER would be pointing at a different parameter than the
  ## layout above documents -- reading a pane an earlier row reordered, which
  ## is exactly what the paragraph above says about a descriptor an earlier row
  ## wrote.  MEASURED: without this, BT8's Up moved `gm` to line 9 and nine
  ## later rows (BT10, BT13, BT14, BT16, BT17, BT21, BT25, BT26, BT27) then
  ## edited the wrong parameter and failed.  ⚠ A store reset with no pane reset
  ## also leaves the two DISAGREEING, which is the one state R2 exists to
  ## prevent -- so this is not merely tidiness, it is the section refusing to
  ## assert from a window the store no longer explains.  Section RE's `re_reset`
  ## was written this way from the start; this one predates it.
  ## The cursor goes with them: `rdw::push` clears it (ruling DD-1), and every
  ## row below already sets its own row before it presses anything.
  b5_fixture_blocks
  return {}
}

## THE DIALOG STUB — `rename`, NEVER `proc`. test_ase_bus_bits_0159.tcl:129-132
## records why: a bare `proc` overwrites the real one and the `rename ... {}`
## that puts it back then DELETES it. The rename is guarded because in the RED
## state there is nothing to rename.
set ::b5_dlg_calls 0
set ::b5_dlg_args {}
set ::b5_dlg_answer {}
if {[llength [info commands ::rdw::scope_dialog]]} {
  rename ::rdw::scope_dialog ::rdw::b5_real_scope_dialog
}
proc ::rdw::scope_dialog {args} {
  incr ::b5_dlg_calls
  set ::b5_dlg_args $args
  return $::b5_dlg_answer
}
proc b5_dlg {answer} { set ::b5_dlg_calls 0 ; set ::b5_dlg_args {} ; set ::b5_dlg_answer $answer }

b5_fixture_blocks

# --- BT0  THE CONTROL --------------------------------------------------------
## GREEN BEFORE THE CHANGE, and that is the point: it says the fixture is live
## so that no row below can pass by asserting something about nothing.
check {BT0 CONTROL the fixture is live: two devices of ONE private class from TWO different cell files, an IHP-shaped seed whose first triple has label != param, nothing owned yet, and a two-block pane whose older block carries four parameter rows} \
  [list $B5_LOAD [rw_ans ::op_annot::type M1] [rw_ans ::op_annot::type M2] \
        [rw_ans ::op_param_lists::class b5ndev] [rw_ans ::op_param_lists::class b5pdev] \
        [rw_ans ::op_param_lists::seed b5cls] [b5_eff annotation] \
        [b5_owns class b5cls annotation] \
        [expr {$B5_CELL1 ne {} && $B5_CELL1 ne $B5_CELL2 ? 1 : 0}] \
        [llength $::rdw::blocks] [llength [b5_flat]] \
        [lindex [b5_entry 9] 1]] \
  [list 0 b5ndev b5pdev b5cls b5cls $B5_SEED $B5_SEED 0 1 2 13 {    ids : 12u}]

# --- BT1  THE HEADER IS INVERTIBLE -------------------------------------------
## rdw::header joins the instance name and the cadence path with a `:`, and an
## instance name may itself contain one. The split must be GREEDY on the last
## `:` that is followed by the path half, which always begins with `/`. The
## row fences the split and the join AS ONE PAIR, so they cannot drift.
check {BT1 rdw::_hdr_instname is the exact inverse of rdw::header's join - for a deep path, for the empty path this fixture actually has, for an instance name that itself carries a colon, and for a line that is not a header at all} \
  [list [rw_ans ::rdw::_hdr_instname {M1:/xdut/xbg/xamp1}] \
        [rw_ans ::rdw::_hdr_instname {M1:/}] \
        [rw_ans ::rdw::_hdr_instname {A:B:/x}] \
        [rw_ans ::rdw::_hdr_instname [lindex [rw_ans ::rdw::header M1] 0]] \
        [rw_ans ::rdw::_hdr_instname {not a header at all}]] \
  {M1 M1 A:B M1 {}}

# --- BT3  THE TARGET IS PURE -------------------------------------------------
## No Tk anywhere in this row: _locate and _row_param are functions of
## ::rdw::blocks and of one block entry. That is what lets the whole button
## column be driven on the --nogui arm, which is where the majority of this
## suite lives.
## ⚠ THE PARAM IS THE RAW NAME. `ids`, never the label `id`.
check {BT3 rdw::_locate maps a flat pane line onto {blockindex entryindex} across TWO stacked blocks and answers {} past the end, and rdw::_row_param answers the RAW param for a parameter row and {} for the header, the device path, the note and the separator} \
  [list [rw_ans ::rdw::_locate 4] [rw_ans ::rdw::_locate 9] \
        [rw_ans ::rdw::_locate 11] [rw_ans ::rdw::_locate 13] \
        [rw_ans ::rdw::_locate 14] [rw_ans ::rdw::_locate 0] \
        [rw_ans ::rdw::_row_param [b5_entry 9]] \
        [rw_ans ::rdw::_row_param [b5_entry 11]] \
        [rw_ans ::rdw::_row_param [b5_entry 12]] \
        [rw_ans ::rdw::_row_param [b5_entry 6]] \
        [rw_ans ::rdw::_row_param [b5_entry 7]] \
        [rw_ans ::rdw::_row_param [b5_entry 8]] \
        [rw_ans ::rdw::_row_param [b5_entry 13]]] \
  {{0 3} {1 3} {1 5} {1 7} {} {} ids gds vgs {} {} {} {}}

# --- BT4  NO SUBJECT, AND NO ROW ---------------------------------------------
## Two different silences, two different sentences. An empty store is "you have
## not dumped anything yet"; a cursor on a header line is "click a parameter
## row". Neither may open a dialog and neither may touch the store.
b5_lists_reset
b5_dlg {scope broad list annotation}
set ::rdw::blocks {}
rw_ans ::rdw::set_list summary
rw_ans ::rdw::set_row 1
set BT4_NOSUBJ {}
foreach id {up down delete add} { lappend BT4_NOSUBJ [b5_ok1 [b5_press $id] {press 1}] }
set BT4_D1 $::b5_dlg_calls
b5_fixture_blocks
rw_ans ::rdw::set_list annotation
set BT4_NOROW {}
foreach ln {6 7 8 13} {
  rw_ans ::rdw::set_row $ln
  lappend BT4_NOROW [b5_ok1 [b5_press up] {parameter row}]
}
check {BT4 with nothing dumped every mutating button refuses and tells the user to press a list key over a device first, and with dumps present a cursor on the header, the device path, the note or the separator refuses and tells them to click a parameter row - neither silence opens a dialog and neither touches the store} \
  [list $BT4_NOSUBJ $BT4_D1 $BT4_NOROW $::b5_dlg_calls \
        [b5_owns class b5cls annotation] [b5_owns class b5cls summary]] \
  {{1 1 1 1} 0 {1 1 1 1} 0 0 0}

# --- BT6  THE PANE'S ROW SET AND THE LIST ARE NOT THE SAME SET ---------------
## `vgs` is published by the run and declared by no list, so it is DRAWN and
## not REORDERABLE. Refusing by name is the only honest answer: a silent no-op
## on a row the user can see is the failure rdw::inert existed to prevent.
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 12
set BT6_M [b5_press up]
check {BT6 a parameter the run published but no list declares is refused BY NAME, naming the class and the list it is not in, and stores nothing - the pane's row set and the list are not the same set} \
  [list [b5_ok1 $BT6_M vgs] [b5_ok1 $BT6_M b5cls] [b5_ok1 $BT6_M annotation] \
        $::b5_dlg_calls [b5_owns class b5cls annotation] [b5_eff annotation]] \
  [list 1 1 1 0 0 $B5_SEED]

# --- BT7  THE BOUNDARY REFUSES, AND THE GREYING DOES NOT MOVE ----------------
## Ladder decision D4: the greying stays keyed on LIST IDENTITY alone. A
## position-dependent grey has to re-grey on every cursor move, which needs a
## new binding on the pane - issue 1306/1308 ground - so the boundary is a
## refusal with a sentence instead.
b5_lists_reset
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 9
set BT7_UP [b5_press up]
rw_ans ::rdw::set_row 11
set BT7_DN [b5_press down]
check {BT7 Up on the first row and Down on the last refuse with a sentence naming the row and its end of the list, the list is byte-identical afterwards, and rdw::button_state has not moved - the greying stays keyed on list identity, never on position} \
  [list [b5_ok1 $BT7_UP ids] [b5_ok1 $BT7_UP first] \
        [b5_ok1 $BT7_DN gds] [b5_ok1 $BT7_DN last] \
        [b5_eff annotation] [b5_owns class b5cls annotation] \
        [rw_ans ::rdw::button_state up annotation] \
        [rw_ans ::rdw::button_state down annotation]] \
  [list 1 1 1 1 $B5_SEED 0 normal normal]

# --- BT8  THE REORDER, AND WHAT IT SAYS --------------------------------------
## With nothing owned the first reorder MATERIALISES the class entry, which is
## DD-2's primary key. Exactly two entries move; the other list is untouched.
b5_lists_reset
set BT8_OWN0 [b5_owns class b5cls annotation]
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 10
set BT8_M [b5_press up]
## ⚠ ITEM B5-2 ADDED THE LAST THREE LEGS, AND THEY CONTRADICT THE PRESERVED
## PATCH. The patch DEFERRED the redraw after a reorder and said so on screen -
## "The drawn order follows on the next Add, Delete or reload (issue 1312)".
## Issue 1312 is FIXED (ruling DD-13, item B2e): `seed` reads the declaration,
## so a reorder can no longer leak through the seed into the summary list nobody
## owns, and store row N4 fences the opposite. The deferral's stated cost is
## gone, and a status line citing a fixed issue as its reason is a false
## statement on a screen the user is reading. So the display key moves NOW, for
## every type token of the class, and the sentence stops citing 1312.
check {BT8 Up on the second row swaps exactly two entries and no more, materialises the class entry DD-2 makes the primary key, leaves the summary list alone, writes the display key for BOTH type tokens at once so the sheet follows immediately, and SAYS what moved - naming the parameter, the list and the scope, and no longer citing a fixed issue as a reason to defer} \
  [list $BT8_OWN0 [b5_owns class b5cls annotation] [b5_eff annotation] \
        [b5_owns class b5cls summary] [b5_eff summary] \
        [b5_ok1 $BT8_M gm] [b5_ok1 $BT8_M annotation] [b5_ok1 $BT8_M class] \
        [b5_dkey b5ndev shown] [b5_dkey b5pdev shown] \
        [expr {[b5_ok1 $BT8_M gm] && [string first {1312} $BT8_M] < 0 \
               && [string first {reload} $BT8_M] < 0 ? 1 : 0}]] \
  [list 0 1 {{gm gm 1} {id ids 0} {gds gds 1}} 0 $B5_SEED 1 1 1 \
        {{gm gm 1} {id ids 0} {gds gds 1}} {{gm gm 1} {id ids 0} {gds gds 1}} 1]

# --- BT9  WHO ASKS THE DIALOG, AND WHO MUST NOT ------------------------------
## The spec's B7 table gives the dialog to Delete and Add and to nothing else.
## A dialog on every reorder makes reordering unusable, and a Save that asks a
## scope question is asking about a decision it is not taking.
## ⚠ THE SAVE LEG `cd`s INTO THE SCRATCH TREE. See this section's header.
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 10
rw_ans ::rdw::button up
set BT9_UP $::b5_dlg_calls
rw_ans ::rdw::button down
set BT9_DN $::b5_dlg_calls
rw_ans ::rdw::set_row 9
rw_ans ::rdw::button delete
set BT9_DEL $::b5_dlg_calls
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::rdw::set_list summary
rw_ans ::rdw::set_row 9
rw_ans ::op_param_lists::set_list class b5cls annotation {{gm gm 1}}
rw_ans ::rdw::button add
set BT9_ADD $::b5_dlg_calls
set BT9_OLDPWD [pwd]
cd $scratch
set ::b5_dlg_calls 0
rw_ans ::rdw::button save
set BT9_SAVE $::b5_dlg_calls
cd $BT9_OLDPWD
## The REAL dialog, unstubbed, on the headless arm only: it must answer {} and
## return, not block. On :99 it would build a window and sit in tkwait, which
## is issue 0803 itself - SD1 of the keys suite drives it there, with a deadman.
set BT9_HEADLESS [expr {$live_tk ? {n/a} : \
  [expr {[llength [info commands ::rdw::b5_real_scope_dialog]] \
         ? [rw_ans ::rdw::b5_real_scope_dialog delete {} annotation] : {NOPROC}}]}]
check {BT9 the scope dialog is consulted EXACTLY ONCE per Delete and once per Add and NEVER for Up, Down or Save, no settings file is dropped on the repo root, and with no Tk at all the real dialog answers Cancel and returns instead of blocking (issue 0803, answered by construction)} \
  [list $BT9_UP $BT9_DN $BT9_DEL $BT9_ADD $BT9_SAVE \
        [expr {[file isdirectory [file join $repo .xschem]] ? 1 : 0}] \
        [expr {$live_tk ? {n/a} : $BT9_HEADLESS}]] \
  [list 0 0 1 1 0 0 [expr {$live_tk ? {n/a} : {}}]]

# --- BT10  NARROW TOUCHES ONE FLAVOR, BROAD MOVES THE CLASS ------------------
## The acceptance sentence, both halves, plus DD-8's shadow. A narrow write is
## a NEW row and file order is precedence, so a `*` entry declared earlier
## still wins - and the button must SAY so rather than looking broken.
b5_lists_reset
b5_dlg [list scope narrow list annotation]
rw_ans ::op_param_lists::set_list flavor [list b5cls $B5_CELL2] annotation {{id ids 0} {gm gm 1}}
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 9
set BT10_M1 [b5_press delete]
set BT10_NARROW [list [b5_owns flavor [list b5cls $B5_CELL1] annotation] \
                      [b5_owns class b5cls annotation] \
                      [rw_ans ::op_param_lists::get_list flavor [list b5cls $B5_CELL2] annotation] \
                      [b5_eff annotation $B5_CELL1]]
b5_lists_reset
b5_dlg [list scope broad list annotation]
rw_ans ::rdw::set_row 9
set BT10_M2 [b5_press delete]
set BT10_BROAD [list [b5_owns class b5cls annotation] \
                     [b5_owns flavor [list b5cls $B5_CELL1] annotation] \
                     [b5_eff annotation $B5_CELL2]]
b5_lists_reset
b5_dlg [list scope narrow list annotation]
rw_ans ::op_param_lists::set_list flavor [list b5cls *] annotation {{id ids 0} {gm gm 1}}
rw_ans ::rdw::set_row 9
set BT10_M3 [b5_press delete]
set BT10_SHADOW [list [b5_owns flavor [list b5cls $B5_CELL1] annotation] \
                      [b5_eff annotation $B5_CELL1]]
check {BT10 narrow scope writes ONE flavor entry and leaves the sibling flavor and the class entry untouched; broad scope moves the CLASS and the sibling cell follows it; and a narrow write an earlier glob already shadows is REPORTED with the order to fix, never left looking like a dead button (DD-8, issue 1311)} \
  [list [b5_ok1 $BT10_M1 ids] $BT10_NARROW \
        [b5_ok1 $BT10_M2 ids] $BT10_BROAD \
        [b5_ok1 $BT10_M3 order] $BT10_SHADOW] \
  [list 1 [list 1 0 {{id ids 0} {gm gm 1}} {{gm gm 1} {gds gds 1}}] \
        1 [list 1 0 {{gm gm 1} {gds gds 1}}] \
        1 [list 1 {{id ids 0} {gm gm 1}}]]

# --- BT12  CANCEL CHANGES NOTHING AT ALL -------------------------------------
b5_lists_reset
b5_dlg {}
rw_ans ::op_param_lists::said_clear
set BT12_D0 [rw_ans ::op_annot::descriptor b5ndev]
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 9
set BT12_M [b5_press delete]
check {BT12 Cancel on the scope dialog changes NOTHING: no key owned, no report added to the store's own log, the descriptor byte-identical, and the window SAYS it was cancelled rather than going silent} \
  [list $::b5_dlg_calls [b5_owns class b5cls annotation] \
        [b5_owns flavor [list b5cls $B5_CELL1] annotation] \
        [b5_nsaid] \
        [expr {[rw_ans ::op_annot::descriptor b5ndev] eq $BT12_D0 ? 1 : 0}] \
        [b5_ok1 $BT12_M ancel]] \
  {1 0 0 0 1 1}

# --- BT13  DD-10: DELETE REFUSES THE LAST ROW --------------------------------
## ⚠ THE ONE BYTE-GOLDEN SENTENCE IN THIS SECTION, AND IT IS THE USER'S OWN.
## DECISIONS.md DD-10 writes it out; a ruling's words are not this item's to
## reword. The second half of the row is what keeps the first half honest: a
## Delete of a TWO-row list succeeds, so the refusal is about the LAST ROW and
## not about Delete.
set B5_DD10 {at least one parameter must stay. To stop showing operating-point values on this device, turn the annotation off instead.}
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::op_param_lists::set_list class b5cls annotation {{id ids 0}}
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 9
set BT13_M [b5_press delete]
set BT13_L1 [b5_eff annotation]
rw_ans ::op_param_lists::set_list class b5cls annotation {{id ids 0} {gm gm 1}}
set BT13_M2 [b5_press delete]
check {BT13 DD-10 Delete refuses to remove the LAST remaining row of the annotation list and says the ruling's own sentence verbatim, the row is still there - and a Delete of a two-row list then succeeds, so the refusal is about the last row and not about Delete} \
  [list [b5_ok1 $BT13_M $B5_DD10] $BT13_L1 \
        [b5_eff annotation] \
        [expr {$BT13_M2 ne $BT13_M ? 1 : 0}]] \
  [list 1 {{id ids 0}} {{gm gm 1}} 1]

# --- BT14  DD-10 ON THE SUMMARY LIST, WITH ITS OWN SENTENCE ------------------
## Ladder decision D5: the ruling's text is unqualified, so the refusal applies
## to BOTH lists - but DD-10's ARGUMENT is annotation-specific (an emptied
## `shown` blanks the block and drops the device out of the declutter), so one
## sentence for both lists would be FALSE about the summary case.
b5_lists_reset
b5_dlg {scope broad list summary}
rw_ans ::op_param_lists::set_list class b5cls summary {{id ids 0}}
rw_ans ::rdw::set_list summary
rw_ans ::rdw::set_row 9
set BT14_M [b5_press delete]
check {BT14 DD-10 on the summary list refuses too, with its OWN sentence - one line, naming the row, and NOT carrying the annotation half of the ruling's wording, which would be false about this list} \
  [list [b5_ok1 $BT14_M ids] \
        [expr {[string first "turn the annotation off" $BT14_M] < 0 ? 1 : 0}] \
        [expr {$BT14_M ne $B5_DD10 ? 1 : 0}] \
        [b5_eff summary] [b5_owns class b5cls summary]] \
  [list 1 1 1 {{id ids 0}} 1]

# --- BT15  THE GREYING IS ALSO A COMMAND-PATH FENCE --------------------------
## The disabled widget is not the only fence. rdw::button consults
## rdw::button_state itself, so a caller reaching the proc directly - a key, a
## menu, a later item - gets the same answer the widget would have given.
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::rdw::set_list all
rw_ans ::rdw::set_row 9
set BT15_DEL [b5_press delete]
rw_ans ::rdw::set_list annotation
set BT15_ADD [b5_press add]
check {BT15 Delete on list 3 and Add on list 1 are refused through rdw::button even when it is invoked directly, quoting the same rdw::button_state table the widget greying reads - and neither opens a dialog nor touches the store} \
  [list [b5_ok1 $BT15_DEL Delete] [b5_ok1 $BT15_DEL all] \
        [b5_ok1 $BT15_ADD Add] [b5_ok1 $BT15_ADD annotation] \
        $::b5_dlg_calls [b5_owns class b5cls annotation]] \
  {1 1 1 1 0 0}

# --- BT16  ADD RE-ADDS THE TRIPLE, VERBATIM ----------------------------------
## Landmine 12 / invariant I1: the KIND is the raw-name SHAPE, and this file
## mints none. Add finds the existing {label param kind} triple by its PARAM
## and re-adds it whole - label `id`, param `ids`, kind 0.
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::op_param_lists::set_list class b5cls annotation {{gm gm 1}}
rw_ans ::rdw::set_list summary
rw_ans ::rdw::set_row 9
set BT16_M [b5_press add]
set BT16_L [rw_ans ::op_param_lists::get_list class b5cls annotation]
check {BT16 Add from the summary list re-adds the triple VERBATIM into the annotation list - label id, param ids, kind 0, all three fields carried - with no label re-minted from the param and no kind invented} \
  [list $BT16_L [lsearch -exact $BT16_L {id ids 0}] \
        [b5_ok1 $BT16_M ids] [b5_ok1 $BT16_M annotation]] \
  [list {{gm gm 1} {id ids 0}} 1 1 1]

# --- BT17  ADD FROM LIST 3 ASKS WHICH LIST -----------------------------------
## The spec's own cell: "add to annotation or summary (the dialog asks which)".
## The stub records BOTH answers, and the row asserts the button honoured both
## - the scope AND the list it was told.
b5_lists_reset
b5_dlg [list scope narrow list summary]
rw_ans ::op_param_lists::set_list class b5cls summary {{gm gm 1}}
rw_ans ::rdw::set_list all
rw_ans ::rdw::set_row 9
set BT17_M [b5_press add]
check {BT17 Add from list 3 consults the dialog with the `all` identity - which is what makes it ask WHICH list - and writes into the list it was told at the scope it was told, leaving the class entry for that list alone} \
  [list $::b5_dlg_calls [lindex $::b5_dlg_args end] \
        [b5_owns flavor [list b5cls $B5_CELL1] summary] \
        [rw_ans ::op_param_lists::get_list flavor [list b5cls $B5_CELL1] summary] \
        [b5_owns flavor [list b5cls $B5_CELL1] annotation] \
        [rw_ans ::op_param_lists::get_list class b5cls summary]] \
  [list 1 all 1 {{gm gm 1} {id ids 0}} 0 {{gm gm 1}}]

# --- BT18  ADD MINTS NO KIND -------------------------------------------------
## `vgs` is drawn by the run and declared in no list and in no PDK seed, so
## there is no triple to re-add and no honest way to guess its kind. Rule R3:
## the kind is the raw-name SHAPE, so a wrong one writes a `.save` card that
## matches nothing - and one bogus card destroys the whole operating point.
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::rdw::set_list all
rw_ans ::rdw::set_row 12
set BT18_M [b5_press add]
check {BT18 Add from list 3 of a parameter declared in no list and in no PDK seed REFUSES by name, mints no kind and stores nothing - the kind is the raw-name shape and this file invents none} \
  [list [b5_ok1 $BT18_M vgs] \
        [b5_owns class b5cls annotation] [b5_owns class b5cls summary] \
        [b5_owns flavor [list b5cls $B5_CELL1] annotation] \
        [b5_eff annotation]] \
  [list 1 0 0 0 $B5_SEED]

# --- BT19  A LIVE CANVAS PICK MODE BLOCKS THE DIALOG -------------------------
## MEASURED while planning this item: `grab set .rdw.scope` really does take
## `grab current`, so a modal opened while a verb-noun pick is live SWALLOWS
## the canvas click the mode is waiting for and the mode looks dead. Ladder
## decision D9: refuse to open one, and name the key that ends the mode. This
## is adjacent to issue 1309 without being it - B5 adds no key and calls no
## pick_start.
b5_lists_reset
b5_dlg {scope broad list annotation}
set ::rdw::pick(canvas) .drw
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 9
set BT19_M [b5_press delete]
set BT19_RUN [rw_ans ::rdw::pick_running]
array unset ::rdw::pick
check {BT19 a Delete pressed while a canvas pick mode is live refuses and NAMES Escape, opens no dialog, creates no .rdw.scope toplevel, takes no grab and leaves the mode running} \
  [list [b5_ok1 $BT19_M Escape] $::b5_dlg_calls $BT19_RUN \
        [b5_owns class b5cls annotation] \
        [expr {$live_tk ? [rw_w winfo exists .rdw.scope] : 0}] \
        [expr {$live_tk ? [rw_w grab current] : {}}]] \
  {1 0 1 0 0 {}}

# --- BT20  THE STATUS LINE IS ONE-LINE-SAFE ----------------------------------
## `::rdw::statusmsg` is an `entry -textvariable` and the store's own sentences
## interpolate caught errors, which are multi-line by nature. rdw::_line has
## carried this rule for every BLOCK line since B3; the status line was the one
## emit point outside it, and B5 is the item that starts routing store prose
## through it.
rw_ans ::rdw::status "line1\nline2\tand3"
set BT20_M [b5_say]
rw_ans ::rdw::status {}
check {BT20 rdw::status collapses a multi-line message onto ONE line before it reaches the entry - the store's sentences interpolate caught errors and are multi-line by nature - and an empty message still clears the field} \
  [list $BT20_M [expr {[string first "\n" $BT20_M] < 0 ? 1 : 0}] [b5_say]] \
  [list {line1 line2 and3} 1 {}]

# --- BT21  A NARROW EDIT REPORTS HONESTLY (issue 1310) -----------------------
## MEASURED: `apply` is per `type=` token and passes no cellname, and op_annot
## holds ONE descriptor per type, so a per-cell display key cannot be expressed
## at all without editing op_annot.tcl - which this item may not. The flavor
## entry is stored, written and honoured by `effective`; it does not reach the
## drawn sheet. The button says so rather than looking broken. Filed as 1310.
b5_lists_reset
b5_dlg [list scope narrow list annotation]
set BT21_D0 [rw_ans ::op_annot::descriptor b5ndev]
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 9
set BT21_M [b5_press delete]
check {BT21 a NARROW edit is stored and honoured by `effective` for this cell and this cell only, the type's descriptor is byte-identical afterwards because a per-cell display key cannot be expressed at all, and the status SAYS the sheet still follows the class list (issue 1310, stated rather than discovered)} \
  [list [b5_owns flavor [list b5cls $B5_CELL1] annotation] \
        [b5_eff annotation $B5_CELL1] [b5_eff annotation $B5_CELL2] \
        [expr {[rw_ans ::op_annot::descriptor b5ndev] eq $BT21_D0 ? 1 : 0}] \
        [b5_ok1 $BT21_M class]] \
  [list 1 {{gm gm 1} {gds gds 1}} $B5_SEED 1 1]

# --- BT22  THE STRUCTURAL FENCE, REPLACING S1's AND K11's `== 0` -------------
## ⚠ ROWS S1 AND K11 GOLDED `op_param_lists:: == 0` IN src/rdw.tcl, AND B5's
## OWN DELIVERABLE FALSIFIES THAT GOLDEN. S1's own trailing comment already
## says so: "B5 is where the store is wired". The fence is not deleted, it is
## REPLACED BY A SHARPER ONE - the file may name the store only through its
## PUBLISHED verbs, never a `_private` one, and it still names none of the six
## forbidden doors S1 lists. S1 and K11 keep every other term they had.
set B5_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]
set B5_STORE_ALL [rw_count $B5_F {op_param_lists::}]
set B5_STORE_OK 0
## ⚠ THE ALLOW-LIST GAINED `reduce_why` AND `conf_tiers` (item B5-a). Both are
## PUBLISHED verbs of the store, minted for issues 1323 and 1325, and the row's
## point is unchanged: this file may name the store only through verbs the
## store publishes, and the `op_param_lists::_` term below still golds ZERO.
foreach v {effective set_list get_list owns apply write_conf conf_path said class seed governs reduce_why conf_tiers} {
  incr B5_STORE_OK [rw_count $B5_F "op_param_lists::$v"]
}
set B5_HANDBUILT 0
foreach t {{[list hdr } {[list dim } {[list dev } {[list note }} {
  incr B5_HANDBUILT [rw_count $B5_F $t]
}
check {BT22 STRUCTURAL src/rdw.tcl reaches the list store ONLY through its published verbs and never a private one, still names none of the six forbidden doors, still reaches the seam only through ase::backend_hook, no longer defines rdw::inert - a proc that says `item B5 wires it` after B5 wired it is a lie - and still builds no block line by hand} \
  [list [expr {$B5_STORE_ALL > 0 ? 1 : 0}] \
        [expr {$B5_STORE_ALL == $B5_STORE_OK ? 1 : 0}] \
        [rw_count $B5_F {op_param_lists::_}] \
        [rw_count $B5_F {::ase::backend::ngspice::}] \
        [rw_count $B5_F {raw value}] \
        [rw_count $B5_F {sim_capabilities}] \
        [rw_count $B5_F {blanket_op_save}] \
        [rw_count $B5_F {ase::theme}] \
        [expr {$B5_F eq {NOFILE} ? {NOFILE} : [rw_has $B5_F {ase::backend_hook}]}] \
        [llength [info commands ::rdw::inert]] \
        $B5_HANDBUILT] \
  {1 1 0 0 0 0 0 0 1 0 0}

# ============================================================================
# BT25 .. BT28 — ITEM B5-2's OWN FOUR ROWS
# ============================================================================
# ⚠ THESE FOUR CONTRADICT THE PRESERVED PATCH, AND EACH ONE NAMES A MEASUREMENT
# TAKEN AT HEAD c940a5df RATHER THAN AN OPINION ABOUT IT.
#   BT25 / BT26  A6: the button asked exact-key `owns` where `effective` asks a
#                GLOB, so with `{b5cls *b5n*}` governing a device the column
#                edited a list that device does not read. Two write paths, two
#                different corrections.
#   BT27         A7: `set_list` returns 1 WITH A REPORT when it reduced the
#                list by LABEL, and `rdw::_edit` reads the store's report only
#                on the rc=0 arm - so the one case issue 1288's ruling exists
#                for ("the user is told once") is the case the button drops.
#   BT28         the narrow key is the cell name used as a `string match` GLOB,
#                and a cell name that is not a glob matching itself mints a key
#                that answers nothing.
# ============================================================================

# --- BT25  A6, THE Up/Down HALF: A REORDER MOVES WHAT THE DEVICE READS -------
## MEASURED at HEAD, and it is the reason op_param_lists::governs exists:
##     effective b5cls annotation <M1's cell>        = the FLAVOR list
##     owns flavor {b5cls <M1's cell>} annotation    = 0
## because the entry's key is the GLOB `*b5n*`, not the literal cell name. A
## reorder that asked the second question would answer "broad", write the CLASS
## entry, and leave the user looking at a pane whose order did not move - while
## the status line said it had.
b5_lists_reset
rw_ans ::op_param_lists::set_list flavor [list b5cls *b5n*] annotation $B5_SEED
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 10
set BT25_M [b5_press up]
check {BT25 with a flavor entry whose GLOB governs this cell, an Up press writes THAT entry - the class entry stays unowned, what `effective` answers for this cell really moves, the sibling cell is still on the PDK seed, and the status line NAMES the glob it wrote at rather than claiming a class-wide change it did not make} \
  [list [b5_owns flavor [list b5cls *b5n*] annotation] \
        [rw_ans ::op_param_lists::get_list flavor [list b5cls *b5n*] annotation] \
        [b5_owns class b5cls annotation] \
        [b5_eff annotation $B5_CELL1] [b5_eff annotation $B5_CELL2] \
        [b5_ok1 $BT25_M {*b5n*}] [b5_ok1 $BT25_M gm]] \
  [list 1 {{gm gm 1} {id ids 0} {gds gds 1}} 0 \
        {{gm gm 1} {id ids 0} {gds gds 1}} $B5_SEED 1 1]

# --- BT26  A6, THE BROAD HALF: THE CLASS MOVES AND THE DEVICE DOES NOT -------
## ⚠ AND THE BROAD BASE IS STILL THE CLASS LIST, NOT THIS CELL's. Taking the
## base from `effective $cls $listname $cell` - which the item's own plan asked
## for - would write the FLAVOR list's rows into the CLASS key and destroy every
## class row the flavor entry does not carry. That is ruling DD-7's failure, the
## one that reverted item B2a twice. So the cell goes into the POST-write check
## instead: the class really moved, this device did not, and the button SAYS SO
## instead of reporting a bare success the user cannot see.
b5_lists_reset
b5_dlg [list scope broad list annotation]
rw_ans ::op_param_lists::set_list flavor [list b5cls *b5n*] annotation $B5_SEED
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 10
set BT26_M [b5_press delete]
check {BT26 a BROAD Delete on a device a flavor glob governs moves the CLASS list and nothing else - the flavor entry is byte-identical afterwards, what this device reads is unchanged, and the status line says so by naming the glob that still wins for it, never a bare success about rows that did not move} \
  [list [b5_owns class b5cls annotation] \
        [rw_ans ::op_param_lists::get_list class b5cls annotation] \
        [rw_ans ::op_param_lists::get_list flavor [list b5cls *b5n*] annotation] \
        [b5_eff annotation $B5_CELL1] \
        [b5_ok1 $BT26_M {*b5n*}]] \
  [list 1 {{id ids 0} {gds gds 1}} $B5_SEED $B5_SEED 1]

# --- BT27  A7: THE STORE TELLS, AND THE BUTTON MUST NOT DROP IT -------------
## MEASURED at HEAD: `set_list class b5cls annotation {{id vgs 2} {gds gds 1}
## {id ids 0}}` returns **1** - success - with the report `a second entry for
## label "id" ... the later one replaces it in place`, and the stored list
## becomes `{id ids 0} {gds gds 1}`: the row the user never touched is GONE.
## IHP's shipped `{id ids 0}` is exactly this label != param shape, so this is
## not a synthetic case. Issue 1288's ruling is that the two doors reach the
## same verdict with the same sentence and the user is told ONCE; a button that
## reads the store's report only on the FAILURE arm tells them zero times.
##
## ⚠ RE-CHECKED UNDER RULING DD-15 BY ITEM B5-3, AND THIS ROW DOES NOT MOVE.
## Item B5-a's note warned that guarding the ADD arm the way the reorder is
## guarded would red this row, and asked whether DD-15 changed that. It does
## not: DD-15 shuts the DECLARATION door (`op_annot::register`), and the label
## collision HERE is minted by `set_list` from two triples the button itself
## assembles - issue 1288's ruled accept-and-report, which DD-15 moves nothing
## about. The refusal being at the declaration is precisely what makes
## extending the reorder guard to Add unnecessary, so the row's assertion
## stands unchanged and no leg is added.
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::op_param_lists::set_list class b5cls annotation {{id vgs 2} {gds gds 1}}
rw_ans ::op_param_lists::said_clear
rw_ans ::rdw::set_list summary
rw_ans ::rdw::set_row 9
set BT27_M [b5_press add]
set BT27_L [rw_ans ::op_param_lists::get_list class b5cls annotation]
check {BT27 an Add whose triple collides BY LABEL with a row already in the list repeats the STORE's own sentence in the status line, one-lined, rather than reporting a plain success - the stored list is what get_list holds and what effective answers, and the user is told once that a row they did not touch was replaced} \
  [list $BT27_L [b5_eff annotation] \
        [b5_ok1 $BT27_M {replaces it in place}] \
        [b5_ok1 $BT27_M ids] \
        [b5_owns class b5cls annotation]] \
  [list {{id ids 0} {gds gds 1}} {{id ids 0} {gds gds 1}} 1 1 1]

# --- BT28  A NARROW KEY MUST BE A GLOB THAT MATCHES ITSELF ------------------
## The narrow key is the CELL NAME, stored and later matched with
## `string match -nocase`. MEASURED: `a[bc].sym` and `a\b.sym` do NOT match
## themselves, so the key would be written and then answer nothing - and the
## DD-8 shadow branch would fire, blaming "an entry declared earlier in the
## settings file" that does not exist. One wrong sentence produced by the code
## written to remove another. Refuse up front, name the broad alternative, and
## store nothing.
## ⚠ THE SECOND HALF IS THE CONTROL: an ordinary cell name goes through the
## SAME door and is accepted, so the guard is about self-matching and not about
## narrow scope.
b5_lists_reset
set BT28_BAD [dict create instname M1 type b5ndev class b5cls cellname {a[bc].sym}]
set BT28_R   [rw_ans ::rdw::_edit delete $BT28_BAD annotation narrow ids]
set BT28_OK  [dict create instname M1 type b5ndev class b5cls cellname b5plain.sym]
set BT28_R2  [rw_ans ::rdw::_edit delete $BT28_OK annotation narrow ids]
check {BT28 a narrow write whose cell name is not a glob matching itself is REFUSED with its own sentence naming the class-wide alternative, and stores no flavor key at all - while an ordinary cell name through the same door is accepted, so the guard is about the glob and not about narrow scope} \
  [list [lindex $BT28_R 0] \
        [b5_ok1 [lindex $BT28_R 1] {a[bc].sym}] \
        [b5_ok1 [lindex $BT28_R 1] b5cls] \
        [b5_owns flavor [list b5cls {a[bc].sym}] annotation] \
        [b5_owns class b5cls annotation] \
        [lindex $BT28_R2 0] \
        [b5_owns flavor [list b5cls b5plain.sym] annotation]] \
  [list refused 1 1 0 0 ok 1]

# --- BT23  THE REAL WIDGETS, DISPLAY ARM ONLY --------------------------------
## The twin of W4b, rewritten. B3's obligation - every enabled button SAYS what
## it did - does not lapse when the buttons stop being inert; it is exactly
## then that a silent button becomes indistinguishable from a broken one.
if {$live_tk} {
  b5_lists_reset
  b5_dlg {scope broad list annotation}
  b5_fixture_blocks
  rw_ans ::rdw::open
  catch {update idletasks}
  rw_ans ::rdw::set_list annotation
  catch {update idletasks}
  set BT23_CMD {}
  foreach id {up down delete add save} { lappend BT23_CMD [rw_has [rw_w .rdw.b.$id cget -command] "rdw::button $id"] }
  rw_ans ::rdw::set_row 10
  rw_ans ::rdw::status {}
  rw_w .rdw.b.up invoke
  catch {update idletasks}
  set BT23_M [b5_say]
  check {BT23 every enabled button carries rdw::button and nothing else, a real .rdw.b.up invoke really moves the store, and the window still SAYS what happened without ever claiming it is not wired yet} \
    [list $BT23_CMD [b5_owns class b5cls annotation] [b5_eff annotation] \
          [expr {$BT23_M ne {} && $BT23_M ne {NOVAR} ? 1 : 0}] \
          [expr {[string first {not wired yet} $BT23_M] < 0 ? 1 : 0}] \
          [b5_ok1 $BT23_M gm]] \
    [list {1 1 1 1 1} 1 {{gm gm 1} {id ids 0} {gds gds 1}} 1 1 1]
  catch {destroy .rdw.scope}

  # --- BT31  ISSUE 1356: THE USER'S OWN GESTURE, AND WHAT IT REALLY DID -------
  ## THE USER'S WORDS: "I select a bunch of lines - sa, sb, up to scc - and
  ## press Delete".  MEASURED on their own M18 at HEAD d81b4b24: `tag ranges
  ## sel` covered SIX rows, `::rdw::targetrow` was the anchor row alone, and
  ## one press produced ONE verdict about ONE parameter.  A multi-row delete is
  ## not a thing this window does -- `rdw::button` reads `rdw::_target_line`,
  ## whose only setter is the <Button-1> click, while every reader of the text
  ## selection in this file is on the CLIPBOARD path -- and nothing on screen
  ## said so, which is why "the delete did not have an effect" was a reasonable
  ## reading of a delete that had exactly one.
  ##
  ## THE ROW ASSERTS BOTH HALVES, because a note that fired unconditionally
  ## would be noise rather than an answer: with a multi-line selection standing
  ## the sentence is there, and with the selection gone the very same press on
  ## the very same fixture is byte-identical without it.
  b5_lists_reset
  b5_dlg {scope broad list annotation}
  b5_fixture_blocks
  rw_ans ::rdw::open
  catch {update idletasks}
  rw_ans ::rdw::set_list annotation
  rw_ans ::rdw::render_pane
  catch {update idletasks}
  set BT31_PR {}
  set BT31_N 0
  foreach _e [b5_flat] {
    incr BT31_N
    if {[rw_ans ::rdw::_row_param $_e] ne {}} { lappend BT31_PR $BT31_N }
  }
  set BT31_FIRST [lindex $BT31_PR 0]
  set BT31_LAST  [lindex $BT31_PR end]
  catch {.rdw.p.t tag remove sel 1.0 end}
  catch {.rdw.p.t tag add sel $BT31_FIRST.0 [expr {$BT31_LAST + 1}].0}
  catch {update idletasks}
  set BT31_SEL   [rw_ans ::rdw::_selection_lines]
  set BT31_TROW  [rw_ans ::rdw::set_row $BT31_FIRST]
  set BT31_EFF0  [b5_eff annotation]
  set BT31_M     [b5_press delete]
  set BT31_EFF1  [b5_eff annotation]
  ## THE CONTROL: the same fixture, the same press, no selection standing.
  b5_lists_reset
  b5_dlg {scope broad list annotation}
  b5_fixture_blocks
  rw_ans ::rdw::render_pane
  catch {.rdw.p.t tag remove sel 1.0 end}
  catch {update idletasks}
  rw_ans ::rdw::set_row $BT31_FIRST
  set BT31_M2 [b5_press delete]
  check {BT31 ISSUE 1356 THE USER'S OWN GESTURE: a mouse selection covering every parameter row of a block, then one Delete - exactly ONE parameter leaves the list, and the window SAYS the selection was not the target instead of leaving the user to infer it from a store they cannot see; the identical press with no selection standing carries no such clause, so the sentence is an answer and not noise} \
    [list [expr {$BT31_SEL >= 2 ? 1 : 0}] $BT31_TROW \
          [expr {[llength $BT31_EFF0] - [llength $BT31_EFF1]}] \
          [b5_ok1 $BT31_M {the buttons act on the shaded row alone}] \
          [rw_count $BT31_M {Delete:}] \
          [rw_has $BT31_M2 {the buttons act on the shaded row alone}] \
          [expr {$BT31_M2 ne {} && $BT31_M2 ne {NOVAR} ? 1 : 0}]] \
    [list 1 $BT31_FIRST 1 1 1 0 1]
  catch {.rdw.p.t tag remove sel 1.0 end}
  catch {destroy .rdw.scope}
  rw_ans ::rdw::close
  catch {update idletasks}
}

# --- the section leaves the tree as it found it ------------------------------
catch {rename ::rdw::scope_dialog {}}
if {[llength [info commands ::rdw::b5_real_scope_dialog]]} {
  rename ::rdw::b5_real_scope_dialog ::rdw::scope_dialog
}
array unset ::rdw::pick
rw_ans ::op_param_lists::reset
catch {op_annot::register b5ndev {}}
catch {op_annot::register b5pdev {}}
set ::rdw::blocks {}
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::status {}
catch {xschem raw clear}

# ============================================================================
# SECTION CU — ITEM R1, ISSUE 1337: THE LINE CURSOR. THE HALF THAT NEEDS NO Tk.
# ============================================================================
# The user's words: "clicking on any line makes the entire line a shade darker
# (noticeably)."  Driver decisions DD-1 (one cursor; a new block clears it) and
# DD-2 (the shade is DERIVED from the palette, never hard-coded).
#
# ⚠ THE CURSOR THIS ITEM MAKES VISIBLE ALREADY EXISTS, AND THAT IS THE WHOLE
# TRAP.  `rdw::set_row` / `rdw::_target_line` (src/rdw.tcl:1940, :1954) are
# item B5's target row, and `rdw::_subject`'s own comment already calls it "the
# block the CURSOR is in": Delete, Add, Up and Down act on it today and the
# user cannot see it.  So R1 must SHADE THAT ROW, not mint a second one.  A
# `cursor` tag that tracks its own variable would give the window two cursors —
# a visible one and the one the buttons obey — and every row in section BT
# would still pass while Delete deleted a line the user was not looking at.
# Rows CU9, CU12 and CU14 (in test_rdw_keys_1245.tcl) are that fence; CU5 here
# is its headless half.
#
# THE CONTRACT R1 ADDS TO src/rdw.tcl:
#   rdw::color cursor        the shade.  A role in `rdw::color_sources` with
#                            its own `rdw::_color_fallback` entry, DERIVED from
#                            the pane background so it survives both themes.
#   tag `cursor` on .rdw.p.t configured `-background [rdw::color cursor]`, and
#                            LOWER than `sel` so a selection still shows.
#   rdw::set_row {n}         also paints the shading (it already moves insert).
#   rdw::_target_line {}     answers the SHADED line, 0 when there is none.
#   a <Button-1> on .rdw.p.t that sets the row from `@%x,%y` and does NOT
#                            `break` the Text class binding (the selection is
#                            the reason this window exists — item R3).
#   rdw::push                clears the cursor (DD-1).
#
# RED BEFORE R1, MEASURED 2026-09-05 ON THIS BINARY AT HEAD 077bdfe4:
#   `rdw::color cursor` answers `black` — the generic `_color_fallback`
#   fall-through — so the pane's own #000000 text would be invisible on it;
#   `rdw::palette` carries no `cursor` role; and `rdw::push` leaves
#   `rdw::_target_line` exactly where it was.  CU1 CU2 CU3 CU4 CU5 all red.
#
# ⚠ NO ROW BELOW ASSERTS A LITERAL COLOUR, and that is DD-2 stated as a test.
# A row spelling `#d0d0d0` would lock in precisely the hard-coded grey the
# decision rejects.  Every row compares LUMINANCES instead, so any derivation
# that is actually visible passes and any that is not, fails.

## Luminance, in pure Tcl, because these rows run on the --nogui arm where
## `winfo rgb` does not exist.  Hex of 1/2/3/4 digits per channel; a colour
## NAME is resolved through Tk when there is a Tk, and answers -1 otherwise so
## the row REDS rather than passing on an unparseable value.
proc cu_rgb {c} {
  if {[regexp {^#([0-9a-fA-F]+)$} $c -> h]} {
    set n [string length $h]
    if {$n % 3 != 0} { return {} }
    set w [expr {$n / 3}]
    if {$w < 1 || $w > 4} { return {} }
    set max [expr {(1 << (4 * $w)) - 1}]
    set out {}
    for {set i 0} {$i < 3} {incr i} {
      set part [string range $h [expr {$i * $w}] [expr {$i * $w + $w - 1}]]
      set v 0
      if {[scan $part %x v] != 1} { return {} }
      lappend out [expr {int(double($v) * 255.0 / $max + 0.5)}]
    }
    return $out
  }
  if {[llength [info commands winfo]]} {
    set r {}
    if {![catch {winfo rgb . $c} r] && [llength $r] == 3} {
      set out {}
      foreach v $r { lappend out [expr {int($v / 257.0 + 0.5)}] }
      return $out
    }
  }
  return {}
}
proc cu_lum {c} {
  set p [cu_rgb $c]
  if {[llength $p] != 3} { return -1 }
  return [expr {0.30 * [lindex $p 0] + 0.59 * [lindex $p 1] + 0.11 * [lindex $p 2]}]
}
## "Noticeably" is the user's own word, so it gets a number: 20 of 255, about
## 8%.  A #ffffff -> #e0e0e0 step is 31 and passes; a 12%-multiply darken of a
## near-black pane is 4 and does not, which is the point of row CU3.
proc cu_delta {a b} {
  set la [cu_lum $a] ; set lb [cu_lum $b]
  if {$la < 0 || $lb < 0} { return -1 }
  return [expr {abs($la - $lb)}]
}
proc cu_noticeable {a b} { return [expr {[cu_delta $a $b] >= 20 ? 1 : 0}] }
proc cu_readable   {a b} { return [expr {[cu_delta $a $b] >= 60 ? 1 : 0}] }
proc cu_darker {a b} {
  set la [cu_lum $a] ; set lb [cu_lum $b]
  if {$la < 0 || $lb < 0} { return 0 }
  return [expr {$lb - $la >= 20 ? 1 : 0}]
}
proc cu_dicthas {d k} {
  set v 0
  if {[catch {dict exists $d $k} v]} { return 0 }
  return [expr {$v ? 1 : 0}]
}

## A THEME THAT IS NOT THIS ONE.  `ase::palette` is the window's only colour
## source and today it answers one hard-coded LIGHT set, so a shade that is
## wrong in the dark is invisible to every other row in this file.  The stub is
## installed by rename and restored by rename, and every row that uses it
## ASSERTS THE RESTORE as a leg — a suite that leaves a stubbed palette behind
## would quietly re-colour every later row.
set ::CU_STUB_TBL {}
set ::CU_STUB_FG  {}
proc cu_pal_install {tbl fg} {
  set ::CU_STUB_TBL $tbl ; set ::CU_STUB_FG $fg
  if {![llength [info commands ::cu_pal_real]]} {
    if {![llength [info commands ::ase::palette]]} { return 0 }
    rename ::ase::palette ::cu_pal_real
  }
  catch {rename ::ase::palette {}}
  proc ::ase::palette {{name {}}} {
    if {$::CU_STUB_TBL eq {RAISE}} { return -code error {this theme has no opinion} }
    set pal [dict create panel $::CU_STUB_TBL table $::CU_STUB_TBL \
                 header $::CU_STUB_TBL accent #8b0000 fieldfg $::CU_STUB_FG \
                 selectbg #4a6984 selectfg #ffffff \
                 disabledbg $::CU_STUB_TBL disabledfg $::CU_STUB_FG]
    if {$name ne {}} { return [dict get $pal $name] }
    return $pal
  }
  return 1
}
proc cu_pal_restore {} {
  if {![llength [info commands ::cu_pal_real]]} { return 0 }
  catch {rename ::ase::palette {}}
  rename ::cu_pal_real ::ase::palette
  return 1
}

# --- CU1  the shade is a ROLE, with its own fallback -------------------------
set CU1_PAL [rw_ans ::rdw::palette]
set CU1_SRC [rw_ans ::rdw::color_sources]
check {CU1 the shade is a named role of the window's OWN palette - it appears in rdw::color_sources, rdw::palette answers for it, and rdw::_color_fallback has an entry of its own for it rather than dropping through to the generic `black` every unknown role gets} \
  [list [cu_dicthas $CU1_PAL cursor] \
        [expr {![rw_bad $CU1_SRC] && [lsearch -exact $CU1_SRC cursor] >= 0 ? 1 : 0}] \
        [expr {[rw_ans ::rdw::_color_fallback cursor] ne
               [rw_ans ::rdw::_color_fallback cu-no-such-role] ? 1 : 0}]] \
  {1 1 1}

# --- CU2  the user's own word: DARKER, and noticeably -----------------------
set CU2_C  [rw_ans ::rdw::color cursor]
set CU2_BG [rw_ans ::rdw::color field]
set CU2_FG [rw_ans ::rdw::color fieldfg]
check {CU2 in the shipped light theme the cursor shade is NOTICEABLY DARKER than the pane it sits on - at least 20 of 255 in luminance, the user's word `noticeably` given a number - and the pane's own text colour is still readable on it, which `black` (today's generic fall-through) is not} \
  [list [cu_darker $CU2_C $CU2_BG] \
        [cu_readable $CU2_C $CU2_FG] \
        [expr {$CU2_C ne $CU2_BG ? 1 : 0}]] \
  {1 1 1}

# --- CU3  DD-2: DERIVED, and it tracks the pane background ------------------
## THE ROW A HARD-CODED GREY FAILS, AND SO DOES A MULTIPLICATIVE DARKEN.
## A literal #d0d0d0 does not move when the theme does (leg 2); a
## "background * 0.88" derivation moves but is 4 of 255 away from a near-black
## pane, which is not a shade anybody can see (leg 3).
set CU3_LIGHT [rw_ans ::rdw::color cursor]
cu_pal_install #202020 #e8e8e8
set CU3_D1   [rw_ans ::rdw::color cursor]
set CU3_D1BG [rw_ans ::rdw::color field]
set CU3_D1FG [rw_ans ::rdw::color fieldfg]
cu_pal_install #303030 #e8e8e8
set CU3_D2   [rw_ans ::rdw::color cursor]
set CU3_REST [cu_pal_restore]
check {CU3 DD-2 the shade is DERIVED and not written down: against a DARK palette it is a different colour from the light one, still noticeably different from that pane background, still readable against that pane foreground, and it moves again when only the background moves - so it tracks the pane rather than a literal} \
  [list $CU3_REST \
        [expr {![rw_bad $CU3_D1] && $CU3_D1 ne $CU3_LIGHT ? 1 : 0}] \
        [cu_noticeable $CU3_D1 $CU3_D1BG] \
        [cu_readable   $CU3_D1 $CU3_D1FG] \
        [expr {![rw_bad $CU3_D2] && $CU3_D2 ne $CU3_D1 ? 1 : 0}] \
        [rw_ans ::rdw::color field]] \
  {1 1 1 1 1 #ffffff}

# --- CU4  a theme with NO opinion still gets a usable shade -----------------
cu_pal_install RAISE {}
set CU4_C  [rw_ans ::rdw::color cursor]
set CU4_BG [rw_ans ::rdw::color field]
set CU4_FG [rw_ans ::rdw::color fieldfg]
set CU4_REST [cu_pal_restore]
check {CU4 when the theme answers nothing at all the fallback table answers, and its cursor shade is a usable one: noticeably darker than the fallback pane and readable against the fallback text - a missing option-database entry must not be able to paint the pane black} \
  [list $CU4_REST \
        [cu_darker   $CU4_C $CU4_BG] \
        [cu_readable $CU4_C $CU4_FG] \
        [expr {$CU4_C eq [rw_ans ::rdw::_color_fallback cursor] ? 1 : 0}] \
        [rw_ans ::rdw::color field]] \
  {1 1 1 1 #ffffff}

# --- CU5  DD-1: a new dump CLEARS the cursor, headless ----------------------
## ⚠ NON-VACUOUS BY CONSTRUCTION: the row asserts the cursor was really SET
## before it asserts it was cleared.  A `set_row` that did nothing at all would
## otherwise satisfy "the cursor is 0 after a push" perfectly.
## The reason is DD-1's own: rdw::push PREPENDS, so the line the user clicked
## now holds a different block's text, and a cursor that slid onto it silently
## would give item R2's Up/Down a subject the user never chose.
set CU5_KEEP $::rdw::blocks
set ::rdw::blocks {}
set CU5_SET [rw_ans ::rdw::set_row 4]
set CU5_HAD [rw_ans ::rdw::_target_line]
rw_ans ::rdw::push [rw_block [rw_ansd [dict create {@m.x1.mcu} {{id 1.5}}] {} {} 0 ok] \
                             [rw_ctx {MCU:/} {@m.x1.mcu} op MCU]]
set CU5_NOW [rw_ans ::rdw::_target_line]
set CU5_NB  [llength $::rdw::blocks]
set ::rdw::blocks $CU5_KEEP
rw_ans ::rdw::set_row 0
check {CU5 DD-1 a new dump CLEARS the cursor: the row was really cursored first, the push really landed, and afterwards the window has no cursored row at all - because push PREPENDS and the line the user clicked now holds different text} \
  [list $CU5_SET $CU5_HAD $CU5_NOW $CU5_NB] \
  {4 4 0 1}

# --- CU16  a theme that answers a NAME rather than a hex string -------------
## ⚠ ADDED BY THE IMPLEMENTING PASS, NOT THE RED ONE, and it is here because
## the crew brief asks for the input most likely to break the change and then
## asks whether any row would SEE it.  This one no row above sees.
## `ase::palette` spells its colours in hex today, so every row above feeds the
## derivation a `#rrggbb` string -- but `table` is a Tk COLOUR, and Tk colours
## have names.  A name cannot be read at all on the --nogui arm, where there is
## no `winfo` to resolve it, so the derivation must DEGRADE to the fallback
## rather than raise or drop through to the generic `black` that would paint
## the pane's own text invisible.  With a display it resolves through
## `winfo rgb` instead, and the two arms agree on this fixture because a white
## pane is a white pane either way -- which is what lets the row run on BOTH.
cu_pal_install white black
set CU16_C    [rw_ans ::rdw::color cursor]
set CU16_REST [cu_pal_restore]
check {CU16 a theme that answers a Tk colour NAME rather than a hex string still gets a usable shade - the --nogui arm cannot read a name at all and must fall back rather than raise or answer the generic `black` - and the answer is still noticeably darker than a white pane and readable against black text} \
  [list $CU16_REST \
        [expr {![rw_bad $CU16_C] && $CU16_C ne {black} ? 1 : 0}] \
        [cu_darker   $CU16_C #ffffff] \
        [cu_readable $CU16_C #000000] \
        [rw_ans ::rdw::color field]] \
  {1 1 1 1 #ffffff}

# --- CU17  the stale-target sweep is not a Tk feature -----------------------
## ⚠ ALSO ADDED BY THE IMPLEMENTING PASS, and it fences a line of src/rdw.tcl
## that only this arm can see.  Row CU14 of tests/headless/test_rdw_keys_1245.tcl
## already proves that key 4 takes the cursor with the block it discards -- but
## it runs on `:99` only, and the sweep that does it lives in rdw::render_pane,
## which RETURNS EARLY when there is no Tk.  Put the sweep one line lower, below
## that guard, and every displayed run stays green while the headless arm keeps
## a target pointing at a line no block owns any more: the two arms would then
## answer differently about the same store, and the store is the half that works
## headless (rdw::push's own words).
##
## SECOND HALF, AND IT IS WHAT STOPS THE ROW PASSING VACUOUSLY: a sweep that
## cleared the target on EVERY repaint would satisfy the first half perfectly.
## So the row also cursors a line the surviving block still owns and asserts
## that a second key 4 leaves it exactly where it is.
set CU17_KEEP $::rdw::blocks
set CU17_B [rw_block [rw_ansd [dict create {@m.x1.mcu} {{id 1.5}}] {} {} 0 ok] \
                     [rw_ctx {MCU:/} {@m.x1.mcu} op MCU]]
set ::rdw::blocks {}
rw_ans ::rdw::push $CU17_B
rw_ans ::rdw::push $CU17_B
set CU17_N0  [llength $::rdw::blocks]
## The LAST line of the two-block render, computed from the store rather than
## transcribed: it is always in the OLDER block, which is the one key 4 throws
## away.  The stamp adds no line (row BS6), so a block's length is its entries.
set CU17_TGT [expr {2 * [llength [lindex $::rdw::blocks 0]]}]
set CU17_PRE [expr {$CU17_TGT >= 2 ? 1 : 0}]
set CU17_SET [rw_ans ::rdw::set_row $CU17_TGT]
set CU17_HAD [rw_ans ::rdw::_target_line]
rw_ans ::rdw::keep_latest
set CU17_NOW [rw_ans ::rdw::_target_line]
set CU17_N1  [llength $::rdw::blocks]
rw_ans ::rdw::set_row 1
set CU17_LIVE [rw_ans ::rdw::_target_line]
rw_ans ::rdw::keep_latest
set CU17_STILL [rw_ans ::rdw::_target_line]
set ::rdw::blocks $CU17_KEEP
rw_ans ::rdw::set_row 0
rw_ans ::rdw::status {}
check {CU17 the cursor is dropped when the line it points at is thrown away, WITH NO Tk AT ALL - key 4 discards the older dump and the target that pointed into it goes with it, on the arm that has no pane to repaint - and a target the surviving block still owns is left exactly where the user put it} \
  [list $CU17_PRE $CU17_N0 $CU17_SET $CU17_HAD $CU17_NOW $CU17_N1 \
        $CU17_LIVE $CU17_STILL] \
  [list 1 2 $CU17_TGT $CU17_TGT 0 1 1 1]

# ============================================================================
# SECTION RE — ITEM R2, ISSUE 1338: UP AND DOWN MOVE THE ROW IN THE WINDOW,
# AND THE SHEET FOLLOWS. THE HALF THAT NEEDS NO Tk.
# ============================================================================
# The user's words: "Promote/demote using Up/Down arrow should be reflected in
# the Results Display Window as well as the schematic annotation - if applied
# to annotation params (1 key) or summary list (2 key)."  Driver decisions DD-3
# (Up and Down act on R1's cursored row) and DD-4 (only lists 1 and 2 re-render
# the schematic; list 3 has no presence on the sheet).
#
# ⚠ HALF OF THIS IS ALREADY TRUE AND THE SUITE MUST SAY WHICH HALF.  MEASURED
# on this binary at HEAD 27122ca4, driving a real `rdw::button up`:
#   the STORE moves            `effective` goes {id ids 0} {gm gm 1} {gds gds 1}
#                              -> {gm gm 1} {id ids 0} {gds gds 1}
#   the DESCRIPTOR moves       `shown` is rewritten for BOTH type tokens
#   the SHEET is re-rendered   `xschem get annot_overlay_flushes` +1, and
#                              op_annot::text answers in the new order
#   the WINDOW does not move   ::rdw::blocks is byte-identical afterwards, so
#                              the pane keeps showing the OLD order until the
#                              user presses 1 or 2 again
# So rows RE3 and RE7 are FENCES on behaviour that already works, and rows RE1,
# RE2, RE4 and RE5 are the item: the pane must show the reorder it just made.
# RE6 is the third thing, and it is a DEFECT, not a feature - see below.
#
# ============================================================================
# THE CONTRACT R2 ADDS, SPELLED HERE BECAUSE THIS FILE IS WHERE IT IS LOCKED
# ============================================================================
# After an ACCEPTED Up or Down, for every stored block whose subject resolves
# to the CLASS whose list was edited:
#
#   * the block's rows that the edited list DECLARES are re-filled, in the
#     list's new order, into the slots those declared rows already occupied;
#   * every other row keeps its own slot - the header, the device path, the
#     notes, the separator, a "  <rawdev>" sub-header, and a parameter row the
#     run published that no list declares;
#   * a row NEVER crosses a "  <rawdev>" sub-header, so a value stays with the
#     primitive that published it;
#   * the block's stamped subject (issue 1322) survives the rewrite;
#   * the CURSOR follows the ROW, not the line number, so a second press moves
#     the same parameter again.
#
# A block whose subject does not resolve, or resolves to another class, is not
# touched at all: nothing says which list its rows belong to.
#
# ============================================================================
# THE INPUT MOST LIKELY TO BREAK THIS, AND THE ROW THAT SEES IT
# ============================================================================
# ⚠ THE PANE'S ROW ORDER IS NOT THE LIST'S ROW ORDER, AND THE OBVIOUS
# IMPLEMENTATION - SWAP THE TWO ADJACENT DISPLAY LINES - IS WRONG.
# rdw::format_answer emits, per primitive, the `devices` pairs FIRST, then
# `nonfinite`, then `absent`.  So a list of {id ids 0} {gm gm 1} {gds gds 1}
# whose `gm` came back non-finite renders as
#       ids : 12u          list index 0
#       gds : 5.6u          list index 2
#       gm  : (did not converge)   list index 1
# and an Up on `gds` swaps list entries 2 and 1 - which leaves the DISPLAY
# order exactly as it was.  A swap of the two adjacent display lines would put
# `gds` above `ids` and the window would then be showing an order the store
# does not hold.  Row RE1 presses Up on that very row and requires the block to
# come back UNCHANGED, then presses again and requires it to change; a blind
# adjacent swap reds the first press and the shipped code reds the second.
#
# THREE MORE, EACH WITH A ROW:
#   * a MULTI-PRIMITIVE block.  One XR1 resolves to several primitives, each
#     with its own "  <rawdev>" sub-header and its own copy of every parameter
#     (ruling D-3).  An implementation that collects the block's parameter rows
#     and re-lays them in list order moves rows across the sub-headers, and a
#     number then sits under a device that never published it - a plausible
#     wrong NUMBER, which is invariant I3 exactly.                     -> RE4
#   * a row NO LIST DECLARES.  `vgs` is published by the run and declared by
#     nothing; row BT6 already refuses to reorder it, and it must not be
#     re-slotted by somebody else's reorder either.                    -> RE4
#   * a BLANK-VALUED row.  The `absent` bucket renders after the computed
#     pairs, so a declared row with no value can sit BELOW an undeclared one -
#     and it must still travel with the list.                          -> RE4
#   * THREE OTHER BLOCKS: a second one of the SAME class, one with NO SUBJECT,
#     and one of a DIFFERENT class.  The store is class-wide, so a window that
#     reorders only the block the cursor is in shows the same class list in two
#     different orders at once; a block whose device could not be resolved at
#     dump time has no class, so nothing says which of its rows the edited list
#     declares; and a block of another class carries a list nobody edited.
#                                                                      -> RE5
#
# ⚠ RE5 IS AN E QUESTION THIS SUITE ANSWERS ONE WAY.  Neither DD-3 nor DD-4
# says whether an OLDER block of the edited class follows.  It is written here
# as "every block of that class follows" because the alternative - only the
# cursored block - puts two different orders for one class on the screen at the
# same time, which is a statement the store cannot support.  It is the one row
# below that a ruling could delete without touching the item, and it is on the
# owed ledger as rule debt 1338_R2_every_block_of_the_class_follows for exactly
# that reason.
#
# ============================================================================
# ISSUE 1330 IS THE THIRD THING THIS ITEM OWES, AND ROW RE6 IS WHY
# ============================================================================
# `rdw::_apply_now` wraps every call in a bare `catch` and returns nothing, so
# an `apply` that fails is invisible: MEASURED on this binary, with
# `op_param_lists::apply` renamed to a proc that raises, an Up press still
# reports "Up: moved gm up in the annotation list for class ..." - the full
# success sentence, with no hint that the sheet did not follow.  Until this
# item that channel carried nothing anybody was promised; R2 is the item that
# promises the schematic follows, so a silent failure to re-render is now a
# false statement on a screen the user is reading.  Row RE6 fences the SHAPE of
# the correction and not its prose: the edit itself still stands, the message
# still names the parameter, it is still one line, it is NOT the sentence the
# same press produces when the apply succeeds, and it says something did not
# happen.  The wording goes on the same rule debt as every other sentence in
# this window.
#
# ============================================================================
# WHICH ROWS ARE RED BEFORE R2, MEASURED 2026-09-05 AT HEAD 27122ca4
# ============================================================================
#   RED    RE1 RE2 RE4 RE5   the store moves and the block does not
#          RE6               the failure is reported as a success
#   GREEN  RE0               the fixture's own control
#          RE3               a refusal already changes nothing
#          RE7               the sheet is already re-rendered on an accepted
#                            edit and already is not on a refusal or on list 3
# RE3 and RE7 are evidence of nothing except that R2 broke neither; they are
# here because DD-4 is a decision and an undefended decision is one refactor
# from being undone.

set RE_ROOT [file join $scratch r2re]
file mkdir $RE_ROOT
proc re_mksym {path type} {
  set fd [open $path w]
  puts $fd "v {xschem version=3.4.5 file_version=1.2}"
  puts $fd "G {}"
  puts $fd "K {type=$type"
  puts $fd {format="@spiceprefix@name @pinlist @model"}
  puts $fd "template=\"name=M1 model=$type spiceprefix=X\""
  puts $fd "}"
  puts $fd "V {}"
  puts $fd "S {}"
  puts $fd "E {}"
  puts $fd "L 4 -20 -20 20 -20 {}"
  puts $fd "B 5 -22.5 -12.5 -17.5 -7.5 {name=d dir=inout}"
  puts $fd "T {@name} 0 -40 0 0 0.2 0.2 {}"
  close $fd
}
set RE_SYMN [file join $RE_ROOT re2n.sym]
set RE_SYMP [file join $RE_ROOT re2p.sym]
set RE_SYMR [file join $RE_ROOT re2r.sym]
re_mksym $RE_SYMN re2ndev
re_mksym $RE_SYMP re2pdev
re_mksym $RE_SYMR re2rdev
set RE_SCH [file join $RE_ROOT re2.sch]
set fd [open $RE_SCH w]
puts $fd "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
C \{$RE_SYMN\} 300 -300 0 0 \{name=M1\}
C \{$RE_SYMP\} 300 -120 0 0 \{name=M2\}
C \{$RE_SYMR\} 300 -60 0 0 \{name=R1\}"
close $fd
catch {xschem raw clear}
set RE_LOAD [catch {xschem load $RE_SCH}]
catch {update idletasks}
## The IHP shape again: label `id`, param `ids`, kind 0.  A button column that
## looks a row up BY LABEL round-trips sky130 and gf180 and silently misses
## this one, which is the whole reason section BT uses it too.
set RE_DESC [list devpath {\@m.@path@name} \
                  params {{id ids 0} {gm gm 1} {gds gds 1}}]
set RE_SEEDP {ids gm gds}

## --- the section's own readers ---------------------------------------------
proc re_flat {} {
  set out {}
  if {![info exists ::rdw::blocks]} { return {} }
  foreach b $::rdw::blocks { foreach e $b { lappend out $e } }
  return $out
}
## The PARAMETER NAMES of one block's parameter rows, in pane order.  Read
## through rdw::_row_param, which row BT3 already golds, so this reader cannot
## invent a row the pane does not have.
proc re_params {bi} {
  set out {}
  foreach e [lindex $::rdw::blocks $bi] {
    set p [rw_ans ::rdw::_row_param $e]
    if {![rw_bad $p] && $p ne {}} { lappend out $p }
  }
  return $out
}
## Tag and text of every entry of one block, the STAMP dropped - so a shape
## golden is about what is on the screen and not about issue 1322's record,
## which its own leg asserts separately.
proc re_shape {bi} {
  set out {}
  foreach e [lindex $::rdw::blocks $bi] {
    lappend out [list [lindex $e 0] [lindex $e 1]]
  }
  return $out
}
## The RAW param names the store's list holds, in store order.
proc re_lparams {ln} {
  set l [rw_ans ::op_param_lists::effective re2cls $ln]
  if {[rw_bad $l]} { return $l }
  set out {}
  foreach t $l { lappend out [lindex $t 1] }
  return $out
}
## The parameter the CURSOR is on, resolved the way rdw::button resolves it.
proc re_cursor_param {} {
  set l [rw_ans ::rdw::_target_line]
  if {[rw_bad $l]} { return $l }
  if {![string is integer -strict $l] || $l <= 0} { return NOROW }
  set loc [rw_ans ::rdw::_locate $l]
  if {[rw_bad $loc]} { return $loc }
  if {$loc eq {}} { return NOLINE }
  set p [rw_ans ::rdw::_row_param \
           [lindex [lindex $::rdw::blocks [lindex $loc 0]] [lindex $loc 1]]]
  if {[rw_bad $p]} { return $p }
  if {$p eq {}} { return NOTPARAM }
  return $p
}
proc re_say {} {
  return [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]
}
proc re_press {id} {
  rw_ans ::rdw::status {}
  rw_ans ::rdw::button $id
  return [re_say]
}
proc re_ok1 {m needle} {
  if {$m eq {} || $m eq {NOVAR} || [string match {NOPROC*} $m]} { return 0 }
  if {[string first "\n" $m] >= 0} { return 0 }
  return [expr {[string first $needle $m] >= 0 ? 1 : 0}]
}
## Does this sentence say something did NOT happen?  ⚠ `not` alone is useless:
## it is a substring of `annotation`, which every success sentence in this
## window already carries.  Three whole phrases instead, none of which can
## appear by accident in a plain success line.
proc re_negated {m} {
  if {$m eq {} || $m eq {NOVAR}} { return 0 }
  foreach n {{could not} {did not} {failed} {was not}} {
    if {[string first $n $m] >= 0} { return 1 }
  }
  return 0
}
## The C overlay cache's flush counter - the ONE seam that says the schematic
## was actually asked to re-render, on the arm that has no pixels.  -1 when the
## binary cannot answer at all, so a row REDS rather than passing on nothing.
proc re_flush {} {
  set v -1
  catch {set v [xschem get annot_overlay_flushes]}
  return $v
}

## THE THREE-BLOCK FIXTURE, AND EVERY LINE OF IT IS DELIBERATE.
##   MZZ  newest, NO SUBJECT at all - the instance is not on this sheet, so
##        rdw::push stamps nothing and no class can be resolved for it.  Its
##        rows are spelled gm then ids, which is the order a class-wide
##        reorder WOULD produce, so "left alone" and "reordered" are
##        distinguishable on it.
##   M2   same private class as M1, rows gm then ids - the sibling block of
##        row RE5.
##   M1   the order-divergence block: `gm` is NON-FINITE, so the pane shows
##        ids / gds / gm while the list holds ids / gm / gds.
## MEASURED PANE LAYOUT, driven out of rdw::format_answer on this binary:
##      1 hdr  MZZ:/          7 hdr  M2:/         13 hdr  M1:/
##      2 dim  @m.mzz         8 dim  @m.m2        14 dim  @m.m1
##      3 note (incomplete)   9 note (incomplete) 15 note (incomplete)
##      4      gm  : 2     10      gm  : 34u 16     ids : 12u
##      5      ids : 1     11      ids : 9.9u 17     gds : 5.6u
##      6      (separator)   12      (separator)   18     gm  : (did not converge)
##                                                 19     (separator)
proc re_ansd {devices nonfinite} {
  return [dict create devices $devices absent {} nonfinite $nonfinite \
                      complete 0 state ok]
}
proc re_ctx {inst dp} {
  return [dict create header "$inst:/" devpath $dp simtype op instname $inst \
                      sim ngspice]
}
proc re_blk {inst dp devices nonfinite} {
  return [rw_block [re_ansd $devices $nonfinite] [re_ctx $inst $dp]]
}
proc re_fixture {} {
  set ::rdw::blocks {}
  rw_ans ::rdw::set_row 0
  rw_ans ::rdw::push [re_blk M1 @m.m1 \
      {@m.m1 {{ids 1.2e-05} {gds 5.6e-06}}} {{@m.m1 gm nan}}]
  rw_ans ::rdw::push [re_blk M2 @m.m2 {@m.m2 {{gm 3.4e-05} {ids 9.9e-06}}} {}]
  rw_ans ::rdw::push [re_blk MZZ @m.mzz {@m.mzz {{gm 2.0} {ids 1.0}}} {}]
  return {}
}
## ONE block, TWO primitives, a BLANK-VALUED row in each of them and a
## parameter no list declares in one of them.  Ruling D-3's sub-header is what
## makes the groups real; the `absent` bucket renders AFTER the `devices` pairs,
## so `vgs` - which the list does not declare - sits BETWEEN two rows that do,
## which is what makes "the declared rows re-fill the slots the declared rows
## occupied" a different answer from "the block's rows are sorted".
## MEASURED PANE LAYOUT, driven out of rdw::format_answer on this binary:
##      1 hdr  M1:/           6      gm  : 22u   11      vgs : 0.55
##      2 dim  x1             7      gds :           12      gds :
##      3 note (incomplete)   8 dev    @m.x1.mb      13 note (blank footnote)
##      4 dev    @m.x1.ma     9      ids : 33u   14      (separator)
##      5      ids : 11u 10      gm  : 44u
proc re_fixture_multi {} {
  set ::rdw::blocks {}
  rw_ans ::rdw::set_row 0
  rw_ans ::rdw::push [rw_block \
      [dict create devices {@m.x1.ma {{ids 1.1e-05} {gm 2.2e-05}}
                            @m.x1.mb {{ids 3.3e-05} {gm 4.4e-05} {vgs 0.55}}} \
                   absent {{@m.x1.ma gds {}} {@m.x1.mb gds {}}} \
                   nonfinite {} complete 0 state ok] \
      [re_ctx M1 x1]]
  return {}
}
## THE FOUR-BLOCK FIXTURE ROW RE5 NEEDS: the three above plus a device of a
## DIFFERENT private class, newest and therefore on top.  Its rows are spelled
## `gm` then `ids` too, so "left alone" and "re-ordered by somebody else's
## list" are distinguishable on it - and so are "re-ordered by its OWN class's
## list", which nobody asked for either.
##      1 hdr  R1:/     7 hdr  MZZ:/    13 hdr  M2:/     19 hdr  M1:/
##      2 dim  @m.r1    8 dim  @m.mzz   14 dim  @m.m2    20 dim  @m.m1
##      3 note ...      9 note ...      15 note ...      21 note ...
##      4      gm      10      gm       16      gm       22      ids
##      5      ids     11      ids      17      ids      23      gds
##      6      (sep)   12      (sep)    18      (sep)    24      gm
##                                                       25      (separator)
proc re_fixture_cls {} {
  re_fixture
  rw_ans ::rdw::push [re_blk R1 @m.r1 {@m.r1 {{gm 7.0} {ids 8.0}}} {}]
  return {}
}
## ⚠ IT RE-REGISTERS THE DESCRIPTOR, for section BT's own measured reason
## (issue 1312): an accepted press calls `op_param_lists::apply`, which
## rewrites `params` and `shown`, and a per-row reset that only reset the STORE
## would leave every row after the first reading a descriptor an earlier row
## wrote.
proc re_reset {} {
  rw_ans ::op_param_lists::reset
  rw_ans ::op_param_lists::set_class re2ndev re2cls
  rw_ans ::op_param_lists::set_class re2pdev re2cls
  rw_ans ::op_param_lists::set_class re2rdev re2rcls
  catch {op_annot::register re2ndev $::RE_DESC}
  catch {op_annot::register re2pdev $::RE_DESC}
  catch {op_annot::register re2rdev $::RE_DESC}
  rw_ans ::op_param_lists::said_clear
  re_fixture
  rw_ans ::rdw::set_list annotation
  rw_ans ::rdw::status {}
  return {}
}

re_reset

# --- RE0  THE CONTROL --------------------------------------------------------
## GREEN BEFORE THE CHANGE.  It says the fixture is live AND that the pane's
## order and the store's order really do disagree, so no row below can pass by
## asserting something about nothing.
check {RE0 CONTROL the fixture is live: two type tokens of ONE private class and a third in a class of its own, an IHP-shaped seed whose first triple has label != param, three stacked blocks of which the newest has no resolvable subject at all - and the M1 block's displayed parameter order really does DIFFER from the store's list order, which is what makes an adjacent-line swap distinguishable from a re-order} \
  [list $RE_LOAD [rw_ans ::op_annot::type M1] [rw_ans ::op_annot::type M2] \
        [rw_ans ::op_annot::type R1] \
        [rw_ans ::op_param_lists::class re2ndev] \
        [rw_ans ::op_param_lists::class re2pdev] \
        [rw_ans ::op_param_lists::class re2rdev] \
        [llength $::rdw::blocks] [llength [re_flat]] \
        [re_params 2] [re_params 1] [re_params 0] \
        [re_lparams annotation] \
        [expr {[re_params 2] ne [re_lparams annotation] ? 1 : 0}] \
        [expr {[rw_ans ::rdw::block_subject [lindex $::rdw::blocks 0]] eq {} ? 1 : 0}] \
        [expr {[rw_ans ::rdw::block_subject [lindex $::rdw::blocks 2]] ne {} ? 1 : 0}]] \
  [list 0 re2ndev re2pdev re2rdev re2cls re2cls re2rcls 3 19 \
        {ids gds gm} {gm ids} {gm ids} $RE_SEEDP 1 1 1]

# --- RE1  THE WINDOW SHOWS THE ORDER THE STORE HOLDS -------------------------
## THREE PRESSES ON ONE CURSORED ROW, AND EACH ONE ANSWERS A DIFFERENT
## QUESTION.
##   press 1  the store swaps `gds` past `gm`, which the pane ALREADY shows in
##            that order - so the block must come back UNCHANGED.  An
##            adjacent-display-line swap reds here.
##   press 2  the store swaps `gds` past `ids`, which the pane does NOT already
##            show - so the block must change.  HEAD reds here: the store moves
##            and ::rdw::blocks is byte-identical.
##   press 3  `gds` is now the first row, so the press must be REFUSED BY NAME.
##            If the cursor had stayed on its LINE NUMBER instead of following
##            the row, it would now be sitting on `ids` and this press would
##            silently move a parameter the user did not choose - which is
##            DD-1's own argument, one item later.
re_reset
rw_ans ::rdw::set_row 17
set RE1_C0 [re_cursor_param]
set RE1_M1 [re_press up]
set RE1_P1 [re_params 2] ; set RE1_L1 [re_lparams annotation]
set RE1_C1 [re_cursor_param]
set RE1_M2 [re_press up]
set RE1_P2 [re_params 2] ; set RE1_L2 [re_lparams annotation]
set RE1_C2 [re_cursor_param]
set RE1_M3 [re_press up]
set RE1_P3 [re_params 2] ; set RE1_L3 [re_lparams annotation]
set RE1_SUBJ [rw_ans ::rdw::block_subject [lindex $::rdw::blocks 2]]
set RE1_SUBJOK 0
catch {set RE1_SUBJOK [expr {[dict get $RE1_SUBJ instname] eq {M1} ? 1 : 0}]}
check {RE1 the pane shows the order the STORE holds, never a swap of two adjacent display lines: a reorder the display already agreed with leaves the block untouched, the next one really moves the row, the cursor follows the ROW and not the line number so the third press is refused BY NAME at the top of the list, and the block keeps the subject it was stamped with} \
  [list $RE1_C0 \
        $RE1_P1 $RE1_L1 $RE1_C1 [re_ok1 $RE1_M1 gds] \
        $RE1_P2 $RE1_L2 $RE1_C2 \
        [re_ok1 $RE1_M3 gds] [re_ok1 $RE1_M3 first] $RE1_P3 $RE1_L3 \
        $RE1_SUBJOK] \
  [list gds \
        {ids gds gm} {ids gds gm} gds 1 \
        {gds ids gm} {gds ids gm} gds \
        1 1 {gds ids gm} {gds ids gm} \
        1]

# --- RE2  DOWN IS THE MIRROR, AND THE CURSOR WALKS ---------------------------
## The same three questions from the other end.  The third press is the fence
## on the walk: after two Downs `ids` is the LAST row and the press must be
## refused naming it - a cursor left on line 16 would be sitting on `gm`, which
## is the FIRST row, and would be refused with a different word about a
## different parameter.
re_reset
rw_ans ::rdw::set_row 16
set RE2_C0 [re_cursor_param]
set RE2_M1 [re_press down]
set RE2_P1 [re_params 2] ; set RE2_L1 [re_lparams annotation]
set RE2_C1 [re_cursor_param]
set RE2_M2 [re_press down]
set RE2_P2 [re_params 2] ; set RE2_L2 [re_lparams annotation]
set RE2_C2 [re_cursor_param]
set RE2_M3 [re_press down]
check {RE2 Down is the mirror of Up in the window as well as in the store - two presses walk the same parameter down two places, the cursor stays on the parameter and not on the line, and the third press is refused BY NAME at the BOTTOM of the list rather than moving whatever slid under the old line number} \
  [list $RE2_C0 \
        $RE2_P1 $RE2_L1 $RE2_C1 \
        $RE2_P2 $RE2_L2 $RE2_C2 \
        [re_ok1 $RE2_M3 ids] [re_ok1 $RE2_M3 last] [re_params 2]] \
  [list ids \
        {gm ids gds} {gm ids gds} ids \
        {gm gds ids} {gm gds ids} ids \
        1 1 {gm gds ids}]

# --- RE3  FENCE: A REFUSED REORDER CHANGES NOTHING AT ALL --------------------
## GREEN TODAY AND IT MUST STAY GREEN.  A repaint on the refusal arm would be a
## visible change reporting a command that did not happen - item B4's own rule,
## and the reason rdw::key resolves before it moves any state.
re_reset
rw_ans ::rdw::set_row 16
set RE3_SH0 [re_shape 2]
set RE3_F0  [re_flush]
set RE3_M   [re_press up]
set RE3_D   [expr {[re_flush] - $RE3_F0}]
check {RE3 FENCE a refused reorder changes NOTHING: the block is byte-identical, the cursor is still where the user put it, the list has not moved, and the schematic is not re-rendered - a refusal that repainted would be a visible change reporting a command that did not happen} \
  [list [re_ok1 $RE3_M ids] [re_ok1 $RE3_M first] \
        [expr {[re_shape 2] eq $RE3_SH0 ? 1 : 0}] \
        [rw_ans ::rdw::_target_line] [re_cursor_param] \
        [re_lparams annotation] $RE3_D] \
  [list 1 1 1 16 ids $RE_SEEDP 0]

# --- RE4  NOTHING CROSSES A DEVICE SUB-HEADER, AND AN UNDECLARED ROW STAYS ---
## Ruling D-3's block: one instance, two primitives, each with its own
## "  <rawdev>" sub-header and its own copy of every parameter - including a
## BLANK-VALUED one, which rdw::format_answer emits after the computed ones -
## plus a `vgs` the run published and no list declares, sitting BETWEEN two
## rows that the list does declare.
##
## An Up on the second primitive's blank `gds` must re-order BOTH groups (they
## draw the same list), must move the blank row past `vgs` without moving
## `vgs`, and must leave every value under the device that published it.  Three
## implementations red here and one passes:
##   sort the block's parameter rows by list order   -> rows cross the
##                                                      sub-headers and 4.4e-05
##                                                      lands under @m.x1.ma
##   permute ALL parameter rows of a group           -> `vgs` moves, and it is
##                                                      in no list at all
##   swap the two adjacent display lines             -> the blank row swaps
##                                                      with `vgs`
## A plausible wrong number under the wrong device is invariant I3 exactly, and
## this is the block a designer pastes into a review document.
re_reset
re_fixture_multi
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 12
set RE4_C0 [re_cursor_param]
set RE4_M  [re_press up]
set RE4_EXP [list [list hdr {M1:/}] [list dim x1] [list note $RW_INC] \
                  [list dev {  @m.x1.ma}] \
                  [list {} {    ids : 11u}] \
                  [list {} {    gds :}] \
                  [list {} {    gm  : 22u}] \
                  [list dev {  @m.x1.mb}] \
                  [list {} {    ids : 33u}] \
                  [list {} {    gds :}] \
                  [list {} {    vgs : 0.55}] \
                  [list {} {    gm  : 44u}] \
                  [list note $RW_ABSN] \
                  [list {} {}]]
check {RE4 in a multi-primitive block both primitives re-order because both draw the same list, no row crosses a device sub-header so every value stays under the device that published it, a BLANK-valued row re-orders with the rest, the parameter the run published and no list declares keeps its own slot even when a declared row moves past it, and the cursor is on the moved row of the primitive the user clicked} \
  [list $RE4_C0 [re_ok1 $RE4_M gds] [re_lparams annotation] \
        [re_shape 0] [rw_ans ::rdw::_target_line] [re_cursor_param]] \
  [list gds 1 {ids gds gm} $RE4_EXP 10 gds]

# --- RE5  EVERY BLOCK OF THE EDITED CLASS FOLLOWS; NO OTHER BLOCK MOVES -----
## ⚠ THE E QUESTION.  DD-3 and DD-4 are silent on the OTHER blocks; this row
## answers "every block whose subject resolves to the EDITED class", because
## the store is class-wide and the alternative puts two orders for one class on
## the screen at once.  Recorded as rule debt 1338_R2_every_block_of_the_class
## _follows so the user can overrule it; overruling deletes this row and
## nothing else.
##
## THE OTHER TWO BLOCKS ARE THE GUARD THAT KEEPS IT HONEST, and both are
## spelled `gm` then `ids` so that "left alone" is distinguishable from
## "re-ordered":
##   MZZ  no subject at all - the instance is not on this sheet, so nothing
##        says which list its rows belong to;
##   R1   a device of a DIFFERENT private class, whose own list nobody edited.
##        Its rows disagree with its own class list too, so an implementation
##        that re-orders every block by whatever class it belongs to reds here
##        while passing every other row in this section.
re_reset
re_fixture_cls
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 23
set RE5_C0   [re_cursor_param]
set RE5_P3_0 [re_params 3]
set RE5_P2_0 [re_params 2]
set RE5_P1_0 [re_params 1]
set RE5_P0_0 [re_params 0]
set RE5_M    [re_press up]
set RE5_RCLS [re_ok1 [rw_ans ::op_param_lists::class re2rdev] re2rcls]
check {RE5 a class-wide reorder is reflected in EVERY block of that class, so the window never shows one class list in two different orders at once - while a block whose device could not be resolved at dump time carries no class, and a block of a DIFFERENT class carries a list nobody edited, and neither is touched, rows spelled the same way included} \
  [list $RE5_C0 $RE5_P3_0 $RE5_P2_0 $RE5_P1_0 $RE5_P0_0 $RE5_RCLS \
        [re_ok1 $RE5_M gds] [re_lparams annotation] \
        [re_params 3] [re_params 2] [re_params 1] [re_params 0] \
        [expr {[rw_ans ::rdw::block_subject [lindex $::rdw::blocks 1]] eq {} ? 1 : 0}]] \
  [list gds {ids gds gm} {gm ids} {gm ids} {gm ids} 1 \
        1 {ids gds gm} \
        {ids gds gm} {ids gm} {gm ids} {gm ids} 1]

# --- RE6  ISSUE 1330: AN APPLY THAT FAILS IS NOT A SUCCESS ------------------
## ⚠ `rename`, NEVER `proc` - test_ase_bus_bits_0159.tcl:129-132's idiom, the
## same one section BT's dialog stub uses: a bare `proc` overwrites the real
## command and the `rename ... {}` that puts it back then DELETES it.  The
## restore is asserted as a leg, because a suite that left the store unable to
## apply would quietly re-colour every row after it.
re_reset
rw_ans ::rdw::set_row 17
set RE6_OKM [re_press up]
re_reset
rw_ans ::rdw::set_row 17
set RE6_REN 0
if {[llength [info commands ::op_param_lists::apply]]} {
  rename ::op_param_lists::apply ::re_real_apply
  proc ::op_param_lists::apply {args} {
    return -code error {the store cannot apply today}
  }
  set RE6_REN 1
}
set RE6_BADM [re_press up]
set RE6_LIST [re_lparams annotation]
set RE6_REST 0
if {$RE6_REN} {
  catch {rename ::op_param_lists::apply {}}
  rename ::re_real_apply ::op_param_lists::apply
  set RE6_REST [expr {[llength [info commands ::op_param_lists::apply]] ? 1 : 0}]
}
check {RE6 issue 1330 an apply that FAILS is not reported as a success: the edit itself still stands and the message still names the parameter on one line, but it is not the sentence the identical press produces when the apply succeeds and it says something did not happen - R2 is the item that promises the schematic follows, so a silent failure to re-render is a false statement on a screen the user is reading} \
  [list $RE6_REN $RE6_REST \
        [re_ok1 $RE6_OKM gds] [re_negated $RE6_OKM] \
        [re_ok1 $RE6_BADM gds] [re_negated $RE6_BADM] \
        [expr {$RE6_BADM ne $RE6_OKM ? 1 : 0}] \
        $RE6_LIST] \
  [list 1 1 1 0 1 1 1 {ids gds gm}]

# --- RE7  FENCE: DD-4, WHO GETS A RE-RENDER AND WHO DOES NOT ----------------
## GREEN TODAY, AND IT IS THE ONLY THING DEFENDING DD-4.  The counter is the C
## overlay cache's own flush count, which moves when and only when the epoch
## does - the first leg proves that by redrawing twice and watching it stand
## still, so a "+1" below is a statement about this edit and not about the fact
## that a redraw happened at all.
re_reset
catch {xschem redraw}
set RE7_A [re_flush]
catch {xschem redraw}
set RE7_B [re_flush]
rw_ans ::rdw::set_row 17
set RE7_F1 [re_flush] ; set RE7_M1 [re_press up]
set RE7_D1 [expr {[re_flush] - $RE7_F1}]
re_reset
rw_ans ::rdw::set_row 16
set RE7_F2 [re_flush] ; set RE7_M2 [re_press up]
set RE7_D2 [expr {[re_flush] - $RE7_F2}]
re_reset
rw_ans ::rdw::set_list summary
rw_ans ::rdw::set_row 17
set RE7_F3 [re_flush] ; set RE7_M3 [re_press up]
set RE7_D3 [expr {[re_flush] - $RE7_F3}]
re_reset
rw_ans ::rdw::set_list all
rw_ans ::rdw::set_row 17
set RE7_F4 [re_flush] ; set RE7_M4 [re_press up]
set RE7_D4 [expr {[re_flush] - $RE7_F4}]
rw_ans ::rdw::set_list annotation
check {RE7 FENCE DD-4 the schematic is asked to re-render for an ACCEPTED reorder of the annotation list and of the summary list, and is not asked at all for a refusal or for list 3 - the counter stands still across two plain redraws first, so a move below is a statement about the edit and not about redrawing} \
  [list [expr {$RE7_A >= 0 ? 1 : 0}] [expr {$RE7_B == $RE7_A ? 1 : 0}] \
        [re_ok1 $RE7_M1 gds] [expr {$RE7_D1 >= 1 ? 1 : 0}] \
        [re_ok1 $RE7_M2 first] $RE7_D2 \
        [re_ok1 $RE7_M3 gds] [expr {$RE7_D3 >= 1 ? 1 : 0}] \
        [re_ok1 $RE7_M4 {list 3}] $RE7_D4] \
  [list 1 1 1 1 1 0 1 1 1 0]

# ============================================================================
# THE FOUR ROWS R2's ADVERSARY NEEDED AND R2 DID NOT HAVE
# ============================================================================
# All four were driven RED against the shipped R2 (commit 0122c9a7) before
# they were written; the receipts are in doc/claude/rdw_batch/LEDGER.md.  Each
# one exists because a green count said a thing that was not true:
#
#   RE8   issue 1347.  RE7 golds `annot_overlay_flushes`, and that counter
#         moves on ANY re-register -- `op_annot::register` bumps
#         `::op_annot::gen` whether or not the descriptor came back different.
#         So RE7 goes green for a summary reorder whose drawn result is BYTE-
#         IDENTICAL, which is the shipped state.  This row golds the STRING
#         `op_annot::text` puts on the sheet.
#   RE9   issue 1348.  A device-flavor reorder re-slotted a block of a cell the
#         entry does not match.
#   RE10  issue 1349.  Delete and Add left the pane and the store disagreeing
#         about ORDER.
#   RE11  issue 1348's other side.  A BROAD write over a device a flavor entry
#         shadows must not re-slot that device's block -- which is what
#         `rdw::_shadow_why`'s own broad sentence already tells the user.

## The LABEL ORDER the SHEET actually draws, out of the proc that draws it.
## Never a re-derivation from the store: the whole question here is whether the
## two agree, and a reader that asked the store would answer yes by
## construction.
proc re_text {inst} {
  set t [rw_ans ::op_annot::text $inst]
  if {[rw_bad $t]} { return $t }
  return $t
}
proc re_labels {inst} {
  set t [re_text $inst]
  if {[rw_bad $t]} { return $t }
  set out {}
  foreach l [split $t "\n"] {
    set l [string trim $l]
    if {$l eq {}} { continue }
    lappend out [lindex [split $l =] 0]
  }
  set trimmed {}
  foreach l $out { lappend trimmed [string trim $l] }
  return $trimmed
}

# --- RE8  THE DRAWN RESULT, NOT THE COUNTER (issue 1347) ---------------------
## ⚠ THE TWO LEGS ARE DELIBERATELY ASYMMETRIC, AND THE ASYMMETRY IS THE FACT.
## `op_param_lists::_show_set` filters the annotation+summary union by the
## ANNOTATION list's labels, in union order, and `_save_set` lays the union out
## annotation-first -- so every drawn row takes its position from list 1 and
## the summary list's order can never reach the sheet at all.  DD-4 says "only
## lists 1 and 2 re-render the schematic" and that is TRUE of the re-render;
## it is not true of the RESULT, and R2's status line said the plain success
## sentence for both.
##
## The counter is read on both legs and golded as moving on both, which is what
## makes this row a statement about RE7 as well: two presses that differ in the
## only way the user can see are INDISTINGUISHABLE to the fence that was
## supposed to defend them.
re_reset
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 17
set RE8_A0 [re_labels M1] ; set RE8_T0 [re_text M1] ; set RE8_F0 [re_flush]
set RE8_MA [re_press up]
set RE8_A1 [re_labels M1] ; set RE8_T1 [re_text M1]
set RE8_DA [expr {[re_flush] - $RE8_F0}]
re_reset
rw_ans ::rdw::set_list summary
rw_ans ::rdw::set_row 17
set RE8_B0 [re_labels M1] ; set RE8_S0 [re_text M1] ; set RE8_F2 [re_flush]
set RE8_MB1 [re_press up]
set RE8_MB2 [re_press up]
set RE8_B1 [re_labels M1] ; set RE8_S1 [re_text M1]
set RE8_DB [expr {[re_flush] - $RE8_F2}]
set RE8_PANE [re_params 2] ; set RE8_LIST [re_lparams summary]
rw_ans ::rdw::set_list annotation
check {RE8 the fence is the DRAWN RESULT and not the re-render counter: an accepted annotation reorder really does move the string op_annot::text puts on the sheet, an accepted SUMMARY reorder leaves it BYTE-IDENTICAL because the sheet draws the annotation list, the window follows the summary order anyway because that half is what the user asked for, and the status line SAYS the drawn order did not move - while annot_overlay_flushes moves on BOTH, so the counter cannot tell the two apart} \
  [list [re_ok1 $RE8_MA gds] $RE8_A0 $RE8_A1 \
        [expr {$RE8_T1 ne $RE8_T0 ? 1 : 0}] [expr {$RE8_DA >= 1 ? 1 : 0}] \
        [re_negated $RE8_MA] \
        [re_ok1 $RE8_MB2 gds] $RE8_B0 $RE8_B1 \
        [expr {$RE8_S1 eq $RE8_S0 ? 1 : 0}] [expr {$RE8_DB >= 1 ? 1 : 0}] \
        [re_negated $RE8_MB2] $RE8_PANE $RE8_LIST] \
  [list 1 {id gm gds} {id gds gm} 1 1 0 \
        1 {id gm gds} {id gm gds} 1 1 1 {gds ids gm} {gds ids gm}]

# --- RE9  A FLAVOR REORDER REACHES THE CELLS THE ENTRY MATCHES (issue 1348) --
## The press's own sentence names the glob it wrote at.  MEASURED at the
## shipped R2, with a flavor entry on M1's cell only: the class list stood
## still, M1's block followed the flavor entry -- and M2's block, a different
## cell governed by the unmoved class entry, went `gm ids` -> `ids gm`.  A
## block re-slotted by a press that did not touch its list is a window telling
## the user a change reached further than it did, and the store cannot support
## the reading either way.
##
## TWO PRESSES, because one leaves M1's pane where it already was: the flavor
## list starts equal to the seed and the pane's `gm` is non-finite, so the
## first press moves the LIST and not the DISPLAY (row RE1's own trap).
re_reset
set RE9_CELL [rw_w xschem getprop instance M1 cell::name]
set RE9_SET [rw_ans ::op_param_lists::set_list flavor [list re2cls $RE9_CELL] \
                annotation {{id ids 0} {gm gm 1} {gds gds 1}}]
set RE9_G [rw_ans ::op_param_lists::governs re2cls annotation $RE9_CELL]
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 17
set RE9_M1 [re_press up]
set RE9_M2 [re_press up]
set RE9_FL {}
foreach t [rw_ans ::op_param_lists::effective re2cls annotation $RE9_CELL] {
  lappend RE9_FL [lindex $t 1]
}
check {RE9 a device-flavor reorder reaches the blocks that entry governs and no others: the press writes the flavor list, the CLASS list stands still, the block of the cell the glob matches follows - and the block of a sibling cell governed by the untouched class entry keeps its own order, so the window never shows a change reaching further than the sentence says it did} \
  [list $RE9_SET [lindex $RE9_G 0] \
        [re_ok1 $RE9_M2 gds] [re_ok1 $RE9_M2 $RE9_CELL] \
        $RE9_FL [re_lparams annotation] \
        [re_params 2] [re_params 1] [re_params 0]] \
  [list 1 flavor 1 1 {gds ids gm} $RE_SEEDP {gds ids gm} {gm ids} {gm ids}]

# --- RE10  DELETE AND ADD KEEP THE PANE AND THE STORE AGREEING (issue 1349) --
## ⚠ `rename`, NEVER `proc`, for the dialog stub - section BT's own idiom and
## row RE6's, and the restore is asserted as a leg.
##
## MEASURED at the shipped R2: after an Up the two agreed on `ids gds gm`; a
## broad Delete of `gds` and an Add of it back left the store at `ids gm gds`
## against a pane still reading `ids gds gm`, with nothing said.  The reason
## the code gave for not re-slotting here was an argument about MEMBERSHIP --
## "a re-slot could neither add the new row nor remove the deleted one" -- and
## both halves are true and neither is about ORDER: `rdw::_reslot_block` is a
## strict permutation over the rows the run published AND the list declares.
## So this row golds BOTH: the order agrees, and the pane's row SET is
## unchanged from first press to last.
re_reset
set RE10_REN 0
if {[llength [info commands ::rdw::scope_dialog]]} {
  rename ::rdw::scope_dialog ::re10_real_dialog
  set RE10_REN 1
}
set ::re10_answer {}
proc ::rdw::scope_dialog {args} { return $::re10_answer }
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 17
set RE10_SET0 [lsort [re_params 2]]
set RE10_MU [re_press up]
set RE10_AU [expr {[re_params 2] eq [re_lparams annotation] ? 1 : 0}]
set ::re10_answer [dict create scope broad]
set RE10_MD [re_press delete]
set RE10_PD [re_params 2]
rw_ans ::rdw::set_list all
set ::re10_answer [dict create scope broad list annotation]
set RE10_MA [re_press add]
rw_ans ::rdw::set_list annotation
set RE10_PA [re_params 2] ; set RE10_LA [re_lparams annotation]
set RE10_SET1 [lsort [re_params 2]]
catch {rename ::rdw::scope_dialog {}}
set RE10_REST 0
if {$RE10_REN} {
  rename ::re10_real_dialog ::rdw::scope_dialog
  set RE10_REST [expr {[llength [info commands ::rdw::scope_dialog]] ? 1 : 0}]
}
check {RE10 Delete and Add leave the pane and the store agreeing about ORDER, which is the property Up and Down had just taught the user to rely on: a broad Delete then an Add of the same parameter puts the store back in a new order and the pane follows it, while the pane's row SET is untouched from the first press to the last - a re-slot is a permutation over the rows this run published, so it adds no row the simulator did not report and drops none that it did} \
  [list $RE10_REN $RE10_REST \
        [re_ok1 $RE10_MU gds] $RE10_AU \
        [re_ok1 $RE10_MD gds] $RE10_PD \
        [re_ok1 $RE10_MA gds] $RE10_PA $RE10_LA \
        [expr {$RE10_PA eq $RE10_LA ? 1 : 0}] \
        [expr {$RE10_SET1 eq $RE10_SET0 ? 1 : 0}] [llength $RE10_PA]] \
  [list 1 1 1 1 1 {ids gds gm} 1 {ids gm gds} {ids gm gds} 1 1 3]

# --- RE11  A BROAD WRITE DOES NOT RE-SLOT A BLOCK IT DID NOT REACH ----------
## The other side of issue 1348, and it is `rdw::_shadow_why`'s own sentence
## made true in the pane: a broad Delete over a device a flavor entry governs
## really does change the class list and really does not reach that device, and
## the status line says so in those words.  A pane that re-slotted the cursored
## block anyway would be contradicting the sentence printed beneath it - while
## the sibling block, which the class entry really does govern, must follow.
re_reset
set RE11_CELL [rw_w xschem getprop instance M1 cell::name]
rw_ans ::op_param_lists::set_list flavor [list re2cls $RE11_CELL] \
  annotation {{id ids 0} {gm gm 1} {gds gds 1}}
set RE11_REN 0
if {[llength [info commands ::rdw::scope_dialog]]} {
  rename ::rdw::scope_dialog ::re11_real_dialog
  set RE11_REN 1
}
proc ::rdw::scope_dialog {args} { return [dict create scope broad] }
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 17
set RE11_M [re_press delete]
set RE11_P2 [re_params 2] ; set RE11_P1 [re_params 1]
set RE11_CL [re_lparams annotation]
catch {rename ::rdw::scope_dialog {}}
set RE11_REST 0
if {$RE11_REN} {
  rename ::re11_real_dialog ::rdw::scope_dialog
  set RE11_REST [expr {[llength [info commands ::rdw::scope_dialog]] ? 1 : 0}]
}
check {RE11 a BROAD write over a device a flavor entry shadows does not re-slot that device's block: the class list really moves, the status line says in DD-8's own words that this device's own rows did not change, the cursored block is byte-identical to prove it - and the sibling block, which the class entry really does govern, follows the list that really moved} \
  [list $RE11_REN $RE11_REST \
        [re_ok1 $RE11_M gds] [re_ok1 $RE11_M {did not change}] \
        $RE11_CL $RE11_P2 $RE11_P1] \
  [list 1 1 1 1 {ids gm} {ids gds gm} {ids gm}]

# --- the section leaves the tree as it found it ------------------------------
rw_ans ::op_param_lists::reset
catch {op_annot::register re2ndev {}}
catch {op_annot::register re2pdev {}}
set ::rdw::blocks {}
rw_ans ::rdw::set_row 0
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::status {}
catch {xschem raw clear}


# ============================================================================
# SECTION RH — ITEM R4, ISSUE 1340: THE TWO FENCES ROUND THE RAISE
# ============================================================================
# The user's words: "When user sends info to the Results Display Window (RDW),
# the RDW needs to be raised (no need to focus, just raise), just as the
# Library Manager is raised when one does Ctrl-Alt-S."
#
# ⚠ BOTH ROWS HERE ARE GREEN BEFORE R4 AND SAYING SO IS THE POINT. The
# behaviour the user asked for cannot be measured on an arm with no window
# manager, no stacking order and no keyboard focus, so R4's RED rows are
# section RA of tests/headless/test_rdw_keys_1245.tcl, which parks a decoy
# toplevel over the window and reads `wm stackorder`, real Map/Unmap events
# and `focus`. What is left for THIS file is the two ways R4 can break
# something that has nothing to do with raising, and neither of them is
# visible over there:
#
#   RH1  THE DOOR MUST STAY USABLE WITH NO Tk AT ALL. `rdw::push` is the store's
#        own entry point and the whole reason the pure layer exists: this suite,
#        test_op_param_store_1245 and every --nogui dump call it with no
#        display, and `winfo` and `wm` are not merely absent there, they are
#        UNDEFINED COMMANDS. A raise that is not behind `rdw::have_tk` turns
#        every headless dump into an error, and the row also holds ruling
#        DD-6's letter: the shared helper's body is REUSED, not copied into
#        this file, and this window never asks for activation.
#        ⚠ `rdw::open` STAYS THE ONE CONSTRUCTOR (row N1). A push into a closed
#        window must remain a store push - the dumps deliberately survive a
#        close (rdw::close's own comment) - so the cheap way to raise, calling
#        `rdw::open` from `push`, is fenced here as well as in row RA4.
#
#   RH2  THE SPLIT MUST LEAVE THE OTHER FOUR CALLERS ACTIVATING. Ruling DD-6
#        drops `raise_activate_toplevel`'s LAST line for the RDW by splitting
#        the proc or adding an argument - never by deleting the line. Deleting
#        it satisfies every RED row in section RA and silently stops the
#        Library Manager, the CIW, create_instance and copy_form taking the
#        focus they are entitled to. Row RA5 is the behavioural twin of this
#        one; this is the arm that runs when there is no display at all.
set RH_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]
if {$live_tk} { rw_ans ::rdw::close ; catch {update} }
set ::rdw::blocks {}
rw_ans ::rdw::set_row 0
set RH1_R [rw_ans ::rdw::push \
  [rw_block [rw_ansd [dict create {@m.x1.mrh} {{id 1.5}}] {} {} 0 ok] \
            [rw_ctx {MRH:/} {@m.x1.mrh}]]]
check {RH1 FENCE the dump door survives with no Tk and copies nothing: a push with no display still stores its block and returns it, builds no window - rdw::open is this window's one constructor and the dumps survive a close - and src/rdw.tcl neither copies the shared raise helper's wm withdraw body nor ever asks for activation, which is ruling DD-6 in one line} \
  [list [rw_bad $RH1_R] \
        [llength $::rdw::blocks] \
        [expr {$live_tk ? [rw_w winfo exists .rdw] : 0}] \
        [expr {$RH_F eq {NOFILE} ? {NOFILE} : [rw_count $RH_F {wm withdraw}]}] \
        [rw_count $RH_F {activate_window}]] \
  {0 1 0 0 0}

set RH2_B [rw_body ::raise_activate_toplevel]
set RH2_LM [rw_slurp [file join $repo src library_manager.tcl]]
set RH2_CIW [rw_slurp [file join $repo src ciw.tcl]]
check {RH2 FENCE the shared raise is still the Library Manager's: raise_activate_toplevel is a live command whose body still asks for activation, issue 0843's _remap_verify is still there to recover a dropped re-map, and the two windows the user named the analogy after still call it - a split that deleted the last line instead of moving it would pass every other row this item adds} \
  [list [rw_bad $RH2_B] \
        [expr {[rw_bad $RH2_B] ? 0 : [rw_has $RH2_B {activate_window}]}] \
        [expr {[llength [info commands ::_remap_verify]] > 0 ? 1 : 0}] \
        [expr {[rw_count $RH2_LM {raise_activate_toplevel}] >= 1 ? 1 : 0}] \
        [expr {[rw_count $RH2_CIW {raise_activate_toplevel}] >= 1 ? 1 : 0}]] \
  {0 1 1 1 1}

## RH3 IS THE IMPLEMENTING PASS'S OWN ROW, for the question RH1 and RH2 do not
## ask. Those two fence what the split must NOT do: rdw.tcl must not copy the
## body, raise_activate_toplevel must not lose the activation. Neither of them
## says the two halves are still JOINED -- and that is the regression this item
## actually creates. Rewrite `raise_activate_toplevel` as a plain `raise $top`
## plus the activation and RH1, RH2 and every RED row in section RA stay green
## while the Library Manager quietly loses issue 0054's re-map and issue 0843's
## recovery on the one window manager they were written for. The row is
## structural on purpose: the behaviour needs a WM that DROPS a re-map, which
## no display here has (tests/headless/test_remap_verify.tcl simulates the drop
## and is the behavioural half).
set RH3_RT [rw_body ::raise_toplevel]
set RH3_RA [rw_body ::raise_activate_toplevel]
check {RH3 STRUCTURAL the two halves of the split are still joined: raise_toplevel exists and holds the shared body - issue 0054's wm withdraw re-map and issue 0843's deferred _remap_verify - and asks for no activation, while raise_activate_toplevel DELEGATES to it rather than carrying a second copy of that body. A rewrite that re-derived either half would pass RH1, RH2 and every row of section RA}   [list [rw_bad $RH3_RT]         [expr {[rw_bad $RH3_RT] ? 0 : [rw_has $RH3_RT {wm withdraw}]}]         [expr {[rw_bad $RH3_RT] ? 0 : [rw_has $RH3_RT {_remap_verify}]}]         [expr {[rw_bad $RH3_RT] ? 1 : [rw_count $RH3_RT {activate_window}]}]         [expr {[rw_bad $RH3_RA] ? 0 : [rw_has $RH3_RA {raise_toplevel}]}]         [expr {[rw_bad $RH3_RA] ? 1 : [rw_count $RH3_RA {wm withdraw}]}]]   {0 1 1 0 1 0}

set ::rdw::blocks {}
rw_ans ::rdw::set_row 0
rw_ans ::rdw::status {}


# ============================================================================
# SECTION EN — ITEM R5, ISSUE 1341: THE VALUES PRINT IN ENGINEERING NOTATION,
# THROUGH THE SHEET'S OWN PROC
# ============================================================================
# The user's words: "Display of parameters in the RDW should be using
# engineering notation - just like annotation on the schematic."
#
# THE SEAM IS ONE PROC. `rdw::_value_text` (src/rdw.tcl:419) is the only place
# a `devices` value becomes text; `op_annot::eng_or_blank` (src/op_annot.tcl:1266)
# is what `op_annot::text` (:2125) puts on the sheet. "Just like annotation on
# the schematic" is not "looks similar": it is THE SAME PROC, so the window and
# the sheet cannot drift. A second formatter living in rdw.tcl would pass EN1
# and red EN2 and EN6.
#
# ⚠ RULING DD-7 IS THE WHOLE DESIGN OF THIS ITEM, AND IT REJECTS THE ONE-LINER.
# `set v [op_annot::eng_or_blank $v]` at the call site is the obvious version.
# It is wrong in three measured ways, one row each:
#   EN3  eng_or_blank returns {} FOR EVERYTHING THAT IS NOT A FINITE NUMBER, and
#        this window's values are frequently not numbers: a model name, a `-`
#        placeholder, a width already written `1.5u`, a two-token value. The
#        one-liner blanks every one of them, and a blanked value in this window
#        does not read as "not a number" - it reads as the ABSENT column's
#        blank, whose footnote then says something FALSE about it (F5, F19).
#   EN4  a non-finite value in the `devices` bucket. eng_or_blank blanks it,
#        which is issue 1272's defect wearing engineering notation: `nan` used
#        to print here, and an empty string where `nan` used to print is a
#        SILENT loss of the one thing the user needed told. The RDW already has
#        words for it and they are what must appear - `rdw::_nonfinite_text`,
#        the same words the `nonfinite` BUCKET gets (F4, Q3). Invariant I3
#        forbids painting the raw `nan` too, so pass-through is not the answer
#        either.
#   EN3  `to_eng` (xschem.tcl:1902) EVALUATES its argument: `uplevel #0 expr
#        [join $args]`. So `to_eng {[set ::en_canary 1]}` really runs the
#        bracket, at GLOBAL SCOPE, on a string that arrived from a raw file.
#        eng_or_blank's `_finite` gate is what stops it, which is why the fence
#        below is "rdw.tcl names eng_or_blank and names to_eng ZERO times" and
#        not merely "the numbers look right".
#
# ⚠ THE SHARPEST INPUT, AND IT IS MEASURED ON THIS BINARY: `to_eng 1e400`
# returns the string `infT`. A raw may hold an overflowing literal, `1e400`
# passes `string is double -strict`, and an implementation that reached for
# to_eng directly would paste `ft : infT` into a design-review document - a
# plausible-looking engineering number that is not a number. EN4's fourth leg
# is that input.
#
# ⚠ THE ABSENT BUCKET'S BLANK AND `(no value reported)` BOTH SURVIVE, and EN5
# is the row that asks all three of the window's existing words at once, in ONE
# block, so a fix that gets the numbers right by flattening the vocabulary reds
# here rather than in a suite nobody re-ran.
#
# WHICH ROWS ARE RED BEFORE R5, AND WHY.  MEASURED on the unmodified tree,
# HEAD 62391a3f, --nogui and :99 both: `5 FAILED (128 passed)`.
#   RED    EN1 EN2 EN4 EN5 EN6 - `rdw::_value_text` returns the raw string
#          today, so every golden below carries a number the window does not
#          yet print, EN2's list differs from its first element on, and EN6
#          asks a question about a formatter that does not exist.
#   GREEN  EN3, AND SAYING SO IS THE POINT.  Today nothing is formatted, so
#          nothing is lost and nothing is evaluated; EN3 is the fence against
#          the fix, not against the code, and its red-before proof is a
#          SABOTAGE RUN.  A row whose only evidence is the shipped tree is a
#          statement about the FENCE, which is three items old on this branch.
#   EN7 was added by the IMPLEMENTING pass, not the RED pass, and it is red
#          before the change too (`1e-321` printed raw is not what the sheet
#          prints for it).  It exists because the implementing pass asked the
#          crew brief's question - "the input most likely to break your change:
#          would any row see it?" - and the answer for a value outside to_eng's
#          SI ladder was no.  Its own comment carries the measurements.
#
# FOUR SABOTAGE VARIANTS RUN AGAINST THIS SECTION, EVERY ONE CAUGHT.  Each is
# a plausible implementation of "use engineering notation", not a strawman:
#   SB-ONELINER   ruling DD-7's own rejected `[op_annot::eng_or_blank $v]` at
#                 the call site                     -> EN2 EN3 EN4 (+ H4 F20)
#   SB-UNGATED    `to_eng $v` with no `_finite` gate: the numbers are right and
#                 ::en_canary FIRES - a raw file's string reaches
#                 `uplevel #0 expr` - and `1e400` prints `infT`
#                                                    -> EN2 EN3 EN4 (+ H4)
#   SB-OWNFORMAT  rdw.tcl grows its own %.4g SI ladder, numerically IDENTICAL
#                 to the sheet at the shipped ev_precision 4 - EN1, EN3, EN4
#                 and EN5 all pass                            -> EN2 EN6
#   SB-FLATTEN    right numbers, vocabulary flattened: an empty value blanks
#                 instead of saying `(no value reported)`     -> EN5 (+ F19)
# ⚠ SB-ONELINER PASSES EN5 and SB-OWNFORMAT PASSES EN1, EN3, EN4 AND EN5.
# Neither row set is redundant with the other, and a section that had stopped
# at "the numbers look right" would have shipped both.
# AND SIXTEEN EXISTING GOLDENS MOVE WITH THEM, in this file (F1 F3 F4 F5 F7 F8
# F14 F15 Q1 Q3 Q4 Q6 K8 BT0 RE4, both arms) and one in
# tests/headless/test_op_param_store_1245.tcl (BE0). They are updated in the
# same pass and for the same reason: they spell out what the window prints, and
# what the window prints is what this item changes. Measured by running the
# whole suite against the R5 prototype, not by reading.
#
# THE NUMBERS BELOW WERE MEASURED, NOT DERIVED. `to_eng` was driven on this
# binary with the shipped `ev_precision` 4 (xschem.tcl:18540):
#   1.11e-05 -> 11.1u   0.001 -> 1m     1e-15 -> 1f     1.2e9 -> 1.2G
#   -1.11e-05 -> -11.1u 0.75 -> 0.75    0 -> 0          1.2e-05 -> 12u
#   2.5e-3 -> 2.5m      4.7e-12 -> 4.7p 1.234567e-05 -> 12.35u (12.3457u at 6)
#   1e400 -> infT       nan -> {}       abc -> {}

set EN_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]
set EN_CTX [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1]

# --- EN1  THE BEHAVIOUR THE USER ASKED FOR, AS THE PASTE SHAPE ---------------
## Seven magnitudes across six decades, plus the genuine zero F12 protects and
## a negative. The last leg is R2's machinery read back over the SAME block:
## `rdw::_row_param` recovers a parameter name from a rendered line, and every
## Up/Down, every re-slot and every cursor read goes through it - a value that
## suddenly carries a unit suffix must not cost the window its rows.
set EN1_ANS [rw_ansd [dict create {@m.x1.m1} \
      {{id 1.11e-05} {gm 0.001} {cgs 1e-15} {ft 1.2e9} {vth 0.75} {is 0} \
       {ibulk -1.11e-05}}] {} {} 0 ok]
set EN1_B [rw_block $EN1_ANS $EN_CTX]
set EN1_T [rw_text  $EN1_ANS $EN_CTX]
set EN1_P {}
if {![rw_bad $EN1_B]} {
  foreach e $EN1_B { lappend EN1_P [rw_ans ::rdw::_row_param $e] }
}
check {EN1 every value in the block prints in engineering notation - microamps, millisiemens, femtofarads, gigahertz - the raw exponent form appears NOWHERE, a genuine 0 is still 0 and a negative keeps its sign, and R2's row reader still recovers every parameter name from the re-formatted lines} \
  [list $EN1_T [rw_count $EN1_T {1.11e-05}] [rw_count $EN1_T {0.001}] \
        [rw_count $EN1_T {1e-15}] [rw_count $EN1_T {1.2e9}] $EN1_P] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    id    : 11.1u} {    gm    : 1m} {    cgs   : 1f} \
                  {    ft    : 1.2G} {    vth   : 0.75} {    is    : 0} \
                  {    ibulk : -11.1u} {}] \
        0 0 0 0 {{} {} {} id gm cgs ft vth is ibulk {}}]

# --- EN2  THE SAME PROC AS THE SHEET, NOT A SECOND FORMATTER ----------------
## The behavioural half is deliberately an equality with `op_annot::eng_or_blank`
## rather than a second list of literals: EN1 already holds the literals, and
## what this row adds is that the two surfaces cannot disagree ABOUT A VALUE
## NOBODY WROTE A GOLDEN FOR. The structural half is the safety gate - to_eng
## evaluates its argument at global scope, so a direct call from this file is a
## code path out of a raw file and not a formatting choice.
set EN2_V {1.11e-05 0.001 1e-15 1.2e9 -1.11e-05 0.75 0 2.5e-3 4.7e-12}
set EN2_GOT {} ; set EN2_WANT {}
foreach v $EN2_V {
  lappend EN2_GOT  [rw_ans ::rdw::_value_text $v]
  lappend EN2_WANT [rw_ans ::op_annot::eng_or_blank $v]
}
check {EN2 the window formats a finite value BYTE-IDENTICALLY to op_annot::eng_or_blank, the proc op_annot::text puts on the sheet, for nine values across nine decades - and src/rdw.tcl reaches it by name while calling the evaluating to_eng not once, which is what keeps a raw file's string out of `uplevel #0 expr`} \
  [list $EN2_GOT [lindex $EN2_WANT 0] \
        [expr {$EN_F eq {NOFILE} ? {NOFILE} : ([rw_count $EN_F {eng_or_blank}] >= 1 ? 1 : 0)}] \
        [expr {$EN_F eq {NOFILE} ? {NOFILE} : [rw_count $EN_F {to_eng}]}]] \
  [list $EN2_WANT 11.1u 1 0]

# --- EN3  A NON-NUMERIC VALUE PASSES THROUGH UNCHANGED, AND IS NOT EVALUATED -
## Ruling DD-7's rejected one-liner loses every one of these. They are not
## exotic: a model name is what a `.op` save of a subcircuit parameter carries,
## `-` is the placeholder a PDK writes for a column it declines to compute, a
## geometry already written `1.5u` is the ordinary spelling in a netlist, and a
## two-token value is what a backend returns for a swept pair.
## THE LAST ONE IS THE SAFETY ROW. If anything on this path calls to_eng
## without the finite gate, the bracket runs and ::en_canary exists.
catch {unset ::en_canary}
set EN3_ANS [rw_ansd [dict create {@m.x1.m1} [list \
      [list model sg13g2_lv_nmos] \
      [list corner {-}] \
      [list w {1.5u}] \
      [list pair {1.5 2.5}] \
      [list note {50%}] \
      [list expr_ {[set ::en_canary 1]}]]] {} {} 0 ok]
set EN3_T [rw_text $EN3_ANS $EN_CTX]
check {EN3 a model name, a `-` placeholder, a value already written 1.5u, a two-token value and a percent all pass through VERBATIM - none of them becomes the absent column's blank, whose footnote would then be false about it - and a value holding a command substitution is rendered, never run: ::en_canary does not exist} \
  [list $EN3_T [rw_count $EN3_T {(no value reported)}] \
        [expr {[info exists ::en_canary] ? {CANARY-FIRED} : 0}]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    model  : sg13g2_lv_nmos} {    corner : -} \
                  {    w      : 1.5u} {    pair   : 1.5 2.5} \
                  {    note   : 50%} {    expr_  : [set ::en_canary 1]} {}] \
        0 0]

# --- EN4  A NON-FINITE VALUE IS NOT BLANKED, AND NEVER PRINTS AS A NUMBER ----
## Ruling DD-7: "blanking them would silently undo issue 1272, which this
## branch has already paid for once." `nan` used to print here verbatim, which
## invariant I3 forbids for a different reason, so neither the old behaviour nor
## eng_or_blank's blank is the answer: the words the window ALREADY HAS are.
## The `1e400` leg is the one that catches a direct to_eng call - it answers
## `infT`, and `infT` reads like a measurement.
set EN4_ANS [rw_ansd [dict create {@m.x1.m1} \
      {{id nan} {gm inf} {gds -inf} {ft 1e400} {vth 0.75}}] {} {} 0 ok]
set EN4_T [rw_text $EN4_ANS $EN_CTX]
check {EN4 a non-finite value arriving in the `devices` bucket renders the window's existing words, exactly as the nonfinite BUCKET does - never a blank, never `(no value reported)`, never the raw nan/inf text and never to_eng's `infT` - while the finite neighbour in the same block is untouched} \
  [list $EN4_T [rw_count $EN4_T {nan}] [rw_count $EN4_T {inf}] \
        [rw_count $EN4_T {(no value reported)}]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  "    id  : $RW_NF" "    gm  : $RW_NF" "    gds : $RW_NF" \
                  "    ft  : $RW_NF" {    vth : 0.75} {}] \
        0 0 0]

# --- EN5  ALL THREE OF THE WINDOW'S EXISTING WORDS SURVIVE, IN ONE BLOCK -----
## The three distinctions this window makes - a column with no value reported,
## a column that did not converge, and a column the raw names but the simulator
## never computed - are the reason issue 1272 and issue 1284 were paid for. A
## formatter is exactly the kind of change that flattens them, because every
## one of them arrives at the renderer as "not a number".
set EN5_ANS [rw_ansd [dict create {@m.x1.m1} {{ids 1.2e-05} {vth {}} {gm}}] \
                     {{@m.x1.m1 gds}} {{@m.x1.m1 vbs nan}} 0 ok]
set EN5_T [rw_text $EN5_ANS $EN_CTX]
check {EN5 engineering notation costs the window none of its vocabulary: the measured value is engineered, an empty and a value-less pair still say `(no value reported)`, the nonfinite bucket still says `(did not converge)`, the absent column is still a BLANK with no trailing space, and the blank-value footnote still rides exactly once} \
  [list $EN5_T [rw_count $EN5_T $RW_ABSN]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    ids : 12u} {    vth : (no value reported)} \
                  {    gm  : (no value reported)} "    vbs : $RW_NF" \
                  {    gds :} $RW_ABSN {}] 1]

# --- EN6  THE USER'S OWN PRECISION SETTING REACHES THE WINDOW ---------------
## `to_eng` reads the global `ev_precision` at call time and the user can set it
## (xschem.tcl:17740, "Enter precision (int)"). A second formatter in rdw.tcl
## carrying a hard-coded %.4g would pass EN1 and EN5 and be wrong the first time
## the user changed it - and the window and the sheet would then print DIFFERENT
## numbers for the same value, which is the one thing this item exists to stop.
##
## ⚠ THE ROW DRIVES BOTH PRECISIONS AND ASSERTS NEITHER AS THE USER'S -- ISSUE
## 1345.  It used to check `$EN6_SAVE` against the literal `4`, which made the
## suite hard-depend on the very preference the row is about: `set_ne
## ev_precision 4` (xschem.tcl:18540) is only a DEFAULT, so a
## `~/.xschem/xschemrc` carrying `set ev_precision 6` reds EN6 with nothing
## whatever wrong in the tree (MEASURED: `--preinit 'set ev_precision 6'`
## reds EN6 and ONLY EN6 -- 1.11e-05 is 11.1u and 1.2e-05 is 12u at both).
## The subject was never the default; it is that 4 and 6 print DIFFERENT
## numbers, that the window reads the global LIVE rather than caching it, and
## that it agrees with the sheet at whatever the user has set.
set EN6_SAVE [expr {[info exists ::ev_precision] ? $::ev_precision : {NOVAR}}]
set ::ev_precision 4
set EN6_P4 [rw_ans ::rdw::_value_text 1.234567e-05]
set ::ev_precision 6
set EN6_P6 [rw_ans ::rdw::_value_text 1.234567e-05]
if {$EN6_SAVE eq {NOVAR}} { catch {unset ::ev_precision} } else { set ::ev_precision $EN6_SAVE }
set EN6_BACK  [rw_ans ::rdw::_value_text 1.234567e-05]
set EN6_SHEET [rw_ans ::op_annot::eng_or_blank 1.234567e-05]
set EN6_REST  [expr {[info exists ::ev_precision] ? $::ev_precision : {NOVAR}}]
check {EN6 the window honours the user's ev_precision because it goes through the sheet's formatter and carries none of its own: precision 4 prints 12.35u, 6 prints 12.3457u, and at whatever the user actually has set the window prints exactly what the sheet prints - the row drives both settings and depends on neither being the shipped default} \
  [list $EN6_P4 $EN6_P6 $EN6_BACK $EN6_REST] \
  [list 12.35u 12.3457u $EN6_SHEET $EN6_SAVE]

# --- EN7  THE VALUES NOBODY WROTE A GOLDEN FOR, ADDED BY THE IMPLEMENTING PASS
## The implementing pass asked the brief's question - "write down the input most
## likely to break your change, and check whether any row would see it" - and
## found six that no row above sees, because they are values `to_eng`'s own SI
## ladder does not cover.  MEASURED on this binary at ev_precision 4:
##   1e-321   -> 9.98e-304a   (denormal, below atto: an exponent AND a suffix)
##   1e20     -> 1e+08T       (above tera: the same mixed form at the top)
##   0x10     -> 16           0b101 -> 5    +5 -> 5    5. -> 5    .5 -> 0.5
## Two of those read oddly and one silently rebases a hex literal, and NONE of
## it is this item's doing: it is `to_eng`, and the SHEET PRINTS THE SAME THING.
## That is the row.  DD-7's promise is not "every value is pretty", it is "the
## window and the sheet cannot disagree", so this row asks for the EQUALITY and
## for the two invariants that must hold whatever to_eng answers - the value is
## never blanked and never becomes `(did not converge)`.  Written as an
## equality on purpose: pinning `9.98e-304a` as a literal would fence a libm
## denormal this item does not own, and would red on the day someone fixes
## to_eng's ladder - at which point BOTH surfaces move together, which is the
## whole design.
set EN7_V {1e-321 1e20 0x10 0b101 +5 5. .5}
set EN7_GOT {} ; set EN7_WANT {} ; set EN7_BLANK 0 ; set EN7_NF 0
foreach v $EN7_V {
  set g [rw_ans ::rdw::_value_text $v]
  lappend EN7_GOT  $g
  lappend EN7_WANT [rw_ans ::op_annot::eng_or_blank $v]
  if {$g eq {}} { incr EN7_BLANK }
  if {$g eq $RW_NF} { incr EN7_NF }
}
check {EN7 a finite value outside to_eng's SI ladder - a denormal, a number above tera, a hex and a binary literal - still prints EXACTLY what the sheet prints for it, and is never blanked and never called a non-convergence: the guarantee this item buys is agreement, and it holds for the values nobody wrote a golden for} \
  [list $EN7_GOT $EN7_BLANK $EN7_NF] \
  [list $EN7_WANT 0 0]

# --- EN8  A NUMBER THE FORMATTER DECLINED IS NOT A NON-CONVERGENCE ----------
## ISSUE 1345, AND IT IS THE WORST THING THIS WINDOW CAN DO.  `_value_text`
## used to decide "this value is non-finite" by seeing an EMPTY string come
## back from `op_annot::eng_or_blank` -- and that proc answers {} for TWO
## different reasons the caller cannot tell apart: the value really is nan/inf,
## OR `to_eng` could not format a perfectly finite number.
##
## THE SECOND REASON IS REACHABLE FROM A SHIPPED MENU.  `Simulation > Set
## netlist / graph / annotation precision` (src/xschem.tcl:17738-17740) is a
## bare `input_line` free-text entry with NO validation, and its OK button runs
## `eval set ev_precision [.dialog.f1.e get]`, so anything typed STICKS.
## MEASURED on this binary, all eight of the values below stick and all eight
## make `format %.${pr}g` raise inside to_eng (xschem.tcl:1928/1930).  From
## that moment EVERY finite, correctly measured value in the pane read
## `(did not converge)` -- a claim about the CIRCUIT, printed for a number the
## simulator computed perfectly well, on the one surface this feature exists to
## have pasted into a design-review document.  Invariant I3 at its sharpest.
##
## IT ALSO BROKE R5'S OWN HEADLINE PROMISE: in that state the SHEET blanks the
## row (op_annot.tcl:2125 emits `id =`) while the WINDOW asserted a
## non-convergence, so the two surfaces DID disagree - the one thing ruling
## DD-7 and this whole item exist to stop.
##
## THE REPAIR ASKS THE QUESTION INSTEAD OF INFERRING IT: `op_annot::_finite`,
## the predicate `eng_or_blank` itself uses, so this file carries no second
## opinion about what non-finite means (row EN10 fences that).  When the value
## IS finite and the formatter merely declined, the window prints the RAW TEXT
## -- unformatted but TRUE, which is exactly what the pre-existing missing-
## formatter arm already did and what the file's comment already argued for.
##
## THE OTHER DIRECTION IS HALF THE ROW.  A repair that stopped saying
## `(did not converge)` altogether would pass the first leg and silently undo
## issue 1272, so a genuine nan and inf are driven at every broken precision
## too and must STILL say the words.
set EN8_SAVE [expr {[info exists ::ev_precision] ? $::ev_precision : {NOVAR}}]
set EN8_BAD {-1 2.5 abc 4x +4 0x4 6. 6.0}
set EN8_LIES {} ; set EN8_NF {} ; set EN8_WORDS 0 ; set EN8_BLANK 0
foreach pr $EN8_BAD {
  set ::ev_precision $pr
  foreach v {1.11e-05 0.001 0.75 0 -1.11e-05} {
    set g [rw_ans ::rdw::_value_text $v]
    ## THE CONTRACT, STATED RELATIVE TO THE SHEET ON PURPOSE.  Where the
    ## sheet's own proc still has an answer the window must print THAT ONE
    ## (DD-7); where it has none the window prints the RAW TEXT, which is
    ## unformatted but true.  Pinning literals here instead would fence
    ## `to_eng`'s behaviour under a garbage precision, which this item does
    ## not own -- MEASURED: at ev_precision `4x`, `to_eng 0` does not raise
    ## at all, it answers the string `0000g`, and the SHEET prints that too.
    ## ⚠ `if`, NOT `expr {... ? $v : $s}` -- caught by this very row on its
    ## first green run: expr NUMIFIES the branch it takes, so the golden for
    ## `1.11e-05` came out `1.11e-5` and the row reported a mismatch that was
    ## its own doing.  A string comparison's expected value must never be
    ## built by expr.
    set s [rw_ans ::op_annot::eng_or_blank $v]
    if {$s eq {}} { set want $v } else { set want $s }
    if {$g eq $RW_NF} { incr EN8_WORDS }
    if {$g eq {}} { incr EN8_BLANK }
    if {$g ne $want} { lappend EN8_LIES "$pr:$v=>$g want $want" }
  }
  foreach v {nan inf} {
    if {[rw_ans ::rdw::_value_text $v] ne $RW_NF} { lappend EN8_NF "$pr:$v" }
  }
}
if {$EN8_SAVE eq {NOVAR}} { catch {unset ::ev_precision} } else { set ::ev_precision $EN8_SAVE }
set EN8_BACK  [rw_ans ::rdw::_value_text 1.11e-05]
set EN8_SHEET [rw_ans ::op_annot::eng_or_blank 1.11e-05]
## The one HARD literal in the row: at the sharpest of the eight, the pane must
## read the number the simulator computed.
set ::ev_precision -1
set EN8_M1 [rw_ans ::rdw::_value_text 1.11e-05]
if {$EN8_SAVE eq {NOVAR}} { catch {unset ::ev_precision} } else { set ::ev_precision $EN8_SAVE }
check {EN8 a FINITE value the formatter merely declined is never called a non-convergence: with ev_precision set to each of the eight things the shipped precision menu accepts without validation, every measured value still prints what the SHEET prints for it, or its own true raw text where the sheet has no answer at all - never blanked, never `(did not converge)` - while a genuine nan and inf still DO say it, and putting the setting back restores the engineered number} \
  [list $EN8_LIES $EN8_NF $EN8_WORDS $EN8_BLANK \
        [expr {$EN8_BACK eq $EN8_SHEET}] [rw_bad $EN8_BACK] $EN8_M1] \
  [list {} {} 0 0 1 0 1.11e-05]

# --- EN9  THE EVALUATING FORMATTER REBASES NUMERIC LITERALS, AND BOTH ------
# --- SURFACES DO IT TOGETHER ------------------------------------------------
## ISSUE 1345's second half, and it is a CORRECTION TO THIS FILE'S OWN COMMENT
## rather than a behaviour change.  src/rdw.tcl said the `string is double
## -strict` gate was "a SECOND lock ... so a value that reached it unguarded
## would EVALUATE at global scope".  That is true only for NON-numeric strings.
## `to_eng` is `uplevel #0 expr [join $args]`, so every string that PASSES the
## gate still reaches `expr` at global scope, and expr REBASES numeric
## literals.  MEASURED on this binary, window and sheet alike:
##   010 -> 8    007 -> 7    00000000012 -> 10    0x10 -> 16    0b101 -> 5
## and `08`/`09` are not doubles at all, so they take the verbatim arm.
##
## NOT HARDENED HERE, DELIBERATELY.  Normalising the literal in rdw.tcl would
## print 10 in the window where the sheet prints 8 -- the exact disagreement
## ruling DD-7 forbids -- so this row pins the AGREEMENT and the measured
## values, which is what makes the corrected comment checkable.  Latent today:
## the only registrant of the `devices` bucket fills it from `xschem raw value`
## via op_annot::raw_class, i.e. C-formatted decimals that never carry a
## leading zero.  A future text-parsing producer (the blanket `set altshow`
## dump, issues 1333-1336) is the plausible way in, and it would red this row
## the moment it disagreed with the sheet.
set EN9_V {010 007 00000000012 0x10 0b101}
set EN9_GOT {} ; set EN9_WANT {} ; set EN9_BLANK 0 ; set EN9_NF 0
foreach v $EN9_V {
  set g [rw_ans ::rdw::_value_text $v]
  lappend EN9_GOT  $g
  lappend EN9_WANT [rw_ans ::op_annot::eng_or_blank $v]
  if {$g eq {}}     { incr EN9_BLANK }
  if {$g eq $RW_NF} { incr EN9_NF }
}
check {EN9 a leading-zero, hex or binary numeric literal is REBASED by the evaluating formatter - 010 prints 8, not 10 - and the window does it in lockstep with the sheet: the gate in rdw.tcl stops a NON-numeric string reaching `uplevel #0 expr`, it does not stop a numeric one, and hardening only this side would be the disagreement DD-7 forbids} \
  [list $EN9_GOT $EN9_BLANK $EN9_NF] \
  [list [list 8 7 10 16 5] 0 0]

# --- EN10 STRUCTURAL  THE WINDOW ASKS THE PREDICATE, IT DOES NOT INFER IT ---
## Issue 1345's repair is one line of reasoning and it is invisible in the
## numbers: EN8 goes green again the moment `_value_text` stops reading a blank
## as a verdict, but so would a version that grew its OWN finiteness test -
## `$v > -Inf`, a regexp on `nan|inf`, a `$v*0.0` of its own - and that is the
## drift item R5 exists to remove.  DD-7's promise is that the window and the
## sheet CANNOT disagree, which needs them to share the predicate, not merely
## to agree today.  So: `_value_text` names `op_annot::_finite`, it consults it
## BEFORE it chooses the non-convergence words, and this file spells the test
## exactly once - by calling it.
set EN10_B [rw_body ::rdw::_value_text]
set EN10_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]
check {EN10 STRUCTURAL the window asks op_annot::_finite - the predicate eng_or_blank itself uses - and asks it BEFORE it reaches for `(did not converge)`, and src/rdw.tcl carries no second spelling of the finiteness test: no Inf comparison, no nan regexp, no arithmetic of its own} \
  [list [rw_bad $EN10_B] \
        [expr {[rw_bad $EN10_B] ? 0 : [rw_has $EN10_B {op_annot::_finite}]}] \
        [expr {[rw_bad $EN10_B] ? 0 : \
               ([string first {_finite} $EN10_B] < \
                [string first {_nonfinite_text} $EN10_B])}] \
        [rw_count $EN10_F {*0.0}] [rw_count $EN10_F {-Inf}] \
        [rw_count $EN10_F {to_eng}]] \
  {0 1 1 0 0 0}

catch {unset ::en_canary}
set ::rdw::blocks {}
rw_ans ::rdw::set_row 0
rw_ans ::rdw::status {}


# ============================================================================
# SECTION S — THE STRUCTURAL FENCES, AND HYGIENE
# ============================================================================
# S1 is the seam's whole point stated as a fence: "nothing above it changes
# when the wildcard arrives". Calling ::ase::backend::ngspice::op_param_set
# directly is behaviourally IDENTICAL today, which is exactly why this row is
# structural rather than behavioural. The other four tokens are the forbidden
# doors: `xschem raw value` is the second reader invariant I3 forbids (issue
# 1272's own defect), ase::sim_capabilities STARTS THE USER'S SIMULATOR on a
# cache miss (ase.tcl:1777, and :3813's comment forbids it on a path with no
# Run behind it), blanket_op_save answers B1's question the way DD-1 forbids,
# and ase::theme has a one-way global font side effect that
# test_calc_skeleton's S13 exists to police.
# ⚠ op_param_lists:: is on the list for a different reason: B3's buttons are
# INERT, so B3 calls neither `load` nor `write_conf`, and staying off that
# namespace keeps this item clear of all six of B2's open defects 1276-1281 -
# including 1278, whose unbounded-glob freeze would otherwise land on the
# redraw path. B2a repairs them; B5 is where the store is wired.
# ⚠ WHOLE-LINE `#` COMMENTS ARE STRIPPED FIRST (as in H3), so the file may and
# should EXPLAIN the seam in prose above its code; what it may not do is call
# through it.
# RED before B3: S1 (the file does not exist).  GREEN before B3: S2.

## ⚠ THE SEVENTH TERM MOVED TO ROW BT22, BY ITEM B5, AND THE COMMENT ABOVE
## ANTICIPATED IT: "B5 is where the store is wired". `op_param_lists:: == 0`
## was true only while the button column was inert; B5's whole deliverable is
## the first real caller of `set_list`, `apply` and `write_conf`. The fence is
## not dropped, it is REPLACED BY A SHARPER ONE - BT22 asserts the file names
## the store ONLY through its published verbs and never a `_private` one, which
## is a stronger statement than a bare zero ever was. The other six tokens stay
## at zero here, unchanged.
# ============================================================================
# SECTION CY — THE COPY'S THREE DECISIONS, ON THE ARM WITH NO DISPLAY
# ============================================================================
# Issue 1344. The behavioural rows are CP13/CP14/CP15 of
# test_rdw_keys_1245.tcl: they need a mapped pane, a real drag, a real X
# selection and a real clipboard, so they are all behind that suite's
# `have_tk` guard and a machine with no display runs NONE of them.
#
# Every decision those rows are about is a PURE function, and pure functions
# run on both arms. So the three predicates are fenced here as well, where
# nothing can drop them: "is there anything worth copying", "how many lines is
# this", and "is that widget part of this window". A structural row underneath
# holds the four call sites to them, because a predicate nobody consults is a
# predicate that passes while the window goes on wiping the clipboard.

## CY1 — the guard that matters.
## `rdw::copy` used to ask `$txt eq {}`, which CANNOT be true of any span this
## window can produce: `get first last` with first < last always yields at
## least one character. The guard was dead, and the reachable class it should
## have caught is a span holding nothing but BLANK SPACE — of which the empty
## window's mandatory trailing newline is the instance that cost a user their
## clipboard.
set CY1_GOT {}
foreach _c [list {} "\n" { } {   } "\t" " \t\n " "x" " x " "\nx\n" {0}] {
  lappend CY1_GOT [rw_ans ::rdw::_worth_copying $_c]
}
check {CY1 the copy's guard asks whether there is anything WORTH copying, not whether the string is empty: a bare newline, a run of spaces, a tab and any mix of them are all refused, while any span carrying one printable character - `0` included, which is falsy in every other language the reader knows - is copied} \
  $CY1_GOT \
  {0 0 0 0 0 0 1 1 1 1}

## CY2 — one counter, so the two sentences cannot disagree.
## `rdw::select_all` counted the LINE NUMBER of `end - 1c` and `rdw::copy`
## counted the elements of `split $txt \n`. Measured before the fix, on one and
## the same Select All: "Selected the whole window, 7 lines." then "Copied 8
## lines, 170 characters, to the clipboard." Both wrong, and wrong by different
## amounts. What the user is promised is the shape that lands in their
## document, so a trailing newline ENDS the last line rather than starting an
## empty new one.
set CY2_GOT {}
foreach _c [list {} {a} "a\n" "a\nb" "a\nb\n" "\n" "\n\n" "a\n\n" "a\nb\nc\n"] {
  lappend CY2_GOT [rw_ans ::rdw::_copy_lines $_c]
}
check {CY2 ONE counter for both sentences, and it counts the lines the PASTE will occupy: a trailing newline ends the last line instead of starting an empty new one, so `a` and `a<NL>` are both one line and `a<NL>b` and `a<NL>b<NL>` are both two - the split-on-newline arithmetic the copy used says two and three} \
  $CY2_GOT \
  {0 1 1 2 2 1 2 2 3}

## CY3 — a widget of this toplevel is not a foreign thief.
## `rdw::_selection_changed` used to test `$own eq {.rdw.p.t}` and nothing
## else, so the status entry — a readonly `entry` with -exportselection 1, and
## the widget item B5 writes the settings-file path into — was scored a FOREIGN
## theft the moment the user dragged across it, the stale mirror was kept, and
## Ctrl-C copied the pane.
set CY3_GOT {}
foreach _w [list {} {.} {.drw} {.rdw} {.rdw.p.t} {.rdw.s.msg} {.rdw.b.up} \
                 {.rdwx} {.rdwx.y} {.rdwctl}] {
  lappend CY3_GOT [rw_ans ::rdw::_in_window $_w]
}
check {CY3 the pane, the status entry and the button column are all THIS window - a selection made in any of them is the user's selection and not somebody else's theft - while the canvas, the main toplevel, a window that merely starts with the same letters and the empty answer `selection own` gives for a foreign owner are all not} \
  $CY3_GOT \
  {0 0 0 1 1 1 1 0 0 0}

## CY4 — and the four call sites, because a predicate nobody consults is a
## predicate that passes while the window goes on wiping the clipboard.
## The last two terms are the two doors on to the clipboard: the pane's own
## widget-tag chord, whose `break` is what stops Tk's `bind Text <<Copy>>`
## running as a SECOND copy that obeys none of these guards, and the count that
## says the dead `$txt eq {}` test is gone.
set CY4_SA [rw_body ::rdw::select_all]
set CY4_CP [rw_body ::rdw::copy]
set CY4_SC [rw_body ::rdw::_selection_changed]
set CY4_BD [rw_body ::rdw::build]
check {CY4 STRUCTURAL the three predicates are actually consulted: select_all tags to `end - 1c` and never to a bare `end`, copy asks _worth_copying instead of the dead `$txt eq {}`, both count through _copy_lines, copy reaches a selection standing in a sibling widget and routes its receipt through _copy_report, _selection_changed decides with _in_window rather than on the pane's name alone, and build binds the chord on the PANE so Tk's own Text class copy cannot run behind rdw::copy's back} \
  [list [rw_bad $CY4_SA] \
        [rw_has $CY4_SA {end - 1c}] \
        [rw_count $CY4_SA {tag add sel 1.0 end}] \
        [rw_has $CY4_SA {_worth_copying}] \
        [rw_has $CY4_SA {_copy_lines}] \
        [rw_bad $CY4_CP] \
        [rw_has $CY4_CP {_worth_copying}] \
        [rw_count $CY4_CP {$txt eq {}}] \
        [rw_has $CY4_CP {_copy_lines}] \
        [rw_has $CY4_CP {_sibling_selection}] \
        [rw_has $CY4_CP {_copy_report}] \
        [rw_bad $CY4_SC] \
        [rw_has $CY4_SC {_in_window}] \
        [rw_count $CY4_SC "\$own eq {.rdw.p.t}"] \
        [rw_bad $CY4_BD] \
        [rw_count $CY4_BD ".rdw.p.t <<Copy>>"]] \
  {0 1 0 1 1 0 1 0 1 1 1 0 1 0 0 1}

# ============================================================================
# SECTION NW — ISSUE 1300: KEYS 1 AND 2 NARROW THE CONTENT, NOT ONLY THE
# IDENTITY.  BOTH ARMS, BECAUSE EVERY DECISION HERE IS A PURE FUNCTION.
# ============================================================================
# The user's own first complaint, in their words: "1 key dumps ALL OP info for
# a MOS FET in the RDW, when it's supposed to dump only those parameters that
# get annotated on the schematic."  MEASURED on their own design before this
# fix: keys 1, 2 and 3 produced BYTE-IDENTICAL 1939-character blocks, and key 1
# printed 88 rows for one MOSFET of which their PDK's annotation list declares
# six.  `rdw::format_answer` took no list argument and no caller ever gave it
# one.
#
# ⚠ THE NARROWING HAS EXACTLY ONE DEFINITION IN THIS TREE AND THIS SECTION
# FENCES THAT IT IS THE ONE USED.  `::op_param_lists::effective` is it, reached
# through `rdw::_list_params` -- the reader item R2 already built for the
# reorder, so the pane's narrowing and the pane's ORDER cannot come from two
# opinions (invariant I1).  Issue 1300 refused its own option (a), "filter from
# op_annot::descriptor's params", for exactly that reason, and row NW7 is what
# reds if somebody re-derives it.
#
# ⚠ AND THE ORDER IS THE LIST'S, NOT THE RAW FILE'S.  Item R2 (issue 1338)
# already promises that Up and Down move the row in the window; a key that
# re-rendered in raw-file order would undo that promise on the very next press
# of 1.  The permutation is `rdw::_reslot_block`'s, unchanged and re-used, so
# there is one rule for "the list's order" and not two.
#
# ⚠ WHAT KEY 3 DOES IS UNCHANGED, AND NW2 IS THE CONTROL THAT SAYS SO.  Ruling
# D-5 and DD-1 make key 3 the escape hatch -- "what this run's raw actually
# holds" -- so it must keep printing every published row, in raw order, with no
# narrowing sentence at all.  A narrowing that reached key 3 would make the
# `complete` flag a lie and would leave the withheld rows unreachable.
#
# ⚠ AND THE SENTENCE IS NOT OPTIONAL.  A pane that silently drops 82 of 88 rows
# is DD-1's own failure shape one surface further out: the reader cannot tell a
# narrowed block from a device that published six columns.  So a narrowed block
# SAYS which list narrowed it, how many rows it withheld, how many of those did
# not converge, and that key 3 has them.  The list name goes in the BLOCK
# rather than in window chrome because the block is what the user pastes into a
# design review, and chrome does not travel with a paste (row NW10).
#
# ⚠ THE LABEL IS PAST TENSE ON PURPOSE.  "as it stood at this dump" is what
# makes issue 1300's option (c) objection LAPSE rather than merely change
# cause: a standing block is a record, the store is live, and a Delete that
# removes a row from the list does not re-render blocks already on screen
# (`rdw::_reslot_block` is a strict permutation -- its own comment: "adds
# nothing, removes nothing").  A present-tense label would be false the moment
# the user pressed Delete.
#
# RED BEFORE THE FIX, MEASURED ON THE UNMODIFIED TREE AT 79b0a0ce: NW1 NW3 NW4
# NW6 NW7 NW9 NW10 -- seven of the ten, because `rdw::format_answer` renders
# every published row whatever the ctx says and the four procs NW7 asks for do
# not exist.  GREEN BEFORE THE FIX, all three of them for a reason worth
# writing down rather than a reason to drop them:
#   NW2  the key-3 CONTROL.  Its whole content is that this change did not move
#        the escape hatch, so it is supposed to be green on both sides.
#   NW8  the DD-4/DD-6 DECK FENCE.  Same: its content is that the display
#        decision stayed out of the deck, which was true before and must stay
#        true after.
#   NW5  green VACUOUSLY before the fix -- with nothing narrowing anywhere,
#        "a ctx that names no list renders the un-narrowed block" is trivially
#        satisfied.  It becomes load-bearing the moment narrowing exists, and
#        its sabotage (narrow on a ctx with no list) is what proves it.

set NW_DESC [list devpath {\@m.@path@name} \
                  params {{nid nid 0} {ngm ngm 1} {nvth nvth 2}}]
catch {op_annot::register nw_dev $NW_DESC}
rw_ans ::op_param_lists::set_class nw_dev nwcls
## The SUMMARY list is owned so that it differs from the annotation list.  The
## annotation list is deliberately NOT owned, so it answers the PDK seed and
## row NW1 is about the shipped resolution path rather than about a store write.
rw_ans ::op_param_lists::set_list class nwcls summary {{ngm ngm 1}}

## SIX published columns for one primitive: four computed, one non-finite, one
## absent.  Three of the six are in the annotation list {nid ngm nvth}, and the
## computed ones are stored in an order the list does not hold, so a change that
## merely FILTERED and kept raw order would still red NW1.
set NW_ANS [rw_ansd [dict create {@m.nw1} {{nvth 0.75} {nid 1.11e-05} \
                                           {zzz 42} {ngm 0.001}}] \
                    {{@m.nw1 zabs}} {{@m.nw1 znf nan}} 0 ok]
proc nw_ctx {lst {cls nwcls}} {
  set c [rw_ctx {NW1:/} {@m.nw1} op NW1]
  if {$lst ne {}} { dict set c list $lst }
  if {$cls ne {}} { dict set c class $cls ; dict set c cellname {} }
  return $c
}
set NW_NARROW1 {Narrowed to the nwcls annotation list as it stood at this dump. 3 columns are not in that list and not shown; this run published 6 for this device. 1 of the withheld did not converge. Press 3 for everything this run published.}
set NW_NARROW2 {Narrowed to the nwcls summary list as it stood at this dump. 5 columns are not in that list and not shown; this run published 6 for this device. 1 of the withheld did not converge. Press 3 for everything this run published.}

check {NW1 THE USER'S FIRST COMPLAINT, CLOSED: key 1 prints the class's ANNOTATION list and nothing else - three of the six columns this run published - IN THE LIST'S OWN ORDER rather than the raw file's, and the block says which list narrowed it, how many rows it withheld and that key 3 has them} \
  [rw_text $NW_ANS [nw_ctx annotation]] \
  [rw_lines {NW1:/} {@m.nw1} $RW_INC $NW_NARROW1 \
            {    nid  : 11.1u} {    ngm  : 1m} {    nvth : 0.75} {}]

check {NW2 CONTROL key 3 is UNCHANGED - ruling D-5's escape hatch still prints every column this run published, in raw-file order, with the non-finite words, the absent blank, its footnote and NO narrowing sentence anywhere} \
  [rw_text $NW_ANS [nw_ctx all]] \
  [rw_lines {NW1:/} {@m.nw1} $RW_INC \
            {    nvth : 0.75} {    nid  : 11.1u} {    zzz  : 42} {    ngm  : 1m} \
            {    znf  : (did not converge)} {    zabs :} $RW_ABSN {}]

check {NW3 KEYS 1 AND 2 STOP RENDERING IDENTICAL BLOCKS, which is issue 1300's headline measurement inverted: the summary list is owned and holds one row, so key 2 prints that row alone and names the summary list, and the three blocks are pairwise different} \
  [list [rw_text $NW_ANS [nw_ctx summary]] \
        [expr {[rw_text $NW_ANS [nw_ctx annotation]] eq [rw_text $NW_ANS [nw_ctx summary]] ? 1 : 0}] \
        [expr {[rw_text $NW_ANS [nw_ctx annotation]] eq [rw_text $NW_ANS [nw_ctx all]] ? 1 : 0}] \
        [expr {[rw_text $NW_ANS [nw_ctx summary]] eq [rw_text $NW_ANS [nw_ctx all]] ? 1 : 0}]] \
  [list [rw_lines {NW1:/} {@m.nw1} $RW_INC $NW_NARROW2 {    ngm : 1m} {}] 0 0 0]

## NW4 — the EMPTY list, and the two agreements a counting sentence gets wrong.
## `nwzcls` is a class nobody declared and nobody owns, so `effective` answers
## the empty list rather than raising; the honest rendering is a SENTENCE, never
## a header followed by nothing, which reads as a broken window.
set NW_ONE   [rw_ansd [dict create {@m.nw1} {{nid 1.11e-05} {zzz 42}}] {} {} 0 ok]
set NW_ALLIN [rw_ansd [dict create {@m.nw1} {{nid 1.11e-05} {ngm 0.001}}] {} {} 0 ok]
check {NW4 THE EMPTY LIST IS A SENTENCE, NOT A BLANK BLOCK, and the counts agree with themselves: one withheld row reads `1 column is`, three read `3 columns are`, and a run every one of whose columns IS in the list says so instead of counting to zero} \
  [list [rw_text $NW_ANS   [nw_ctx annotation nwzcls]] \
        [rw_text $NW_ONE   [nw_ctx annotation]] \
        [rw_text $NW_ALLIN [nw_ctx annotation]]] \
  [list [rw_lines {NW1:/} {@m.nw1} $RW_INC \
           {The nwzcls annotation list was empty at this dump, so nothing this run published for this device is shown. Press 3 for everything this run published.} {}] \
        [rw_lines {NW1:/} {@m.nw1} $RW_INC \
           {Narrowed to the nwcls annotation list as it stood at this dump. 1 column is not in that list and not shown; this run published 2 for this device. Press 3 for everything this run published.} \
           {    nid : 11.1u} {}] \
        [rw_lines {NW1:/} {@m.nw1} $RW_INC \
           {Narrowed to the nwcls annotation list as it stood at this dump. Every column this run published for this device is in that list.} \
           {    nid : 11.1u} {    ngm : 1m} {}]]

check {NW5 A CALLER THAT CANNOT NAME A LIST NARROWS NOTHING - a ctx with no `list` key, and one whose device has no class, both render the un-narrowed block byte for byte, so the twenty hand-built contexts in this file and every future caller of the door keep today's answer instead of silently losing rows} \
  [list [expr {[rw_text $NW_ANS [nw_ctx {}]] eq [rw_text $NW_ANS [nw_ctx all]] ? 1 : 0}] \
        [expr {[rw_text $NW_ANS [nw_ctx annotation {}]] eq [rw_text $NW_ANS [nw_ctx all]] ? 1 : 0}] \
        [rw_has [rw_text $NW_ANS [nw_ctx {}]] {Narrowed to the}] \
        [rw_has [rw_text $NW_ANS [nw_ctx annotation {}]] {Narrowed to the}]] \
  {1 1 0 0}

check {NW6 THE THREE BUCKETS NARROW TOGETHER AND THE WITHHELD NON-CONVERGENCE IS SAID OUT LOUD: a `nonfinite` row no list declares is withheld like any other but is COUNTED in a clause of its own, so the one fact issue 1272 says a designer most wants to be told is stated rather than dropped; and the absent footnote follows the NARROWED absent bucket, so a block with no blank in it no longer explains what a blank means} \
  [list [rw_has [rw_text $NW_ANS [nw_ctx annotation]] {(did not converge)}] \
        [rw_has [rw_text $NW_ANS [nw_ctx annotation]] {1 of the withheld did not converge.}] \
        [rw_has [rw_text $NW_ANS [nw_ctx annotation]] $RW_ABSN] \
        [rw_has [rw_text $NW_ANS [nw_ctx all]] {(did not converge)}] \
        [rw_has [rw_text $NW_ANS [nw_ctx all]] $RW_ABSN] \
        [rw_has [rw_text $NW_ANS [nw_ctx all]] {of the withheld did not converge}]] \
  {0 1 0 1 1 0}

check {NW7 STRUCTURAL ONE DEFINITION OF THE NARROWING: format_answer asks rdw::_narrow_spec, which asks the item R2 reader rdw::_list_params, which asks ::op_param_lists::effective and nothing else - and neither the spec nor the renderer names op_annot::descriptor or reads a `params` key, which is the second definition issue 1300 refused option (a) over} \
  [list [rw_has [rw_body ::rdw::format_answer] {rdw::_narrow_spec}] \
        [rw_has [rw_body ::rdw::_narrow_spec] {rdw::_list_params}] \
        [rw_has [rw_body ::rdw::_list_params] {op_param_lists::effective}] \
        [rw_count [rw_body ::rdw::_narrow_spec] {op_annot::descriptor}] \
        [rw_count [rw_body ::rdw::format_answer] {op_annot::descriptor}] \
        [rw_count [rw_body ::rdw::_narrow_spec] {op_param_lists::effective}] \
        [rw_has [rw_body ::rdw::format_answer] {rdw::_reslot_block}] \
        [expr {[llength [info commands ::rdw::_narrow_answer]] ? 1 : 0}] \
        [expr {[llength [info commands ::rdw::_narrow_line]] ? 1 : 0}] \
        [expr {[llength [info commands ::rdw::_cols_are]] ? 1 : 0}]] \
  {1 1 1 0 0 0 1 1 1 1}

## NW8 / NW9 — a REAL sheet holding a REAL instance of the fixture type, so the
## deck fence and the ctx door are driven rather than asserted.  bs_mksym and
## bs_mksch are section BS's, re-used: one symbol shape for the whole file.
set NW_DIR [file join $scratch nw1300]
file mkdir $NW_DIR
set NW_SYM [file join $NW_DIR nw.sym]
set NW_SCH [file join $NW_DIR nw.sch]
bs_mksym $NW_SYM nw_dev
bs_mksch $NW_SCH $NW_SYM
xschem load $NW_SCH
catch {update idletasks}

## NW8 — RULINGS DD-4 AND DD-6, THE ONE THING THIS FIX MAY NOT DO: "a display
## decision NEVER changes what the simulator is asked to save".  The narrowing
## lives entirely in the renderer, so the deck's save cards for a real instance
## of this type are byte-identical whichever list the window is on, and they
## still carry every row the descriptor declared -- including the two the
## SUMMARY list does not.
set NW8_CARDS {}
set NW8_KEEP $::rdw::listkind
foreach _lk {annotation summary all} {
  catch {rw_ans ::rdw::set_list $_lk}
  lappend NW8_CARDS [rw_ans ::op_annot::_cards_for M1 {}]
}
catch {rw_ans ::rdw::set_list $NW8_KEEP}
set NW8_DESCP {}
catch {set NW8_DESCP [dict get [::op_annot::descriptor nw_dev] params]}
check {NW8 RULINGS DD-4 AND DD-6 the display decision stays out of the deck: a real instance's .save cards are the same three on all three list identities even though the summary list declares one row, and the descriptor's `params` - the ONE list op_annot::_cards_for builds cards from - is untouched} \
  [list [llength [lindex $NW8_CARDS 0]] \
        [expr {[lindex $NW8_CARDS 0] eq [lindex $NW8_CARDS 1] ? 1 : 0}] \
        [expr {[lindex $NW8_CARDS 1] eq [lindex $NW8_CARDS 2] ? 1 : 0}] \
        [rw_count [lindex $NW8_CARDS 1] {[nvth]}] \
        $NW8_DESCP] \
  [list 3 1 1 1 {{nid nid 0} {ngm ngm 1} {nvth nvth 2}}]

## NW9 — THE SEAM'S ONLY DOOR CARRIES THE LIST AND THE SUBJECT, exactly as it
## already carries `sim` (issue 1284) and `simtype` (issue 1298).  Without this
## the keys would select an identity that never reached the renderer, which IS
## issue 1300.  A ctx that already names a list still wins, so every hand-built
## context in this file is unaffected.
set NW9_BODY [rw_body ::rdw::dump_devpath]
set NW9_KEEP $::rdw::listkind
catch {rw_ans ::rdw::set_list summary}
set NW9_S [rw_ans ::rdw::_list_ctx [rw_ctx {M1:/} {@m.M1} op M1]]
catch {rw_ans ::rdw::set_list annotation}
set NW9_A [rw_ans ::rdw::_list_ctx [rw_ctx {M1:/} {@m.M1} op M1]]
set NW9_W [rw_ans ::rdw::_list_ctx [dict replace [rw_ctx {M1:/} {@m.M1} op M1] list all]]
set NW9_N [rw_ans ::rdw::_list_ctx [rw_ctx {M1:/} {@m.M1} op ZZNOSUCHINST]]
catch {rw_ans ::rdw::set_list $NW9_KEEP}
proc nw9 {c k} {
  if {[rw_bad $c]} { return $c }
  if {![dict exists $c $k]} { return NOKEY }
  return [dict get $c $k]
}
check {NW9 THE SEAM'S ONLY DOOR AMENDS THE CTX WITH THE LIVE LIST IDENTITY AND THE DEVICE'S CLASS, the way it already amends `sim` and `simtype`: a key press narrows without any caller knowing how, the identity really follows rdw::set_list, a ctx that already names a list still wins, and an instance the editor cannot resolve gets NO class rather than a guessed one} \
  [list [rw_bad $NW9_BODY] [rw_has $NW9_BODY {rdw::_list_ctx}] \
        [nw9 $NW9_S list] [nw9 $NW9_A list] [nw9 $NW9_W list] \
        [nw9 $NW9_A class] [file tail [nw9 $NW9_A cellname]] \
        [nw9 $NW9_N list] [nw9 $NW9_N class]] \
  [list 0 1 summary annotation all nwcls nw.sym annotation NOKEY]

check {NW10 THE LIST NAME TRAVELS WITH THE PASTE: the narrowing sentence is a line of the BLOCK, so rdw::block_text hands it to the clipboard and a dump pasted into a design review says which list it came from and that it is not the whole run - which a window title or a chrome label above the pane could not do - and it is a `note` line, not a value row} \
  [list [rw_has [rw_ans ::rdw::block_text [rw_block $NW_ANS [nw_ctx annotation]]] $NW_NARROW1] \
        [rw_has [rw_ans ::rdw::block_text [rw_block $NW_ANS [nw_ctx summary]]] $NW_NARROW2] \
        [rw_has [rw_ans ::rdw::block_text [rw_block $NW_ANS [nw_ctx all]]] {Narrowed to the}] \
        [lindex [lindex [rw_block $NW_ANS [nw_ctx annotation]] 3] 0] \
        [rw_ans ::rdw::_row_param [lindex [rw_block $NW_ANS [nw_ctx annotation]] 3]]] \
  {1 1 0 note {}}


# ============================================================================
# SECTION LX — ISSUE 1355: THE WINDOW SAYS WHICH LIST IS IN FORCE, AND THE
# SCOPE DIALOG SAYS WHICH LIST IT IS ABOUT
# ============================================================================
# THE USER'S SECOND COMPLAINT, IN THEIR OWN WORDS: "When I use 2 key, the RDW
# doesn't say 'summary' view, so it's not clear.  The fact that the Delete
# button is NOT greyed out is a clue. ... I ... press Delete and get the pop up
# dialog asking where to apply, but it doesn't say 'summary list'."
#
# MEASURED AT HEAD d81b4b24, AFTER THE NARROWING LANDED, ON THE USER'S OWN
# M18:/x1/x1: the window TITLE is `Results Display Window` on all three
# identities, the status line is EMPTY on the dump path, `.rdw` has exactly
# three children (`.rdw.s .rdw.b .rdw.p`) and none of them names a list, and
# the REAL scope dialog raised by a real Delete is BYTE-IDENTICAL on
# annotation and on summary: `.rdw.scope.q` = "Delete on M18: which devices
# should this change?", two scope radiobuttons, OK, Cancel, and NO `.q2` at
# all.  So the only on-screen difference between list 1 and list 2 is still
# the Add button's grey, which is what the user reached for -- and it is
# EVIDENCE FOR "not list 3" AND NO EVIDENCE AT ALL FOR "I am on summary".
#
# ⚠ THE BLOCK ALREADY NAMES A LIST AND THIS IS NOT A SECOND ANNOUNCEMENT.
# Issue 1353's narrowing sentence (`rdw::_narrow_line`, row NW10) is PAST
# TENSE and is about THE BLOCK -- "as it stood at this dump" -- because a block
# is a RECORD that travels with the paste.  The chrome is PRESENT TENSE and is
# about THE BUTTONS: it names the identity `::rdw::listkind` holds now, which
# is what Up, Down, Delete and Add will act on WHATEVER dump the user happens
# to be reading.  They are two different facts and they answer two different
# questions; the failure the user hit is exactly the gap between them, because
# pressing 2 without re-dumping leaves a block saying `annotation` over buttons
# acting on `summary`.  Rows LX5 and LX10 are the fences that keep them one
# builder and keep the chrome OUT of the paste.
#
# ⚠ AND THE CHROME DOES NOT SAY THE PANE IS WIDER THAN THE LIST.  The list-
# identity diagnosis proposed a second sentence, "The pane shows every row this
# run published", and said in the same breath that it must be DELETED when the
# narrowing lands.  It landed first (issue 1353), so it is never written.  Row
# LX4 is the fence: a chrome line that went on telling the user the pane is
# wider than the list after it stopped being true would be the same defect as
# the status line that cited a fixed issue 1312 as its reason.
#
# RED BEFORE THE FIX: every row of this section except LX11's silent legs.
# The six procs LX1..LX6 assert do not exist, `.rdw.hdr` does not exist,
# `.rdw.scope.q2` does not exist on lists 1 and 2, and `rdw::button` reports a
# one-row edit with no word about the six rows the user had highlighted.

set LX_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]

check {LX1 ONE BUILDER FOR THE LIST'S NAME AND ITS GLOSS: three identities, one table each, and the phrase composes them - so the dialog's radiobuttons, the dialog's new statement, the chrome line and the window title cannot drift into four wordings of one fact, which is this file's own rule at rdw::_buttons} \
  [list [rw_ans ::rdw::_list_name annotation] [rw_ans ::rdw::_list_name summary] \
        [rw_ans ::rdw::_list_name all] [rw_ans ::rdw::_list_name zznosuch] \
        [rw_ans ::rdw::_list_gloss annotation] [rw_ans ::rdw::_list_gloss summary] \
        [rw_ans ::rdw::_list_phrase annotation] [rw_ans ::rdw::_list_phrase summary] \
        [rw_ans ::rdw::_list_phrase all] [rw_ans ::rdw::_list_phrase zznosuch]] \
  [list {the annotation list} {the summary list} {everything this run published} {} \
        {drawn on the sheet} {computed, not drawn} \
        {the annotation list (drawn on the sheet)} \
        {the summary list (computed, not drawn)} \
        {everything this run published (live from the simulator)} {}]

check {LX2 THE LIST AN EDIT WILL ACTUALLY WRITE IS NOT ALWAYS THE LIST THE USER IS STANDING ON - spec 4.2 B7's Add cell says a summary-list Add writes the ANNOTATION list, MEASURED on the user's own M18 as `Add: gm is already in the mos annotation list` after a press made on the summary list - so the answer has ONE proc and the dialog can name it} \
  [list [rw_ans ::rdw::_edit_list delete annotation] \
        [rw_ans ::rdw::_edit_list delete summary] \
        [rw_ans ::rdw::_edit_list up summary] \
        [rw_ans ::rdw::_edit_list down annotation] \
        [rw_ans ::rdw::_edit_list add summary] \
        [rw_ans ::rdw::_edit_list add all] \
        [rw_ans ::rdw::_edit_list delete all]] \
  [list annotation summary summary annotation annotation annotation annotation]

check {LX3 THE SCOPE DIALOG'S STATEMENT: lists 1 and 2 get a STATEMENT in the slot where list 3 already asks its QUESTION, so the dialog names a list in all three states instead of one - and the Add-from-summary case names the annotation list AND says where to choose, because naming the identity in force would have been the wrong list} \
  [list [rw_ans ::rdw::_scope_statement delete annotation] \
        [rw_ans ::rdw::_scope_statement delete summary] \
        [rw_ans ::rdw::_scope_statement add summary] \
        [rw_ans ::rdw::_scope_statement add all] \
        [rw_ans ::rdw::_scope_statement delete all]] \
  [list {This changes the annotation list (drawn on the sheet).} \
        {This changes the summary list (computed, not drawn).} \
        {This changes the annotation list (drawn on the sheet). Add writes there even from the summary list - press 3 first to choose the list.} \
        {} {}]

check {LX4 THE CHROME LINE IS PRESENT TENSE AND IS ABOUT THE BUTTONS, not about the pane: it names the identity the keys chose and says the buttons act on THAT list rather than on the block being read - and it does NOT say the pane is wider than the list, because issue 1353's narrowing landed first and a sentence that outlived its fact is the defect this batch keeps paying for} \
  [list [rw_ans ::rdw::_chrome_line annotation] \
        [rw_ans ::rdw::_chrome_line summary] \
        [rw_ans ::rdw::_chrome_line all] \
        [rw_ans ::rdw::_chrome_line zznosuch] \
        [rw_count [rw_ans ::rdw::_chrome_line summary] {every row this run published}] \
        [rw_count [rw_ans ::rdw::_chrome_line annotation] {every row this run published}]] \
  [list {Keys 1/2/3: the annotation list (drawn on the sheet) - the buttons edit this list, not the block you are reading.} \
        {Keys 1/2/3: the summary list (computed, not drawn) - the buttons edit this list, not the block you are reading.} \
        {Keys 1/2/3: everything this run published (live from the simulator) - press 1 or 2 to edit a list; only Add works here.} \
        {} 0 0]

check {LX5 STRUCTURAL ONE BUILDER, SEVERAL CONSUMERS: the button column, the dialog's default and the dialog's statement all ask rdw::_edit_list; the two radiobuttons, the statement and the chrome all ask rdw::_list_phrase; each gloss is a literal EXACTLY ONCE in the file; and rdw::set_list still calls exactly ONE refresher, so a key press cannot move the buttons without moving the words} \
  [list [rw_has [rw_body ::rdw::button] {_edit_list}] \
        [rw_has [rw_body ::rdw::scope_dialog] {_edit_list}] \
        [rw_has [rw_body ::rdw::scope_dialog_build] {_scope_statement}] \
        [rw_has [rw_body ::rdw::_scope_statement] {_edit_list}] \
        [rw_has [rw_body ::rdw::scope_dialog_build] {_list_phrase}] \
        [rw_has [rw_body ::rdw::_chrome_line] {_list_phrase}] \
        [expr {$LX_F eq {NOFILE} ? {NOFILE} : [rw_count $LX_F {drawn on the sheet}]}] \
        [expr {$LX_F eq {NOFILE} ? {NOFILE} : [rw_count $LX_F {computed, not drawn}]}] \
        [rw_count [rw_body ::rdw::set_list] {rdw::apply_list_state}] \
        [rw_has [rw_body ::rdw::apply_list_state] {_chrome_line}] \
        [rw_has [rw_body ::rdw::apply_list_state] {_title}] \
        [rw_has [rw_body ::rdw::build] {rdw::apply_list_state}]] \
  [list 1 1 1 1 1 1 1 1 1 1 1 1]

check {LX6 THE TITLE NAMES THE LIST TOO, and it is the SECOND surface rather than the first: a window manager may truncate it and it is the furthest thing on screen from the pane, but it survives the window being small and it is what the taskbar shows - and an identity the window cannot name falls back to the spec's plain title rather than to a half-written one} \
  [list [rw_ans ::rdw::_title annotation] [rw_ans ::rdw::_title summary] \
        [rw_ans ::rdw::_title all] [rw_ans ::rdw::_title zznosuch]] \
  [list {Results Display Window - the annotation list} \
        {Results Display Window - the summary list} \
        {Results Display Window - everything this run published} \
        {Results Display Window}]

check {LX10 THE CHROME DOES NOT TRAVEL WITH THE PASTE, which is row NW10's other half: the block is the RECORD and says which list narrowed it in the past tense, the chrome is the STATE and says which list the buttons act on now - so block_text carries the narrowing sentence and carries neither the chrome line nor the title, and a dump pasted into a design review is not stamped with an identity the user has since changed} \
  [list [rw_has [rw_ans ::rdw::block_text [rw_block $NW_ANS [nw_ctx annotation]]] $NW_NARROW1] \
        [rw_has [rw_ans ::rdw::block_text [rw_block $NW_ANS [nw_ctx annotation]]] {Keys 1/2/3}] \
        [rw_has [rw_ans ::rdw::block_text [rw_block $NW_ANS [nw_ctx summary]]] {Keys 1/2/3}] \
        [rw_has [rw_ans ::rdw::block_text [rw_block $NW_ANS [nw_ctx all]]] {Keys 1/2/3}] \
        [rw_has [rw_ans ::rdw::block_text [rw_block $NW_ANS [nw_ctx annotation]]] {Results Display Window}]] \
  [list 1 0 0 0 0]

check {LX11 ISSUE 1356: SELECTING LINES IS NOT SELECTING THEM FOR EDITING, and the window says so exactly when it matters - the note is one sentence, it fires only on a selection covering two lines or more, and with no Tk at all it is silent, so the --nogui arm and a window with no selection are never told about a gesture nobody made} \
  [list [rw_ans ::rdw::_selection_note] \
        [rw_ans ::rdw::_selection_lines] \
        [expr {[llength [info commands ::rdw::_selection_note]] ? 1 : 0}] \
        [expr {[llength [info commands ::rdw::_selection_lines]] ? 1 : 0}] \
        [rw_has [rw_body ::rdw::_selection_note] {_selection_lines}] \
        [rw_has [rw_body ::rdw::button] {_selection_note}]] \
  [list {} 0 1 1 1 1]

if {$live_tk} {
  rw_ans ::rdw::open
  catch {update idletasks}
  set LX7_KEEP $::rdw::listkind
  proc lx_hdr {} {
    if {![winfo exists .rdw.hdr]} { return NO-WIDGET }
    return [rw_w .rdw.hdr cget -text]
  }
  catch {rw_ans ::rdw::set_list annotation} ; catch {update idletasks}
  set LX7_A [lx_hdr] ; set LX8_A [rw_w wm title .rdw]
  catch {rw_ans ::rdw::set_list summary} ; catch {update idletasks}
  set LX7_S [lx_hdr] ; set LX8_S [rw_w wm title .rdw]
  catch {rw_ans ::rdw::set_list all} ; catch {update idletasks}
  set LX7_W [lx_hdr] ; set LX8_W [rw_w wm title .rdw]
  ## A CLOSE AND A REOPEN, because rdw::build retitles and rebuilds the chrome
  ## from scratch and `::rdw::listkind` outlives the window.  MEASURED at HEAD:
  ## build DECLARES `variable listkind` and never reads it, so a window rebuilt
  ## while the summary list was in force came back titled for no list at all.
  catch {rw_ans ::rdw::close} ; catch {update idletasks}
  catch {rw_ans ::rdw::open} ; catch {update idletasks}
  set LX7_R [lx_hdr] ; set LX8_R [rw_w wm title .rdw]
  set LX7_CLASS [rw_w winfo class .rdw.hdr]
  set LX7_TAKE [rw_w .rdw.hdr cget -takefocus]
  set LX7_SIDE [rw_ans dict get [rw_w pack info .rdw.hdr] -side]
  set LX7_ORDER 0
  set LX7_SLAVES [rw_w pack slaves .rdw]
  if {![rw_bad $LX7_SLAVES]} {
    set _h [lsearch -exact $LX7_SLAVES .rdw.hdr]
    set _p [lsearch -exact $LX7_SLAVES .rdw.p]
    set LX7_ORDER [expr {$_h >= 0 && $_p >= 0 && $_h < $_p ? 1 : 0}]
  }
  check {LX7 THE LIVE CHROME: a ::label above the pane whose text follows rdw::set_list for all three identities and comes back correct after a close and a reopen - a LABEL because no widget in this window may take the keyboard (issue 1308) and because a label can never own PRIMARY, so it cannot join a copy} \
    [list $LX7_A $LX7_S $LX7_W $LX7_R $LX7_CLASS $LX7_TAKE $LX7_SIDE $LX7_ORDER] \
    [list [rw_ans ::rdw::_chrome_line annotation] [rw_ans ::rdw::_chrome_line summary] \
          [rw_ans ::rdw::_chrome_line all] [rw_ans ::rdw::_chrome_line all] \
          Label 0 top 1]

  check {LX8 THE LIVE TITLE follows the same setter and the same rebuild - so the identity is on screen even when the pane is scrolled away, the window is small or the user is looking at the taskbar} \
    [list $LX8_A $LX8_S $LX8_W $LX8_R] \
    [list [rw_ans ::rdw::_title annotation] [rw_ans ::rdw::_title summary] \
          [rw_ans ::rdw::_title all] [rw_ans ::rdw::_title all]]

  ## THE REAL DIALOG, THROUGH ITS REAL BUILDER.  `rdw::scope_dialog` is stubbed
  ## in this section of the suite (the b5_dlg rename above), but
  ## `rdw::scope_dialog_build` is NOT, so the widgets a real Delete would raise
  ## can be read without a modal and without a grab -- the cheapest way to gold
  ## a dialog and the one row 0803 cannot hang.
  set LX9_SUBJ [dict create instname M18 class mos cellname sky130_fd_pr/nfet_01v8_lvt type nmos]
  proc lx_dlg {op ln} {
    catch {destroy .rdw.scope}
    set r [rw_ans ::rdw::scope_dialog_build $op $::LX9_SUBJ $ln]
    if {[rw_bad $r]} { return [list $r $r $r $r] }
    set out {}
    foreach w {.rdw.scope.q2 .rdw.scope.li.annotation .rdw.scope.li.summary} {
      lappend out [expr {[winfo exists $w] ? [rw_w $w cget -text] : {ABSENT}}]
    }
    lappend out [rw_w wm title .rdw.scope]
    catch {destroy .rdw.scope}
    return $out
  }
  set LX9_A [lx_dlg delete annotation]
  set LX9_S [lx_dlg delete summary]
  set LX9_ADD [lx_dlg add summary]
  set LX9_W [lx_dlg add all]
  check {LX9 THE USER'S OWN SENTENCE, ANSWERED: the pop-up now says which list it is about on lists 1 and 2 - a STATEMENT in the exact slot where list 3 asks its QUESTION - list 3 is untouched and still asks, an Add made from the summary list names the ANNOTATION list it will really write, and the two radiobutton glosses are the shared phrase rather than two more literals} \
    [list $LX9_A $LX9_S $LX9_ADD $LX9_W] \
    [list [list [rw_ans ::rdw::_scope_statement delete annotation] ABSENT ABSENT {Which devices?}] \
          [list [rw_ans ::rdw::_scope_statement delete summary] ABSENT ABSENT {Which devices?}] \
          [list [rw_ans ::rdw::_scope_statement add summary] ABSENT ABSENT {Which devices?}] \
          [list {And which list should it go into?} \
                [rw_ans ::rdw::_list_phrase annotation] \
                [rw_ans ::rdw::_list_phrase summary] {Which devices?}]]
  catch {rw_ans ::rdw::set_list $LX7_KEEP}
  ## THE SECTION LEAVES THE WINDOW AS IT FOUND IT.  Row S2 asserts no toplevel
  ## of the suite's own is still standing when the file ends, and the file's
  ## own clean-up runs AFTER S2 - so a section that reopens `.rdw` has to shut
  ## it itself.  MEASURED: without this line S2 reds.
  catch {destroy .rdw.scope}
  catch {rw_ans ::rdw::close}
  catch {update idletasks}
}

set S1_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]
check {S1 STRUCTURAL the forbidden doors: rdw.tcl reaches the seam ONLY through ase::backend_hook, never by the backend proc's name, and names none of `xschem raw value` / ase::sim_capabilities / blanket_op_save / ase::theme (op_param_lists:: moved to row BT22 when item B5 wired the store)} \
  [list [expr {$S1_F eq {NOFILE} ? {NOFILE} : [rw_has $S1_F {ase::backend_hook}]}] \
        [rw_count $S1_F {::ase::backend::ngspice::}] \
        [rw_count $S1_F {raw value}] \
        [rw_count $S1_F {sim_capabilities}] \
        [rw_count $S1_F {blanket_op_save}] \
        [rw_count $S1_F {ase::theme}]] \
  {1 0 0 0 0 0}

## An untracked untitled*.sch in the repo root turns THREE tests red. ⚠ The
## repo root ALREADY holds untitled~.sch and untitled~.sym and they are
## DELIBERATELY LEFT THERE (the known cause of test_ase_core's C11 baseline
## red, a phantom nothing in this batch may "fix"), so the row compares the
## glob against itself rather than asserting it is empty.
check {S2 HYGIENE the suite creates no untitled* anywhere and leaves no toplevel of its own behind} \
  [list [expr {[lsort [glob -nocomplain -directory $repo -tails untitled*]] eq $S2_ROOT0 ? 1 : 0}] \
        [llength [glob -nocomplain -directory $scratch -tails untitled*]] \
        [llength [glob -nocomplain -directory $here -tails untitled*]] \
        [expr {$live_tk ? [rw_w winfo exists .rdw] : 0}]] \
  {1 0 0 0}

# --- clean up ---------------------------------------------------------------
catch {xschem raw clear}
if {$live_tk} { rw_ans ::rdw::close ; catch {destroy .rdwctl} }

# ============================================================================
# THE CHECK-COUNT FLOOR — TRAP 7, WHICH THIS SUITE HAD NO GUARD RAIL FOR
# ============================================================================
# Copied verbatim in shape from KX_FLOOR (test_rdw_keys_1245.tcl:1713), minted
# after a run of THAT suite silently executed fewer rows and still printed ALL
# PASS. Until item B5-3 only the keys suite carried a floor; this one gained a
# whole section of Tk-gated and dialog-gated rows with nothing watching the
# denominator, and a green count is a statement about the FENCE.
#
# ⚠ IT IS THE --nogui MINIMUM, NOT THE Tk NUMBER. The display arm runs the
# `live_tk` rows too (121 with item B5's rows in place), so an equality would
# red every headless run. The floor is the arm that runs FEWEST rows.
#
# ⚠ IT IS A FLOOR, NOT AN EQUALITY. Adding rows must not red the suite: RAISE
# it when you add them, and NEVER lower it to make a run pass, which is the one
# move that would put the skipped-row defect straight back.
#
# ⚠ IT IS AN `incr fail`, NOT A `check`. A `check` would add itself to $npass
# and inflate the very number it is guarding.
#
# 83 (HEAD 59ef24af, --nogui) + 24 (item B5's preserved section BT, of whose 25
# rows one is `live_tk`-gated) + 2 (item B5-3's BT29 and BT30) = 109.
## ⚠ AND RAISED 109 -> 116 BY ITEM R1 (issue 1337), IN THE SAME COMMIT AS THE
## SEVEN ROWS IT COVERS: section CU's CU1..CU5, the line cursor's palette half
## and DD-1, plus CU16 and CU17, which the implementing pass added for the two
## questions those five do not ask -- a theme that answers a colour NAME, and
## the stale-target sweep on the arm with no Tk to repaint.  All seven run on
## BOTH arms.  A floor is raised when rows are added and NEVER lowered to make a
## run pass.
## ⚠ AND RAISED 116 -> 124 BY ITEM R2 (issue 1338), IN THE SAME COMMIT AS
## THE EIGHT ROWS IT COVERS: section RE's RE0..RE7, Up and Down moving the row
## in the window and the sheet following.  All eight run on BOTH arms.  A floor
## is raised when rows are added and NEVER lowered to make a run pass.
## ⚠ AND RAISED 124 -> 127 BY ITEM R4 (issue 1340), IN THE SAME COMMIT AS THE
## THREE ROWS IT COVERS: section RH's RH1 and RH2, the two fences round the
## raise, plus RH3, which the implementing pass added for the question those
## two do not ask -- that the two halves of the split are still JOINED.  All
## three run on BOTH arms.  R4's RED rows are section RA of
## test_rdw_keys_1245.tcl, which needs a stacking order and a keyboard.  A
## floor is raised when rows are added and NEVER lowered to make a run pass.
## ⚠ AND RAISED 127 -> 131 BY THE REPAIR OF ISSUE 1344, IN THE SAME COMMIT AS
## THE FOUR ROWS IT COVERS: section CY's CY1..CY4, the copy's three pure
## decisions and the structural row over their call sites.  All four run on
## BOTH arms - which is why they are here at all: 1344's behavioural rows
## (CP13..CP15 of test_rdw_keys_1245) are every one of them behind that suite's
## `have_tk` guard.  A floor is raised when rows are added and NEVER lowered to
## make a run pass.
## ⚠ AND RAISED 131 -> 134 BY THE REPAIR OF ISSUE 1345, IN THE SAME COMMIT AS
## THE THREE ROWS IT COVERS: EN8 (a finite value the formatter merely declined
## is never called a non-convergence, driven at all eight precisions the
## shipped menu accepts without validation), EN9 (the evaluating formatter
## rebases numeric literals, and both surfaces do it together) and EN10
## (structural: the window ASKS op_annot::_finite rather than inferring
## finiteness from a blank).  All three run on BOTH arms.  A floor is raised
## when rows are added and NEVER lowered to make a run pass.

## Issue 1345: put the reader's own precision back before the verdict.
if {$RW_EVP_SAVE eq {NOVAR}} { catch {unset ::ev_precision} } \
else { set ::ev_precision $RW_EVP_SAVE }

## ⚠ AND RAISED 134 -> 144 BY THE REPAIR OF ISSUE 1300, IN THE SAME COMMIT AS
## THE TEN ROWS IT COVERS: section NW's NW1..NW10, keys 1 and 2 narrowing the
## pane to the list they name, the sentence that says which list withheld what,
## the empty list, the caller that cannot name a list, the one-definition fence
## over `op_param_lists::effective`, the DD-4/DD-6 deck fence, the ctx door and
## the paste.  All ten run on BOTH arms - the narrowing is a pure function of an
## answer and a context, so nothing here needs a display; issue 1300's own
## behavioural rows are KN1 and KN2 of test_rdw_keys_1245.tcl, which need the
## cadence bind and a real canvas.  A floor is raised when rows are added and
## NEVER lowered to make a run pass.
## ⚠ AND RAISED 144 -> 152 BY THE REPAIR OF ISSUES 1355 AND 1356, IN THE SAME
## COMMIT AS THE EIGHT ROWS OF THIS SECTION THAT RUN ON BOTH ARMS: LX1..LX6,
## LX10 and LX11 - the one builder for the list's name and gloss, the list an
## edit really writes, the dialog's statement, the chrome sentence, the
## one-builder structural fence, the title, the fence that keeps the chrome OUT
## of the paste and the multi-row selection note.  This section's other four
## rows (LX7, LX8, LX9 and section BT's BT31) need a mapped window, a real
## label, a real dialog and a real text selection, so they are `live_tk`-gated
## and are deliberately NOT counted here - the floor is the arm that runs
## FEWEST rows.  Issue 1355's behavioural rows are LK1 and LK2 of
## test_rdw_keys_1245.tcl, which need the cadence bind and a real canvas.  A
## floor is raised when rows are added and NEVER lowered to make a run pass.
set RW_FLOOR 152
set RW_RAN [expr {$npass + $fail}]
if {$RW_RAN < $RW_FLOOR} {
  puts "FAIL: RWFLOOR the suite ran only $RW_RAN checks, below its floor of\
$RW_FLOOR — rows were SKIPPED, and a skipped row is not a passing one : FAIL"
  incr fail
}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }

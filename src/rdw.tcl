# rdw.tcl -- the Results Display Window (RDW).
#
# Item B3 of doc/claude/op_param_batch/PLAN.md, feature 1245.
# Spec: doc/claude/specs/op_param_lists.md sections 4.2 (B1/B2/B3/B7) and
# 5.1 (Q6, Q10).  Rulings: doc/claude/op_param_batch/DECISIONS.md D-3, D-4,
# D-5 and driver decision DD-1.
#
# ============================================================================
# WHY THIS WINDOW EXISTS, IN THE USER'S OWN WORDS
# ============================================================================
# The text must be SELECTABLE and COPYABLE so it can be pasted into
# design-review documents.  That is not a nice-to-have; it is the reason this
# is a window and not a line in the CIW.  So the pane is a real Tk text with
# a real selection, `-exportselection 1` so the X PRIMARY selection and
# Ctrl-C both work, and `-state disabled` so nobody can type into a record of
# a simulation.
#
# NOT `textwindow` (xschem.tcl:13567).  That proc takes a FILENAME, opens an
# EDITABLE widget, and its Save writes back to that file -- building on it
# would offer to save a results dump over one of the user's design files.
#
# ============================================================================
# WHAT THIS WINDOW SAYS, AND WHAT IT DOES NOT
# ============================================================================
# It says what THIS run's currently selected raw slot actually holds and
# actually computed for exactly this device path, which primitive each number
# belongs to, which columns the simulator did not compute, which ones came
# back non-finite, THAT THE LIST IS NOT EVERYTHING THE DEVICE HAS, and -- when
# there is nothing -- WHICH of the five silences this is.
#
# It does NOT say that the run converged.  An empty `nonfinite` bucket is not
# proof: the same NaN in an ASCII raw arrives as a finite 0 and lands in
# `devices` (src/save.c, deliberate; issue 1272 is still open).  No sentence
# below claims convergence.
#
# ============================================================================
# THE SEAM'S ANSWER IS FIVE KEYS (ase::backend_hook <sim> op_param_set)
# ============================================================================
#   devices   ordered {<rawdev> {{<param> <value>} ...}}, raw-file order,
#             one entry per PRIMITIVE the request covers
#   absent    ordered {<rawdev> <param>} -- columns the raw NAMES and the
#             simulator did not compute
#   nonfinite ordered {<rawdev> <param> <text>} -- columns the raw DOES carry,
#             holding Inf/NaN: a device that did not converge
#   complete  the honesty flag AS DATA (0 for today's ngspice)
#   state     no_devpath | no_raw | not_op | not_annotated | ok
#
# ⚠ THE SHARPEST TRAP, MEASURED AND NOT INFERRED: a real device can appear in
# NO `devices` entry at all.  An all-dims=0 device answers
#     devices {} absent {{@m.x1.m9 id} {@m.x1.m9 vth}} state ok
# and a binary raw with NaN/Inf answers
#     devices {} nonfinite {{@m.x1.m8 id nan} {@m.x1.m8 vth inf}} state ok
# A renderer that walks `dict keys [dict get $ans devices]` prints an EMPTY
# dump for a real, named, non-converged device.  So the row set is the UNION
# of the rawdev names in all THREE buckets -- rdw::_rowdevs, below.
#
# ============================================================================
# THE THREE RENDERING OBLIGATIONS, ALL RULED, NONE OPTIONAL
# ============================================================================
# 1. `complete` 0 MUST BE VISIBLE (DD-1's corollary).  Key 3's answer is
#    incomplete BY CONSTRUCTION today, and a caller that renders the pairs
#    silently reads as a COMPLETE list -- the failure D-4 exists to prevent.
# 2. `nonfinite` renders "(did not converge)", never a blank and never the raw
#    `nan`/`inf` text.  A non-converged operating point is a RESULT a designer
#    wants told, not a gap.  Invariant I3 forbids the raw text.
# 3. The four non-`ok` states are FOUR DIFFERENT SENTENCES, and `ok` with an
#    empty union is a FIFTH.  `not_op` in particular means the user is looking
#    at a transient: say so, and say what to do.  None of them says
#    "nothing found".
#
# ============================================================================
# THREE LAYERS, SO THE RENDERER IS TESTABLE WITH NO Tk AT ALL
# ============================================================================
#   pure      _cadence_path  _rowdevs  _incomplete_line  _nonfinite_text
#             _state_sentence  format_answer  block_text  button_state
#   context   header  sim  dump  dump_devpath  push  status   (xschem/op_annot,
#             still no Tk)
#   Tk        have_tk  open  close  build  render_pane  set_list  inert
#             palette  color
#
# ⚠ SURVIVING --nogui BY NOT BEING CONSTRUCTED.  This file is reached by the
# UNGUARDED bare `source` block in xschem.tcl, so a single Tk command executed
# at SOURCE time aborts startup (issue 0663's mechanism).  Nothing below runs
# at source time but `namespace eval` and `proc`; every Tk command sits inside
# a proc behind rdw::have_tk.
#
# ⚠ THE BUTTONS ARE INERT IN THIS ITEM.  B3 ships the column, the greying and
# a test-drivable path to each button.  Item B5 wires them to the store and
# ships the two scope dialogs.  This file calls the list store not at all.
#
# Suite: tests/headless/test_rdw_window_1245.tcl (both arms).

namespace eval rdw {
    # THE STORE.  A list of blocks, NEWEST FIRST.  The pane is a projection of
    # this and never the other way round, which is what makes every renderer
    # row drivable under --nogui.
    variable blocks {}

    # Which list the button column is greying for: annotation | summary | all.
    # Spec 4.2 B7 greys per list; item B4 owns the keys that select one and
    # MUST drive rdw::set_list rather than minting a second state variable
    # (invariant I1's shape: one builder, several consumers).
    variable listkind annotation

    # The window's own status line.  Always settable, headless included.
    variable statusmsg {}

    # An explicit backend override, for the suite and for B4/B5.  Empty means
    # "resolve it" -- see rdw::sim.
    variable sim {}
}

# ---------------------------------------------------------------------------
# The live-Tk predicate.  Shape copied from simconf_have_tk (xschem.tcl:4009),
# NOT called across the namespace boundary.  The second half is not
# decoration: under --nogui `winfo` really is an undefined command, so
# `[info exists ::has_x]` alone would still raise.
proc rdw::have_tk {} {
    return [expr {[info exists ::has_x] && [llength [info commands winfo]] > 0}]
}

# ---------------------------------------------------------------------------
# THE PURE LAYER.  No Tk, no `xschem`, no backend: hand it a dict, get lines.

# Q6's already-taken default spelling.  The user asked for
# `M2B:/xdut/xbg/xamp1`; the tree has three spellings and none is that one, so
# this mints it from `xschem get sch_path`, whose measured shape carries BOTH
# a leading and a trailing dot (`.xdut.xbg.xamp1.`).  At the top sheet
# sch_path is `.` and the trim yields the empty string, so the header
# degenerates to `M1:/` -- the path stays rooted and the header's shape stays
# constant with depth, so two pastes from different sheets still align.
#
# `sim_sch_path` is deliberately NOT used: it strips every level above the
# point the raw was loaded at, so the header would stop matching the schematic
# the user is looking at.
proc rdw::_cadence_path {schpath} {
    return "/[string map {. /} [string trim $schpath .]]"
}

# THE UNION.  See the trap block at the top of this file: `devices` alone is
# not the row set, because a device whose every column is absent, or whose
# every column is non-finite, has no `devices` entry at all and is still a
# real device the user is looking at.  First-appearance order across
# devices -> absent -> nonfinite, raw-file order within each.
proc rdw::_rowdevs {ans} {
    set devs {}
    catch {set devs [dict keys [dict get $ans devices]]}
    set abs {}
    catch {set abs [dict get $ans absent]}
    foreach e $abs { lappend devs [lindex $e 0] }
    set nf {}
    catch {set nf [dict get $ans nonfinite]}
    foreach e $nf { lappend devs [lindex $e 0] }
    set out {}
    foreach d $devs {
        if {[lsearch -exact $out $d] < 0} { lappend out $d }
    }
    return $out
}

# OBLIGATION 1, and it is DD-1's corollary rather than a nicety: the seam
# hands `complete` over as DATA, and a window that renders the pairs without
# it reads as a complete list.  Printed only in state `ok` with a non-empty
# union -- under `no_raw` it would pair "no results are loaded" with "this is
# what the run saved", and under ok-with-nothing it says the same thing twice
# as the fifth sentence already does.
proc rdw::_incomplete_line {ans} {
    set c 0
    catch {set c [dict get $ans complete]}
    if {[string is boolean -strict $c] && $c} { return {} }
    return {Not a complete list: these are the operating-point columns this run saved for this device, not everything the device has.}
}

# OBLIGATION 2.  A column the raw carries for a device that did not converge
# is a RESULT, not a gap: it renders as words, never as the raw text and never
# as the blank an ABSENT column gets.  Invariant I3 forbids painting `nan`.
proc rdw::_nonfinite_text {text} {
    return {(did not converge)}
}

# The footnote that makes a blank value legible.  Invariant I3 says a missing
# vector renders BLANK -- not 0, not NaN, not the previous run's number -- and
# a bare blank after a colon reads as a bug, so the block says once what a
# blank means, exactly when there is one.
proc rdw::_absent_line {} {
    return {A blank value means the raw names that column but the simulator did not compute it.}
}

# ISSUE 1282 / RULING DD-5.  THE SEAM'S ALLOW-LIST IS `{op dc}`, NOT `{op}`.
# ase.tcl:8803 copied it DELIBERATELY from update_op()'s own guard in
# src/save.c, so that this window and the on-sheet annotation agree about what
# counts as an operating point.  A raw whose current slot is a DC transfer
# characteristic therefore answers `ok` with real point-0 numbers, and this
# window presented them under a heading saying "operating-point" with the word
# `dc` NOWHERE ON SCREEN (measured: sim_type dc, state ok, block mentions dc
# zero times).  A DC sweep's point 0 is the first step of the sweep, not the
# circuit's quiescent point, and pasting that into a design review under an
# "operating point" heading is the plausible-wrong-number failure invariant I3
# exists to prevent.  DD-5 takes option (a): KEEP RENDERING IT, AND NAME THE
# ANALYSIS.  Option (c), refusing `dc`, is forbidden -- it would contradict the
# allow-list and red row G3b of the seam's suite, a cross-language fence over
# save.c's own op/dc strcmps.
#
# ⚠ THE WORDING IS NOT DD-5's QUOTED SPECIMEN, AND save.c IS WHAT MOVED IT.
# The ruling proposes "these numbers come from the `dc` analysis at its first
# point, not from a standalone operating point".  That asserts something FALSE
# for a case save.c creates itself: save.c:1073 and :1120 both carry
#     if(raw->npoints[...] > 1 && !strcmp(sim_type, "op")) sim_type = "dc";
# so a MULTI-POINT `Operating Point` plot is renamed `dc` BY THE READER, and a
# user who ran nothing but an operating point would be told they ran a sweep.
# MEASURED: a three-point `Plotname: Operating Point` raw answers
# `xschem raw sim_type` = dc.  DD-5's DECISION is implemented; only its
# specimen wording is refuted.  The sentence below names what the LOADED
# RESULTS CALL THEMSELVES rather than what the user ran, which is true in both
# cases and asserts nothing stronger.  The exact wording is on the owed ledger
# as a rule debt for the user.
#
# ⚠ THE GATE IS `$sty ne {} && $sty ne "op"`.  The empty half is not
# decoration: a hand-built ctx and a failed `xschem raw sim_type` both produce
# {}, and a sentence that fired on those would be indistinguishable from an
# honest one.  Fired only in state `ok` with a non-empty union -- on the fifth
# silence it would put "these numbers come from..." over a block with no
# numbers.
## `a` or `an`, for a word that came from the simulator (issue 1297).
## ⚠ VOWEL-INITIAL IS THE TEST, NOT A LIST OF KNOWN ANALYSES: the kinds are
## whatever the raw's `Plotname` mapped to, so a list would be wrong for the
## first kind nobody anticipated. It is not perfect English for every possible
## token, and it does not have to be -- it is right for `op`, `ac`, `dc`,
## `tran`, `noise`, `sp` and `sens`, which is every kind this tree produces.
proc rdw::_article {word} {
    if {[regexp -nocase {^[aeiou]} $word]} { return "an" }
    return "a"
}

proc rdw::_analysis_line {ctx} {
    set sty {}
    catch {set sty [dict get $ctx simtype]}
    if {$sty eq {} || $sty eq {op}} { return {} }
    return "These numbers come from the first point of results xschem reports as a $sty analysis, not as a standalone operating point. A $sty sweep's first point is one sweep step, and xschem also reports a multi-point operating point as $sty."
}

# ISSUE 1284.  THE ANSWER DICT IS NOT TRUSTED INPUT.  It is whatever a backend
# hands over, and ruling D-5 records that the user IS BUILDING A CUSTOM NGSPICE
# the seam exists to admit -- so the first backend to hand this window a shape
# it did not expect will be the user's own.  The shipped ngspice backend cannot
# produce any of these (it builds `devices` with `dict set` and gates every
# value through `op_annot::raw_class`'s `string is double -strict`), which is
# exactly why nothing here was ever exercised.
#
# FOUR SHAPES MEASURED, plus two found while planning:
#   * a malformed `devices` value fell into _rowdevs's dict-level catch, the
#     union came back empty, and the window rendered the FIFTH SILENCE -- a
#     statement about the RAW, and FALSE, because the run may have saved
#     plenty and it is the ANSWER that could not be read;
#   * a malformed per-device VALUE RAISED out of this pure renderer, which
#     every suite row and every widget path calls;
#   * a malformed `absent` bucket and a malformed `nonfinite` bucket RAISE the
#     same way (measured while planning B2a, not in the issue).
# So one predicate validates the whole answer BEFORE anything walks it, and a
# flawed answer gets its OWN sentence naming the backend, because the remedy is
# there and not in the run.
#
# Every walk below is `llength`-checked rather than `catch`-wrapped-per-use, so
# the renderer stays PURE: one verdict, taken once, before any rendering.
proc rdw::_wellformed {v} { return [expr {[catch {llength $v}] ? 0 : 1}] }

# ⚠ ISSUE 1284, SECOND PASS: THE FIRST FIX WAS REFUTED, AND THIS IS THE HALF
# THAT WAS WRONG.  B2a's `_answer_flaw` opened
#     if {[catch {dict keys [dict get $ans devices]} devs]} { return 1 }
# so an ABSENT `devices` key was malformed BY CONSTRUCTION, and the call sat
# ELEVEN lines ABOVE the state branch.  A third-party backend's perfectly legal
# minimal refusal `{state no_raw}` therefore rendered a complaint about the
# BACKEND where HEAD rendered "No simulation results are loaded.  Run a
# simulation, or load a raw file, then ask again." -- and MEASURED, all four
# non-`ok` states did it, not just `no_raw`.  That is the exact class ruling
# D-5 exists to admit: the user is building a custom ngspice and it will be the
# first backend to occupy this seam, so a window that greets a correct minimal
# answer with an accusation sends its author hunting a bug that is in here.
#
# THE RULE, AND BOTH HALVES ARE LOAD-BEARING:
#   * A NON-`ok` STATE IS A COMPLETE AND LEGAL ANSWER ON ITS OWN.  `devices`,
#     `absent`, `nonfinite` and `complete` are required only when `state` is
#     `ok`, so the state is read FIRST (rdw::_answer_state, below) and a
#     refusal returns its own sentence with NO shape check of any kind.
#   * AN ABSENT BUCKET IS EMPTY, NOT MALFORMED.  Only a key that is PRESENT
#     and un-walkable is a flaw.  `dict exists` is measured safe on a malformed
#     dict (returns 0, never raises), so the guard cannot itself become the
#     raise it is here to prevent.
# Invariant I3 applied to a SENTENCE rather than to a number: a plausible wrong
# statement on screen is the same failure as a plausible wrong value.
#
# ⚠ ISSUE 1284 SECTION 5, CLOSED BY ITEM B2d.  The second pass above fixed
# the four MEASURED shapes and left two that section 5 filed and nobody closed,
# while 1284's ACCEPT row says "1284 FIXED".  Both are UNDERSPECIFIED entries:
# well-formed lists that do not carry what the seam contracts them to carry.
# Each gets its own NAMED predicate rather than an inline literal, so each new
# guarantee can be neutralised on its own and has a sabotage handle that does
# not have to borrow the whole-predicate one.
#
#   * `rdw::_bucket_width` -- THE TWO BUCKETS ARE NOT THE SAME WIDTH, and the
#     shared `llength $e < 2` gate was the bug.  `absent` is a `{<rawdev>
#     <param>}` PAIR; `nonfinite` is a `{<rawdev> <param> <text>}` TRIPLE (item
#     B1's re-do added the third field).  A two-field nonfinite entry passed the
#     shared gate and then rendered `(did not converge)` -- an assertion the
#     window made on NO evidence, because `rdw::_nonfinite_text` discards its
#     argument and returns the words unconditionally.  Obligation 2 says the
#     words report what the raw actually holds; here the raw was never quoted.
#
#   * `rdw::_named` -- ARITY WAS THE WRONG QUESTION.  A `devices` pair `{{} 1.5}`
#     has arity 2 and rendered `     : 1.5`, a value belonging to no parameter:
#     the "blank row that means nothing" this predicate's own comment gives as
#     the reason it rejects a short bucket entry.  The right question is whether
#     the entry NAMES a parameter, asked of the devices pair's FIRST field and
#     of a bucket entry's SECOND.  It may NOT be asked as arity: F19's
#     value-less `{id}` has arity 1, a perfectly good name, and must keep
#     rendering `(no value reported)`.
#
# Neither is reachable through the shipped ngspice backend -- `ase::op_param_split`
# returns {} for an empty parameter and `ase::op_param_set` always emits a
# nonfinite TRIPLE -- which is ruling D-5's point, not an argument for leaving
# them: the first backend to occupy these shapes will be the user's own custom
# ngspice, and "(did not converge)" about a column nobody reported would send
# its author hunting a convergence problem that does not exist.
proc rdw::_bucket_width {key} { return [expr {$key eq {nonfinite} ? 3 : 2}] }
proc rdw::_named {n} { return [expr {[string trim $n] eq {} ? 0 : 1}] }

proc rdw::_answer_flaw {ans} {
    if {[dict exists $ans devices]} {
        set pairs [dict get $ans devices]
        set devs {}
        if {[catch {dict keys $pairs} devs]} { return 1 }
        foreach d $devs {
            set pv [dict get $pairs $d]
            if {![rdw::_wellformed $pv]} { return 1 }
            foreach e $pv {
                if {![rdw::_wellformed $e]} { return 1 }
                if {[llength $e] < 1} { return 1 }
                ## A pair with no parameter NAME renders a value under nothing.
                ## Arity is deliberately NOT the question here: a value-less
                ## `{id}` is a named column with nothing reported for it, and
                ## `_value_text` has words for that.
                if {![rdw::_named [lindex $e 0]]} { return 1 }
            }
        }
    }
    foreach key {absent nonfinite} {
        if {![dict exists $ans $key]} { continue }
        set b [dict get $ans $key]
        if {![rdw::_wellformed $b]} { return 1 }
        foreach e $b {
            if {![rdw::_wellformed $e]} { return 1 }
            ## A short entry would render a device sub-header with an empty
            ## parameter name, which is a blank row that means nothing -- and a
            ## short NONFINITE entry would additionally make the window assert
            ## non-convergence with nothing quoted from the raw.
            if {[llength $e] < [rdw::_bucket_width $key]} { return 1 }
            if {![rdw::_named [lindex $e 1]]} { return 1 }
        }
    }
    return 0
}

# THE STATE, READ ONCE AND READ FIRST.  Answers {hasstate state}.  An answer
# with no readable `state` -- including one that is not a dict at all -- is
# ITSELF malformed and gets the sentence naming the backend, because the remedy
# is there.  HEAD instead defaulted to `set state unknown`, inventing a state
# name the backend never sent and then rendering a sentence that blames this
# window for the backend's omission.  A state that IS present but unrecognised
# is a different fact and keeps its own sentence, naming that state.
proc rdw::_answer_state {ans} {
    set st {}
    if {[catch {dict get $ans state} st]} { return [list 0 {}] }
    return [list 1 $st]
}

proc rdw::_flaw_line {sim} {
    if {$sim eq {}} { set sim simulator }
    return "The $sim operating-point reader answered in a shape this window could not read, so nothing is shown for this device. This is a fault in that reader's answer, not a statement about the run."
}

# ONE PAIR IS ONE LINE, AND DATA MAY NOT BREAK THAT.  A newline inside a value
# made one pair render as TWO lines, the second unindented and carrying NO TAG,
# which breaks the one-pair-one-line model `block_text` and `render_pane`
# share -- the paste shape and the pane would then disagree about how many
# lines a block has.  A device name and a parameter name do it too.  Collapsed
# here rather than stripped, so nothing silently joins two words.
proc rdw::_oneline {s} { return [string map [list "\n" { } "\r" { } "\t" { }] $s] }

# ⚠ ONE BLOCK ENTRY IS ONE LINE, AND THE GUARANTEE LIVES AT THE EMIT POINT.
# `_oneline` above covered the three DATA fragments (parameter name, value,
# device name) and nothing else, so the guarantee held for four of the seam's
# five keys and failed on the fifth: `_state_sentence`'s default arm echoes
# the backend's own `state` verbatim, so an answer as small as
#     {devices {} absent {} nonfinite {} complete 0 state "weird\n    id  : 1.11e-05"}
# rendered 4 block entries as 5 lines of text, the extra one a correctly
# indented, correctly formatted operating-point row that NO BUCKET EVER
# CARRIED.  Measured on the fixed tree before this proc existed; the same
# escape existed in `_flaw_line`'s backend name, in `_sim_refusal`, in the
# `dim` device-path line, and in dump_devpath's "could not answer: $ans",
# which interpolates a caught Tcl error and so is multi-line by nature.
# Wrapping each fragment separately would have been nine edits and a tenth
# site the next author forgets, so EVERY line this file appends to a block
# goes through here instead: the paste shape, the pane and the block's own
# entry count can then never disagree, whatever a backend sends.  That is
# invariant I3 read as "a plausible wrong LINE is as bad as a plausible wrong
# number" -- an injected row is indistinguishable from a measured one once it
# is on the clipboard.  The pair rows still one-line their name and value
# BEFORE this point, because the column width is computed from the name and a
# newline would inflate it.
proc rdw::_line {tag text} { return [list $tag [rdw::_oneline $text]] }

# INVARIANT I3, AND THE BLANK'S ONE MEANING.  A `devices` pair carrying no
# value at all, or an empty string, used to render BYTE-IDENTICALLY to an
# ABSENT column -- so the one honest distinction this renderer makes was lost,
# and the per-block blank footnote ("the raw names that column but the
# simulator did not compute it") was then FALSE about them.  Words, in the same
# family as `(did not converge)`, keep the blank glyph meaning exactly one
# thing, and leave the footnote's "rides exactly once" golden where it is.
#
# ISSUE 1341 / RULING DD-7 -- ENGINEERING NOTATION, THROUGH THE SHEET'S OWN
# PROC.  The user asked for "engineering notation - just like annotation on
# the schematic", and "just like" is not "looks similar": `eng_or_blank`
# (src/op_annot.tcl:1266) is the proc `op_annot::text` (:2125) puts on the
# sheet, so calling THAT ONE here is what makes the two surfaces unable to
# disagree about a value nobody wrote a golden for.  It also carries the
# user's own `ev_precision`, which to_eng reads at call time (xschem.tcl:1902)
# and a second %.4g ladder living in this file would not: at the shipped 4 the
# two are numerically identical, and they part company the first time the user
# sets it to 6 -- which is exactly the disagreement this item exists to stop.
#
# ⚠ IT IS A WRAPPER, NOT A SUBSTITUTION.  DD-7 rejects the one-liner
# `set v [::op_annot::eng_or_blank $v]` at the call site, because that proc
# returns EMPTY for everything that is not a finite double and this window's
# values frequently are not one.  Four arms, and three of them are the reason:
#
#   BLANK      stays first and stays words (issue 1284, above).
#   A NUMBER   is engineered by the sheet's proc.
#   NOT A
#   NUMBER     passes through VERBATIM.  A model name, a `-` placeholder for a
#              column the PDK declines to compute, a geometry already written
#              `1.5u`, a swept pair `1.5 2.5`: the one-liner blanks every one
#              of them, and a blanked value here does not read as "not a
#              number", it reads as the ABSENT column's blank -- whose footnote
#              then says something FALSE about it.
#   A NON-
#   FINITE
#   NUMBER     gets `_nonfinite_text`, the words the nonfinite BUCKET already
#              gets.  eng_or_blank blanks `nan`, and an empty string where
#              `nan` used to print is issue 1272's defect wearing engineering
#              notation -- a silent loss of the one thing the user needed
#              told.  Invariant I3 forbids painting the raw `nan` too, so the
#              old pass-through was not the answer either.
#
# ⚠ THE `string is double -strict` GATE IS WHAT SPLITS THE LAST TWO, and it is
# also a SECOND lock on the safety gate eng_or_blank already carries: to_eng is
# `uplevel #0 expr [join $args]`, so a value that reached it unguarded would
# EVALUATE at global scope -- and these values arrive from a raw file.  A
# `devices` pair holding `[set ::whatever 1]` is not a double, so it never gets
# near it.  This file therefore names eng_or_blank and never names to_eng; the
# suite's row EN2 fences both halves by counting them in this file.
#
# ⚠ `1e400` IS THE INPUT THAT MADE THE NON-FINITE ARM WORTH ITS OWN BRANCH.
# MEASURED on this binary: it passes `string is double -strict`, and `to_eng`
# answers the string `infT` -- which reads like a measurement and would paste
# into a design review as one.  eng_or_blank's `_finite` catches it (the
# `$v*0.0 == 0.0` raise, op_annot.tcl:1179) and answers {}, which is how a
# blank reaches the last arm below.
#
# ⚠ AND THE {} FROM A MISSING FORMATTER IS NOT THE {} FROM A NON-FINITE VALUE.
# `catch` leaves the NOFMT sentinel in place only when the call RAISED -- an
# op_annot that never loaded -- and that arm falls back to the raw text, which
# is unformatted but true.  Answering `(did not converge)` there would invent a
# non-convergence for a number the simulator computed perfectly well, which is
# the plausible-wrong-number failure invariant I3 exists to prevent.  The cost
# is that in THAT arm a `nan` prints raw again, exactly as it did before this
# item; telling it apart without the sheet's proc would mean a second spelling
# of "is this finite" in this file, which is the drift the item exists to
# remove.  Unreachable as shipped -- xschem.tcl:16780 sources op_annot.tcl
# before :16821 sources this file -- and MEASURED by renaming eng_or_blank
# away: 1.11e-05 -> `1.11e-05`, nan -> `nan`, and both come straight back when
# it is renamed home.
proc rdw::_value_text {v} {
    if {[string trim $v] eq {}} { return {(no value reported)} }
    if {![string is double -strict $v]} { return [rdw::_oneline $v] }
    set e {NOFMT}
    catch {set e [::op_annot::eng_or_blank $v]}
    if {$e eq {NOFMT}} { return [rdw::_oneline $v] }
    if {$e ne {}} { return [rdw::_oneline $e] }
    return [rdw::_nonfinite_text $v]
}

# OBLIGATION 3.  The four non-`ok` states otherwise all arrive as the same
# empty list, and `ok` with an empty union is a FIFTH silence -- the common
# one under measured rule R1 (gm/gds/vth exist only if the deck saved them;
# `save all` does not include them), and neither an error nor a bug.
proc rdw::_state_sentence {state ctx} {
    set inst {}
    catch {set inst [dict get $ctx instname]}
    set dp {}
    catch {set dp [dict get $ctx devpath]}
    set sty {}
    catch {set sty [dict get $ctx simtype]}
    switch -exact -- $state {
        no_raw {
            return {No simulation results are loaded. Run a simulation, or load a raw file, then ask again.}
        }
        not_annotated {
            return {Operating-point results are loaded but nothing has been published from them yet. Annotate them first (Waves > Op Annotate, or key 6), then ask again.}
        }
        not_op {
            ## ⚠ `[rdw::_article]`, NOT A BARE `a` -- ISSUE 1297. The analysis
            ## kind comes from the simulator, so the sentence read "a op
            ## analysis" for the one kind this window exists to talk about.
            return "The loaded results are [rdw::_article $sty] $sty analysis, not an operating point. Nothing was read from them: load the operating-point results and ask again. (An OP+TRAN run writes both to one file, and reading the transient makes it the current one.)"
        }
        no_devpath {
            return "$inst has no operating-point descriptor, so there is no device path to ask about. A PDK registers one with op_annot::register."
        }
        ok {
            return "This run's raw holds no operating-point columns for $dp. Only parameters the deck explicitly saved appear here."
        }
    }
    return "The operating-point reader answered with a state this window does not know: '$state'."
}

# THE BLOCK.  `ans` is the seam's five-key answer; `ctx` is
# {header devpath simtype instname}.  Returns an ordered list of {tag line}
# pairs -- ONE model, rendered to the pane by rdw::render_pane and to the
# paste shape by rdw::block_text, so the two can never drift.
#
#   line 1  M2B:/xdut/xbg/xamp1        tag hdr   (Q6's default, as asked)
#   line 2  the raw's own device path  tag dim   (what a user pastes into
#                                                 ngspice; omitted when empty)
#   line 3  the incompleteness sentence, or the ONE state sentence
#   then    per primitive of the union, "  <rawdev>", suppressed only when
#           there is exactly one primitive whose name equals line 2
#   then    "    %-*s : %s", the width being the longest param name in the
#           block capped at 24, right-trimmed so a blank leaves no trailing
#           space.  devices pairs first, then nonfinite, then absent.
#   then    the blank-value footnote, only when `absent` is non-empty
#   then    ONE empty separator line.
#
# ⚠ DATA NEVER BECOMES A FORMAT SPEC.  The format string is a literal and
# every value is an argument, nothing is `subst`ed or `eval`ed, so a `%` or a
# `[` in a device path or a parameter name passes through verbatim.
proc rdw::format_answer {ans ctx} {
    set hdr {}
    catch {set hdr [dict get $ctx header]}
    set dp {}
    catch {set dp [dict get $ctx devpath]}
    ## ISSUE 1284, SECOND PASS.  THE STATE COMES FIRST, AND THE ORDER IS HALF
    ## THE FIX -- B2a's version consulted `_answer_flaw` ELEVEN LINES ABOVE
    ## this branch, so a legal `{state no_raw}` was accused of being malformed.
    ## Three arms, in this order and no other:
    ##   (a) NO READABLE STATE, including an `ans` that is not a dict at all,
    ##       is itself a malformed answer -> the sentence naming the backend.
    ##   (b) A NON-`ok` STATE is a complete and legal answer on its own -> its
    ##       own sentence, with NO shape check, because a refusal makes no
    ##       claim about data and nothing may walk what it did not claim.
    ##   (c) ONLY UNDER `ok` is the shape consulted, and there only for a
    ##       bucket that is PRESENT.
    lassign [rdw::_answer_state $ans] hasstate state
    if {!$hasstate} {
        set who {}
        catch {set who [dict get $ctx sim]}
        return [rdw::_refusal $ctx [rdw::_flaw_line $who]]
    }
    if {$state ne {ok}} {
        return [rdw::_refusal $ctx [rdw::_state_sentence $state $ctx]]
    }

    ## A malformed answer that DOES claim `ok` must not reach any walk below,
    ## and must not fall into the fifth silence -- which is a statement about
    ## the RAW and would be false.  The sentence names the backend because the
    ## remedy is there.
    if {[rdw::_answer_flaw $ans]} {
        set who {}
        catch {set who [dict get $ctx sim]}
        return [rdw::_refusal $ctx [rdw::_flaw_line $who]]
    }

    set out {}
    lappend out [rdw::_line hdr $hdr]
    if {$dp ne {}} { lappend out [rdw::_line dim $dp] }

    set devs [rdw::_rowdevs $ans]
    if {[llength $devs] == 0} {
        lappend out [rdw::_line note [rdw::_state_sentence $state $ctx]]
        lappend out [list {} {}]
        return $out
    }

    ## RULING DD-5.  Between the device path and the incompleteness line, so a
    ## reader learns WHAT the numbers are before being told the list of them is
    ## partial.
    set an [rdw::_analysis_line $ctx]
    if {$an ne {}} { lappend out [rdw::_line note $an] }

    set inc [rdw::_incomplete_line $ans]
    if {$inc ne {}} { lappend out [rdw::_line note $inc] }

    set pairs [dict create]
    catch {set pairs [dict get $ans devices]}
    set abs {}
    catch {set abs [dict get $ans absent]}
    set nf {}
    catch {set nf [dict get $ans nonfinite]}

    set rows {}
    set w 0
    foreach d $devs {
        set r {}
        if {[dict exists $pairs $d]} {
            ## ⚠ THE PARAMETER NAME AND THE VALUE ARE BOTH ONE-LINED, AND A
            ## VALUE-LESS OR EMPTY PAIR BECOMES WORDS (issue 1284).  An absent
            ## column's blank is built below and is deliberately NOT passed
            ## through _value_text: the blank has exactly one meaning and the
            ## per-block footnote is what says it.
            foreach pv [dict get $pairs $d] {
                lappend r [list [rdw::_oneline [lindex $pv 0]] \
                                [rdw::_value_text [lindex $pv 1]]]
            }
        }
        foreach e $nf {
            if {[lindex $e 0] eq $d} {
                lappend r [list [rdw::_oneline [lindex $e 1]] \
                                [rdw::_nonfinite_text [lindex $e 2]]]
            }
        }
        foreach e $abs {
            if {[lindex $e 0] eq $d} {
                lappend r [list [rdw::_oneline [lindex $e 1]] {}]
            }
        }
        foreach pv $r {
            set l [string length [lindex $pv 0]]
            if {$l > $w} { set w $l }
        }
        lappend rows [list $d $r]
    }
    if {$w > 24} { set w 24 }

    # RULING D-3.  One XR1 resolves to several primitives and two of them can
    # both publish a parameter spelled `i`; without the per-primitive
    # sub-header the two numbers cannot be told apart, which is exactly why
    # the seam's return shape was amended from a flat {param value} list.
    # Suppressed on the ordinary single-primitive case, where it would just
    # repeat line 2.
    set showdev 1
    if {[llength $devs] == 1 && [lindex $devs 0] eq $dp} { set showdev 0 }

    foreach dr $rows {
        if {$showdev} { lappend out [rdw::_line dev "  [lindex $dr 0]"] }
        foreach pv [lindex $dr 1] {
            lappend out [rdw::_line {} [string trimright \
                [format {    %-*s : %s} $w [lindex $pv 0] [lindex $pv 1]]]]
        }
    }
    if {[llength $abs] > 0} { lappend out [rdw::_line note [rdw::_absent_line]] }
    lappend out [list {} {}]
    return $out
}

# The paste shape: the block's lines, tags dropped.  The trailing separator
# makes the text end in a newline, so two dumps pasted one after the other are
# separated in the document too.
proc rdw::block_text {block} {
    set out {}
    foreach e $block { lappend out [lindex $e 1] }
    return [join $out "\n"]
}

# Spec 4.2 B7's table, AS DATA rather than as a switch buried in a widget
# callback, so the greying can be asserted with no Tk.
#
#   button        annotation (1)   summary (2)   all (3)
#   Up / Down     reorder          reorder       reorder
#   Delete        remove           remove        GREYED   (list 3 is live from
#                                                          the run and has no
#                                                          persisted state)
#   Add           --               add           add (the dialog asks which)
#   Save          write            write         write
#
# The spec's Add cell for list 1 is an em dash, which does not say greyed
# versus absent.  DECISION (ladder L2, rule debt 1245_B3_add_greyed_on_list1):
# GREYED.  The column then keeps a constant shape as the user switches lists;
# an absent button moves the other four under the pointer.
proc rdw::button_state {id kind} {
    if {$id eq {add} && $kind eq {annotation}} { return disabled }
    if {$id eq {delete} && $kind eq {all}} { return disabled }
    return normal
}

# THE COLUMN'S ids AND LABELS, ONCE (invariant I1).  `rdw::build` packs them
# and `rdw::_button_label` reads them back to name the button in the status
# line; two literal lists would drift the moment a label is reworded, and the
# status line's whole obligation is that a message NAMES THE BUTTON IT CAME
# FROM.
proc rdw::_buttons {} { return {up Up down Down delete Delete add Add save Save} }

proc rdw::_button_label {id} {
    foreach {i l} [rdw::_buttons] { if {$i eq $id} { return $l } }
    return {}
}

# ---------------------------------------------------------------------------
# TWO ONE-LINE ACCESSORS THAT NAME A CHOICE THE WHOLE WINDOW RESTS ON.
# They exist so the choice has ONE place, and so a reviewer can flip either
# and watch the suite say which promise broke.

# The pane is READ-ONLY.  Nobody may type into a record of a simulation.
proc rdw::_pane_state {} { return disabled }

# The pane owns the X PRIMARY selection.  This is the user's stated reason the
# window exists at all: select, Ctrl-C, paste into a design-review document.
proc rdw::_exportsel {} { return 1 }

# NEWEST DUMP ON TOP.  One accessor names the end of the pane a new dump lands
# at, and both the store (rdw::push) and the view (rdw::render_pane) honour
# it, so they cannot disagree about which end is new.
proc rdw::_insert_index {} { return 1.0 }

# ---------------------------------------------------------------------------
# THE CONTEXT LAYER.  Reads xschem and op_annot; still no Tk.

# {cadence-line devpath-line}.
#
# ⚠ INVARIANT I1, ONE NAME BUILDER.  Line 2 is op_annot::devpath's OWN string,
# byte for byte, including the empty string for an instance no descriptor
# claims.  This file builds no raw device name of its own, ever: a hand-built
# path spelled without the leading `@` makes the seam answer
# `devices {} state ok`, byte-identical to "unknown device", which is the
# wrong-answer-wearing-a-healthy-state that returned item B1 [F].
proc rdw::header {instname} {
    set p {}
    catch {set p [xschem get sch_path]}
    set dp {}
    catch {set dp [::op_annot::devpath $instname]}
    return [list "$instname:[rdw::_cadence_path $p]" $dp]
}

# Which backend answers.  An explicit ::rdw::sim override wins (the suite and
# items B4/B5 drive it); else the single registered backend when there is
# exactly one; else ngspice if it is registered; else nothing.
#
# ⚠ THE SEAM IS NEVER CALLED BY ITS PROC NAME.  Naming the ngspice proc
# directly is behaviourally identical TODAY, which is precisely why it would
# be a defect: the whole point of the seam is that nothing above it changes
# when the user's wildcard ngspice arrives (ruling D-5).
proc rdw::sim {} {
    variable sim
    if {[info exists sim] && $sim ne {}} { return $sim }
    set names {}
    catch {set names [::ase::backend_names]}
    if {[llength $names] == 1} { return [lindex $names 0] }
    if {[lsearch -exact $names ngspice] >= 0} { return ngspice }
    return {}
}

# A refusal that is still a block: the header the user asked about, and one
# sentence saying why there is no answer.  A caught refusal, never a raise --
# this is reached from a menu item and, later, from a key.
proc rdw::_refusal {ctx text} {
    set hdr {}
    catch {set hdr [dict get $ctx header]}
    set dp {}
    catch {set dp [dict get $ctx devpath]}
    set out {}
    lappend out [rdw::_line hdr $hdr]
    if {$dp ne {}} { lappend out [rdw::_line dim $dp] }
    lappend out [rdw::_line note $text]
    lappend out [list {} {}]
    return $out
}

# THE SEAM'S ONLY DOOR.  Resolve the hook, call it, format the answer, push
# the block.  Returns the block.
# ISSUE 1282 part 2.  "No such simulator" and "a simulator that registered
# without an operating-point reader" are DIFFERENT FACTS WITH DIFFERENT
# REMEDIES -- check the name, versus add a hook -- and this feature's whole
# obligation 3 is that different silences get different sentences.  One
# `catch {ase::backend_hook $s op_param_set}` arm produced ONE sentence for
# both.  ase::backend_hook already mints two distinct errors (ase.tcl:550
# "unknown simulator" and :553 "unknown hook"), so no new information is
# needed, only a caller that asks which case it is -- and asking membership
# BEFORE the call keeps one source of truth rather than parsing an error
# string.  `op_param_set` is deliberately NOT on register_backend's required
# list (ase.tcl:534), so "registered, no reader" is genuinely reachable.
# ⚠ Item B5 is the first thing that sets ::rdw::sim, so the split has to exist
# before B5, not after.
proc rdw::_sim_refusal {s} {
    set names {}
    catch {set names [::ase::backend_names]}
    if {[lsearch -exact $names $s] < 0} {
        return "No simulator named $s is registered, so there is nothing to ask for this device. Check the name, or register a backend for it with ase::register_backend."
    }
    return "Simulator $s is registered but declares no operating-point reader - the op_param_set hook - so this window has nothing to show for it. A backend adds that hook to publish operating-point columns."
}

proc rdw::dump_devpath {devpath ctx} {
    set s [rdw::sim]
    ## The renderer's malformed-answer sentence names the backend, so the
    ## backend has to be in the context it is handed (issue 1284).
    catch {dict set ctx sim $s}
    ## ⚠ AND SO DOES THE ANALYSIS KIND -- ISSUE 1298. This proc is THE SEAM'S
    ## ONLY DOOR, and items B4 and B5 call it with contexts they build
    ## themselves. Ruling DD-5's "name the analysis" sentence was a property of
    ## rdw::dump alone, so any other caller silently got a DC sweep rendered as
    ## an operating point -- the defect issue 1282 was filed and fixed for,
    ## coming straight back through the door the fix did not cover.
    ## A ctx that already carries an explicit `simtype` still wins, so the
    ## suite's hand-built contexts are unaffected, and `{}` stays meaningful:
    ## a failed read and a hand-built ctx both produce it, and _analysis_line
    ## deliberately says nothing for `{}` rather than guess.
    if {![dict exists $ctx simtype]} {
        catch {dict set ctx simtype [xschem raw sim_type]}
    }
    if {$s eq {}} {
        set blk [rdw::_refusal $ctx \
            {No simulator backend is registered, so there is nothing to ask for this device.}]
    } elseif {[catch {::ase::backend_hook $s op_param_set} hook]} {
        set blk [rdw::_refusal $ctx [rdw::_sim_refusal $s]]
    } elseif {[catch {uplevel #0 [list $hook $devpath]} ans]} {
        set blk [rdw::_refusal $ctx \
            "The operating-point reader for $s could not answer: $ans"]
    } else {
        set blk [rdw::format_answer $ans $ctx]
    }
    ## ⚠ THE VALUE HANDED BACK IS THE VALUE STORED (issue 1322).  `push`
    ## now stamps the block with what it was about, so returning `$blk` would
    ## hand the caller an UNSTAMPED copy of a block the store holds stamped --
    ## two values for one dump, and the caller's is the one that cannot say
    ## which device it came from.
    return [rdw::push $blk]
}

# The whole round trip for one instance name: the header, the ONE name
# builder's device path, the current analysis kind, then the seam.  Item B4
# calls this from its keys.
proc rdw::dump {instname} {
    set h [rdw::header $instname]
    set sty {}
    catch {set sty [xschem raw sim_type]}
    set ctx [dict create header [lindex $h 0] devpath [lindex $h 1] \
                         simtype $sty instname $instname]
    return [rdw::dump_devpath [lindex $h 1] $ctx]
}

# ---------------------------------------------------------------------------
# WHAT A BLOCK WAS ABOUT (issue 1322).
#
# ⚠ A BLOCK USED TO BE A RENDERING WITH NO IDENTITY, AND THAT IS THE DEFECT
# THAT REVERTED ITEM B5-2.  `rdw::header` joins an instance name to a cadence
# path, and `rdw::push` stored the rendered lines and nothing else -- so the
# only surviving trace of WHICH DEVICE a block was about was the header
# STRING, whose NAME half a later button re-resolved against WHATEVER SHEET IS
# OPEN.  Nothing in this tree clears the store on a schematic load, and nothing
# should: reviewing two sheets' dumps side by side is what this window is for.
#
# MEASURED at HEAD with two TOP-LEVEL sheets each holding an `M1` -- the
# default `template="name=M1 ..."` of every device symbol in this tree, which
# makes this the ORDINARY case and not a contrivance:
#     the block on screen was about   ncls / vn.sym
#     the re-resolved subject said    type vpdev class pcls cellname vp.sym
#     Delete's verdict                ok
#     ncls kept its row; pcls lost one -- a device nobody was looking at.
#
# ⚠ AND THE OBVIOUS GUARD IS ALREADY REFUTED BY THAT SAME MEASUREMENT.
# Comparing the header's PATH half catches nothing: `xschem get sch_path` is
# `.` on both sheets, `rdw::_cadence_path` renders `/` for both, and the two
# headers are BYTE-IDENTICAL.  THE AXIS IS SHEET IDENTITY, NOT HIERARCHY PATH,
# and `xschem get schname` is the accessor that separates them.
#
# So the subject is captured AT DUMP TIME, while the sheet it came from is
# still the sheet on screen, and it rides inside the block's OWN HEADER ENTRY
# as a THIRD element.  The block therefore stays ONE FLAT LIST OF ENTRIES:
# `llength $b` is still the block's LINE COUNT, `rdw::block_text` reads
# `lindex $e 1` and is byte-identical, and `rdw::render_pane` paints exactly
# the same number of lines.
#
# ⚠ WHY NOT A PARALLEL SUBJECT LIST.  It would be two structures to keep
# aligned across THREE writers, not two -- `rdw::push`, `rdw::keep_latest`,
# and the suites, which assign the store directly -- and a desynced parallel
# list answers about the wrong block while every existing row stays green.
# That is invariant I1's failure shape, and this batch's own recurring one.
#
# ⚠ AND WHY NOT A NEW BLOCK ENTRY.  An extra entry changes `llength $b`, which
# the pane's line arithmetic uses as a LINE COUNT, and `rdw::block_text` would
# put it straight into the user's paste.
#
# ⚠ THE CLASS IS DELIBERATELY NOT CAPTURED.  `op_param_lists::class` is a pure
# classmap lookup with no sheet dependence, so it already has exactly one home
# (invariant I1); only the `type=` token is sheet-dependent.  A consumer
# derives the class from the captured type.
#
# Suite: tests/headless/test_rdw_window_1245.tcl section BS (both arms) and
# tests/headless/test_rdw_keys_1245.tcl row KS1, which drives the capture
# through the real keybinding rather than through a hand-called push.

# The exact inverse of rdw::header's join.  An instance name may itself carry
# a colon, so the split is on the LAST colon that is followed by the path half
# -- which `rdw::_cadence_path` guarantees always begins with `/`, at the top
# sheet included (`M1:/`).  A line that is not a header at all answers {}.
proc rdw::_hdr_instname {line} {
    if {[regexp {^(.*):(/.*)$} $line -> nm path]} { return $nm }
    return {}
}

# May this `type=` token be recorded as a subject at all?
#
# ⚠ `missing` IS NOT A TYPE.  It is xschem's own placeholder for a symbol the
# editor could not find (systemlib/missing.sym, save.c:7281) -- the same token
# `descend_missing_sym` (actions.c:6049-6063) guards by name.  It matters here
# because `op_param_lists::class` returns the TOKEN for a type nobody mapped,
# BY CONTRACT, so a consumer's "class is empty" guard would wave the
# placeholder straight through and the user would read a sentence naming a
# class no PDK ever declared.  Recording nothing is the honest answer, and
# blank is available HERE and is not available later.
#
# STATED COST: a user-authored symbol that really exists on disk and really
# declares `type=missing` gets no captured subject either.  actions.c's own
# comment records that this is a different fact wearing the same token, and no
# shipped symbol in this tree carries it.
proc rdw::_subject_resolved {type} {
    if {$type eq {}} { return 0 }
    if {$type eq {missing}} { return 0 }
    return 1
}

# Does this block already carry a subject?  One that does is never
# re-captured: it is the record of a dump that already happened, and reading
# the live editor for it again is the very defect the stamp exists to remove.
proc rdw::_stamped {block} {
    set e {}
    if {[catch {lindex $block 0} e]} { return 0 }
    set n 0
    if {[catch {llength $e} n]} { return 0 }
    return [expr {$n >= 3 ? 1 : 0}]
}

# {instname type cellname schname} read RIGHT NOW -- from the block's own
# header text and the sheet that is still open -- or {} when nothing can be
# trusted.  Every read is caught: a dump must never fail because an instance
# went away between the seam's answer and the push.
proc rdw::_capture_subject {block} {
    set line {}
    catch {set line [lindex [lindex $block 0] 1]}
    set inst [rdw::_hdr_instname $line]
    if {$inst eq {}} { return {} }
    set type {}
    catch {set type [::op_annot::type $inst]}
    if {![rdw::_subject_resolved $type]} { return {} }
    set cell {}
    catch {set cell [xschem getprop instance $inst cell::name]}
    set sch {}
    catch {set sch [xschem get schname]}
    return [dict create instname $inst type $type cellname $cell schname $sch]
}

# THE ONE READER OF WHERE THE STAMP LIVES, AND A PURE FUNCTION OF ITS
# ARGUMENT.  It reads no namespace state whatever, so a caller that assigns the
# store directly -- three suites do -- cannot desync it, and a block passed
# around by value carries its own answer with it.  {} when the block carries
# no subject, which is the honest answer for every block whose device could
# not be resolved at dump time.
proc rdw::block_subject {block} {
    set e {}
    if {[catch {lindex $block 0} e]} { return {} }
    if {[catch {llength $e} n]} { return {} }
    if {$n < 3} { return {} }
    return [lindex $e 2]
}

# ---------------------------------------------------------------------------
# BRING THE WINDOW TO THE FRONT WHEN SOMETHING IS SENT TO IT (issue 1340).
#
# The user's words: "When user sends info to the Results Display Window (RDW),
# the RDW needs to be raised (no need to focus, just raise), just as the
# Library Manager is raised when one does Ctrl-Alt-S."
#
# ⚠ IT IS THE LIBRARY MANAGER'S OWN RAISE, REUSED AND NOT RE-DERIVED.  A plain
# `raise` is an INERT NO-OP on the window manager the user reported from --
# that WM applies stacking only at map time -- so `raise_toplevel`
# (xschem.tcl) re-MAPs instead, and carries issue 0843's deferred
# `_remap_verify` for the case that WM drops the re-map and loses the window
# outright.  Re-deriving either would re-ship a known defect.  Ruling DD-6
# also says which half of that helper is NOT wanted here: its sibling's last
# line asks the window manager to make this window ACTIVE, and the user said
# no need to focus, so this calls the split-off half.
#
# ⚠ AND THE RE-MAP TAKES THE KEYBOARD IF NOTHING CATCHES IT.  Measured on :99
# under openbox, keyboard parked on the canvas first, nothing else changed:
#     plain raise            no re-map          keyboard stays on .drw
#     withdraw + deiconify   really re-mapped   KEYBOARD MOVES TO .rdw
# and it stays there through every later event pump, because a window manager
# grants focus to a newly MAPPED toplevel.  That is the one thing the user
# forbade in the same sentence as the request, and it is worse here than
# elsewhere: the grammar that fills this window -- bare 1/2/3/4 and the
# command mode's Escape -- lives on the design CANVAS, so a stolen focus
# leaves a mode the user cannot leave.
#     rdw::_arm_focus_handback is the one-shot that already catches exactly
# that grant, and it declines to arm for an ALREADY-MAPPED window -- correctly,
# until now: no map was coming, and a flag left lying around is a bounce
# waiting to happen (issue 1306).  A dump now re-maps a mapped window, so a
# map IS coming, and the arm is told so.  That is a second caller of the
# EXISTING hand-back, not a second focus path; rdw::show's synchronous
# `_focus_canvas` is not enough on its own because the grant arrives later.
#
# ⚠ IT CONSTRUCTS NOTHING.  `rdw::open` is this window's one constructor (row
# N1 of the window suite) and the dumps deliberately survive a close, so a
# push into a closed window stays a store push and raises nothing.  Calling
# rdw::open from here is the cheap implementation and would conjure a window
# the user closed on the next dump; rows RA4 and RH1 are the fence.
#
# The raise is caught: by the time it runs the block is already stored and
# already on screen, and a window manager that refuses a re-map is not a
# reason to fail the dump the user asked for.  Rows RA1-RA4 are what say the
# raise really happens, so the catch cannot hide a regression from the suite.
proc rdw::_raise {} {
    if {![rdw::have_tk]} { return 0 }
    if {![winfo exists .rdw]} { return 0 }
    rdw::_arm_focus_handback 1
    catch {raise_toplevel .rdw}
    return 1
}

# Add a block to the store and repaint.  The store is namespace state and
# works headless; the pane is only its projection.
#
# ⚠ IT STAMPS THE SUBJECT (issue 1322), AND ITS SIGNATURE DOES NOT MOVE.
# The capture is here rather than in a new argument for two reasons: every
# fixture in three suites already pushes while the sheet the block came from is
# the sheet that is open, so they all capture the right subject with no edit at
# all; and an optional argument a caller forgets silently restores the defect.
# A block that already carries a subject is stored exactly as it is.
proc rdw::push {block} {
    variable blocks
    if {![rdw::_stamped $block]} {
        set subj [rdw::_capture_subject $block]
        if {$subj ne {}} {
            set e [lindex $block 0]
            set block [lreplace $block 0 0 \
                [list [lindex $e 0] [lindex $e 1] $subj]]
        }
    }
    if {[rdw::_insert_index] eq {1.0}} {
        set blocks [linsert $blocks 0 $block]
    } else {
        lappend blocks $block
    }
    # ⚠ AND IT CLEARS THE CURSOR -- RULING DD-1 (item R1, issue 1337).  This
    # proc PREPENDS, so the line the user clicked now holds a different
    # block's text.  A cursor that stayed at the same line number would point
    # at data the user never chose and the button column would edit it without
    # a word; a cursor that tracked the row to its new number would be a
    # cursor the user did not put there either, one screenful further down.
    # Clearing costs one click after a new dump and is the only reading that
    # cannot act on the wrong device.  Row CU5 (headless) and row CU13 (on
    # screen) are the fence.
    rdw::set_row 0
    rdw::render_pane
    ## ⚠ AND IT RAISES THE WINDOW -- ISSUE 1340, RULING DD-6.  This proc is the
    ## SINGLE DOOR every dump goes through -- keys 1/2/3 and every pick-mode
    ## click reach it through rdw::dump_devpath -- which is why the raise is
    ## here and not in the key handlers: a raise wired into rdw::show alone
    ## would do nothing for a dump that arrived by any other route.  AFTER the
    ## repaint, so what comes to the front is the block that was just sent and
    ## never the previous one.
    rdw::_raise
    return $block
}

# The window's own status line.  The variable is always settable, so the inert
# buttons are drivable under --nogui too; the entry is wired to it by
# -textvariable, so there is nothing to update by hand.  An empty message
# clears the field.
# ⚠ AND IT ONE-LINES, ITEM B5.  `::rdw::statusmsg` is an `entry
# -textvariable` and item B5 is the first thing that puts the LIST STORE's own
# prose in it: `op_param_lists::said`'s reports interpolate caught errors
# (write_conf's `$err`), which are multi-line by nature.  A newline in an entry
# is not wrapped, it is swallowed -- the user reads the first line and never
# learns the rest.  rdw::_line has carried the same rule for every BLOCK line
# since B3; this was the one emit point outside it.  Collapsed at the emit
# point, not at the ten call sites, for _line's own reason: the eleventh call
# site is the one the next author forgets.
proc rdw::status {msg} {
    variable statusmsg
    set statusmsg [rdw::_oneline $msg]
    return {}
}

# ---------------------------------------------------------------------------
# THE Tk LAYER.  Every command below sits behind rdw::have_tk.

# Colours, resolved on EVERY call and never cached (the calculator's own rule,
# calculator.tcl:368-405): a cached palette can be wrong for the whole life of
# the process with no way to re-resolve.  The one source that is not
# ase::palette is `disabledForeground`, the tree-wide convention for greyed
# text, which is what the dimmer second header line uses.
#
# ⚠ ase::palette, never the other one: the sibling proc creates named fonts
# and does a global `option add`, a one-way side effect a suite exists to
# police.  A role that does not resolve falls back rather than raising -- a
# missing option-database entry must not be able to kill the window.
proc rdw::color_sources {} {
    return {
        panel      {ase::palette panel}
        field      {ase::palette table}
        fieldfg    {ase::palette fieldfg}
        selectbg   {ase::palette selectbg}
        selectfg   {ase::palette selectfg}
        accent     {ase::palette accent}
        disabledfg {option get . disabledForeground DisabledForeground}
        notefg     {rdw::_notefg}
        cursor     {rdw::_cursor_shade}
    }
}

# The CIW's own convention for "a result the user must NOTICE without it being
# an error" (ciw.tcl:453).  The incompleteness sentence and the five silences
# are exactly that: not errors, and not to be skimmed past.
proc rdw::_notefg {} { return {dark orange} }

# ---------------------------------------------------------------------------
# ITEM R1, ISSUE 1337 -- THE LINE CURSOR'S SHADE, DERIVED FROM THE PANE.
# The user's words: "clicking on any line makes the entire line a shade darker
# (noticeably)."  Ruling DD-2: the shade is DERIVED, never written down.  A
# literal grey is the obvious thing and it is wrong in one of the two themes --
# #d0d0d0 on a near-black pane is not a shade, it is a stripe.
#
# ⚠ `ase::palette table` DIRECTLY, AND NOT `rdw::color field`.  rdw::palette
# iterates every role in rdw::color_sources and CALLS each source, so a source
# that asked rdw::color for another role would re-enter rdw::palette and
# recurse until the interpreter gave out.  The one thing this proc may read is
# the theme itself; the fallback pane is `rdw::_color_fallback field`'s job,
# below, and it derives from that field the same way.

# A colour to {r g b}, each 0-255, or {} when it cannot be read.  Hex of 1, 2,
# 3 or 4 digits per channel is parsed HERE, in pure Tcl, because half this
# window's suite runs on the --nogui arm where there is no `winfo` at all; a
# colour NAME is resolved through Tk when there is a Tk, and answers {} when
# there is not -- which makes the shade fall back rather than raise.
proc rdw::_rgb255 {c} {
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

# One step AWAY from `c`, as `#rrggbb`, or {} when `c` cannot be read.
#
# ⚠ AN ABSOLUTE STEP, NOT A MULTIPLY, AND THE DIRECTION FLIPS ON A DARK
# BACKGROUND.  The obvious derivation is `background * 0.88`, and it is
# invisible in exactly the theme this proc exists for: 0.88 of #202020 is
# #1c1c1c, four parts in 255 -- a difference no eye finds and no screenshot
# shows.  A fixed ±40 of 255 is a step the user can see on either ground
# (#ffffff -> #d7d7d7, #202020 -> #484848), and on an already dark pane the
# only direction with room left is LIGHTER.  "Noticeably" is the user's own
# word, so the window suite's section CU gives it a number -- 20 of 255 -- and
# fences both halves: a literal fails because it does not move with the theme,
# a multiply fails because it does not move far enough.
#
# The 0.30/0.59/0.11 weights are the standard luminance mix; the threshold is
# the midpoint of the range they produce, so `dark` means "darker than a mid
# grey" and nothing subtler.
proc rdw::_shade_step {c} {
    set rgb [rdw::_rgb255 $c]
    if {[llength $rgb] != 3} { return {} }
    set r [lindex $rgb 0]
    set g [lindex $rgb 1]
    set b [lindex $rgb 2]
    set lum [expr {0.30 * $r + 0.59 * $g + 0.11 * $b}]
    set d [expr {$lum > 96 ? -40 : 40}]
    set out {}
    foreach v [list $r $g $b] {
        set n [expr {$v + $d}]
        if {$n < 0} { set n 0 }
        if {$n > 255} { set n 255 }
        lappend out $n
    }
    return [format {#%02x%02x%02x} [lindex $out 0] [lindex $out 1] [lindex $out 2]]
}

proc rdw::_cursor_shade {} {
    set bg {}
    catch {set bg [ase::palette table]}
    if {$bg eq {}} { return {} }
    return [rdw::_shade_step $bg]
}

proc rdw::_color_fallback {role} {
    switch -exact -- $role {
        panel      { return #f2f2f2 }
        field      { return #ffffff }
        fieldfg    { return #000000 }
        selectbg   { return #4a6984 }
        selectfg   { return #ffffff }
        accent     { return #8b0000 }
        disabledfg { return grey50 }
        notefg     { return {dark orange} }
        cursor     { return [rdw::_shade_step [rdw::_color_fallback field]] }
    }
    return black
}

proc rdw::palette {} {
    set out {}
    foreach {role src} [rdw::color_sources] {
        set v {}
        catch {set v [uplevel #0 $src]}
        if {$v eq {}} { set v [rdw::_color_fallback $role] }
        lappend out $role $v
    }
    return $out
}

proc rdw::color {role} {
    set pal [rdw::palette]
    if {[dict exists $pal $role]} { return [dict get $pal $role] }
    return [rdw::_color_fallback $role]
}

# Raise-or-open, the calculator's singleton shape (calculator.tcl:412) plus the
# live-Tk guard calc::open does not need and this one does: item B4 reaches
# rdw::open from a key binding, and this window's own suite calls it under
# --nogui.
#
# ⚠ IT TAKES THE KEYBOARD NOWHERE, AND THAT IS THE FIX FOR A MEASURED
# DEFECT.  This window is a read-only record; the grammar that fills it -- bare
# 1/2/3/4 and the command mode's Escape -- lives on the design CANVAS, so a
# raise that moved keyboard focus here left a mode the user could not leave.
# Raising is not focusing, and the window manager's own map-time grant is
# caught by rdw::_focus_handback (see rdw::_arm_focus_handback below).
proc rdw::open {} {
    if {![rdw::have_tk]} { return {} }
    if {[winfo exists .rdw]} {
        wm deiconify .rdw
        raise .rdw
        return .rdw
    }
    return [rdw::build]
}

# ⚠ THE DUMPS SURVIVE A CLOSE.  ::rdw::blocks is namespace state, not window
# state, and this proc touches it not at all.  The calculator clears its
# message history on close because those are transient notices; these blocks
# ARE the artifact the feature exists to produce -- the user's words: paste
# them into design-review documents -- and losing an hour of them to a stray
# click on the window's X is the worse failure.  Every block is self-labelling
# (its own header, its own incompleteness line), so a stale one cannot be
# mistaken for a fresh one.  Rule debt 1245_B3_dumps_survive_close.
proc rdw::close {} {
    if {![rdw::have_tk]} { return {} }
    # Item R3: the remembered selection is a pair of indices into a buffer that
    # is about to stop existing.  Forgetting it here rather than on the next
    # open keeps `rdw::copy` from ever answering with the previous window's
    # text -- the pane is rebuilt by rdw::render_pane, but ::rdw::selspan is
    # namespace state and would otherwise outlive the widget.
    rdw::_forget_selection
    catch {destroy .rdw}
    return {}
}

proc rdw::build {} {
    variable listkind
    toplevel .rdw
    wm title .rdw {Results Display Window}
    wm protocol .rdw WM_DELETE_WINDOW rdw::close
    wm minsize .rdw 520 260
    ## The window manager grants keyboard focus to a newly mapped toplevel
    ## asynchronously, after every synchronous hand-back has already run.
    ## rdw::_focus_handback catches that one grant and gives the keyboard back
    ## to the canvas; it is inert unless a dump path armed it.
    bind .rdw <FocusIn> {rdw::_focus_handback %W}
    ## ⚠ ESCAPE HAS TO LIVE HERE TOO -- ISSUE 1308, RULING DD-12.
    ## The command mode's `1`/`2`/`3`/`4` and `<Key-Escape>` are bound on the
    ## CANVAS. Issue 1306's fix let this window keep the keyboard when the user
    ## clicks the text pane -- which is the whole point of the feature, since
    ## the dumps exist to be selected and pasted into a design-review document
    ## -- and the consequence measured immediately after was that the mode's
    ## documented exit became unreachable: the canvas no longer had the
    ## keyboard, and nothing on `.rdw` ended the mode.
    ##
    ## ⚠ IT ENDS THE MODE AND DOES NOT CLOSE THE WINDOW, and that asymmetry is
    ## deliberate. Escape closes a dialog in many applications, but this is not
    ## a dialog: it holds an hour of dumps that are the artifact the feature
    ## exists to produce, and rdw::close's own comment records that losing them
    ## to a stray click is the worse failure. A stray Escape is the same
    ## accident with a different finger. So Escape ends a mode when one is
    ## running and does NOTHING otherwise -- never a destructive default.
    ##
    ## The binding is on the toplevel, so it fires wherever focus sits inside
    ## the window, including the text pane, which is the case that matters.
    bind .rdw <Key-Escape> {
        if {[::rdw::pick_running]} { ::rdw::pick_end ; break }
    }
    ## ⚠ THE COPY CHORD LIVES ON THE TOPLEVEL TAG TOO, AND FOR THE SAME REASON
    ## AS ESCAPE -- ITEM R3, ISSUE 1339, RULING DD-5.
    ## Tk sends a key event to the FOCUS window, and the only copy this window
    ## had was `bind Text <<Copy>>`, which therefore existed only while
    ## .rdw.p.t itself held the keyboard.  MEASURED on this binary: with the
    ## keyboard on this window's own `Up` button a real Ctrl-C copies nothing
    ## at all -- the CLIPBOARD does not even come into existence -- and the
    ## same with it on .rdw.  Both are one click away, and worse:
    ## rdw::_arm_focus_handback deliberately hands the keyboard to the CANVAS
    ## after every dump, so "press a button, then copy" is the ORDINARY path
    ## and "select, then copy" is the rare one.  That is the user's first
    ## sentence, and no amount of re-binding the pane would have reached it.
    ##
    ## The toplevel tag is in the bindtag chain of every widget in this window
    ## (measured: .rdw.p.t -> `.rdw.p.t Text .rdw all`, .rdw.b.up ->
    ## `.rdw.b.up Button .rdw all`, .rdw itself -> `.rdw Toplevel all`), so one
    ## binding covers the pane, all five buttons, the status entry and the
    ## toplevel.
    ##
    ## ⚠ AND NOT `bind all`, WHICH IS THE CHEAP WAY TO GET THE SAME REACH.
    ## `all` reaches .drw, where Ctrl-C is the schematic's own copy-selected-
    ## objects; row CP11 of the keys suite is that fence, the same shape as the
    ## bare-digit fences B3/B4/B5 already in that file.
    ##
    ## THREE SEQUENCES, PER DD-5, AND THE VIRTUAL ONE IS NOT REDUNDANT.
    ## `event info <<Copy>>` on this build answers <Control-Key-c>, <Key-F16>,
    ## <Control-Lock-Key-C>, <Meta-Key-w>, <Lock-Meta-Key-W> and
    ## <Control-Key-Insert>; the two physical binds are what DD-5 names and are
    ## what a reader looks for, and <<Copy>> is what carries the other four and
    ## whatever a future Tk maps.  Tk prefers a physical binding over a virtual
    ## one on the SAME tag, so exactly one of the three fires per keystroke.
    ##
    ## The `break` stops the `all` tag.  Measured empty for all three sequences
    ## on this build, so it is defence in depth rather than the mechanism --
    ## kept, and named, the way wave_viewer.tcl:9187 keeps its own.
    bind .rdw <<Copy>>             {rdw::copy ; break}
    bind .rdw <Control-Key-c>      {rdw::copy ; break}
    bind .rdw <Control-Key-Insert> {rdw::copy ; break}
    catch {.rdw configure -background [rdw::color panel]}

    # The status line owns the bottom edge: it is where the five inert buttons
    # say why they did nothing, and where item B5's Save will name the exact
    # settings-file path it wrote.  A button that does nothing AND says
    # nothing cannot be told from a broken one.
    frame .rdw.s -background [rdw::color panel]
    entry .rdw.s.msg -textvariable ::rdw::statusmsg -state readonly \
        -relief sunken -borderwidth 1 -takefocus 0 \
        -background [rdw::color field] \
        -readonlybackground [rdw::color field] \
        -foreground [rdw::color fieldfg] \
        -selectbackground [rdw::color selectbg] \
        -selectforeground [rdw::color selectfg]
    pack .rdw.s.msg -side left -fill x -expand 1 -padx 3 -pady 3
    pack .rdw.s -side bottom -fill x

    # The button column, greyed per spec 4.2 B7 and WIRED by item B5.
    #
    # ⚠ ONE COMMAND FOR ALL FIVE, AND IT IS NOT A CONVENIENCE.  `rdw::button`
    # consults rdw::button_state itself, so the greying table is the COMMAND
    # PATH's fence as well as the widget's: a key, a menu or a later item that
    # reaches the proc directly gets the same answer the widget would have
    # given.  Five separate callbacks would have put that decision in the
    # widget layer, where the --nogui arm cannot see it.
    #
    # ⚠ AND NO WIDGET HERE MAY TAKE FOCUS (issue 1308).  Tk buttons do not on
    # X, which is the only reason the column hands the keyboard back; an entry,
    # a listbox or a -takefocus 1 button would change that into 1308's stuck
    # state.  The scope dialog is a separate TOPLEVEL for exactly that reason.
    #
    # ⚠ `::button`, WITH THE GLOBAL QUALIFIER, AND IT IS NOT STYLE.  This proc
    # runs inside `namespace eval rdw`-scoped code and item B5 named its
    # command sink `rdw::button`, which SHADOWS Tk's own `button` for every
    # unqualified call in this namespace.  Measured the moment it landed: the
    # widget line raised `wrong # args: should be "button id"`, from inside a
    # Button-1 handler, so Tk sent it to `bgerror` -- which pops a MODAL error
    # dialog nobody clicks, and the whole suite HUNG instead of failing (issue
    # 0803's shape, arriving through a name collision rather than a dialog).
    # Every widget command below is qualified for the same reason.
    frame .rdw.b -background [rdw::color panel]
    foreach {id label} [rdw::_buttons] {
        ::button .rdw.b.$id -text $label -width 8 -command [list rdw::button $id]
        pack .rdw.b.$id -side top -fill x -padx 4 -pady 2
    }
    pack .rdw.b -side right -fill y

    # The pane.  Read-only, selectable, exporting the X selection.
    frame .rdw.p -background [rdw::color panel]
    text .rdw.p.t -width 96 -height 26 -font TkFixedFont -wrap word \
        -state [rdw::_pane_state] -exportselection [rdw::_exportsel] \
        -borderwidth 1 -relief sunken \
        -background [rdw::color field] \
        -foreground [rdw::color fieldfg] \
        -selectbackground [rdw::color selectbg] \
        -selectforeground [rdw::color selectfg] \
        -yscrollcommand {.rdw.p.ys set}
    scrollbar .rdw.p.ys -command {.rdw.p.t yview}
    # `-wrap word` rather than a horizontal scrollbar: the incompleteness
    # sentence and the five silences are long, and a sentence clipped off the
    # right edge is a sentence the user does not read.  Wrapping is a DISPLAY
    # property -- a copied selection still carries the original lines, so the
    # paste shape is unaffected.
    catch {
        set hf [font actual TkFixedFont]
        dict set hf -weight bold
        .rdw.p.t tag configure hdr -font $hf
    }
    .rdw.p.t tag configure dim  -foreground [rdw::color disabledfg]
    .rdw.p.t tag configure dev  -foreground [rdw::color accent]
    .rdw.p.t tag configure note -foreground [rdw::color notefg]
    # ITEM R1, ISSUE 1337 -- THE LINE CURSOR.  The other four tags colour TEXT;
    # this one colours the whole row, so that the row Delete / Add / Up / Down
    # act on is a row the user can SEE.  It shades the target rdw::set_row
    # already moved -- there is exactly one cursor here, and rdw::_paint_cursor
    # is its only painter.
    #
    # ⚠ AND IT IS LOWERED BELOW `sel`.  MEASURED on this binary: `tag names`
    # answers `sel hdr dim dev note`, so `sel` is the LOWEST-priority tag in
    # the pane and a tag created now lands ABOVE it -- and a full-width
    # background above `sel` hides the selection outright.  This window exists
    # to be selected and pasted into a design-review document (item R3, issue
    # 1339), so the cursor gives way to the selection and never the other way
    # round.  Row CU10 of tests/headless/test_rdw_keys_1245.tcl is that fence.
    .rdw.p.t tag configure cursor -background [rdw::color cursor]
    .rdw.p.t tag lower cursor sel
    # ITEM R3, ISSUE 1339 -- THE HIGHLIGHT THAT SURVIVES A PRIMARY THEFT.
    # `keepsel` wears the selection's own colours because it IS the selection,
    # still standing after the X server handed PRIMARY to somebody else; see
    # rdw::_selection_changed for the mechanism and for what was measured.
    #
    # ⚠ ITS PRIORITY IS PINNED BETWEEN THE OTHER TWO, and neither neighbour is
    # arbitrary.  A tag created now lands ABOVE everything, and a full-width
    # selection colour above `sel` would hide the real selection whenever both
    # cover the same span.  Below `cursor` it would be hidden BY the line
    # cursor, which is a full-width background of its own.  Raising it just
    # above `cursor` leaves the order cursor / keepsel / sel, which is what row
    # CP8 of the keys suite reads back.
    .rdw.p.t tag configure keepsel -background [rdw::color selectbg] \
        -foreground [rdw::color selectfg]
    .rdw.p.t tag raise keepsel cursor
    bind .rdw.p.t <<Selection>> {rdw::_selection_changed}
    # ⚠ NO `break`.  A <Button-1> binding that ends in `break` stops the Text
    # CLASS binding, which is where the drag anchor a selection extends from is
    # set -- so the cursor would cost the window the one thing it is for.  The
    # widget binding runs BEFORE the class binding (bindtags MEASURED on this
    # binary are `.rdw.p.t Text .rdw all` -- item R1 wrote `.` for the third
    # tag, and item R3 depends on it really being `.rdw`), so both happen, in
    # that order.
    bind .rdw.p.t <Button-1> {rdw::pane_click %x %y}
    # ITEM R3 -- THE EXTEND, AND WHY IT IS ON THE TOPLEVEL TAG.
    # The fix-up has to run AFTER Tk's own <B1-Motion> has recomputed `sel`,
    # and the widget tag runs BEFORE the class tag.  `.rdw` is the next tag
    # after `Text` in the chain above, so this is the first place a binding can
    # see what the class binding decided.  rdw::pane_drag ignores every widget
    # but the pane -- the scrollbar shares this tag.
    bind .rdw <B1-Motion> {rdw::pane_drag %W}
    # ITEM R3, RULING DD-5 -- A COPY THAT NEEDS NO KEYBOARD AT ALL.
    # "A keyboard binding that a window manager or X server eats can never
    # leave the user with no way to get the text out -- which is the whole
    # point of the window."  MEASURED before this line existed: `bind
    # .rdw.p.t <Button-3>`, `bind Text <Button-3>` and `bind all <Button-3>`
    # were all the empty string, so a right-click in this pane did nothing.
    # %X %Y are ROOT pixels, which is what tk_popup wants -- the spelling
    # library_manager.tcl:144 already uses.  The `break` is defence in depth
    # against a future toplevel- or all-level Button-3, not the mechanism.
    bind .rdw.p.t <Button-3> {rdw::popup_menu %X %Y ; break}
    ## ⚠ AND THE CHORD IS BOUND ON THE PANE AS WELL, WHICH IS THE ONLY WAY
    ## rdw::copy CAN BE THE ONE COPY IT SAYS IT IS (issue 1344).
    ## The bindtag chain here is `.rdw.p.t Text .rdw all`, so `bind Text
    ## <<Copy>>` -- Tk's own tk_textCopy -- runs BEFORE the toplevel binding
    ## above it.  While the pane holds the keyboard that class binding is a
    ## SECOND door on to the clipboard, and it obeys none of rdw::copy's
    ## guards: MEASURED while writing row CP13, a selection covering nothing
    ## but a blank line put a bare newline on the clipboard through it, and the
    ## refusal rdw::copy then printed was true of everything except what had
    ## already happened.
    ##
    ## The widget tag runs FIRST, so this binding is the first thing the event
    ## meets, and the `break` is load-bearing here rather than defence in
    ## depth: it stops `Text` and it stops `.rdw`, so exactly one copy runs and
    ## it is this one.  Breaking THIS class binding costs nothing -- rdw::copy
    ## does everything tk_textCopy does and refuses the cases it should --
    ## unlike <Button-1>, whose class binding sets the drag anchor and is why
    ## the comment above it forbids a `break` there.
    bind .rdw.p.t <<Copy>>             {rdw::copy ; break}
    bind .rdw.p.t <Control-Key-c>      {rdw::copy ; break}
    bind .rdw.p.t <Control-Key-Insert> {rdw::copy ; break}
    pack .rdw.p.ys -side right -fill y
    pack .rdw.p.t -side left -fill both -expand 1
    pack .rdw.p -side left -fill both -expand 1

    rdw::apply_button_states
    rdw::render_pane
    return .rdw
}

# Repaint the pane from the store.  The store is newest-first and the blocks
# are laid out in that order, so the newest dump is on top and older ones are
# pushed below it.
proc rdw::render_pane {} {
    variable blocks
    variable targetrow
    # ⚠ A CURSOR MAY NOT OUTLIVE THE LINE IT POINTS AT (item R1, issue 1337),
    # AND THE SWEEP RUNS ABOVE THE Tk GUARD ON PURPOSE.  Every repaint is a
    # chance for the target's line to have gone: `4` (rdw::keep_latest) throws
    # the older dumps away, and a later item's reorder rewrites the rows in
    # place.  `rdw::_locate` is already the exact predicate for "a line some
    # block still owns", so a target it can no longer resolve is cleared HERE,
    # once, rather than at each of the callers that can strand one.
    #
    # The store works headless and the pane is only its projection (rdw::push's
    # own words), so a sweep behind the Tk guard would leave the two ARMS
    # disagreeing about the same store: with a display the buttons would say
    # "no row is marked", without one they would still refuse a line that no
    # longer exists BY ITS NUMBER.  This suite's majority runs --nogui and
    # would never have seen it.
    #
    # Clearing is the least-destructive reading: the buttons say there is no
    # row rather than editing whatever slid under the old line number.
    if {[info exists targetrow] && $targetrow > 0 \
        && [rdw::_locate $targetrow] eq {}} { set targetrow 0 }
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    .rdw.p.t configure -state normal
    .rdw.p.t delete 1.0 end
    # ITEM R3, ISSUE 1339.  ::rdw::selspan and ::rdw::dragfrom are pairs of
    # TEXT INDICES, and every line they name has just ceased to exist.  A text
    # index never fails to resolve -- Tk clamps it -- so a span left standing
    # here would go on copying, silently and plausibly, whatever slid under
    # those line numbers.  That is issue 1324's shape (a mark left to drift
    # while a variable still named the old row) pointed at the clipboard.
    rdw::_forget_selection
    foreach b $blocks {
        foreach e $b {
            .rdw.p.t insert end "[lindex $e 1]\n" [lindex $e 0]
        }
    }
    .rdw.p.t configure -state [rdw::_pane_state]
    rdw::_paint_cursor
    catch {.rdw.p.t see [rdw::_insert_index]}
    return {}
}

# THE CURSOR'S ONLY PAINTER (item R1, issue 1337).  It draws ::rdw::targetrow
# and reads no other state, so the shading cannot disagree with the row the
# button column acts on -- a second variable of its own would have given this
# window TWO cursors, a visible one and the one Delete obeys.
#
# ⚠ `$n.0` TO `[expr {$n + 1}].0`, NOT `lineend`.  The user's words are "the
# ENTIRE line"; a tag that stops at `lineend` stops at the last character, and
# on a 96-column pane holding a 12-character parameter row that is a stub of
# colour rather than a line.  Ending at the START of the next line is what
# paints past the last character to the right edge.  A WRAPPED line (the pane
# is -wrap word and the incompleteness sentence really does wrap) is one
# logical line and is shaded whole by the same span.
#
# The `insert` mark follows, so anything that reads the widget agrees with the
# variable -- issue 1324's measured disagreement (insert 9, targetrow 3) is
# what a mark left to drift on its own looks like.
proc rdw::_paint_cursor {} {
    variable targetrow
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    catch {.rdw.p.t tag remove cursor 1.0 end}
    if {![info exists targetrow]} { return {} }
    if {![string is integer -strict $targetrow] || $targetrow <= 0} { return {} }
    catch {.rdw.p.t mark set insert $targetrow.0}
    catch {.rdw.p.t tag add cursor $targetrow.0 [expr {$targetrow + 1}].0}
    return {}
}

# A click in the pane cursors the line under the pointer (item R1, issue 1337).
#
# ⚠ IT REFUSES A LINE NO BLOCK OWNS, AND `rdw::_locate` IS THE WHOLE GUARD.
# MEASURED: `index @x,y` CLAMPS -- a click in the empty lower half of a pane
# holding a 12-line render answers line 13, the widget's own trailing artifact.
# Shading that would put the cursor on a row the user cannot see and the
# buttons cannot use.  `_locate` already answers {} for exactly those lines
# (and for every line of an empty pane), so the refusal needs no new
# machinery.  A refused click leaves the cursor WHERE THE USER PUT IT: the
# least-destructive reading, and the one that does not punish a missed click.
proc rdw::pane_click {x y} {
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    # ITEM R3, ISSUE 1339.  This runs BEFORE the Text class binding throws the
    # standing selection away, which is the only moment the press can still be
    # compared against it.  It arms or disarms unconditionally, above every
    # early return below: a click this proc REFUSES for the cursor's sake is
    # still a click, and leaving the previous gesture's anchor armed would let
    # it extend a selection the user has since walked away from.
    rdw::_arm_extend $x $y
    set ix {}
    if {[catch {.rdw.p.t index @$x,$y} ix]} { return {} }
    set l [lindex [split $ix .] 0]
    if {![string is integer -strict $l]} { return {} }
    if {[rdw::_locate $l] eq {}} { return {} }
    rdw::set_row $l
    return {}
}

# ===========================================================================
# ITEM R3, ISSUE 1339 -- SELECT, AND COPY WHAT YOU SELECTED
# ===========================================================================
# The user's words: "Select and then press CTRL-C doesn't work. (Using VcXsrv
# for now). Double-click to start selection and then extend selection with
# press-and-drag seemed to work once, but not reliably. It's only worked one
# time."
#
# Pasting a dump into a design-review document is the whole stated reason this
# window is a Text widget and not a CIW dump, so this is the item that decides
# whether the feature is usable at all.
#
# ⚠ THE LITERAL READING OF RULING DD-5 IS A NO-OP HERE, AND SHIPPING IT WOULD
# HAVE BEEN GREEN AND WRONG.  DD-5 spells the repair as "bind <Control-c>,
# <Control-Insert> and <<Copy>> to a proc that does clipboard clear + clipboard
# append".  MEASURED on this binary, Tk 8.6.17, :99, 2026-09-05:
# `event info <<Copy>>` ALREADY answers <Control-Key-c>, <Key-F16>,
# <Control-Lock-Key-C>, <Meta-Key-w>, <Lock-Meta-Key-W> and
# <Control-Key-Insert>, and with the keyboard in the pane a real Ctrl-C ALREADY
# copies, through Tk's own Text class binding.  A row that selected a line,
# pressed Ctrl-C at the pane and asserted the clipboard passes on the
# UNMODIFIED tree.  Three different things are broken, and the literal reading
# of DD-5 fixes none of them:
#
#   1. THE KEYBOARD IS USUALLY NOT IN THE PANE.  Fixed by binding the chord on
#      the TOPLEVEL tag -- see rdw::build, where the measurement is recorded.
#
#   2. ANOTHER X CLIENT TAKES PRIMARY AND THE SELECTION VANISHES.  Fixed by
#      the mirror below -- see rdw::_selection_changed.
#
#   3. DOUBLE-CLICK, LET GO, THEN PRESS AND DRAG THROWS THE WORD AWAY.  Fixed
#      by rdw::pane_drag below.
#
# AND THE INPUT MOST LIKELY TO BREAK THE FIX, WHICH IS DD-5's OWN SPELLING:
# `clipboard clear` followed by `clipboard append` with nothing to append
# DESTROYS whatever the user had on the clipboard -- very likely the thing they
# were about to paste this dump next to.  rdw::copy therefore decides FIRST and
# writes second, and says out loud that it copied nothing: a copy that quietly
# does nothing cannot be told from the broken one this item exists to fix, and
# "doesn't work" is the entire bug report.  Same obligation as calc::inert's
# and rdw::button's -- a real control that does something and says nothing.
#
# WHAT WAS REJECTED, AND WHAT IT WOULD HAVE COST.  `-exportselection 0` (flip
# rdw::_exportsel) makes 2 impossible in ONE LINE, because a pane that exports
# nothing can never lose PRIMARY.  It also ends select-then-middle-click-paste,
# which rdw::_exportsel's own comment calls the user's stated reason the window
# exists at all.  Row CP10 of the keys suite is the receipt for not paying it.
#
# Suite: tests/headless/test_rdw_keys_1245.tcl section CP.  ⚠ RULING DD-8: a
# green :99 run is necessary and NOT sufficient for this item -- $DISPLAY is
# the VcXsrv / HC-Consult server the user actually looks at, `:0` is WSLg's
# Xwayland and `:99` is Xvfb (CLAUDE.md's three-server table), and selection
# and clipboard are precisely where the three differ.

namespace eval rdw {
    # THE REMEMBERED SELECTION, {first last} or {} -- the mirror that keeps the
    # user's selection alive across a PRIMARY theft.  rdw::_selection_changed
    # is its only writer.
    variable selspan
    if {![info exists selspan]} { set selspan {} }

    # The standing selection a <Button-1> press landed INSIDE of, {first last}
    # or {}, armed by rdw::_arm_extend and spent by rdw::pane_drag.  It is not
    # the same thing as `selspan`: this one answers "should the drag now
    # starting GROW what is already selected", and it is empty for the far more
    # common press that lands outside.
    variable dragfrom
    if {![info exists dragfrom]} { set dragfrom {} }
}

# THE MIRROR'S ONLY WRITER, and the one place this window decides whether a
# selection went away because the USER dropped it or because SOMEBODY TOOK IT.
#
# ⚠ THE MECHANISM, MEASURED RATHER THAN ASSUMED.  A Tk text widget with
# -exportselection 1 answers the loss of the X PRIMARY selection by DELETING
# ITS OWN `sel` TAG.  Driven on this binary: with a line selected,
# `selection own -selection PRIMARY .` leaves `tag ranges sel` EMPTY, `get
# sel.first sel.last` raising "text doesn't contain any characters tagged with
# sel", and the following Ctrl-C writing NOTHING AT ALL -- tk_textCopy's catch
# swallows it, so the user's clipboard silently keeps whatever it had.  That is
# BOTH halves of the user's report in one mechanism, and VcXsrv is exactly
# where it bites: its Windows clipboard bridge takes PRIMARY on its own
# schedule, which is why the gesture "worked one time".
#
# ⚠ AND THE DISCRIMINATOR IS THE OWNER, WHICH IS THE ONLY HONEST ONE.  Both a
# theft and a deliberate deselect arrive here as one <<Selection>> event with
# `tag ranges sel` empty, so the event alone cannot tell them apart.  MEASURED,
# reading `selection own` INSIDE the handler:
#     user clicks elsewhere in the pane   -> owner is .rdw.p.t
#     a script does `tag remove sel`      -> owner is .rdw.p.t
#     another client takes PRIMARY        -> owner is that client, or empty
# Tk does not release the selection when the tag is merely emptied, so "the
# pane still owns PRIMARY" means the user gave the selection up and the mirror
# must go with it; "the pane has lost PRIMARY" means it was taken, and the
# highlight the user is looking at must NOT vanish under them.  The query is
# local -- `selection own` names a window in THIS application or nothing, and
# never makes an X round trip to a foreign owner, which inside an event handler
# could block for the selection timeout.
#
# The mirror is NOT re-asserted as `sel`, deliberately: re-adding the tag would
# take PRIMARY straight back off the client that just asked for it, and two
# applications fighting over the selection is worse than the bug.
proc rdw::_selection_changed {} {
    variable selspan
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    set r {}
    if {[catch {.rdw.p.t tag ranges sel} r]} { return {} }
    if {[llength $r] >= 2} {
        set selspan [list [lindex $r 0] [lindex $r end]]
        rdw::_paint_keepsel
        return {}
    }
    set own {}
    catch {set own [selection own -displayof .rdw.p.t -selection PRIMARY]}
    # ⚠ A SELECTION IN ANY WIDGET OF THIS TOPLEVEL IS THE USER'S SELECTION,
    # AND THE MIRROR MUST GIVE WAY TO IT (issue 1344, defect b).  This test used
    # to be `$own eq {.rdw.p.t}` and nothing else, so the status entry -- which
    # is a readonly `entry` with -exportselection 1, and which item B5 fills
    # with the settings-file path, the single most copy-worthy string in the
    # window -- was scored a FOREIGN theft the moment the user dragged across
    # it.  The stale mirror was kept and the next Ctrl-C copied the PANE.
    # MEASURED before this line: PRIMARY holding
    # `/home/analog/.xschem/op_param_lists.tcl`, Ctrl-C, clipboard `MCU:/`.
    #
    # A theft is somebody ELSE taking the selection.  A sibling of this window
    # taking it is the user putting the selection somewhere else on purpose,
    # which is the same event as putting it down in the pane.
    if {[rdw::_in_window $own]} {
        set selspan {}
        rdw::_paint_keepsel
    }
    return {}
}

# Is $w this window or something inside it?  Pure, so the --nogui suite can
# fence it; `.rdw.` with the dot is deliberate -- a future toplevel named
# `.rdwx` is not this window and `string match {.rdw*}` would claim it.
proc rdw::_in_window {w} {
    if {$w eq {}} { return 0 }
    if {$w eq {.rdw}} { return 1 }
    if {[string match {.rdw.*} $w]} { return 1 }
    return 0
}

# The mirror's only painter, ::rdw::selspan and nothing else -- the same rule
# rdw::_paint_cursor follows, and for the same reason: a highlight drawn from a
# second opinion is a highlight that can disagree with what Ctrl-C copies.
proc rdw::_paint_keepsel {} {
    variable selspan
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    catch {.rdw.p.t tag remove keepsel 1.0 end}
    if {[llength $selspan] == 2} {
        catch {.rdw.p.t tag add keepsel [lindex $selspan 0] [lindex $selspan 1]}
    }
    return {}
}

# Drop both spans and the highlight that draws one.  Called wherever the buffer
# they index into stops being the buffer they were taken from.
proc rdw::_forget_selection {} {
    variable selspan
    variable dragfrom
    set selspan {}
    set dragfrom {}
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    catch {.rdw.p.t tag remove keepsel 1.0 end}
    return {}
}

# The span a copy acts on: {first last}, or {} when there is nothing to copy.
#
# ⚠ `sel` FIRST AND THE MIRROR SECOND, NEVER THE OTHER WAY ROUND.  While the
# pane still owns PRIMARY the widget's own tag is the truth -- the user may
# have moved it with the mouse a microsecond ago, and the mirror is only ever
# as fresh as the last <<Selection>>.  The mirror is consulted only when `sel`
# is gone, which in this window means one thing: somebody took PRIMARY.
#
# first..last rather than the individual ranges, because that is exactly what
# Tk's own tk_textCopy copies (`$w get sel.first sel.last`).  The two doors on
# to the clipboard must not disagree about a discontiguous selection, and this
# window has no way to make one anyway.
proc rdw::_selection_span {} {
    variable selspan
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    set r {}
    if {![catch {.rdw.p.t tag ranges sel} r] && [llength $r] >= 2} {
        return [list [lindex $r 0] [lindex $r end]]
    }
    if {[llength $selspan] != 2} { return {} }
    # ⚠ AND THE MIRROR IS STALE THE MOMENT ANOTHER WIDGET OF THIS WINDOW
    # HOLDS THE SELECTION (issue 1344, defect b).  rdw::_selection_changed
    # already drops it when it sees the hand-over, but it only sees one it is
    # told about: the pane fires <<Selection>> when its OWN `sel` tag changes,
    # and after a foreign theft that tag is already empty, so a later drag in
    # the status entry changes nothing the pane can hear.  Without this leg the
    # mirror outlives the theft AND the hand-over and Ctrl-C copies the pane.
    if {[llength [rdw::_sibling_selection]] == 2} { return {} }
    set ok 0
    if {[catch {.rdw.p.t compare [lindex $selspan 0] < [lindex $selspan 1]} ok]} {
        return {}
    }
    if {!$ok} { return {} }
    return $selspan
}

# THE SELECTION STANDING IN SOME OTHER WIDGET OF THIS WINDOW: {widget text},
# or {} when no widget of .rdw except the pane holds one.
#
# ⚠ THE STATUS ENTRY IS NOT A CURIOSITY, IT IS THE POINT.  `.rdw.s.msg` is a
# readonly `entry` with -exportselection 1 and a real drag selects in it; item
# B5 writes the settings-file path there, and a path is exactly the sort of
# string a user copies.  Ruling DD-5 gave this window a copy that works from
# anywhere in it -- so "anywhere in it" has to include the one widget whose
# contents the user most wants.
#
# ⚠ THE OWNER IS ASKED FIRST AND `selection get` ONLY AFTER.  `selection own`
# names a window in THIS application or nothing and never makes an X round
# trip; `selection get` against a LOCALLY owned selection is served in-process
# by the owner's own handler, so neither call can block inside a key handler
# for the selection timeout.  Reading it from X rather than from the widget
# keeps this proc honest for a widget class that is not an entry.
proc rdw::_sibling_selection {} {
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw]} { return {} }
    set own {}
    if {[catch {selection own -displayof .rdw -selection PRIMARY} own]} { return {} }
    if {$own eq {.rdw.p.t}} { return {} }
    if {![rdw::_in_window $own]} { return {} }
    set txt {}
    if {[catch {selection get -displayof .rdw -selection PRIMARY} txt]} { return {} }
    return [list $own $txt]
}

# ⚠ THE GUARD THAT MATTERS IS NOT "IS THE STRING EMPTY" (issue 1344,
# defect a).  `rdw::copy` used to ask `$txt eq {}`, which CANNOT be true of any
# span this window can produce -- `get first last` with first < last always
# yields at least one character -- so the guard was dead and the real case went
# through it.  The reachable instance is the EMPTY WINDOW: a Tk text widget
# always holds one mandatory trailing newline, `tag add sel 1.0 end` on it is
# the range {1.0 2.0}, and the user's clipboard was replaced by "\n".
#
# Whitespace, so a span of spaces or blank separator lines is refused too.  The
# cost is that a user who genuinely wanted to copy blank space is told no; the
# alternative is destroying the document they were about to paste into.
proc rdw::_worth_copying {txt} {
    return [expr {[string trim $txt] eq {} ? 0 : 1}]
}

# ONE COUNTER, AND BOTH DOORS COUNT THE SAME STRING WITH IT (issue 1344,
# defect d).  The window used to say "Selected the whole window, 1 line" and
# then "Copied 2 lines, 1 characters" about one and the same content, because
# rdw::select_all counted the LINE NUMBER of `end - 1c` and rdw::copy counted
# the elements of `split $txt \n`.  Both were wrong and they were wrong by
# different amounts.
#
# What the user is promised is the shape that lands in their document, so a
# trailing newline ends the last line rather than starting a new empty one --
# "a\nb\n" is two lines, and so is "a\nb".
proc rdw::_copy_lines {txt} {
    if {$txt eq {}} { return 0 }
    set n [llength [split $txt "\n"]]
    if {[string index $txt end] eq "\n"} { incr n -1 }
    return $n
}

# SAY WHAT THE COPY DID -- UNLESS THE STATUS LINE IS THE THING BEING COPIED
# (issue 1344, defect c).  rdw::status writes ::rdw::statusmsg, which is the
# -textvariable of `.rdw.s.msg`; writing it REPLACES that entry's contents and
# with them the user's live selection.  MEASURED before this proc existed: the
# user selects the settings-file path in the status line, presses Ctrl-C, and
# the path vanishes under their own selection.
#
# So when the copy's source IS that entry the window says nothing and leaves
# the line alone.  A receipt is worth less than the text it is a receipt for,
# and the still-standing highlight is the receipt: the selection survives, a
# second Ctrl-C works, and the path is still on screen to be read.  Driver
# decision, filed as a rule debt so the user can overturn it.
#
# Refusals are NOT routed through here and speak unconditionally: a refusal
# from that entry means it held nothing but blank space, so there is nothing
# left to destroy, and a silent refusal is CP5's own defect.
proc rdw::_copy_report {from msg} {
    if {$from eq {.rdw.s.msg}} { return {} }
    rdw::status $msg
    return {}
}

# THE ONE COPY, AND IT SERVES BOTH DOORS.  The chord (rdw::build) and the
# right-click menu (rdw::popup_menu) call this proc and nothing else, so the
# guard below cannot be true of one door and false of the other -- two
# implementations of "copy the selection" is exactly how a window ends up
# wiping the clipboard through the menu after the keyboard path was fixed.
proc rdw::copy {} {
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    # THREE PLACES A SELECTION CAN BE, AND THE ORDER IS THE WHOLE DECISION.
    #
    #   1. the pane's own live `sel` -- the freshest answer there is, and the
    #      one the user may have moved with the mouse a microsecond ago;
    #   2. ANOTHER WIDGET OF THIS TOPLEVEL, which today means the status entry
    #      and the settings-file path item B5 writes into it.  Issue 1344,
    #      defect b: a selection made there used to be scored a foreign theft,
    #      so the stale mirror was kept and Ctrl-C handed the user the pane's
    #      first line instead of the path they had highlighted;
    #   3. the mirror, which is what survives a genuine theft by another X
    #      client (rdw::_selection_changed) and is therefore the STALEST of the
    #      three -- it must come last, and rdw::_selection_span refuses it
    #      outright while a sibling holds the selection.
    #
    # Legs 1 and 3 are rdw::_selection_span, which is why leg 2 is asked in
    # between rather than after: a span from the mirror is not evidence about a
    # selection that is standing somewhere else right now.
    #
    # ⚠ AND ONE TAIL, NOT A SECOND COPY FOR THE SECOND SOURCE.  Every leg below
    # only decides `from` and `txt`; the guard, the clipboard write and the
    # sentence are written once, underneath.  A `_copy_sibling` proc of its own
    # would be the second implementation this comment block opens by warning
    # about, with the whitespace guard on one side of it only.
    set from .rdw.p.t
    set txt {}
    set span [rdw::_selection_span]
    if {[llength $span] == 2} {
        if {[catch {.rdw.p.t get [lindex $span 0] [lindex $span 1]} txt]} {
            rdw::status "The selection could not be read ([rdw::_oneline $txt]), so the clipboard was left alone."
            return {}
        }
    } else {
        set sib [rdw::_sibling_selection]
        if {[llength $sib] != 2} {
            # ⚠ DECIDE FIRST, WRITE SECOND.  `clipboard clear` here -- DD-5's
            # own order -- would destroy the clipboard of a user who pressed
            # Ctrl-C in the wrong window, and they would never learn why.
            rdw::status {Nothing is selected, so the clipboard was left alone. Drag over the lines you want (or right-click for Select All) and press Ctrl-C again.}
            return {}
        }
        set from [lindex $sib 0]
        set txt  [lindex $sib 1]
    }
    if {![rdw::_worth_copying $txt]} {
        rdw::status {There is nothing but blank space in the selection, so the clipboard was left alone.}
        return {}
    }
    catch {clipboard clear -displayof .rdw.p.t}
    if {[catch {clipboard append -displayof .rdw.p.t -- $txt} e]} {
        rdw::status "The clipboard refused the selection ([rdw::_oneline $e])."
        return {}
    }
    # The pane is -wrap word and the long sentences really do wrap, so the
    # count the user is told is the count of LOGICAL lines -- which is the
    # shape that will land in their document.  Saying "3 lines" for a paste
    # that arrives as 5 display rows would be the window lying about its one
    # deliverable.
    set n [rdw::_copy_lines $txt]
    rdw::_copy_report $from "Copied $n [expr {$n == 1 ? {line} : {lines}}], [string length $txt] characters, to the clipboard."
    return {}
}

# Select the whole window.  The other half of DD-5's keyboard-free door: a user
# who wants the entire dump should not have to drag across a scrolling pane.
proc rdw::select_all {} {
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    # ⚠ `end - 1c`, NEVER `end`, AND THAT ONE CHARACTER IS ISSUE 1344 DEFECT a.
    # A Tk text widget always holds a mandatory trailing newline, so on an
    # EMPTY pane `tag add sel 1.0 end` is the range {1.0 2.0} -- a real,
    # two-element range over a character the user never put there.  The
    # `llength $r < 2` guard below therefore never fired on the one window it
    # exists for, rdw::copy found a one-character span that its own `$txt eq
    # {}` test could not refuse, and three clicks in a freshly opened, empty
    # Results Display Window replaced the user's clipboard with a newline.
    # MEASURED identically on :99 and on the user's VcXsrv before this line.
    #
    # `end - 1c` collapses that range to nothing on an empty pane, so the guard
    # fires, and on a populated one it drops the same phantom newline off the
    # end of the copy -- which is also what makes the two sentences agree about
    # how many lines there are.
    catch {.rdw.p.t tag add sel 1.0 {end - 1c}}
    set r {}
    catch {.rdw.p.t tag ranges sel} r
    set txt {}
    if {[llength $r] >= 2} {
        catch {.rdw.p.t get [lindex $r 0] [lindex $r end]} txt
    }
    # AND THE SAME "WORTH COPYING" TEST rdw::copy USES, for the same reason and
    # from the same proc: a pane holding nothing but blank space is a pane with
    # nothing in it to select, whatever the index arithmetic says.
    if {![rdw::_worth_copying $txt]} {
        catch {.rdw.p.t tag remove sel 1.0 end}
        rdw::status {There is nothing in the window to select yet.}
        return {}
    }
    # ONE COUNTER, THE SAME STRING (issue 1344 defect d).  This used to be the
    # LINE NUMBER of `end - 1c` while rdw::copy counted `split $txt` elements,
    # so the window said "Selected the whole window, 1 line" and then "Copied 2
    # lines, 1 characters" about one and the same content.
    set n [rdw::_copy_lines $txt]
    rdw::status "Selected the whole window, $n [expr {$n == 1 ? {line} : {lines}}]. Press Ctrl-C, or right-click Copy, to put it on the clipboard."
    return {}
}

# RULING DD-5's KEYBOARD-FREE DOOR.  Built once and kept: it is a child of
# .rdw, so rdw::close destroys it with the window and a reopened window builds
# a fresh one.
#
# ⚠ `::menu`, WITH THE GLOBAL QUALIFIER, for rdw::build's own reason -- an
# unqualified widget command inside this namespace is one same-named proc away
# from a `wrong # args` raised inside a Button-3 handler, which Tk sends to
# bgerror, which pops a modal dialog nobody clicks.
#
# ⚠ `Copy` IS THE FIRST ENTRY AND NOTHING ELSE MAY MATCH `*copy*` ABOVE IT --
# row CP4 finds the entry by label, and so will the next reader.  The
# accelerator names the chord that really exists; `Select All` deliberately
# carries none, because Tk's Text class already spends <Control-Key-a> on
# beginning-of-line and an accelerator that does nothing is a lie on screen.
proc rdw::popup_menu {rootx rooty} {
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw]} { return {} }
    if {![winfo exists .rdw.pop]} {
        if {[catch {::menu .rdw.pop -tearoff 0 -takefocus 0}]} { return {} }
        .rdw.pop add command -label {Copy} -accelerator {Ctrl+C} -command rdw::copy
        .rdw.pop add command -label {Select All} -command rdw::select_all
        catch {
            .rdw.pop configure -background [rdw::color panel] \
                -foreground [rdw::color fieldfg] \
                -activebackground [rdw::color selectbg] \
                -activeforeground [rdw::color selectfg]
        }
    }
    catch {tk_popup .rdw.pop $rootx $rooty}
    return {}
}

# ARM THE EXTEND.  Called from rdw::pane_click, which the widget tag runs
# BEFORE the Text class binding -- the one moment at which the press can still
# be compared against the selection the class binding is about to delete.
#
# ⚠ THE PRESS MUST LAND INSIDE THE STANDING SELECTION, AND THAT TEST IS THE
# WHOLE FENCE.  An extend that extends unconditionally is the obvious over-fix
# and it is worse than the bug: the second selection would grow out of the
# first for ever and the user could never make a small one again.  Row CP7 of
# the keys suite presses OUTSIDE and requires a FRESH selection; rows CP6 and
# CP7 together are what pins this to "inside".
proc rdw::_arm_extend {x y} {
    variable dragfrom
    set dragfrom {}
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    set r {}
    if {[catch {.rdw.p.t tag ranges sel} r]} { return {} }
    if {[llength $r] < 2} { return {} }
    set first [lindex $r 0]
    set last [lindex $r end]
    set ix {}
    if {[catch {.rdw.p.t index @$x,$y} ix]} { return {} }
    set inside 0
    if {[catch {expr {[.rdw.p.t compare $ix >= $first] \
                      && [.rdw.p.t compare $ix <= $last]}} inside]} { return {} }
    if {$inside} { set dragfrom [list $first $last] }
    return {}
}

# THE USER'S SECOND SENTENCE: double-click a word, LET GO, then press and drag.
#
# ⚠ WHAT TK DOES, MEASURED 5/5 ON THE FIXTURE.  `bind Text <1>` ends in
# `%W tag remove sel 0.0 end` and tk::TextButton1 re-anchors on the press, so
# the second gesture starts a FRESH character run from wherever it landed: a
# double-click on `complete` at 3.6-3.14 followed by a press at 3.10 and a drag
# to 3.40 answers 3.10-3.40 -- the word the user double-clicked, cut in half.
# The gesture that DOES work is holding the second click down (Tk's own
# word-wise extension), and so does a shift-click, which is exactly why the
# user saw it work "one time": their hand sometimes held the second click.
#
# ⚠ AND THE REPAIR IS A UNION AFTER THE FACT, NOT A `break` BEFORE IT.  The
# alternative is to stop the class binding on the press and re-anchor by hand,
# which means writing `tk::Priv(selectMode)` and the widget's private anchor
# mark from this file -- Tk internals, re-derived, in the one binding whose
# comment in rdw::build already records what breaking that class binding costs.
# Unioning the drag's own answer with the span the press landed in needs no
# internals at all, keeps every gesture Tk already gets right (row CP7 legs 1-3
# are unchanged code paths), and degrades correctly: with `dragfrom` empty this
# proc is a no-op and the pane behaves exactly as it does today.
#
# It restores the span even when the drag has not yet moved far enough for
# tk::TextSelectTo to re-tag anything, which is what keeps a press-and-tiny-
# drag inside a selection from silently emptying it.
proc rdw::pane_drag {w} {
    variable dragfrom
    if {$w ne {.rdw.p.t}} { return {} }
    if {[llength $dragfrom] != 2} { return {} }
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    set first [lindex $dragfrom 0]
    set last [lindex $dragfrom 1]
    set r {}
    if {![catch {.rdw.p.t tag ranges sel} r] && [llength $r] >= 2} {
        catch {
            if {[.rdw.p.t compare [lindex $r 0] < $first]} { set first [lindex $r 0] }
            if {[.rdw.p.t compare [lindex $r end] > $last]} { set last [lindex $r end] }
        }
    }
    # ONE range, always: the press landed inside {first last}, so the drag's own
    # answer and the remembered span overlap and their union is contiguous.
    catch {.rdw.p.t tag add sel $first $last}
    return {}
}

# The list identity the greying keys on.  Item B4 owns the keys that select a
# list and MUST drive this setter; a second state variable would be exactly
# the two-builders drift invariant I1 forbids.
proc rdw::set_list {kind} {
    variable listkind
    if {[lsearch -exact {annotation summary all} $kind] < 0} {
        return -code error \
            "rdw::set_list: unknown list '$kind' (annotation, summary or all)"
    }
    set listkind $kind
    rdw::apply_button_states
    return $kind
}

proc rdw::apply_button_states {} {
    variable listkind
    if {![rdw::have_tk]} { return {} }
    foreach id {up down delete add save} {
        if {![winfo exists .rdw.b.$id]} { continue }
        .rdw.b.$id configure -state [rdw::button_state $id $listkind]
    }
    return {}
}

# ⚠ `rdw::inert` USED TO LIVE HERE AND ITEM B5 DELETED IT.  It said "the
# button column is built but not wired yet (item B5 wires it)", which after B5
# wired it is a lie -- and rows W4b and Q9 golded that lie.  Its OBLIGATION,
# copied from calc::inert (calculator.tcl:607), does not lapse with the
# inertness; it sharpens.  A real, visible, enabled control that DOES something
# and says nothing is exactly as indistinguishable from a broken one, so every
# path out of rdw::button ends in a status line that names the button it came
# from.  See "THE BUTTON COLUMN" at the foot of this file.

# ===========================================================================
# ITEM B4 -- THE KEYS AND THE TWO GRAMMARS
# ===========================================================================
# Ruling D-2, the user's own choice: this window takes bare 1 / 2 / 3 / 4 IN
# THE CADENCE PROFILE ONLY.  Stock xschem keeps `logic_set`.  The four binds
# live in src/cadence_style_rc; everything they do once the event has arrived
# lives here, so the grammar is testable with no Tk at all.
#
#   1 -> annotation list   2 -> summary list   3 -> everything
#   4 -> refresh: keep only the most recent dump
#
# TWO GRAMMARS, THE USER'S OWN WORDS FOR BOTH.
#   NOUN-VERB  exactly one instance selected, press a key, dump it.
#   VERB-NOUN  nothing selected, press a key: enter a COMMAND MODE and click
#              devices.  "This is a command mode, so clicking will not change
#              selected set."  So the click is resolved with the READ-ONLY
#              `xschem instance_at` (findnet.c:553, override_lock=1), which
#              writes neither `.sel` nor `sel_array`.  Its mutating twin was
#              measured at one instance's bbox centre answering `poly 0 2 698`
#              and setting lastsel 1 -- it does not merely select, it selects a
#              DIFFERENT OBJECT than the instance under the cursor.  Do not
#              reach for it here, and row K10 is the structural fence that says
#              so.
#   REFUSE     more than one selected, or a selection that is not an instance:
#              ONE short CIW line, no block, and the selection untouched.
#
# WHERE EACH REFUSAL GOES, AND WHY THE TWO CHANNELS ARE NOT DOUBLE-BOOKED.
# Item B3 already minted five window sentences for "there is nothing to say
# about this device", and PLAN forbids rewording them ad hoc.  The user asked
# for "a short message in CIW if more than one selected or nothing is
# available".  Echoing both says the same fact twice, so the split is:
#   a DEVICE was resolved  -> the WINDOW answers, in B3's locked sentence, and
#                             the CIW stays silent (this includes a device with
#                             no descriptor and a run with no raw);
#   NO device was resolved -> ONE CIW line, no block, no window.
# That is the second half of the user's sentence landing in the window rather
# than the CIW, and it is this item's E question: see the ledger row.
#
# WHAT THE KEYS DELIBERATELY DO NOT DO.  Keys 1, 2 and 3 select a list
# IDENTITY through rdw::set_list -- B3's ONE setter -- and narrow no CONTENT.
# The narrowing has exactly one definition in this tree (the list store's
# `effective`, plus ruling DD-6's display key that item B2b built), and row S1
# of this file's own suite forbids naming op_param_lists:: here at all.  A
# second definition of "the annotation list" living in this file is precisely
# the two-builders drift invariant I1 exists to prevent, and a block LABELLED
# with a list whose content is identical for all three would imply a narrowing
# that did not happen -- the DD-1 failure shape.  Filed as issue 1300.
#
# Suite: tests/headless/test_rdw_window_1245.tcl section K (both arms) and
# tests/headless/test_rdw_keys_1245.tcl (the binds, the mode, the pick and the
# descend; :99 only, because src/cadence_style_rc cannot be sourced under
# --nogui -- it dies at its first `bind`).

namespace eval rdw {
    # THE COMMAND MODE'S WHOLE STATE.  One array, not a per-session dict:
    # there is one canvas pick mode at a time, exactly as ASE Direct Plot has
    # one `sod(active)`.
    #   canvas     the widget the seize is currently on
    #   prevpress prevrel prevesc prevmotion   the FOUR predecessors, handed
    #              back verbatim.  The fourth is issue 1304: see rdw::_pick_seize.
    #   suspended  set only between cmdmode's suspend and resume arms
    variable pick
    if {![info exists pick]} { array set pick {} }

    # The one-shot flag rdw::_arm_focus_handback sets and rdw::_focus_handback
    # clears.  Namespace state rather than a proc-local, because the arming and
    # the firing are two different events.
    variable focus_pending
    if {![info exists focus_pending]} { set focus_pending 0 }
}

# ---------------------------------------------------------------------------
# THE ONE REFUSAL CHANNEL.  Every "there is no device to ask about" line in
# this item goes through here, so the wording cannot drift between the two
# grammars and a suite can observe the channel by stubbing one command.
# `ciw_echo` (ciw.tcl:502) is defined under --nogui and silently returns when
# there is no CIW widget, so this is safe on every arm.
proc rdw::_ciw {msg} {
    catch {ciw_echo $msg}
    return {}
}

# ---------------------------------------------------------------------------
# WHAT IS SELECTED, IN THE FOUR ANSWERS THE KEYS HAVE TO TELL APART:
#   {none {}}  {one <instname>}  {many {}}  {notinst {}}
#
# ⚠ THE MEASUREMENT IS COPIED FROM cadence::one_instance_selected
# (utils/cadence_nav.tcl:38), NOT ITS CALL.  This file is installed and is
# sourced by stock xschem; utils/cadence_nav.tcl is neither, so calling across
# would make an installed helper depend on a profile file that may not be
# there.  The measurement itself is `xschem get lastsel` and then the row's
# TYPE -- never `llength [xschem selected_set]`, which throws on an instance
# name holding an unbalanced brace (issue 0388) and which filters wires away
# entirely, so a single selected WIRE would read as "nothing selected" and the
# key would arm the pick mode over a live selection.
proc rdw::_selected_instance {} {
    set n 0
    catch {set n [xschem get lastsel]}
    if {![string is integer -strict $n] || $n <= 0} { return [list none {}] }
    if {$n != 1} { return [list many {}] }
    set rows {}
    catch {set rows [xschem selection]}
    set row [lindex $rows 0]
    if {[lindex $row 0] ne {instance}} { return [list notinst {}] }
    set name {}
    catch {set name [xschem getprop instance [lindex $row 1] name]}
    if {[string trim $name] eq {}} { return [list notinst {}] }
    return [list one $name]
}

# ---------------------------------------------------------------------------
# Hand the keyboard back to the design canvas.
#
# ⚠ `-force`, AND THE REASON IS MEASURED IN ASE.  The command mode's Escape
# binding lives on the CANVAS, so a dump that leaves keyboard focus on the
# results toplevel leaves a mode the user cannot escape --
# ase_window.tcl:1905-1911 records the same failure from the other side.  A
# plain `focus $cv` only moves the focus WITHIN a toplevel, so it cannot undo a
# focus that has already crossed to another one; `-force` can.  This is a
# hand-back, not a steal: the key that started this was pressed on the canvas.
#
# It arms nothing itself.  Arming here would re-arm on every hand-back and the
# handler would then chase its own tail.
proc rdw::_focus_canvas {} {
    if {![rdw::have_tk]} { return {} }
    set cv {}
    catch {set cv [xschem get current_win_path]}
    if {$cv eq {} || ![winfo exists $cv]} { return {} }
    catch {focus -force $cv}
    return $cv
}

# ---------------------------------------------------------------------------
# THE HAND-BACK IS EVENT DRIVEN, BECAUSE A SYNCHRONOUS ONE CANNOT WIN THE RACE.
#
# ⚠ MEASURED, :99 under openbox, FIRST open of a session: immediately after
# rdw::_focus_canvas has run, and again after `update idletasks`, the keyboard
# is on the canvas; ONE `update` later it is on .rdw and it stays there.  The
# window manager grants focus to a newly MAPPED toplevel on a MapNotify round
# trip, which arrives after every synchronous call in the dump path has
# returned.  On the SECOND open the same hand-back sticks, because a WM grants
# map-time focus once.  So the first dump of a session -- and only the first --
# used to leave a command mode whose Escape the keyboard could not reach.
#
# ⚠ AND THIS IS WHY B4's OWN ROW V8 PASSED WITH THE RACE LIVE: every row before
# it had already mapped .rdw.  Ordering inside a suite is part of the fixture.
#
# THREE NARROWINGS, EACH ONE A CASE THAT MUST NOT BOUNCE:
#   * ONE SHOT.  The flag is cleared by the first grant it catches, so the
#     user's next click on the window keeps the keyboard.
#   * ONLY WHEN A MAP IS ACTUALLY COMING.  A dump into an already-mapped window
#     arms nothing: there is no grant to catch, and an armed flag left lying
#     around is a bounce waiting to happen.
#   * ONLY WHEN THE KEYBOARD LANDED ON THE TOPLEVEL ITSELF.  The decision is
#     WHERE THE KEYBOARD ENDED UP -- `[focus]` -- and not which window named
#     the event.  Issue 1306: deciding on `%W` alone shipped a hand-back that
#     BOUNCED the user's deliberate click into the text pane, which is the one
#     focus this window is entitled to keep and the whole reason the window
#     exists (select a block, copy it into a design-review document).
#
#     ⚠ TWO REAL MECHANISMS PUT `.rdw` IN `%W`, AND ONLY ONE OF THEM IS THE
#     BINDTAGS ONE.  Both measured:
#       - INFERIOR crossing (focus already inside .rdw, moving to .rdw.p.t):
#         Tk delivers FocusIn to .rdw.p and .rdw.p.t only, and this binding
#         fires for them because the toplevel's name is in every child's
#         BINDTAGS.  That is the mechanism the pre-fix comment named, and it
#         is correct as far as it goes.
#       - Crossing from OUTSIDE (.drw -> .rdw.p.t, the WM-less arm): X ALSO
#         delivers a separate FocusIn to `.rdw` ITSELF, detail
#         NotifyNonlinearVirtual, along the ANCESTOR chain.  `%W` is then
#         literally `.rdw` for a click on the pane, so no `%W` test whatever
#         can tell that click from the window manager's map-time grant.
#     The discriminator that CAN is the one the WM itself supplies: the grant
#     lands on the TOPLEVEL (`[focus]` eq `.rdw`, detail NotifyAncestor), while
#     every deliberate landing lands on a CHILD (`[focus]` eq `.rdw.p.t`).
#
#     ⚠ AND THE OBVIOUS GLOB IS WRONG.  `[string match .rdw* [focus]]` -- the
#     line issue 1306's own recommended fix prints -- matches the DESCENDANT
#     `.rdw.p.t` exactly as readily as `.rdw`, so the click is still bounced.
#     Measured 3/3 under a WM and 3/3 WM-less.  The test is EXACT EQUALITY
#     against the toplevel, and row K16 of the window suite keeps `string
#     match` out of this proc so nobody reintroduces it as a simplification.
#
# COST, STATED (rejected alternatives are in the receipt), AND IT IS TRUE FOR
# THE FIRST TIME: a deliberate landing does NOT spend the one shot -- only a
# real grant does -- so if a window manager maps this window and never focuses
# it, the armed flag survives, and the user's next click on the window's FRAME
# or on its BUTTON COLUMN (Tk buttons do not take focus on X, so `[focus]`
# stays at `.rdw`) hands the keyboard back to the canvas exactly once.  A click
# on the TEXT never does.  A timer disarm would remove that wart and
# reintroduce the flakiness this fix exists to delete.
#
# ⚠ `remapping` IS THE SECOND NARROWING'S ESCAPE HATCH, NOT A HOLE IN IT
# (issue 1340).  "Only when a map is actually coming" is a statement about the
# window, and item R4 made it false: a dump into an ALREADY-MAPPED window now
# re-maps it (rdw::_raise), so a grant IS coming and declining to arm would
# leave the keyboard in this window -- the one thing the user forbade.  The
# caller says so explicitly rather than this proc guessing, because every
# other caller's window really is either absent or unmapped and their
# behaviour must not move.
proc rdw::_arm_focus_handback {{remapping 0}} {
    variable focus_pending
    if {![rdw::have_tk]} { return 0 }
    if {!$remapping && [winfo exists .rdw] && [winfo ismapped .rdw]} { return 0 }
    set focus_pending 1
    return 1
}

proc rdw::_focus_handback {{w {}}} {
    variable focus_pending
    if {![info exists focus_pending] || !$focus_pending} { return 0 }
    ## %W is a cheap NECESSARY-but-not-sufficient first cut: it rejects the two
    ## inferior child events without paying for a `focus` call.  It is NOT the
    ## decision -- see the ancestor chain above.
    if {$w ne {} && $w ne {.rdw}} { return 0 }
    ## THE DECISION.  Strictly BELOW the focus_pending early return, because
    ## --nogui has no `focus` command at all and this proc survives headless
    ## only by returning before it gets here.
    set land {} ; catch {set land [focus]}
    if {$land ne {.rdw}} { return 0 }
    set focus_pending 0
    rdw::_focus_canvas
    return 1
}

# ---------------------------------------------------------------------------
# NOUN-VERB.  Open the window FIRST and dump second: rdw::render_pane no-ops
# when .rdw.p.t does not exist, so a key that dumped without opening would put
# the block in the store and NOTHING on screen.
#
# ⚠ AND THAT ORDER WAS UNFENCED UNTIL NOW.  Deleting the open reds no row that
# reads ::rdw::blocks, which is every dump row in both suites -- the store is
# filled either way and only the SCREEN is empty.  Row F2 of the keys suite
# reads `.rdw.p.t get 1.0 end` for exactly that reason, and row K15 of the
# window suite fences the order structurally on both arms.
proc rdw::show {instname} {
    rdw::_arm_focus_handback
    rdw::open
    set blk [rdw::dump $instname]
    rdw::_focus_canvas
    return $blk
}

# ---------------------------------------------------------------------------
# KEY 4.  Trim the store to the most recent block.
#
# ⚠ WHICH END IS NEWEST IS ASKED OF rdw::_insert_index, THE SAME ACCESSOR
# rdw::push BRANCHES ON.  A hard-coded `lrange $blocks 0 0` is right today and
# silently keeps the OLDEST block the day the accessor is flipped -- exactly
# the gap issue 1283 filed against row Q1b.  Invariant I1: one definition of
# "newest", several consumers.
#
# It always NAMES what it did in the status line, empty store included: a
# control that silently does nothing cannot be told from a broken one
# (calc::inert's own reason, calculator.tcl:607).
proc rdw::keep_latest {} {
    variable blocks
    set n [llength $blocks]
    if {$n > 1} {
        if {[rdw::_insert_index] eq {1.0}} {
            set blocks [lrange $blocks 0 0]
        } else {
            set blocks [lrange $blocks end end]
        }
    }
    rdw::render_pane
    if {$n > 1} {
        rdw::status "Refresh: kept the most recent dump and cleared [expr {$n - 1}] earlier one(s)."
    } elseif {$n == 1} {
        rdw::status {Refresh: the window already shows one dump - there was nothing to clear.}
    } else {
        rdw::status {Refresh: the window is already empty - there was nothing to clear.}
    }
    return {}
}

# ---------------------------------------------------------------------------
# THE KEY ITSELF.  `kind` is annotation | summary | all | refresh.
proc rdw::key {kind} {
    if {$kind eq {refresh}} {
        rdw::_arm_focus_handback
        rdw::open
        rdw::keep_latest
        rdw::_focus_canvas
        return {}
    }
    ## ⚠ THE SELECTION IS RESOLVED BEFORE ANY STATE MOVES, AND THAT ORDER IS
    ## THE FIX.  B4 set the list identity first and refused second, so a
    ## refused key still re-labelled the window and re-greyed the whole button
    ## column with a list the user never got -- a visible state change reporting
    ## a command that did not happen.  A refusal must change nothing: no list,
    ## no buttons, no block, no selection.  Row K12 of the window suite holds
    ## it on both arms.
    lassign [rdw::_selected_instance] what name
    if {$what eq {many}} {
        return [rdw::_ciw {Results window: more than one object is selected - select exactly one device instance, or select nothing at all and press the key again to pick devices by clicking.}]
    }
    if {$what ne {one} && $what ne {none}} {
        return [rdw::_ciw {Results window: the selected object is not a device instance - select one instance, or select nothing at all and press the key again to pick devices by clicking.}]
    }
    ## B3's ONE list-identity setter.  A second state variable here would be
    ## the drift invariant I1 forbids, and the button greying reads this one.
    ## An unknown list name is therefore reported by the setter that owns the
    ## names, not by a second validator living here.
    if {[catch {rdw::set_list $kind} e]} {
        return [rdw::_ciw "Results window: $e"]
    }
    if {$what eq {one}} {
        rdw::show $name
    } else {
        rdw::pick_start
    }
    return {}
}

# ---------------------------------------------------------------------------
# THE PICK'S TWO NAMED READERS.  Both exist as named callees rather than
# inline calls so that a sabotage variant has something to neutralise and so
# that row K10 can fence WHICH verb the canvas is read through.

# ⚠ THE CLICK BOX IS A CACHE, AND THREE MEASURED OPERATIONS MOVE IT WITHOUT
# REFRESHING IT.  find_closest_element() gates candidates on the CACHED
# inst[i].x1..y2 (findnet.c:461) and nothing recomputes that cache except a
# symbol_bbox() call.  Item A6 closed every symbol_bbox() door from inside the
# callee (select.c:723), which does not help when nothing calls it:
#   * issue 1266 -- `xschem annotate_op` and `xschem raw clear` move the gate's
#     answer while calling symbol_bbox() NOT AT ALL.  Driven both directions: a
#     click lands on blank canvas one way and misses visible text the other.
#   * issue 1260 -- `xschem setprop instance` and `xschem move_instance
#     ... nodraw` still write the click box from a stale gate.
#   * item A3 -- with the declutter on, a device's with-text box SHRINKS to
#     what is still drawn, so a fixture written against pre-A3 coordinates
#     misses.
# So the gate is refreshed before EVERY pick, not once at mode entry: the mode
# seizes Button-1, the lone release, Escape and the Button-1 drag and nothing
# else, so 6 / Ctrl-6 / Ctrl-Alt-6 and any annotate_op still move the gate
# WHILE the mode is live, and a first-pick-only refresh is stale by the second
# click.  Rows P1 and P2 are those two cases.
proc rdw::_refresh_pick_gate {} {
    catch {xschem update_all_sym_bboxes}
    return {}
}

# THE READ-ONLY COORDINATE PICK.  Answers an instance name or the empty string
# and changes nothing at all -- no selection, no highlight, no modify flag.
proc rdw::_pick_at {x y} {
    set r {}
    catch {set r [xschem instance_at $x $y]}
    return $r
}

# ---------------------------------------------------------------------------
# THE SEIZE.  The shape is ase::ui::select_on_design's (ase_window.tcl:1877,
# the latch at :1897-1899):
# latch the predecessors, take Button-1 and Escape, take the lone RELEASE too
# (the press it pairs with was swallowed, so it must not reach C on its own),
# and give the canvas keyboard focus or a real ESC never arrives.
#
# ⚠ IT TAKES A FOURTH SEQUENCE THAT ASE'S DOES NOT, AND THAT IS ISSUE 1304.
# Copying the three-sequence shape leaves C's rubber band with a start and no
# end: a motion with Button1Mask calls select_rect(START,1) + unselect_all(1)
# and sets STARTSELECT (callback.c:7250-7260), and the ONLY thing that
# terminates it is ButtonRelease's select_rect(...,END,-1) (callback.c:9748) --
# which the seized release eats.  Measured on the shipped cmos_inv.sch, an
# 8-step drag from empty canvas with the three-sequence seize live: ui_state
# 24, lastsel 20, twenty objects in `xschem selection`, and all three unchanged
# after the release AND after a real Escape.  The same gesture with no mode
# armed terminates at ui_state 0 with nothing selected.  That is a direct
# violation of the user's own requirement -- "This is a command mode, so
# clicking will not change selected set" -- reached by a one-pixel drift of the
# hand.  So <B1-Motion> is seized too.
#
# ⚠ IT BLINDS C ONLY WHILE BUTTON 1 IS HELD.  C's motion handler also drives
# the crosshair, the hover highlight, the fly-lines and the status line
# (callback.c:7169); those all run on plain <Motion>, which is untouched, so
# the mode still tracks the pointer.  Row V2b's hover leg is that measurement.
# The seize is on the design canvas only and never on `.` -- xschem.tcl's
# tab-swap <B1-Motion> starts on `.tabs.x*` and is unreachable from here.
#
# ⚠ Measured on this tree: `.drw` is a FRAME whose shipped bindings are the
# GENERIC <Button> and <Key>, so all four predecessors are the EMPTY STRING.
# `bind w seq {}` DESTROYS a binding, which is what makes the restore
# byte-identical -- a restore that writes an empty script back would leave an
# empty-but-PRESENT binding that passes a string comparison and fails the
# sequence-list one.  Row V6 holds both legs, and it reads the <B1-Motion> slot
# while the mode is still LIVE, because after the release it is back at its
# predecessor whether the seize ever took it or not.
proc rdw::_pick_seize {cv} {
    variable pick
    set pick(canvas)     $cv
    set pick(prevpress)  [bind $cv <ButtonPress-1>]
    set pick(prevrel)    [bind $cv <ButtonRelease-1>]
    set pick(prevesc)    [bind $cv <Key-Escape>]
    set pick(prevmotion) [bind $cv <B1-Motion>]
    bind $cv <ButtonPress-1>   "[list rdw::pick_click]; break"
    bind $cv <ButtonRelease-1> {break}
    bind $cv <Key-Escape>      "[list rdw::pick_end]; break"
    bind $cv <B1-Motion>       {break}
    catch {focus -force $cv}
    return $cv
}

# Arm the mode.  1 when it is armed (or already was), 0 when it could not be.
#
# ⚠ AN ALREADY-LIVE MODE RE-ARMS IN PLACE AND DOES NOT RELEASE AND RETAKE.
# ASE's select_on_design self-serialises by ENDING the previous mode first
# (ase_window.tcl:1879); copying that here would drop the pick every time the
# user pressed a different list key, releasing and retaking the same seize for
# nothing.  ESC is the only exit -- that is what "this is a command mode"
# means, and it is the user's own phrase.
#
# ⚠ THAT ARGUMENT IS RIGHT FOR A LIVE MODE AND WAS WRONG FOR A SUSPENDED ONE.
# ISSUE 1305, MEASURED: a descend suspends the mode (cmdmode::suspend_all ->
# rdw::pick_suspend, which releases the canvas and sets pick(suspended)); the
# user then presses 1-4 during hi_descend_pick_arm's event-loop wait; pick_start
# falls through the guard above -- correctly, the mode is not live -- and seizes
# the canvas again WITHOUT clearing the flag.  The later cmdmode::resume_all
# then calls rdw::pick_resume, which seizes an ALREADY-SEIZED canvas and latches
# the seize's OWN scripts as the predecessors.  ESC restores them.  Measured
# after ESC: P='rdw::pick_click; break' R='break' E='rdw::pick_end; break'
# M='break' -- a PERMANENT seize, unrecoverable inside the session, in which
# every click dumps and nothing can be selected again.  That is the exact
# inverse of the user's ruling that a command mode must not change the selected
# set.
#
# THE FIX is the one cmdmode ruling D6 already describes -- "exactly the first
# one to arrive wins" (cmdmode.tcl:36-42).  pick_start arriving first
# legitimately wins the latch, so clearing the suspend is PART OF TAKING THE
# CANVAS BACK: the later resume finds nothing suspended and pick_resume's own
# guard returns 0.  The unset sits BELOW the canvas guard on purpose -- a re-arm
# that could not take a canvas must leave the suspend intact for the real
# resume -- and it is the same idiom pick_resume uses twelve lines further down,
# and the one ase::ui::sod_resume uses (ase_window.tcl:2047).
#
# COST, STATED: this re-seizes on the canvas CURRENT AT KEY-PRESS TIME, which
# during a descend's wait is still the PARENT.  Because resume_all's
# pick_resume now returns 0, a descend that lands on a DIFFERENT canvas (new
# window, new tab) leaves the mode live on the OLD one and never rehomes it.
# The rejected alternative that preserved the rehome -- have the suspended arm
# return 1 without seizing -- makes a 1-4 press during the wait silently do
# nothing, which contradicts ruling D-2's premise that those keys are always
# live.  The un-rehomed residue is recorded on issue 1307, whose own subject is
# a command-mode seize arriving on a canvas nobody armed it on.
proc rdw::pick_start {} {
    variable pick
    if {![rdw::have_tk]} { return 0 }
    if {[info exists pick(canvas)] && ![info exists pick(suspended)]} { return 1 }
    set cv {}
    catch {set cv [xschem get current_win_path]}
    if {$cv eq {} || ![winfo exists $cv]} { return 0 }
    ## ISSUE 1305: clear the outstanding suspend as part of taking the canvas
    ## back, so resume_all finds nothing to resume.  BELOW the guard above.
    unset -nocomplain pick(suspended)
    rdw::_pick_seize $cv
    rdw::_ciw {Results window: click a device to show its operating-point columns; ESC ends. Clicking does not change the selection.}
    return 1
}

# ONE CLICK.  Coordinates default to the UN-SNAPPED mouse position --
# `xschem get mousex` / `mousey`, scheduler.c:5047 and :5051 -- which is the
# point the cursor is actually on and the pair every C click path reads.
# Defaulting rather than requiring them is what lets a suite drive this proc
# with exact coordinates AND through real events; issue 1303's own acceptance
# is that the DEFAULT path is the one exercised, because that is where the
# defect lived.
#
# ⚠ ISSUE 1303, MEASURED, AND WHY THERE IS NO FALLBACK TO THE GRID PAIR.
# Resolving the click from the grid-snapped position instead names a DIFFERENT
# DEVICE.  On the shipped xschem_library/examples/cmos_inv.sch, one pixel
# apart:
#       175.175 -199.612  ->  M1     the point under the cursor
#       180     -200      ->  R1     that same point snapped to the grid
# Lattice sweep over every instance bbox on that sheet: 23725 points, 1513
# (6.4%) miss the device entirely and 129 (0.5%) resolve to a different device
# -- silently, with nothing on screen saying which happened.  That is invariant
# I3's plausible-wrong-answer failure one object out: a results window headed
# R1 for a click on M1.  So when the un-snapped readers cannot be read this
# proc REFUSES through the one CIW channel and names what it could not read.
# It does NOT fall back to the grid position, because that fallback IS the
# defect, one binary mismatch away.  The grid position remains the right pair
# for PLACING geometry and is used nowhere in this file.
#
# ⚠ AND THE PAIR READ HERE IS THE LAST MOTION'S POINT, NOT THE PRESS'S.  The
# seize `break`s the press before C sees it, and C updates both mouse pairs on
# every event it does see (callback.c:10145).  A real hand always moves the
# pointer onto the device before pressing, so it reads the right point; a
# caller that presses with no preceding motion reads a stale one.  The keys
# suite generates the motion first for exactly this reason.
#
# A MISS IS NOT THE END OF THE COMMAND.  Empty canvas and a wire are the same
# answer here (the reader resolves instances only), and both keep the mode
# live: a mode that ended on a mis-click would be unusable.
proc rdw::pick_click {{x {}} {y {}}} {
    if {$x eq {}} { catch {set x [xschem get mousex]} }
    if {$y eq {}} { catch {set y [xschem get mousey]} }
    if {$x eq {} || $y eq {}} {
        return [rdw::_ciw {Results window: this build cannot report the un-snapped mouse position, so a click cannot be resolved to the device under the cursor - press ESC to leave.}]
    }
    rdw::_refresh_pick_gate
    set inst [rdw::_pick_at $x $y]
    if {[string trim $inst] eq {}} {
        return [rdw::_ciw {Results window: no device under the click - click on a device body, or press ESC to leave.}]
    }
    rdw::show $inst
    return $inst
}

# Hand all FOUR bindings back, verbatim and under catch (the canvas may be
# dead).  ONE proc shared by the end path and the suspend path, exactly as
# ase::ui::sod_release (ase_window.tcl:1948) is, so the two cannot drift --
# which is the whole reason issue 1304's fourth sequence is added here and in
# rdw::_pick_seize and nowhere else.  Row K14 fences the two against each
# other.  Returns 1 only if it released a live mode.
proc rdw::pick_release {} {
    variable pick
    if {![info exists pick(canvas)]} { return 0 }
    set cv $pick(canvas)
    catch {bind $cv <ButtonPress-1>   $pick(prevpress)}
    catch {bind $cv <ButtonRelease-1> $pick(prevrel)}
    catch {bind $cv <Key-Escape>      $pick(prevesc)}
    catch {bind $cv <B1-Motion>       $pick(prevmotion)}
    return 1
}

# Leave the mode.  Safe to call when nothing is live, on every arm.
## Is a pick mode live on some canvas right now?  ⚠ SUSPENDED COUNTS AS
## RUNNING (issue 1308): a mode paused by a descend is still a mode the user
## has to be able to leave, and `pick(canvas)` is what `pick_end` releases.
proc rdw::pick_running {} {
    variable pick
    return [expr {[info exists pick(canvas)] ? 1 : 0}]
}

proc rdw::pick_end {} {
    variable pick
    set r [rdw::pick_release]
    array unset pick
    return $r
}

# ---------------------------------------------------------------------------
# THE SUSPEND/RESUME CONTRACT (src/cmdmode.tcl, issue 0201).  A descend
# mid-mode must pause the seize and put it back on the canvas it LANDS on.
#
# ⚠ THE SUSPEND ARM NOW RUNS ON EVERY DESCEND IN EVERY PROFILE FOREVER, so
# "0 and no damage when there is nothing to release" is a permanent obligation,
# not a convenience.
proc rdw::pick_suspend {} {
    variable pick
    if {![info exists pick(canvas)]} { return 0 }
    if {[info exists pick(suspended)]} { return 0 }
    if {![rdw::pick_release]} { return 0 }
    set pick(suspended) 1
    return 1
}

# ⚠ ALL FOUR PREDECESSORS ARE RE-LATCHED FROM THE CANVAS WE ARE LANDING ON,
# not carried over from the one the mode was seized on: a new window or tab has
# its own binding set (set_bindings + clone_canvas_bindings), and the
# predecessors latched on the parent do not describe it.
# ase::ui::sod_resume (ase_window.tcl:2039-2046) records the same, and it is
# the load-bearing half of ruling D2 of issue 0201.  It re-latches by calling
# rdw::_pick_seize, so the count follows that proc and cannot drift from it.
proc rdw::pick_resume {{canvas {}}} {
    variable pick
    if {![info exists pick(suspended)]} { return 0 }
    if {$canvas eq {} || ![winfo exists $canvas]} {
        set canvas {}
        catch {set canvas $pick(canvas)}
    }
    if {$canvas eq {} || ![winfo exists $canvas]} {
        ## Nowhere left to come back to -- the window was closed while the mode
        ## was paused.  Drop it rather than leave an unreachable record behind.
        array unset pick
        return 0
    }
    unset -nocomplain pick(suspended)
    rdw::_pick_seize $canvas
    return 1
}

# ⚠ AT SOURCE TIME, AND THAT IS SAFE.  cmdmode.tcl is pure Tcl and is sourced
# at xschem.tcl:16760, BEFORE this file at :16790; ase_window.tcl:2055 already
# registers the same way.  Nothing here touches Tk, so --nogui is unaffected --
# and the registration being source-time is what lets the headless arm prove it
# happened at all.
#
# ⚠ BUT IT IS GUARDED, AND NOT FOR TIDINESS.  Row N2 of this file's own suite
# sources rdw.tcl into a BARE `interp create` slave -- an interpreter with
# neither `winfo` nor `xschem` -- as the non-brittle proof that nothing here
# runs at source time.  That slave has no cmdmode either, so an unguarded
# `cmdmode::register` would fail the very row that polices this file's --nogui
# survival.  The guard is therefore a statement about WHERE this file can be
# loaded, not a silent fallback: it returns 0 when the contract is absent, and
# the caller can say so.  Inside xschem the contract is always there, which is
# what the headless arm of row K9 measures.
proc rdw::_register_cmdmode {} {
    if {![llength [info commands ::cmdmode::register]]} { return 0 }
    ::cmdmode::register rdw_pick rdw::pick_suspend rdw::pick_resume
    return 1
}
rdw::_register_cmdmode

# ===========================================================================
# ITEM B5 -- THE BUTTON COLUMN AND THE TWO SCOPE DIALOGS
# ===========================================================================
# Spec 4.2 B7's table, wired.  Rulings DD-2, DD-6, DD-7, DD-8, DD-9 and DD-10.
#
#   button        annotation (1)   summary (2)      all (3)
#   Up / Down     reorder          reorder          reorder
#   Delete        remove           remove           GREYED
#   Add           GREYED           add to list 1    the dialog asks which
#   Save          write the settings file, all three
#
# Every Delete and every Add first raises a SCOPE DIALOG -- this device flavor
# only, versus every device of this broad class.  Narrow writes a `flavor`
# entry keyed on the cell name; broad writes the `class` entry, which ruling
# DD-2 makes the primary key.
#
# ⚠ WHERE THE NARROWING IS DEFINED, AND WHERE IT IS NOT.  This file computes
# no list of its own.  `op_param_lists::effective` is the ONE definition of
# "the annotation list for this device" (flavor in file order, then the class
# entry, then the PDK seed), and every list this column reads or writes comes
# from it.  Re-deriving one here from op_annot::descriptor is issue 1300's
# rejected option (a) and invariant I1's exact failure shape.
#
# ⚠ AND THE KEYS STILL NARROW NOTHING.  Item B4's 1/2/3 select a list
# IDENTITY; that is unchanged and issue 1300 stays the user's question.  What
# B5 adds is the first CALLER of the store's editing path, which is why rows
# S1 and K11 handed their `op_param_lists:: == 0` term to row BT22.
#
# ---------------------------------------------------------------------------
# THE THREE THINGS THE COLUMN NEEDED AND B3 DID NOT HAVE
# ---------------------------------------------------------------------------
# 1. A TARGET.  nhse's own rule (xschem.tcl:1314) -- "the row your cursor is
#    in" -- with no new focusable widget, because a focusable widget in this
#    column is issue 1308's stuck state (Tk buttons do not take focus on X and
#    that is the only reason the keyboard goes back to the canvas).  MEASURED
#    on :99: a `-state disabled` text still moves `insert` on a real Button-1,
#    so a plain click was enough to aim the buttons from the day they landed.
#    ⚠ AND FOR THREE ITEMS IT AIMED THEM INVISIBLY.  A disabled text draws no
#    insertion cursor, so the user clicked, watched a new dump arrive and was
#    told the line they could plainly see was not a parameter row (issue
#    1324).  ITEM R1 (issue 1337) SHADES THAT ROW: `::rdw::targetrow` is the
#    cursor, `rdw::set_row` its one setter, `rdw::_paint_cursor` its one
#    painter, and `rdw::pane_click` the binding that moves it.
#
# 2. A SUBJECT.  `rdw::push` RECORDS what a block was about at DUMP TIME
#    (issue 1322, item B5-a) -- instance, `type=` token, cell and sheet -- and
#    `rdw::block_subject` reads it back out of the block itself.  This section
#    derives nothing from the live editor: the earlier attempt split the
#    header back into a bare name and re-resolved it, which answers about
#    whatever sheet is open NOW and is the defect that reverted item B5-2.  A
#    window-global "last device dumped" would be wrong the same way, one block
#    over: it would edit a different device's list than the block the cursor
#    is sitting in, with nothing on screen saying so.
#
# 3. A ROW NAME.  ⚠ THE PANE PRINTS THE RAW PARAMETER, NOT THE LABEL.  IHP's
#    first triple is `{id ids 0}` and the block line is `    ids : 1.2e-05`, so
#    every lookup into a list is BY THE PARAM FIELD.  Matching by label
#    round-trips sky130 and gf180 perfectly and silently misses IHP -- the one
#    PDK in this tree that distinguishes them.
#
# ---------------------------------------------------------------------------
# WHY THE DIALOG IS A CHILD TOPLEVEL WITH A BUILD/DONE/WRAPPER SPLIT
# ---------------------------------------------------------------------------
# ⚠ ISSUE 0803: a modal a suite cannot click does not FAIL, it HANGS, and takes
# the audit with it.  So the shape is `ase::ui::bus_dialog`'s
# (ase_window.tcl:1320/1392/1406), copied deliberately:
#   * `scope_dialog_build` builds and returns the window and touches no event
#     loop, so the widget tree is inspectable with no `tkwait` anywhere;
#   * `scope_dialog_done` sets the result and destroys, so a test can invoke a
#     radiobutton and the OK button from an `after` timer;
#   * `scope_dialog` is the thin wrapper, and its `tkwait` is GUARDED -- the
#     build-time `update` can let a timer destroy the window first;
#   * with NO Tk at all it answers Cancel and RETURNS.  A dialog that is only
#     safe when a display is present is not safe.
# MEASURED while planning: `.rdw.scope`'s bindtags are {.rdw.scope Toplevel
# all}, so a child toplevel does NOT inherit `.rdw`'s ruling DD-12 Escape and
# can bind its own Cancel with no collision -- a dialog that inherited it would
# silently end the canvas command mode the user is in the middle of.
#
# ⚠ AND IT REFUSES TO OPEN WHILE A CANVAS PICK MODE IS LIVE.  MEASURED: `grab
# set .rdw.scope` really does take `grab current`, so a modal opened over a
# live verb-noun pick swallows the canvas click the mode is waiting for and the
# mode looks dead.  Adjacent to issue 1309 without being it: this item adds no
# key and calls no `pick_start`.
#
# ---------------------------------------------------------------------------
# WHAT A SUCCESSFUL EDIT DOES *AFTER* THE STORE, AND THE ONE EXCEPTION
# ---------------------------------------------------------------------------
# Delete and Add call `op_param_lists::apply` -- once with the subject's own
# `type=` token, because a token the class map does not name is unreachable
# from the bare call (issue 1279), and once bare, because the class's mapped
# SIBLINGS must follow: `apply nmos` alone leaves every pmos on the sheet
# drawing the old list.  Ruling DD-6 then writes the UNION into `params` (what
# the run computes, so `_cards_for` keeps emitting the card) and the annotation
# list into the display key (what the sheet draws).  Delete is a DISPLAY
# decision and never a SAVE decision.
#
# ⚠ A REORDER APPLIES TOO, AND THAT REVERSES THE PRESERVED PATCH ON PURPOSE
# (item B5-2).  The patch deferred it and said so on screen, because
# `op_param_lists::_save_set` builds the union ANNOTATION-FIRST, `apply` writes
# it into the descriptor's `params`, and `op_param_lists::seed` read that same
# field back as "the PDK's own list" -- so reordering list 1 silently reordered
# list 2's answer, which nobody owns.  Ruling DD-13 (item B2e) split the
# descriptor into THREE lists: `seed` now reads the DECLARATION, which nothing
# but `op_annot::register` can write, and `_show_set` filters the union
# annotation-first into the display key.  The leak is structurally gone -- issue
# 1312 is FIXED, store row N4 fences the opposite -- so a status line citing it
# as a reason to defer would be a false statement on a screen the user is
# reading.  Up and Down redraw like Delete and Add.
#
# Suite: tests/headless/test_rdw_window_1245.tcl section BT (both arms),
# tests/headless/test_op_param_store_1245.tcl section BE (the file half) and
# tests/headless/test_rdw_keys_1245.tcl section SD (the real modal, :99).

namespace eval rdw {
    # The target row, as a 1-BASED PANE LINE, and 0 for "no row".  IT IS THE
    # CURSOR -- the one item R1 (issue 1337) made visible, not a headless
    # shadow of a second one.  `rdw::set_row` is its only setter and moves the
    # variable, the pane's `insert` mark and the `cursor` shading together;
    # `rdw::_target_line` reads it back.  A cursor with a variable of its own
    # would let Delete edit a line the user is not looking at while every row
    # of this feature's suite still passed.
    variable targetrow
    if {![info exists targetrow]} { set targetrow 0 }

    # The scope dialog's three variables.  Namespace state rather than
    # proc-locals because the build, the radiobuttons and the wrapper are three
    # different scopes; `scope_result` is pre-set to Cancel BEFORE the build,
    # so a window that never reaches `scope_dialog_done` -- a deadman timer, a
    # window-manager close -- answers Cancel rather than the previous answer.
    variable scope_result {}
    variable scope_choice broad
    variable list_choice annotation
}

# ---------------------------------------------------------------------------
# THE TARGET.  Pure enough to drive with no Tk at all, which is where the
# majority of this feature's suite lives.

# THE ONE TARGET SETTER.  `n` is a 1-based pane line; 0 is "no row".
# It moves the SHADING too (item R1, issue 1337), because the target and the
# thing the user sees are one cursor -- see rdw::_paint_cursor.
proc rdw::set_row {n} {
    variable targetrow
    if {![string is integer -strict $n]} { return $targetrow }
    if {$n < 0} { set n 0 }
    set targetrow $n
    rdw::_paint_cursor
    return $n
}

# The cursored line, or 0 when no row is cursored.
#
# ⚠ IT NO LONGER READS THE PANE'S `insert` MARK, AND THE COMMENT THAT USED TO
# STAND HERE ARGUED THE OPPOSITE (item R1, issue 1337).  "The pane WINS when it
# exists" was right while the target was INVISIBLE: a real click moved `insert`
# and nothing else, so the widget was the only place the user's click was
# recorded.  Now the click goes through `rdw::pane_click` -> `rdw::set_row`,
# which moves the variable, the mark and the shading together, and reading the
# mark back would be a second opinion about the same thing -- one that can
# never say "no row", because an `insert` mark ALWAYS has a line.  That is the
# whole difficulty: DD-1 requires the window to answer "there is no cursor"
# after a new dump, and issue 1324 measured the mark drifting to line 9 on its
# own while this variable still said 3.  The variable is the answer; the
# widget follows it.
proc rdw::_target_line {} {
    variable targetrow
    if {![info exists targetrow]} { return 0 }
    return $targetrow
}

# A flat pane line -> {blockindex entryindex}, or {} past either end.  PURE: a
# function of ::rdw::blocks alone, because rdw::render_pane paints one entry
# per line in store order and nothing else.
proc rdw::_locate {line} {
    variable blocks
    if {![string is integer -strict $line]} { return {} }
    if {$line < 1} { return {} }
    set n 0
    set bi 0
    foreach b $blocks {
        set len 0
        catch {set len [llength $b]}
        if {$line <= $n + $len} { return [list $bi [expr {$line - $n - 1}]] }
        incr n $len
        incr bi
    }
    return {}
}

# The RAW parameter name of one block entry, or {} when the entry is not a
# parameter row.  A tagged entry (hdr / dim / dev / note) never is, and neither
# is the separator; what is left is `rdw::format_answer`'s own
# "    %-*s : %s" row, whose first field is the parameter the seam published.
proc rdw::_row_param {entry} {
    if {[catch {llength $entry} n]} { return {} }
    if {$n != 2} { return {} }
    if {[lindex $entry 0] ne {}} { return {} }
    set t [lindex $entry 1]
    if {[string trim $t] eq {}} { return {} }
    if {![regexp {^[ ]+(\S+)[ ]+:} $t -> p]} { return {} }
    return $p
}

# ---------------------------------------------------------------------------
# THE SUBJECT.

# ⚠ `rdw::_hdr_instname` IS NOT DEFINED HERE ANY MORE, AND ITS ABSENCE IS THE
# FIX (issue 1322, item B5-a).  It used to be defined twice -- once at the top
# of this file and once in this section -- and the LAST definition silently
# won.  It now has exactly one home, beside `rdw::header`, whose join it
# inverts; `rdw::push` is its other caller.
#
# {instname type class cellname schname} for the block the cursor is in, or {}.
# ⚠ THE BLOCK INDEX IS AN ARGUMENT AND NOT `[lindex $blocks 0]`.  The newest
# dump is on top and the user's cursor is very often in an OLDER one; a subject
# read from the newest block would edit a different device's list than the
# block on screen, and every single-block row ever written would still pass.
#
# ⚠ AND IT RE-RESOLVES NOTHING (issue 1322, item B5-a).  THIS PROC IS THE
# DEFECT THAT REVERTED ITEM B5-2.  It used to split the block's header back
# into a bare instance NAME and ask the LIVE EDITOR what that name meant --
# which answers about whatever sheet is open now, not about the sheet the block
# was dumped from.  MEASURED with two top-level sheets each holding an `M1`,
# which is the default template name of every device symbol in this tree:
#     the block on screen was about   ncls / vn.sym
#     this proc answered              type vpdev class pcls cellname vp.sym
#     Delete's verdict                ok, and it edited pcls
# ⚠ COMPARING THE HEADER'S PATH HALF DOES NOT CATCH IT and no reviewer should
# spend a pass rediscovering that: both sheets are top-level, so both headers
# are byte-identical.  THE AXIS IS SHEET IDENTITY, NOT HIERARCHY PATH.
# `rdw::push` now records the subject AT DUMP TIME and `rdw::block_subject`
# reads it back, so this proc reads a RECORD and asks the editor nothing.
#
# The CLASS is still resolved here, and only here: `op_param_lists::class` is
# a pure classmap lookup with no sheet dependence, so it has one home already
# (invariant I1) and is the one field that is still true whenever it is asked.
# A block whose device could not be resolved at dump time -- a symbol xschem
# could not find, an instance that had already gone -- carries no subject at
# all, and `{}` here is what makes rdw::button's existing guard fire with no
# new sentence.
proc rdw::_subject {blockindex} {
    variable blocks
    set subj [rdw::block_subject [lindex $blocks $blockindex]]
    if {$subj eq {}} { return {} }
    set type {}
    catch {set type [dict get $subj type]}
    if {$type eq {}} { return {} }
    set cls {}
    catch {set cls [::op_param_lists::class $type]}
    set inst {} ; set cell {} ; set sch {}
    catch {set inst [dict get $subj instname]}
    catch {set cell [dict get $subj cellname]}
    catch {set sch  [dict get $subj schname]}
    return [dict create instname $inst type $type class $cls cellname $cell \
                        schname $sch]
}

# ---------------------------------------------------------------------------
# THE WINDOW FOLLOWS THE STORE (item R2, issue 1338).
#
# The user's words: "Promote/demote using Up/Down arrow should be reflected in
# the Results Display Window as well as the schematic annotation."  The sheet
# half already worked -- `rdw::_apply_now` rewrites the descriptors and
# redraws, MEASURED at HEAD 27122ca4 as a `xschem get annot_overlay_flushes`
# of +1 per accepted press -- and the WINDOW half is what was missing: the
# store moved, `::rdw::blocks` came back byte-identical, and the pane kept
# showing the order the user had just changed until they pressed 1 or 2 again.
#
# ⚠ THE PANE'S ROW ORDER IS NOT THE LIST'S ROW ORDER, so "swap the two adjacent
# display lines" is the obvious implementation and it is WRONG.
# `rdw::format_answer` emits, per primitive, the `devices` pairs FIRST, then
# the `nonfinite` ones, then the `absent` ones.  So a list holding
# {id ids 0} {gm gm 1} {gds gds 1} whose `gm` came back non-finite renders as
#       ids : 1.2e-05      gds : 5.6e-06      gm  : (did not converge)
# and an Up on `gds` swaps LIST entries 2 and 1 while leaving the DISPLAY
# exactly as it was.  MEASURED on the IHP-shaped seed row RE0 builds -- label
# != param, which is a shipped PDK shape and not a synthetic one.  A blind
# display swap would put `gds` above `ids` and the window would then be showing
# an order the store does not hold, which is the one thing this item exists to
# prevent.
#
# So a block is RE-SLOTTED, never swapped: the rows the list DECLARES are
# re-filled, in the list's order, into the slots those declared rows already
# occupied, and every other row keeps its own slot.

# The RAW param names the store's list holds for this class and cell, in store
# order, deduped.
#
# ⚠ `::op_param_lists::effective` IS THE ORDER AND NOTHING HERE RE-DERIVES ONE.
# A second opinion about what the sheet draws is invariant I1's two-builders
# drift, and this window's whole promise in R2 is that the two agree.
#
# ⚠ THE CELL IS PASSED, so each block is re-slotted into the order that governs
# IT.  A device-flavor entry legitimately governs one block and not another
# (`rdw::_scope_for` asks exactly this question before the write), so a block
# the flavor entry does not match must keep the class order it is actually
# drawn in.  With no flavor entry in the settings file -- the ordinary case --
# `effective` falls through to the class entry and then to the PDK seed, so the
# extra argument changes nothing at all.
#
# Deduped because `order` is used as a fill sequence below: a list carrying two
# triples with the same RAW param would otherwise place that row twice and drop
# another.  (`op_annot::register` refuses two triples sharing a LABEL as of
# ruling DD-15, but nothing refuses two sharing a param.)
proc rdw::_list_params {cls listname cell} {
    set l {}
    catch {set l [::op_param_lists::effective $cls $listname $cell]}
    set out {}
    foreach t $l {
        set p {}
        if {[catch {lindex $t 1} p]} { continue }
        if {$p eq {}} { continue }
        if {[lsearch -exact $out $p] >= 0} { continue }
        lappend out $p
    }
    return $out
}

# Re-fill one block's declared parameter rows into `order`.  Returns
# {newblock map}, where `map` is a dict from the entry index a row HAD to the
# entry index it now HAS -- the cursor is moved with it, so a second press
# moves the same parameter again instead of whatever slid under the old line
# number.  That is ruling DD-1's own argument, one item later.
#
# ⚠ A MAXIMAL RUN OF PARAMETER ROWS IS ONE PRIMITIVE, AND THAT IS WHAT KEEPS A
# NUMBER UNDER THE DEVICE THAT PUBLISHED IT (ruling D-3).  One XR1 resolves to
# several primitives; `rdw::format_answer` emits a "  <rawdev>" sub-header and
# then that primitive's rows, contiguously, so a permutation confined to one
# run can never cross a sub-header.  An implementation that collected the
# block's parameter rows and re-laid them all in list order moves a value under
# a device that never published it -- a plausible wrong NUMBER in the block a
# designer pastes into a review document, which is invariant I3 exactly.
# Row RE4 is the fence.
#
# ⚠ AND A ROW NO LIST DECLARES KEEPS ITS OWN SLOT.  The `absent` bucket renders
# after the computed pairs, so a parameter the run published and no list
# declares can sit BETWEEN two rows that a list does declare.  Permuting every
# row of the run would move it; the button column already refuses to reorder it
# by name (row BT6), and somebody else's reorder must not do it either.
#
# The block's FIRST entry carries the subject stamp as a third element (issue
# 1322, `rdw::push`), and it is never a parameter row, so it is never rewritten
# here -- row RE1's last leg is the fence on that.
proc rdw::_reslot_block {block order} {
    set map [dict create]
    set n 0
    if {[catch {llength $block} n]} { return [list $block $map] }
    set out $block
    set i 0
    while {$i < $n} {
        if {[rdw::_row_param [lindex $block $i]] eq {}} { incr i ; continue }
        set j $i
        while {$j < $n && [rdw::_row_param [lindex $block $j]] ne {}} { incr j }
        ## [$i, $j-1] is one primitive's rows.
        set slots {}
        for {set k $i} {$k < $j} {incr k} {
            if {[lsearch -exact $order \
                    [rdw::_row_param [lindex $block $k]]] < 0} { continue }
            lappend slots $k
        }
        ## The declared rows of this run, in the LIST's order.  Walked
        ## list-first rather than sorted by rank so that the result does not
        ## depend on `lsort`'s stability, and so two rows of one run spelled
        ## the same way keep their run order.
        set filled {}
        foreach p $order {
            foreach k $slots {
                if {[rdw::_row_param [lindex $block $k]] eq $p} {
                    lappend filled $k
                }
            }
        }
        ## A re-slot is a PERMUTATION: same rows, same slots.  If the two
        ## disagree the block is left exactly as it was rather than half
        ## rewritten -- the least-destructive reading, and the same one
        ## `rdw::pane_click` takes for a refused click.
        if {[llength $filled] == [llength $slots]} {
            set x 0
            foreach k $slots {
                set src [lindex $filled $x]
                lset out $k [lindex $block $src]
                dict set map $src $k
                incr x
            }
        }
        set i $j
    }
    return [list $out $map]
}

# Re-slot EVERY stored block that draws the list just edited, and answer the
# pane line the cursor should move to.  `loc` is the {blockindex entryindex}
# the cursor was at and `line` its flat pane line.
#
# ⚠ EVERY BLOCK OF THE CLASS, NOT JUST THE ONE THE CURSOR IS IN.  The store is
# class-wide, so a window that reordered only the cursored block would show the
# SAME class list in two different orders at once -- a statement the store
# cannot support, and one the user would have to reconcile by hand.  This is an
# E question neither DD-3 nor DD-4 answers; it is on the owed ledger as rule
# debt 1338_R2_every_block_of_the_class_follows for the user to overrule, and
# row RE5 is what an overrule would delete.
#
# ⚠ A BLOCK WITH NO SUBJECT IS NOT TOUCHED, and neither is one of another
# class.  A block whose device could not be resolved at dump time carries no
# subject at all (`rdw::_capture_subject` refuses), so nothing says which of
# its rows the edited list declares; a block of a different class carries a
# list nobody edited.  Row RE5's other two blocks are spelled in the order a
# class-wide reorder WOULD produce, so "left alone" and "reordered" are
# distinguishable on them.
proc rdw::_reorder_shown {cls listname loc line} {
    variable blocks
    set out {}
    set bi 0
    set newline $line
    foreach b $blocks {
        set s [rdw::_subject $bi]
        set c {}
        catch {set c [dict get $s class]}
        if {$s eq {} || $c eq {} || $c ne $cls} {
            lappend out $b ; incr bi ; continue
        }
        set cell {}
        catch {set cell [dict get $s cellname]}
        set ord [rdw::_list_params $cls $listname $cell]
        if {[llength $ord] == 0} { lappend out $b ; incr bi ; continue }
        lassign [rdw::_reslot_block $b $ord] nb map
        lappend out $nb
        if {[llength $loc] == 2 && [lindex $loc 0] == $bi} {
            set ei [lindex $loc 1]
            ## A re-slot is length-preserving and confined to ONE block, so
            ## every line above this block is unchanged and the flat pane line
            ## moves by exactly the entry-index delta.  That also means
            ## `rdw::render_pane`'s stale-target sweep (item R1) cannot fire on
            ## a reorder: `rdw::_locate` still resolves the same line count.
            if {[dict exists $map $ei]} {
                set newline [expr {$line + [dict get $map $ei] - $ei}]
            }
        }
        incr bi
    }
    set blocks $out
    return $newline
}

# ---------------------------------------------------------------------------
# THE LIST HELPERS.  Every one of them reads a list the STORE handed over;
# none builds one.

# The index of a triple by its RAW PARAM field, never by its label.
proc rdw::_index_of {lst param} {
    if {[catch {llength $lst}]} { return -1 }
    set i 0
    foreach t $lst {
        if {[catch {lindex $t 1} p]} { return -1 }
        if {$p eq $param} { return $i }
        incr i
    }
    return -1
}

proc rdw::_triple_in {lst param} {
    set i [rdw::_index_of $lst $param]
    if {$i < 0} { return {} }
    return [lindex $lst $i]
}

# ⚠ ADD MINTS NO `kind`, EVER (invariant I1, measured rule R3).  The kind is
# the raw-name SHAPE -- 0 is i(<dev>[p]), 1 is bare, 2 is v(<dev>[p]) -- so a
# guessed one writes a `.save` card that matches nothing, and one bogus card
# destroys the whole operating point.  A parameter with no declared triple
# anywhere is refused by name instead.
proc rdw::_find_triple {cls cell param} {
    foreach ln {annotation summary} {
        set t [rdw::_triple_in [::op_param_lists::effective $cls $ln $cell] $param]
        if {$t ne {}} { return $t }
    }
    return [rdw::_triple_in [::op_param_lists::seed $cls] $param]
}

# The STORE KEY a REORDER writes at: the flavor entry that actually GOVERNS
# this device, else the class entry, which ruling DD-2 makes the primary key.
# Up and Down raise NO dialog -- spec 4.2 B7 gives it to Delete and Add only,
# and a dialog per click makes reordering unusable -- so they have no answer to
# obey and must find the entry themselves.
#
# ⚠ IT ASKS `op_param_lists::governs`, AND THE QUESTION IT USED TO ASK WAS A
# DIFFERENT ONE (item B5-2, defect A6).  This proc used to ask exact-key
# `owns flavor {<cls> <cellname>}` while every READ of the same list goes
# through `effective`, which matches a cell-name GLOB.  MEASURED at HEAD with a
# flavor entry `{b5cls *b5n*}` governing cell `devices/b5n`:
#     effective b5cls annotation devices/b5n     -> the FLAVOR list
#     owns flavor {b5cls devices/b5n} annotation -> 0
# so the reorder answered "no flavor entry", wrote the CLASS entry, and left
# the user looking at a pane whose order did not move while the status line
# said it had.  ONE narrowing with TWO lookalike definitions is invariant I1's
# exact failure shape, so the scan now has one home in the store and this file
# is a consumer of it.  Fenced by window row BT25 and store rows BG1/BG2.
proc rdw::_scope_for {cls listname cell} {
    set g {}
    catch {set g [::op_param_lists::governs $cls $listname $cell]}
    if {[llength $g] == 2 && [lindex $g 0] eq {flavor}} {
        return [list flavor [lindex $g 1]]
    }
    return [list class $cls]
}

# ---------------------------------------------------------------------------
# DID THE WRITE ACTUALLY REACH THE DEVICE THE USER IS LOOKING AT?
#
# ⚠ ONE CHECK, THREE ARMS, THREE SENTENCES (item B5-2, defect A6's second
# half).  The preserved patch ran ruling DD-8's shadow warning on the NARROW
# arm only, so a BROAD write over a device a flavor glob governs reported a
# bare success about rows that did not move -- the user presses Delete, the
# class list really does change, and the row stays on the sheet with nothing
# said.  The comparison is `get_list` of the key just written against
# `effective` for this cell, NOT against the list we asked for: the store
# legitimately reduces a list by label (issue 1288), and comparing against the
# request would fire this warning on a write that landed perfectly.
#
# ⚠ AND THE BROAD BASE IS STILL THE CLASS LIST.  Taking the base from
# `effective $cls $listname $cell` -- which is the obvious way to give the
# broad arm the cell -- would write the FLAVOR list's rows into the CLASS key
# and destroy every class row the flavor entry does not carry.  That is ruling
# DD-7's failure, the one that reverted item B2a twice.  So the cell reaches
# the broad arm HERE, after the write, and never as its base.
proc rdw::_shadow_why {scope cls listname cell skey key} {
    if {$cell eq {}} { return {} }
    set now {}
    set mine {}
    catch {set now  [::op_param_lists::effective $cls $listname $cell]}
    catch {set mine [::op_param_lists::get_list $skey $key $listname]}
    if {$now eq $mine} { return {} }
    set glob {}
    set g {}
    catch {set g [::op_param_lists::governs $cls $listname $cell]}
    if {[llength $g] == 2 && [lindex $g 0] eq {flavor}} {
        set glob [lindex [lindex $g 1] 1]
    }
    set which [expr {$glob eq {} ? {an entry} : "the device-flavor entry $glob"}]
    if {$scope eq {broad}} {
        return "The $cls class list moved, but $which in the settings file also matches this cell and wins for it, so this device's own rows did not change - precedence is file order."
    }
    if {$scope eq {narrow}} {
        # RULING DD-8: PRECEDENCE IS FILE ORDER AND NOTHING IS RANKED.  A
        # narrow write is a NEW row, so an entry declared EARLIER whose glob
        # also matches this cell still wins -- and the honest answer is to say
        # which order to fix, not to let the button look dead.  Filed as issue
        # 1311: the pane shows parameter rows, not flavor entries, so this
        # window's own Up/Down cannot reorder the entries whose precedence
        # this is.
        return "But $which declared earlier in the settings file also matches this cell and still wins - precedence is file order, so move this entry above it."
    }
    return "But $which in the settings file wins for this cell - precedence is file order, so move this entry above it."
}

# RULING DD-10, AND IT IS THE USER'S OWN SENTENCE.  Both alternatives the
# question offered are bad: an emptied annotation list makes the whole OP block
# vanish, which drops the device out of the declutter (ruling D-6 gates on
# "instances that got OP numbers"), so every W/L and pin label the declutter was
# hiding comes back at once -- the user pressed Delete to see less and got more;
# and treating an empty list as "no narrowing" makes Delete a silent no-op.
#
# ⚠ IT APPLIES TO BOTH LISTS, WITH TWO DIFFERENT SENTENCES.  The ruling's text
# is unqualified so the refusal is unqualified, but its ARGUMENT is
# annotation-specific -- an emptied summary list breaks no declutter -- so one
# sentence for both would be false about the summary case, and this feature's
# own obligation is that different facts get different sentences.
proc rdw::_last_row_why {base listname param} {
    if {[catch {llength $base} n]} { return {} }
    if {$n > 1} { return {} }
    if {$listname eq {annotation}} {
        return {at least one parameter must stay. To stop showing operating-point values on this device, turn the annotation off instead.}
    }
    return "$param is the only row left in the summary list, and at least one parameter must stay. Add another before removing this one."
}

# What the STORE said about the call just made, or a fallback.  Read as the
# TAIL of `said` rather than the whole of it, so a report from earlier in the
# session is not repeated and a `said_clear` from anywhere destroys nothing.
# ⚠ THE STORE'S OWN WORDING, NEVER A SECOND ONE FOR THE SAME FACT: two
# wordings for one failure is how a user learns to distrust both.
proc rdw::_store_tail {before fallback} {
    set tail {}
    catch {set tail [lrange [::op_param_lists::said] $before end]}
    if {[llength $tail]} { return [join $tail { }] }
    return $fallback
}

# RULING DD-16 -- THE SOURCE SHEET, NAMED ONLY WHEN IT IS NOT THE OPEN ONE.
#
# A block carries the sheet it was dumped from (item B5-a, issue 1322:
# `rdw::_capture_subject` stamps `schname` at DUMP time and `rdw::block_subject`
# reads it back).  The user can therefore edit, an hour later and on a different
# sheet, a block dumped from a device that is no longer on screen.
#
# ⚠ THE EDIT IS NOT REFUSED, AND THAT IS THE RULING'S OWN ARGUMENT.  The three
# lists are CLASS- and FLAVOR-level settings, not sheet state -- a block says
# "this dump was about an nfet of class mos", and editing the mos list is a
# global action that is correct regardless of which sheet happens to be in
# front.  The window deliberately keeps its dumps across a close (`rdw::close`'s
# own comment) precisely so they can be worked with later, so refusing here
# would block a legitimate edit for a reason the user would find arbitrary.
#
# ⚠ AND THE SENTENCE IS CONDITIONAL, NOT UNCONDITIONAL.  In the common case the
# source sheet IS the open one, and saying so is noise on every press.  The
# clause earns its place exactly when the two differ -- which is the case a user
# could otherwise misread, and which, before issue 1322 was fixed, silently
# edited the wrong device.
#
# ⚠ AN ABSENT OR EMPTY `schname` MEANS DO NOT NAME THE SHEET.  A block whose
# device could not be resolved at dump time is never stamped (`_capture_subject`
# refuses {} and `missing`), and a hand-built subject dict -- which is what the
# suites' own fixtures pass -- carries no `schname` key at all.  MEASURED:
# `dict get` on such a dict RAISES, so an unguarded read here would raise from
# inside the decision core and refuse an edit that was working.  Invariant I3's
# spirit one layer out: a missing datum renders blank, never a wrong assertion.
#
# ⚠ THE COMPARISON IS A PLAIN STRING COMPARE.  NOT `file normalize`: issue
# 1327 established it does not resolve a path's final component, so it
# establishes no file identity anyway, and it puts a filesystem call in a status
# path.  NOT `op_param_lists::_fid`: that is a PRIVATE store verb and row BT22
# golds that this file names no private one.  Both values come from the same
# `xschem get schname` accessor, which is why no existing row moves.
#
# ⚠ AND A STRING COMPARE IS NOT FILE IDENTITY -- ISSUE 1329.  An earlier draft
# of this comment claimed the two values "are byte-identical whenever they name
# the same sheet -- measured directly".  THAT IS FALSE, and item B5-3's
# adversary measured the counter-example: one sheet opened through a SYMLINK
# yields two different strings, so this proc emits the clause for a sheet that
# IS the open one.  The choice stands because both alternatives above are worse
# from THIS file; the fix is a PUBLIC `op_param_lists::same_file` wrapping
# `_fid`, added to BT22's allow-list.  Blast radius is one wrong advisory
# sentence and never a wrong write -- DD-16 rules the cross-sheet edit ALLOWED,
# so this clause is advice, not a gate.
#
# A named callee rather than three lines inline, following `rdw::_tier_note`
# just below and for the same reason: a reviewer can neutralise exactly this
# sentence and watch one row say so.
proc rdw::_sheet_note {subject} {
    set src {}
    catch {set src [dict get $subject schname]}
    if {$src eq {}} { return {} }
    set now {}
    catch {set now [xschem get schname]}
    if {$now eq {}} { return {} }
    if {$src eq $now} { return {} }
    return "That dump was taken on $src, which is not the sheet now open - these are class and device-flavor settings, not sheet state, so the edit applies wherever you are standing."
}

# ---------------------------------------------------------------------------
# THE DECISION CORE.  It performs the store call and returns
# {ok|refused <sentence>}, and it touches no Tk -- so every sentence and every
# refusal in this feature is asserted on the --nogui arm.  Copied in shape from
# `nhse_save_announce` (xschem.tcl:1409), which factors the branch and the
# exact sentence out of the widget call for the same reason.
proc rdw::_edit {op subject listname scope param} {
    set cls  [dict get $subject class]
    set cell [dict get $subject cellname]
    if {$scope eq {governing}} {
        # UP AND DOWN, WHICH RAISE NO DIALOG AND SO HAVE NO ANSWER TO OBEY.
        # They write at whatever entry governs this device today, because a
        # reorder whose only effect is invisible is a broken button.
        set g    [rdw::_scope_for $cls $listname $cell]
        set skey [lindex $g 0]
        set key  [lindex $g 1]
        if {$skey eq {flavor}} {
            set base  [::op_param_lists::effective $cls $listname $cell]
            set where "for cells matching [lindex $key 1] of class $cls"
        } else {
            set base  [::op_param_lists::effective $cls $listname]
            set where "for class $cls"
        }
    } elseif {$scope eq {narrow}} {
        if {$cell eq {}} {
            return [list refused "this device's symbol has no cell name, so there is no device-flavor entry to write. Choose every device of class $cls instead."]
        }
        ## ⚠ A NARROW KEY IS A GLOB, AND NOT EVERY CELL NAME IS A GLOB THAT
        ## MATCHES ITSELF (item B5-2).  The flavor key is stored verbatim and
        ## later matched with `string match -nocase`, so MEASURED: `a[bc].sym`
        ## and `a\b.sym` do NOT match themselves.  Written anyway, the entry
        ## would answer nothing for the very device it was minted for -- and
        ## `rdw::_shadow_why` would then fire ruling DD-8's sentence, blaming
        ## "an entry declared earlier in the settings file" that does not
        ## exist.  One wrong sentence produced by the code written to remove
        ## another.  Refuse up front, name the class-wide alternative, and
        ## store nothing.  `a*b.sym` and `a?b.sym` DO self-match but also match
        ## siblings; that residual is filed as issue 1321, not fixed here --
        ## this guard cannot tell a deliberate glob from a literal, and
        ## refusing every cell name containing `*` would refuse a legal
        ## filename for a case nobody has hit.
        if {![string match -nocase $cell $cell]} {
            return [list refused "the cell name $cell contains glob characters, and a device-flavor entry is matched as a glob - a key written from it would never match this device again. Choose every device of class $cls instead."]
        }
        set skey  flavor
        set key   [list $cls $cell]
        set base  [::op_param_lists::effective $cls $listname $cell]
        set where "for cell $cell only"
    } else {
        set skey  class
        set key   $cls
        set base  [::op_param_lists::effective $cls $listname]
        set where "for class $cls"
    }
    set i [rdw::_index_of $base $param]
    set notin "$param is not in the $cls $listname list. The pane also shows rows this run published that no list declares, and only the list's own rows can be edited here."
    ## ⚠ AND ON THE BROAD ARM IT IS NOT ALWAYS TRUE.  The broad base is the
    ## CLASS list, which for a device a flavor entry governs is NOT the list
    ## the pane's rows came from -- so a row the user can plainly see would be
    ## reported "not in the list".  Name the flavor entry and the narrow choice
    ## instead: the fact is different, so the sentence is different.
    if {$i < 0 && $scope eq {broad} && $cell ne {}} {
        set seen {}
        catch {set seen [::op_param_lists::effective $cls $listname $cell]}
        if {[rdw::_index_of $seen $param] >= 0} {
            set notin "$param is in this device's own $listname list but not in the $cls class list, so a class-wide change cannot reach it. Choose this device flavor only instead."
        }
    }
    switch -exact -- $op {
        up -
        down {
            if {$i < 0} { return [list refused $notin] }
            if {$op eq {up} && $i == 0} {
                return [list refused "$param is already the first row of the $cls $listname list."]
            }
            if {$op eq {down} && $i == [expr {[llength $base] - 1}]} {
                return [list refused "$param is already the last row of the $cls $listname list."]
            }
            set j [expr {$op eq {up} ? $i - 1 : $i + 1}]
            set new [lreplace $base $i $i [lindex $base $j]]
            set new [lreplace $new $j $j [lindex $base $i]]
            ## ⚠ A REORDER MUST NOT BECOME A DELETION (issue 1323, rulings
            ## DD-4 and DD-6).  `op_annot::register` accepts a declaration
            ## carrying two triples that share a LABEL; `seed` returns it
            ## undeduped and `effective` hands it out as the base above -- but
            ## `set_list` keeps ONE entry per label, so the list comes back
            ## SHORTER than it went in and `op_annot::_cards_for` stops
            ## emitting a `.save` card the deck was asking for.  MEASURED at
            ## HEAD with no button code at all: an UP press turned
            ##     {id ids 0} {id vgs 2} {gm gm 1}  into  {id ids 0} {gm gm 1}
            ## and `m1[vgs]` vanished from the deck.  DD-4/DD-6 say a display
            ## decision NEVER changes what the simulator is asked to save, and
            ## an Up press is not even a Delete.
            ##
            ## ⚠ IT GUARDS THE REORDER AND NOTHING ELSE, AND THAT IS A
            ## MEASUREMENT, NOT A PREFERENCE.  A reorder is DEFINITIONALLY
            ## length-preserving, so a shortening one is unambiguously a
            ## defect.  Delete and Add are not: ruling DD-10 governs Delete's
            ## last row, and issue 1288 RULED that an Add whose triple collides
            ## by label is ACCEPTED, replaces the earlier row in place and
            ## tells the user once -- which row BT27 golds by name.  Refusing
            ## them here would be a THIRD door with a THIRD rule, which is the
            ## disagreement issue 1288 exists to remove.  The residual -- a
            ## Delete on a duplicate-label DECLARATION drops two display rows
            ## -- was filed as issue 1326 and is now FIXED, one door further
            ## back: ruling DD-15 makes `op_annot::register` refuse a
            ## declaration carrying two triples that share a display label, so
            ## the ambiguity is rejected where it is created and never reaches
            ## a button.  This guard stays as the SECOND door, because DD-15
            ## cannot shut `::op_annot::desc` against a fixture or an older
            ## session's stored state -- one rule, two doors, which is the
            ## principle DD-15 itself names.
            ##
            ## ⚠ AND IT RUNS BEFORE THE WRITE.  Issue 1323's own recommended
            ## wording was to check afterwards and restore the base; that
            ## cannot restore, because a `set_list` of the base dedupes it
            ## identically -- storing a THIRD value neither the user nor the
            ## PDK chose -- and a base that came from the SEED left the key
            ## UNOWNED, which no verb in this store can undo.
            ##
            ## The STORE owns the sentence (`op_param_lists::reduce_why`, the
            ## `governs` precedent: one rule, a second reader); this file mints
            ## no second wording for a fact the store already words.
            set drop {}
            catch {set drop \
                [::op_param_lists::reduce_why $skey $key $listname $new]}
            if {$drop ne {}} { return [list refused $drop] }
            set did "moved $param $op in the $listname list"
        }
        delete {
            if {$i < 0} { return [list refused $notin] }
            set why [rdw::_last_row_why $base $listname $param]
            if {$why ne {}} { return [list refused $why] }
            set new [lreplace $base $i $i]
            set did "removed $param from the $listname list"
        }
        add {
            if {$i >= 0} {
                return [list refused "$param is already in the $cls $listname list."]
            }
            set t [rdw::_find_triple $cls $cell $param]
            if {$t eq {}} {
                return [list refused "$param is published by this run, but no list and no PDK descriptor declares it - so this window cannot tell which raw-name shape it has, and it will not guess one. A PDK declares it with op_annot::register."]
            }
            set new [linsert $base end $t]
            set did "added $param to the $listname list"
        }
        default { return [list refused "there is no such edit."] }
    }
    set before 0
    catch {set before [llength [::op_param_lists::said]]}
    if {![::op_param_lists::set_list $skey $key $listname $new]} {
        return [list refused [rdw::_store_tail $before \
            "the list store refused that change and said nothing about why."]]
    }
    set say "$did $where."
    ## ⚠ THE STORE'S OWN REPORT IS READ ON THE SUCCESS ARM TOO (item B5-2,
    ## defect A7).  `set_list` returns 1 WITH A REPORT when it REDUCED the list
    ## by LABEL -- issue 1288's ruling, "the two doors reach the same verdict
    ## with the same sentence and the user is told once".  MEASURED at HEAD:
    ## adding `{id vgs 2}` to `{{id ids 0} {gds gds 1}}` returns 1, reports
    ## `the later one replaces it in place`, and the untouched `ids` row is
    ## GONE.  IHP's shipped `{id ids 0}` is exactly that label != param shape,
    ## so this is not a synthetic case.  The preserved patch read the report
    ## only on the rc=0 arm, which told the user zero times in the one case the
    ## ruling exists for.  ⚠ AND THE ADD IS NOT REFUSED: a third door with a
    ## third rule is the disagreement issue 1288 is about.
    set told [rdw::_store_tail $before {}]
    if {$told ne {}} { append say " $told" }
    ## RULING DD-16, ON THE SUCCESS ARM ONLY, AND AT EXACTLY ONE PLACE so all
    ## three `ok` returns below carry it and no refusal arm does.  A refusal
    ## changed nothing, so the false belief this clause corrects never forms --
    ## the same argument `rdw::_do_save` makes for `_tier_note`, and the nine
    ## refusal sentences above are already complete and true without it.
    set sheet [rdw::_sheet_note $subject]
    if {$sheet ne {}} { append say " $sheet" }
    set shadow [rdw::_shadow_why $scope $cls $listname $cell $skey $key]
    if {$shadow ne {}} { return [list ok "$say $shadow"] }
    if {$scope ne {narrow}} { return [list ok $say] }
    # ISSUE 1310, STATED RATHER THAN DISCOVERED.  `apply` is per `type=` token
    # and passes no cell name, and op_annot holds ONE descriptor per type, so a
    # per-cell display list cannot be expressed at all without editing
    # op_annot.tcl, which this item may not.  The entry is stored, written and
    # honoured by `effective`; it does not reach the drawn sheet.
    return [list ok "$say The sheet still draws the $cls class list - a per-cell display list cannot be expressed yet (issue 1310)."]
}

# Ruling DD-6, both halves, and the sibling types with it.
proc rdw::_apply_now {subject} {
    set t {}
    catch {set t [dict get $subject type]}
    ## ⚠ THE ORDER IS HARMLESS AND ITS OLD REASON IS DEAD (item B5-2).  This
    ## comment used to say the bare call MUST come first, because an
    ## explicit-token-first order would leave the subject's type carrying the
    ## union while its class SIBLINGS still carried the PDK's list, so the bare
    ## call that followed would reach `seed`, see two types of one class
    ## disagree, and report a divergence the caller had just created.  Ruling
    ## DD-13 (item B2e) made `seed` read the DECLARATION, which nothing but
    ## `op_annot::register` can write, so that route no longer exists:
    ## RE-MEASURED both orders on this tree, zero reports either way and
    ## `params` byte-identical on both type tokens.  The order is kept because
    ## it is not worth churning; the reason is gone, and a stale reason invites
    ## the next reader to "fix" the order on a false premise.
    ##
    ## WHAT DOES STILL HOLD is why there are two calls at all: a `type=` token
    ## the class map does not name is unreachable from the bare call (issue
    ## 1279), and the class's mapped SIBLINGS must follow, or `apply nmos`
    ## alone leaves every pmos on the sheet drawing the old list.
    ##
    ## ⚠ AND IT ANSWERS NOW, WHICH IS ISSUE 1330 (item R2).  This proc used to
    ## be three bare `catch`es and a bare `return {}`, so an `apply` that
    ## FAILED was invisible and both call sites reported the full success
    ## sentence.  MEASURED at HEAD 27122ca4 with `op_param_lists::apply`
    ## renamed to a proc that raises: an Up press still said "Up: moved gm up
    ## in the annotation list for class ...", with no hint that the sheet had
    ## not followed.
    ##
    ## That was harmless while nobody had been promised anything: until item R2
    ## this channel carried no claim about the schematic.  R2 is the item whose
    ## whole promise is that the annotation follows the reorder, so a swallowed
    ## failure is now a FALSE STATEMENT on a screen the user is reading -- the
    ## same class of defect as a refusal that repainted.  The caller decides
    ## what to do with the answer; this proc only stops eating it.
    ##
    ## TWO WAYS TO FAIL AND BOTH ARE REPORTED.  A RAISE is an exception and is
    ## quoted; a `_say` is the store's own worded report and is read as the
    ## TAIL of `said`, `rdw::_store_tail`'s rule exactly -- the store's wording
    ## and never a second one for the same fact.  MEASURED: an ordinary
    ## accepted press adds NOTHING to `said` across both applies, so the
    ## success sentence is byte-identical to the one this file emitted before
    ## (row RE6's third leg golds that it is not negated).
    set before 0
    catch {set before [llength [::op_param_lists::said]]}
    set err {}
    if {[catch {::op_param_lists::apply} err]} {
        return "The schematic annotation was not updated: $err"
    }
    if {$t ne {} && [catch {::op_param_lists::apply $t} err]} {
        return "The schematic annotation was not updated: $err"
    }
    set told [rdw::_store_tail $before {}]
    if {$told ne {}} {
        return "The schematic annotation was not updated: $told"
    }
    if {[catch {xschem redraw} err]} {
        return "The schematic annotation was not redrawn: $err"
    }
    return {}
}

# ---------------------------------------------------------------------------
# THE SCOPE DIALOG.

proc rdw::scope_dialog_build {op subject listname} {
    variable scope_choice
    variable list_choice
    catch {destroy .rdw.scope}
    set w [::toplevel .rdw.scope]
    wm title $w {Which devices?}
    wm transient $w .rdw
    catch {$w configure -background [rdw::color panel]}
    set inst {}
    catch {set inst [dict get $subject instname]}
    set cls {}
    catch {set cls [dict get $subject class]}
    set cell {}
    catch {set cell [dict get $subject cellname]}
    ::label $w.q -anchor w -justify left -background [rdw::color panel] \
        -text "[string totitle $op] on $inst: which devices should this change?"
    pack $w.q -side top -fill x -padx 8 -pady {8 4}
    ::frame $w.sc -background [rdw::color panel]
    ::radiobutton $w.sc.narrow -anchor w -variable ::rdw::scope_choice \
        -value narrow -background [rdw::color panel] \
        -text "this device flavor only ([expr {$cell eq {} ? {no cell name} : $cell}])"
    ::radiobutton $w.sc.broad -anchor w -variable ::rdw::scope_choice \
        -value broad -background [rdw::color panel] \
        -text "every device of class $cls"
    pack $w.sc.narrow $w.sc.broad -side top -fill x
    pack $w.sc -side top -fill x -padx 16
    # THE SECOND QUESTION, AND ONLY WHERE THE SPEC ASKS FOR IT.  List 3 is
    # everything this run's raw holds, so an Add from it has no list of its own
    # to land in and the dialog must ask which.  Lists 1 and 2 already name it.
    if {$listname eq {all}} {
        ::label $w.q2 -anchor w -background [rdw::color panel] \
            -text {And which list should it go into?}
        pack $w.q2 -side top -fill x -padx 8 -pady {8 4}
        ::frame $w.li -background [rdw::color panel]
        ::radiobutton $w.li.annotation -anchor w -variable ::rdw::list_choice \
            -value annotation -background [rdw::color panel] \
            -text {the annotation list (drawn on the sheet)}
        ::radiobutton $w.li.summary -anchor w -variable ::rdw::list_choice \
            -value summary -background [rdw::color panel] \
            -text {the summary list (computed, not drawn)}
        pack $w.li.annotation $w.li.summary -side top -fill x
        pack $w.li -side top -fill x -padx 16
    }
    ::frame $w.btns -background [rdw::color panel]
    ::button $w.btns.ok -text OK -width 8 \
        -command [list rdw::scope_dialog_done $w ok]
    ::button $w.btns.cancel -text Cancel -width 8 \
        -command [list rdw::scope_dialog_done $w cancel]
    pack $w.btns.cancel $w.btns.ok -side right -padx 4
    pack $w.btns -side bottom -fill x -pady 6 -padx 6
    # ase::ui::bind_dialog_esc's one line (ase_window.tcl:1580), and MEASURED
    # safe here: a child toplevel's bindtags are {.rdw.scope Toplevel all}, so
    # this cannot reach `.rdw`'s ruling DD-12 Escape and cannot end the canvas
    # command mode by accident.
    bind $w <Key-Escape> [list rdw::scope_dialog_done $w cancel]
    wm protocol $w WM_DELETE_WINDOW [list rdw::scope_dialog_done $w cancel]
    return $w
}

proc rdw::scope_dialog_done {w how} {
    variable scope_result
    variable scope_choice
    variable list_choice
    if {$how eq {ok}} {
        set scope_result [dict create scope $scope_choice list $list_choice]
    } else {
        set scope_result {}
    }
    catch {grab release $w}
    catch {destroy $w}
    return {}
}

# -> {scope narrow|broad list annotation|summary}, or {} for Cancel.
proc rdw::scope_dialog {op subject listname} {
    variable scope_result
    variable scope_choice
    variable list_choice
    # PRE-SET TO CANCEL, BEFORE THE BUILD.  A window destroyed by a deadman
    # timer or by a window manager never reaches scope_dialog_done, and a stale
    # result would then be read as an answer the user never gave.
    set scope_result {}
    set scope_choice broad
    set list_choice [expr {$listname eq {all} ? {annotation} : $listname}]
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw]} { return {} }
    set prevfocus {}
    catch {set prevfocus [focus]}
    set w {}
    if {[catch {rdw::scope_dialog_build $op $subject $listname} w]} { return {} }
    catch {update}
    catch {raise $w}
    catch {grab set $w}
    ## ⚠ THE DIALOG TAKES THE KEYBOARD, AND A GRAB ALONE IS NOT ENOUGH.
    ## MEASURED: Tk REDIRECTS a keyboard event to the DISPLAY's focus window,
    ## not to the window the event names -- so with the canvas still holding
    ## the keyboard (rdw::_pick_seize ends in `focus -force $cv`), an Escape
    ## aimed at this dialog was delivered to the CANVAS instead and silently
    ## ENDED the user's command mode, while the dialog sat there waiting.  A
    ## grab stops the pointer reaching other windows; it does not move the
    ## keyboard.  `-force`, because the focus we are taking it from was itself
    ## taken with `-force` and a plain `focus` cannot cross toplevels.
    ##
    ## ⚠ AND IT IS HANDED STRAIGHT BACK.  This is the one place in this file
    ## that takes the keyboard, so it is the one place that must give it back:
    ## the canvas is where the command mode's own Escape lives (issue 1308),
    ## and a dialog that kept the keyboard would leave a mode the user cannot
    ## leave -- the exact defect DD-12 was ruled about, one window further out.
    catch {focus -force $w}
    # GUARDED, for ase::ui::bus_dialog's own reason (ase_window.tcl:1414): the
    # build-time `update` can let a timer destroy the window before we get
    # here, and `tkwait window` on a dead path never returns.
    if {[winfo exists $w]} { catch {tkwait window $w} }
    catch {grab release $w}
    if {$prevfocus ne {} && [winfo exists $prevfocus]} {
        catch {focus -force $prevfocus}
    }
    return $scope_result
}

# ---------------------------------------------------------------------------
# SAVE.

# Ruling DD-7's read-modify-write is the STORE's, not this file's: `write_conf`
# reads the tier it is about to write, changes only the keys this session
# changed and preserves every other row verbatim, rows this build cannot parse
# included.  This proc chooses the tier, names the file it wrote, and repeats
# the store's own sentence when it refuses.
# ⚠ THE TWO TIERS CAN BE ONE FILE, AND AT THE ORDINARY LAUNCH CWD THEY ARE
# (issue 1325, item B5-a).  `op_param_lists::conf_path project` is
# `[pwd]/.xschem/op_param_lists.conf`, so a session started in `$HOME` -- which
# is how xschem is normally started -- resolves the PROJECT tier onto the
# USER-GLOBAL file.  MEASURED: both answer
# `/home/analog/.xschem/op_param_lists.conf`, and a Save taken there is read
# back by every other design on the machine.  Ruling DD-7's whole subject is
# that a write touches ONE TIER'S OWN FILE, so a Save that cannot say the two
# are the same file is that ruling failing where the user cannot see it.
#
# THE FIX IS TO MAKE THE REPORT HONEST, NOT TO CHANGE WHICH TIER SAVE WRITES.
# Issue 1273 -- "which directory IS the project" -- is a live rule debt on the
# owed ledger and is the USER's to settle; this note names the collision and
# points at it.  A named callee rather than three lines inline, so a reviewer
# can neutralise exactly this sentence and watch a row say so.
proc rdw::_tier_note {path} {
    set tiers {}
    catch {set tiers [::op_param_lists::conf_tiers $path]}
    if {[llength $tiers] < 2} { return {} }
    return "That file is both tiers here - this project directory and your user configuration directory are the same directory - so every design on this machine reads it back (issue 1273 asks which directory is the project)."
}

proc rdw::_do_save {label} {
    set path {}
    catch {set path [::op_param_lists::conf_path project]}
    if {$path eq {}} {
        return [rdw::status "$label: there is no project settings-file path to write to."]
    }
    set before 0
    catch {set before [llength [::op_param_lists::said]]}
    set ok 0
    catch {set ok [::op_param_lists::write_conf $path]}
    if {$ok} {
        ## ON THE SUCCESS ARM ONLY.  A refused Save changed nothing, so the
        ## false belief this sentence corrects never forms -- and the refusal
        ## arm already carries the STORE's own wording, which must not be
        ## diluted by a second sentence about a file that was not written.
        set note [rdw::_tier_note $path]
        if {$note ne {}} {
            return [rdw::status \
                "$label: wrote the operating-point parameter lists to $path $note"]
        }
        return [rdw::status "$label: wrote the operating-point parameter lists to $path"]
    }
    return [rdw::status "$label: [rdw::_store_tail $before \
        "could not write the parameter lists to $path."]"]
}

# ---------------------------------------------------------------------------
# THE ONE COMMAND EVERY WIDGET CARRIES.
#
# ⚠ EVERY PATH OUT OF HERE ENDS IN A STATUS LINE THAT NAMES THE BUTTON IT CAME
# FROM.  That is rdw::inert's obligation surviving the wiring: the status line
# is shared by all five buttons, so a message that does not identify itself is
# the same failure as a silent one, one step further in.
proc rdw::button {id} {
    variable listkind
    variable blocks
    set label [rdw::_button_label $id]
    if {$label eq {}} {
        return [rdw::status "There is no button called '$id' in this window."]
    }
    # THE GREYING TABLE IS THE COMMAND PATH'S FENCE TOO.  A key, a menu or a
    # later item that reaches this proc directly gets the same answer the
    # disabled widget would have given.
    if {[rdw::button_state $id $listkind] ne {normal}} {
        return [rdw::status "$label: this button is greyed on the $listkind list, so there is nothing here for it to do."]
    }
    if {$id eq {save}} { return [rdw::_do_save $label] }
    if {($id eq {delete} || $id eq {add}) && [rdw::pick_running]} {
        return [rdw::status "$label: a device pick is running on the canvas - click a device, or press Escape to end the mode, then press $label again. A dialog opened now would swallow the click the mode is waiting for."]
    }
    if {[llength $blocks] == 0} {
        return [rdw::status "$label: nothing has been dumped into this window yet - press 1, 2 or 3 over a device first."]
    }
    set line [rdw::_target_line]
    set loc [rdw::_locate $line]
    set param {}
    if {$loc ne {}} {
        set param [rdw::_row_param \
            [lindex [lindex $blocks [lindex $loc 0]] [lindex $loc 1]]]
    }
    # ⚠ TWO SENTENCES, BECAUSE THERE ARE NOW TWO WAYS TO HAVE NO ROW (item R1,
    # issue 1337).  Before the cursor was visible `_target_line` read the
    # pane's `insert` mark, which always has a line, so "no row at all" could
    # not be said and did not need saying.  It can now: ruling DD-1 clears the
    # cursor on every new dump, and "line 0 is not a parameter row" would be a
    # sentence about a line that does not exist, on a screen the user is
    # reading.
    if {$line <= 0} {
        return [rdw::status "$label: no row is marked in this window - click a parameter row, which shades to show it is the target, then press $label again."]
    }
    if {$param eq {}} {
        return [rdw::status "$label: line $line is not a parameter row - click a parameter row in the pane, then press $label again."]
    }
    set subj [rdw::_subject [lindex $loc 0]]
    if {$subj eq {} || [dict get $subj type] eq {} || [dict get $subj class] eq {}} {
        return [rdw::status "$label: the device this block was dumped from has no operating-point descriptor in this design any more, so there is no list to edit."]
    }
    if {$id eq {up} || $id eq {down}} {
        # List 3 is what this run's raw actually holds (ruling DD-1), which is
        # why the store refuses to persist it at all: there is no stored order
        # to move.  The greying stays keyed on list IDENTITY -- a
        # position-dependent grey would have to re-grey on every cursor move,
        # which needs a new binding on the pane and is issue 1306/1308 ground.
        if {$listkind eq {all}} {
            return [rdw::status "$label: list 3 is live from the simulator and has no stored order to change. Press 1 or 2 first."]
        }
        set ln $listkind
        # `governing`, not narrow-or-broad: Up and Down raise no dialog, so
        # rdw::_edit resolves the key itself through op_param_lists::governs.
        lassign [rdw::_edit $id $subj $ln governing $param] verdict sentence
        if {$verdict ne {ok}} { return [rdw::status "$label: $sentence"] }
        # ⚠ AND IT APPLIES, LIKE DELETE AND ADD (item B5-2).  The preserved
        # patch deferred the redraw here and SAID SO on screen -- "The drawn
        # order follows on the next Add, Delete or reload (issue 1312)" --
        # because `op_param_lists::seed` read back the very field `apply`
        # writes, so an apply after the user owned an annotation list reordered
        # the seed, and the SUMMARY list, which nobody owns, then answered in
        # the annotation list's order.  Ruling DD-13 (item B2e) killed that:
        # `seed` reads the DECLARATION now, `_show_set` filters the union
        # annotation-first, and store row N4 fences the opposite.  The
        # deferral's stated cost no longer exists, and a status line citing a
        # FIXED issue as its reason is a false statement on a screen the user
        # is reading.  Rows BT8 and BE7 assert the display key moves now, for
        # every type token of the class.
        #
        # ⚠ AND THE WINDOW FOLLOWS TOO, WHICH IS ITEM R2 (issue 1338).  The
        # SHEET half already worked -- MEASURED at HEAD 27122ca4 as a
        # `xschem get annot_overlay_flushes` of +1 per accepted press -- but
        # `::rdw::blocks` came back byte-identical, so the pane kept showing
        # the order the user had just changed until they pressed 1 or 2 again.
        # `rdw::_reorder_shown` re-slots every block that draws this class's
        # list and answers the pane line the cursored ROW moved to.
        #
        # ⚠ THE CURSOR IS RE-POINTED BEFORE THE REPAINT, NOT AFTER.
        # `rdw::render_pane` paints the shading from `::rdw::targetrow` on its
        # way out (`rdw::_paint_cursor`), so setting the row afterwards would
        # paint twice and, in between, shade the line the parameter has LEFT.
        # Row RD1 reads the `cursor` tag's own ranges off the live widget and
        # is the fence.
        #
        # ⚠ AND IT RUNS BEFORE `_apply_now`, so a sheet that cannot be
        # re-rendered still leaves the WINDOW agreeing with the store the user
        # just changed -- the edit stood, and the sentence below says which
        # half did not follow (issue 1330).
        set line [rdw::_reorder_shown [dict get $subj class] $ln $loc $line]
        rdw::set_row $line
        rdw::render_pane
        set why [rdw::_apply_now $subj]
        if {$why ne {}} { return [rdw::status "$label: $sentence $why"] }
        return [rdw::status "$label: $sentence"]
    }
    set deflist [expr {$id eq {add} ? {annotation} : $listkind}]
    set ans [rdw::scope_dialog $id $subj $listkind]
    if {$ans eq {}} {
        return [rdw::status "$label: cancelled - nothing was changed."]
    }
    set scope broad
    catch {set scope [dict get $ans scope]}
    if {$scope ne {narrow} && $scope ne {broad}} { set scope broad }
    set ln $deflist
    if {$listkind eq {all}} { catch {set ln [dict get $ans list]} }
    if {$ln ne {annotation} && $ln ne {summary}} { set ln $deflist }
    lassign [rdw::_edit $id $subj $ln $scope $param] verdict sentence
    if {$verdict ne {ok}} { return [rdw::status "$label: $sentence"] }
    ## ISSUE 1330 REACHES THIS DOOR TOO.  Delete and Add have always relied on
    ## `_apply_now` to put the change on the sheet, so a swallowed failure was
    ## just as false here; it was only never fenced because no row asked.
    ##
    ## ⚠ AND THE BLOCKS ARE NOT RE-SLOTTED ON THIS ARM.  A Delete or an Add
    ## changes WHICH rows the list holds, and the pane's rows are what THIS RUN
    ## published -- a re-slot could neither add the new row (no run published
    ## it) nor remove the deleted one (the run still did).  Ruling DD-3 gives
    ## item R2 the reorder and nothing else; a window that dropped a row the
    ## simulator really reported would be inventing a dump.
    set why [rdw::_apply_now $subj]
    if {$why ne {}} { return [rdw::status "$label: $sentence $why"] }
    return [rdw::status "$label: $sentence"]
}

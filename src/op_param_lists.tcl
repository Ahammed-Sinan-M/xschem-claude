## File: src/op_param_lists.tcl
##
## THE OP PARAMETER LIST STORE -- item B2 of doc/claude/op_param_batch/PLAN.md.
## Spec: doc/claude/specs/op_param_lists.md, section 4.3 (the class map) and
## section 4.4 (the settings file). Rulings: doc/claude/op_param_batch/
## DECISIONS.md -- D-4, D-7, and the driver decisions DD-2 and DD-3.
##
## Four things live here and nothing else. There is NO UI (the window is item
## B3's, the buttons are B5's) and no C.
##
##   (a) THE CLASS MAP.  A `type=` K-record token -> a broad class. It is DATA,
##       an array a user extends with one line, never a `switch`. Measured: the
##       shipped `type=` vocabulary is OPEN -- sky130 alone ships `varactor`,
##       `npn`, `pnp`, `pwell_resistor`, `p_diffusion_resistor`,
##       `n_diffusion_resistor` and `high_precision_p`; IHP ships `pnp` (NOT
##       `vertical_pnp`), `inductor` and `esd`; and xschem_library uses `type=`
##       for bare part numbers (2N3906, 4001, 12SK7). A closed classifier would
##       be wrong on the day it shipped.
##       AN UNMAPPED TOKEN IS ITS OWN CLASS -- identity, never {} and never a
##       raise. That makes the map an OVERRIDE TABLE rather than a gate: a PDK
##       with a token nobody anticipated still gets working lists, and the
##       shipped default therefore stays at section 4.3's five groups and
##       invents no grouping the user never ruled on.
##
##   (b) THE ORDERED LISTS, per class (DD-2's primary key) and per flavor
##       (DD-2's optional override, a CELL-NAME GLOB, the same narrowing
##       op_annot::_matches already performs). List names are `annotation` and
##       `summary`. Section 4.2's third list, `all`, is LIVE from the simulator
##       and is NEVER PERSISTED: storing it would be a list no simulator ever
##       published, which is the invented data ruling D-4 forbids. So `owns`
##       answers 0 for it, `effective` answers {}, and a settings-file row that
##       names it is reported and skipped.
##
##   (c) THE PDK SEED (D-7: "seed from the PDK, the user's file wins"). A class
##       with no user entry answers the ordered {label param kind} triples the
##       PDK registered through op_annot::register, read back through the
##       published op_annot::descriptor. There is no second registry here.
##       ⚠ IT READS THE DECLARATION KEY, NOT `params` (ruling DD-13, issue
##       1312). `apply` below writes the annotation+summary UNION into `params`,
##       so a seed read out of `params` is not the PDK's list at all after the
##       first apply -- it is whatever the last apply computed, which let two
##       Deletes destroy a PDK row, its `.save` card and the sibling type's
##       copy, with Add unable to put any of them back. `op_annot::register` is
##       the declaration's only writer and `_params` below is its only reader.
##       A descriptor with no declaration -- one that never passed through
##       `register` -- falls back to `params`, which is the behaviour of every
##       descriptor that predates the key (invariant I7).
##       THE SEED IS A TRIPLE, NOT A NAME, AND IHP IS THE PROOF:
##       sky130A/sky130_procs.tcl and gf180mcuD/gf180_procs.tcl both declare
##       `{id id 0}`, but ihp-sg13g2/sg13g2_procs.tcl declares `{id ids 0}` --
##       LABEL `id`, PARAM `ids`, and they DIFFER. A store that kept only the
##       name would round-trip two PDKs perfectly and silently rewrite the
##       third. All three fields are carried everywhere, including through the
##       settings file.
##
##   (d) THE SETTINGS FILE, read by a strict parser and written with the
##       write-beside-and-move idiom.
##
## ===========================================================================
## DD-3: THE SETTINGS FILE IS DATA, AND IS NEVER SOURCED
## ===========================================================================
## TWO FILES, NOT ONE. Spec section 4.4 conflates them; DD-3 corrects it. THIS
## file is the IMPLEMENTATION -- Tcl code, shipped, installed, sourced from
## xschem.tcl. The SETTINGS FILE it reads is
##
##     <pwd>/.xschem/op_param_lists.conf        the project tier
##     $USER_CONF_DIR/op_param_lists.conf       the user-global fallback
##
## and it is line-oriented DATA. The reader does no `source`, no `eval`, no
## `subst`, no `uplevel` and no substitution of any kind; anything it does not
## recognise is REPORTED and SKIPPED, never obeyed.
##
## The reason is the user's own requirement that the file be SHAREABLE WITH
## TEAMMATES. A file that is shared and then sourced is arbitrary code
## execution on whoever opens the project -- the headline feature would be the
## vulnerability. MEASURED on this tree, feeding a plausible shared conf to the
## `uplevel #0 [list source $path]` idiom that ase::sim_load_conf uses, with the
## payload placed FIRST under a friendly "share freely" header:
##
##     SOURCED: OPL_PWNED=1  marker_on_disk=1  err={invalid command name "mos"}
##
## The variable was set AND a file was created; the Tcl error that follows is
## COSMETIC, because the payload had already run. A caller that read the raise
## as evidence would have scored that file safe. Issue 0812 already burned this
## tree on `subst` and paths. The price is this parser instead of a one-line
## `source`, and it is worth it.
##
## FIELDS ARE SPLIT WITH `regexp -inline -all {\S+}`, NEVER by treating the
## line as a Tcl list. Measured: `llength {mos annotation { id 0}` RAISES
## `unmatched open brace in list`, so a stray `{` in a teammate's file would
## kill the reader from the inside. A parser its own input can kill is not a
## strict parser.
##
## THE GRAMMAR (every row self-contained, so skipping a malformed one cannot
## silently reassign the rows after it):
##
##     # a whole-line comment ; blank lines are skipped
##     version 2
##     [pdk <name>]                  a PDK SECTION HEADER; [pdk *] goes back to
##                                   the rows that apply to every PDK
##     class  <type-token> <broad-class>
##     list   class  <class> <listname>
##     list   flavor <class> <cell-name glob> <listname>
##     param  class  <class> <listname> <label> <rawparam> <kind>
##     param  flavor <class> <cell-name glob> <listname> <label> <rawparam> <kind>
##
## THE PDK AXIS IS NOT A NEW ROW SHAPE AND THE VERSION DOES NOT MOVE (issue
## 1388). Every v2 row means exactly what it meant before; the only new LINE
## KIND is the section header, and a v2 row's arity, fields and order are
## untouched. Bumping to `version 3` was rejected AND MEASURED AGAINST THE
## USER'S OWN FILE: theirs says `version 2` and is completely correct under
## this grammar, so a bump would report a mismatch at every launch about a file
## with nothing wrong with it, and ruling DD-11 would then rewrite their
## version line on the next Save for no behavioural reason at all. THE PRICE,
## STATED: an OLDER xschem reading a sectioned file reports the header as an
## unknown keyword, skips it, and then applies the section's rows to EVERY PDK
## -- so a file with PDK sections is shareable with a teammate on this build or
## newer, and merely wrong-not-broken on an older one. Recorded in the issue
## and in spec section 4.4 rather than in the emitted header, which the user
## reads every time and which is already at its length budget.
##
## GRAMMAR v2 -- ITEM B2c, ISSUE 1277. A `flavor` row carries its CLASS as a
## field of its own, so `effective <class>` can never be answered by a flavor
## somebody wrote with another class in mind, and so the class and the glob
## reach the file as TWO SEPARATE unquoted fields. Emitting the two-element key
## WHOLE is what corrupted a metacharacter-bearing glob in both earlier
## attempts: Tcl's list-to-string rule braces the element and the reader's
## `regexp -inline -all` split reads the braces literally. v1 had no class
## field, so a v1 `flavor` row is a WRONG FIELD COUNT under v2 and is reported
## and skipped -- never migrated by inference, because guessing which class
## `*nfet_01v8_lvt*` meant is the invention ruling D-4 forbids one level up.
## THE ARITY THEREFORE DEPENDS ON THE SCOPE, so the scope is validated FIRST.
##
## PRECEDENCE AMONG FLAVOR ROWS IS FILE ORDER (ruling DD-8). When two globs of
## the SAME class both match a cell name, THE FIRST ONE IN THE FILE WINS.
## Nothing is ranked and no code anywhere decides which glob is "narrower".
## Two crews ranked and both shipped a bare `*` beating a specific pattern --
## the filed defect, under its own fix, twice -- because "narrower" has no
## defensible total order over globs: neither `sky130_fd_pr__*` nor
## `*nfet_01v8_lvt*` contains the other. File order is something the user SETS
## and can SEE, and the spec's button column already gives every list Up and
## Down, so the reordering UI exists before the rule needs one.
## ACROSS TWO FILES "first in the file" has no answer, so read order decides:
## the user-global file is read first, and a project row outranks a personal
## one only by using the SAME class and the SAME glob. The emitted header says
## all of this, and the suite's row F5 BUILDS ITS CASE OUT OF THAT SENTENCE --
## a file that states a rule its own code does not obey reds.
##
## A `param` row implicitly declares its list, so a hand-editing user never has
## to write the `list` line; `list` exists so an EMPTIED list can be expressed,
## and a lost `list` line degrades to the PDK seed, which is the safe
## direction. THE FIRST `param` OR `list` ROW FOR A GIVEN (scope,key,listname)
## IN A FILE CLEARS WHAT AN EARLIER TIER PUT THERE -- that is what makes the
## project file WIN over the user-global one (D-7) rather than append to it.
## Within one file the rows then accumulate in file order, and a repeated LABEL
## replaces in place and is reported.
##
## ===========================================================================
## THE PDK AXIS (issue 1388): THREE PRECEDENCE AXES, AND THEY ARE ORDERED
## ===========================================================================
## The user's constraint is the whole design and it is generous: "a given
## launch, with a set of libraries will not have more than one PDK included".
## The PDK is therefore a PER-PROCESS CONSTANT, so nothing here ever merges two
## PDKs and no store key gains a PDK field. A row that is not for THIS launch's
## PDK is NEVER PARSED INTO THE STORE AT ALL -- which is the same structural
## move ruling DD-7 makes about provenance one layer out: you cannot leak a row
## you never read.
##
## The three axes, OUTERMOST FIRST, because two of them used to be one:
##   1. TIER.  The project file's rows for a (scope,key,listname) replace the
##      user-global file's rows for it, WHATEVER PDK SCOPE EITHER WAS WRITTEN
##      IN. Read order decides and `touched` is per FILE, so this axis is
##      unchanged by the PDK work and stays the outermost one.
##   2. PDK SCOPE, within one file.  A row under `[pdk <name>]` for THIS
##      launch's PDK beats a row with no PDK scope, WHEREVER THE SECTION SITS
##      IN THE FILE. This is a RANK, not file order, and that is deliberate:
##      the user's ruling is "PDK section beats the un-scoped rows", and a rank
##      means moving your section to the top of the file cannot silently cost
##      you your per-PDK list. Implemented by reading the file in TWO PASSES --
##      un-scoped rows first, then this PDK's -- so the SAME "first touch of a
##      key clears what came before" machinery that gives axis 1 its answer
##      gives axis 2 its answer too, with no rank bookkeeping anywhere.
##   3. FILE ORDER among flavor globs (ruling DD-8, above). Untouched.
## Axis 2 is the only new one and it is the only one that is a rank. Saying
## which is which is the point: an earlier draft made axis 2 file order too,
## and then "PDK beats un-scoped" was false for exactly the user who put their
## section first.
##
## A ROW WITH NO PDK SCOPE APPLIES TO EVERY PDK. That is what every row in
## every existing file is, so this is what backward compatibility means
## concretely, and it is why an old file needs no migration and gets none.
## NO PDK DETECTED IS NOT AN ERROR: a launch with no PDK reads the un-scoped
## rows and `[pdk *]`, applies no `[pdk <name>]` section, and otherwise behaves
## exactly as it did before this existed.
##
## ⚠ SAVE EDITS THE ROWS WHERE THEY ALREADY ARE, AND NEVER INVENTS A SECTION.
## If the file already carries rows for a dirty key in THIS launch's PDK
## section, the writer edits them there; otherwise it edits the un-scoped rows,
## which is byte-for-byte what it did before this item. So an existing file --
## the user has a real nine-row one at <repo>/.xschem/op_param_lists.conf --
## is never rewritten into the new shape behind their back, and per-PDK lists
## are opted into by TYPING one header, which the emitted header explains in
## one line. The alternative, "a Save under a PDK always writes into that
## PDK's section", is a live RULE DEBT (issue 1388) and is the user's to
## settle: it delivers their sentence more literally and it also silently
## grows a section into a file whose owner never asked for one, and leaves the
## un-scoped rows behind as a stale list a no-PDK launch would then read back.
##
## THE TIER WIN IS PER (scope,key,listname), NOT PER CLASS. DD-3's own sentence
## says "per class"; per-list is FINER, never coarser, so a project file that
## customises `mos annotation` no longer silently discards the user-global's
## `mos summary`.
##
## ===========================================================================
## DD-7: SAVE IS A READ-MODIFY-WRITE OF ONE TIER'S OWN FILE
## ===========================================================================
## Writing a tier READS THAT TIER'S EXISTING FILE, changes only the keys THIS
## SESSION actually changed, and writes it back. Every other row is preserved
## VERBATIM -- comments, blank lines, the `version` row, and rows this build
## does not understand.
##
## Two earlier attempts serialized a MERGED model and tagged each row with the
## tier it came from. Both lost rows the user had typed: one deleted a user's
## `class mydiode diode`, the other deleted a user's explicit `class nmos mos`
## BECAUSE ITS VALUE EQUALLED THE SHIPPED DEFAULT -- which is exactly the row
## somebody writes down to protect themselves against a default changing. Both
## reported success with zero messages.
##
## The new shape cannot fail that way because YOU CANNOT DELETE A ROW YOU
## NEVER PARSED INTO A MODEL. Provenance stops being a field to get right and
## becomes a property of which file you opened. A row a FUTURE build writes
## survives a save by THIS one, which is what "shareable with teammates"
## requires the moment two people are on different versions.
##
## WHAT "THIS SESSION CHANGED" MEANS, spelled out because DD-7 does not spell
## it: `set_list` and `set_class` stamp; a DIRECT `load_conf <path>` stamps,
## because importing a file into your session IS a session change; `load` --
## the two-tier startup restore -- stamps NOTHING, because that is the
## session's initial state and not a change. Ladder L2. Stamping only in the
## setters would make an imported file unsaveable; stamping in `load` too
## would re-open the leak that writes the project tier's rows into the user's
## own file.
##
## COST, STATED: Save re-reads the file it is about to write, so a file edited
## by hand between load and save is MERGED rather than overwritten. That is
## what a person expects of a config file. And an existing target that cannot
## be READ stops the save with a sentence rather than proceeding -- writing
## this session's few changed keys over a file whose other rows were never
## read would be DD-7's own failure mode arriving through its own fix.
##
## THE CLASS MAP HAS NO DEFAULT-COMPARISON FILTER. A token this session set is
## written whether or not its value equals the shipped default, so no row can
## ever be dropped for agreeing with a default. That is the second refutation
## retired structurally rather than by care.
##
## ===========================================================================
## THE PROJECT TIER IS `<pwd>/.xschem/`, NOT `[xschem get current_dirname]`.
## Measured: after loading a schematic from elsewhere current_dirname MOVES
## while pwd does not, so a Save taken while descended into a PDK library cell
## would write the project file into the PDK tree and the next read, back at the
## top, would not find it. pwd is stable for the whole session, so the reader
## and the writer can never silently disagree, and it matches the tree's ONLY
## project-vs-user precedent, xinit.c:3500-3515's `./xschemrc` in pwd. This is
## an L2 ladder decision and is on the owed ledger as a rule debt, issue 1273.
##
## ===========================================================================
## ENCODING IS PINNED ON BOTH CHANNELS; TRANSLATION IS DELIBERATELY NOT
## ===========================================================================
## MEASURED on this box: `encoding system` is utf-8 here and iso8859-1 under
## LC_ALL=C, and the SAME BYTES read back as a DIFFERENT STRING (length 15 vs
## 16) depending on the reader's locale. A file whose headline feature is that
## it is shareable cannot depend on the teammate's LANG, so _chanconf pins
## `-encoding utf-8` on the read channel AND the write channel. Nothing else in
## this tree pins it, so it does not arrive by copying a neighbour.
## CRLF, on the other hand, is ALREADY handled by the DEFAULT `auto`
## translation; copying the tree's `-translation binary` idiom (ase.tcl:1625,
## xschem.tcl:7910) would REINTRODUCE the bug. Pin the encoding, leave the
## translation alone, and keep action_registry.tcl's defensive trailing-\r trim.
##
## ===========================================================================
## SOURCE-TIME PURITY
## ===========================================================================
## This file is a BARE `source` from xschem.tcl, which puts it inside
## tests/headless/test_startup_guard_0663's contract: a raise at SOURCE TIME
## aborts startup (cleanly now, exit 1; via issue 0423 it used to be exit 139).
## So the file defines PROCS and LITERAL namespace variables and nothing else.
## It reads no file, stats no directory, calls no `xschem` subcommand and
## touches op_annot:: not at all until a proc is called. op_annot.tcl:224-231
## states the rule for itself; this file inherits it. It must also source
## cleanly TWICE and into a bare Tcl interpreter that has no `xschem` command.
##
## ===========================================================================
## THE APPLY DOOR IS op_annot::register, AND IT IS CALLED FROM NOWHERE HERE
## ===========================================================================
## Invariant I5 requires a changed list to take effect ON REDRAW -- no restart,
## no rebuild. Only op_annot::register bumps ::op_annot::gen (op_annot.tcl:346),
## which annot_overlay_sync() folds into the overlay's epoch (actions.c:2032). A
## direct `set ::op_annot::desc(...)` would be stored, correct in Tcl, and
## INVISIBLE ON SCREEN until an unrelated redraw -- I5 failing silently. So
## `apply` exists here, and defining it is what stops item B5 writing a second
## door. It is deliberately UNWIRED: an auto-apply at startup is provably wrong
## ordering, because this file is sourced from xschem.tcl before any PDK
## `_procs.tcl` runs, so it would write into an empty registry and register's
## deliberate REPLACE semantics would then discard it.
##
## Suite: tests/headless/test_op_param_store_1245.tcl.

namespace eval ::op_param_lists {

  ## THE SHIPPED DEFAULT CLASS MAP -- section 4.3's five groups and nothing
  ## more. A map entry is a CLAIM that two tokens share one list; groupings no
  ## ruling covers (varactor -> capacitor, esd -> diode) are exactly the shape
  ## D-4 forbids, one level up, and the identity fallback below makes leaving
  ## them out harmless. Measured tokens that are deliberately NOT here, each a
  ## one-line `class <token> <class>` row in the user's own settings file:
  ##   sky130: varactor npn pnp pwell_resistor p_diffusion_resistor
  ##           n_diffusion_resistor high_precision_p
  ##   IHP:    pnp inductor esd
  ## sky130 spells a resistor THREE ways, which is why `res` is not enough.
  variable defaultmap {
    nmos                          mos
    pmos                          mos
    res                           resistor
    poly_resistor                 resistor
    high_precision_poly_resistor  resistor
    high_precision_poly_p         resistor
    capacitor                     capacitor
    moscap                        capacitor
    diode                         diode
    vertical_npn                  bipolar
    vertical_pnp                  bipolar
  }

  ## token -> broad class. Guarded exactly as op_annot.tcl guards `desc`, so a
  ## second source of this file is a no-op rather than a silent reset of a
  ## user's map.
  variable classmap
  if {![array exists classmap]} { array set classmap $defaultmap }

  ## [list <scope> <key> <listname>] -> the ordered list of {label param kind}.
  variable lists
  if {![array exists lists]} { array set lists {} }

  ## The same key -> 1 when the USER owns that list. `owns` 1 with an empty
  ## list and `owns` 0 are DIFFERENT FACTS -- "I chose to show nothing" against
  ## "I never customised this" -- and collapsing them would answer the PDK seed
  ## to a user who had deliberately cleared the list. Issue 1272 cost this batch
  ## one item for the same collapse, one class further out.
  variable owned
  if {![array exists owned]} { array set owned {} }

  ## broad class -> 1 once a seed divergence has been reported for it. Separate
  ## from `reports` on purpose: said_clear empties the reports the caller has
  ## already read, and must not make the store say the same thing again.
  variable warned
  if {![array exists warned]} { array set warned {} }

  ## THE INSERTION ORDER OF THE STORE KEYS (ruling DD-8). A plain LIST, not a
  ## dict and not an array: `array names` answers hash order, and reaching for
  ## `lsort` because an array offers no other deterministic order is exactly
  ## how both earlier attempts ended up ranking globs. Appended by `set_list`
  ## and by `_parse_line` the first time a key is seen, emptied by `reset`, and
  ## read back through `_keys` by the ONLY two consumers that need an order:
  ## `effective`, which returns the first matching flavor, and the writer,
  ## which appends new entries in the order the user made them.
  variable keyorder
  if {![info exists keyorder]} { set keyorder {} }

  ## WHAT THIS SESSION ACTUALLY CHANGED (ruling DD-7). Two sets, keyed exactly
  ## as their stores are: `dirty` on the store key, `dirtyclass` on the `type=`
  ## token. They are NOT provenance -- nothing here records which file a row
  ## came from, which is the design that lost rows twice. They record only that
  ## this session touched the thing, so the writer knows which of the target
  ## file's own rows it is entitled to rewrite and leaves every other row alone.
  ## Cleared by `reset` and by nothing else: a successful write does NOT clear
  ## them, so a user who saves both tiers gets the change in both.
  variable dirty
  if {![array exists dirty]} { array set dirty {} }
  variable dirtyclass
  if {![array exists dirtyclass]} { array set dirtyclass {} }

  ## WHAT THIS SESSION'S `apply` ACTUALLY WROTE, per `type=` token (issue 1292).
  ## One entry per type apply rewrote, holding FOUR {present value} pairs: the
  ## PRE-apply state of `params` and `shown`, and the state apply WROTE into
  ## each. Nothing else is recorded and no value is ever parsed.
  ##
  ## WHY IT EXISTS: `apply` is the only writer of `shown` and no verb removed
  ## it, so `reset` + `apply` -- which is exactly what a Reset/Defaults button
  ## is built on -- left the sheet narrowed for the rest of the session. The
  ## record is what lets `apply` UN-DO EXACTLY ITS OWN WRITE, in full or not at
  ## all: a descriptor whose `params`/`shown` are no longer byte-identical to
  ## what apply left there has been rewritten by someone else (a PDK, the
  ## user's rc under I5) and is dropped from the record and LEFT ALONE. Issue
  ## 1292 §4 option 1 asks for that distinction in so many words -- "removing a
  ## key THIS FILE wrote is not the same as rewriting a PDK's dict" -- and this
  ## is that distinction made real rather than stated in a comment.
  ##
  ## ⚠ `reset` DOES NOT CLEAR IT, deliberately: reset+apply IS the undo the
  ## record exists to serve. Clearing it there would make issue 1292 unfixable
  ## by the very pair of verbs the issue names.
  variable applied
  if {![array exists applied]} { array set applied {} }

  ## The report buffer. A LIST, one element per report, so a caller can count
  ## how many times the user was told something.
  variable reports
  if {![info exists reports]} { set reports {} }

  ## SENTENCES THE TERMINAL HAS ALREADY BEEN TOLD BY A READ THIS ONE REPLACES.
  ## `set_pdk`'s re-read parses the SAME two files again, so without this every
  ## per-row complaint in them -- a malformed row, an unknown keyword, a
  ## duplicate label -- would be printed to stderr TWICE on every workarea
  ## launch this tree ships, once by the startup read and once by the read that
  ## supersedes it. MEASURED before the gate, on the shipped sky130A rc.
  ##
  ## ⚠ IT GATES THE ECHO, NEVER THE BUFFER. `said` still receives every
  ## sentence, so nothing that COUNTS reports can be changed by this and no row
  ## moves; only the duplicate line on the user's terminal disappears.
  ## ⚠ AND ONLY `set_pdk` EVER FILLS IT, for the duration of its own re-read.
  ## It is not a general "tell me once" cache: two DIFFERENT problems still
  ## speak, and the same problem in a later session speaks again. `reset` does
  ## NOT clear it, because `set_pdk` resets in the middle of the window it owns.
  variable echoskip
  if {![info exists echoskip]} { set echoskip {} }

  variable scopes    {class flavor}
  variable listnames {annotation summary}
  ## Section 4.2's list 3. Live from the simulator, never persisted (D-4).
  variable livelist  all
  ## GRAMMAR v2 (issue 1277): a `flavor` row carries its class as a field.
  variable version   2
  variable basename  op_param_lists.conf

  ## -----------------------------------------------------------------------
  ## REPORTING. Reported and skipped, never obeyed (DD-3).
  ## The stderr prefix follows action_registry.tcl:329. It must NOT begin a
  ## line with `FAIL:` at column 0: full_audit.sh's has_failure() is
  ## `^(FAIL[: !]|...)`, so a store that echoed its reports that way would red
  ## its own suite from the outside.
  ## -----------------------------------------------------------------------
  proc _say {msg} {
    variable reports ; variable echoskip
    lappend reports $msg
    ## The buffer always gets it; the terminal is spared a sentence the read
    ## this one REPLACES already printed. See `echoskip` above.
    if {[lsearch -exact $echoskip $msg] < 0} {
      catch {puts stderr "op_param_lists: $msg"}
    }
    return {}
  }

  proc said {} { variable reports ; return $reports }

  proc said_clear {} { variable reports ; set reports {} ; return {} }

  ## Back to the shipped map and no user lists at all.
  ## ⚠ `applied` IS NOT CLEARED HERE. See its declaration above: reset+apply is
  ## the undo of issue 1292, so the record must survive the reset half of it.
  ## ⚠ NEITHER IS `pdkoverride` (issue 1388), and for a sharper reason: the
  ## PDK is a fact about the LAUNCH, not about the user's data. A Reset that
  ## also un-declared the PDK would answer a different settings file's rows
  ## afterwards, which is a mode change nobody asked a Reset button for.
  ## `forget_pdk` is the verb for that, and a suite that moves the PDK puts it
  ## back itself.
  proc reset {} {
    variable classmap ; variable defaultmap ; variable lists
    variable owned ; variable warned ; variable reports
    variable keyorder ; variable dirty ; variable dirtyclass
    variable loadedpdk
    array unset classmap
    array set classmap $defaultmap
    array unset lists
    array set lists {}
    array unset owned
    array set owned {}
    array unset warned
    array set warned {}
    set keyorder {}
    array unset dirty
    array set dirty {}
    array unset dirtyclass
    array set dirtyclass {}
    set reports {}
    ## THE ROWS ARE GONE, so "they were read under X" is no longer true of
    ## anything. Not the same as un-declaring the PDK, which `reset`
    ## deliberately does not do -- this is a fact about the STORE.
    set loadedpdk {}
    return {}
  }

  ## -----------------------------------------------------------------------
  ## THE CLASS MAP
  ## -----------------------------------------------------------------------
  ## op_param_lists::class <type-token> -> the broad class.
  ## Identity for a token nobody mapped. Never {} and never a raise: returning
  ## {} would silently lose the lists of every token nobody anticipated, and
  ## raising would contradict op_annot::descriptor's own rule that "this type is
  ## not annotated" is a DATA condition.
  proc class {token} {
    variable classmap
    if {[info exists classmap($token)]} { return $classmap($token) }
    return $token
  }

  ## The extension door. One line in a settings file, or one call from an rc.
  proc set_class {token cls} {
    variable classmap
    set classmap($token) $cls
    _mark_dirty class $token
    return $cls
  }

  ## -----------------------------------------------------------------------
  ## THE CLASS DISPLAY NAME (issue 1373)
  ## -----------------------------------------------------------------------
  ## op_param_lists::class_label <class-key> -> what a PERSON reads for it.
  ##
  ## ⚠ THE KEY DOES NOT MOVE.  A class key is the store's PRIMARY KEY -- it
  ## indexes `lists`, `owned` and `warned`, it is compared with `eq` by
  ## `_flavor_matches_class`, and it is a FIELD THE USER TYPES into a settings
  ## file (`list class mos annotation`, `param class mos ...`,
  ## `class nmos mos`).  MEASURED: `get_list class MOS annotation` is empty and
  ## `governs MOS annotation foo.sym` answers nothing, so `MOS` is a DIFFERENT
  ## KEY, not the same one shouted.  This proc therefore answers a string for
  ## PROSE ABOUT DEVICES and nothing else; it never renames anything.
  ##
  ## ⚠ SITES THAT MUST NOT BE ROUTED THROUGH IT, so the next reader does not
  ## "fix" the inconsistency in the wrong direction: `_dup_why` (:616),
  ## `set_list`'s key reports, `_key_why` (:442), `seed`'s divergence report
  ## (:960) and the parser's reports.  Every one of those prints the class as a
  ## SETTINGS-FILE FIELD the user types back, and keys are case-sensitive, so a
  ## user who reads `MOS` there and writes `list class MOS annotation` gets a
  ## silently dead entry.  `seed`'s report also names the type tokens beside the
  ## class, which is the other reason it keeps the key spelling.
  ##
  ## ⚠ AND IT IS A TABLE, NOT `string toupper`.  The user's rule is "acronyms
  ## upper case", not "everything upper case": the identity fallthrough of
  ## `class` above mints keys like `pwell_resistor`, `high_precision_p` and
  ## `subcircuit` from any PDK's `type=` tokens, and shouting those would be a
  ## second defect wearing the first one's fix.  Only rows whose display
  ## DIFFERS from the key are listed; `resistor`, `capacitor`, `diode` and
  ## `bipolar` are already their own human spelling and reach the user through
  ## the SAME identity return an unmapped key takes.
  ##
  ## ⚠ IT LIVES HERE, NOT IN rdw.tcl, AND THERE IS NO `rdw::_class_name`
  ## WRAPPER.  This file may not call `rdw::` (SOURCE-TIME PURITY, above), so
  ## an accessor over there could never be reached by the store's own
  ## sentences -- and a second copy is the two-wordings-for-one-fact drift that
  ## `rdw::_list_name`/`_list_gloss` were written to stop one concept over.
  ## ONE door: every surface calls this one.
  ##
  ## Ratified so far: the user's own words, "why is that not uppercase? MOS is
  ## an acronym!".  NPN, PNP and ESD are the same rule applied to the other
  ## acronym keys the identity fallthrough really mints on the shipped sky130
  ## and IHP trees.  Whether the table should also carry prose for the
  ## snake_case sky130 keys, and whether `bipolar` should read `BJT`, is the
  ## user's vocabulary and is on the owed ledger as rule debt 1373.
  variable classlabel
  if {![array exists classlabel]} {
    array set classlabel {
      mos   MOS
      npn   NPN
      pnp   PNP
      esd   ESD
    }
  }

  proc class_label {cls} {
    variable classlabel
    if {[info exists classlabel($cls)]} { return $classlabel($cls) }
    return $cls
  }

  ## The extension door, matching `set_class` above: one call from an rc for a
  ## PDK whose class keys this table has never heard of.  Deliberately NO
  ## `_mark_dirty`: a display name is not a settings-file field, so there is
  ## nothing for the writer to round-trip and marking it dirty would make the
  ## store offer to save a grammar row that does not exist.
  proc set_class_label {cls label} {
    variable classlabel
    set classlabel($cls) $label
    return $label
  }

  ## -----------------------------------------------------------------------
  ## KEYS AND VALIDATION
  ## -----------------------------------------------------------------------
  ## THE ONE KEY BUILDER, AND IT CANONICALISES (invariant I1). A flavor key is
  ## the TWO-ELEMENT list {<class> <cell-name glob>}; the store key stays THREE
  ## elements so `lindex $k 2` is still the listname for every scope.
  ##
  ## ⚠ THE CANONICALISATION IS THE WHOLE OF ISSUE 1277's KEY-IDENTITY HOLE. An
  ## earlier attempt used an uncanonicalised two-element list as an array index,
  ## so a hand-typed key and a parsed one landed in DIFFERENT slots: a re-set
  ## emitted two conflicting rows and the reader discarded one with nothing said
  ## anywhere. `[list [lindex $key 0] [lindex $key 1]]` is idempotent for every
  ## glob shape the format can carry, so the hand-typed spelling and the parsed
  ## one collapse onto one index -- at ONE door, not four.
  proc _key {scope key listname} {
    if {$scope eq "flavor"} {
      if {![catch {list [lindex $key 0] [lindex $key 1]} ck]} { set key $ck }
    }
    return [list $scope $key $listname]
  }

  ## THE KEY'S SHAPE, PER SCOPE (grammar v2). Answers {} when the key is
  ## storable and a SENTENCE when it is not, so both doors report the same thing
  ## and neither can store a key no reader will ever look for.
  ##   class  -> one non-empty whitespace-free token
  ##   flavor -> exactly {<class> <cell-name glob>}, both fields non-empty and
  ##             whitespace-free, because the settings file is
  ##             whitespace-delimited and a field with a space in it could not
  ##             be read back.
  proc _key_why {scope key} {
    if {$scope eq "flavor"} {
      if {[catch {llength $key} n]} {
        return "the flavor key \"$key\" is not a well-formed list; grammar v2 wants {<class> <cell-name glob>}"
      }
      if {$n != 2} {
        return "the flavor key \"$key\" has $n fields; grammar v2 wants exactly two, {<class> <cell-name glob>}"
      }
      foreach fld $key {
        if {$fld eq {} || [regexp {\s} $fld]} {
          return "the flavor key \"$key\" has a field that is empty or carries whitespace, so it could not be written back"
        }
      }
      return {}
    }
    if {$key eq {} || [regexp {\s} $key]} {
      return "the $scope key \"$key\" is empty or carries whitespace, so it could not be written back"
    }
    return {}
  }

  ## THE KEY AS FILE FIELDS. A flavor key becomes TWO unquoted fields; every
  ## other scope is one.
  ## ⚠ THIS IS THE METACHARACTER FIX AND IT IS THE WRITER'S, NOT THE READER'S.
  ## `puts $fp "list $scope $key $ln"` interpolates a two-element key WHOLE, so
  ## Tcl's list-to-string rule escapes any list metacharacter in the glob while
  ## the reader's plain whitespace split reads the escape LITERALLY. Measured on
  ## the earlier attempt, every one of these read back different with no report:
  ##   a{b* -> a\{b*   a}b* -> a\}b*   a[b* -> {a[b*}   a\b* -> {a\b*}
  ## Emitting the fields SEPARATELY carries all of them unchanged, which is why
  ## the other arm -- refuse a metacharacter at write time -- is not taken: it
  ## would cost `[nm]` and `\*`, both documented `string match` features, to
  ## solve a problem the writer created. `_key_why` already refuses whitespace
  ## at both doors, so nothing that reaches here can split into the wrong count.
  ## BOTH the `list` row and the `param` row go through here: fixing only one
  ## would turn a corrupted glob into a corrupted glob whose EMPTINESS is also
  ## lost, because the `list` row is what carries an emptied list.
  proc _key_fields {scope key} {
    if {$scope eq "flavor"} { return "[lindex $key 0] [lindex $key 1]" }
    return $key
  }

  ## DOES THIS FLAVOR ENTRY BELONG TO THIS CLASS? Grammar v2's whole point, and
  ## the half of issue 1277 that ruling DD-8 keeps: before it a flavor entry
  ## carried no class at all and answered every query whose cell name its glob
  ## happened to match, so a capacitor could be answered by a list somebody
  ## wrote with MOS in mind.
  proc _flavor_matches_class {k cls} {
    set kk [lindex $k 1]
    if {[catch {llength $kk} n]} { return 0 }
    if {$n != 2} { return 0 }
    return [expr {[lindex $kk 0] eq $cls ? 1 : 0}]
  }

  ## THE FIELD COUNT ONE ROW OF THE GRAMMAR HAS. It depends on the SCOPE, which
  ## is why `_parse_line` validates the scope before it counts fields.
  proc _row_arity {verb scope} {
    set n [expr {$verb eq "list" ? 4 : 7}]
    if {$scope eq "flavor"} { incr n }
    return $n
  }

  ## ONE FIELDS-TO-KEY BUILDER, used by the READER and by the WRITER's merge
  ## classifier (invariant I1). The alternative is a second, laxer grammar
  ## reader inside the writer, and when the two disagree the writer either
  ## duplicates a row or replaces the wrong one, silently.
  ## Answers {} for anything that is not a well-formed data row of this
  ## grammar -- and a row the writer cannot identify is a row it copies
  ## verbatim, which is the safe direction under DD-7.
  ## ⚠ EVERY GATE THE READER APPLIES IS APPLIED HERE TOO -- ISSUE 1294, AND IT
  ## IS THE DEFECT THAT REVERTED ITEM B2c.
  ##
  ## This proc used to stop after verb + scope + arity, which made it LAXER
  ## than `_parse_line`. Under ruling DD-7 the writer merges by identifying
  ## rows, so a row the READER refused but the WRITER could still identify was
  ## treated as part of a dirty key's group and DROPPED. Measured, with
  ## `param class mos annotation NEWROW raw ratio` -- seven fields, verb
  ## `param`, scope `class`, and a kind the reader rejects:
  ##
  ##     load:  <path>:3: kind "ratio" is not an integer   (READER refuses)
  ##     save:  write=1  writereports=0  NEWROW_kept=0     (WRITER deletes)
  ##
  ## rc=1, zero reports, a line the user typed destroyed -- byte-for-byte the
  ## signature that reverted B2a and B2a-2. Reproduced for 5/5 unreadable
  ## kinds. And it falsifies BOTH of DD-7's public promises at once: "you
  ## cannot delete a row you never parsed into a model" is only true while the
  ## writer cannot IDENTIFY such a row, and the emitted header's "rows a newer
  ## xschem wrote that this one does not understand" is exactly this case --
  ## a newer build that extends a VALUE vocabulary rather than adding a
  ## keyword writes a known verb with a field this build cannot read.
  ##
  ## ⚠ SO THE RULE IS NOT "share a key builder", IT IS "the two doors reach the
  ## SAME VERDICT ON EVERY LINE". Row Y1 drives a corpus through both and
  ## asserts they agree, which fences the divergence itself rather than the one
  ## instance of it that was measured.
  ##
  ## An unidentifiable row is copied VERBATIM by the writer, which is the safe
  ## direction: the cost of failing to recognise a row is a duplicate the user
  ## can see and delete, and the cost of wrongly recognising one is a silent
  ## deletion they cannot.
  proc _row_id {f} {
    set verb [lindex $f 0]
    if {$verb ne "list" && $verb ne "param"} { return {} }
    if {[llength $f] < 2} { return {} }
    set scope [lindex $f 1]
    if {![_valid_scope $scope]} { return {} }
    if {[llength $f] != [_row_arity $verb $scope]} { return {} }
    if {$scope eq "flavor"} {
      set key  [list [lindex $f 2] [lindex $f 3]]
      set ln   [lindex $f 4]
      set rest 5
    } else {
      set key  [lindex $f 2]
      set ln   [lindex $f 3]
      set rest 4
    }
    ## The reader's remaining gates, in the reader's own order.
    variable livelist
    if {$ln eq $livelist} { return {} }
    if {![_valid_list $ln]} { return {} }
    if {$verb eq "param"} {
      if {[_triple [list [lindex $f $rest] [lindex $f [expr {$rest + 1}]] \
                         [lindex $f [expr {$rest + 2}]]]] eq {}} { return {} }
    }
    return [_key $scope $key $ln]
  }

  ## THE STORE KEYS IN THE ORDER THEY WERE FIRST SEEN (ruling DD-8). This is
  ## the accessor that replaced `lsort [array names owned]` in `effective` and
  ## in the writer. Renaming it is the sabotage that puts the ranking back.
  proc _keys {} {
    variable keyorder ; variable owned
    set out {}
    foreach k $keyorder { if {[info exists owned($k)]} { lappend out $k } }
    return $out
  }

  proc _key_touch {k} {
    variable keyorder
    if {[lsearch -exact $keyorder $k] < 0} { lappend keyorder $k }
    return {}
  }

  ## THE DIRT (ruling DD-7). `kind` is `class` for a `type=` token and `list`
  ## for a store key. One predicate, so a reviewer can disable it and watch the
  ## suite say which promise broke.
  proc _mark_dirty {kind id} {
    variable dirty ; variable dirtyclass
    if {$kind eq "class"} { set dirtyclass($id) 1 } else { set dirty($id) 1 }
    return {}
  }

  proc _is_dirty {kind id} {
    variable dirty ; variable dirtyclass
    if {$kind eq "class"} { return [expr {[info exists dirtyclass($id)] ? 1 : 0}] }
    return [expr {[info exists dirty($id)] ? 1 : 0}]
  }

  ## THE DUPLICATE-LABEL RULE, IN ONE PLACE, FOR BOTH DOORS (issue 1288).
  ## `set_list` and the file parser are the only two ways an entry enters the
  ## store and they used to disagree about the very same input: the parser
  ## replaced the earlier triple in place and said so, `set_list` accepted both
  ## rows in silence and `_save_set`'s first-wins dedup then dropped the user's
  ## second row with nothing said anywhere. The parser is right, so the parser's
  ## rule lives here and both doors call it.
  proc _dup_index {cur label} {
    set i 0
    foreach e $cur {
      if {![catch {lindex $e 0} l] && $l eq $label} { return $i }
      incr i
    }
    return -1
  }

  proc _dup_why {label scope key listname} {
    return "a second entry for label \"$label\" in $scope $key $listname; the later one replaces it in place"
  }

  proc _valid_scope {scope} {
    variable scopes
    return [expr {[lsearch -exact $scopes $scope] >= 0 ? 1 : 0}]
  }

  proc _valid_list {listname} {
    variable listnames
    return [expr {[lsearch -exact $listnames $listname] >= 0 ? 1 : 0}]
  }

  ## THE ONE NORMALISER. Every stored entry passes through here, so the store
  ## has exactly one idea of what an entry is: THREE fields, all three carried.
  ## Answers {} for anything it cannot store -- and a whitespace-bearing field
  ## is one of those, because the settings file is whitespace-delimited and a
  ## field with a space in it could not be read back.
  ## The kind is any INTEGER: the store is deliberately not stricter than
  ## op_annot::_wrap, whose default arm copies token.c's "anything but 0/1 is
  ## v(...)" convention, so a PDK that starts using a fourth kind is not gated
  ## by this file.
  proc _triple {t} {
    if {[catch {llength $t} n]} { return {} }
    if {$n != 3} { return {} }
    foreach f $t {
      if {$f eq {}} { return {} }
      if {[regexp {\s} $f]} { return {} }
    }
    if {![string is integer -strict [lindex $t 2]]} { return {} }
    return [list [lindex $t 0] [lindex $t 1] [lindex $t 2]]
  }

  ## -----------------------------------------------------------------------
  ## THE LISTS
  ## -----------------------------------------------------------------------
  proc owns {scope key listname} {
    variable owned
    if {![_valid_scope $scope]} { return 0 }
    if {![_valid_list $listname]} { return 0 }
    return [expr {[info exists owned([_key $scope $key $listname])] ? 1 : 0}]
  }

  proc get_list {scope key listname} {
    variable lists
    if {![owns $scope $key $listname]} { return {} }
    return $lists([_key $scope $key $listname])
  }

  ## Store one whole list.
  ##
  ## ⚠ THE CONTRACT MOVED, DELIBERATELY (issue 1288, ladder L3). It used to read
  ## "Returns 1, or 0 WITH A REPORT and no change at all". That still holds of a
  ## MALFORMED TRIPLE -- half a list is a list the user never chose -- but a
  ## repeated LABEL is now a REDUCTION, not a refusal: the later triple replaces
  ## the earlier one IN PLACE, the user is told once, and the call returns 1.
  ## That is what the file parser has always done with the same input, and issue
  ## 1288 requires the two doors to reach the same verdict with the same
  ## sentence. The alternative -- refuse, and keep the old wording -- leaves the
  ## two doors disagreeing about the same rule, which is the defect itself.
  proc set_list {scope key listname triples} {
    variable lists ; variable owned
    if {![_valid_scope $scope]} {
      _say "unknown scope \"$scope\"; expected `class` or `flavor`"
      return 0
    }
    variable livelist
    if {$listname eq $livelist} {
      _say "the `$livelist` list is live from the simulator and is never stored (ruling D-4)"
      return 0
    }
    if {![_valid_list $listname]} {
      _say "unknown list name \"$listname\"; expected `annotation` or `summary`"
      return 0
    }
    set why [_key_why $scope $key]
    if {$why ne {}} {
      _say $why
      return 0
    }
    if {[catch {llength $triples} n]} {
      _say "the $scope list \"$key $listname\" is not a well-formed list ($triples)"
      return 0
    }
    set out {}
    foreach t $triples {
      set tt [_triple $t]
      if {$tt eq {}} {
        _say "refusing the $scope list \"$key $listname\": the entry \"$t\" is not a {label param kind} triple of three whitespace-free fields with an integer kind"
        return 0
      }
      ## The file parser's own rule, through the shared predicate (issue 1288).
      set hit [_dup_index $out [lindex $tt 0]]
      if {$hit >= 0} {
        _say [_dup_why [lindex $tt 0] $scope $key $listname]
        set out [lreplace $out $hit $hit $tt]
      } else {
        lappend out $tt
      }
    }
    set k [_key $scope $key $listname]
    set lists($k) $out
    set owned($k) 1
    _key_touch $k
    ## Changed HERE, so the tier saved next is entitled to rewrite this key's
    ## rows in its own file and nothing else (ruling DD-7).
    _mark_dirty list $k
    return 1
  }

  ## WOULD A `set_list` OF THIS VALUE DROP A ROW? (issue 1323)
  ##
  ## ⚠ A REORDER BECAME A DELETION, AND THAT VIOLATES RULINGS DD-4 AND DD-6.
  ## `op_annot::register` accepts a `params` list carrying two triples that
  ## share a LABEL; `_params` reads that declaration verbatim (ruling DD-13),
  ## `seed` returns it undeduped and `effective` hands it out as the base a
  ## reorder swaps two elements of. `set_list` then applies the duplicate-label
  ## rule and the list comes back SHORTER. MEASURED end to end at HEAD:
  ##     base           {id ids 0} {id vgs 2} {gm gm 1}
  ##     an Up press    {id vgs 2} {id ids 0} {gm gm 1}
  ##     effective      {id ids 0} {gm gm 1}
  ##     .save cards    m1[ids] m1[gm]   -- m1[vgs] IS GONE FROM THE DECK
  ## `apply` unions through `_save_set` and `_merge_declared`, both of which
  ## dedupe by label again, so nothing downstream can put the row back. An Up
  ## press is not even a Delete, and DD-4/DD-6 say in one sentence that a
  ## display decision never changes what the simulator is asked to save.
  ##
  ## ⚠ THE GUARD RUNS BEFORE THE WRITE, NOT AFTER IT, AND THAT REFUTES THE
  ## ISSUE'S OWN RECOMMENDED WORDING. Issue 1323 recommends "after the write,
  ## if the stored list is shorter than the base, restore the base and refuse".
  ## THAT CANNOT RESTORE: a `set_list` of the base dedupes it identically, so
  ## the "restore" would store `{id vgs 2} {gm gm 1}` -- a THIRD value neither
  ## the user nor the PDK ever chose -- and when the base came from the SEED
  ## the key was previously UNOWNED, which no verb in this store can undo.
  ##
  ## ⚠ ONE RULE, TWO READERS -- the `governs` precedent, applied to
  ## `_dup_index`. `set_list` is UNCHANGED: issue 1288's ruling stands, both
  ## doors still reach the same verdict with the same sentence, and this verb
  ## adds a READER rather than a rule.
  ##
  ## ⚠ THIS HEADER USED TO REJECT MAKING `op_annot::register` REFUSE, AND
  ## RULING DD-15 OVERRULES THAT CLAUSE. It is rewritten rather than left,
  ## because a comment that contradicts a binding ruling is how the next reader
  ## re-derives a settled question. What was argued here -- "it punishes the PDK
  ## author" -- was aimed at issue 1326's option (a), refusing the DELETE, which
  ## breaks a button for every press of that class with a sentence about a row
  ## the user never touched. DD-15 took option (c) instead: `op_annot::register`
  ## refuses a DECLARATION carrying two triples that share a display label, once,
  ## where the ambiguity is introduced (`op_annot::_dup_declared_label`).
  ##
  ## ⚠ AND THIS VERB STAYS, AS THE SECOND DOOR. DD-15 shuts the declaration; it
  ## does not and cannot shut `::op_annot::desc`, which a fixture, an older
  ## session's stored state, or any code assigning the array directly still
  ## reaches. One rule, two doors -- which is the principle DD-15 itself names.
  ##
  ## TWO ROUTES ARE STILL REJECTED, AND THE ISSUE REJECTS THEM TOO: making
  ## `seed` dedupe (it re-splits the declaration from the seed, which is the
  ## split ruling DD-13 exists to remove) and making `set_list` keep duplicates
  ## (it reopens 1288, and `_key`, `_save_set` and `_merge_declared` all assume
  ## label uniqueness).
  ##
  ## THE WORDING IS NEW BECAUSE THE FACT IS NEW. `_dup_why` says a row WAS
  ## replaced in place; this says a row WOULD BE DROPPED and the write has not
  ## happened. Two wordings for two facts, never two for one.
  ##
  ## -> {} when a `set_list` of these triples would store every row -- which
  ##    includes every malformed list, because that is a REFUSAL with its own
  ##    sentence and not a reduction.
  ## -> the sentence when it would REDUCE the list.
  proc reduce_why {scope key listname triples} {
    if {[catch {llength $triples}]} { return {} }
    set seen {}
    foreach t $triples {
      set tt [_triple $t]
      if {$tt eq {}} { return {} }
      set l [lindex $tt 0]
      if {[_dup_index $seen $l] >= 0} {
        return "this change would DROP a row: the list carries more than one entry for label \"$l\", and $scope $key $listname keeps one entry per label, so storing it would leave fewer rows than it started with. A reorder must not remove a parameter the simulator is asked to save."
      }
      lappend seen $tt
    }
    return {}
  }

  ## -----------------------------------------------------------------------
  ## DESCRIPTOR KEY STATE: {present value}
  ## -----------------------------------------------------------------------
  ## A key's whole state as ONE comparable value, because ABSENT and PRESENT
  ## AND EMPTY are different facts about a descriptor (ruling DD-6's row D10
  ## turns on exactly that) and a plain `dict get` collapses them. Used by the
  ## declaration read below and by the issue-1292 undo further down; nothing
  ## here parses a value and nothing here raises.
  proc _key_state {d key} {
    if {[catch {dict exists $d $key} has]} { return [list 0 {}] }
    if {!$has} { return [list 0 {}] }
    if {[catch {dict get $d $key} v]} { return [list 0 {}] }
    return [list 1 $v]
  }

  ## Is <key> of <d> still in exactly <state>? Byte comparison, both halves.
  proc _state_eq {d key state} {
    return [expr {[_key_state $d $key] eq $state ? 1 : 0}]
  }

  ## Put <key> of <d> back into <state>: SET when it was present, REMOVE when
  ## it was absent. An undo that can only set would leave a key this file
  ## created behind, which is the whole of issue 1292.
  proc _apply_state {d key state} {
    if {[lindex $state 0]} {
      if {[catch {dict set d $key [lindex $state 1]} d2]} { return $d }
      return $d2
    }
    if {[catch {dict unset d $key} d2]} { return $d }
    return $d2
  }

  ## -----------------------------------------------------------------------
  ## THE PDK SEED (D-7)
  ## -----------------------------------------------------------------------
  ## The params of ONE registered type, read through the published accessor.
  ## Never enumerates ::op_annot::desc: the candidate types for a class are the
  ## tokens the CLASS MAP sends there, so this file reaches into no other
  ## namespace's internals and a class nobody registered answers {}.
  ##
  ## THE FIELD PICKER, AND THE ONE PLACE THE DECLARATION IS READ.
  ## {1 <value>} when the descriptor carries a declaration, {0 {}} when it does
  ## not. Its own proc so the read has exactly ONE site: `_params` below is the
  ## only reader of the key anywhere in the tree, and this is the only line of
  ## `_params` that knows the key's name.
  proc _decl_state {d} {
    return [_key_state $d declared]
  }

  proc _params {type} {
    if {[catch {::op_annot::descriptor $type} d]} { return {} }
    if {$d eq {}} { return {} }
    ## ⚠ THE DECLARATION, NOT `params` -- RULING DD-13, ISSUE 1312.
    ## `apply` writes the annotation+summary UNION into `params`, and this proc
    ## is what `seed` calls "the PDK's own list". Reading them out of ONE field
    ## meant that after the first apply the seed was whatever the last apply
    ## computed: two broad-scope Deletes took a parameter out of `params`, out
    ## of the seed and out of the SIBLING type, the `.save` card went with it,
    ## and Add had no source left to put it back. Measured by item B5; the
    ## exact inverse of DD-4/DD-6, whose whole content is that Delete changes
    ## what is DRAWN and never what the simulator computes.
    ## `op_annot::register` is the declaration's only writer (op_annot.tcl's
    ## `_declare`), and it PRESERVES one it is handed, so `apply` -- which
    ## round-trips the dict it read -- cannot reach it.
    ##
    ## THE ABSENT-KEY FALLBACK IS LOAD-BEARING, NOT A COURTESY. Every
    ## descriptor that never passed through `register` carries no declaration
    ## and must answer exactly the bytes it answers today (invariant I7). The
    ## same string is then validated the same way, and the report names WHICH
    ## list was dropped, because after an apply the two fields can differ and a
    ## message blaming `params` for a `params` that parses fine is invariant
    ## I3's family one layer up.
    set _st [_decl_state $d]
    if {[lindex $_st 0]} {
      set p [lindex $_st 1]
      set what declaration
    } else {
      if {[catch {dict exists $d params} has]} { return {} }
      if {!$has} { return {} }
      if {[catch {dict get $d params} p]} { return {} }
      set what params
    }
    if {[string trim $p] eq {}} { return {} }
    ## ⚠ THE PDK'S LIST IS AN UNVALIDATED STRING AND THIS IS THE ONLY DOOR
    ## IT ENTERS THE STORE BY -- ISSUE 1291.
    ## Every guard above answers a question about the DICT; none asks whether
    ## the value is a well-formed Tcl LIST. It need not be: a descriptor may be
    ## registered from a user's own rc (invariant I5, which is the documented
    ## way to choose a different parameter set), and issue 0447's live shape is
    ## a valid triple followed by an unclosed open brace -- row K17 of
    ## test_op_annot golds that exact string. (It is not written out here: an
    ## unbalanced brace in a comment makes THIS file fail `info complete`,
    ## which is how this comment was first written and immediately caught.)
    ##
    ## Returned verbatim, that string reaches `foreach t [effective ...]` in
    ## _save_set and _show_set and RAISES `unmatched open brace in list`. Item
    ## B2b opened that door without meaning to: HEAD's apply never called seed
    ## at all, and the union is what made the seed reachable. Measured: apply
    ## went rc=0 -> rc=1, wrote nothing, and left the descriptor permanently
    ## un-applyable for the rest of the session.
    ##
    ## ⚠ BOTH LEVELS ARE CHECKED, because both raise. A malformed OUTER list
    ## breaks `foreach`; a well-formed outer list holding a malformed ELEMENT
    ## breaks the `lindex` that reads the triple one line later. Answering {}
    ## for the whole descriptor is deliberate: half a parameter list is not a
    ## safer answer than none, and the report says which type was dropped.
    if {[catch {llength $p}]} {
      _say "the descriptor for `$type` has a $what list that does not parse;\
            ignoring it. Fix it in the rc that registered it."
      return {}
    }
    foreach _row $p {
      if {[catch {llength $_row}]} {
        _say "the descriptor for `$type` has a $what row that does not parse;\
              ignoring the whole list. Fix it in the rc that registered it."
        return {}
      }
    }
    return $p
  }

  ## op_param_lists::seed <class> -> the PDK's ordered triples for that class.
  ##
  ## THE MAP IS NOT ONTO and that is normal: IHP registers `vertical_npn` and
  ## no `vertical_pnp` though section 4.3's map names both, and three of the
  ## five shipped classes (resistor, capacitor, diode) are registered by no PDK
  ## in this tree at all. Each answers {} without raising.
  ##
  ## WHEN TWO TYPES IN ONE CLASS DISAGREE: the FIRST WINS and the divergence is
  ## reported ONCE. NOTHING IS EVER MERGED -- a merged list is one no PDK ever
  ## declared, which is the invented data D-4 forbids.
  ## "First" is spelled FIRST IN LEXICAL ORDER OF THE `type=` TOKEN, not first
  ## registered: ::op_annot::desc is a Tcl ARRAY, `array names` answers hash
  ## order, and op_annot publishes no enumerator, so registration order is not
  ## available to any caller. Lexical order is deterministic and COINCIDES with
  ## registration order for every PDK in this tree (each registers via
  ## `foreach t {nmos pmos}`). The missing enumerator is filed as issue 1274,
  ## not fixed here -- this item may not edit op_annot.tcl.
  ## No shipped PDK produces the disagreement: all three register nmos and pmos
  ## with byte-identical params.
  proc seed {cls} {
    variable classmap ; variable warned
    set cands [list $cls]
    foreach t [array names classmap] {
      if {$classmap($t) eq $cls} { lappend cands $t }
    }
    set best {} ; set winner {} ; set others {}
    foreach t [lsort -unique $cands] {
      set p [_params $t]
      if {$p eq {}} { continue }
      if {$winner eq {}} {
        set winner $t
        set best $p
        continue
      }
      if {$p ne $best} { lappend others $t }
    }
    if {[llength $others] && ![info exists warned($cls)]} {
      set warned($cls) 1
      _say "class \"$cls\" is seeded by types whose PDK lists disagree: \"$winner\" comes first and wins; [join $others {, }] ignored. Nothing is merged."
    }
    return $best
  }

  ## -----------------------------------------------------------------------
  ## RESOLUTION (DD-2): flavor beats class beats the PDK seed
  ## -----------------------------------------------------------------------
  ## The flavor key is a CELL-NAME GLOB matched with `string match -nocase`,
  ## which is the narrowing op_annot::_matches (op_annot.tcl:411) already
  ## performs over `getprop instance <n> cell::name`. Inventing a second flavor
  ## concept keyed on anything else would fork the narrowing.
  ## DD-2's own sentence: `nfet_01v8_lvt` with no entry of its own uses the
  ## `mos` lists.
  ##
  ## ⚠ PRECEDENCE IS FILE ORDER AND NOTHING IS RANKED (ruling DD-8). The scan
  ## used to be `foreach k [lsort [array names owned]]`, returning the first
  ## glob that matched. `lsort` orders by the character after the leading `*`,
  ## so with `*fet*` and `*nfet_01v8*` both matching `nfet_01v8_lvt` the BROAD
  ## one won -- in BOTH insertion orders -- and the winner FLIPPED when the
  ## LOSER was merely renamed. Two later attempts replaced that with a
  ## narrowness ranking and both shipped a bare `*` beating a specific pattern,
  ## which is how the ranking died: "narrower" has no defensible total order
  ## over globs. `_keys` answers the order the entries were declared in, which
  ## for a settings file IS the order of its rows, so the file is its own
  ## documentation and the user reorders with the buttons they already have.
  ##
  ## ⚠ THE SCAN IS `governs`, AND `effective` IS ITS FIRST CONSUMER (item B5-2,
  ## invariant I1). The two used to be one proc, and item B5's button column
  ## then asked a DIFFERENT question to find the entry a reorder should be
  ## written at -- exact-key `owns flavor {<cls> <cellname>}`. MEASURED with a
  ## flavor entry `{b5cls *b5n*}` governing cell `devices/b5n`:
  ##     effective b5cls annotation devices/b5n     -> the FLAVOR list
  ##     owns flavor {b5cls devices/b5n} annotation -> 0
  ## so the exact-key question answered "no flavor entry" about a device whose
  ## every read goes through one, and the button edited a list the device does
  ## not read. That is ONE narrowing with TWO lookalike definitions, which is
  ## invariant I1's exact failure shape. Splitting the scan out gives the
  ## narrowing one definition and two readers, and row BG1 locks the two
  ## together by asserting `get_list` of what `governs` NAMES is byte-identical
  ## to `effective` of the same three arguments.
  ##
  ##   governs {cls listname {cellname {}}}
  ##     -> {flavor {<cls> <glob>}}   a flavor entry answered
  ##     -> {class <cls>}             the class entry answered
  ##     -> {}                        nothing is owned; the PDK seed answered
  proc governs {cls listname {cellname {}}} {
    if {![_valid_list $listname]} { return {} }
    if {$cellname ne {}} {
      foreach k [_keys] {
        if {[lindex $k 0] ne "flavor"} { continue }
        if {[lindex $k 2] ne $listname} { continue }
        if {![_flavor_matches_class $k $cls]} { continue }
        if {[string match -nocase [lindex [lindex $k 1] 1] $cellname]} {
          return [list flavor [lindex $k 1]]
        }
      }
    }
    if {[owns class $cls $listname]} { return [list class $cls] }
    return {}
  }

  proc effective {cls listname {cellname {}}} {
    if {![_valid_list $listname]} { return {} }
    set g [governs $cls $listname $cellname]
    if {$g eq {}} { return [seed $cls] }
    return [get_list [lindex $g 0] [lindex $g 1] $listname]
  }

  ## -----------------------------------------------------------------------
  ## THE PDK IDENTITY, AND THE SECTION HEADER (issue 1388)
  ## -----------------------------------------------------------------------
  ## ⚠ WHAT IS ACTUALLY SET, MEASURED 2026-09-08 IN THIS TREE'S OWN THREE PDK
  ## WORKAREAS, because three of the four candidates read plausibly and only
  ## one of them survives contact:
  ##
  ##   workarea      env(PDK)     env(PDK_ROOT)  ::PDK      XSCHEM_LIBRARY_PATH
  ##   sky130A       sky130A      UNSET          sky130A    {} (EMPTY)
  ##   gf180mcuD     gf180mcuD    UNSET          UNSET      {} (EMPTY)
  ##   ihp-sg13g2    ihp-sg13g2   UNSET          UNSET      {} (EMPTY)
  ##
  ##   * `env(PDK)` is set by ALL THREE (each rc's `if {![info exists
  ##     ::env(PDK)]} { set ::env(PDK) <name> }`), the values are distinct, and
  ##     they are the names a person would type. IT IS THE ONE THAT WORKS.
  ##   * `env(PDK_ROOT)` is set by NONE of them. sky130A sets a TCL GLOBAL
  ##     `::PDK_ROOT`, and it is `/home/analog/eda/tools/share/pdk` -- the
  ##     directory that HOLDS pdks, identical for every PDK installed beside
  ##     each other. IT IS A LOCATION, NOT AN IDENTITY: keyed on it, every PDK
  ##     in an open_pdks install would share one section called `pdk`.
  ##   * `$::XSCHEM_LIBRARY_PATH` is EMPTY in all three -- every workarea is
  ##     registry-only Cadence mode and sets `set XSCHEM_LIBRARY_PATH {}`. It
  ##     does not distinguish the three PDKs; it distinguishes NOTHING.
  ##     (`XSCHEM_LIBRARY_DEFS` does differ, but it is a path to a
  ##     `library.defs`, and taking a PDK NAME out of it means guessing which
  ##     path component is the PDK -- the invention ruling D-4 forbids.)
  ##   * THE REGISTERED `op_annot` DESCRIPTORS CANNOT TELL sky130A FROM
  ##     gf180mcuD, WHICH IS THE USER'S OWN EXAMPLE. Measured: both register
  ##     exactly {nmos pmos} and both declare byte-identical
  ##     `{id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}`.
  ##     Only IHP differs ({nmos pmos vertical_npn}, and `{id ids 0}`). The
  ##     semantically honest candidate is the one that cannot answer the
  ##     question that was asked.
  ##
  ## ⚠ AND THE HARD PART IS NOT WHICH VARIABLE, IT IS *WHEN*. MEASURED: the
  ## startup `catch {::op_param_lists::load}` (xschem.tcl:17550) runs while
  ## xschem.tcl is being sourced, and a PDK workarea is entered with
  ## `--script <workarea>/cadence_style_rc`, which xinit.c:3793 sources AFTER
  ## that. So at load time `env(PDK)` is UNSET for every launch this tree's own
  ## PDK launcher makes -- the probe printed `env(PDK) = <UNSET>` at the top of
  ## the --script phase, which is already later than `load`. A per-PDK settings
  ## file whose PDK is unknown when the file is read is not a feature.
  ## TWO SUPPORTED ORDERS, AND BOTH ARE REAL:
  ##   (a) `PDK` exported in the ENVIRONMENT before launch -- the open_pdks
  ##       convention, and the case that needs no code at all: `load` sees it.
  ##   (b) the workarea rc DECLARES it, with `op_param_lists::set_pdk`, which
  ##       RE-READS the two tiers because the first read could not have known.
  ##       The three shipped `cadence_style_rc` files call it, beside the
  ##       `env(PDK)` line they already had.
  ## Rejected: making `load` lazy so it happens after the rc. Its own comment
  ## (xschem.tcl:17532) rules that out -- "initial state" would then depend on
  ## which door the user opened first.
  ##
  ## SOURCE-TIME PURITY IS INTACT: these are literals, and nothing below reads
  ## the environment until a proc is called.
  ##
  ## `pdkoverride` is a LIST, not a string: empty means "nobody declared one,
  ## ask the environment", and a ONE-ELEMENT list is a declaration -- which may
  ## declare the EMPTY string, meaning "this launch has no PDK" even though the
  ## environment names one. Collapsing the two would make `set_pdk {}`
  ## ambiguous, which is the {present value} distinction `_key_state` already
  ## draws one concept over.
  variable pdkoverride
  if {![info exists pdkoverride]} { set pdkoverride {} }

  ## THE PDK THE STORE'S ROWS WERE ACTUALLY READ UNDER. Same LIST shape as
  ## `pdkoverride`: empty means "nothing has been loaded", a one-element list
  ## is the PDK the last `load` ran under, and that element may be the EMPTY
  ## STRING, which is the ordinary startup case.
  ##
  ## ⚠ IT EXISTS BECAUSE "HAS THE PDK CHANGED" IS NOT A QUESTION ABOUT `pdk`,
  ## AND A REAL LAUNCH IS WHAT PROVED IT. `set_pdk` first compared the resolved
  ## PDK before and after its own write. The three shipped rcs set `env(PDK)`
  ## and THEN declare, so by the time `set_pdk` ran `pdk` ALREADY answered
  ## `sky130A` out of the environment -- before and after were equal, the
  ## re-read was skipped, and MEASURED end to end in a project directory whose
  ## conf carried a `[pdk sky130A]` section:
  ##     AT-STARTUP pdk=          mos={id id 0} {gm gm 1}
  ##     AFTER-RC   pdk=sky130A   mos={id id 0} {gm gm 1}   <- the section LOST
  ## Every store row was green for it: the suite's fixture declared through the
  ## override alone, never through the environment, so "before" really was
  ## empty there. The question the code has to ask is about THE ROWS IN THE
  ## STORE -- "they were read under X, the launch is now Y" -- which is what
  ## this variable answers and what `pdk` structurally cannot.
  variable loadedpdk
  if {![info exists loadedpdk]} { set loadedpdk {} }

  ## Is <name> usable as a PDK identity? {} when it is -- INCLUDING THE EMPTY
  ## STRING, which means "no PDK" and is not an error (the user's own
  ## non-negotiable).
  ##
  ## THERE ARE EXACTLY TWO REFUSALS AND THEY ARE THE SAME REFUSAL: a name this
  ## file could not WRITE BACK as `[pdk <name>]`. Whitespace, because the
  ## header is one whitespace-free field like every other field in this
  ## whitespace-delimited file (the same sentence `_key_why` makes about keys);
  ## and `]`, because `_section_of`'s pattern ends the name at the first one,
  ## so `[pdk a]b]` would be read back as the PDK `a`. Both are stated as the
  ## round trip rather than as two rules, and row PK1b DRIVES the round trip in
  ## both directions -- it was minted because deleting the `]` arm outright
  ## left the whole suite green (this item's adversary), the comment above it
  ## claimed there was only one refusal, and `_scope_header`'s `pdk` arm -- the
  ## writing half of the pair -- had no caller of its own to keep it honest.
  proc _pdk_why {name} {
    if {$name eq {}} { return {} }
    if {[regexp {\s} $name]} {
      return "the PDK name \"$name\" carries whitespace, so it could not be written as a `\[pdk <name>\]` section header; this launch is treated as having no PDK"
    }
    if {[string first {]} $name] >= 0} {
      return "the PDK name \"$name\" carries a `\]`, so it could not be written as a `\[pdk <name>\]` section header; this launch is treated as having no PDK"
    }
    return {}
  }

  proc _pdk_env {} {
    if {![info exists ::env(PDK)]} { return {} }
    if {[catch {string trim $::env(PDK)} v]} { return {} }
    return $v
  }

  ## THIS LAUNCH'S PDK, OR {} FOR NONE. THE ONE DEFINITION (invariant I1);
  ## every other proc here asks this one and nothing re-derives it.
  ##
  ## ⚠ NOT CACHED, DELIBERATELY. It is a per-process constant in PRACTICE, but
  ## a cache would be a second copy of the fact that goes stale the moment
  ## `set_pdk` or a test moves it, and the read is two `info exists`. One fact,
  ## one reader, recomputed.
  ## ⚠ AND IT NEVER REPORTS. `_scope_applies` calls it once per line of the
  ## file; a report in here would be a flood. `load_conf` says the sentence
  ## once per file instead.
  proc pdk {} {
    variable pdkoverride
    if {[llength $pdkoverride]} {
      set n [lindex $pdkoverride 0]
    } else {
      set n [_pdk_env]
    }
    if {[_pdk_why $n] ne {}} { return {} }
    return $n
  }

  ## THE DECLARATION DOOR, matching `set_class`'s shape: one call from a PDK's
  ## own rc. Returns the LIST OF PATHS RE-READ, which is {} when nothing was.
  ##
  ## ⚠ IT RE-READS THE TIERS, AND THAT IS THE WHOLE REASON IT EXISTS. The
  ## startup `load` ran before the rc could name the PDK, so it applied the
  ## un-scoped rows and skipped every `[pdk ...]` section.
  ##
  ## ⚠ AND IT RE-READS FROM AN EMPTY STORE, NOT ON TOP OF THE OLD ONE. The
  ## first draft called `load` straight over the existing store on the strength
  ## of "first touch of a key clears what came before", which really does
  ## rebuild every key's CONTENT -- and left `keyorder`, which is FILE ORDER
  ## among flavor globs (ruling DD-8), carrying the first read's positions with
  ## the second read's new keys appended after them. So THE SAME TWO FILES GAVE
  ## DIFFERENT ANSWERS depending on how the PDK arrived. MEASURED, user tier
  ## `[pdk sky130A] flavor mos *nfet_01v8_lvt*`, project tier un-scoped
  ## `flavor mos *`:
  ##     `PDK=sky130A xschem`   (env first, one read)  -> *nfet_01v8_lvt* wins
  ##     the shipped rc         (read, then declare)   -> bare `*` wins
  ## and the rc is the default path for all three PDKs this tree ships. A
  ## `reset` makes the sentence below true instead of merely plausible: the end
  ## state is identical to a launch that knew its PDK all along, ORDER AND ALL.
  ## Safe because the dirty check above already refused every case where the
  ## store holds something the files do not, and `reset` deliberately keeps
  ## `pdkoverride` (the declaration) and `applied` (issue 1292's undo).
  ## Rows PK7 and PK7b compare the two arrival orders' STORES; PK13b compares
  ## their flavor ORDER, which is the half that was wrong.
  ##
  ## ⚠ "CHANGED" MEANS "DIFFERENT FROM WHAT THE ROWS WERE READ UNDER", NOT
  ## "different from a moment ago". The three shipped rcs set `env(PDK)` and
  ## THEN declare, so a before/after comparison of `pdk` is equal on both sides
  ## and skips the re-read -- measured, with the section silently lost. See
  ## `loadedpdk` above.
  ##
  ## ⚠ IT WILL NOT RE-READ OVER YOUR UNSAVED EDITS. A re-read is silent
  ## discard for any key this session already changed, so a declaration that
  ## arrives AFTER an edit records the name, re-reads nothing, and says so.
  ## In the supported order nothing is dirty yet: `load` stamps nothing
  ## (ruling DD-7) and the rc runs before any window is open.
  proc set_pdk {name} {
    variable pdkoverride ; variable dirty ; variable dirtyclass
    set why [_pdk_why $name]
    if {$why ne {}} {
      _say $why
      set pdkoverride [list {}]
      return {}
    }
    variable loadedpdk
    set pdkoverride [list $name]
    ## NOTHING HAS BEEN READ YET, so there is nothing to correct: the next
    ## `load` will simply see the right PDK.
    if {![llength $loadedpdk]} { return {} }
    if {[lindex $loadedpdk 0] eq [pdk]} { return {} }
    if {[array size dirty] || [array size dirtyclass]} {
      _say "PDK \"$name\" was declared after this session changed a list, so the settings files were NOT re-read and any `\[pdk $name\]` rows in them are not applied. Save your lists, or restart with PDK=$name in the environment."
      return {}
    }
    ## The read below REPLACES the one above it, so it replaces its report
    ## buffer too (`reset`) and does not re-echo its sentences to the terminal
    ## (`echoskip`). What IS new -- the sections this launch skips, which the
    ## provisional startup read could not honestly name -- is not in the
    ## snapshot and is said normally.
    variable reports ; variable echoskip
    set echoskip $reports
    reset
    ## The flag is cleared on EVERY exit, including one nothing here expects.
    ## `load` is not documented to raise, and a leaked `echoskip` would silence
    ## those sentences for the rest of the process -- a debugging aid turned
    ## into a gag. The raise is re-thrown, not swallowed.
    if {[catch {load} got]} {
      set echoskip {}
      return -code error $got
    }
    set echoskip {}
    return $got
  }

  ## Drop the declaration and go back to the environment. The restore half of
  ## `set_pdk`, so a suite can put the reader's own launch back.
  ## ⚠ IT DOES NOT RE-READ, AND ROW PK1 DRIVES THAT. `set_pdk` re-reads because
  ## a PDK arriving late is the case the feature exists for; forgetting one is
  ## a test's own cleanup and re-reading there would give a row a store it did
  ## not build. So after `forget_pdk` the STORE still holds exactly what the
  ## declaration read -- only the identity goes back to the environment -- and
  ## PK1 asserts both halves, because replacing this body with `return [load]`
  ## used to leave the suite green (this item's adversary).
  proc forget_pdk {} {
    variable pdkoverride
    set pdkoverride {}
    return {}
  }

  ## -----------------------------------------------------------------------
  ## THE SECTION HEADER
  ## -----------------------------------------------------------------------
  ## A SCOPE IS A TWO-ELEMENT LIST, never a bare string, so no PDK name can
  ## ever collide with a sentinel:
  ##   {any {}}      the rows that apply to EVERY PDK -- the top of the file,
  ##                 and everything under `[pdk *]`
  ##   {pdk <name>}  a `[pdk <name>]` section
  ##   {bad {}}      the rows under a header this reader could not read
  ##
  ## ⚠ `[pdk *]` IS THE WAY BACK, AND THE WRITER NEEDS IT MORE THAN THE USER
  ## DOES. An appended row lands at the END of the file, and the end of a
  ## sectioned file is INSIDE a section, so a writer with no way to say "back
  ## to every PDK" would silently give a new un-scoped list the last section's
  ## PDK. `*` reuses the glob vocabulary the `flavor` scope already spends, and
  ## the one collision it could have -- a PDK literally named `*` -- is
  ## harmless rather than wrong: such a launch matches `[pdk *]`, which is
  ## "every PDK", which includes it.
  ##
  ## ⚠ A HEADER THIS READER CANNOT READ POISONS THE SECTION RATHER THAN
  ## LEAVING THE SCOPE ALONE. `[pdk sky 130A]` is two fields where one was
  ## wanted; leaving the current scope unchanged would make the rows under it
  ## UN-SCOPED, i.e. would apply rows the user wrote for ONE PDK to EVERY PDK,
  ## which is the leak this whole item is about. Applying them to nothing is
  ## the safe direction -- the same direction "a lost `list` line degrades to
  ## the PDK seed" already takes -- and the reader says so on the header line.
  ##
  ## `[` CAN START NO OTHER LINE. A data row starts with one of four verbs and
  ## a comment with `#`; the only `[` a row can carry is inside a cell-name
  ## glob, which is never the first field. So "the trimmed line starts with
  ## `[`" is a complete and unambiguous trigger.
  ##
  ## -> {}                  this is not a section header
  ## -> {ok <scope>}        a well-formed one
  ## -> {bad <sentence>}    it looks like one and is not
  proc _section_of {line} {
    set t [string trim $line]
    if {[string index $t 0] ne {[}} { return {} }
    if {[regexp {^\[[ \t]*pdk[ \t]+([^\]\s]+)[ \t]*\]$} $t -> nm]} {
      if {$nm eq {*}} { return [list ok [list any {}]] }
      return [list ok [list pdk $nm]]
    }
    return [list bad "\"$t\" is not a section header; the shape is `\[pdk <name>\]`, one whitespace-free name, or `\[pdk *\]` for every PDK. The rows under it are read and NOT applied, because guessing which PDK you meant would apply them to the wrong one"]
  }

  ## Does a scope apply to THIS launch? The one place the constant is spent.
  proc _scope_applies {scope} {
    set kind [lindex $scope 0]
    if {$kind eq {any}} { return 1 }
    if {$kind ne {pdk}} { return 0 }
    set p [pdk]
    if {$p eq {}} { return 0 }
    return [expr {[lindex $scope 1] eq $p ? 1 : 0}]
  }

  ## WHICH OF `load_conf`'s TWO PASSES AN APPLYING SCOPE BELONGS TO.
  ## ⚠ A PARTITION, NOT A SECOND FENCE (invariant I1). It is asked ONLY about
  ## scopes `_scope_applies` has already accepted, and among those the only
  ## two possibilities are the un-scoped rows and this launch's own section.
  ## The reader used to test `[lindex $scope 0] ne $phase` directly, which
  ## happened to exclude a `bad` scope as well -- so `_scope_applies` had a
  ## silent understudy, and with `_scope_applies` sabotaged to accept
  ## everything the reader stayed correct and the whole suite stayed GREEN
  ## while the WRITER, which has no understudy, rewrote the user's rows under
  ## an unreadable header. One predicate now answers "is this row mine" for
  ## both; row PK5b is the writer's half of the fence.
  proc _phase_of {scope} {
    if {[lindex $scope 0] eq {any}} { return any }
    return pdk
  }

  ## A scope AS A FILE LINE. The writer's half of `_section_of`, and the only
  ## place a header is spelled.
  ##
  ## ⚠ THE `pdk` ARM HAS NO PRODUCTION CALLER TODAY AND STAYS ANYWAY, WITH A
  ## ROW ON IT. `_merge_lines` emits only `[pdk *]` (the `any` arm), because
  ## the shipped Save edits rows where they already are and invents no section;
  ## the `pdk` arm is what rule debt 1388 option 1 -- "a Save under a PDK always
  ## writes into that PDK's section" -- would call the moment the user rules for
  ## it. Deleting it would leave the reader able to parse a header shape the
  ## writer has no word for, which is how `_row_id` and `_parse_line` drifted in
  ## issue 1294. Row PK1b is its caller until the user's ruling arrives: it
  ## asserts `_section_of [_scope_header ...]` is the identity for every name
  ## `_pdk_why` accepts, and is NOT for the two it refuses -- which is the whole
  ## reason those two are refused.
  proc _scope_header {scope} {
    if {[lindex $scope 0] eq {pdk}} { return "\[pdk [lindex $scope 1]\]" }
    return {[pdk *]}
  }

  ## Why a section is being read and not applied. Its own proc because the
  ## sentence differs for a launch WITH another PDK and a launch with NONE, and
  ## the second one is the case a user meets first.
  proc _skip_why {scope} {
    set nm [lindex $scope 1]
    set p [pdk]
    if {$p eq {}} {
      return "the rows under `\[pdk $nm\]` are for PDK $nm and this launch has no PDK, so they are read and not applied"
    }
    return "the rows under `\[pdk $nm\]` are for PDK $nm and this launch is PDK $p, so they are read and not applied"
  }

  ## THE ONE SECTION SCANNER, TWO CONSUMERS (invariant I1): the strict reader
  ## and the writer's read-modify-write. A second scanner inside the writer
  ## would let a header the reader honoured be a data line to the merge, and
  ## the merge would then rewrite a row in the wrong PDK's section with nothing
  ## said anywhere -- the exact divergence issue 1294 measured one row shape
  ## over, where `_row_id` was laxer than `_parse_line`.
  ##
  ## -> a list, ONE ELEMENT PER INPUT LINE, each {<scope> <kind> <text>}:
  ##      kind `row`     an ordinary line, in <scope>
  ##      kind `header`  a well-formed section header that OPENED <scope>
  ##      kind `bad`     a header this reader could not read; <text> says why
  ##                     and <scope> is {bad {}} from there on
  proc _scope_lines {lines} {
    set cur [list any {}]
    set out {}
    foreach line $lines {
      set s [_section_of $line]
      if {$s eq {}} { lappend out [list $cur row {}] ; continue }
      if {[lindex $s 0] eq {ok}} {
        set cur [lindex $s 1]
        lappend out [list $cur header {}]
        continue
      }
      set cur [list bad {}]
      lappend out [list $cur bad [lindex $s 1]]
    }
    return $out
  }

  ## -----------------------------------------------------------------------
  ## THE TWO TIERS
  ## -----------------------------------------------------------------------
  proc conf_path {which} {
    variable basename
    if {$which eq "user"} {
      if {![info exists ::USER_CONF_DIR]} { return {} }
      if {$::USER_CONF_DIR eq {}} { return {} }
      return [file join $::USER_CONF_DIR $basename]
    }
    if {$which eq "project"} { return [file join [pwd] .xschem $basename] }
    _say "unknown settings tier \"$which\"; expected `user` or `project`"
    return {}
  }

  ## WHICH TIERS DOES THIS PATH ACTUALLY BELONG TO? (issue 1325)
  ##
  ## ⚠ THE TWO TIERS CAN BE ONE FILE, AND AT THE ORDINARY LAUNCH CWD THEY ARE.
  ## `conf_path project` is `[pwd]/.xschem/<basename>`, so with the cwd at
  ## `$HOME` -- which is how xschem is normally started -- it resolves to the
  ## SAME file as `conf_path user`. MEASURED at HEAD:
  ##     user    = /home/analog/.xschem/op_param_lists.conf
  ##     project = /home/analog/.xschem/op_param_lists.conf
  ## `load` below already knows it and dedupes with `file normalize` and a
  ## `seen` list. THE WRITER DID NOT: a Save that reported a project write
  ## rewrote the USER-GLOBAL settings of every design on this machine, and
  ## ruling DD-7's "a write touches one tier's own file" went vacuous in
  ## exactly the case a user meets first. (The measurement was not academic --
  ## a probe of the reverted caller really did write the developer's own
  ## `~/.xschem/op_param_lists.conf`.)
  ##
  ## This is the accessor that lets a caller SAY SO. It does not change which
  ## tier Save writes: issue 1273 -- "which directory IS the project" -- is a
  ## live rule debt and is the USER's to settle. Making `conf_path project`
  ## answer empty on a collision is rejected by issue 1325 itself, because
  ## `load` and `write_conf` both depend on that accessor.
  ##
  ## READ-ONLY BY CONSTRUCTION: it creates nothing, owns nothing, and pushes no
  ## report -- a tier reporter that wrote anything would be a second writer
  ## wearing a reader's name.
  ##
  ## -> the tiers whose `conf_path` normalizes to this path, in `{user
  ##    project}` order; {} for a path that is neither.
  ## An identity a symlink cannot disguise (issue 1327).
  ##
  ## ⚠ `file normalize` DOES NOT RESOLVE SYMLINKS -- measured, and it is the
  ## whole of 1327: with the project conf a symlink to the user-global file,
  ## `conf_tiers` answered `project` alone while the USER-GLOBAL file was the
  ## one that changed. That is issue 1325's own title coming back through a
  ## door its fix did not cover, and it is why a Save could still name one file
  ## and write another.
  ##
  ## Device + inode is the identity the filesystem itself uses, so it sees
  ## through symlinks, hardlinks and bind mounts alike, where any amount of
  ## string normalisation sees through none of them.
  ##
  ## ⚠ FALLS BACK TO THE NORMALISED STRING, deliberately. A path that does not
  ## exist yet has no inode -- and the first Save of a first run is exactly
  ## that case, so a stat-only answer would make the ordinary first run the
  ## broken one. Two paths that do not exist are then compared as strings,
  ## which is the best available answer and is what the old code did for every
  ## case.
  proc _fid {path} {
    if {$path eq {}} { return {} }
    set n {}
    if {[catch {file normalize $path} n]} { return {} }
    if {[catch {file stat $n st}]} { return "name:$n" }
    if {![info exists st(dev)] || ![info exists st(ino)]} { return "name:$n" }
    return "ino:$st(dev):$st(ino)"
  }

  proc conf_tiers {path} {
    if {$path eq {}} { return {} }
    set n [_fid $path]
    if {$n eq {}} { return {} }
    set out {}
    foreach which {user project} {
      set p [conf_path $which]
      if {$p eq {}} { continue }
      set pn [_fid $p]
      if {$pn eq {}} { continue }
      if {$pn eq $n} { lappend out $which }
    }
    return $out
  }

  ## Read the user-global file, then the project one; the project file wins per
  ## (scope,key,listname). Returns the LIST OF PATHS actually read, in read
  ## order. A missing file is the ordinary first-run case, not a failure
  ## (ase.tcl:2101 states it), and two tiers resolving to the SAME path are read
  ## once.
  proc load {} {
    variable loadedpdk
    ## ⚠ IS THIS READ PROVISIONAL? Exactly when it has no PDK AND nothing has
    ## been read yet -- i.e. it is the startup restore, the one read a
    ## `--script` workarea rc can still supersede by declaring a PDK. A
    ## re-read from `set_pdk` is not (something was read), and a launch whose
    ## PDK came from the environment is not (it has one). Captured BEFORE the
    ## record below overwrites it. See the section-report gate in `load_conf`.
    set provisional [expr {[pdk] eq {} && ![llength $loadedpdk]}]
    ## RECORDED BEFORE THE READ, not after: `_scope_applies` is what the read
    ## spends the PDK on, so the value that governed this store's contents is
    ## the one live at the start of it, and a `set_pdk` racing the read cannot
    ## leave the record claiming a PDK the rows were not filtered by.
    set loadedpdk [list [pdk]]
    set got {} ; set seen {}
    foreach which {user project} {
      set p [conf_path $which]
      if {$p eq {}} { continue }
      ## Same identity as conf_tiers uses, for the same reason (issue 1327):
      ## two tiers that are the same FILE through a symlink must be read once.
      set n [_fid $p]
      if {$n ne {} && [lsearch -exact $seen $n] >= 0} { continue }
      lappend seen $n
      if {![file isfile $p]} { continue }
      ## ⚠ STAMP NOTHING. This is the session's INITIAL STATE, not a change the
      ## session made, so a later Save of one tier rewrites only the keys the
      ## user actually touched and leaves the other tier's rows in the other
      ## tier's file (ruling DD-7). A direct `load_conf` DOES stamp -- importing
      ## a file into your session is a session change -- which is the whole of
      ## the difference between the two doors.
      if {[load_conf $p 0 $provisional]} { lappend got $p }
    }
    return $got
  }

  ## -----------------------------------------------------------------------
  ## THE STRICT READER (DD-3)
  ## -----------------------------------------------------------------------
  ## ⚠ THE OPTIONAL `stamp` IS RULING DD-7's, AND THE REQUIRED ARITY DOES NOT
  ## MOVE. A DIRECT `load_conf <path>` stamps the keys it sets as
  ## changed-this-session, because importing a file into your session IS a
  ## session change and a user who imports then saves must get what she
  ## imported. `load`, the two-tier startup restore, passes 0.
  ## ⚠ THE SECOND OPTIONAL ARGUMENT IS `provisional` (issue 1388), AND THE
  ## REQUIRED ARITY STILL DOES NOT MOVE (row J5). A PROVISIONAL read is one
  ## whose PDK may still arrive: the startup `load` runs while xschem.tcl is
  ## sourced, and the workarea `--script` rc that DECLARES the PDK is sourced
  ## after it. Only `load` passes 1, and only for the session's first read.
  proc load_conf {path {stamp 1} {provisional 0}} {
    if {![file isfile $path]} {
      _say "no settings file at $path"
      return 0
    }
    set rd [_read_lines $path]
    if {[lindex $rd 0] ne "ok"} {
      _say "cannot read $path: [lindex $rd 1]"
      return 0
    }
    set lines  [lindex $rd 1]
    set scoped [_scope_lines $lines]

    ## THE HEADERS ARE REPORTED ONCE, HERE, BEFORE ANY ROW IS APPLIED -- not
    ## inside the two passes below, which would say each sentence twice.
    ## A section that is READ AND NOT APPLIED is not an error and is not
    ## silence either: with three PDKs' sections in one file the user is told
    ## once per section which ones this launch skipped, which is the first
    ## question they will ask.
    ##
    ## ⚠ EXCEPT FROM A READ THAT COULD STILL BE SUPERSEDED, WHICH SAYS NOTHING
    ## ABOUT SECTIONS AT ALL (issue 1388's repair pass). `_skip_why`'s no-PDK
    ## sentence is a claim about THE LAUNCH, and the startup read is not in a
    ## position to make it: the rc that names the PDK is sourced after it.
    ## MEASURED before this gate -- `cd <proj> && xschem --script
    ## sky130A/cadence_style_rc` over a conf with three sections -- FIVE lines,
    ## the first of them FALSE:
    ##   :3: ... `[pdk sky130A]`    ... this launch has no PDK   <- FALSE, that
    ##                                  section was applied one line later
    ##   :5: ... `[pdk gf180mcuD]`  ... this launch has no PDK
    ##   :7: ... `[pdk ihp-sg13g2]` ... this launch has no PDK
    ##   :5: ... `[pdk gf180mcuD]`  ... this launch is PDK sky130A   <- again
    ##   :7: ... `[pdk ihp-sg13g2]` ... this launch is PDK sky130A   <- again
    ## and after it TWO, from the read that governs, and not one word about the
    ## section this launch applied. Re-measured the same way for all three
    ## shipped workareas. Row PK14 counts the lines in a CHILD PROCESS, because
    ## the echo is stderr and `said` alone would score the duplicate green.
    ##
    ## THE `bad` ARM IS NOT GATED: a header nobody can read is a fact about the
    ## FILE, true whoever reads it and whenever.
    ##
    ## `provisional` IS NARROWER THAN "[pdk] IS EMPTY", so THE NO-PDK WORDING
    ## STAYS LIVE. Only `load` passes it, and only for the session's FIRST read
    ## -- the one read a `--script` rc can still supersede. A direct
    ## `load_conf` (importing a file by hand) is nobody's provisional read, so
    ## a PDK-less session that opens a sectioned file is still told why nothing
    ## applied.
    ## ⚠ PRICE, STATED, AND ON THE RULE LEDGER AS ISSUE 1388 QUESTION 2: a
    ## launch with NO PDK AT ALL -- started outside the workarea, sections in
    ## the file -- is no longer told AT STARTUP. The alternative was a false
    ## sentence on every workarea launch this tree ships.
    set ev [_pdk_env]
    if {$ev ne {} && [_pdk_why $ev] ne {}} { _say "$path: [_pdk_why $ev]" }
    set n 0
    foreach sc $scoped {
      incr n
      switch -- [lindex $sc 1] {
        bad     { _say "$path:$n: [lindex $sc 2]" }
        header  {
          if {![_scope_applies [lindex $sc 0]] && !$provisional} {
            _say "$path:$n: [_skip_why [lindex $sc 0]]"
          }
        }
      }
    }

    ## ⚠ TWO PASSES, AND THEY ARE THE PDK PRECEDENCE ITSELF (issue 1388).
    ## Un-scoped rows first, then this launch's PDK section rows. `touched` is
    ## SHARED across the two, so the first PDK-scoped row for a key clears what
    ## the un-scoped rows put there by the very machinery that already makes a
    ## project file win over a user-global one -- no rank field, no second
    ## comparison, nothing to keep in step. That is why the rank does NOT
    ## depend on where the section sits in the file, which is the user's
    ## ruling: "PDK section beats the un-scoped rows".
    ## EVERY LINE IS PARSED AT MOST ONCE: a line belongs to exactly one phase,
    ## and a line in a section for ANOTHER PDK (or under an unreadable header)
    ## belongs to neither, so it can raise no report of its own -- its section
    ## already said so, once, above.
    ## ⚠ AND AXIS 3 IS SEEDED FIRST, IN FILE ORDER, BECAUSE THE TWO PASSES
    ## CANNOT CARRY IT (issue 1388, found by this item's adversary).
    ## `keyorder` is the list `governs` walks to answer "which flavor glob wins
    ## on this cell", and ruling DD-8's answer is FILE ORDER. Letting the phase
    ## loop below append to it made the answer PHASE order instead, so a
    ## `flavor` row inside THIS LAUNCH'S OWN `[pdk ...]` section was always
    ## tried AFTER every un-scoped one -- it lost sitting first in the file,
    ## and lost while being the PDK-specific row. MEASURED on the brief's own
    ## example shape (`[pdk sky130A]` carrying `flavor mos *nfet_01v8_lvt*`
    ## above an un-scoped `flavor mos *`):
    ##     governs -> flavor {mos *}                <- the broad, LOWER row
    ## and with the two section headers deleted, the same two rows answer
    ##     governs -> flavor {mos *nfet_01v8_lvt*}
    ## That made `_header_lines`' own flavor paragraph -- "THE FIRST ONE IN
    ## THIS FILE WINS ... put the row you want to win ABOVE the other one",
    ## which the writer stamps into every new settings file -- FALSE for every
    ## sectioned file. A file lying to its own reader is the exact failure that
    ## paragraph records two earlier attempts making. Row F5 stayed green
    ## because its fixture has no sections; row PK13 drives F5's own worked
    ## example through a sectioned one.
    ##
    ## THE TWO AXES ARE DIFFERENT QUESTIONS AND NOW ANSWER IN DIFFERENT
    ## PLACES: axis 2 (the passes below) decides WHICH ROWS FILL A KEY; axis 3
    ## (here) decides WHICH KEY ANSWERS A CELL. Seeding is safe in both
    ## directions -- `_keys` returns only keys that are `owned`, so a seeded
    ## key no row ends up creating is invisible, and `_key_touch` keeps a key's
    ## FIRST position, so an earlier tier is still not re-ordered by a later
    ## one restating it. `_row_id` is the same row recogniser the writer uses,
    ## so a line that seeds no key here parses to no key below either.
    foreach line $lines sc $scoped {
      if {[lindex $sc 1] ne {row}} { continue }
      if {![_scope_applies [lindex $sc 0]]} { continue }
      set k [_row_id [regexp -inline -all {\S+} $line]]
      if {$k ne {}} { _key_touch $k }
    }

    set touched {}
    foreach phase {any pdk} {
      set n 0
      foreach line $lines sc $scoped {
        incr n
        if {[lindex $sc 1] ne {row}} { continue }
        set scope [lindex $sc 0]
        ## ⚠ ONE FENCE, THEN A PARTITION -- not two fences (invariant I1).
        ## `_scope_applies` is the ONLY thing that decides whether a row is
        ## this launch's; `_phase_of` then merely says which pass an APPLYING
        ## row belongs to. The two used to be independent tests, and the
        ## redundancy hid a hole: `_scope_applies` sabotaged to accept
        ## everything left the reader correct and the suite green while the
        ## writer destroyed rows under an unreadable header (row PK5b).
        if {![_scope_applies $scope]} { continue }
        if {[_phase_of $scope] ne $phase} { continue }
        if {[string trim $line] eq {}} { continue }
        if {[string index [string trimleft $line] 0] eq "#"} { continue }
        _parse_line $path $n $line touched $stamp $scope
      }
    }
    return 1
  }

  ## THE ONE SPLITTER, TWO CONSUMERS (invariant I1): the strict reader above and
  ## the writer's read-modify-write below. A second splitter inside the writer
  ## would merge a teammate's CRLF file differently from the way the parser read
  ## it, and no existing row could see the difference -- the CRLF row fences the
  ## PARSE, not the merge.
  ## Answers {ok <lines>} or {err <message>}; never raises.
  ## ⚠ `split` on a file that ends in a newline yields ONE TRAILING EMPTY
  ## ELEMENT that is not a line. Dropping exactly one is what keeps a save from
  ## growing the file by a blank line every single time.
  proc _read_lines {path} {
    if {[catch {open $path r} fp]} { return [list err $fp] }
    _chanconf $fp
    if {[catch {read $fp} data]} {
      catch {close $fp}
      return [list err $data]
    }
    catch {close $fp}
    set out {}
    ## The default `auto` translation already maps \r\n -> \n on read, so the
    ## trim is a no-op on the normal path; it keeps the reader correct if the
    ## channel is ever opened in a non-auto translation mode.
    foreach raw [split $data "\n"] { lappend out [string trimright $raw "\r"] }
    if {[llength $out] && [lindex $out end] eq {}} { set out [lrange $out 0 end-1] }
    return [list ok $out]
  }

  ## ONE ROW. Nothing here runs, expands or substitutes anything the file says.
  ##
  ## ⚠ THE OPTIONAL TRAILING `pdkscope` IS THE PDK AXIS (issue 1388), AND THE
  ## REQUIRED ARITY DOES NOT MOVE -- the same shape `stamp` and `write_body`'s
  ## `old` already take. It is used for ONE thing: it QUALIFIES THE `touched`
  ## MARKERS, so "the first row for this key in this file clears what came
  ## before" becomes "the first row for this key IN THIS SCOPE clears what came
  ## before". That single change is the whole of "a PDK section beats the
  ## un-scoped rows", and it also stops a legitimate per-PDK `class` row from
  ## being reported as a duplicate of the un-scoped one it is meant to
  ## override -- a false alarm the un-qualified marker really did raise.
  ## ⚠ IT IS NAMED `pdkscope`, NOT `scope`: this proc's own `scope` local is
  ## the ROW's scope (`class` / `flavor`), an entirely different axis, and one
  ## name for two axes is how the next reader writes a real bug here.
  proc _parse_line {path lineno line tvar {stamp 1} {pdkscope {any {}}}} {
    variable classmap ; variable lists ; variable owned
    variable livelist ; variable version
    upvar 1 $tvar touched
    set f [regexp -inline -all {\S+} $line]
    set verb [lindex $f 0]
    set at "$path:$lineno"

    if {$verb eq "version"} {
      if {[llength $f] != 2} {
        _say "$at: `version` takes one number, got [llength $f] fields: $line"
        return 0
      }
      if {[lindex $f 1] ne $version} {
        ## ⚠ NAME BOTH VERSIONS AND SAY WHAT CHANGED. A v1 `flavor` row has one
        ## field too few under v2 and is skipped; it is NEVER migrated by
        ## inference, because guessing which class `*nfet_01v8_lvt*` meant is
        ## exactly the invention ruling D-4 forbids one level up -- and the
        ## guess would be silent, so a user whose flavor quietly stopped
        ## applying would have nothing on screen to read. This row is the thing
        ## that tells her.
        _say "$at: settings file version [lindex $f 1] is not the version $version this xschem writes; grammar v2 gave every `flavor` row a class field of its own, so a v1 flavor row is one field short and is reported and skipped. Reading the rest row by row anyway: $line"
        return 0
      }
      return 1
    }

    if {$verb eq "class"} {
      if {[llength $f] != 3} {
        _say "$at: `class` takes <type-token> <broad-class>, got [llength $f] fields: $line"
        return 0
      }
      set tok [lindex $f 1]
      set ck [list class $pdkscope $tok]
      if {[lsearch -exact $touched $ck] >= 0} {
        _say "$at: a second `class` row for \"$tok\" in one file; the later mapping wins: $line"
      } else {
        lappend touched $ck
      }
      set classmap($tok) [lindex $f 2]
      if {$stamp} { _mark_dirty class $tok }
      return 1
    }

    if {$verb eq "list" || $verb eq "param"} {
      ## ⚠ THE SCOPE IS VALIDATED BEFORE THE FIELDS ARE COUNTED, because under
      ## grammar v2 the arity DEPENDS on the scope. Counting first would report
      ## a field count for an unknown scope -- and it is the same row either
      ## way, so only one of the two orders tells the reader what is actually
      ## wrong with the line.
      if {[llength $f] < 2} {
        _say "$at: `$verb` needs a scope (`class` or `flavor`) as its first field, got [llength $f] fields: $line"
        return 0
      }
      set scope [lindex $f 1]
      if {![_valid_scope $scope]} {
        _say "$at: unknown scope \"$scope\"; expected `class` or `flavor`: $line"
        return 0
      }
      set want [_row_arity $verb $scope]
      if {[llength $f] != $want} {
        _say "$at: `$verb $scope` takes $want whitespace-separated fields, got [llength $f]: $line"
        return 0
      }
      if {$scope eq "flavor"} {
        set key [list [lindex $f 2] [lindex $f 3]]
        set ln  [lindex $f 4]
        set rest 5
      } else {
        set key [lindex $f 2]
        set ln  [lindex $f 3]
        set rest 4
      }
      if {$ln eq $livelist} {
        _say "$at: the `$livelist` list is live from the simulator and is never stored in a settings file (ruling D-4): $line"
        return 0
      }
      if {![_valid_list $ln]} {
        _say "$at: unknown list name \"$ln\"; expected `annotation` or `summary`: $line"
        return 0
      }
      set t {}
      if {$verb eq "param"} {
        set t [_triple [list [lindex $f $rest] [lindex $f [expr {$rest + 1}]] \
                             [lindex $f [expr {$rest + 2}]]]]
        if {$t eq {}} {
          _say "$at: kind \"[lindex $f [expr {$rest + 2}]]\" is not an integer: $line"
          return 0
        }
      }
      ## THE FIRST TOUCH OF A KEY IN THIS FILE CLEARS WHAT AN EARLIER TIER PUT
      ## THERE. That is what makes the project file WIN rather than append.
      set k [_key $scope $key $ln]
      ## ⚠ THE MARKER IS SCOPE-QUALIFIED, THE STORE KEY IS NOT. The store has
      ## one PDK (a per-process constant), so `lists`/`owned` gain no field;
      ## only the question "has this file already touched this key IN THIS PDK
      ## SCOPE" does.
      if {[lsearch -exact $touched [list $pdkscope $k]] < 0} {
        lappend touched [list $pdkscope $k]
        set lists($k) {}
        set owned($k) 1
        ## FILE ORDER (ruling DD-8): a key keeps the position of its FIRST
        ## appearance, so an earlier tier's row is not re-ordered by a later
        ## tier restating it.
        _key_touch $k
        if {$stamp} { _mark_dirty list $k }
      }
      if {$verb eq "list"} { return 1 }
      set cur $lists($k)
      set hit [_dup_index $cur [lindex $t 0]]
      if {$hit >= 0} {
        _say "$at: [_dup_why [lindex $t 0] $scope $key $ln]: $line"
        set lists($k) [lreplace $cur $hit $hit $t]
      } else {
        lappend cur $t
        set lists($k) $cur
      }
      return 1
    }

    _say "$at: unknown keyword \"$verb\"; this file is data and nothing in it is ever run, so the line is skipped: $line"
    return 0
  }

  ## -----------------------------------------------------------------------
  ## THE WRITER (issue 0937): AN INTERRUPTED WRITE NEVER TRUNCATES
  ## -----------------------------------------------------------------------
  ## Copied in shape from ase::sim_write_conf / ase::sim_write_body
  ## (src/ase.tcl:1999-2036). `open <path> w` TRUNCATES before a single byte is
  ## written, so a failure anywhere after that would leave the user with an
  ## EMPTY settings file and, if the writer raised, no sentence about it either.
  ## The file the user has keeps whatever it had until a complete new one is
  ## ready to take its place. Returns 1, or 0 with a report; never raises.
  ##
  ## What is NOT copied is ase::sim_load_conf's partner reader, whose
  ## `uplevel #0 [list source $path]` is exactly what DD-3 forbids.
  proc _tmpname {path} { return $path.new }

  proc _chanconf {ch} {
    ## The encoding is pinned; the TRANSLATION is deliberately left at `auto`,
    ## which is what already handles CRLF.
    catch {fconfigure $ch -encoding utf-8}
    return {}
  }

  ## WHERE THE WRITE ACTUALLY LANDS, RESOLVED ONCE (issue 1276).
  ##
  ## ⚠ `file normalize` DOES NOT RESOLVE A PATH'S FINAL COMPONENT, and neither
  ## `file rename -force` nor `open` complains about any of this: measured, a
  ## target that was a DIRECTORY left the bytes at `<dir>/<name>.new` INSIDE it
  ## and reported success, and a target that was a SYMLINK had its link
  ## REPLACED by a regular file while the real file stayed empty -- both with
  ## zero reports. There is nothing to check afterwards, so the guard has to be
  ## a PRECONDITION.
  ##
  ## ⚠ AND IT HAS TO RUN FIRST. A symlink to a DIRECTORY answers `file
  ## isdirectory` 1, so the chain must be resolved before the directory guard;
  ## a DANGLING symlink answers exists=0 / isfile=0 / isdirectory=0 while `file
  ## link` still succeeds, so resolution must also precede the permission
  ## capture and the temp name.
  ##
  ## ⚠ THE RELATIVE-TARGET CORRECTION. Issue 1276's own recommended one-liner,
  ## `file normalize [file link $path]`, resolves a relative target against the
  ## CURRENT WORKING DIRECTORY: for a link at <d>/sub/link.conf -> real.conf it
  ## answers <d>/real.conf, not <d>/sub/real.conf, so a fix built on it writes
  ## the user's settings into the cwd. Join against the LINK's own directory.
  ##
  ## Answers the file the write should land on, or {} for a chain deeper than
  ## 16 links, which is what a loop looks like from here.
  proc _resolve_target {path} {
    set p $path
    ## ONE PASS PER LINK, PLUS ONE MORE to see that the last thing is not a
    ## link at all. A loop of exactly 16 passes refuses a chain of exactly 16,
    ## which the sentence in _target_why calls "more than 16 links deep" --
    ## measured: 15 saved, 16 was refused. The bound and the sentence have to
    ## name the same number.
    for {set i 0} {$i <= 16} {incr i} {
      if {[catch {file link $p} tgt]} { return $p }
      if {$tgt eq {}} { return $p }
      ## ⚠ THE TILDE. `file join` and `file normalize` EXPAND a leading tilde;
      ## THE KERNEL DOES NOT. A stored target of `~/notes.conf` is a link into
      ## a directory NAMED `~` beside the link -- readlink says `~/notes.conf`
      ## and, with no such directory there, the link reads as DANGLING.
      ## Without the `./` this resolver answered a path in the user's HOME and
      ## write_conf OVERWROTE AN UNRELATED FILE THERE while returning 1 --
      ## this issue's own headline symptom arriving through its own fix.
      ## Measured in tclsh: [file join /a/b {~/x}] -> `~/x`, normalized ->
      ## `/home/<you>/x`; with the `./` -> `/a/b/~/x`, kernel-identical. The
      ## other shapes are untouched: `sub/y` -> /a/b/sub/y, `/abs/z` -> /abs/z
      ## (an absolute target still wins), `../up.conf` -> /a/up.conf.
      if {[string index $tgt 0] eq "~"} { set tgt ./$tgt }
      ## ⚠ A MEASURED RESIDUAL THAT NO ROW PINS. `file normalize` collapses
      ## `..` LEXICALLY across a component that DOES NOT EXIST; the kernel does
      ## not. Measured here (tclsh 8.6.17): with `sub` a link to <d>/elsewhere,
      ## [file normalize <base>/./sub/../x] answers <d>/x -- the same as
      ## `readlink -f`, so an EXISTING component, directory or link, is
      ## resolved first and there is no divergence at all. With no `~` beside
      ## the link, [file normalize <base>/./~/../x] answers <base>/x while the
      ## kernel refuses <base>/~/../x with ENOENT. Left as it is, on purpose:
      ## in that state the link is BROKEN, this writer writes through broken
      ## links by design (rows W7b / R11d), and <base>/x is exactly the path
      ## the kernel names once the missing component is created as an ordinary
      ## directory (measured). What is NOT covered, and no row says anything
      ## about it: the missing component later appearing as a link elsewhere.
      ## ⚠ AND `file normalize` RAISES on a `~user` no password entry matches
      ## (measured: `user "nosuchuser_xschem" doesn't exist`), out of a writer
      ## whose contract is "never raises". A path that cannot even be named is
      ## not a path this may write, so it is refused.
      ## ⚠ NO ROW REACHES THIS CATCH and none can: after the `./` above a
      ## tilde can only reach `file normalize` from the CALLER's own path, and
      ## `file link` raises on that first and returns above. It is insurance,
      ## not a covered arm -- do not read the suite as proving it.
      if {[catch {file normalize [file join [file dirname $p] $tgt]} p]} { return {} }
    }
    return {}
  }

  ## THE TARGET'S OWN PRECONDITIONS, NAMED ONCE so the choice has one place and
  ## a reviewer can disable it and watch the suite say which promise broke.
  ## Answers {} when the resolved target may be written, and the sentence
  ## otherwise.
  proc _target_why {path target} {
    if {$target eq {}} {
      return "cannot save the parameter lists to $path: it is a symbolic link chain more than 16 links deep, which is what a loop looks like from here. The file you already had is untouched."
    }
    if {[file isdirectory $target]} {
      set what $path
      if {$target ne $path} { append what " (which resolves to $target)" }
      return "cannot save the parameter lists to $what: it is a directory, not a settings file. Nothing was written inside it, and the file you already had is untouched."
    }
    return {}
  }

  proc write_conf {{path {}}} {
    if {$path eq {}} { set path [conf_path project] }
    if {$path eq {}} {
      _say "no settings file path to write to"
      return 0
    }
    ## BEFORE `file dirname`, BEFORE `file mkdir`, BEFORE the temp name and
    ## BEFORE the permission capture -- see _resolve_target's comment.
    set target [_resolve_target $path]
    set why [_target_why $path $target]
    if {$why ne {}} {
      _say $why
      return 0
    }
    set path $target
    ## RULING DD-7: READ THE FILE WE ARE ABOUT TO WRITE. Every row this session
    ## did not change is preserved verbatim, so a row this build never parsed
    ## cannot be deleted by it.
    ## ⚠ AN EXISTING TARGET THAT CANNOT BE READ STOPS THE SAVE. Proceeding would
    ## write this session's few changed keys over a file whose other rows were
    ## never read -- DD-7's own failure mode arriving through its own fix.
    set old {}
    if {[file exists $path]} {
      set rd [_read_lines $path]
      if {[lindex $rd 0] ne "ok"} {
        _say "cannot save the parameter lists to $path: it already exists but could not be read ([lindex $rd 1]), and saving would overwrite rows this xschem never saw. The file you already had is untouched."
        return 0
      }
      set old [lindex $rd 1]
    }
    set dir [file dirname $path]
    if {![file isdirectory $dir]} {
      if {[catch {file mkdir $dir} err]} {
        _say "cannot save the parameter lists to $path: $err"
        return 0
      }
    }
    set tmp [_tmpname $path]
    set mode {}
    if {[file exists $path]} { catch {set mode [file attributes $path -permissions]} }
    ## THE TEMP IS PART OF THE TARGET (issue 1378), AND _resolve_target ONLY
    ## GUARDS `$path`. The temp name is deterministic, `open <tmp> w` FOLLOWS a
    ## symlink and `file rename` does NOT, so a stale `<conf>.new` left behind
    ## as a link wrote the settings THROUGH the link into an unrelated file and
    ## then moved the LINK ITSELF onto the user's settings file. Measured on
    ## this writer before this pair of lines: rc 1, zero reports, the settings
    ## file is now a `link`, and the bystander lost its own content and gained
    ## the settings -- this issue's own headline symptom, one step further down.
    ##
    ## ⚠ `file delete` HERE, NEVER `file delete -force`. The temp name is also
    ## the one rows W1/W7h use as a DIRECTORY on purpose, and a directory a user
    ## put there is not this writer's to remove: `file delete -force` deletes a
    ## whole tree and a plain `file delete` still removes an EMPTY directory
    ## (both measured, tclsh 8.6.17). `file type` is the probe rather than
    ## `file exists` because a DANGLING link answers exists=0 and type=link.
    ##
    ## ⚠ THE UNLINK/CREATE WINDOW IS REAL AND ORDERING DOES NOT CLOSE IT. What
    ## closes it is CREAT|EXCL, which POSIX requires to fail on an existing path
    ## INCLUDING a symlink, dangling or not -- measured here: `open <link>
    ## {WRONLY CREAT EXCL} 0666` raises `file already exists` over a link to a
    ## real file, over a dangling link and over a directory, and leaves the
    ## link's target untouched, while `open <path> w` over a dangling link
    ## CREATES the target. Anything planted in the window therefore makes the
    ## create FAIL and the user is told, instead of the write being followed
    ## somewhere else. The explicit 0666 is what Tcl's `w` already used: both
    ## land at 00644 under this shell's umask 0022 (measured).
    if {![catch {file type $tmp} tkind] && $tkind ne {directory}} { catch {file delete $tmp} }
    if {[catch {open $tmp {WRONLY CREAT EXCL} 0666} fp]} {
      _say "cannot save the parameter lists to $path: $fp. The file you already had is untouched."
      return 0
    }
    if {[catch {_chanconf $fp ; write_body $fp $old ; close $fp} err]} {
      catch {close $fp}
      catch {file delete -force $tmp}
      _say "cannot save the parameter lists to $path: $err. The file you already had is untouched."
      return 0
    }
    if {[catch {file rename -force $tmp $path} err]} {
      catch {file delete -force $tmp}
      _say "cannot save the parameter lists to $path: $err. The file you already had is untouched."
      return 0
    }
    ## A move replaces the file, and with it whatever permissions the user had
    ## put on their own copy.
    if {$mode ne {}} { catch {file attributes $path -permissions $mode} }
    return 1
  }

  ## THE HEADER BLOCK, EMITTED ONLY INTO A FILE THAT HAS NO LINES YET.
  ##
  ## ⚠ AN EXISTING FILE NEVER GAINS THE PDK PARAGRAPH, AND THAT IS RIGHT
  ## (issue 1388, ruling DD-11). The prose is the user's; only the `version`
  ## line is xschem's. So the user with a file written before this item keeps
  ## the header they have, which is still TRUE OF THEIR FILE -- every row in it
  ## is un-scoped and every sentence in it still describes what happens. A
  ## header that gained a paragraph about a feature the file does not use would
  ## be xschem rewriting sentences a person typed, which this batch has already
  ## reverted three items for.
  ##
  ## ⚠ TWO PRECEDENCE AXES, TWO SHORT LABELLED PARAGRAPHS, NOT ONE LONG ONE.
  ## The existing `flavor` paragraph is untouched, INCLUDING its `e.g.` lines,
  ## because row F5 reads that worked example back out of a freshly written
  ## file and builds its case from it. The PDK paragraph sits ABOVE it and
  ## names its own axis in its first two words, so a reader looking for one
  ## rule is not made to read the other. Interleaving them was the shape that
  ## made this a wall of text; labelling them is what keeps it readable. The
  ## wording is a LOOK DEBT (issue 1388) -- a green suite is not an eyeball.
  ##
  ## ⚠ THE PRECEDENCE PARAGRAPH MUST BE TRUE OF THE CODE BELOW IT. Both earlier
  ## attempts wrote "narrowest matching glob wins" into every settings file they
  ## emitted while implementing something else entirely -- a file lying to its
  ## own reader. The suite's row F5 reads the worked example back OUT of a
  ## freshly written file, builds the two-row file the example describes and
  ## asserts the winner the FILE names, so the sentence and the code cannot
  ## drift apart without reddening. Change the wording and the case it builds
  ## changes with it; change the rule and the row goes red.
  ##
  ## ⚠ AND F5'S FIXTURE HAS NO `[pdk ...]` SECTIONS, WHICH IS HOW THE PDK AXIS
  ## MADE THIS PARAGRAPH FALSE WITHOUT REDDENING IT (issue 1388). Row PK13
  ## reads the SAME worked example out of the SAME emitted header and drives it
  ## through a SECTIONED file, and PK13b drives it across the two tiers with
  ## the PDK arriving late. Three rows, one sentence, because the sentence is
  ## what the user reads.
  ## If you edit the `e.g.` line, keep its shape:
  ##     e.g. `flavor <class> <glob>` above `flavor <class> <glob>` wins on cell
  ##          <cellname>;
  proc _header_lines {} {
    variable version
    set out {}
    lappend out {# xschem operating-point parameter lists -- written by xschem.}
    lappend out {# See doc/claude/specs/op_param_lists.md section 4.4.}
    lappend out {#}
    lappend out {# THIS FILE IS DATA AND xschem RUNS NOTHING THAT IS IN IT. A strict}
    lappend out {# reader parses it row by row; a row it does not recognise is reported}
    lappend out {# and skipped. That is what makes it safe to accept from a teammate.}
    lappend out {#}
    lappend out {#   class <type-token> <broad-class>}
    lappend out {#   list  class  <class> <listname>}
    lappend out {#   list  flavor <class> <cell-name glob> <listname>}
    lappend out {#   param class  <class> <listname> <label> <rawparam> <kind>}
    lappend out {#   param flavor <class> <cell-name glob> <listname> <label> <rawparam> <kind>}
    lappend out {#   [pdk <name>]                a PDK section header}
    lappend out {#}
    lappend out {# scope:    class | flavor (a cell-name glob, matched case-insensitively)}
    lappend out {# listname: annotation | summary}
    lappend out {# kind:     0 -> i(dev[p]) , 1 -> bare dev[p] , 2 -> v(dev[p])}
    lappend out {#}
    lappend out {# PDK SCOPE: rows above the first `[pdk ...]` header apply to EVERY PDK,}
    lappend out {# and that is what every row in an older file is. Rows under `[pdk sky130A]`}
    lappend out {# apply only to a launch whose PDK is sky130A, and they BEAT the un-scoped}
    lappend out {# rows for the same list wherever in this file you put the section.}
    lappend out {# `[pdk *]` goes back to the every-PDK rows. A launch with NO PDK reads the}
    lappend out {# un-scoped rows and nothing else. xschem takes the PDK from PDK in your}
    lappend out {# environment, or from the workarea rc that declares it.}
    lappend out {# The TIER still wins first: your personal file is read before this project's,}
    lappend out {# so a row here replaces one there for the same list whatever section either}
    lappend out {# is in. A section never changes the flavor file-order rule below.}
    lappend out {#}
    lappend out {# PRECEDENCE among `flavor` rows: when two globs of the SAME class both}
    lappend out {# match a cell name, THE FIRST ONE IN THIS FILE WINS. Nothing is ranked}
    lappend out {# and nothing is measured for narrowness: put the row you want to win}
    lappend out {# ABOVE the other one.}
    lappend out {#   e.g. `flavor mos *nfet_01v8_lvt*` above `flavor mos *` wins on cell}
    lappend out {#        sky130_fd_pr__nfet_01v8_lvt; swap the two rows and the bare *}
    lappend out {#        wins.}
    lappend out {# A `flavor` row answers ONLY for the class named in its own row.}
    lappend out {# Your personal file is read BEFORE this project's, so its flavor rows}
    lappend out {# are tried first; a project row outranks a personal one only by using}
    lappend out {# the SAME class and the SAME glob.}
    lappend out {#}
    lappend out {# xschem edits only the rows it changed and leaves everything else in}
    lappend out {# this file exactly as you wrote it -- your comments, your ordering, and}
    lappend out {# rows a newer xschem wrote that this one does not understand.}
    lappend out {# It edits them WHERE THEY ALREADY ARE: in your PDK's section when this}
    lappend out {# file already has rows for that list there, otherwise in the un-scoped}
    lappend out {# rows. It never adds a `[pdk ...]` section for you -- type one yourself}
    lappend out {# and xschem maintains it from then on.}
    lappend out "version $version"
    return $out
  }

  ## ONE ENTRY, AS FILE ROWS. The `list` row is what lets an EMPTIED list
  ## survive a round trip instead of degrading to the PDK seed.
  proc _entry_lines {k} {
    variable lists
    set scope [lindex $k 0]
    set kf    [_key_fields $scope [lindex $k 1]]
    set ln    [lindex $k 2]
    set out [list "list $scope $kf $ln"]
    if {[info exists lists($k)]} {
      foreach t $lists($k) {
        lappend out "param $scope $kf $ln [lindex $t 0] [lindex $t 1] [lindex $t 2]"
      }
    }
    return $out
  }

  ## THE MERGE (ruling DD-7). `old` is the lines already in the file being
  ## written, in order. Everything this session did not change is copied
  ## VERBATIM -- comments, blank lines, the `version` row, and any row this
  ## build cannot identify. A dirty group is replaced IN PLACE at its FIRST
  ## line and its later lines are dropped; a dirty thing the file had no row
  ## for is appended.
  ##
  ## ⚠ WHY THERE IS NO PROVENANCE FIELD ANYWHERE HERE. Two attempts serialized
  ## a MERGED model and tagged each row with the tier it came from, and both
  ## deleted rows the user had typed -- one a personal `class mydiode diode`,
  ## the other an explicit `class nmos mos` BECAUSE ITS VALUE EQUALLED THE
  ## SHIPPED DEFAULT, which is precisely the row somebody writes down to
  ## protect against a default changing. You cannot delete a row you never
  ## parsed into a model, so provenance stops being a field to get right and
  ## becomes a property of which file you opened.
  ##
  ## ⚠ AND THE CLASS MAP HAS NO DEFAULT-COMPARISON FILTER any more. A token this
  ## session set is written whether or not it agrees with the shipped default.
  ## NOTHING IS STAMPED -- no timestamp, no pid, no hostname -- so writing the
  ## same store twice gives the same bytes and the file a team checks in diffs
  ## only when somebody changed something.
  ## ⚠ WHERE A DIRTY GROUP IS REWRITTEN, WHEN THE FILE HAS PDK SECTIONS
  ## (issue 1388). One pre-pass, so the answer is decided BEFORE a single line
  ## is emitted and the walk below cannot rewrite the first occurrence it
  ## happens to reach.
  ##
  ## THE RULE IS "EDIT THE ROWS WHERE THEY ALREADY ARE", and it is the
  ## conservative arm on purpose: if this file already carries rows for a dirty
  ## key in THIS launch's `[pdk ...]` section, the writer edits them THERE;
  ## otherwise it edits the un-scoped rows, which is byte-for-byte what it did
  ## before the PDK axis existed. So an existing file -- and the user has a
  ## real one -- is never rewritten into the new shape behind their back, and a
  ## per-PDK list is opted into by TYPING one header, once. The other arm, "a
  ## Save under a PDK always writes into that PDK's section", is a live rule
  ## debt (issue 1388): it reads the user's sentence more literally and it also
  ## grows a section into a file whose owner never asked for one, and strands
  ## the un-scoped rows as a stale list a no-PDK launch still reads back.
  ##
  ## ⚠ A SECTION FOR ANOTHER PDK IS NOT A CANDIDATE, EVER. Its rows were never
  ## read into this store (`_scope_applies` is false for them), so rewriting
  ## one from this session's model would be writing rows into a PDK this launch
  ## never loaded -- the deletion shape ruling DD-7 exists to make structurally
  ## impossible, arriving through the one door DD-7 does not watch.
  ##
  ## -> an array-shaped LIST of {<what> <id> <scope>} triples, `what` being
  ##    `class` or `list`. A dirty thing with no entry has no applicable row in
  ##    the file and is APPENDED, in the un-scoped section.
  proc _merge_where {old scoped} {
    set out {}
    foreach line $old sc $scoped {
      if {[lindex $sc 1] ne {row}} { continue }
      set scope [lindex $sc 0]
      if {![_scope_applies $scope]} { continue }
      set f [regexp -inline -all {\S+} $line]
      set what {} ; set id {}
      if {[lindex $f 0] eq "class" && [llength $f] == 3 \
          && [_is_dirty class [lindex $f 1]]} {
        set what class ; set id [lindex $f 1]
      } else {
        set k [_row_id $f]
        if {$k ne {} && [_is_dirty list $k]} { set what list ; set id $k }
      }
      if {$what eq {}} { continue }
      set hit -1 ; set i 0
      foreach e $out {
        if {[lindex $e 0] eq $what && [lindex $e 1] eq $id} { set hit $i ; break }
        incr i
      }
      if {$hit < 0} {
        lappend out [list $what $id $scope]
        continue
      }
      ## THE PDK SECTION WINS OVER THE UN-SCOPED ROWS, which is the same rank
      ## the READER applies. Reader and writer disagreeing about which rows a
      ## key "is" would put the edit in the section the launch does not read.
      if {[lindex $scope 0] eq {pdk} && [lindex [lindex $out $hit] 2 0] eq {any}} {
        set out [lreplace $out $hit $hit [list $what $id $scope]]
      }
    }
    return $out
  }

  proc _merge_where_of {where what id} {
    foreach e $where {
      if {[lindex $e 0] eq $what && [lindex $e 1] eq $id} { return [lindex $e 2] }
    }
    return {}
  }

  proc _merge_lines {old} {
    variable classmap ; variable dirtyclass ; variable version
    set out {}
    if {![llength $old]} {
      foreach l [_header_lines] { lappend out $l }
    }
    ## THE SAME SCANNER THE READER USED (invariant I1), so a header the reader
    ## honoured is a header here too.
    set scoped [_scope_lines $old]
    set where  [_merge_where $old $scoped]
    set cur    [list any {}]
    set doneclass {} ; set donekey {}
    foreach line $old sc $scoped {
      if {[lindex $sc 1] ne {row}} {
        ## A section header, well-formed or not, is the USER's line and is
        ## copied verbatim like every comment. Only the scope it opens matters
        ## here, and `_scope_lines` already resolved that.
        set cur [lindex $sc 0]
        lappend out $line
        continue
      }
      set cur [lindex $sc 0]
      set f [regexp -inline -all {\S+} $line]
      ## ⚠ XSCHEM OWNS THE `version` LINE. THE USER OWNS EVERY COMMENT.
      ## RULING DD-11, issue 1296. This is the ONE line of an existing file
      ## that is rewritten, and it is rewritten because leaving it is a
      ## correctness bug rather than a cosmetic one: a v1 file that gains v2
      ## rows still claiming `version 1` is SELF-REFUTING ON DISK -- the next
      ## load_conf reports the version mismatch and skips rows this build just
      ## wrote. DD-7's promise is about the rows the user WROTE, not about a
      ## machine stamp saying which dialect those rows are in.
      ## ⚠ AND THE HEADER PROSE IS DELIBERATELY *NOT* REFRESHED, though it goes
      ## stale the same way. Silently rewriting sentences a person typed is
      ## worse than an out-of-date comment, and this batch has reverted three
      ## items for deleting things the user wrote. Correctness wins on the
      ## machine field; the user wins on the prose.
      ## Bumping it does not silence anything: a v1 `flavor` row is one field
      ## short under v2, so it is still reported, by the arity gate instead of
      ## the version gate -- a better message, on the row that is actually
      ## wrong.
      ## ⚠ THE PDK AXIS DOES NOT MOVE IT (issue 1388): the version did not
      ## change, so this arm is inert for every file already at `version 2`,
      ## sectioned or not.
      if {[lindex $f 0] eq "version" && [llength $f] == 2 \
          && [lindex $f 1] ne $version} {
        lappend out "version $version"
        continue
      }
      if {[lindex $f 0] eq "class" && [llength $f] == 3 \
          && [_is_dirty class [lindex $f 1]] \
          && [_merge_where_of $where class [lindex $f 1]] eq $cur} {
        set tok [lindex $f 1]
        if {[lsearch -exact $doneclass $tok] >= 0} { continue }
        lappend doneclass $tok
        if {[info exists classmap($tok)]} { lappend out "class $tok $classmap($tok)" }
        continue
      }
      set k [_row_id $f]
      if {$k ne {} && [_is_dirty list $k] \
          && [_merge_where_of $where list $k] eq $cur} {
        if {[lsearch -exact $donekey $k] >= 0} { continue }
        lappend donekey $k
        foreach l [_entry_lines $k] { lappend out $l }
        continue
      }
      lappend out $line
    }
    ## ⚠ AN APPENDED ROW LANDS AT THE END OF THE FILE, AND THE END OF A
    ## SECTIONED FILE IS INSIDE A SECTION. Without this the writer would give a
    ## brand-new un-scoped list the last section's PDK -- silently, and only
    ## for users who had adopted sections, which is the worst possible
    ## population to break. `[pdk *]` is emitted ONLY when something is
    ## actually appended AND the walk ended somewhere other than the un-scoped
    ## scope, so no existing file gains a line it did not need.
    set tail {}
    foreach tok [lsort [array names dirtyclass]] {
      if {![_is_dirty class $tok]} { continue }
      if {[lsearch -exact $doneclass $tok] >= 0} { continue }
      if {![info exists classmap($tok)]} { continue }
      lappend tail "class $tok $classmap($tok)"
    }
    foreach k [_keys] {
      if {![_is_dirty list $k]} { continue }
      if {[lsearch -exact $donekey $k] >= 0} { continue }
      foreach l [_entry_lines $k] { lappend tail $l }
    }
    if {[llength $tail] && [lindex $cur 0] ne {any}} {
      lappend out [_scope_header [list any {}]]
    }
    foreach l $tail { lappend out $l }
    return $out
  }

  ## The body, split out only so the writer above can wrap the whole of it plus
  ## the close in ONE catch.
  ##
  ## ⚠ `old` IS AN OPTIONAL TRAILING ARGUMENT AND THE REQUIRED ARITY DOES NOT
  ## MOVE: every existing caller passes exactly one argument and row J1 pins it.
  proc write_body {fp {old {}}} {
    foreach line [_merge_lines $old] { puts $fp $line }
    return 1
  }

  ## -----------------------------------------------------------------------
  ## THE APPLY DOOR (invariant I5)
  ## -----------------------------------------------------------------------
  ## Write the user's lists into the descriptor registry, through
  ## op_annot::register and nothing else. Returns the list of types
  ## re-registered. A class the user owns nothing for is left strictly alone --
  ## applying the seed back over the PDK's own descriptor would be a no-op that
  ## still bumped the generation counter and still rewrote a dict this file
  ## does not own.
  ## The FLAVOR entries are deliberately not applied: a descriptor is keyed on
  ## the `type=` token and a flavor is a cell-name glob, so only the display
  ## path can narrow that far.
  ##
  ## ⚠ TWO FIELDS ARE WRITTEN AND A THIRD IS CARRIED THROUGH UNTOUCHED
  ## (rulings DD-4, DD-6 and DD-13). The third one first, because it is the
  ## one this proc must be incapable of writing:
  ##   declared  WHAT THE PDK DECLARED. `op_annot::register` is its only
  ##             writer and `_params` its only reader. `apply` never names it:
  ##             it reads the whole descriptor, sets the two fields below on
  ##             it and re-registers, and `register` preserves a declaration it
  ##             is handed -- so the declaration rides through every apply by
  ##             CONSTRUCTION rather than by anybody remembering to copy it.
  ##             Row N12 of tests/headless/test_op_param_store_1245.tcl counts
  ##             the writing lines in this file and in apply's own body, and
  ##             expects zero of each.
  ## and the two this proc does write:
  ##   params  the UNION of the annotation and summary lists AND OF THIS TYPE'S
  ##           OWN DECLARATION (`_merge_declared`, appended LAST) -- WHAT THE
  ##           RUN COMPUTES. op_annot::_cards_for builds the .save cards from it,
  ##           so a parameter the user only summarises is still in the raw, and
  ##           so is one she hid but a `derived` row still needs as an operand.
  ##   shown   the annotation half of that union -- WHAT THE SHEET DRAWS.
  ##           op_annot::text is its only reader. Without it a Delete has no
  ##           visible effect at all: `params` would keep growing and the sheet
  ##           would keep drawing every row of it.
  ##
  ## ⚠ THE SUBSET IS BUILT, NOT ASSERTED, AND THAT DISTINCTION IS THE WHOLE
  ## POINT. An earlier revision of this door copied the annotation list
  ## wholesale into `shown` and asserted in a comment that it was a subset of
  ## `params`; it was MEASURED FALSE on issue 1288's live duplicate-label door
  ## (`set_list class mos annotation {{A id 0} {A gm 1}}` is accepted with no
  ## report), _save_set's label dedup dropped the second row, and
  ## op_annot::_kind then raised on a label that was in no params list. So
  ## `shown` is DERIVED BY FILTERING the very list written to `params`: every
  ## element of `shown` is literally an element of `params`, for every input,
  ## whether or not 1288 is ever fixed.
  proc _apply_owns {c} {
    return [expr {[owns class $c annotation] || [owns class $c summary]}]
  }

  ## The union, in annotation-then-summary order, deduped BY LABEL with the
  ## annotation triple winning. Taken over `effective`, NEVER `get_list`,
  ## because an UNOWNED list answers the PDK seed.
  ##
  ## ⚠ THIS COMMENT USED TO SAY the union "can only ever be a SUPERSET of what
  ## `params` already held, so no PDK row is ever lost". THAT WAS TRUE WHEN IT
  ## WAS WRITTEN AND IS NOT TRUE NOW, and the change is worth stating rather
  ## than deleting. It held only WHILE ONE OF THE TWO LISTS WAS UNOWNED: the
  ## unowned one fell through to the seed and dragged every PDK row into the
  ## union for free. Item B5's button column is precisely the thing that owns
  ## BOTH lists, and two broad-scope Deletes then left a union with no row for
  ## the deleted parameter at all -- so `op_annot::_cards_for` stopped emitting
  ## its `.save` card and, under measured simulator rule R1, the parameter
  ## stopped existing in the raw. That is the outcome ruling DD-4 exists to
  ## forbid. The feature grew out from under the comment.
  ##
  ## WHAT PROTECTS THE PDK'S ROWS NOW IS NOT AN ACCIDENT OF OWNERSHIP: `apply`
  ## unions this list with THE TYPE'S OWN DECLARATION (`_merge_declared`), so
  ## every row the PDK declared is in `params` whoever owns what. `_save_set`
  ## itself is unchanged and still knows nothing about the declaration -- the
  ## third input is per TYPE and this proc is per CLASS.
  proc _save_set {cls} {
    set out {}
    set seen [dict create]
    foreach ln {annotation summary} {
      foreach t [effective $cls $ln] {
        set l [lindex $t 0]
        if {[dict exists $seen $l]} { continue }
        dict set seen $l 1
        lappend out $t
      }
    }
    return $out
  }

  ## The rows THIS TYPE declared, through the one door that validates them.
  proc _declared_rows {t} {
    return [_params $t]
  }

  ## THE THIRD INPUT TO THE UNION (ruling DD-4): the class's save set, plus the
  ## rows this TYPE declared that the save set does not already carry by label,
  ## APPENDED LAST.
  ##
  ## WHY IT IS NEEDED AT ALL. DD-13's declaration key fixes the SEED, and on
  ## its own it still leaves item B5's other measured harm alive: with both
  ## lists owned, the union of the two has no row for a deleted parameter, so
  ## the `.save` card goes and the simulator stops computing it. DD-4 is
  ## unqualified -- "Delete removes a parameter from what is DRAWN. It never
  ## changes what the simulator is asked to save" -- and it states its own
  ## price: "a user who deletes a row to make the deck smaller does not get a
  ## smaller deck". Saving an operating-point parameter is measured free (spec
  ## §3.3), so that price is a slightly larger raw and nothing else.
  ##
  ## WHY LAST. `_show_set` filters the union IN UNION ORDER, so a declaration
  ## placed FIRST would freeze the drawn order -- which is exactly what DD-13
  ## rejected its option (b) for, and what item B5's Up/Down buttons exist to
  ## change. Appended last, the declaration re-enters `params` behind whatever
  ## the user chose and cannot be drawn at all unless her annotation list names
  ## its label, in which case the label was already in the union.
  ##
  ## WHY THE TYPE'S OWN DECLARATION AND NOT `seed $cls`. `seed` is
  ## first-lexical-wins across the class and merges nothing, so a sibling type
  ## that declares differently would lose its own rows to the winner's.
  ##
  ## NOTHING IS INVENTED (D-4): every appended row was declared by the PDK or
  ## by the user's own rc, and a malformed row is skipped rather than guessed.
  proc _merge_declared {saveset t} {
    set seen [dict create]
    foreach _r $saveset {
      if {[catch {lindex $_r 0} l]} { return $saveset }
      dict set seen $l 1
    }
    set out $saveset
    foreach _r [_declared_rows $t] {
      if {[catch {lindex $_r 0} l]} { continue }
      if {[dict exists $seen $l]} { continue }
      dict set seen $l 1
      lappend out $_r
    }
    return $out
  }

  ## The display list: the union FILTERED by the annotation list's labels.
  ## Never a copy of the annotation list -- see the subset paragraph above.
  proc _show_set {cls saveset} {
    set keep [dict create]
    foreach t [effective $cls annotation] { dict set keep [lindex $t 0] 1 }
    set out {}
    foreach t $saveset {
      if {[dict exists $keep [lindex $t 0]]} { lappend out $t }
    }
    return $out
  }

  ## -----------------------------------------------------------------------
  ## THE ISSUE-1292 UNDO: apply un-does EXACTLY its own write, in full or not
  ## at all
  ## -----------------------------------------------------------------------
  ## Record what apply is about to overwrite and what it wrote, so that a later
  ## apply over a class NOBODY OWNS ANY MORE can put both fields back --
  ## including REMOVING `shown`, which no verb could do before and which is why
  ## `reset` + `apply` used to leave the sheet narrowed for the session.
  ##
  ## THE PRE-STATE IS CAPTURED ONCE AND THEN HELD, so N applies undo to the
  ## state before the FIRST of them, not to the state the previous one left.
  ## It is RE-captured the moment the descriptor apply is about to rewrite is
  ## no longer the one apply last left there -- a PDK re-registering, a user's
  ## rc under invariant I5, a suite's fresh fixture -- because an undo must
  ## never reach back past a write this file did not make.
  proc _record_applied {t pre post} {
    variable applied
    set rec {}
    if {[info exists applied($t)]} {
      set old $applied($t)
      if {[_state_eq $pre params [dict get $old wparams]] \
       && [_state_eq $pre shown  [dict get $old wshown]]} {
        set rec $old
      }
    }
    if {$rec eq {}} {
      set rec [dict create pparams [_key_state $pre params] \
                           pshown  [_key_state $pre shown]]
    }
    dict set rec wparams [_key_state $post params]
    dict set rec wshown  [_key_state $post shown]
    set applied($t) $rec
    return {}
  }

  ## May this type's descriptor be put back? ONLY when this session's apply
  ## wrote it AND both fields are still byte-identical to what apply wrote.
  ## Anything else has been rewritten by someone else and is not ours to
  ## touch -- issue 1292 §4 option 1's demanded distinction, made checkable.
  proc _restorable {t} {
    variable applied
    if {![info exists applied($t)]} { return 0 }
    if {[catch {::op_annot::descriptor $t} d]} { return 0 }
    if {$d eq {}} { return 0 }
    set rec $applied($t)
    if {![_state_eq $d params [dict get $rec wparams]]} { return 0 }
    if {![_state_eq $d shown  [dict get $rec wshown]]}  { return 0 }
    return 1
  }

  ## Put the recorded pre-state back, through ::op_annot::register and through
  ## nothing else. A direct `set ::op_annot::desc(...)` would be correct Tcl,
  ## would not bump ::op_annot::gen, and would leave the sheet narrowed until
  ## an unrelated redraw -- invariant I5 failing silently, which is the exact
  ## failure section A of the suite exists to prevent.
  ## The record is dropped on the way out: the undo is not repeatable, because
  ## after it there is nothing of this file's in the descriptor to undo.
  proc _restore_applied {types} {
    variable applied
    set out {}
    foreach t $types {
      if {![info exists applied($t)]} { continue }
      set rec $applied($t)
      if {[catch {::op_annot::descriptor $t} d]} { unset applied($t) ; continue }
      if {$d eq {}} { unset applied($t) ; continue }
      set d [_apply_state $d params [dict get $rec pparams]]
      set d [_apply_state $d shown  [dict get $rec pshown]]
      if {[catch {::op_annot::register $t $d} err]} {
        _say "cannot restore the parameter lists for symbol type \"$t\": $err"
        continue
      }
      unset applied($t)
      lappend out $t
    }
    return $out
  }

  ## ⚠ TWO PASSES, AND THE FIRST ONE TOUCHES NOTHING (invariant I1: one seed,
  ## read once, before anything rewrites it). `_save_set` reaches the PDK seed
  ## through ::op_annot::descriptor and the second pass rewrites exactly those
  ## descriptors, so a single loop would let the first type applied become the
  ## seed the second type reads -- nmos sorts before pmos and both map to the
  ## same class, so it is reachable, not theoretical.
  proc apply {args} {
    variable classmap ; variable applied
    if {[llength $args]} {
      set cands $args
    } else {
      ## ⚠ THE SESSION RECORD IS PART OF THE BARE CANDIDATE SET (issue 1292).
      ## `reset` puts `classmap` back to the SHIPPED map, so a type the user
      ## class-mapped herself would otherwise drop out of the candidate set at
      ## the exact moment the undo needs it and stay narrowed for the session.
      set cands [concat [array names classmap] [array names applied]]
    }
    set save [dict create]
    set order {}
    set undo {}
    foreach t [lsort -unique $cands] {
      set c [class $t]
      if {![_apply_owns $c]} {
        ## Nobody owns this class any more. If this session's apply wrote the
        ## descriptor and nothing has touched it since, un-do exactly that
        ## write; otherwise forget the record and leave the descriptor alone.
        if {[_restorable $t]} {
          lappend undo $t
        } elseif {[info exists applied($t)]} {
          unset applied($t)
        }
        continue
      }
      if {[catch {::op_annot::descriptor $t} d]} { continue }
      if {$d eq {}} { continue }
      if {![dict exists $save $c]} {
        dict set save $c [_save_set $c]
      }
      ## PER TYPE, NOT PER CLASS: the third input to the union is THIS TYPE's
      ## own declaration (DD-4, `_merge_declared`), and two types of one class
      ## are entitled to declare differently. `_show_set` then filters the very
      ## list that is written to `params`, so the DD-6 subset still holds by
      ## construction.
      set ps [_merge_declared [dict get $save $c] $t]
      lappend order [list $t $d $ps [_show_set $c $ps]]
    }
    set done {}
    foreach e $order {
      set t [lindex $e 0]
      set d [lindex $e 1]
      if {[catch {dict set d params [lindex $e 2]} d2]} { continue }
      if {[catch {dict set d2 shown [lindex $e 3]} d3]} { continue }
      if {[catch {::op_annot::register $t $d3} err]} {
        _say "cannot register the parameter lists for symbol type \"$t\": $err"
        continue
      }
      ## ⚠ `[lindex $e 1]`, NOT `$d`. `dict set d params ...` WRITES BACK INTO
      ## THE VARIABLE `d` as well as answering the new dict, so by this line
      ## `$d` is already the post-apply descriptor. Passing it as the PRE state
      ## made every record's pre-state equal to its own write, and the issue-1292
      ## undo then restored the state before the LAST apply instead of the state
      ## before the FIRST -- measured, not reasoned: a 40-edit storm undid to a
      ## descriptor still carrying three of the user's rows. The list element is
      ## untouched by the dict writes above, so it is the pre state.
      _record_applied $t [lindex $e 1] $d3
      lappend done $t
    }
    foreach t [_restore_applied $undo] { lappend done $t }
    return $done
  }
}

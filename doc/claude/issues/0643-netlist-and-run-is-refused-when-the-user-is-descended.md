# 0643 — Netlist and Run is REFUSED (Status: Error, no run) when the user is descended into the design

STATUS: **FIXED 2026-09-08** by the `descend_run_batch` (items **A** and **B**;
item C's pinning rows were not yet in the working tree when this was written —
see "Still owed"), on top of HEAD `19f8e351`. `Netlist and Run` now works from **any level of the
design's own hierarchy**; the refusal survives only for a design that is nowhere
on this window's stack. Two seams moved, a third was deliberately left alone,
and the whole thing is pinned by `test_ase_core` **RT0–RT12** and
`test_ase_window`'s **R block**. See **"Resolution, 2026-09-08"** at the end of
this file for what moved, the measurements, and what was left standing.

*History of this line: OPEN — measured 2026-08-23 by the 0616 crew, REPORTED BY
THE USER 2026-09-08 and re-measured that day (see "The user's report" below).
Deliberately not fixed in 0616 (rung L2 plus a named hazard, see below). It was
the largest remaining defect on the Netlist-and-Run button, and it sat exactly
where the OP-annotation workflow puts the user.*

## What happens

Descend one level into the design (`xschem descend` into `x1` of `tb_bandgap`,
`currsch` 0 → 1) — i.e. stand exactly where "run, then descend and press 6"
leaves you — and press **Netlist and Run**. Measured:

```
CASE C — DESCENDED: user is one level down (where "press 6" happens)
  xschem get schname = .../sky130_tests_ase/bandgap/schematic/bandgap.sch   currsch=1
  do_run GUARD (... ne design_path) = 1
  <<< UNMAP toplevel . >>>
  <<< MAP   toplevel . >>>
  status = 'Status: Error'  background=red
  run_id = ''
  >>> RESULT: toplevel . UNMAPPED 1 time(s), re-MAPPED 1 time(s)
```

No simulation runs. The status segment goes red and `run_id` stays empty.

## Why

`do_run`'s guard `[file normalize [xschem get schname]] ne $dpath` fires (you are
on `bandgap.sch`, not `tb_bandgap.sch`). It routes through
`ase::ui::design_window`, and `raise_design_editor`'s **second** loop — the
issue-0168 descended-window match, which matches the design anywhere in a
window's `sch` stack — finds this window and returns **1 without ascending**.
`design_window` therefore reports success, `do_run`'s post-check re-tests the
same guard, it is still true, and the run is refused:

> ase: design is not the current schematic; open it via Session > Design Window first

So the user gets the flash **and** no simulation. After 0616's fix the flash is
gone (the `ifhidden` arm skips the re-map on a visible window) but the refusal is
untouched.

## Why 0616 did not fix it

Rung **L2** (smallest blast radius) plus a named hazard. Making the guard pass by
**ascending** would change `currsch` immediately before a run, which is issue
**0608**'s ordering trap — *read the raw at the TOP, then descend; descending
first empties `sim_sch_path` and every device row goes blank*. 0616's fix
deliberately changes window/tab context only and never touches `currsch`, so it
leaves 0608 alone. Fixing this one cannot.

**Rejected in 0616:** relaxing `do_run`'s guard to accept a descendant. That only
moves the same refusal down into `ase::netlist`'s own guard ("design is not the
current schematic"), which is a real guard with real callers.

## What a fix has to decide

1. Should a descended user's **Netlist and Run** netlist the *design* (ascend,
   netlist, and put them back where they were), or should it refuse *clearly*
   instead of with a bare red status?
2. If it ascends, `sim_sch_path` / descend-state ordering must be re-checked
   against 0608 before and after — that is the whole point of the hazard.
3. Either way the user needs a sentence, not a red rectangle. Today the echo goes
   to the status line and names a menu item, which is the same detour 0616 was
   about.

## Acceptance

- Pressing **Netlist and Run** while descended either runs the design's deck, or
  reports in words what it did and why, with `run_id` and the status segment
  consistent with each other.
- 0608's rows stay green either way.
- A regression row in `tests/headless/test_ase_window.tcl` descends first and
  asserts the outcome (there is none today; the W6m rows cover the *foreign
  window context* case, not the *descended* case).

---

## The user's report, 2026-09-08 — and what it changes

The user hit this on their own bench, two levels down, and did not read the
refusal as a guard:

> I open sky130_tests_ase/tb_bandgap, then the debug_st1 state and then,
> Session > Design Window so that the schematic is linked to that ASE-L and
> then, I descend into x1 and again x1. Now, I click the N&> (Netlist and Run
> button) in ASE-L to get: `ase: design is not the current schematic; open it
> via Session > Design Window first`. Where does this inane restriction come
> from? There is no such limitation in Cadence's Analog Design Environment
> (ADE-L), which we want be better than.

That reframes the issue. It is no longer "the refusal is unclear"; it is
**ADE-L parity**: in ADE-L the design is a `lib/cell/view` and the tool
netlists it whatever window is in front. This one is to be REMOVED, not
re-worded.

### Measured 2026-09-08 on `:99` (openbox), HEAD `19f8e351`, sky130A workarea

**1. The guard is protecting against a real wrong answer.** `xschem netlist`
netlists `xctx->sch[xctx->currsch]` — the level you are STANDING on
(`global_spice_netlist`, spice_netlist.c:359-373), not the top of the stack.
Same session, same file, two netlists:

```
at level 0 : ** sch_path: .../tb_bandgap/schematic/tb_bandgap.sch      14862 bytes, 8 .subckt
descend x1, x1
at level 2 : ** sch_path: .../bandgap_opamp/schematic/bandgap_opamp.sch  4685 bytes
```

Without the guard, `N&>` two levels down would have silently simulated the
op-amp on its own — no sources, no testbench, and a results file that looks
fine. So the refusal is a *symptom*. The defect is that xschem's netlister is
bound to the viewport, and ASE-L's design is not.

**2. Ascend / netlist / re-descend works, is exact, and is cheap.** The replay
names come straight out of the hierarchy the user is standing in, so nothing
has to be remembered across the round trip:

```tcl
set nlev [xschem get currsch]
for {set i 1} {$i <= $nlev} {incr i} {
  lappend names [lindex [split [string trim [xschem get sch_path $i] .] .] end]
}
for {set i 0} {$i < $nlev} {incr i} { xschem go_back 2 }
xschem netlist -noalert $nl
foreach n $names { xschem descend -inst $n }
```

Measured, 2 levels: `sch_path` restored to `.x1.x1.`, both descends returned 1
with an empty `descend_error`, **88 ms** for the whole round trip, and the
netlist taken after the ascent is **byte-identical** (`cmp`) to one taken at
the top before descending.

**3. ⚠ THE DRIVER'S FIRST READING OF THE RESULTS BASIS WAS WRONG, and the
correction is recorded here rather than deleted.** The claim, made 2026-09-08
before any code was written, was that `ase::attach_raw`/`attach_dbs` carried the
same bug and that `Simulation > Run` pressed while descended already annotates
blanks. **Both are false.** They came from measuring a *bare* `xschem raw read`,
which is not the door annotation uses.

The annotation door passes a hierarchy level, and has since issue 0684:

```
ase::ui::annot_ensure_loaded   ->  level from ase::session_for_current
  -> op_annot::db_attach $path $level
    -> xschem annotate_op $np $level
      -> scheduler.c:2539-2543   raw->level = level ; raw->schname = sch[level]
```

Measured standing two levels down in tb_bandgap with the `debug_st1` session
open, on the shipped raw:

```
ase::session_for_current            ->  {sky130_tests_ase/tb_bandgap/debug_st1 0 ...}   level 0
op_annot::db_attach $raw 0          ->  raw_level=0   sim_sch_path='x1.x1.'   correct
op_annot::db_attach $raw {}         ->  raw_level=2   sim_sch_path=''         the bare door
```

So the results basis at depth is **already right**, and this issue is the netlist
only. What the earlier text got right is the underlying mechanism —
`sch_waves_loaded()` (draw.c:2853) resolves the basis by matching `raw->schname`
against the hierarchy stack, and a read with no level stamps it at `currsch`.

**One narrow hole IS real and is deliberately not closed here.**
`annot_ensure_loaded` takes the level only when `[lindex $s 0] eq $key`, so when a
*different* session — one bound to a descendant cell — owns the nearest level,
this session's post-run refresh passes `{}` and stamps at `currsch`. Filed
separately; not reachable on the reported bench.

### What the fix has to be

One helper, two call sites — invariant I1, one definition of "put the design
in front, do this, put the user back":

* `ase::netlist` (ase.tcl:5965) — the guard the user hit;
* `ase::ui::do_run` (ase_window.tcl:7256) — the pre-check that mints the
  sentence, which becomes "is the design REACHABLE", not "is it current";

`ase::attach_dbs` is NOT one of them — see (3). `ase::ui::do_run_existing`
(`Simulation > Run`) is not one either: it never re-netlists, so it never needed
the guard, and its annotation is correct at depth by (3).

The already-open-in-another-window case is NOT part of this: `ase::ui::design_window`
+ `raise_design_editor` already switch the xschem context to the window holding
the design (0616), and that half works.

**The one safety rule the helper must carry** is not new either — `op_annot.tcl`
already descends and returns the whole hierarchy on every `N&>` (the OP-card
walk), and it already wrote the doctrine:

* `go_back` calls `load_backup_as` whenever a `<cell>~.sch` exists, and that
  ends in `set_modify(1)` — a clean buffer comes back MODIFIED, and on the
  shipped `bandgap_opamp` a clean 73-instance buffer came back with 72
  (op_annot.tcl I4, issues 0495/0626);
* with `autosave_backup` 0 and a genuinely modified buffer, descend + go_back
  silently REVERTS the unsaved edit;
* so `op_annot::_park_backup` parks the flag for a clean buffer, and
  `op_annot::_assert_saveable` REFUSES the modified + `autosave_backup 0`
  combination outright rather than walking it.

The new helper must reuse both, not re-derive them. A round trip that loses a
user's unsaved edits to save them a menu click is a worse defect than the one
being fixed.

### Acceptance, extended

- `N&>` and `Run` both work from any hierarchy level of the design, and from a
  window showing something else, with no refusal and no menu detour.
- The netlist taken while descended is byte-identical to the one taken at the
  top (measurable with `cmp`, as above).
- After the run, `sim_sch_path` at the user's level is the deck-absolute one, so
  annotation is populated at whatever level they are standing on. This already
  holds (3) and gains a PINNING row rather than a fix.
- The user ends where they started: same level, same `sch_path`, same zoom, and
  `modified` unchanged.
- A descended level with unsaved edits and `autosave_backup` off is REFUSED with
  a sentence that names the cell and the remedy — never walked.
- Rows in `tests/headless/test_ase_window.tcl` (descended `N&>`), and in
  `test_op_annot.tcl` for the raw basis at depth.

---

## Resolution, 2026-09-08 — `descend_run_batch`

Batch directory: `doc/claude/descend_run_batch/` (`CREW_BRIEF.md`, `PLAN.md`,
`DECISIONS.md`, `LEDGER.md`, `receipts/`). Everything below is quoted from the
crews' receipts; nothing here was re-derived. Every `file:line` in this section
was re-read in the tree before being written down.

### The two seams that moved

**1. `ase::netlist` (`src/ase.tcl:6390`) — four arms, one of them new.**

```
design IS current                    -> ase::netlist_in_place        (a, unchanged)
headless (no ::has_x)                -> xschem load $path ; body     (b, unchanged)
design is on THIS window's stack     -> ase::with_design_current      (c, NEW)
otherwise                            -> refuse, in new words          (d)
```

The work is `ase::netlist_in_place` (`src/ase.tcl:6356`), split out of the old
body so the guard and the work are separable. `ase::op_cards_capture` stays
**inside** it (issue 0436): its precondition is that the design is the current
schematic, and the round trip is what now guarantees that.

The round trip is `ase::with_design_current {dpath script}`
(`src/ase.tcl:6175`), over five smaller procs in the same section:
`ase::hier_instnames` (`:5989`, a deliberate **copy** of
`cadence::hier_instnames`, `utils/cadence_nav.tcl:45` — `src/ase.tcl` ships and
is sourced by stock xschem, `utils/cadence_nav.tcl` is neither, the rule
`src/rdw.tcl:4360-4366` already wrote), `ase::stack_level` (`:6016`, shallowest
match first — see DECISIONS D2), `ase::hier_ascend_to` (`:6044`),
`ase::hier_stranded_msg` (`:6059`) and `ase::hier_redescend` (`:6088`, which
re-reads `currsch` every step rather than replaying blindly, so a short ascent
cannot walk the user *past* their entry level).

**2. `ase::ui::do_run` (`src/ase_window.tcl:7228`) — one predicate, in two
places, plus one sentence.** `[file normalize [xschem get schname]] ne $dpath`
became `[ase::stack_level $dpath] < 0`, in the pre-check and again in the
post-routing re-check. `ifhidden` is kept (0616 unchanged), 1389's `run_busy`
is still the first statement, and `ase::ui::do_run_existing` was confirmed by
reading — end to end through `ase::run_existing` and `ase::run_deck` — to need
no change at all, and pinned as row R12 rather than left as prose.

### The seam that did NOT move

`ase::attach_dbs` / `xschem annotate_op` — see section (3) above. The annotation
basis at depth was already right and the batch **pins** it rather than changing
it. Anyone who finds themselves editing it should re-read (3) first.

### What it costs — the user's "without adding cost" answer

The round trip is *already made twice* on every press of that button:

| already happens on every `N&>` | measured |
|---|---|
| `xschem netlist` — the C netlister loads every sub-block and restores | 66 ms |
| `op_annot::save_cards` — the Tcl walk behind the 468 OP save cards | 177 ms |
| **what this batch adds** | **28.1–30.4 ms** (five trips, two levels) |

`global_spice_netlist` already calls `unselect_all`, so selection churn was
already paid too. `::keep_symbols` is deliberately **left alone** (DECISIONS
D3), which is what keeps the deck the user receives byte-identical to today's.

### The measurements that close the acceptance list

On `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap`, `:99` with openbox live,
`./src/xschem --pipe -q --nolog`, `cadence_style_rc` sourced from inside the
script (receipt 01 §3):

```
top.netlist.bytes        = 14862   (8 .subckt)
descend x1, x1           -> ret 1, 1 ; descend_error empty both times
here.netlist.bytes       = 4685    <- the wrong answer the guard was protecting
trip.ms (walk + netlist) = 85.2
walk alone, 5 trips (ms) = 29.6  28.3  28.1  30.4  29.7
trip.drawcount.delta     = 1       <- ONE repaint, at the end
post.currsch / sch_path  = 2 / .x1.x1.
view before/after        = identical to 15 significant figures
post.modified / autosave = 0 / 1
cmp top.spice desc.spice = 0       <- BYTE-IDENTICAL, 14862 == 14862
```

Against "Acceptance, extended", item by item:

* *`N&>` works from any hierarchy level, no refusal, no menu detour* — receipt
  02 rows **R4** (reaches `ase::run` exactly once, refuses nothing) and **R13**
  (the real `Simulation > Netlist and Run` menu entry, pressed two levels down
  through a live ASE-L window, status not reddened).
* *byte-identical netlist* — `cmp` 0, above, and receipt 01 row **RT11**.
* *`sim_sch_path` correct at the user's level* — already true, section (3);
  the pinning row is item C's and is **still owed** (see below).
* *user ends where they started* — `.x1.x1.`, `currsch` 2, same view, `modified`
  unchanged: rows **RT4** and **R5**.
* *unsaved edits + `autosave_backup` off are REFUSED, never walked* — row
  **RT6**, verbatim sentence:
  > `ase: 'descend_child.sch' has UNSAVED edits and autosave backup is off. Netlisting the design from here has to leave this level and come back, and with no autosave backup that round trip silently REVERTS unsaved edits (issue 0626). Save this cell, or turn Options > Autosave backup on, and press it again.`
* *rows in `test_ase_window`* — the whole **R block**, R1–R14.

### Two hazards the fix had to carry, and does

**The `~` doctrine (issues 0495/0626).** `go_back` calls `load_backup_as`
whenever a `<cell>~.sch` sits beside the cell, and that ends in `set_modify(1)`.
The trip therefore parks `autosave_backup` at 0 for a **clean** entry buffer
(`op_annot::_park_backup`'s idiom, restored unconditionally), **refuses** the
modified + `autosave_backup 0` combination outright, and **carries** the
modified + `autosave_backup 1` case (DECISIONS D4). The park is row-1-only for a
measured reason: `load_backup_as` early-returns on
`!tclgetboolvar("autosave_backup")` (`src/save.c:6186`), so parking in the carry
row would disable the very restore the carry depends on.

**One thing `op_annot`'s walk never had to solve.** op_annot descends *below*
its entry level and comes back, so `go_back`'s `load_backup_as` restores its
entry buffer for it. This batch **pops** the entry level and returns by
`descend`, and `descend_schematic()` uses plain `load_schematic()`. The restore
is an explicit `xschem load_backup <entrycell> 0` after the last re-descend.

**A read-only axis PLAN.md did not have, found by crew A.**
`src/cadence_style_rc:564` sets `descend_readonly 1`, so in the setup this user
actually runs *every descended level is a read-only browse buffer* and
`xschem get modified` reads 0 at depth however much is typed — rows 2 and 3 of
the safety table are only reachable after a Ctrl-2. Worse, the final `descend`
re-applies `descend_readonly`, so `load_backup_as`'s `set_modify(1)` landed on a
buffer that had just been made read-only again and the carried edits came back
with `modified` **0** — one close-without-prompt from being lost a second time.
Fixed by snapshotting `xschem get readonly` at entry and restoring it *before*
the `load_backup`. Row **RT8** pins both directions.

### The surviving refusal, and why there are two tails

The refusal is not deleted, it is narrowed: it fires only for a design that is
**nowhere on this window's stack**. Its head is minted once —
`ase::design_unreachable_msg {design {remedy {}}}` (`src/ase.tcl:6139`) →
`ase: design <X> is not open in this window` — and the *tail* is the caller's
(DECISIONS **D6**, raised by crew B as B-2):

| door | tail | why it is true there |
|---|---|---|
| `ase::netlist` (`src/ase.tcl:6420`) | `; open it via Session > Design Window first` | a CIW or script caller has **not** tried that route |
| `ase::ui::do_run` (`src/ase_window.tcl:7307`) | `; Session > Design Window did not open it` | this arm is reached **only after** `design_window ifhidden` has run and failed |

Both doors call the mint; verified by grep — the only two `is not open in this
window` literals in `src/` are the mint itself and its own comment. The words
`is not the current schematic` are gone from both doors (rows **R8** and
**RT12** assert the absence).

**Both tails are UNRATIFIED user-visible copy** and carry a `rule` debt against
this issue number. Crew B's own note: the surviving refusal is harder to reach
than PLAN.md implied — `ase::ui::design_window`'s not-open-anywhere path always
ends in `xschem load -gui $dpath` and returns 1 (`src/ase_window.tcl:6850`),
after which the design *is* on some window's stack, so the refusal fires only
when `design_window` itself fails to produce the design. Worth knowing before
anyone tunes its wording for frequency.

### Suites, by name and status (receipts 01 §6 and 02 §6)

| suite | arm | status | checks | floor |
|---|---|---|---|---|
| `test_ase_core` | `--nogui` | ALL PASS | **216** | 203 → raised by 13 |
| `test_ase_core` | `:99` | ALL PASS | **216** | 203 → raised by 13 |
| `test_ase_window` | `--nogui` | ALL PASS | **49** | 32 → raised to 49 |
| `test_ase_window` | `:99` | ALL PASS | **267** | 245 → raised to 267 |
| `test_ase_final` / `test_ase_final_gf180` / `test_ase_persist` / `test_ase_view` / `test_op_dump_altshow` / `test_op_annot` | `--nogui` | ALL PASS | 82 / 35 / 34 / 32 / 70 / 485 | unchanged |

A/B verified: with `src/ase_window.tcl` reverted to the old predicate and the old
sentence (byte-restored afterwards, `md5sum` matched both sides), R4/R6/R7/R8/R9
red — 7 failed, 42 passed. The rows are not vacuous.

### Still owed

* **Item C's rows are not in the working tree at the time of this write-up.**
  The end-to-end byte-identity row on the real bench, the annotation-basis-at-
  depth pin in `test_op_annot`, and the two safety rows are still to land; the
  `cmp` 0 above was measured by hand by crew A, not by a committed row.
  `tests/headless/test_ase_core.tcl:2859` says so in the file itself.
* **The two refusal tails are unratified** — `rule` debt on **0643**.
* **No visible flicker is an eyes claim, not a drawcount claim** — `look` debt.
  `trip.drawcount.delta = 1` is evidence, not a pair of eyes.
* Issue **1393** — the narrow `annot_ensure_loaded` level hole named in section
  (3), filed rather than built.
* Issue **1394** — a PRE-EXISTING modal hang uncovered while building a fixture
  for this work. Not caused by this batch.

# PLAN — descend_run_batch

Four items. A and B are independent files and run in parallel; C and D follow.
Read `CREW_BRIEF.md` first — every measurement is there and none of it should be
re-derived.

Issue **1393** is minted for this batch (`doc/claude/issues/NUMBERING.md` tail
said "next free 1393"). Issue **0643** is the standing report and is CLOSED by
item D.

---

## Item A — the round trip (`src/ase.tcl`)

### A1. `ase::stack_level {npath}`

The level of THIS window's hierarchy stack whose schematic is `npath`, or `-1`.

```tcl
proc ase::stack_level {npath} { ... }
```

* `npath` is already `file normalize`d; normalize each `xschem get schname $l`
  before comparing.
* Scan **0 upward to `currsch`** and return the FIRST (shallowest) match. A cell
  that appears twice in one stack is a recursive hierarchy; ASE-L's design is the
  deck's TOP, so the shallowest occurrence is the one to netlist. (Note
  `ase::session_for_current` scans the other way, deepest-first, on purpose — it
  answers a different question, "which session owns the nearest level". Do not
  unify them; do note the difference in a comment.)
* Never raises. `-1` on any failure.

### A2. `ase::with_design_current {dpath script}`

Evaluate `script` with `dpath` as the current schematic, then put the user back
exactly where they were. `script` is a fully-formed command list and is evaluated
with **`uplevel #0`** (no caller-frame ambiguity). Returns the script's value.

Behaviour:

1. `set lev [ase::stack_level $dpath]`. `lev < 0` → raise
   `"ase: design ... is not open in this window"` **without moving anything**.
2. `lev == currsch` → the design already IS current: `uplevel #0 $script` and
   return. No park, no walk, no `~` handling.
3. Otherwise, the safety gate, then ascend `currsch - lev` levels with
   `xschem go_back 2` (`what & 1` = confirm OFF so no modal can appear on a
   button press; `what & 2` = do not reset the window title), run the script,
   then re-descend by replaying `lrange [ase::hier_instnames] $lev end` through
   `xschem descend -fallback -inst <name>`.

**`-fallback` is not optional** (issue 0979): a copy whose bound schematic file
is missing must not strand the user part-way down the path they were standing on.

### A3. The safety gate — the decision table

| entry buffer | `::autosave_backup` | what the trip does |
|---|---|---|
| clean | either | park the flag at 0 for the trip (`op_annot::_park_backup`'s idiom), so the ascent is a plain reload and no ancestor is flagged modified. Restore the park unconditionally. |
| modified | on | do **not** park — the `~` is where the edits live and `go_back`'s `load_backup_as` is what restores them. After the final re-descend, restore the entry buffer with `xschem load_backup [xschem get schname] 0` (see CREW_BRIEF §4 — `descend` does NOT do this for you). |
| modified | off | **REFUSE** before moving anything (issue 0626). The sentence names the cell and both remedies: save it, or turn `Options > Autosave backup` on. |

### A4. Restore discipline (issue 0432 / op_annot I6)

* The unwind is bounded by the **entry** `currsch`, never by 0.
* Every exit path restores: a `catch` around the ascent + script, then the
  re-descend and the park restore, then re-raise the script's error with
  `-options` so the caller sees the original message and stack.
* If a re-descend step fails, stop, restore what can be restored, and raise a
  sentence that says WHERE the user was left. Silence here strands them.
* No visible flicker: park `no_draw` for the trip if that measures cleaner, but
  the final view MUST be painted before returning (the last `descend` paints when
  `no_draw` is 0 — check, do not assume).
* Do **not** touch `::keep_symbols`. Measured 34 ms without it; leaving it alone
  keeps the netlist the user gets byte-identical to today's. Recorded in
  DECISIONS.md as D3.

### A5. `ase::hier_instnames {}`

The instance names entered to reach the current level, top-first; `{}` at the
top. This is a **copy** of `cadence::hier_instnames` (`utils/cadence_nav.tcl:45`),
NOT a call. `src/ase.tcl` is installed and sourced by stock xschem;
`utils/cadence_nav.tcl` is neither — the same rule `src/rdw.tcl:4360-4366`
already states for `cadence::one_instance_selected`. Carry that citation in the
comment so the next reader does not "de-duplicate" it.

### A6. `ase::netlist` (currently `src/ase.tcl:5945-5985`)

Split the body so the guard and the work are separable, then:

```
design IS current            -> body
headless (no ::has_x)        -> xschem load $path ; body      (unchanged)
design is on this stack      -> ase::with_design_current $path {body}   <- NEW
otherwise                    -> the existing error, reworded to say
                                "is not open in this window"
```

`ase::op_cards_capture` stays INSIDE the body: its whole precondition is that
the design is the current schematic, and the round trip is what now guarantees
that. Do not move it out.

**Rows** go in `tests/headless/test_ase_core.tcl` (floor 203, `--nogui` and
`:99` both).

---

## Item B — the door (`src/ase_window.tcl`)

`ase::ui::do_run` (`:7228-7266`) currently pre-checks *"is the design the current
schematic"* and refuses when it is not. It becomes *"is the design REACHABLE"*:

```tcl
if {[ase::stack_level $dpath] < 0} {
  ase::ui::design_window $key ifhidden
  update
  if {[ase::stack_level $dpath] < 0} { ...the refusal, reworded... }
}
```

* Keep `ifhidden` and keep its comment — issue 0616's reasoning is unchanged.
* Keep the 1389 `run_busy` pre-check as the FIRST statement.
* `ase::ui::do_run_existing` needs no change (it never netlists) — confirm that
  in your receipt rather than assuming it.
* The refusal sentence that survives is for a genuinely unreachable design. It
  must not say "open it via Session > Design Window" when the design *is* open
  and the user is simply standing inside it — that wording is the whole
  complaint.

**Rows** go in `tests/headless/test_ase_window.tcl` (floor 245 under X, 32
`--nogui`). At least: descended two levels → `do_run` reaches `ase::run` (stub
it) and does NOT refuse; a foreign window → still routes; a design that is
nowhere → still refuses, with the new wording.

---

## Item C — pin what already works, and the end-to-end row

1. **Pin the annotation basis at depth** (CREW_BRIEF §3). A row that: loads
   tb_bandgap, opens the `debug_st1` session, calls `ase::ui::design_window`,
   descends two levels, calls `op_annot::db_attach $raw <level>` with the level
   `ase::session_for_current` reports, and asserts `sim_sch_path` is `x1.x1.`
   and `raw_level` is 0. Use the committed raw fixture, **never**
   `~/.xschem/simulations/`.
2. **The end-to-end descended netlist**: descend two levels, run `ase::netlist`
   through the round trip, and `cmp` the artifact against one taken at the top.
   Byte-identical or the row reds.
3. **The 0626 refusal**: modified buffer + `autosave_backup 0` → refused, nothing
   moved, `currsch` unchanged.
4. **The lossless return**: modified buffer + `autosave_backup 1` → after the
   trip the entry buffer is back at the same level AND still `modified`, with its
   edit present.

---

## Item D — the write-up

* **Close issue 0643.** Its "What a fix has to decide" and "Acceptance" sections
  are answered. ✅ The driver's two wrong claims in that file (a third seam in
  `ase::attach_raw`, and `Simulation > Run` annotating blanks at depth) were
  ALREADY corrected in place by the driver on 2026-09-08, with the measurement
  that refutes them — see its section (3). Do not re-correct; just close.
* **File issue 1393** for the narrow `annot_ensure_loaded` level hole (§3, last
  paragraph): measured, deliberately not built. Record 1393 in
  `NUMBERING.md` in the same commit and advance the tail.
* Update `doc/claude/specs/ase_l.md:601`, which documents the old refusal as
  covered behaviour.
* `owed.sh add rule 1393 ...` for the hole, and `owed.sh add look` for anything
  only eyes can confirm (the absence of a visible flicker during the round trip
  is exactly such a thing).

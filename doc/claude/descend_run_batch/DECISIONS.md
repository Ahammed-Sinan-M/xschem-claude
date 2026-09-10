# DECISIONS — descend_run_batch

Two kinds of entry, kept visibly apart. A **USER RULING** is something the user
said. A **DRIVER DECISION** was taken on their behalf because they were not
asked; every one of those is filed as a `rule` debt so they can overturn it.

---

## USER RULINGS

**U1 — the restriction goes.** *"Where does this inane restriction come from?
There is no such limitation in Cadence's Analog Design Environment (ADE-L),
which we want be better than."* ADE-L parity is the standard. A guard that is
correct in its own terms can still be the wrong shape when it makes the user pay
for a limitation of the machinery underneath it.

**U2 — no added cost.** *"We want to solve the user's problem without adding
cost."* The answer is that the round trip is already being made twice per press
(66 ms in C, 177 ms in Tcl); this adds 34 ms to it. Anything that would make the
button measurably slower needs to come back to the user first.

**U3 — the hidden-window idea was raised by the user and is NOT being built
now.** *"Why not just open up the design ... in a virtual schematic window
(invisible) in memory and dump the netlist from that."* It is the right long-term
architecture and the wrong thing to build today, for three measured reasons:
`create_new_window()` needs `has_x` and ends in `wm deiconify` + `raise` +
`focus -force` (`src/xinit.c:2137-2152`), so a scratch window appears on screen
and takes the keyboard — the one thing the user has told us never to do; a second
window reads from DISK, so an unsaved top-level edit would silently not be
simulated; and it costs a second full context. The ascend/re-descend is
**more** correct, because it netlists the live in-memory document. Recorded here
rather than in a comment so the idea is not lost — it is the right shape for a
later pass that adds a windowless context in C.

**U4 — Alt-E / Alt-X were pointed at by the user as prior art.** They are
`cadence::return_to_top` / `cadence::descend_to_last` in
`utils/cadence_nav.tcl:313` and `:365`, over `cadence::hier_instnames` (`:45`),
`cadence::ascend_to_top` (`:85`) and `cadence::descend_instnames` (`:341`), and
they are exactly this round trip with a cross-window chain on top. **ASE-L copies
the measurement, not the call** — `src/ase.tcl` is installed and sourced by stock
xschem while `utils/cadence_nav.tcl` is neither, which is the rule
`src/rdw.tcl:4360-4366` already wrote for the same situation.

---

## DRIVER DECISIONS (each owes a `rule` debt)

**D1 — the third seam was a driver error, corrected before any code was
written.** The driver measured a bare `xschem raw read` while descended, saw the
basis go wrong, and told the user that `ase::attach_raw` needed fixing and that
`Simulation > Run` already annotates blanks at depth. Both are false: the
annotation door passes a level (`annot_ensure_loaded` → `db_attach $path $level`
→ `annotate_op $np $level` → `raw->level`/`raw->schname`), and it measures
correct at depth. The batch pins the working behaviour instead of changing it.
The wrong claims are corrected in place in issue 0643.

**D2 — `ase::stack_level` scans shallowest-first.** A design cell appearing twice
in one stack is a recursive hierarchy; ASE-L's design is the deck's TOP, so the
shallowest occurrence is the one to netlist. `ase::session_for_current` scans
deepest-first because it answers a different question (nearest ancestor session).
Alternative rejected: unifying the two loops — one definition of two different
questions is not invariant I1, it is a bug waiting for a recursive hierarchy.

**D3 — `::keep_symbols` is left alone during the round trip.** `op_annot`'s walk
parks it at 1 to avoid purge/reload churn. Measured here: the whole two-level
trip is 34 ms without parking, and leaving it alone keeps the deck the user
receives byte-identical to today's. Cost of the decision: a purge + reload of the
symbol table per level. Alternative rejected: park it, for an unmeasurable saving
and a new axis in the netlist path.

**D4 — a modified entry buffer is CARRIED, not refused, when `autosave_backup`
is on.** `op_annot` only ever refuses (its walk never pops its entry level). This
batch pops it, so `descend`'s plain `load_schematic` would drop the edit from the
buffer; `xschem load_backup` puts it back. Refusing instead would have been
simpler and would have made a user with one unsaved tweak two levels down unable
to press Run at all. With `autosave_backup` OFF the refusal stands, because then
there is nothing to come back to (issue 0626).

**D5 — the surviving refusal is reworded to "is not open in this window".** The
shipped sentence tells the user to do the thing they have already done, which is
the whole complaint. It now fires only when the design really is nowhere on this
window's stack.

**D6 — the two refusals keep two tails, but ONE minted head.** Raised by crew B
as decision B-2. `ase::netlist`'s refusal is reached by a CIW or script caller
that has NOT tried the Design Window route, so *"open it via Session > Design
Window first"* is true there. `ase::ui::do_run`'s is reached only AFTER that
route has run and failed, so the same tail would tell the user to repeat a step
that just silently failed. Two situations, two truthful remedies — that is not
an invariant I1 violation, which is about one definition of one FACT. But the
shared head *is* one fact, and two files spelling it independently is exactly
what I1 forbids. Resolution: one mint (`ase::design_unreachable_msg`), the tail
selected by the caller. Cost: one more proc. Alternative rejected: forcing one
sentence on both doors, which would make one of the two doors lie.

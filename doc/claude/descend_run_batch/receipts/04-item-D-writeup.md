# Receipt 04 — item D: the write-up

Scope as briefed: documentation only. **Nothing under `src/` or
`tests/headless/*.tcl` was touched** (another process is auditing them), nothing
committed, nothing pushed, no `git checkout/restore/stash/clean`. No binary was
launched — this item needed none.

Files written:

| file | what |
|---|---|
| `doc/claude/issues/0643-netlist-and-run-is-refused-when-the-user-is-descended.md` | STATUS → **FIXED 2026-09-08**; new **"Resolution, 2026-09-08"** section at the end (the file is now 410 lines) |
| `doc/claude/issues/1393-the-annotation-level-is-taken-only-when-this-session-owns-the-nearest-one.md` | **NEW** — the `annot_ensure_loaded` level hole, filed not built |
| `doc/claude/issues/1394-a-zero-instance-child-schematic-turns-a-later-netlist-into-a-modal-hang.md` | **NEW** — crew A's pre-existing modal hang |
| `doc/claude/issues/NUMBERING.md` | two substantive tail entries; **next free number 1393 → 1395** |
| `doc/claude/specs/ase_l.md` | three edits — see D5 below; new section at `:625` |
| `doc/claude/descend_run_batch/LEDGER.md` | item rows filled, floors table, debts table |

---

## D1 — issue 0643 is CLOSED

**STATUS** now reads `FIXED 2026-09-08` by the `descend_run_batch` — **items A
and B**, not "A, B and C" (see the honesty note under D6). The old STATUS
paragraph is kept verbatim underneath as *"History of this line"* rather than
deleted.

The new **Resolution** section names the two seams that moved and the one that
did not, with current line numbers:

* `ase::netlist` (`src/ase.tcl:6390`) — four arms, the third (`ase::stack_level
  >= 0` → `ase::with_design_current`, `src/ase.tcl:6175`) new; the work split
  out as `ase::netlist_in_place` (`:6356`) with `op_cards_capture` still inside
  it. The five supporting procs are named and cited (`:5989`, `:6016`, `:6044`,
  `:6059`, `:6088`).
* `ase::ui::do_run` (`src/ase_window.tcl:7228`) — one predicate in two places
  plus one sentence; `ifhidden`, 1389's `run_busy`-first and `do_run_existing`
  all explicitly recorded as unchanged.
* `ase::attach_dbs` / `annotate_op` — **not** moved, with a pointer back to
  section (3).

Measured numbers quoted from the receipts, not re-derived: `top.netlist.bytes
14862` vs `here.netlist.bytes 4685`; walk 29.6 / 28.3 / 28.1 / 30.4 / 29.7 ms
over five trips; `trip.ms` 85.2 walk+netlist; `drawcount` delta **1**; view
identical to 15 significant figures; **`cmp top.spice desc.spice = 0`**, 14862
== 14862; the already-paid 66 ms / 177 ms that answer the user's "no added
cost"; the RT6 refusal sentence verbatim. Suites and floors: `test_ase_core`
203 → **216** (both arms), `test_ase_window` 32 → **49** headless and 245 →
**267** on `:99`, plus the six unchanged suites and crew B's 7-red A/B.

The two hazards the fix carries (the `~`/`autosave_backup` doctrine and the
read-only axis crew A found that PLAN.md did not have) are recorded, as is the
D6 head/tail table.

### Section (3) — verified, NOT re-corrected

Read in full and checked against the source and both receipts. **It still reads
true.** Every claim in it verified:

| section (3) claim | verdict |
|---|---|
| `annot_ensure_loaded` → `db_attach $path $level` → `annotate_op $np $level` | ✅ `src/ase_window.tcl:2782-2793` |
| `scheduler.c:2539-2543  raw->level = level ; raw->schname = sch[level]` | ✅ actual lines **2541-2542**, inside the cited range |
| `sch_waves_loaded()` at `draw.c:2853` | ✅ exact |
| the level is taken only when `[lindex $s 0] eq $key` | ✅ `src/ase_window.tcl:2785`, verbatim |
| the two measured `db_attach` outcomes (0 → `x1.x1.`, `{}` → `''`) | consistent with CREW_BRIEF §3 and with the code |
| "the results basis at depth is already right" | consistent — nothing in items A/B touched that path |

Two pre-fix line citations elsewhere in 0643 are now stale by construction —
"What the fix has to be" says `ase.tcl:5965` and `ase_window.tcl:7256`, which
are now `:6390` and `:7228`. They were correct when written, they are part of
the historical record of what the fix *had* to be, and the Resolution section
carries the current numbers. **Left alone deliberately.**

---

## D2 — issue **1393** minted

`1393-the-annotation-level-is-taken-only-when-this-session-owns-the-nearest-one.md`

The measured content from CREW_BRIEF §3 and 0643 section (3), written out as a
mechanism: `session_for_current` (`src/ase.tcl:9263`) scans **deepest-first** and
returns the *nearest* session — deliberately, for issue 0168's reason, which its
own header states. `annot_ensure_loaded` takes the level only if that nearest
session is the one being refreshed, so a **second** session bound to a descendant
cell makes the outer session's refresh pass `{}`; `annotate_op` then leaves
`raw->level` at `currsch` (`src/scheduler.c:2540-2542` overrides only
`if(level >= 0)`), `sch_waves_loaded()` cannot place the deck-absolute paths, and
every row renders blank **with no sentence** — the same silent-failure shape as
0838 / 0886 / 1392.

Three options recorded, not one: (a) ask `ase::stack_level [ase::ui::design_path
$key]` — the mint this batch just added answers the right question; (b) drop the
`eq $key` test — cheapest and **wrong**, it would stamp the outer raw at the
inner level; (c) refuse in words instead of drawing blanks. (a) and (c) are not
exclusive.

**§6 "What would turn the not-built judgement over"**: a user report (a block
designer and a system designer on one sheet is not exotic); anything that makes a
second session ordinary (per-block sessions from the library manager or a
hierarchy browser); or any change to `session_for_current`'s scan direction,
since its deepest-first walk is precisely what makes "nearest" and "mine" differ.

---

## D3 — issue **1394** minted, and crew A's citations CHECKED

`1394-a-zero-instance-child-schematic-turns-a-later-netlist-into-a-modal-hang.md`

The STATUS line says it plainly, first sentence: **PRE-EXISTING, reproduced at
HEAD `19f8e351` with no `ase::` code in the picture, filed against the batch only
because the batch is what walked into it, not reproducible on the real
tb_bandgap bench.** "Do not attribute this to the descend/round-trip work."

### Citations verified — the two crew A gave

| crew A's citation | verdict |
|---|---|
| `src/scheduler.c:9167` — the modal | ✅ **exact.** `else` at `:9167`, `if(has_x) tcleval("tk_messageBox …` at `:9168`, the message string at `:9169`. The whole dispatcher chain is `:9157-9169`. |
| `-noalert` does not suppress it | ✅ **confirmed by construction.** `alert` (cleared at `src/scheduler.c:9089`, documented at `:9047`) is passed only to the five `global_*_netlist()` back ends. The message box sits in the chain's `else` and never reads it. |
| `src/save.c:6469` — `netlist_type` moved aside when `instances == 0` | ✅ **exact.** `if(!strcmp(tclresult(), "SYMBOL") \|\| xctx->instances == 0)`. |

Strengthened while checking: `CAD_SYMBOL_ATTRS` is **5** (`src/xschem.h:229`) and
the dispatcher tests only 1/2/3/4/6 (`src/xschem.h:225-230`), so a `netlist_type`
left at `CAD_SYMBOL_ATTRS` falls into that `else` by construction. **Descending
into a zero-instance schematic is sufficient to arm the defect** — that half is
airtight.

### ⚠ One crew A claim I could NOT confirm, and did not copy

Crew A's stated cause — *"the parent reload does not put it back"* — **is not
established by reading**, and the issue says so instead of repeating it. The very
next lines are a restore (`src/save.c:6474-6480`,
`if(xctx->loaded_symbol) xctx->netlist_type = xctx->save_netlist_type;`), and
`go_back` does reach them (`src/actions.c:6505-6506`,
`load_schematic(1, filename, set_title, 1)` — `reset_undo` 1, parent has
instances), so on a straight reading the type should come back.

The reproduction is crew A's measurement and I have no reason to doubt it; what
is missing is the step that defeats the restore. Two candidates are recorded, the
leading one found while checking: **`save_netlist_type` is initialised to `0` per
context** (`src/xinit.c:913`; `alloc_xschem_data()` runs per window and per tab —
`:1002, 1060, 1605, 2089, 2242, 3662`), and the stash at `:6470` is itself
conditional, so a restore that fires before it ever held a real format writes 0
— no more a valid format than 5 — into `netlist_type` and lands on the identical
`else`. The second candidate is one of `load_schematic()`'s early returns (e.g.
`src/save.c:6414`) or the `load_backup_as()` branch. The issue names the one-build
experiment that settles it: `dbg(0, …)` of
`netlist_type`/`save_netlist_type`/`loaded_symbol`/`instances` on both sides of
the `descend` and both sides of the `go_back`.

Also recorded: the hang produces **no exit code, no banner and no `FAIL`**, which
is the one shape `tests/banner_rule.tcl` and the two shell readers cannot
classify; and the three RT-row workarounds (probe instead of netlist, RT11's
stub, the one-instance child fixture) that must be reverted when it closes.

---

## D4 — `NUMBERING.md`

Two tail entries at the density of 1389–1392 (not stubs): 1393 carries the
mechanism, the measured both-sides `db_attach` pair, the not-built judgement with
its reason, all three options with the reason (b) is wrong, and the rule debt.
1394 leads with **PRE-EXISTING**, carries both verified citations and the
`-noalert`-cannot-reach-it argument, and carries the ⚠ paragraph saying crew A's
stated cause is unconfirmed with the `save_netlist_type = 0` candidate named.

**`**The next free number is 1393.**` → `**The next free number is 1395.**`**
Grepped `doc/claude/issues/` first: nothing above 1392 existed.

---

## D5 — `doc/claude/specs/ase_l.md`

Three edits; the 0616 section's `raise_mode` table and reasoning are untouched
because they are still in force.

1. **`:575`** — the paragraph describing `do_run`'s equality guard now opens with
   a dated pointer (*"REPLACED on 2026-09-08 — issue 0643"*) and is put in the
   past tense. The 0616 narrative is history and stays history.
2. **`:600`** (the "load-bearing, do not simplify" bullet the brief pointed at) —
   it quoted the dead sentence *"design is not the current schematic"* as the
   cost of dropping the context switch. It now names the surviving refusal
   (`ase::design_unreachable_msg`) and says *why* dropping the context switch
   still costs: a design on **another window's** stack is exactly what the switch
   repairs.
3. **`:625`** — new section **"Netlist and Run works from any level of the design
   (issue 0643, 2026-09-08)"**, replacing the old *"Still broken on this button,
   filed not fixed"* paragraph. It keeps the old symptom as history (including
   the user's own words), then gives the new contract as a four-row table
   (current / on this stack / on another window's stack / nowhere), the door-asks-
   reachability point, why a round trip rather than a relaxed guard
   (`src/spice_netlist.c:359-373`, 4685 vs 14862), the cost answer, the `~` and
   read-only safety rules, `do_run_existing` needing no change, and the **D6
   head/tail table** — one minted head, two truthful tails, forcing one sentence
   would make one door lie. Ends with the pinned floors and the note that both
   tails are unratified UI copy carrying a `rule` debt on 0643.

---

## D6 — ledger and debts

### `LEDGER.md`

Item rows filled, plus two new tables (floors after the batch, by name; debts
this batch leaves).

**⚠ Item C is NOT in the working tree**, and the ledger says so at length rather
than leaving the row blank or optimistic. Evidence: `git status --short` shows
only `src/ase.tcl`, `src/ase_window.tcl`, `tests/headless/test_ase_core.tcl`,
`tests/headless/test_ase_window.tcl` modified — `tests/headless/test_op_annot.tcl`
is untouched — and `tests/headless/test_ase_core.tcl:2859` still reads *"The
end-to-end byte-identity row is item C's, on that bench."* The `cmp`-identical
netlist quoted throughout was measured **by hand** by crew A, not by a committed
row. The ledger row ends *"Do not read the closed 0643 as meaning C landed"*, and
0643's own STATUS and "Still owed" say the same. (The brief said A, B and C were
all in the tree; they are not. Reporting rather than working around it.)

### `owed.sh` — three added, exactly as briefed

```
owed.sh add rule 1393 "…"   -> recorded rule debt: 1393
owed.sh add rule 0643 "…"   -> recorded rule debt: 0643
owed.sh add look  descend_run_batch_no_flicker_on_the_ascend_re_descend_round_trip "…"
```

* **rule 1393** — the unratified judgement that the level hole stays unbuilt.
  Carries the mechanism, both measured `db_attach` outcomes, the three options
  with (b) marked wrong, and the "overturn this if you ever run two ASE-L
  sessions on one hierarchy" trigger. `ref:` auto-resolved to the new issue file.
* **rule 0643** — crew B's **B-1/B-2**: the two refusal tails. Both quoted
  verbatim with their file:line, the D6 reason they differ, the note that
  forcing one voice makes one door lie, and the note that the door's arm is hard
  to reach (`src/ase_window.tcl:6850`). `ref:` auto-resolved to 0643. Crew B
  explicitly deferred these to item D's ledger entry rather than filing their own
  — done.
* **look** — the flicker. Written as the user's own gesture (tb_bandgap →
  debug_st1 → Session > Design Window → descend x1, x1 → `N&>`), states exactly
  what to watch for, and states what is measured and why it does not substitute:
  drawcount delta 1, `sch_path` `.x1.x1.`, view identical to 15 s.f. — **all
  taken on Xvfb `:99`**, where `<Configure>` traffic differs from the user's
  Windows X server by a measured factor of 3.

**No `suite` debt added, on purpose:** `test_ase_core` and `test_ase_window`
**already carry unpaid `:0` suite debts** (0d old, from issues 1389 and 1391),
and suite debts dedupe by name — a fourth `add` would only have overwritten a
still-accurate reason with a newer one. Those two existing debts cover this
batch's GUI legs (R13/R14) as they stand.

### Counts

| list | before | after |
|---|---|---|
| rule | 123 | **125** |
| look | 55 | **56** |
| suite | 7 | **7** |

`owed.sh list` verified all three new entries present, with `ref:` lines resolved
for both rule debts.

---

## Hygiene

* Nothing under `src/` or `tests/headless/*.tcl` opened for writing; no test run,
  no binary launched, nothing written under `~/.xschem/`.
* No commit, no push, no `git checkout/restore/stash/clean`, no `pkill`.
* `git status` gained only the three doc files this item wrote (0643 was already
  modified by the driver before I started).

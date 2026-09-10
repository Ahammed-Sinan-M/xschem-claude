# Receipt — item B, the door (`ase::ui::do_run`)

Issue **0643**. Scope was exactly two files, and exactly two files moved:
`src/ase_window.tcl` and `tests/headless/test_ase_window.tcl`. Nothing
committed, nothing pushed, `src/ase.tcl` untouched (crew A's edits were already
in the tree when I measured — see §5).

---

## 1. What changed, and where

### `src/ase_window.tcl:7228-7311` — `ase::ui::do_run`

**One predicate swapped, in two places, plus one sentence.**

| line | before | after |
|---|---|---|
| `:7290` | `if {[file normalize [xschem get schname]] ne $dpath} {` | `if {[ase::stack_level $dpath] < 0} {` |
| `:7299` | the same equality test, again, after the route | `if {[ase::stack_level $dpath] < 0} {` |
| `:7300` | `"ase: design is not the current schematic; open it via Session > Design Window first"` | `"ase: design <cell> is not open in this window; Session > Design Window did not open it"` |

Rendered (measured, with the cell substituted):

```
ase: design tb_bandgap is not open in this window; Session > Design Window did not open it
```

Everything else in the proc is byte-identical:

* **1389's `run_busy` is still the first statement** (`:7232-7233`, the two lines under the 1389 header comment), above
  `design_path` and above the routing. Row R11 asserts that with the real lock
  table, not a stubbed predicate.
* the `design_path eq {}` arm (`:7234-7239`) is unchanged;
* `ifhidden` (`:7291`) is unchanged, and so is the `update` after it;
* the `catch {ase::run ...}` / `run_raised` / `run_started` tail is unchanged.

**Comment work** (`:7240-7289`, and a second block at `:7293-7298`). The existing
`ifhidden` / 0616 block was load-bearing and is kept, updated truthfully rather
than deleted:

* the user's own words at the top, because the sentence they hit *was* the
  defect;
* why the equality test failed from depth (`schname` is the leaf, and Session >
  Design Window brings the same descended window back, so the second look failed
  identically — the button was unusable from any depth, not merely inconvenient);
* what `ase::stack_level` answers, that making the design current for the
  duration is `ase::netlist`'s job now, and the 34 ms / 66 ms / 177 ms numbers
  that are the "no added cost" answer;
* **why this door does not walk the hierarchy** (a door that ascended would have
  to unwind on every error arm below it);
* a ⚠ paragraph saying plainly **where the safety actually lives** — see §4,
  because I first wrote this paragraph wrong and corrected it;
* 0616's reasoning, retained *with the reason it is untouched*: the waveform
  viewer is a separate xschem window (`new_schematic create_window`,
  `src/wave_viewer.tcl:1315-1337`), so the design is not on the viewer window's
  stack either, `stack_level` still returns `-1` there, and the routing still
  fires for the user's *other* reported case. The new predicate makes the route
  fire **less often**; it does not make it fire in different places.

### `tests/headless/test_ase_window.tcl`

* `:60-73` — the file's own index gains the `R1-R14` entry.
* `:288-368` — a **two-level scratch fixture**: `hier_top -x1-> hier_mid -x1->
  hier_leaf` (two `type=subcircuit` symbols, four schematics, plus `hier_else`
  as somewhere real to stand that is not the design). Measured `sch_path`
  `.x1.x1.` — the user's exact shape. It lives entirely under the suite's
  scratch tree.
  **Deliberately NOT the shipped `sky130_tests_ase/tb_bandgap`** the batch was
  measured on: descending it and coming back touches a cell that ships with a
  `<cell>~.sch` beside it (CREW_BRIEF §4, issue 0626), i.e. writes in the repo
  tree, and the door does not care what is inside the cells.
* `:2946-3236` — the **R block**, last in the file, inside the big catch, and
  **outside** the `has_x` guard so it runs in both arms and moves both floors.

---

## 2. The rows, and what each one actually proves

Helpers: `r_echo_on/off` + `r_echoed_n` (an echo spy — `w_aecho_spy` could not be
reused, it is defined inside the GUI block), `r_run_on/off` (renames `ase::run`,
`ase::run_existing` and `ase::ui::run_started` out; the real `run_started` opens
a log toplevel and attaches a trace to an execute id that was never launched),
`r_dw_on/off` (renames `ase::ui::design_window` out, records the `raise_mode` it
was called with, and optionally performs a body).

| row | proves |
|---|---|
| **R1** (×2) | the fixture really reproduces the report: `sch_path .x1.x1.`, `currsch 2`, `schname` = the leaf; and `design_path` resolves to `hier_top`. |
| **R2** | **the anti-vacuity anchor.** The *old* `schname ne $dpath` predicate is TRUE at that exact spot — so a green R4 is the door changing behaviour, not the situation changing. Green in both A/B arms by design. |
| **R3** | `ase::stack_level` answers `0` while standing at level 2 — the door's precondition, in the reported position. |
| **R4** (×2) | **the report.** Descended two levels, `do_run` reaches `ase::run` exactly ONCE and refuses nothing — neither the new sentence nor the old one. |
| **R5** | the door does **not move the user**: still `.x1.x1.`, `currsch 2` after the press. (The walk belongs to `ase::netlist`, not here.) |
| **R6** | the door does **not route at all** when the design is reachable — no `design_window`, so no withdraw/deiconify, which is 0616's cost. |
| **R7** (×2) | a design genuinely nowhere on the stack is **still refused** (`ase::run` not called, exactly one refusal) — and after exactly ONE routing attempt, with `ifhidden`. |
| **R8** | the words **`is not the current schematic` are gone from this door**. This is the user's literal complaint, asserted as an absence. |
| **R9** (×2) | the refusal names the cell it could not reach, and is tagged `error`, not `note` (nothing is running; contrast 1389's busy refusal, which is deliberately `note`). |
| **R10** | the routing arm still WORKS: unreachable + a `design_window` that really brings the design up → runs on the second look, one route, no refusal. This is the headless twin of W6m. |
| **R11** (×2) | **1389 order.** With the REAL lock table holding this session's raw path, `do_run` refuses FIRST: no run, no routing, no reachability sentence, and the refusal that *is* said is the busy one. |
| **R12** | `do_run_existing` ignores the stack entirely — design nowhere, standing on a foreign cell, still reaches `ase::run_existing`, never routes, never refuses. §3's finding, as a row. |
| **R13** (×2, X only) | the **real `Simulation > Netlist and Run` menu entry**, pressed two levels down through a live ASE-L window, runs — and the status segment is not reddened. Its precondition list also re-asserts that the old predicate was false at press time. |
| **R14** (×2, X only) | the same real gesture with the design nowhere: refused, in the new words, never the old ones, and the status segment goes `red` / `Status: Error`. |

**R13/R14 carry the CREW_BRIEF trap fix**: `ase::open_state` leaves
`current_win_path` on another window, so the block does an explicit
`xschem new_schematic switch $r_win` before descending. `design_window` would
also repair it, but it loads and raises — the very thing R13 must prove did not
happen before the press.

### A/B — the rows are not vacuous

`src/ase_window.tcl` reverted to the old predicate *and* the old sentence
(byte-restored afterwards; `md5sum` verified `69d7ef53…` both sides), headless
arm:

```
FAIL: R4 ISSUE 0643 descended two levels, do_run reaches ase::run exactly once -> {0} (exp {1})
FAIL: R4 ...and refuses nothing (neither the new sentence nor the old one)     -> {0 1} (exp {0 0})
FAIL: R6 ...and does NOT route through Session > Design Window at all          -> {ifhidden} (exp {})
FAIL: R7 a design that is nowhere on this window's stack is still refused      -> {0 0} (exp {0 1})
FAIL: R8 the words `is not the current schematic` are gone from this door      -> {1} (exp {0})
FAIL: R9 the refusal names the design cell it could not reach                  -> {0} (exp {1})
FAIL: R9 ...and is tagged error, not note                                      -> {} (exp {error})
RESULT: 7 FAILED (42 passed)
```

with the echo it actually emitted printed by the row's own diagnostic:

```
R7 echoes were: {error {ase: design is not the current schematic; open it via Session > Design Window first}}
```

R11 and R12 stayed green in the A/B, correctly — they are about behaviour this
item did not touch.

---

## 3. `do_run_existing` — CONFIRMED by reading, not assumed

**It needs no change.** The chain, read end to end:

1. `ase::ui::do_run_existing` (`src/ase_window.tcl:7316-7327`) calls exactly four
   things: `ase::ui::run_busy`, `ase::run_existing`, `ase::ui::run_raised`,
   `ase::ui::run_started`. No `xschem get schname`, no `design_path`, no
   `design_window`.
2. `ase::run_existing` (`src/ase.tcl:6204-6221` at the time I read it) resolves
   the four backend hooks, builds `<rundir>/<cell>.spice`, checks `file isfile`,
   and hands off to `ase::run_deck`. It never calls `ase::netlist` and never
   reads the current schematic. Its own header says so: *"needs no
   current-schematic guard because no netlisting happens — works with the design
   window closed."*
3. `ase::run_deck` (`src/ase.tcl:6231-6547`, i.e. up to the next `proc`) grepped
   for `schname|currsch|descend|sch_path|xschem netlist|op_cards|
   with_design_current|ase::netlist`: **two hits, both benign** — a comment that
   cites `ase::netlist`'s reason for deleting its own artifact, and
   `ase::op_cards_for` (`src/ase.tcl:4499-4503`), which is a pure lookup in the
   cached `op_cards` dict and touches no schematic context.

So the whole `Simulation > Run` path is context-free with respect to the current
schematic, and adding a stack test to it would be a new restriction, not parity.
Pinned as **row R12** rather than left as prose, and the suite's existing **W6b**
already pins the other half (Run must not re-netlist, hand-edit sentinel).

---

## 4. Where PLAN.md is wrong or incomplete — plainly

**(a) PLAN item B is CORRECT as written.** The snippet, the `ifhidden` keep, the
`run_busy`-first keep, the `do_run_existing` claim and the two floors (245 / 32)
all matched what I found. Nothing in item B had to be worked around.

**(b) But the surviving refusal is *harder to reach* than PLAN implies, and
that changes how it must be tested.** PLAN asks for a row where "a design that is
nowhere → still refuses". In the shipped product that arm is close to
unreachable through the real `ase::ui::design_window`, because that proc's
not-open-anywhere path always ends in `xschem load -gui $dpath` and returns 1
(`src/ase_window.tcl:6846-6860`, the `xschem load -gui $dpath` at `:6850`) — after which the design *is* on some window's
stack. The refusal therefore fires only when `design_window` itself fails to
produce the design (a vanished file, a load that lands elsewhere). The only
deterministic way to test it is with `design_window` renamed out, which is what
R7-R9 do and what the block's comment says. Worth knowing before someone reads
the refusal as a common path and tunes its wording for frequency.

**(c) I corrected a claim I had written into the code comment myself, and it is
worth recording because it is the kind of thing that outlives a receipt.** My
first draft of the ⚠ paragraph said *"DO NOT WEAKEN THIS TO 'no check at all' —
delete it and `N&>` two levels down silently simulates the op-amp alone."* That
was **false once item A landed**: `ase::netlist` now refuses on its own for an
unreachable design, so deleting this pre-check would not netlist the wrong deck.
What deleting it would actually cost is 0616's routing and a refusal that can say
no without going through `ase::run`. The `global_spice_netlist()` /
`xctx->sch[xctx->currsch]` fact is still the reason the batch does a **round
trip** instead of simply dropping the old test — it just belongs one layer down.
The comment now says exactly that.

---

## 5. Decisions PLAN.md did not settle (I took them; overturn freely)

**B-1 — the surviving refusal names what was already tried.** PLAN and DECISIONS
D5 fixed the head of the sentence ("is not open in this window") and forbade the
old tail. They did not say what the tail becomes. The arm is reached **only
after** `design_window ifhidden` has already run and failed, so *any* wording
that points the user at Session > Design Window tells them to repeat a step that
just silently failed — not only in the descended case, in every case. I wrote:

> `ase: design <cell> is not open in this window; Session > Design Window did not open it`

Terse, names the cell (a session window carries no other clue which cellview it
could not reach), and states the attempt so the user does not repeat it.

**B-2 — the door's sentence and `ase::netlist`'s sentence now differ in their
tail.** Crew A's `ase::netlist` ends with *"is not open in this window; open it
via Session > Design Window first"*, which is right **there** — a CIW or script
caller has not tried the routing. This door has. Two situations, two truthful
tails, one shared head. **If the driver wants one voice, this is the seam**, and
the door is the one that should keep its extra clause. Flagging rather than
silently unifying.

**B-3 — `ase::stack_level` is called twice rather than cached in a variable.**
It is a pure read (`currsch` + one `xschem get schname` per level, `catch`ed
throughout), the second call must see the world *after* `design_window` +
`update`, and caching the first would read stale. No measurable cost.

**B-4 — no defensive `info commands ase::stack_level` in the product.**
`src/ase.tcl` and `src/ase_window.tcl` ship and are sourced together; a missing
`ase::stack_level` is a load-order defect and should raise loudly rather than
fall back to the old predicate. The **test** skips gracefully instead (see §6).

**B-5 — the R block is last in the file.** It loads schematics into the main
window and opens a second session; running it after everything else means
nothing above can be perturbed by it. It is outside the `has_x` guard on purpose,
so both floors move together.

None of these is a user-visible ruling beyond B-1/B-2, which are UI copy. I did
**not** file an `owed.sh add rule` for them — item D owns the batch's ledger
entries and the 0643 write-up, and B-1/B-2 are the same sentence the write-up
has to quote. **Driver: if you want them ratified, they belong in D's `rule`
entry for 0643, not a separate one.**

---

## 6. Suite results — by name and status

Binary: `make -C src` → *"Nothing to be done"* (this item is Tcl only). Tree at
`19f8e351` + the working-tree edits of items A and B.

| suite | arm | status | checks | floor |
|---|---|---|---|---|
| `test_ase_window` | `--nogui --pipe -q --nolog` | **ALL PASS** | **49** | was 32 → **raised to 49** |
| `test_ase_window` | `devdisplay.sh exec … --pipe -q --nolog` (`:99`, openbox live) | **ALL PASS** | **267** | was 245 → **raised to 267** |

Exact commands:

```sh
./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_window.tcl
tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_window.tcl
```

* **Zero `FAIL` lines, zero `SKIPPED` lines, zero `UNEXPECTED ERROR` lines** in
  either arm; exit 0 both.
* Repeated: headless 3/3 identical (49), `:99` 3/3 identical (267). No flake.
* +17 headless, +22 on `:99` (the extra 5 are R13/R14's four rows plus
  `R13 open_state → 1`).
* All fourteen R names appear as `ok:` in both arms except R13/R14, which are X
  only and appear as `ok:` there.
* `run_regression.tcl` **not run** (issue 0990 — the driver owns it).

Every row skips cleanly if item A is not in the tree:

```
SKIPPED: R3-R14 (ase::stack_level absent -- item A of descend_run_batch not in
this tree; the door cannot be exercised without its predicate)
```

R1/R2 still run in that state (they need no predicate), so the fixture itself is
still covered from either side of the merge. **The 49 / 267 floors above are the
post-merge numbers** — `ase::stack_level`, `ase::with_design_current` and
`ase::hier_instnames` were all already in `src/ase.tcl` when I measured
(`src/ase.tcl:5989`, `:6016`, `:6152`), so both runs took the full path, not the
skip.

## 7. Hygiene

* Nothing committed, nothing pushed, no `git checkout/restore/stash/clean`.
* `git status` shows my two files plus other crews' (`src/ase.tcl`,
  `doc/claude/issues/0643-*.md`) — I did not touch theirs.
* **`~/.xschem/simulations/tb_bandgap_ase.raw` last written 18:01:12, before my
  first run (≈18:47).** The driver's control measurement is intact. No
  simulation was run against it; the R rows stub `ase::run` entirely.
  `~/.xschem/recent_files` unchanged (18:00:43). `~/.xschem/geometry` does move
  on any GUI suite's exit — pre-existing, not this item's doing, and the write at
  18:57:02 belongs to another agent's `measure.tcl` run that was live at the time.
* No `pkill`. No stray `xschem` of mine left running. The `:99` window manager
  (openbox, Openbox 3.6.1) was live for every `:99` measurement.
* The fixture lives under the suite's swept scratch root
  (`tests/headless/.scratch`), which is why `git status` shows nothing new.

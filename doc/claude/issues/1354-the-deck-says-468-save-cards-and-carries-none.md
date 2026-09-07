# 1354 — the log says "468 device OP save card(s) added to the deck" for a deck that carries none

**Status: FIXED** (both halves), 2026-09-05. Found while diagnosing issue 1300.
It is not that defect, but it is what made the crew brief's premise wrong, and
it was live in the user's log.

## Measured

The user's log `/tmp/Xschem.log.5` carries

    ASE: 468 device OP save card(s) added to the deck.

and the shape-`c` nudge (*"... one request at a time ... Your simulator cannot
do either of the shorter ways"*).

Their rendered deck, `/home/analog/.xschem/simulations/tb_bandgap_ase.spice`,
contains **zero `@` characters** — no `.save @dev[param]` cards at all. Lines
332-345 are `.save all` … `op` / `set altshow` /
`show all > …tb_bandgap_ase.opinfo`. That is deck shape **d**.

## Re-derived by driving, not by reading (2026-09-05)

A probe primed the capability cache with `altshow_op_dump 1` and drove the real
seams (`scratchpad/ITEM_1354/probe/p1.tcl`, `p2.tcl`):

    TIER          : tier d reason dump ndev 2 ncards 3
    REPORT-KIND   : op_tier_perdevice          <-- the defect
    SENTENCE      : "... one request at a time ... Your simulator cannot do
                     either of the shorter ways, so this is the only one
                     available."
    DECK @-chars  : 0
    ECHO (tier d) : ASE: 3 device OP save card(s) added to the deck.
    ECHO (tier c) : ASE: 3 device OP save card(s) added to the deck.   <-- identical

So the two halves fail differently and the difference is the fix:

* **the sentence** — `ase::op_tier_report` *does* ask `ase::op_save_tier`, gets
  `d`, and then throws the answer away: its `switch` had arms for `a` and `b`
  only, so `d` fell through to `op_tier_perdevice`. Reason `dump` is not one of
  that sentence's five reason tails either, so it landed on the catch-all —
  which tells the user their simulator *cannot* do a shorter way, about the very
  build that was given the shortest one **because it can**.
* **the count** — `ase::op_cards_capture` never consults the shape *and must
  not*. It runs at NETLIST time, before any deck exists; `ase::op_save_tier`
  goes through `ase::sim_capabilities`, which on a cache MISS makes a scratch
  folder and **starts the user's simulator**; and `Simulation > Netlist >
  Recreate` (`ase::ui::do_netlist_recreate` → `ase::netlist` → capture,
  `src/ase_window.tcl:6477`) is a netlist gesture with no run behind it. A plain
  Netlist may not launch a simulator to word a sentence.

## Fixed

1. **`op_tier_dump`**, a fifth sentence kind, minted in `ase::sim_why` beside
   the other four (ruling D5-4: sentences are minted there and never rendered at
   the call site) and selected by a new `d` arm in `ase::op_tier_report`'s
   switch. It says shape d is the *good* case, which is what it is:

   > Your simulator can print out every device's operating-point numbers in one
   > go, so this run asked for the whole set at once instead of making a
   > separate request for each number. That is the shortest way there is: the
   > deck names no device at all, and the numbers come back in a small file of
   > their own beside the results. It covers more of your devices than asking
   > one at a time does, not fewer. If that file does not appear, this run will
   > tell you so.

   The third clause is a measurement, not reassurance: `render_deck`'s own
   shape-d arm records 468 of 468 pairs recovered on the user's `tb_bandgap`,
   worst relative error 4.70e-06, and **212 devices dumped against the 78** the
   per-device cards named.

   No reason tails. Only `dump` (measured) and `forced` (chosen by hand) reach
   this shape, and `op_tier_report` already says `op_tier_forced` after it in
   the forced case.

2. **The netlist-time line stops claiming a deck that does not exist yet**, and
   carries the number that still means something on shape d:

       ASE: 3 device OP save card(s) prepared from this schematic, covering
            2 device(s). How the deck asks for them is decided at Run, and the
            run says which way it used.

## The decision taken on the user's behalf — and what was rejected

**A count of cards is a category error on shape d**: that deck carries none, so
"0 cards" would not be a smaller number, it would be a different question
answered. The line now reports what the *walk* built (cards) **and** how many
*devices* they cover, because the device count is the one that survives every
shape — it is what the dump has to cover and what the annotation will consume.

Rejected, and why:

* **"nothing to count on shape d" / suppress the line there** — needs the shape
  at netlist time, which costs a simulator start on a plain Netlist gesture.
* **move the count into `render_deck`, one per shape** — splits one fact across
  two surfaces and duplicates the "how" that the tier sentence already owns;
  that is issue 0635's two-contradictory-sentences shape one layer over.
* **put the device count in the shape-d *sentence* instead** — the dump covers
  *more* devices than the block names (212 vs 78 on the user's bench), so a
  number there would understate what the file holds. One number, one place.

On the user's ledger as rule debt **1354** — they may prefer different words, or
prefer the line to name only devices.

## Fenced by

* **N1..N6** of `tests/headless/test_op_dump_altshow.tcl` (a new section N).
  N1/N3/N4/N5/N6 are all red on the unmodified source; N2 is the declared
  control (green both sides, red under SAB5).
* `op_tier_dump` added to `TIERKINDS` in
  `tests/headless/test_ase_optier_0963.tcl`, which puts it under **S2** (no word
  out of the code in any sentence this surface can say) and **S4** (each
  sentence exists exactly once, in the one place sentences are minted). Both
  red before the `sim_why` arm existed.
* Sabotages, each restored by `cp` with the md5 verified:
  | # | sabotage | red |
  |---|---|---|
  | SAB1 | `op_tier_report` loses its `d` arm (the pre-fix state) | N1 N3 N4 — optier ALL PASS |
  | SAB2 | `sim_why` loses the `op_tier_dump` arm | N3; optier S2 S4 |
  | SAB3 | the netlist line promises the deck again | N5 exactly |
  | SAB4 | the netlist line drops the device count | N6 exactly |
  | SAB5 | every shape reports as the dump | N2; optier S1 S10 |

  SAB1 is the one that matters most: **the optier suite alone cannot see this
  defect** — it has no shape-d capability fixture — which is why the behavioural
  rows live in the dump suite.

* `F19k` / `F19l` of `tests/headless/test_ase_final.tcl` re-spelled to the new
  word in the same commit. F19l is the non-vacuity control for F19k; left on
  `added` it would have started passing because the string it looks for no
  longer exists.

## The siblings, checked before fixing the one that was reported

Every place in this area that states a fact about the deck's shape was checked
against `ase::op_save_tier`:

* `ase::op_report_missing` — **already correct**: `run_deck` stores the tier in
  the run metadata and the reporter branches on it (issue 1335, rows Y1-Y5).
* `ase::cap_report`, `ase::run_log_header` — make no claim about the shape.
* the three refusal lines in `op_cards_capture` (`:4461`, `:4473`, `:4481`) and
  the empty-block line (`:4501`) — all reached only when **no** block was
  captured, and `render_deck` then emits nothing at all, dump included. True on
  every shape.
* `ase::op_cards_count` has exactly two other readers: `op_save_tier`'s own
  dict, and nothing user-facing.

So the two fixed here were the only two.

## Why it mattered beyond tidiness

The crew brief for the RDW list batch reasoned from this line — *"Their log
shows the per-device shape was used for this run (468 device OP save card(s))"*
— and concluded the raw should have held only the annotation parameters. It
held 7825. One wrong sentence in a log sent a whole crew at the wrong
hypothesis, and the user reads the same line.

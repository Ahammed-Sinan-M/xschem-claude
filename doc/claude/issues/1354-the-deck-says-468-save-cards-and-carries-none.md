# 1354 — the log says "468 device OP save card(s) added to the deck" for a deck that carries none

**Status: FILED, NOT FIXED.** Found while diagnosing issue 1300. It is not that
defect, but it is what made the crew brief's premise wrong, and it is live in
the user's log right now.

## Measured

The user's log `/tmp/Xschem.log.5` carries

    ASE: 468 device OP save card(s) added to the deck.

and the shape-`c` nudge (*"... one request at a time ... Your simulator cannot
do either of the shorter ways"*).

Their rendered deck, `/home/analog/.xschem/simulations/tb_bandgap_ase.spice`,
contains **zero `@` characters** — no `.save @dev[param]` cards at all. Lines
332-345 are `.save all` … `op` / `set altshow` /
`show all > …tb_bandgap_ase.opinfo`. That is deck shape **d**.

## Cause, read from code

Two decisions are taken in two places and neither consults the other:

* `ase::op_cards_capture` (`src/ase.tcl:4506`) prints the count from the block
  `::op_annot::save_cards` returned, and is called on the netlist path at
  `:4562`.
* the SHAPE is decided separately by `ase::op_save_tier`, consulted at `:4792`
  and at `:8050` (`render_deck`). Its arm G3a picks tier `d` whenever the
  backend reports `altshow_op_dump == 1`, which the user's ngspice-46+ does.

So the 468 line reports the CAPTURED shape-c block whatever shape the deck ends
up carrying, and the nudge advertises a limitation the run did not hit.

## Why it matters beyond tidiness

The crew brief for the RDW list batch reasoned from this line — *"Their log
shows the per-device shape was used for this run (468 device OP save card(s))"*
— and concluded the raw should have held only the annotation parameters. It
held 7825. One wrong sentence in a log sent a whole crew at the wrong
hypothesis, and it will do it again.

## Fix, not taken here

Take the count from the tier decision, or suppress both sentences on the `d`
arm and say what shape the deck actually got. Small; it is filed rather than
fixed because it is outside the item that found it and because "which sentence
does shape d deserve" is user-visible wording.

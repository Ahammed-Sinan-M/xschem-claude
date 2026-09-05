# 1353 — the RDW narrowing landed, and the four decisions it forced

**Status: FIXED (the narrowing) + FILED, NOT RULED (the four decisions).**
This is the implementing record for issue **1300**, which is now **FIXED**.
Rule debt **1353** on the owed ledger carries the four decisions the user has
not seen.

## What the user reported

> **1 key**: dumps ALL OP info for a MOS FET in the RDW, when it's supposed to
> dump only those parameters that get annotated on the schematic. *(was working
> OK before)*

## What was measured, on the user's own artifacts

Their design, their rendered deck, their 69 MB raw and their 280 KB `.opinfo`
are all on this machine, so every number below is from their case and not from
a stand-in.

* `rdw::format_answer` (`src/rdw.tcl`) took `{ans ctx}`, rendered every pair
  the seam returned and never read `::rdw::listkind`. Keys 1, 2 and 3 emitted
  **byte-identical 1939-character blocks** for their `M18:/x1/x1`. That is
  issue 1300, unchanged since it was filed.
* Their `M18` publishes **88 parameter rows**; the sky130 annotation list
  declares **six** (`id gm gds vgs vth vds`, `sky130A/sky130_procs.tcl:449`).
  So key 1 printed 82 rows no list declares.

**Why it "was working OK before" — the deck, not the pane.** Until commit
`a5e15dda` (2026-09-05 00:41) the deck used save shape **c**, one
`.save @dev[param]` card per declared parameter: measured on their tb_bandgap,
**468 cards, 78 devices, exactly those six parameters**. The raw therefore held
the annotation list and nothing else, and an UNNARROWED pane *looked* narrowed.
`a5e15dda` added shape **d** — `set altshow` + `show all` — chosen
automatically by `ase::op_save_tier` when the backend reports
`altshow_op_dump`, which their ngspice-46+ does. `op_annot::opdump_read` merges
the whole dump into the raw (212 devices, 7825 parameters). **Nothing about the
window regressed. The deck stopped covering for the pane.**

## The fix

Narrowing inside the renderer, from the ONE definition this tree has:

* `rdw::_narrow_spec {ctx}` reads `list`, `class` and `cellname` out of the
  context and asks `rdw::_list_params` — item R2's existing reader — which asks
  `::op_param_lists::effective`. Issue 1300's option (a), "filter from
  `op_annot::descriptor`'s `params`", stays refused: it mints a second
  definition of "the annotation list" beside ruling DD-6's, which is invariant
  I1's drift.
* `rdw::_narrow_answer {ans order}` filters **all three buckets** and counts
  what it dropped, rebuilding the seam's five-key answer so every downstream
  reader (`_rowdevs`, the width, the sub-header suppression, the absent
  footnote) narrows with it.
* `rdw::_list_ctx {ctx}` puts the live list identity and the device's class
  into the context at `rdw::dump_devpath`, **THE SEAM'S ONLY DOOR** — the third
  thing that door amends, after `sim` (issue 1284) and `simtype` (issue 1298),
  and for the same reason.
* The block is then re-slotted by `rdw::_reslot_block`, unchanged and re-used,
  so the pane's order is the list's order and item R2's Up/Down promise holds.

**The fence issue 1300 refused option (b) over is gone and was replaced, not
relaxed.** Row S1's `op_param_lists:: == 0` term moved to row **BT22** when
item B5 wired the store; BT22 allows the store's thirteen PUBLISHED verbs by
name, `effective` is on that list, and `src/rdw.tcl` already had ten call sites
for it. Option (b) reds no row today. The spec paragraph that still claimed S1
"structurally forbids naming the list store inside `src/rdw.tcl`" is corrected
in the same commit.

**Result on the user's own M18, driven end to end:** key 1 now prints the six
declared rows and one sentence; key 3 still prints all 88; the three blocks are
pairwise different (469 / 466 / 1939 characters).

## THE FOUR DECISIONS TAKEN ON THE USER'S BEHALF — rule debt 1353

**(1) A row the run published that NO list declares is HIDDEN under keys 1 and
2, and the block says so.** Three options were costed. (A) hide, (B) show them
below the declared ones, (C) show them with a marker. B and C both leave 88
lines on screen and answer nothing the user reported — their complaint is the
LENGTH. Taken: **A, with the count said out loud**, because a pane that
silently drops 82 of 88 rows is DD-1's own failure shape one surface further
out. A narrowed block now carries:

> Narrowed to the mos annotation list as it stood at this dump. 82 columns are
> not in that list and not shown; this run published 88 for this device. Press
> 3 for everything this run published.

**Sub-decision: a `nonfinite` row no list declares is withheld like any other,
and COUNTED in its own clause** (` N of the withheld did not converge.`).
Ruling DD-1 and issue 1272 both say a non-finite row is the one fact a designer
most wants to be told about; keeping the ROW would make the pane's length
depend on how badly the circuit failed, so the FACT survives the narrowing even
though the row does not. Overrule by deleting one clause of
`rdw::_narrow_line`.

**(2) An EMPTY list is a SENTENCE, never a blank block.**

> The mos annotation list was empty at this dump, so nothing this run published
> for this device is shown. Press 3 for everything this run published.

A header followed by nothing reads as a broken window. This is the sixth
sentence on the channel item B3 minted five for (rule debt
`1245_B3_window_wording`), and it is the third the narrowing adds.

**(3) The block DOES carry the list's name, and it is PAST TENSE.** Issue 1300
refused a `list: annotation` label as "worse than silence", because a label
naming a list whose content is identical for all three implies a narrowing that
did not happen. Half of that lapses now the narrowing is real. The half that
does NOT lapse is that a standing block is a RECORD and the store is LIVE:
`rdw::_reslot_block` is a strict permutation ("adds nothing, removes nothing"),
so no edit path re-narrows a block already on screen and a Delete would leave a
present-tense label asserting something false. **"as it stood at this dump"** is
what makes the sentence true for the life of the block. It goes in the BLOCK
rather than in window chrome because the block is what the user pastes into a
design review (item R3) and chrome does not travel with a paste.

**(4) ORDER: the LIST's order wins, not the raw file's.** Item R2 (issue 1338)
already promises Up and Down move the row in this window; a key that re-rendered
in raw order would undo that promise on the very next press of 1. The
permutation is `rdw::_reslot_block`'s, re-used rather than re-derived, so "the
list's order" has one implementation in `src/rdw.tcl` and not two.

## WHAT THIS DOES NOT FIX, and the user will meet it next

**Keys 1 and 2 still show the SAME ROWS on a machine with no
`op_param_lists.conf` entries** — which is the user's machine (their conf holds
a header and `version 2`, nothing else). An unowned summary list falls through
`effective` to `seed`, which answers the PDK's DECLARATION, i.e. the same six
triples the annotation list answers. MEASURED on their sky130:
`effective mos annotation` and `effective mos summary` are byte-identical. The
two blocks are no longer identical — each NAMES its own list — but their rows
are. Spec §4.2 B4's table says list 2's default is "all available"; the store
says it is the seed. **Which is right is an E question and is not guessed
here**: changing the store's default changes what `_save_set` unions into
`params` and therefore what the deck saves, which is ruling DD-4 ground. On rule
debt 1353.

## Fences

* `tests/headless/test_rdw_window_1245.tcl` section **NW**, ten rows, BOTH arms.
  `RW_FLOOR` 134 -> 144.
* `tests/headless/test_rdw_keys_1245.tcl` section **KN**, two rows, real
  keybindings on a real canvas. `KX_FLOOR` 81 -> 83.
* **NW8 is the DD-4 / DD-6 fence** and it is driven, not asserted: a real
  instance's `.save` cards are byte-identical on all three list identities.
  Proved again outside the suite on the user's own tb_bandgap — **468
  `.save @dev[param]` cards, byte-identical before and after this change and
  across all three identities**.

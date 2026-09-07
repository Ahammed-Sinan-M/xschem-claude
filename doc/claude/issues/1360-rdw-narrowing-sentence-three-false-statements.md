# 1360 — the RDW's narrowing sentence said three things that were not true, and the store's device-flavor scope was fenced by nothing

**Status: FIXED** (commit on `fluid-editing`, with issue 1361).
**Subject:** `rdw::_narrow_line`, `rdw::_narrow_answer`, `rdw::_narrow_spec` in
`src/rdw.tcl` — the sentence issue 1353 added to a narrowed block.
**Why it matters:** that block is what the user pastes into a design review.
Issue 1353's own argument for putting the sentence *inside* the block rather
than in window chrome (row NW10) is that it travels with the paste. A sentence
that is WRONG travels too.

## (a) A block narrowed by a DEVICE-FLAVOR entry was captioned with the CLASS list's name

`rdw::_narrow_spec` resolved the rows through
`rdw::_list_params $cls $ln $cell` — flavor-aware, because
`op_param_lists::effective` asks `governs`, which lets a device-flavor entry
win — and then handed `rdw::_narrow_line` the **class**, which printed
`Narrowed to the <cls> <listname> list`.

MEASURED by two adversaries independently, on the user's own
`tb_bandgap` `/x1/x1` `M18`, in two gestures from their own reported workflow
(press 1, Delete, answer "this device flavor only"):

* `effective mos annotation` = six triples; `effective mos annotation
  sky130_fd_pr/nfet_01v8_lvt` = five (or four, in the other adversary's run);
* `governs` = `flavor {mos sky130_fd_pr/nfet_01v8_lvt}`;
* the pane showed the FLAVOR entry's rows under
  `Narrowed to the mos annotation list ... 83 columns are not in that list`.

The sentence was self-mixing: the NAME came from the class entry and the COUNT
from the flavor entry. `rdw::_edit`'s own success sentence, printed one
keystroke earlier, gets it right (`for cell <n> only`), and issue 1348 exists
precisely because class and flavor are different entries.

**FIXED** by `rdw::_narrowed_list`, which names the entry that answered in
`rdw::_edit`'s own words — `<listname> list for cells matching <glob> of class
<cls>` — and by `rdw::_narrow_spec` carrying `rdw::_scope_for`'s answer (the
file's ONE reader of `op_param_lists::governs`, split out by issue 1348) as a
fourth element. **REJECTED**: dropping the cellname from the `effective` call.
That makes the sentence true by making the pane wrong, and no suite would
notice — see (d).

## (b) The empty-list arm dropped the withheld-non-convergence clause

`rdw::_narrow_line` returned from its `if {$norder == 0}` branch before `$wnf`
was ever read. So the ONE case in which 100% of rows are withheld was the ONE
case that never said a withheld row failed to converge — contradicting the
sub-decision recorded beside it ("it is COUNTED, so the fact survives the
narrowing even when the row does not"), which row NW6 asserts from the other
side. MEASURED: the same answer under a non-empty list said `1 of the withheld
did not converge`, under an empty one said nothing, and key 3 printed
`znf : (did not converge)` throughout.

Reachable with no code at all: a shared settings file carrying
`list class mos annotation` with no `param` rows under it sets `owned=1` with an
empty list (`op_param_lists.tcl`'s parser), and a shared teammate conf is the
store's headline use case.

**Row NW4 golded the omission**, so the suite defended it. Both the code and
that golden are fixed; row **NW12** is the new fence and drives one, two and
zero non-converged columns under an empty list.

## (c) The number was a ROW count wearing the word "columns"

`rdw::_narrow_answer` counted every primitive's copy of a column separately.
One XR1 resolves to several primitives (ruling D-3), so a five-primitive device
publishing TWO distinct columns of which ONE is missing was told
`2 columns are not in that list and not shown; this run published 5 for this
device` — both numbers row counts, printed one line under the DD-1 line that
uses "columns" in the correct per-vector sense. A single block used the word
with two meanings one line apart.

**FIXED by the count, not by the word**: DD-1's line has the prior claim on
"column", and the narrowing is a decision about NAMES (a list declares `id`, not
`id on rend1`). `total`, `kept` and `wnf` are now distinct-column counts over
all three buckets; the FILTER is still per row, so ruling D-3's attribution of a
number to the primitive that published it is untouched. `wnf` moved with them —
a row count there could read "5 of the withheld did not converge" under "3
columns are not in that list". Row **NW13** uses row F7's own five-primitive
XR1 fixture.

## (d) The whole device-flavor path of the narrowing was fenced by nothing

An adversary changed `rdw::_narrow_spec`'s last line to
`rdw::_list_params $cls $ln {}` — silently disabling every per-cell list in the
pane — and measured `test_rdw_window_1245` ALL PASS (155),
`test_rdw_keys_1245` ALL PASS (83), `test_op_param_store_1245` ALL PASS (130).
Behaviourally real: with a class list `{a}` and a flavor list `{b}` governing
the same cell, the shipped code prints `b : 2` and the sabotage prints
`a : 1` — a number for the WRONG PARAMETER, under a sentence naming neither.

Cause: every one of NW1..NW10's fixtures is `cellname {}` and every KN fixture
is a class list. NW9 golds that `rdw::_list_ctx` PUTS `cellname` into the ctx;
nothing golded that anything USED it.

**FIXED** by row **NW11**, which builds a class entry and a flavor entry over
one class and asserts both the rows and the caption. Re-proved by sabotage:
`SB1b` (the `{}` above) reds NW11 and nothing else.

## Fences added, all on BOTH arms
`NW11`, `NW12`, `NW13` of `tests/headless/test_rdw_window_1245.tcl`.
`RW_FLOOR` 154 -> 162 in the same commit (with issue 1361's five rows).

## Sabotages, each restored by `cp` with the md5 verified after
| sabotage | red |
|---|---|
| `SB1a` `rdw::_narrowed_list` ignores the governing scope (the shipped defect) | `NW11` exactly |
| `SB1b` `rdw::_narrow_spec` passes `{}` for the cell (adversary A2's SAB-E) | `NW11` exactly |
| `SB2` the empty arm's clause is a literal `1 of the withheld ...` rather than the count | `NW12` exactly (NW4 stays green, so NW12 is not a copy of it) |
| `SB3` `rdw::_narrow_answer` back to counting rows | `NW13` exactly |

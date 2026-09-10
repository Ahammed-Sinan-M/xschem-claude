# 1338 — Up and Down moved the store and the sheet, and not the window

*Item R2 of the RDW batch (`doc/claude/rdw_batch/`). Branch `fluid-editing`.
Filed and fixed 2026-09-05, at HEAD `27122ca4` (item R1's cursor).*

**The user's words:** *"Promote/demote using Up/Down arrow should be reflected
in the Results Display Window as well as the schematic annotation - if applied
to annotation params (1 key) or summary list (2 key)."*

---

## What was actually wrong, and it was not what the plan said

`doc/claude/rdw_batch/PLAN.md` split the request in two and called the SCHEMATIC
half "the one that is missing today", telling the implementer to *"find what 6 /
Ctrl-6 call to redraw and call the same thing"*. **Half of that premise is
wrong, and the advice in it is actively harmful.** Measured at HEAD `27122ca4`,
driving a real `rdw::button up` on a live three-block fixture:

| what moved | measured |
|---|---|
| the STORE | `effective` goes `{id ids 0} {gm gm 1} {gds gds 1}` → `{gm gm 1} {id ids 0} {gds gds 1}` |
| the DESCRIPTOR | `shown` rewritten for **both** type tokens of the class |
| the SHEET | `xschem get annot_overlay_flushes` **+1**, and `op_annot::text M1` answers in the new order |
| the WINDOW | `::rdw::blocks` **byte-identical** |

So the sheet already followed, through `rdw::_apply_now` → `op_param_lists::apply`
→ `op_annot::register`, whose bump of `::op_annot::gen` carries the overlay
cache's epoch. What was missing was the **window**: the pane kept showing the
order the user had just changed until they pressed `1` or `2` again, which is
the one surface the user is looking at when they press the button.

⚠ **`xschem annotate_op` — what key `6` calls — is the WRONG seam and calling it
would destroy data.** It RELOADS THE RAW (`src/op_annot.tcl:1570,1591`), so on a
1-point operating-point run it would throw the numbers away. There is no second
redraw path to add; there was never a missing one.

A third thing was owed and is fixed here: **issue 1330**.

---

## What was measured, before any source change

Rows RE0–RE7 (`tests/headless/test_rdw_window_1245.tcl`, both arms) and RD1–RD2
(`tests/headless/test_rdw_keys_1245.tcl`, `:99` only) went in first. Five were
red and three were green:

* **RE1 / RE2** — three presses on one cursored row. The store moved; the block
  did not (`got {ids gds gm}`, `exp {gds ids gm}`).
* **RE4** — the multi-primitive block (ruling D-3): shape unchanged,
  `_target_line 12` where 10 was owed.
* **RE5** — the sibling block of the same class did not follow
  (`got {gm ids}`, `exp {ids gm}`).
* **RE6** — issue 1330: with `op_param_lists::apply` renamed to a proc that
  raises, the press reported the **byte-identical success sentence**.
* **RE3 / RE7** green before and after — a refusal changes nothing, and DD-4's
  "lists 1 and 2 re-render, list 3 and a refusal do not" already held.
* **RD1** — the PANE, read through `.rdw.p.t get` and the `cursor` tag's own
  ranges, driven through the real `.rdw.b.up` widget: pane params `{ids gds gm}`
  and tag range `{5.0 6.0}` where `{gds ids gm}` and `{4.0 5.0}` were owed.

---

## The trap: the pane's row order is NOT the list's row order

`rdw::format_answer` emits, per primitive, the `devices` pairs FIRST, then
`nonfinite`, then `absent`. So the IHP-shaped seed `{id ids 0} {gm gm 1}
{gds gds 1}` — label != param, a shipped PDK shape — whose `gm` came back
non-finite renders as

```
    ids : 1.2e-05          list index 0
    gds : 5.6e-06          list index 2
    gm  : (did not converge)   list index 1
```

An Up on `gds` swaps LIST entries 2 and 1 and leaves the DISPLAY exactly as it
was. **The obvious implementation — swap the two adjacent display lines — would
put `gds` above `ids` and the window would then show an order the store does not
hold**, which is the one thing this item exists to prevent. Row RE1 presses on
that very row and requires the block to come back UNCHANGED, then presses again
and requires it to change.

Two more wrong implementations have their own row (RE4):

* **sorting the block's parameter rows by list order** moves rows across the
  `  <rawdev>` sub-headers, so `4.4e-05` lands under `@m.x1.ma`, which never
  published it — a plausible wrong NUMBER in the block a designer pastes into a
  review document (invariant I3);
* **permuting every row of a group** moves `vgs`, which the run published and no
  list declares — the row the button column already refuses to reorder by name
  (row BT6).

---

## What changed

All in `src/rdw.tcl`.

**`rdw::_list_params {cls listname cell}`** (new) — the raw param names
`::op_param_lists::effective` holds, deduped. The order is asked for, never
re-derived (invariant I1). The CELL is passed so each block is re-slotted into
the order that governs IT; with no device-flavor entry, which is the ordinary
case, `effective` falls through to the class entry and then to the PDK seed and
the argument changes nothing.

**`rdw::_reslot_block {block order}`** (new) — re-fills the rows the list
DECLARES, in the list's order, into the slots those declared rows already
occupied, and answers a map from each row's old entry index to its new one. A
**maximal run of consecutive parameter rows is one primitive**, because
`format_answer` emits a sub-header and then that primitive's rows contiguously,
so a permutation confined to one run can never cross a sub-header. A row no list
declares keeps its own slot. The block's first entry carries issue 1322's
subject stamp and is never a parameter row, so it is never rewritten.

**`rdw::_reorder_shown {cls listname loc line}`** (new) — re-slots **every**
block whose subject resolves to the edited class, and answers the pane line the
cursored row moved to (a re-slot is length-preserving and confined to one block,
so the flat line moves by exactly the entry-index delta).

**`rdw::button`**, the up/down arm — re-slots, re-points the cursor, repaints,
and only then applies. The cursor is set BEFORE `render_pane` because
`render_pane` paints the shading on its way out; setting it afterwards would
paint twice and, in between, shade the line the parameter has LEFT.

**`rdw::_apply_now`** — issue 1330. It was three bare `catch`es and a bare
`return {}`; it now answers `{}` on success and a sentence on failure, reading a
raise as an exception and a `_say` as the store's own worded report
(`rdw::_store_tail`'s rule: the store's wording, never a second one). Both call
sites append it. **Measured: an ordinary accepted press adds nothing to `said`
across both applies**, so every success sentence in this window is byte-identical
to the one it emitted before — row RE6's third leg golds that the success
sentence is not negated.

---

## The E question this answers, and how to overrule it

Neither DD-3 nor DD-4 says whether an **older block of the edited class**
follows. It is implemented as **every block of that class follows**, because the
store is class-wide and the alternative puts the same class list on screen in two
different orders at once. On the owed ledger as rule debt
`1338_R2_every_block_of_the_class_follows` (`--eyes`). Overruling it deletes row
RE5 and nothing else.

A block with **no subject** (its device could not be resolved at dump time) and a
block of a **different class** are both left exactly as they were — nothing says
which list the first one's rows belong to, and nobody edited the second one's.

---

## Two test fixtures were stale, and the staleness is the feature working

Neither row's ASSERTION moved; both are per-row RESET helpers that reset the
store and not the pane, which was sufficient only while the pane never moved.

* **`b5_lists_reset`** (`tests/headless/test_rdw_window_1245.tcl`) now calls
  `b5_fixture_blocks`. Without it, BT8's accepted Up moved `gm` to line 9 and
  nine later rows (BT10, BT13, BT14, BT16, BT17, BT21, BT25, BT26, BT27) edited
  the wrong parameter. This is **issue 1312's own defect one layer out** — that
  paragraph is already in the proc, about a descriptor an earlier row wrote — and
  a store reset with no pane reset also leaves the two DISAGREEING, which is the
  state R2 exists to prevent. Section RE's `re_reset` was written this way from
  the start.
* **BE1** (`tests/headless/test_op_param_store_1245.tcl`) re-`set_row 11`'d
  before its second Up press, because until now `gds` stayed on line 11. The
  cursor follows the ROW now, so the second press landed on `gm` and produced
  `{ids gm gds}`. The row is cursored once and pressed twice, which is the
  user's actual gesture; its expectation is unchanged and is what caught it.

---

## Verification, 2026-09-05, this tree, binary rebuilt first

| suite | arm | result |
|---|---|---|
| `test_rdw_window_1245` | `--nogui` | `ALL PASS (124 checks)` |
| `test_rdw_window_1245` | `:99` | `ALL PASS (136 checks)` |
| `test_rdw_keys_1245` | `:99` | `ALL PASS (53 checks)` |
| `test_op_param_store_1245` | `--nogui` | `ALL PASS (130 checks)` |
| `test_op_annot` (control) | `--nogui` | `ALL PASS (485 checks)` |
| T1 `tclsh run_regression.tcl` | solo | **0 counted failures** |

Every one printed a RESULT line; run twice, identical. Floors raised in the same
change, as their own comments require: `RW_FLOOR` 116 → 124, `KX_FLOOR` 51 → 53.

**A green suite is not an eyeball.** R2 is a row moving under the user's eyes and
a shade of grey landing on it; a `look` debt is on the ledger. Suites green,
please look.

---

## The open half, closed 2026-09-07: Delete and Add reach the blocks too

R2 made the window follow **Up and Down**. It did not make it follow **Delete
and Add**, and the user found the gap:

> **Delete is not affecting the current display. Only future items sent to the
> RDW are conforming to the new list.**

They were exactly right, and the reason was `rdw::_reslot_block`: it is a
**strict permutation** — "same rows, same slots" — over the rows the run
published and the list declares. It can re-order a block and it can never add or
remove a row from one. R2 only ever needed the permutation, so the permutation
was all there was; a Delete has nothing to permute.

**Ruling, from the user, put to them with its cost stated: REBUILD THEM.** After
an accepted Delete or Add, every block whose device belongs to the edited class
is re-dumped from the loaded raw, through `rdw::_make_block` — the seam's ONE
builder, so a rebuilt block and a fresh dump are identical by construction (row
**NW9** golds the split: the builder carries the amendment, the door reaches the
builder, and the door renders no answer of its own). The narrowing footnote and
the column widths come out as a fresh dump would have them, which is why a
re-render rather than a row-removal: `rdw::format_answer` discards undeclared
rows at dump time, so a block holds pre-rendered text and no filter applied
later could restore what was never stored.

**The stated cost, which the user accepted:** a block stops being a frozen
record of the run, and an older dump changes under its reader.

**Blocks that cannot be rebuilt are left alone and COUNTED.** No stamp, another
schematic, a devpath that no longer resolves — and, the one that matters:

> ⚠ **A REBUILD MUST NEVER TRADE REAL NUMBERS FOR A REFUSAL.** With no simulator
> backend, no reader hook, or no raw loaded, `rdw::_make_block` legitimately
> answers a well-formed **refusal block** carrying no parameter rows. That is
> the correct answer to a *dump* and a catastrophic answer to a *rebuild*: the
> first cut installed it, so a Delete pressed with no raw loaded wiped every
> number off a block that had them and replaced it with a sentence. MEASURED —
> rows RE10 and RE11 answered `{}` where parameters were expected. A feature
> whose whole promise is "the pane follows the store" had started deleting the
> pane. The guard is a **count**: a rebuild that would take a block from some
> parameter rows to none is refused and the block is counted as stuck. Row
> **RE12** is the fence; `rdw::_stuck_note` says it on screen.

Row **RE10**'s "the row SET is untouched" leg is still true, and now says why:
that fixture has no raw, so nothing there can be rebuilt and the permutation is
what runs. `$RE10_RB` golds `0 rebuilt` so the accident is a contract.

Row **KD1** of the keys suite drives the whole thing through the real UI and
golds both directions: after the press, the block on screen has lost the deleted
row and kept the others.

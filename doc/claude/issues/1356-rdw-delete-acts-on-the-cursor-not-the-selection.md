# 1356 — the Results window's buttons act on the CURSOR row, and a mouse selection of six rows is not a six-row edit

**Status: FIXED, 2026-09-07 — the user ruled the other way and the multi-row
press is BUILT.** The silence was fixed 2026-09-05 as a stopgap while the
feature was a ruling; the ruling came back the other way and the clause it
stood in for is now narrowed to Up and Down, which still cannot take a batch.
Rule debt **1356** is discharged by the user's own instruction below; a NEW
rule debt, **1381**, records the three decisions this build had to take that
the instruction did not settle.

The user's own words:

> In the summary view for `M18:/x1/x1` of `tb_bandgap`, **I select a bunch of
> lines — `sa`, `sb`, up to `scc` — and press Delete** … The delete did not have
> an effect.

## What was measured

Driven on the user's own design, `:99`, real widgets:

* a real `<Button-1>` on the first row followed by five `<B1-Motion>` events and
  a `<ButtonRelease-1>` left `tag ranges sel` = **`8.4 13.4`** — six rows
  highlighted — while `::rdw::targetrow` was **8**, and **one press produced one
  verdict about one parameter**;
* after the narrowing (issue 1353) the same gesture on the six rows the summary
  list really declares: `tag ranges sel` = `5.0 11.0`, `rdw::_selection_lines` =
  **6**, and one Delete removed **`id` alone**.

## Why

`rdw::button` computes its target as `set line [rdw::_target_line]`, and
`rdw::_target_line` returns `::rdw::targetrow` and nothing else. Its ONLY setter
is `rdw::set_row`, called from `rdw::pane_click`, which is bound to
`<Button-1>` alone — `<B1-Motion>` goes to `rdw::pane_drag`, which only fixes up
the `sel` tag. **Every reader of the text selection in `src/rdw.tcl` is on the
CLIPBOARD path**: `copy`, `select_all`, `_selection_changed`, `_selection_span`,
`_sibling_selection`, `_arm_extend`, `pane_drag`, `popup_menu`. None is on the
edit path, and the right-click menu offers only Copy and Select All.

The two gestures — *shade one row* and *highlight several* — look identical on a
pane whose whole purpose is selecting text, and **nothing on screen said which
one the buttons obey.** "The delete did not have an effect" is a reasonable
reading of a delete that had exactly one.

## What was fixed

`rdw::_selection_lines` counts the pane lines the selection covers;
`rdw::_selection_note` returns one sentence when that is **two or more**, and
`rdw::_bstatus` appends it to every verdict `rdw::button` reports:

> Selecting lines does not choose them for editing - the buttons act on the
> shaded row alone.

**It is conditional, which is why it is an answer and not noise** — it fires
only when the user actually made the gesture it is about. And it is computed
**before** the edit, because every success arm ends in `rdw::render_pane`, whose
`delete 1.0 end` takes the `sel` tag with it: a note computed afterwards would
be silent in exactly the case it exists for.

MEASURED on the user's own M18 after the fix:

> Delete: removed id from the summary list for class mos. Selecting lines does
> not choose them for editing - the buttons act on the shaded row alone.

Fenced at the time by row **BT31** of `tests/headless/test_rdw_window_1245.tcl`
(both halves — the clause is there with a selection standing and gone without
one) and row **LX11** (the predicate itself, on both arms). **Both rows have
since been rewritten to the ruling below**; BT31 now golds the batch, and LX11
golds the clause narrowed to Up and Down.

## THE RULING, AND IT WENT THE OTHER WAY

The user's own words, 2026-09-07:

> **When multiple lines of parameters are selected and user presses Add or
> Delete, those should get processed the same way that a single line would get
> processed.** Is that already in place? If not, implement it.

So the proposal below was rejected. It is kept verbatim because its three costs
are exactly the three things the build had to answer, and each one is now a
named proc rather than a declared difficulty:

| the cost, as filed | how it is answered |
|---|---|
| one dialog for N rows | `rdw::scope_dialog` is raised ONCE, outside the loop — which is why the batch is confined to a single BLOCK: the dialog names one instance, one cell and one class, and a question that named one device while writing for another would be a false statement. Row **BT9** golds the count of exactly one; row **BT40** golds the cross-dump refusal. |
| one sentence for N outcomes | `rdw::_batch_edit` composes it: every row that changed is named, and so is every row that did not, **with the core's own reason for each**. A count would be the defect this item removes, pointed the other way. Rows **BT39**, **SL11**. |
| ruling DD-10 over the BATCH | `rdw::_batch_last_row_why`, asked **before the first write** against the base as it then stands. A batch that would empty the list is refused whole; a batch that leaves exactly one row is allowed. Rows **BT31** (leg set A), **BT38**, **SL5**. |

### What was built

* `rdw::_selection_rows` — the parameter rows the `sel` tag covers, in pane
  order, **deduped by parameter name** (a drag can cover one parameter in two
  dumps; the second Delete of `gm` would be refused by a store that had just
  removed it, so the batch would report a failure it caused itself), with the
  blocks recorded so a cross-dump gesture can be refused. Read ONCE at the top
  of `rdw::button`, for the same measured reason the note is: the first repaint
  destroys the tag.
* `rdw::_edit_target` — the entry a press writes, what is in it now, and the
  scope phrase, factored out of `rdw::_edit`'s head so the batch asks the
  identical question once. **Not** a second definition of the key: every arm
  calls `rdw::_write_key`. Row **BT41**.
* `rdw::_batch_edit` — runs the batch through `rdw::_edit`, N times, unchanged.
  It performs no store call of its own.
* `rdw::_batch_spread_why`, `rdw::_batch_skipped_say`, `rdw::_batch_mint_note`,
  `rdw::_and_list`, `rdw::_percell_note` — the prose, each in one place.

**A batch of ONE never reaches any of it.** `rdw::button` routes a single row to
`rdw::_edit` directly, so every sentence the suites gold byte-for-byte is still
produced by the code that produced it before this item.

### What the clause says now

Add and Delete no longer carry it — their own sentence names every row they
changed and every row they did not, which is a better answer than a standing
lecture. Up and Down still do, because they raise no dialog and N rows each
moving up one has no meaning independent of the order they are asked in:

> Selecting lines does not choose them for Up and Down - those act on the
> shaded row alone.

`rdw::_selection_note_for` takes the button id for exactly this. Rows **LX11**
and **LX15** drive both boundaries — the line count at 0/1/2/16 and the button
at up/down vs add/delete/save.

### MEASURED, on a real sky130 nfet with a real one-point raw

```
BEFORE   b0 = id gm gds vgs vth vds     b1 = id gm gds vgs vth vds
drag over id, gm, gds  →  Delete
  "Delete: removed id, gm and gds from the annotation list for class MOS."
AFTER    b0 = vgs vth vds               b1 = vgs vth vds     cursor cleared

drag over vgs, vth, vds  →  Delete
  "Delete: removing vgs, vth and vds would empty the annotation list, and at
   least one parameter must stay. To stop showing operating-point values on
   this device, turn the annotation off instead."
store unchanged — NOTHING was removed, which is the whole point of asking
ruling DD-10 of the batch rather than of each row in turn.

drag across two dumps  →  Delete
  "Delete: the selected rows span 2 dumps in this window. The scope question
   names one device, so select rows from one dump at a time."
```

---

## THE RULING AS ORIGINALLY PROPOSED (rejected by the user, kept for the record)

**Proposed answer: NO, keep it one row and keep saying so.** The costs are real
and none of them is a line of code:

* **one dialog for N rows.** The scope question (*this device flavor only* /
  *every device of class …*) is answered once; applying one answer to N rows is
  a different promise from the one the dialog makes today.
* **one status sentence would have to report N outcomes.** The window's whole
  discipline is that a button says what it did; "removed 4 of 6, refused 2"
  needs a channel that is not a one-line entry at the bottom edge.
* **ruling DD-10's last-row rule would have to be evaluated over the BATCH.**
  `rdw::_last_row_why` refuses a Delete that would empty a list. Per row, a user
  who selects five and presses Delete gets four deletions and one refusal —
  with four already gone and no undo in this window.

**The alternative, if the user wants it:** it is a real feature with a real
design, not a patch, and it should get its own item. Either answer is
defensible; what was not defensible is the window having a behaviour the user
had no way to learn.

## Read alongside

Issue **1355** (the window and the dialog now name the list), **1353** (the
narrowing, which is why `sa`…`scc` are no longer on the summary pane at all, so
the user's exact gesture is no longer reachable), and the rejected alternative
recorded in `rdw::button`'s own comment: a position-dependent grey would have to
re-grey on every cursor move, which needs a new binding on the pane and is issue
1306/1308 ground.

# 1356 — the Results window's buttons act on the CURSOR row, and a mouse selection of six rows is not a six-row edit

**Status: the SILENCE is fixed, 2026-09-05. The FEATURE is a ruling and is not
built.** Rule debt **1356**.

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

Fenced by row **BT31** of `tests/headless/test_rdw_window_1245.tcl` (both halves
— the clause is there with a selection standing and gone without one) and row
**LX11** (the predicate itself, on both arms).

## THE RULING OWED: should a multi-row edit exist?

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

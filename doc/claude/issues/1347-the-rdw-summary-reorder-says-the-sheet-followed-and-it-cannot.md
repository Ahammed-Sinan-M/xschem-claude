# 1347 — a key-2 (summary) reorder made the Results Display Window contradict the sheet, and the fence could not see it

**Status: FIXED (the false sentence). The E question underneath it is the
USER's and is OPEN** — rule debt `1347_R2_summary_order_on_the_sheet`.

Found by item **R2**'s adversary (verify run `wf_2a267b11-e28`, 2026-09-05)
while all four suites were green — window 141, keys 77, store 130, control 485.
Subject: `rdw::_edit` / `rdw::button` (`src/rdw.tcl`), and the structural fact
in `op_param_lists::_show_set` (`src/op_param_lists.tcl:1746`) and
`op_annot::text` (`src/op_annot.tcl`).

## The user's words, and the half that was not delivered

> "Promote/demote using Up/Down arrow should be reflected in the Results
> Display Window as well as the schematic annotation — **if applied to
> annotation params (1 key) or summary list (2 key)**."

Item R2 delivered the window half for both lists and the schematic half for
list 1. For list 2 it delivered the window half and **said** it had delivered
the schematic half too.

## The measurement

Three blocks, an IHP-shaped seed `{id ids 0} {gm gm 1} {gds gds 1}`, cursor on
M1's `gds` row, `rdw::set_list summary`, two accepted `rdw::button up` presses
(`--nogui`, and again on `:99` with a live pane):

```
store summary     ids gm gds   ->  gds ids gm
the pane          ids gds gm   ->  gds ids gm     (moved=1)
op_annot::text M1 "id  =\ngm  =\ngds =\n"
                  ->            "id  =\ngm  =\ngds =\n"   BYTE-IDENTICAL
descriptor shown  id gm gds    ->  id gm gds
annot_overlay_flushes                          +2
status line       "Up: moved gds up in the summary list for class ad2cls."
```

So after a key-2 reorder the window said `gds` first, the schematic still drew
`id` first, and the status line reported a plain success. The disagreement
survived switching back to list 1.

## Why it is structural, and not a bug in R2's code

`op_param_lists::apply` writes two descriptor keys. `params` is the
annotation+summary UNION, laid out **annotation-first** by `_save_set`.
`shown` — the only thing `op_annot::text` draws — is `_show_set`'s filter of
that union by the labels of `effective $cls **annotation**`, **in union
order**. So:

* every drawn row takes its position from the ANNOTATION list;
* a label the summary list alone carries is not in `shown` at all;
* therefore **the summary list's order can never reach the drawn sheet**, for
  any input, before or after R2.

Before R2 the two surfaces agreed because **both stood still**. R2 moved one of
them.

## The fence that was supposed to catch it, and what it actually measured

Row **RE7** of `tests/headless/test_rdw_window_1245.tcl` golds
`xschem get annot_overlay_flushes` `>= 1` for an accepted summary reorder. That
delta was measured at **+2** for the two presses above **while the drawn text
was byte-identical**: `op_annot::register` bumps `::op_annot::gen` on any
re-register, whether or not the descriptor came back different. RE7's own title
is true — the schematic IS asked to re-render — but a counter cannot see that
the answer came back the same, and DD-4's "lists 1 and 2 re-render the
schematic" was read as though it could.

RE7 is left exactly as it is: it defends DD-4's letter and nothing in it is
false. Row **RE8** is added beside it and golds the STRING `op_annot::text`
puts on the sheet, for both legs, with the counter read on both — so the row
says out loud that the counter cannot tell the two presses apart.

## What was fixed

`rdw::_drawn_note` (`src/rdw.tcl`), appended on the success arm of `rdw::_edit`
beside ruling DD-16's `_sheet_note`, for **Up and Down on the summary list
only**:

> The schematic draws the annotation list, so what it draws did not move -
> press 1 and reorder there to change the sheet.

The edit is **not** refused and the pane still follows it: the window half is
what the user asked for on list 2 and it is delivered. Delete and Add on the
summary list keep their sentences unchanged — they promise nothing about drawn
ORDER, so nothing they say is false.

## The E question, which is the user's

Should a **summary-list reorder reach the sheet at all**? Three answers, and
the choice changes what the schematic draws:

* **(a) say it — SHIPPED.** The sentence above. Costs one clause per press.
  DD-4 stays as written; only its reading is corrected.
* **(b) make list 2 reach the sheet.** `shown` would have to take its order
  from somewhere other than the annotation list — a rule for combining two
  orders, which nobody has stated. It also reopens ruling DD-6's "shown is
  DERIVED BY FILTERING params", built that way to contain issue 1288's
  duplicate-label door. A spec change to §4.2 B4, not a repair.
* **(c) stop re-slotting the pane on a summary reorder.** The window and the
  sheet agree again, and the user's "reflected in the Results Display Window …
  if applied to … summary list (2 key)" goes undelivered.

Recorded as rule debt `1347_R2_summary_order_on_the_sheet`. Overruling (a) for
(c) deletes row RE8's third-to-last leg and `rdw::_drawn_note`; overruling for
(b) is a new item.

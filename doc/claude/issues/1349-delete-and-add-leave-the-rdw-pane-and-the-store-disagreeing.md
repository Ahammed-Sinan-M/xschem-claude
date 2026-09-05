# 1349 — Delete and Add left the Results Display Window and the store disagreeing about order

**Status: FIXED.** Found by item **R2**'s adversary (verify run
`wf_2a267b11-e28`, 2026-09-05). Subject: the Delete/Add arm of `rdw::button`
(`src/rdw.tcl`).

## The shape

Item R2 taught the user a property: **the window shows the order the store
holds.** Up and Down maintained it. The two buttons either side of them did
not, and the reason the code gave for that was an argument about a different
question.

## The measurement (shipped R2, `--nogui`, dialog stubbed broad)

```
Up on gds        store  ids gds gm   pane  ids gds gm    agree
Delete gds (1)   store  ids gm       pane  ids gds gm
Add    gds (3)   store  ids gm gds   pane  ids gds gm    DISAGREE
```

Nothing on screen said why.

## Why the stated reason did not support the choice

`rdw::button`'s comment read:

> a re-slot could neither add the new row (no run published it) nor remove the
> deleted one (the run still did)

Both halves are **true**, and neither is about ORDER. `rdw::_reslot_block` is a
strict **permutation** over exactly the rows the run published AND the list
declares: it adds nothing, removes nothing, and leaves every undeclared row in
its own slot (that last is row **RE4**'s subject and was already fenced).
Membership and order are different questions, and the comment answered only the
first.

## The fix

The Delete/Add arm now calls `rdw::_reorder_shown` before `rdw::_apply_now`,
exactly as the Up/Down arm does, with the key `rdw::_write_key` builds for the
scope the dialog actually answered — so a **narrow** write re-slots only the
blocks that flavor entry governs and a **broad** one skips the blocks a flavor
entry shadows (issue **1348**). The cursor is re-pointed before the repaint,
for row RD1's reason.

## Acceptance

Row **RE10** of `tests/headless/test_rdw_window_1245.tcl`: after Up, a broad
Delete and an Add of the same parameter, the pane's declared rows are in the
store's order AND the pane's row SET is unchanged from the first press to the
last — so the row fences membership as well as order, which is what the old
comment was worried about. Driven RED against commit `0122c9a7`.

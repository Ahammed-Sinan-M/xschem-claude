# 1348 — a device-flavor reorder re-slotted a block of a cell the entry does not match

**Status: FIXED.** Found by item **R2**'s adversary (verify run
`wf_2a267b11-e28`, 2026-09-05), all four suites green at the time. Subject:
`rdw::_reorder_shown` (`src/rdw.tcl`).

## The shape

`rdw::_reorder_shown` re-slotted **every stored block whose subject resolved to
the edited CLASS**, into whatever order `effective` answers for that block's
cell *today*. That is a different set from "the blocks the write reached", and
the difference shows the moment a device-flavor entry exists.

## The measurement (shipped R2, `--nogui`)

Three blocks; a flavor entry `set_list flavor {re2cls <M1's .sym>} annotation`
governing M1's cell only; cursor on M1's `gds`; one accepted `Up`:

```
status line   Up: moved gds up in the annotation list
              for cells matching .../p4n.sym of class p4cls.
class annotation list   ids gm gds  ->  ids gm gds     (unmoved, correctly)
flavor list             ids gm gds  ->  ids gds gm
M1's block              ids gds gm  ->  ids gds gm     (its own list)
M2's block              gm  ids     ->  ids gm         <- NOBODY ASKED
```

M2 is a different cell, governed by the **class** entry, which the press did
not touch. So a press whose own sentence names one cell file visibly reordered
another cell's block.

The same hole has a second face on the other arm: a **broad** write over a
device a flavor entry governs really does change the class list and really does
*not* reach that device — `rdw::_shadow_why`'s broad sentence says so in those
words — while the pane re-slotted that very block anyway, contradicting the
sentence printed beneath it.

## The fix

`rdw::_write_key {cls cell listname scope}` — **one** builder of the
`{<scope> <key>}` an edit writes at, used by `rdw::_edit` for the write and by
`rdw::_reorder_shown` for the test. A block is re-slotted only when the entry
that GOVERNS its own cell (`rdw::_scope_for`, i.e. `op_param_lists::governs`)
is that same entry.

Two builders for one narrowing is invariant **I1**'s drift and is what defect
A6 of item B5-2 already cost this feature once (`owns flavor {…}` against
`effective`'s glob); this adds a consumer of the existing store verb, not a
second rule.

`wkey` `{}` disables the guard, for a caller with no key to name. No shipped
caller passes one.

## Acceptance

Rows **RE9** (a flavor press reaches the cells the glob matches and no others,
class list unmoved) and **RE11** (a broad press over a shadowed device leaves
that device's block byte-identical while the sibling the class entry governs
follows) of `tests/headless/test_rdw_window_1245.tcl`. Both driven RED against
commit `0122c9a7` before they were written.

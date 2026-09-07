# 1342 — the probe's own suite reddened when a third deck was added, because C5 counted `.control` blocks

**Status:** FIXED (this branch)
**Files:** `tests/headless/test_ase_simcaps_0948.tcl`

## What happened

The `op-wcard` commits add a **third** capability probe deck (deck C, the
altshow printer probe). Row **C5** of the probe's own suite reads

> every deck the probe hands the simulator asks for a results file in plain text

and implemented it as `count(".control") == count("set filetype=ascii")`. Deck C
produces **text by construction** — it redirects `show all` into a `.txt` and
writes no raw at all — so `set filetype=ascii` would be a request about a file
it never creates. The row went `{1 1 0}` against `{1 1 1}`.

**The sibling branch's hand-off note did not mention it.** It asked for
`test_op_annot`, `test_ase_optier_0963` and `test_op_param_store_1245` to be
confirmed — not the suite belonging to the very probe the second commit changes.

## Why the obvious repair was also wrong

Counting `write` **lines** instead of blocks answers 3, not 2: **deck A writes
its raw twice on purpose** — that repetition *is* the `appendwrite`
measurement. Measured, that gave `{1 1 1 0}`.

## The fix

C5 splits the probe source into `.control` blocks and asks the question only of
blocks that write a raw. Both counts stay **measured from the probe's own
source**, so splitting or merging a deck still cannot redden the row for a
reason that is not about its subject, and a raw-writing deck that drops the
request still does.

84 checks, all pass.

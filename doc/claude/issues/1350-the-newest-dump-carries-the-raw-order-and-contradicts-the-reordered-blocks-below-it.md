# 1350 — after a reorder, the NEXT dump of the same device lands in raw order and contradicts the blocks below it

**Status: FILED, NOT FIXED — it is an E question the user has not answered.**
Rule debt `1350_R2_does_a_new_dump_follow_the_store`.

Found by item **R2**'s adversary (verify run `wf_2a267b11-e28`, 2026-09-05).
Subject: `rdw::push` (`src/rdw.tcl:915`) against `rdw::_reorder_shown`.

## The shape

Row **RE5** answers an E question one way — "every block of the edited class
follows a reorder" — and its own title says *"the window never shows one class
list in two different orders at once"*. `rdw::_reorder_shown`'s comment makes
the same claim. **A new dump breaks it**, because `rdw::push` does not
re-slot: the door `rdw::key 1` → `rdw::show` → `rdw::dump` →
`rdw::dump_devpath` uses lands a block in RAW order on top of blocks that are
in the STORE's order.

## The measurement (`--nogui`, and reproducible after this batch's fixes)

```
two accepted Up presses on M1's gds
  store list          gds ids gm
  M1's block          gds ids gm
one further rdw::push of the same device
  block 0 (NEWEST)    ids gds gm      <- raw order
  block 3 (oldest)    gds ids gm      <- the store's order
```

The OLDEST dumps carry the NEWEST order and the NEWEST dump carries the raw
one. No row sees it: RE5 pushes nothing after its press.

## Why it is not fixed here

Both answers change behaviour the batch already decided, and neither is a
repair:

* **(a) re-slot in `rdw::push` (or in `render_pane`).** Every block draws the
  store's order, always, and the contradiction is gone. But it changes what a
  FRESH dump shows: the pane would stop being "what this run published, in the
  order the raw published it". **MEASURED**: row **RE0**'s own control golds
  the M1 block at `{ids gds gm}` and would go RED — with nothing wrong — because
  the seed order is `ids gm gds`. That is a decision about what the window IS,
  not a bug fix.
* **(b) stop re-slotting the older blocks** — i.e. overrule the existing rule
  debt `1338_R2_every_block_of_the_class_follows`. Then only the cursored block
  follows, and the window shows one class list in two orders at once on
  purpose, which is the thing RE5 exists to prevent.
* **(c) leave it and say so.** Shipped state. The window can hold two orders for
  one class after a re-dump, and nothing tells the user which is the store's.

The existing rule debt covers "an older dump re-orders under you". It does not
cover "and the newest one then disagrees with it", which is why this is filed
separately rather than folded into it.

## Acceptance, when the user rules

A row that presses Up twice, pushes the same device again and golds BOTH
blocks' parameter order — spelled so that (a) and (c) are distinguishable, the
way RE5's own guard blocks are.

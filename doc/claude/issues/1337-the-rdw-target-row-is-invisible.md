# 1337 — the RDW's target row is invisible: the cursor the buttons obey draws nothing

**Status: FIXED** by item **R1** of the RDW batch (`doc/claude/rdw_batch/`),
2026-09-05. Subject: `src/rdw.tcl` — `rdw::color_sources`,
`rdw::_color_fallback`, `rdw::build`, `rdw::render_pane`, `rdw::push`,
`rdw::set_row`, `rdw::_target_line`, `rdw::button`, and four new procs.
**Related:** issue **1324** (the same defect measured from the other side —
**also fixed here**, see below), rulings **DD-1** and **DD-2**, issue **1308**
(the window holds the keyboard), issue **1339** (item R3, the selection).

The user's words: *"clicking on any line makes the entire line a shade darker
(noticeably)."*

## What was wrong

**The cursor already existed. It just drew nothing.** `rdw::set_row` /
`rdw::_target_line` are item B5's target row and `rdw::_subject`'s own comment
already called it *"the block the CURSOR is in"*: Delete, Add, Up and Down have
acted on it since B5-3 landed. But the pane is `-state disabled`, so Tk draws
no insertion cursor at all, and the row those four buttons were about was a row
with nothing on screen to mark it.

Two consequences, both measured rather than reasoned:

* the user clicked a row, watched a new dump arrive, pressed Delete and was
  told the line they could plainly see was not a parameter row — issue
  **1324**, filed and not fixed, whose recorded measurement was `insert=9`
  while `targetrow=3`;
* `rdw::_target_line` preferred the pane's `insert` mark over the variable, so
  it could never answer *"no row"*: an `insert` mark always has a line.

## The measurements

Before, at HEAD `077bdfe4`, `./src/xschem --nogui --pipe -q --nolog`:

```
rdw::color cursor        -> black          (the generic _color_fallback
                                            fall-through, i.e. the pane's own
                                            #000000 text on a black bar)
rdw::palette             -> no `cursor` role at all
.rdw.p.t tag names       -> sel hdr dim dev note        (no cursor tag)
bind .rdw.p.t <Button-1> -> {}                          (the empty string)
set_row 3 ; rdw::push    -> _target_line 9, targetrow 3, nothing painted
```

After, same binary, same command (`:99` for the widget lines):

```
light theme  ase::palette table #ffffff -> rdw::color cursor #d7d7d7
dark  theme  (stub)          #202020 -> rdw::color cursor #484848
a 0.88 MULTIPLY would have given         #1c1c1c  — 4 parts in 255, invisible
tag names                -> cursor sel hdr dim dev note   (cursor LOWEST)
after set_row 3          : insert=3.0  _target_line=3  targetrow=3  tag=3.0 4.0
after one rdw::push      : insert=13.0 _target_line=0  targetrow=0  tag=
after set_row 5          : insert=5.0  _target_line=5  targetrow=5  tag=5.0 6.0
```

The middle line is ruling **DD-1** and it is also issue 1324's disagreement
made impossible: `_target_line` and `targetrow` are now one answer, so they
cannot differ. The `insert` mark still rides to the end of the pane on a
repaint — that is Tk's right gravity and no fix removes it — but it now has no
readers, and the next `set_row` puts it back.

## What changed

1. **`cursor` is a role of the window's own palette** (`rdw::color_sources`,
   `rdw::_color_fallback`), like the four tags beside it. Ruling **DD-2**: the
   shade is DERIVED, never written down.
2. **`rdw::_rgb255` / `rdw::_shade_step` / `rdw::_cursor_shade`** derive it from
   `ase::palette table` — the pane's own background — by an **absolute ±40 of
   255**, flipping to *lighter* when the pane is already dark. A multiply is
   the obvious derivation and is invisible in exactly the theme the derivation
   exists for (see `#1c1c1c` above). `_cursor_shade` reads `ase::palette`
   **directly**: `rdw::palette` iterates every role and calls each source, so a
   source that asked `rdw::color` for another role would recurse forever.
3. **A `cursor` tag on `.rdw.p.t`**, `-background [rdw::color cursor]`, spanning
   `n.0` to `n+1.0` so the colour reaches the right edge past the last
   character — *"the entire line"* — and **`tag lower cursor sel`**, because
   `tag names` proves `sel` is the lowest-priority tag in the pane and a
   full-width background above it would hide the selection this window exists
   to produce.
4. **`bind .rdw.p.t <Button-1>` → `rdw::pane_click`, with no `break`.** A
   `break` would shadow the Text class binding that sets the drag anchor and
   would cost item R3 its whole subject.
5. **`rdw::pane_click` refuses a line no block owns.** `index @x,y` CLAMPS —
   measured, a click in the empty lower half of a 12-line render answers line
   13 — and `rdw::_locate` is already the exact predicate for that, so the
   refusal needed no new machinery. A refused click leaves the cursor where the
   user put it.
6. **`rdw::_paint_cursor` is the one painter** and draws `::rdw::targetrow`
   alone. A tag tracking a private variable would have given the window two
   cursors, a visible one and the one Delete obeys, and every row of section BT
   would still have passed while Delete deleted a line nobody was looking at.
7. **`rdw::render_pane` sweeps a stale target** — `_locate` can no longer
   resolve it — **above** the Tk guard, so the two arms answer the same thing
   about the same store. That covers key `4` (`rdw::keep_latest`) and item R2's
   reorder for free.
8. **`rdw::push` clears the cursor** (ruling **DD-1**): it PREPENDS, so the line
   the user clicked now holds a different block's text.
9. **`rdw::button` gained one sentence**, because there are now two ways to have
   no row: *"no row is marked in this window - click a parameter row, which
   shades to show it is the target, then press Up again."* `line 0 is not a
   parameter row` would be a sentence about a line that does not exist.

## The suites

`tests/headless/test_rdw_window_1245.tcl` section **CU** (CU1–CU5, CU16, CU17;
both arms; floor 109 → 116) and `tests/headless/test_rdw_keys_1245.tcl` section
**CU** (CU6–CU15; `:99`; floor 41 → 51). No row spells a literal colour —
that would lock in the hard-coded grey DD-2 rejects; every row compares
luminances, so a literal fails for not moving with the theme and a multiply
fails for not moving far enough.

CU16 and CU17 were added by the implementing pass, for the two inputs the RED
rows do not ask about. **CU16**: a theme answering a Tk colour **name** rather
than hex — a name cannot be read at all on the `--nogui` arm (no `winfo`), so
the derivation must degrade to the fallback rather than raise or answer
`black`. **CU17**: the stale-target sweep with **no Tk**. `rdw::render_pane`
returns early without a display, so the sweep had to move ABOVE that guard for
the two arms to answer the same thing about the same store — and nothing fenced
it: measured by sabotage (sweep moved one line lower, restore verified by
`md5sum`), CU17 reds alone on `--nogui` while the whole `:99` keys suite,
row CU14 included, stays ALL PASS (51).

## Unratified, and on the user's queue

Three user-visible choices were made without the user, and are recorded as rule
debt **1337** so they can be overturned:

* **a click on nothing leaves the cursor where it was** (the pane's empty lower
  half, or an empty pane). DD-1 is silent; the alternative is clearing it, which
  punishes a missed click.
* **`rdw::keep_latest` (key 4) clears the cursor** when it discards the block
  the cursor pointed into. DD-1 names only `rdw::push`, and key 4 is the second
  path that moves the text under the cursor.
* **the new "no row is marked" sentence**, which joins the ten of item B5-2 and
  the seven of B3.

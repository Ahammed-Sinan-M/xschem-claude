# 1379 — the RDW chrome still says "No device has been sent here yet" after a device has been sent there

**Status: FILED, NOT FIXED.** Found 2026-09-07 by the look-debt digest batch,
while building a reusable pose for the Results Display Window screenshots — the
first photograph taken showed the empty-pane sentence standing over two full
blocks. Subject: `rdw::push`, `rdw::apply_list_state` and the invariant comment
at `src/rdw.tcl:409`.

## What happens

Open the Results Display Window, send a device to it, and the line above the
pane goes on claiming nothing has been sent:

```
PROBE listkind=annotation blocks=0
PROBE chrome_before=|No device has been sent here yet - the annotation list
                     (drawn on the sheet). Select a device and press 1.|
PROBE blocks_after=1
PROBE chrome_after =|No device has been sent here yet - the annotation list
                     (drawn on the sheet). Select a device and press 1.|
PROBE chrome_should=|Keys 1/2/3: the annotation list (drawn on the sheet) -
                     the buttons edit this list, not the block you are reading.|
```

Measured on `:99` (Xvfb 1920x1080x24, openbox 3.6.1) at `f25eb4a5`, driving the
real `rdw::open` + `rdw::push` through `--script`. `chrome_should` is this
tree's own `rdw::_chrome_line` called on the same state one line later, so the
window and its own chrome builder disagree — no golden, no interpretation.

The screenshot is worse than the transcript: the sentence sits directly above
two rendered blocks reading `x1.M1:/tb_bandgap/x1` and `x1.M2:/tb_bandgap/x1`.

## Why

`rdw::_chrome_line` takes `filled` from the store:

```tcl
proc rdw::_chrome_line {kind} {
    variable blocks
    return [rdw::_chrome_text $kind [rdw::_keys_bound] \
                [expr {[llength $blocks] > 0 ? 1 : 0}]]
}
```

but the only proc that pushes that text into the widget, `rdw::apply_list_state`
(`:3844`), is reached from exactly two places — `rdw::build` and
`rdw::set_list` — and the comment at `:409` states that as an invariant:

> `rdw::apply_list_state` is called only from `rdw::build` and `rdw::set_list`,

`rdw::push` calls neither. It calls `rdw::set_row` and `rdw::render_pane`, and
`rdw::dump_devpath` — the single door every dump goes through — ends at
`return [rdw::push $blk]`. So `llength $blocks` changes and nothing recomputes
the sentence that reports it. The chrome is correct at build time (the pane
really is empty then) and correct again the moment the user presses 1, 2 or 3
(which routes through `set_list`), which is why it survives: every path a suite
or a person takes *deliberately* repairs it.

## Why this one matters more than a wording slip

This is **issue 1367 in the mirror**. That one shipped a chrome line claiming to
be `Showing` a pane that was empty; its fix minted the `filled` argument to
`_chrome_text` precisely so the sentence could tell the two states apart. The
argument works. What was never wired is the *recomputation* — so the same
sentence is now false in the opposite direction, and the false statement is the
one a new user meets first: they send their first device to the window and are
told, over the top of the result, that they have not sent one.

The one-setter design in the `:3838` comment ("`rdw::set_list` calls exactly ONE
refresher, so a key press cannot move the buttons without moving the words") is
right and should stay. The defect is not a second builder; it is a *third
caller* that is missing.

## Fix, when someone takes it

`rdw::push` should end at `rdw::apply_list_state` — it already ends at two other
refreshers, and `apply_list_state` is idempotent (it re-derives title, chrome and
all five button states from `listkind` and the store). That also picks up the
button column, whose `Add`/`Delete` greying is a function of the same store and
has the same staleness by the same route — **not verified here**, and worth
measuring in the same pass rather than assumed.

Watch for the cost the `:2703` comment records: `build` deliberately creates the
header WITHOUT its text and lets `apply_list_state` fill it, so the call is
cheap, but a `push` that runs during teardown must not resurrect the widget.

## Fence it, or it comes back a third time

Neither direction of this sentence has a row that reads the WIDGET after a
push — 1367's rows read `_chrome_text` and `_chrome_line`, the builders, which
are correct in both directions and were correct throughout this defect. A fence
that cannot see the difference between the builder and the widget is what let
the same sentence be false twice. The row wanted is: open, push one block,
`update idletasks`, and assert `.rdw.hdr cget -text` **equals**
`rdw::_chrome_line $listkind` — an identity between the widget and its own
builder, which needs no golden string and cannot rot when the wording changes.

# 1362 — the RDW's status line silently amputated its own sentences, and the half it took was the answer

**Status: FIXED** (commit `fa0eb0b0` on `fluid-editing`) — **but its ELISION
was itself a defect and is now gone; see issue 1365.**

> ⚠ **SUPERSEDED IN PART BY 1365, AND THE SUPERSEDED PART IS THIS FILE'S OWN
> CENTRAL ARGUMENT.** Everything below about the one-line `entry` and about the
> wrapping surface still stands. What does not is the claim that a cap on the
> DRAWN text is harmless because "`::rdw::statusmsg` still holds every sentence
> whole ... the painter may shorten what it DRAWS and never what it HOLDS".
> `rdw::copy`'s sibling leg is `rdw::_sibling_selection` -> `selection get
> PRIMARY` — what the WIDGET holds — so an elided widget was an **elided
> clipboard** (MEASURED: 474 characters ending in `...`, against 618 before
> 1362), which is issue 1344's defect returning. The elision also made the
> painted string depend on the WIDTH, so a three-pixel resize destroyed a
> standing selection; and it merely moved the cliff, from 122 characters to 492,
> against real composed verdicts of 618-778. `rdw::_status_cut_mark` no longer
> exists: the cap is a cap on the surface's HEIGHT and the tail is scrolled to.

**Subject:** `.rdw.s.msg` and `rdw::status` in `src/rdw.tcl` — the one-line
field at the bottom of the Results Display Window.
**Why it matters:** issue **1356** minted a clause *specifically* to answer the
user's "the delete did not have an effect". Three independent passes —
adversaries B1 and B2 and the completeness critic — each measured that the
clause never reached the screen. The window answered the question and then hid
the answer.

## What was measured

At HEAD `2004f5e6` on `:99`, and re-measured at `773920f1` by the pass that
fixed it. `.rdw.s.msg` was a one-line `entry -textvariable ::rdw::statusmsg
-state readonly`, **887 px wide at the window's own default 893x498**, with
`-xscrollcommand` empty, no scrollbar (`.rdw.s` has exactly one child) and
`xview` parked at `0.0 0.85`.

After a six-row drag on the pane plus one Delete, the verdict is **147
characters / 1045 px** of TkTextFont:

```
VISIBLE:  Delete: removed id from the summary list for class mos. Selecting
          lines does not choose them for editing - the buttons act on
CUT OFF:   the shaded row alone.
```

The reader is left with a dangling *"the buttons act on"* naming nothing. The
pre-fix build produced 55 characters / 398 px for the same gesture and fitted
with 489 px to spare, so the truncation arrived **with the clause**.

## ⚠ IT WAS NEVER ONE STRING

Adversary B1 named two more shipped sentences over the same 887 px, and this
pass measured a fourth. All four, in the window's own default font:

| sentence | chars | px | was |
|---|---|---|---|
| issue 1356's Delete verdict | 147 | 1045 | cut at `the buttons act on` |
| `rdw::_edit`'s `$notin` refusal | 158 | 1091 | cut at `only the list's o` |
| `Delete: no row is marked …` | 128 | 893 | cut at `press Delete agai` |
| `Delete: a device pick is running …` | 191 | 1348 | cut at `A dialog opened n` |

`rdw::status` has **34 call sites** and three of them interpolate an unbounded
parameter name or filesystem path (`Save: wrote the operating-point parameter
lists to <path>`). Shortening one clause would have moved the cliff by one
sentence; the next sentence anyone writes falls off it too. **So the SURFACE
changed, not the sentence.** No wording in this window was altered by this fix.

## The four options, costed

1. **Shorten the clause.** Cheapest, but the clause exists *because* the user
   asked what it answers, this window has a standing rule against rewording
   B3's minted sentences ad hoc, and it fixes one of four. **Rejected.**
2. **Widen the window's default** to the 1051 px this one sentence needs. A
   per-sentence answer to a general problem, it does nothing for the 1348 px
   one, and a window manager is free to refuse the size. **Rejected.**
3. **Move the clause off the status line** into the pane, the scope dialog or
   the chrome. The pane is the artifact the user pastes into a design review
   and row LX10 is the fence that keeps chrome *out* of it; the chrome is
   per-identity, not per-verdict; the scope dialog is gone by the time the
   verdict exists. None of the three can carry a sentence about one press.
   **Rejected.**
4. **Make the surface able to show what it is given.** **TAKEN.**

## FIXED

`.rdw.s.msg` is now a **wrapping, read-only `text`** that takes as many lines
as its message needs — borrowed from the pane and given back — capped, with a
marked elision past the cap.

* `rdw::status_max_lines` — the cap, **4**, a named number rather than a
  literal inside the painter. Rule debt **1362**: it is the user's number.
* `rdw::_status_height` — the clamp, pure, drivable with no Tk (row SL1).
* `rdw::_status_show` — the one painter (row SL2). It asks the **widget**
  `count -displaylines`, in whatever font the server resolved; past the cap it
  binary-searches the same question for the longest prefix that fits and cuts
  at a space, marking the cut with `rdw::_status_cut_mark` — which is
  `cadence::_annot_fit`'s decision for the C status line (issue 0639) one
  surface over.
* `::rdw::statusmsg` still holds the sentence **whole**. It is the record: the
  `--nogui` arm asserts against it and `rdw::copy` hands it over. The painter
  may shorten what it *draws* and never what it *holds* (row SL3).
* `bind .rdw.s.msg <Configure> {rdw::_status_refit}` — the fit is re-asked on
  the first map and on every user resize, so a window dragged narrower does not
  hide the tail of a sentence already on screen (row SL8).
* `rdw::_status_put` refuses to repaint text the surface already holds. A
  repaint destroys the `sel` tag, and the refit above runs on **every** resize
  — so without the guard, dragging the window's edge while the settings-file
  path was selected would put that selection down under the user's hand, which
  is issue 1344 defect c reached by a different gesture (row SL8's last leg).
* `bind .rdw.s.msg <<Selection>> {rdw::_status_clamp_sel}` — a `text` holds a
  mandatory trailing newline and a drag to the right-hand edge selects it.
  MEASURED the moment the class changed, by pre-existing row **CP14**: PRIMARY
  came back as the settings-file path with a newline glued on. Clamped at the
  **selection**, not at the copy, so the window never publishes a selection it
  did not mean — row CP15 states the same rule for the pane.

**⚠ NOT ONE PIXEL CONSTANT ANYWHERE, AND THAT IS THE POINT.** 147 chars /
1045 px / 887 px are font metrics as Xvfb resolves TkTextFont. The user's own
server (`$DISPLAY` 172.20.160.1:0, vendor HC-Consult) may substitute a
different font, so a fix carrying `1051` would be wrong on their machine by
construction. Every decision above is taken by asking the live widget.

**Measured after:** all four sentences in the table read in full at the
window's own default size, `yview` `0.0 1.0`, the widget's text identical to
the model. At rest the window is `893x498` and `.rdw.s.msg` `887x21` —
byte-identical to the entry it replaced. A two-line verdict makes the window
`893x515`; a `wm geometry`-pinned window keeps its size and the **pane** gives
the line up instead (row SL8).

## Fenced by

Section **SL** of `tests/headless/test_rdw_window_1245.tcl`, eight rows,
`RW_FLOOR` 162 -> 165 (SL1/SL2/SL3 run on both arms; SL4..SL8 need a mapped
window and a real font). All eight are RED on the unmodified pre-fix source
(`8 FAILED (190 passed)`, no pre-existing row moved). Non-vacuous, each by a
sabotage naming its own row:

| sabotage | red |
|---|---|
| A `_status_height`'s non-integer arm returns 2 | **SL1** exactly |
| B a second `.rdw.s.msg insert` site | **SL2** exactly |
| C `_status_cut_mark` returns `…` | **SL3** exactly |
| D the surface never grows (the defect restored) | SL4 SL5 SL6 SL7 SL8 |
| E the elide branch never runs | **SL6** exactly |
| F the surface never shrinks back | SL7 SL8 |
| G the `<Configure>` refit unbound | **SL8** exactly |
| M the no-repaint guard removed | **SL8** exactly |
| J the fit measures the text that is already there | SL4 SL6 SL7 |
| K the 1356 clause shortened | SL5 LX15 |

SL4 (general, quantified over length) and SL5 (the user's own gesture at the
clause's real length) are each red where the other is green — J and K — so
neither is a copy of the other.

Rows **CP14** and **CP16** of `test_rdw_keys_1245.tcl` were re-spelled for the
new widget class (`selection present/range/clear` -> `tag ranges/add/remove
sel`). Neither row's name, property or expected values moved; `KX_FLOOR` is
unchanged at 88.

## Two residues, said out loud

* **A masked sabotage.** `rdw::_bstatus` rewritten to set `::rdw::statusmsg`
  directly, bypassing the painter, leaves the suite ALL PASS. It is masked, not
  unfenced: the `<Configure>` from the previous message's height change is
  still queued, and the refit that fires on it repaints from the model, so the
  user really does see the right text. Recorded because the next person to try
  that sabotage will otherwise conclude SL5 is vacuous, and it is not — SAB-K
  reds SL5 while SL4, SL6, SL7 and SL8 stay green.
* **The section had to be re-hardened for its own red state.** `llength` on
  `rw_w`'s `ERR:bad option "tag": must be bbox, cget, …` raises `list element
  in quotes followed by ":"`, and the first draft of row SL8 therefore KILLED
  the whole file in the pre-fix state: `ok` lines, seven FAILs and no verdict.
  `sl_len` is the wrapper. This file's header warns about exactly that (item
  A2's lesson 6) and it still happened, one row at a time.

## What is still owed

* **Look debt `rdw_1362_status_wrap`** — nobody has seen this on the user's own
  server. The wrap point, the resting height and whether a window that grows
  17 px for a long verdict is acceptable are all theirs to judge.
* **Rule debt 1362** — the cap of 4 lines, the decision to let the window's
  height follow the verdict rather than pinning it, and the `...` marker.

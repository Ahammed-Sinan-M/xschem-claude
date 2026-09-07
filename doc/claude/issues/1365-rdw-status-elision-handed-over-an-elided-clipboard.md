# 1365 — the Results window's status surface handed over its own elided picture of a sentence

**Status:** FIXED (the elision is gone; the cap is a height and the tail scrolls)
**Filed by:** the pass repairing issue 1362's adversary findings
**Against:** commit `fa0eb0b0` — *"fix(1362): the status line stops cutting its
sentences in half, and the surface answers for the next one too"*
**Files:** `src/rdw.tcl` (`rdw::_status_show`, `rdw::_status_put`,
`rdw::_status_scroll_wanted`, `rdw::_status_scroll_sync`,
`rdw::_status_scrollset`, `rdw::build`), `tests/headless/test_rdw_window_1245.tcl`
(section SL — SL3 and SL6 re-spelled, SL9/SL10/SL11/SL12 added)

---

## What 1362 did, and the sentence it staked itself on

Issue 1362 replaced `.rdw.s.msg` — a one-line read-only `entry` 887 px wide at
the window's own default 893x498, with no scrollbar and `xview` parked at
0.0-0.85 — with a wrapping read-only `text` capped at `rdw::status_max_lines`
(4) display lines, and past that cap it **elided** the sentence at a word
boundary and marked the cut with `...`.

Its load-bearing claim, in the commit message, in `src/rdw.tcl`'s own comment
and in NUMBERING.md:

> `::rdw::statusmsg` still holds every sentence WHOLE: it is the record the
> `--nogui` arm asserts against and the string `rdw::copy` hands over, so the
> painter may shorten what it DRAWS and never what it HOLDS.

**The second half of that sentence is false about this window**, and the three
defects below all fall out of its falseness.

## (1) The copy handed over the elided text — issue 1344's defect, returning

`rdw::copy` has three legs. The second is `rdw::_sibling_selection`, which asks
`selection own` and then `selection get -selection PRIMARY` — **what the widget
holds**. `::rdw::statusmsg` is never consulted on that path and *cannot* be:
the user selected a **range** of the widget, and only the widget knows which
characters those are.

MEASURED on :99 at 893x498, on a 618-character verdict composed out of the
parts `rdw::button` really emits (`rdw::_edit`'s own sentence + `_sheet_note`
+ `_shadow_why` + `_selection_note`):

| build | `.rdw.s.msg` holds | PRIMARY after select-all | clipboard after `rdw::copy` |
|---|---|---|---|
| pre-1362 (`entry`) | 618 chars | 618 chars, ends `the shaded row alone.` | **618 chars** |
| at `fa0eb0b0` | 474 chars | 474 chars, ends `still wins -...` | **474 chars, ends in `...`** |

That is issue 1344's own defect — this window handing over text the user did
not select — **returning through the door 1344 was fixed for**, in the window
whose stated purpose (ruling DD-5) is select-and-paste.

## (2) A three-pixel resize destroyed a selection standing in the status line

`rdw::_status_show` did an unconditional `rdw::_status_put $txt` with the FULL
model *before* it measured. On a capped message the widget therefore always
held a different string from the one being put, so `_status_put`'s no-repaint
guard — added by 1362 for exactly this reason — **could never fire**, and the
fit loop then repainted up to thirteen more times inside the binary search.
Every repaint destroys the `sel` tag.

MEASURED: 618-character verdict, `sel` at `1.10 1.40`, window dragged
893 → 890: the tag is **gone**. The pre-1362 `entry` survived the identical
drag. Row SL8 asserted this property and could not see it — its 260-character
message never reaches the cap, so its painted string did not depend on the
width and its guard fired for free.

## (3) A shipped verdict was still cut at the window's default size

MEASURED at 893 px: the first message length the surface elides is **492
characters**. Real composed verdicts run 618–778 (`rdw::_edit` already appends
`_sheet_note`, `_drawn_note` and `_shadow_why`; `rdw::_bstatus` appends
`_selection_note` on top), and a path-free composition reaches 449. So 1362
moved the cliff from 122 characters to 492 and the sentence that answers the
user's question still did not arrive whole.

Section SL could not see this either: SL4 drives at most 260 characters of
filler, SL5 drives 147, and SL6 drives 4000 and asserts only that the cut is
MARKED. **Nothing composed a verdict out of the parts the button column really
emits.**

## (4) The elide path was only ever driven on punctuation-free filler

`sl_msg` generates `the quick brown fox jumps over the lazy dog` repeated —
no full stops, no hyphens, no slashes. The adversary changed the painter's
word-boundary backoff from `string last { }` to `string last {. }` — a change a
reasonable implementer could make — and **all three suites stayed green** while
a real verdict lost a further 116 characters on screen.

---

## The fix: the cap is a HEIGHT, and the text is never cut

The elision is removed rather than patched. `rdw::_status_show` paints
`$statusmsg` and nothing else, at every length and whatever the width; it then
asks the live widget `count -displaylines`, clamps the surface's **height** to
`rdw::status_max_lines`, and packs a scrollbar beside it when the sentence
needs more lines than the surface has.

All three defects then close **by construction** rather than by three guards:

* the clipboard is whole because the widget is whole;
* `_status_put`'s guard fires on every resize, because the painted string no
  longer depends on the width;
* nothing is amputated at any length, so (4) has no path left to test.

**A scrollbar is the affordance `...` only looked like.** Both say "there is
more"; only one can be used to read it, and only one leaves the characters
where a selection, a copy and a middle-click paste can reach them.
`cadence::_annot_fit` (`utils/annot_mode.tcl:724`) elides the C status bar
because that bar is a fixed-size *drawing* with no widget behind it and nothing
in it can be selected; this surface is a Tk text the user copies from, and
ruling DD-5 is what makes the difference load-bearing rather than stylistic.

### Alternatives costed and rejected

* **Revert to the one-line entry.** It held the sentence whole — which is why
  the pre-1362 copy was correct — but showed 122 characters of 618 with no
  scrollbar and no marker. That is issue 1362 itself, and the clause it
  amputates is the one the user asked for.
* **Keep the elision and teach `rdw::copy` to hand over the model.** The user
  selected a RANGE; there is no honest map from a range of the elided picture
  back to a range of the sentence. It also fixes neither (2) nor (3).
* **Raise the cap until today's longest verdict fits.** A per-sentence answer
  to a general problem, and the three sentences that interpolate a filesystem
  path have no longest.
* **Widen the window.** Costed and rejected by 1362 for reasons that still
  hold: a window manager is free to refuse the size.

### What is still the user's

The cap itself. Four lines shows about 474 characters at 893 px, so a
676-character verdict is four lines read and three lines scrolled. **Nothing is
lost either way** — the question is only how much of the window a status line
may take, which is on rule debt 1362.

---

## Fences

`tests/headless/test_rdw_window_1245.tcl`, section SL:

* **SL9** — a select-all in the status surface at a length past the cap: the
  surface holds the model character for character, the X PRIMARY selection IS
  the model, and `rdw::copy`'s clipboard IS the model. (defect 1)
* **SL10** — a selection standing in a verdict past the cap survives three
  pixels of resize, with the same characters under it; control leg at a length
  inside the cap. (defect 2)
* **SL11** — a verdict composed the way `rdw::button` composes one: the return
  of `rdw::_edit` (carrying `_sheet_note` and `_shadow_why`) plus
  `_selection_note_for` appended as `_bstatus` appends it. MEASURED at **676
  characters / 7 display lines** with a real filesystem path and real
  punctuation; read whole, copied whole, last character reachable. (defects 3+4)
* **SL12** — the scrollbar's decision, pure, driven at the cap, one past it,
  and at the two non-integer counts an unmapped widget answers.
* **SL3** re-spelled — the painter is handed `$statusmsg` and nothing else, and
  no cut marker exists anywhere in the file to be reached for.
* **SL6** re-spelled — past the cap the sentence is held whole, drawn whole, the
  scrollbar is on screen and the last character can be brought into view.

`RW_FLOOR` 165 → 166 in the same commit (SL12 is the only new row that runs on
the `--nogui` arm). `KX_FLOOR` unchanged at 88.

### Sabotages (all applied to the repo file, restored by `cp` from a gold copy, md5 verified)

| # | sabotage | window `:99` |
|---|---|---|
| A | the 1362 elision restored verbatim (the defect) | 5 FAILED — SL3 SL6 SL9 SL10 SL11 |
| B | `_status_scroll_wanted` returns `need > h + 1` | 1 FAILED — **SL12** |
| C | `_status_put`'s no-repaint guard removed | 2 FAILED — SL8 SL10 |
| D | the scrollbar never packs | 1 FAILED — **SL6** |
| E | a width-INDEPENDENT 550-character cut | 4 FAILED — SL3 SL6 SL9 SL11 (**SL10 green**) |
| F | `rdw::_sheet_note` returns `{}` | 2 FAILED — BT29 **SL11** |
| G | `_status_clamp_sel` clamps at `end - 60c` | 3 FAILED — SL9 SL10(control) SL11 (**SL3 SL6 green**) |

Every row is red where another is green, so none is a copy of another: SL10 is
green under E where SL9 is red (it measures the width-dependence, not the
length); SL9 is red under G where SL3 is green (it measures the clipboard, not
the call site); SL11 is red under F where every other row is green (it measures
the real composition, not a length).

## Not fixed here, and named so nobody thinks they were

* The four adversary refutations against the 1353 narrowing sentence and the
  three false chrome sentences are issues 1360/1361 and are already repaired;
  the **remaining** open items of this batch (the `$notin` sentence's claim
  about a pane that no longer shows undeclared rows, "cancelled" reported for a
  Delete pressed with the window closed, `rdw::build`'s dead `listkind` reads)
  are untouched by this commit.
* The cap's VALUE is a ruling, not a defect, and stays on rule debt 1362.
* Nothing here has been seen on the user's own server (`$DISPLAY`
  `172.20.160.1:0`, vendor HC-Consult); look debt `rdw_1365_status_scroll` is
  what remains.

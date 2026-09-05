# 1339 — select and `Ctrl-C` did not copy, and double-click-then-drag threw the word away

*Item R3 of the RDW batch (`doc/claude/rdw_batch/`). Branch `fluid-editing`.
Filed and fixed 2026-09-05, at HEAD `01fdebc5` (item R5's engineering
notation). The number was reserved in `NUMBERING.md` when the batch was
planned; the file itself was never written until now.*

**The user's words:** *"Select and then press CTRL-C doesn't work. (Using
VcXsrv for now). Double-click to start selection and then extend selection with
press-and-drag seemed to work once, but not reliably. It's only worked one
time."*

Pasting a dump into a design-review document is the whole stated reason the
Results Display Window is a Text widget and not a CIW dump, so this is the item
that decided whether the feature was usable at all.

---

## The obvious fix was a no-op, and shipping it would have been green and wrong

Ruling **DD-5** spells the repair as *"bind `<Control-c>`, `<Control-Insert>`
and `<<Copy>>` to a proc that reads `sel.first`/`sel.last` and calls
`clipboard clear` + `clipboard append`."*

Measured on this binary — Tk 8.6.17, `:99`, 2026-09-05, before any source
change:

```
event info <<Copy>>
    <Control-Key-c> <Key-F16> <Control-Lock-Key-C> <Meta-Key-w>
    <Lock-Meta-Key-W> <Control-Key-Insert>
```

Both sequences DD-5 names are already carried, and **with the keyboard in the
pane a real `Ctrl-C` already copied** through Tk's own `bind Text <<Copy>>` →
`tk_textCopy`. A test row that selected a line, pressed `Ctrl-C` at the pane and
asserted the clipboard passes on the *unmodified* tree and tells the user
nothing. Three different things were broken, and the literal reading of DD-5
fixes none of them.

---

## What was actually wrong — three mechanisms, each driven

### 1. The keyboard is usually not in the pane

The only copy was a **class** binding, so it existed only while `.rdw.p.t`
itself held the keyboard. Measured, with a selection standing and the keyboard
on this window's own `Up` button: a real `Ctrl-C` copies **nothing at all** —
the CLIPBOARD does not even come into existence. Same with the keyboard on the
toplevel `.rdw`.

Both are one click away, and worse: `rdw::_arm_focus_handback` deliberately
hands the keyboard to the **canvas** after every dump (issue 1306/1308), so
*"press a button, then copy"* is the ordinary path and *"click the pane, then
copy"* is the rare one. Item R2 had just made the button column worth pressing.

### 2. Another X client takes PRIMARY and the selection vanishes

The pane is `-exportselection 1` (`rdw::_exportsel`, `src/rdw.tcl:716`). A Tk
text widget that exports the selection answers the loss of PRIMARY by
**deleting its own `sel` tag**. Driven:

```
    selection own -selection PRIMARY .        ;# another client takes it
    .rdw.p.t tag ranges sel                   -> {}          (empty)
    .rdw.p.t get sel.first sel.last           -> raises
    <Control-Key-c>                           -> clipboard never written
```

`tk_textCopy`'s own `catch` swallows the raise, so the copy fails **silently**.
That is both halves of the user's report in one mechanism, and VcXsrv is exactly
where it bites: its Windows clipboard bridge takes PRIMARY on its own schedule,
which is why the gesture *"worked one time"*.

### 3. Double-click, let go, then press and drag cuts the word in half

`bind Text <1>` ends in `%W tag remove sel 0.0 end` and `tk::TextButton1`
re-anchors on the press, so the second gesture starts a fresh **character** run
from wherever it landed. Measured 5/5, deterministically, on the fixture's
line 3: the double-click selects `complete` at 3.6–3.14; a press at 3.10 and a
drag to 3.40 answers `3.10 3.40` — `lete list: these are the opera`.

The gestures that **do** work are holding the second click down (Tk's own
word-wise extension, 3.6–3.44) and double-click-then-shift-click. That is
precisely why the user saw it work once: their hand sometimes held the second
click.

---

## What was measured before the fix

`tests/headless/test_rdw_keys_1245.tcl` gained section **CP** (eleven rows from
the RED agent, one more — CP12 — from the implementing crew), floor raised
59 → 71. On `:99`, no source change, **byte-identical over four consecutive
runs**:

```
RESULT: 5 FAILED (65 passed)
  CP2  {{.rdw.p.t .rdw.p.t 1} ... {.rdw.b.up .rdw.b.up 0} {.rdw .rdw 0}}   exp all 1
  CP3  {1 1 0 0}                                                exp {1 1 1 1}
  CP4  {0 0 0 0 0 0 disabled}                                   exp {1 1 1 1 1 1 disabled}
  CP5  {1 .rdw.p.t 0 0 0 0 1}                                   exp {1 .rdw.p.t 1 1 1 1 1}
  CP6  {1 1 0 1 1}                                              exp {1 1 1 1 1}
```

and **the same five, plus CP12, on the user's own server** — `$DISPLAY` =
`172.20.160.1:0`, vendor `HC-Consult`, the VcXsrv the report came from (ruling
**DD-8**; `:0` is WSLg's Xwayland and is *not* it):

```
RESULT: 11 FAILED (60 passed)      # the five above, CP12, and five pre-existing RA reds
```

---

## What changed

All of it in `src/rdw.tcl`; no C, no other file.

**The chord moves to the toplevel bindtag** (`:1352-1354`). Measured bindtag
chains: `.rdw.p.t` → `.rdw.p.t Text .rdw all`, `.rdw.b.up` → `.rdw.b.up Button
.rdw all`, `.rdw` → `.rdw Toplevel all`. One binding therefore covers the pane,
all five buttons, the status entry and the toplevel. **Not `bind all`**, which
is the cheap way to the same reach and which reaches `.drw`, where `Ctrl-C` is
the schematic's own copy — row CP11 is that fence. All three sequences are
bound per DD-5; Tk prefers a physical binding over a virtual one on the same
tag, so exactly one fires per keystroke.

**A mirror that survives a PRIMARY theft** (`rdw::_selection_changed`,
`:1697`). The selection is remembered in `::rdw::selspan` and painted with a
tag of the pane's own, `keepsel`, pinned in priority between `cursor` and `sel`
(`:1453-1455`) so it neither hides the real selection nor is hidden by the line
cursor.

The hard part was telling a **theft** from a **deliberate deselect**: both
arrive as one `<<Selection>>` with `tag ranges sel` empty. Measured, reading
`selection own` *inside* the handler:

| what happened | `selection own -selection PRIMARY` |
|---|---|
| user clicks elsewhere in the pane | `.rdw.p.t` |
| a script does `tag remove sel` | `.rdw.p.t` |
| another client takes PRIMARY | that client, or empty |

Tk does not release the selection when the tag is merely emptied. So *"the pane
still owns PRIMARY"* means the user gave the selection up and the mirror goes
with it; *"the pane has lost PRIMARY"* means it was taken, and the highlight
must not vanish under them. The query is local — `selection own` names a window
in this application or nothing, and never makes an X round trip to a foreign
owner, which inside an event handler could block for the selection timeout.

The mirror is **not** re-asserted as `sel`: re-adding the tag would take PRIMARY
straight back off the client that just asked for it.

**The extend** (`rdw::_arm_extend` `:1873`, `rdw::pane_drag` `:1916`). The press
is compared against the standing selection in `rdw::pane_click`, which the
widget tag runs *before* the Text class binding deletes it; if it landed
**inside**, the drag's own answer is unioned with the remembered span by a
`<B1-Motion>` binding on the `.rdw` tag — the first place a binding can see what
the class binding decided. A press **outside** arms nothing and starts a fresh
selection (rows CP7 legs 4–5: without that fence the second selection grows out
of the first for ever and the user can never make a small one again).

The rejected alternative was `break` on the press plus a hand-written re-anchor,
which means writing `tk::Priv(selectMode)` and the widget's private anchor mark
from this file — Tk internals re-derived in the one binding whose comment
already records what breaking that class binding costs (`:1458-1464`).

**The keyboard-free door** (`rdw::popup_menu`, `:1845`). Measured before it
existed: `bind .rdw.p.t <Button-3>`, `bind Text <Button-3>` and
`bind all <Button-3>` were **all the empty string**. A right-click now posts
Copy / Select All. Both doors call **one** `rdw::copy`, so the guard cannot be
true of one and false of the other.

**The clipboard is never wiped, and the window says so.** DD-5's own spelling —
`clipboard clear` then `clipboard append` — with nothing to append destroys
whatever the user had on the clipboard, very likely the thing they were about to
paste the dump next to. `rdw::copy` decides first and writes second, and names
the outcome in the status line either way. A copy that quietly does nothing
cannot be told from the broken one this item exists to fix, and *"doesn't work"*
is the entire bug report. Same obligation `calc::inert` and `rdw::button` carry.

**Stale spans are dropped where the buffer is rewritten**
(`rdw::_forget_selection`, called from `rdw::render_pane` `:1494` and
`rdw::close` `:1272`). A text index never fails to resolve — Tk clamps it — so a
remembered span left standing across a repaint goes on copying, silently and
plausibly, whatever slid under those line numbers.

---

## What was rejected, and what it would have cost

`-exportselection 0` (flipping `rdw::_exportsel`) makes mechanism 2 impossible
in **one line**, because a pane that exports nothing can never lose PRIMARY. It
also ends select-then-middle-click-paste, which `rdw::_exportsel`'s own comment
calls *"the user's stated reason the window exists at all"*. Row **CP10** is
green and is the receipt for not paying that; it is deliberately not a veto.

---

## Verification

| suite | arm | before | after |
|---|---|---|---|
| `test_rdw_keys_1245` | `:99` | 5 FAILED (65 passed) | **ALL PASS (71)** |
| `test_rdw_keys_1245` | `$DISPLAY` (VcXsrv) | 11 FAILED (60 passed) | **5 FAILED (66 passed)** — see below |
| `test_rdw_window_1245` | `--nogui` | ALL PASS (134) | ALL PASS (134) |
| `test_rdw_window_1245` | `:99` | ALL PASS (146) | ALL PASS (146) |
| `test_op_param_store_1245` | `--nogui` | ALL PASS (130) | ALL PASS (130) |
| `test_op_annot` (control) | `--nogui` | ALL PASS (485) | ALL PASS (485) |

**Every CP row passes on the user's own VcXsrv server.** The five that still
fail there are section **RA** — item R4's raise — and they fail **byte-identically
at HEAD `01fdebc5` with this item's source change reverted**, so they are
pre-existing on that display and are not R3's. Filed as **1343**.

CP12 was written by the implementing crew as the input most likely to break the
fix, and its first draft was **vacuous**: pushing over a *live* selection lets
the repaint's own `delete 1.0 end` fire `<<Selection>>`, which the mirror
already listens to, so it passed with `rdw::_forget_selection` commented out of
`render_pane` (ALL PASS 71). Driven from the **post-theft** state — where `sel`
is already empty, the repaint changes nothing and no event fires — it reds
correctly, handing the user `MCU:/` from the *new* block off a span into the
old one.

**Status: FIXED.**

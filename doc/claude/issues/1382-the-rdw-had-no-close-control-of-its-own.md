# 1382 — the Results Display Window had no close control of its own

**Branch** `fluid-editing`. **File** `src/rdw.tcl`. **Suite**
`tests/headless/test_rdw_window_1245.tcl` section **CB**.
**Batch** `doc/claude/rdw_ux_batch/CREW_BRIEF.md`, item A.

## The request

The user, 2026-09-07, verbatim:

> In the RDW, add a Close button to dismiss the window

## What was already true, and it is sharper than "there was no button"

**Ruling DD-12 had already promised this control and the column did not carry
it.** DD-12 (`doc/claude/op_param_batch/DECISIONS.md:411`) rules that Escape
ends a running pick and **never** closes the window, and it states its own cost
in as many words:

> *Cost, stated:* a user who expects Escape to dismiss the window will press it
> and see nothing happen. **The window has its own close control**, and the
> dumps are worth more than the keystroke.

The only close control this window had was the window MANAGER's `X` — chrome,
not part of the window, absent from a screenshot of the widget, and the first
thing an embedded or undecorated toplevel loses. So the consolation offered for
a deliberately inert keystroke named a control this file had never built. That
is the defect; the button is the repair.

⚠ **THE CREW BRIEF FOR THIS ITEM SAID "Escape already closes under ruling
DD-12". IT DOES NOT, AND THE OPPOSITE IS THE RULING.** Acting on that sentence
would have made the button "a third door on the same rule" when it is the
**second**, and — worse — it invites the next reader to make Escape close, which
DD-12 argues against at length because the dumps are the artifact the feature
exists to produce. Row **CB2** now reds that change by arithmetic.

## What shipped

`.rdw.b.close`, a Tk `::button` labelled **Close**, `-command rdw::close`,
packed `-side bottom` **before** `.rdw.b.fontsize` and therefore **below** it —
that side fills the cavity bottom-up. The column now reads:

```
Up  Down  Delete  Add  Save        the five list actions (rdw::_buttons)
--- gap ---
aA                                 how this window renders   (issue 1368)
--- gap ---
Close                              the window itself         (issue 1382)
```

Two supporting changes, both of them one definition replacing two:

* `rdw::apply_list_state`'s greying loop walked the five ids as **literals**,
  three procs away from `rdw::_buttons`. It now walks that table, exactly as
  `rdw::_active_buttons` already did. This is what makes "Close is `normal` on
  all three identities" true **by construction** rather than by a
  `rdw::button_state` row nothing would read.
* `rdw::button`'s unknown-id refusal said *"There is no button called '$id' in
  this window."* — a false statement on a screen the user is reading, since
  `aA` landed. It now says *"'$id' is not one of this window's list buttons."*

## The decisions this request did not settle — rule debt 1382

**A. Where in the column.** SHIPPED: the **foot**, below `aA`.
*Alternatives:* (b) directly under Save with a gap — rejected, it puts the
dismiss control against the one other press whose consequence outlives the
click; (c) between Save and `aA` — rejected, it makes `aA`, a rendering
convenience, the terminal control of the column; (d) a title-bar-only close (the
status quo) — rejected by the request. The shipped order reads by **widening
scope**: a row of a list → this window's rendering → the window. A misclick
costs nothing, which is the survival rule doing its second job.

**B. No `rdw::button close`.** SHIPPED: the command path is `rdw::close`
itself. *Alternative:* an entry in `rdw::_buttons` plus an arm in `rdw::button`,
so the id is reachable the way the five list actions are. Rejected for three
reasons: `rdw::close` is a public name that **predates** the button and that the
`WM_DELETE_WINDOW` protocol already uses, so a second name would be a second
answer to "how is this window dismissed" (invariant I1) with no gesture behind
it; an entry in `rdw::_buttons` would put "Close" into
`rdw::_active_phrase`'s sentence *"only Up, Down, Delete, Add and Save do
anything"*, a list-action claim about a window action; and `rdw::button`'s own
stated obligation — *"every path out of here ends in a status line that names
the button it came from"* — **cannot** be kept by an arm that destroys the
widget the status line lives in. `aA` is the precedent, not an exception: every
button's command is a named `rdw::` proc, and only the LIST ACTIONS go through
`rdw::button`.

**C. Close writes no status line, and no confirmation is asked.** The window
vanishing is the feedback, and the dumps survive, so there is nothing to warn
about. Stated, not ratified.

**E. Close does not end a running pick — added by the repair pass.** SHIPPED:
the mode outlives the window. *Alternative:* end it, which can only be done
inside `rdw::close` so that the button and the window manager's `X` keep
agreeing (invariant I1). Rejected because it is ruling **DD-12**'s asymmetry
read the other way round — Escape ends the MODE and never closes the window, so
Close closes the WINDOW and never ends the mode, one gesture one job — and
because the mode is recoverable by its own documented exit (ESC on the canvas)
and the next click reopens this window through `rdw::show`. ⚠ **The cost,
stated:** a user who presses Close mid-pick still has a seized canvas, so the
next click dumps instead of selecting.

⚠ **THIS COST WAS OVERSTATED WHEN IT WAS WRITTEN, AND THE ITEM BESIDE IT IS WHY.**
The sentence above originally ended *"The CIW sentence the mode printed says 'ESC
ends', and nothing on screen repeats it once the window is gone."* That was true
of item A alone and was false by the time the batch landed: **item B** (issue
1384) puts the mode's own sentence on the schematic status bar, where it stays
after the window is gone and blanks on ESC. MEASURED on `:99`, a real
`.rdw.b.close invoke` with a pick live: `.statusbar.10` still reads *"Click on
instance for annotation OP info in Results Display Window"* 300 ms after the
window is destroyed, and reads empty after ESC. So the accurate cost is
narrower: **the sheet keeps telling you the mode is running and which list it is
for — no surface tells you that ESC is what ends it.**

Recorded here rather than quietly amended because the user is being asked to
ratify decision E, and ratifying a cost that the item next to it had already
softened would be asking them to rule on a fact that is not true. Two items
landing in one batch is exactly how a stated cost goes stale.

**F. The chrome sentence is not reworded.** *"only Add and Save do anything
here"* is read over a column of seven controls, four of which do something. It
is a claim about the LIST ACTIONS, which is the user's own question — *which of
these will do something to THIS list* — but it has been looser prose than it
looks since `aA` landed in issue 1368, and Close is the second non-list control.
*Alternative:* say "only Add and Save act on this list", which is exact and
which no row golds by its old wording. Not shipped: it is user-facing copy, the
user has already ruled on this line once (issue 1355), and the looseness is not
this item's to spend their attention on unasked.

**D. The reworded refusal.** *"'close' is not one of this window's list
buttons."* keeps the id (so a real typo is still legible) and stops denying a
visible button. It does not enumerate the five — terse. The rejected
alternative was to name them, which re-states `rdw::_buttons` in prose.

## The row a future "cleanup" would break, and why it is written twice

`rdw::close` is a **withdraw**, not a discard: `::rdw::blocks` is namespace
state and the proc touches it not at all. That is what lets ruling **DD-16** edit
a block an hour later on a different sheet, and `rdw::close`'s own comment has
recorded it since item B3. A reader who reads `close` as `discard` and adds one
`set blocks {}` destroys the artifact the feature exists to produce, and nothing
else in the file would notice. So it is fenced twice:

* **CB3** (both arms) — the source: `rdw::close` names `blocks` nowhere, unsets
  nothing, and `rdw::open` names it nowhere either.
* **CB6** (`:99`) — the behaviour: two real dumps, a real `.rdw.b.close invoke`,
  the toplevel really gone, `::rdw::blocks` byte-for-byte identical across it,
  a reopen painting the **same** pane text. ⚠ Its two `rw_has` legs are load
  bearing: without them "the text is byte-identical" passes when **both** texts
  are empty, which is exactly the state a `set blocks {}` would leave behind.

## THE REPAIR PASS — WHAT THE FIRST PASS BROKE, AND WHAT IT OVERCLAIMED

An adversary could not break the button and broke **the column it sits in**.
Three findings, all three acted on.

### 1 (major, FIXED) — the window's own minimum size stopped fitting its column

`wm minsize .rdw 520 260` (one line, no comment, no spec entry, no test row) was
written for item **B3**'s five-button column and re-judged never. Take the
header (21 + 4 pad) and the status strip (27) off and that minimum leaves the
column **208 px**:

| column | `winfo reqheight .rdw.b` | at the 520×260 minimum |
|---|---|---|
| five list actions (B3) | 165 | fits, 43 px of slack |
| `+ aA` (issue 1368) | 204 | fits, **4 px** of slack — nobody noticed |
| `+ Close` (this item) | **243** | **35 px short** |

MEASURED on `:99` at exactly 520×260 with the constant still standing:

```
up y=2 h=29 mapped=1     add  y=101 h=29 mapped=1
down y=35 h=29 mapped=1  save y=134 h=29 mapped=1
delete y=68 h=29 mapped=1
fontsize y=376 h=29 mapped=0      <-- aA, UNMAPPED
close y=177 h=29 mapped=1
```

and for the ~30 px above that a 2-to-24 px sliver (h=270 → `aA` 4 px; h=290 →
24 px). ⚠ **The item's own ordering decision chose the victim**: `-side bottom`
allocates Close FIRST, so the packer starves `aA` — the control the user asked
for by name — and never Close. An ordinary drag of the window's bottom edge
reaches it. Every earlier measurement of this column was taken at the default
893×498, where 446 px of cavity hides a 243 px request, so nothing showed.

**Fixed by making the minimum a function of the column**, not by nudging the
constant. `rdw::min_floor` keeps B3's `520 260` as a floor; `rdw::apply_minsize`
raises the height to

```
winfo reqheight .rdw  -  winfo reqheight .rdw.p  +  winfo reqheight .rdw.b
```

— the toplevel's own request with the pane swapped for the column. `.rdw.b` and
`.rdw.p` share one row and the pane is always the taller (446 against 243), so
that expression carries the header, the status strip and every pad exactly once
and models the packer nowhere. MEASURED 498 − 446 + 243 = **295**, and 295 is to
the pixel the first height at which `winfo height .rdw.b` reaches its own
request (294 → `aA` 28 px, still clipped).

This is `calc::min_floor` / `calc::apply_minsize`'s shape
(`src/calculator.tcl:259`), which this tree adopted for **exactly** this defect:
*"Phase 0 wrote `wm minsize .calc 560 620` against empty placeholder panes;
phase 1b then put a 614 px selector grid in, and at the window's OWN declared
minimum the grid overflowed its pane by 66 px."* Same failure, same repair.

⚠ **WHY IT IS CALLED TWICE.** `winfo reqheight` on a frame is set by the packer
in an **idle handler** — MEASURED: immediately after packing seven buttons the
frame still answers `1`, and `243` only after `update idletasks`. So the call at
the head of `rdw::build` sets the floor while `.rdw.b` does not yet exist (no
pump, nothing to measure), and the call at the foot — after `rdw::_apply_font`,
the one setter of the pane's character shape — is the one that measures. Pumping
earlier would map the pane at TkFixedFont size 10, which is the trap that proc's
own comment records.

### 2 (minor, FIXED) — two comments the change invalidated

* `rdw::_focus_click`'s header enumerated the column exhaustively — *"one
  binding covers the pane, the status surface, the five buttons, the `aA`
  button and the frame"* — and that was complete until Close landed.
* Its sibling in `rdw::build` said *"the pane, all five buttons, the status
  entry and the toplevel"*, which was already stale from issue 1368 **and** from
  item 1355, when `.rdw.s.msg` stopped being an `entry`.

Both now name the real widget set, and the second records why an enumeration
that names widgets has to be re-read every time one is added.

### 3 (minor, FIXED) — two comments that asserted more than the code does

**(a) "A misclick here costs nothing at all"** was one word too strong.
MEASURED on `:99`: with a pick live, a real `.rdw.b.close invoke` leaves
`.rdw` destroyed, `rdw::pick_running` **1**, `bind .drw <ButtonPress-1>` still
`rdw::pick_click; break` and `bind .drw <Key-Escape>` still `rdw::pick_end;
break`. It costs no **dumps** — which is the claim that matters and which CB3
and CB6 fence — but the canvas seize outlives the window.

The behaviour is **kept**, and is now a stated contract (decision E below)
rather than an accident of where the seize is bound: rows **CB8** (source) and
**CB10** (a real press, a real seize).

**(b) The chrome sentence** *"only Add and Save do anything here"* is read over
a column of seven controls, four of which do something. That looseness started
with `aA` in 1368, not here. `rdw::_active_phrase`'s header now says in as many
words that it is a claim about the LIST ACTIONS and not about the column, and
the copy is recorded as the user's to rule on (decision F below) rather than
quietly reworded.

## Rows added — section CB, floor 187 → 191 → 193

| row | arm | what it asserts |
|---|---|---|
| CB1 | both | one `.rdw.b.close`, `-text Close`, `-command rdw::close`, packed `-side bottom` **before** `aA`; `close` absent from `rdw::_buttons` and from all three chrome sentences; the greying loop walks that one table and never names this widget |
| CB2 | both | the WM protocol and the button's `-command` are the same proc; `rdw::close` occurs **exactly twice** in the whole builder; `catch {destroy .rdw}` occurs once in the whole file; `<Key-Escape>` still ends the pick (DD-12) |
| CB3 | both | the withdraw contract at source (above) |
| CB4 | both | `rdw::button close` refuses, changes nothing, and no longer denies a visible button — asserted for `fontsize` too |
| CB5 | `:99` | the live widget: mapped Button, `Close`, in `.rdw.b`, side `bottom`, **below** `aA` which is below Save, `-state normal` on all three identities, `-command` equal to the live `wm protocol` string |
| CB6 | `:99` | the press and the survival (above) |
| CB7 | both | `wm minsize` occurs **once** in the whole file and that once is inside `rdw::apply_minsize`; it derives from `.rdw.b` and `.rdw.p`; `rdw::build` names no literal minimum and calls the proc twice, the first call before `frame .rdw.b` and the second after `rdw::_apply_font`; `rdw::min_floor` still answers B3's `520 260` |
| CB8 | both | `rdw::close` names the pick nowhere, and the mode's exit stays where `rdw::_pick_seize` put it — on the canvas's own `<Key-Escape>` |
| CB9 | `:99` | shrink the real toplevel to the `wm minsize` **it published for itself** (never to a number the row spells) and read all seven controls back: mapped, each at its full requested height, the column frame whole, the minimum at or above the floor and no higher than the natural first-open height |
| CB10 | `:99` | a real pick, a real press on Close: the toplevel is gone, `pick_running` is still 1, both canvas bindings intact, and `pick_end` puts the previous binding back |

## A second defect this item found: FZ17's fixture was leaning on `aA` being lowest

`FZ17` (issue 1368's tooltip clamp) parked the **toplevel's** bottom edge on the
screen's and expected a `pos 1` tip on `.rdw.b.fontsize` to flip **above** the
widget. That forced the clamp only for as long as `aA` happened to be the lowest
widget in the column. Packing Close below it raised `aA` by a button and a gap,
the tip no longer needed to flip, and **FZ17 went red with `balloon_show`
untouched** — a row passing for an unstated reason, which is the named defect in
this suite's own preamble. Fixed at the fixture, not at the column: the new
`fz_park_bottom` puts the **button's** bottom edge on the screen's (two steps,
because `wm geometry` addresses the window frame while `winfo rooty` reads the
client area), so both FZ17 and FZ18's bottom case are forced by measurement
whatever the column is made of.

## Measured — after the repair pass

```
test_rdw_window_1245  --nogui        204 checks, ALL PASS
test_rdw_window_1245  :99            251 checks, ALL PASS
test_rdw_keys_1245    :99             90 checks, ALL PASS   (--nogui: SKIP, by design)
test_rdw_seam_1245    :99 / --nogui   49 /  49 checks, ALL PASS
test_op_param_store_1245 :99/--nogui 142 / 142 checks, ALL PASS
test_op_annot         :99 / --nogui  492 / 485 checks, ALL PASS
test_annot_declutter_1244 :99        134 checks, ALL PASS   (control; Tk-only suite)
test_ase_dialogs      :99            176 checks, ALL PASS
test_ase_final        :99             82 checks, ALL PASS
test_wave_split_strip :99            221 checks, ALL PASS
```

`RW_FLOOR` 187 → 191 → **193** (CB1–CB4, CB7 and CB8 run on the `--nogui` arm;
CB5, CB6, CB9 and CB10 are `live_tk`-gated and deliberately uncounted).

### The `:0` run — PAID, and it found a pre-existing red that is not this item's

`GUI_GATE=0 DISPLAY=:0` (Xwayland, **not** the user's screen — see CLAUDE.md's
three-server table), five runs:

```
run 1   3 FAILED (248 passed)   SL8  FZ11  FZ17
run 2   3 FAILED (248 passed)   SL8  FZ11  FZ17
run 3   3 FAILED (248 passed)   SL8  FZ11  FZ17
run 4   4 FAILED               SL8  FZ11  FZ14  FZ17
run 5   ALL PASS (204 checks)   <-- the :0 CLIENT DIED and the suite fell back
                                    to its headless arm; the 204 is the --nogui
                                    count, not a :0 pass
```

**All ten CB rows pass on `:0`.** The three standing reds are pre-existing
Xwayland behaviour, and that was **proved, not assumed** — `git show HEAD:` for
BOTH `src/rdw.tcl` and the suite, so this issue is entirely out of the tree:

```
HEAD  :99   ALL PASS (241 checks)
HEAD  :0    4 FAILED (237 passed)   SL8 FZ11 FZ17 FZ18     (run 1)
HEAD  :0    4 FAILED (237 passed)   SL8 FZ11 FZ17 FZ18     (run 2)
```

The four are there with no Close button in the tree at all. This issue adds
none of them and, incidentally, **removes one**: `fz_park_bottom` parking the
BUTTON's bottom edge rather than the window's is what makes FZ18 pass on `:0`.
A narrower control confirms the same thing from the other side — with **only**
the minsize repair reverted, the same `:0` run gives those four **plus** CB7 and
CB9, which is the two new rows doing their job.

Filed as issue **1383** so it is not re-derived a fourth time (this tree filed
0689 four times and 0690 four times while everybody waved the same count
through); the `test_rdw_window_1245` suite debt now points there rather than
here. ⚠ **The `:0` arm is not trustworthy on its own here**: run 5 shows a
client abort producing a green line with the wrong check count — 204, the
`--nogui` count — which is the WSLg instability CLAUDE.md records.

**NOT** done: a human eyeball, which is what the look debt below is for.

## Debts

* **rule 1382** — decisions A, B, C and D above.
* **rule 1382_repair** — decisions E and F, added by the repair pass. Also
  records, for information rather than ruling, that the minimum size is now
  derived from the column.
* **look** `rdw_close_button_column` — seven controls in one column, two gaps
  and the word "Close"; only the user's eyes can say whether the column now
  reads crowded and whether Close belongs at the foot. **Still standing.** A
  green suite is not an eyeball, and the repair pass changed nothing the eye
  can see at the default size — it changed what survives a drag of the bottom
  edge.
* **suite** `test_rdw_window_1245` — **the `:0` run is done** (ten runs,
  above), and the debt is deliberately left **standing**, re-pointed at issue
  **1383**: this suite still does not PASS on `:0`, for four reasons that are
  none of them this issue's.

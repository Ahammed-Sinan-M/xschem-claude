# 1358 — the Results Display Window cannot hear its own refresh keys

**Status: FIXED** (`src/rdw.tcl`, `rdw::_digit_map` / `rdw::_digit` and four
toplevel bindings in `rdw::build`).
Fenced by section **KB** of `tests/headless/test_rdw_window_1245.tcl`
(`RW_FLOOR` 152 -> 154) and section **KD** of
`tests/headless/test_rdw_keys_1245.tcl` (`KX_FLOOR` 85 -> 87).

## The user's words

> The delete did not have an effect (I left settings on the pop-up at default).
> Then, I tried deleting one at a time. That also did not have an effect next
> time I printed summary.

This is the third of their three symptoms and the only one issues 1300, 1355,
1356 and 1357 did not touch. It was reported as "the delete did not work"; the
delete worked perfectly.

## What was measured

Driven on the keys suite's own fixture at HEAD `2004f5e6`, with **no
`focus -force` anywhere**, deterministic 3/3:

| step | what happened |
|---|---|
| press `2` on the canvas | `[focus]` = `.drw`, one block, `listkind` = summary |
| click the parameter row | `[focus]` = `.rdw.p.t`, `::rdw::targetrow` = 5 |
| press Delete, accept defaults | `op_param_lists::effective b4dev summary` moves `{zid zgm}` -> `{zgm}`, status line says `Delete: removed zid from the summary list for class b4dev.` |
| press `2` to look | **nothing.** `nblocks` stays 1, `.rdw.p.t`'s text is byte-identical, and the pane still reads ` zid : 11.1u` |

**The keystroke is not refused, it is never heard.** The digits are bound on
the CANVAS only (`src/cadence_style_rc:181-184`). Measured on a built window:
`bind .rdw <Key-2>`, `bind .rdw.p <Key-2>`, `bind .rdw.p.t <Key-2>` and
`bind Text <Key-2>` are all the empty string, as is `bind all <Key-2>`. Tk
delivers a key event to the focus widget; it found nothing, and the user got no
block, no error and no status line.

**And the user is *told* to make the click that breaks it.** The window's own
status line reads *"click a parameter row, which shades to show it is the
target, then press Delete again"*, and `rdw::button` never calls
`rdw::_focus_canvas` or `rdw::_arm_focus_handback` — 0 occurrences at HEAD and 0
at pre-batch `79b0a0ce`, so the gap is **pre-existing**, not introduced by this
batch. It became reachable the moment the buttons became worth pressing.

**And the obvious recovery is itself a trap.** Clicking blank canvas to get the
keyboard back DESELECTS the device (`rdw::_selected_instance` goes from
`one M18` to `none {}`), so the next `2` arms the pick mode instead of dumping,
the pane still shows the deleted row, and the status line still carries the OLD
Delete verdict — so there is no new feedback either. Nothing on screen says the
user must click the device again first.

## Why the earlier passes called it dead

Every probe that "confirmed" the delete was visible did
`focus -force .drw` immediately before its `event generate .drw <Key-2>`, which
is precisely the step a user's hand does not make. So does this suite's own
`kn_press` and `lk_press` — correctly, because *their* subject is the canvas
binding. Row **KD1** therefore presses the digit at `[focus]` and asserts, as a
leg, that `[focus]` really is `.rdw.p.t`.

## The fix, and the alternative that was rejected

`rdw::build` now binds the four bare digits on the **toplevel tag** `.rdw`,
which is in the bindtag chain of the pane, all five buttons and the status
entry. This file has answered the same question twice already and both times on
that tag: `<Key-Escape>` (issue 1308, ruling DD-12) — whose own comment names
*"the command mode's `1`/`2`/`3`/`4` and `<Key-Escape>`"* in one breath and then
takes only the Escape — and the copy chord (item R3, issue 1339, ruling DD-5),
whose comment records that *"no amount of re-binding the pane would have reached
it"*. The digits are the half that was left behind.

**REJECTED: hand the keyboard back to the canvas from `rdw::button`'s arms.**
Two measured reasons.
1. It fixes only the gesture that goes through a BUTTON. A click on a row
   followed by a bare `2` — no button at all — is still swallowed. Measured:
   pre-fix CASE A, `nblocks` 1 -> 1.
2. It re-creates ruling DD-5's own defect. Seven of `rdw::button`'s arms are
   refusals that repaint nothing, so the pane's selection survives them; a
   `Ctrl-C` after a refused press would then reach `.drw` and copy SCHEMATIC
   OBJECTS instead of the block the user selected. This window exists to have
   its text pasted into a design review.

Row **KD1** golds the shipped behaviour (`$KD1_WHERE` = `.rdw.p.t` after the
Delete), so a future pass that decides to move the keyboard has to re-take that
decision in the open.

**The mask is the profile's, not a new one.** `0x4c` =
Control|Mod1(Alt)|Mod4(Super), with Lock and NumLock deliberately outside it,
exactly as `cadence_style_rc:181-184` discriminates. This window has nothing to
forward a chord TO, so it declines and lets the event fall through.

**The map is duplicated on purpose and the duplicate is fenced.** The profile's
binding is about the canvas (it must spend modifiers the canvas already uses and
`break` to beat the C dispatcher); this one owes neither. What could drift is
which digit means which list, so `rdw::_digit_map` is the one place `rdw.tcl`
says it and row **KB1** parses *both files* and compares them.

## What was NOT done, and why

**The window does not refresh itself after a successful edit.** It was
considered and refused: every block's caption is past tense by design —
*"Narrowed to the mos summary list **as it stood at this dump**"* — and
`rdw::close`'s own comment records that the dumps are the artifact the feature
exists to produce. Re-narrowing a stored block in place would falsify that
caption; pushing a fresh block on every press would grow the store one block per
Delete. Issue 1349's re-slot is a strict PERMUTATION of rows already in the
block and changes no membership, which is why it does not have this problem.
**This is on the ledger as rule debt 1358 for the user to overrule.**

**Key 4 is bound too**, so the window's keyboard is not a subset of the
canvas's. It trims the store to the newest dump and says so in the status line;
it is the same command the canvas already offers on the same digit. Also on rule
debt 1358.

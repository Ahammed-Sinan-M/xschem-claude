# 1351 — four defects the repair round's own adversaries found: a poll that answers to any grab, a chain that outlives its arm, a give-up past its deadman, and a selection that outlives its text

**Status: FIXED** in this commit. Found by the adversaries of items **P1**
(issue 1344) and **P3** (issue 1332) in the RDW repair batch, 2026-09-05 — four
defects that every suite was green through. Subjects:
`tests/headless/test_rdw_keys_1245.tcl` (the `sd_*` modal driver, the
`KX_FLOOR`) and `src/rdw.tcl` (`rdw::status`).

## Why one number for four

They share a cause worth naming: **each is a fix's own new failure mode, and
each was invisible to the rows that shipped with the fix.** Issue 1332 replaced
a fixed `after 100` with a poll and introduced three; issue 1344 gave the window
one honest copy path and introduced one. The repair round's whole point was
that green suites had already let four defects through; these are the same
lesson one turn later, which is why they are recorded together rather than
scattered.

## A — the floor had three rows of slack

`KX_FLOOR` is the guard that turns "the suite silently ran fewer rows" into a
red. Issue 1332's fix added SD5, SD6 and SD7 and **did not raise it** — the one
commit in this file's history not to. Measured: with the three new `check` calls
routed to a no-op, the suite printed `RESULT: ALL PASS (74 checks)` and the
floor said nothing. The three rows it could no longer see were the three that
fence issue 1332 itself.

Raised 74 → 77, and then 77 → 80 for the rows below, and 80 → 81 for CP16.

## B — the poll answered to a grab belonging to any window

`sd_poll_modal` waited on `[winfo exists .rdw.scope] && [grab current] ne {}`.
`grab current` with no window argument answers for **every** grab this
application holds, so the "exact pair" the comment describes was not exact. The
comment's justification — "a driver that sees a grab is running from inside
`tkwait` on a dialog that is fully modal and already holds the keyboard" — is
true only of the **dialog's** grab.

Driven: one unrelated `catch {grab set .rdw}` with the shape-B delay installed
makes the poll fire during the build's own `update`, focus still on `.drw`,
reding SD2 exactly as the old fixed timer did. No product path to a foreign grab
was found today, so this was latent, not shipped harm.

Fixed: `[grab current] eq {.rdw.scope}`. Fenced by **SD8**.

## C — arming again orphaned the chain it replaced

`sd_arm` set `::SD_POLL_ID {}` and overwrote `::SD_DEADMAN` **without
cancelling either predecessor**, so a second arm threw the first chain's handles
away while the chain itself kept running — beyond any reach of `sd_disarm`.

Under the old fixed `after 100` a stray timer was a one-shot that fired once
within 100 ms and almost certainly inside its own row. A poll is a
self-re-arming chain that lives seconds, i.e. **across rows**, and it presses
buttons on whatever dialog a later row puts up. That is a stronger form of the
very flake this section was written to remove, introduced by the fix for it.

Driven: one extra `sd_arm` before SD2's own, with no dialog in that row and no
disarm, reds SD2.

Fixed: `sd_arm` calls `sd_disarm` as its first statement. Fenced by **SD9**.

## D — the give-up was a poll count that ran past its own deadman

The section comment called the budget "900 × 5 ms = 4.5 s, deliberately INSIDE
the 5 s deadman". `after 5` is a **floor**, not a period. Measured by
instrumenting a full 900-poll give-up: 4856 / 4868 / 4986 ms at load average
~25, and 6028 / 6403 / 6524 ms at load average ~54 — **1.0 to 1.5 s past the
deadman it was claimed to sit inside**, under exactly the contention the poll
exists for. A give-up that arrives after the deadman is defect C wearing a
budget.

Fixed: `sd_arm` stamps `::SD_DEADLINE` at `deadman - 500` ms and the poll stops
on whichever limit comes first. A small budget still gives up on its poll count,
which is what SD7A asserts. Fenced by **SD10**.

## E — a selection that outlived the text it was made of

An entry's selection is a pair of **indices**, not a hold on the characters.
`rdw::status` replaces `::rdw::statusmsg`, the `-textvariable` of `.rdw.s.msg`,
and the range survived that rewrite verbatim — so it came to cover a slice of
the **new** sentence, text the user had never selected.

Driven, in two presses of the chord item R3 added: the line reads
`alpha    beta`; the user selects the four spaces (a double-click on the gap
does exactly this); Ctrl-C is refused, because a whitespace-only span is not
worth copying — and the refusal is deliberately **not** routed through
`rdw::_copy_report`, so it replaces the line. Range 5–9 now covers ` is ` of the
refusal sentence, and a second Ctrl-C copies ` is ` to the clipboard
**silently**, because the source is still that entry. That is item R3's own
quoted defect class — "silently handed you the wrong text" — reached in two
presses of the chord R3 added.

Fixed at the single emit point, `rdw::status`, for `rdw::_oneline`'s own reason
(the eleventh call site is the one the next author forgets), and **only when the
text actually changes** — a line reset to what it already said has invalidated
no index. Fenced by **CP16**, whose last leg is that fence.

## What is NOT fixed here

The adversaries' other findings need a **ruling**, not a patch, and are in the
user's queue as look debts rather than guessed at:

- the status line's receipt goes **stale** rather than silent after a copy from
  that entry (`1344_the_status_line_receipt_goes_stale`);
- two selection-coloured regions can stand in one window at once, and the pane's
  highlight can disagree with what Ctrl-C copies
  (`1344_two_highlights_after_a_status_line_drag`);
- `bind Entry <<Copy>>` is a second door on the status entry, so a copy from
  there runs twice — invisible except in the refusal case;
- the pane's context menu can act on a selection standing in another widget;
- item R4's raise on the user's own VcXsrv is issue **1343**, untouched.

## Verification

`tests/headless/test_rdw_keys_1245.tcl`, `:99` via `devdisplay.sh exec`,
`GUI_GATE=0`: `RESULT: ALL PASS (81 checks)`, three consecutive runs. On the
user's own VcXsrv (`$DISPLAY 172.20.160.1:0`, vendor `HC-Consult`):
`RESULT: 5 FAILED (76 passed)`, and the five are RA1–RA5 — issue **1343**, not
this one. All eleven SD rows and all seventeen CP rows pass on both servers.

**Four sabotages, each caught by exactly the row that claims it**, each applied
to the repo file and restored by `cp` from a gold copy with the md5 verified
afterwards (`9d9d5f2090343ff10faebb55c70ed9fc` for the suite,
`17339010560a05d7e57d0e972b61bccf` for `src/rdw.tcl`), `git status --short`
empty after each:

| sabotage | result |
|---|---|
| `[grab current] ne {}` restored | `1 FAILED (79 passed)` — **SD8** |
| `sd_disarm` removed from `sd_arm`'s head | `1 FAILED (79 passed)` — **SD9** |
| give-up reverted to a poll count only | `1 FAILED (79 passed)` — **SD10** |
| the selection-clear removed from `rdw::status` | `1 FAILED (80 passed)` — **CP16** |

Unmoved, every one asserted to have printed a RESULT line:
`test_rdw_window_1245` ALL PASS (145 `--nogui`, 157 on `:99`),
`test_op_param_store_1245` ALL PASS (130), `test_op_annot` ALL PASS (485).

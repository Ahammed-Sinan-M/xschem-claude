# 1300 — the RDW's keys 1, 2 and 3 select a list IDENTITY and narrow no CONTENT

**Status: FIXED, 2026-09-05.** Found by item **B4** while implementing the keys;
answered by the fix recorded in issue **1353**. Keys 1 and 2 now narrow CONTENT
as well as identity, from `::op_param_lists::effective` reached through item
R2's `rdw::_list_params`, and key 3 is untouched. **Measured on the user's own
`M18:/x1/x1`: 88 rows before, 6 after; key 3 still 88; the three blocks now
pairwise different (469 / 466 / 1939 characters) where they were byte-identical
at 1939.** Fenced by section **NW** of `tests/headless/test_rdw_window_1245.tcl`
(ten rows, both arms) and section **KN** of `test_rdw_keys_1245.tcl` (two rows,
real keybindings), every one proved by a sabotage that reds it.

> ⚠ **THE `[1300]` LEDGER ROW STAYS OPEN, AND THAT IS NOT AN OVERSIGHT.** It
> carries two *other* ratifications that this fix does not touch — the refusal
> split (`src/rdw.tcl:1292` / `:1295`) and the un-snapped-mouse refusal — and a
> rule debt clears only when the user says so. The four decisions THIS fix took
> on the user's behalf are on the separate rule debt **1353**, minted rather
> than folded in because `owed.sh add rule` is deduped by id and would have
> overwritten the text above.

**⚠ THE QUESTION BELOW WAS ANSWERED BY THE FIX, NOT BY THE USER.** Everything
from here down is the record of how the question stood; issue 1353 records which
option was taken and why, and the user may still overrule it.

> **⚠ ITEM B4 WAS REVERTED (status F, 2026-09-04)** on issues **1303**, **1304**
> and the two holes in `PLAN.md`'s B4 table. The keys described below are
> therefore **not in the tree**; they are in
> `doc/claude/op_param_batch/B4_working_tree_REVERTED.patch`. **The question
> this issue asks is unaffected by the revert** — it is about what keys 1, 2
> and 3 should MEAN, and the next crew to apply that patch inherits it
> unchanged.

## What was measured

`src/rdw.tcl` at `724c4160`..`735ea26e` renders a block from
`rdw::format_answer ans ctx`. **`format_answer` takes no list argument at all**,
and the file names the list store nowhere — row **S1** of
`tests/headless/test_rdw_window_1245.tcl` is a hard structural fence that
forbids the token in this file. So keys 1, 2 and 3 as shipped by B4 produce
**byte-identical blocks**; the only thing that differs is `::rdw::listkind`
(and therefore the button greying that reads it).

The spec's B4 table (`doc/claude/specs/op_param_lists.md` §4.2) says key 1 shows
the descriptor's annotation list, key 2 the summary list and key 3 everything —
i.e. **content narrowing**. No item in `doc/claude/op_param_batch/PLAN.md` owns
that work: B4's Do cell does not mention it and B5's Do cell is buttons and
scope dialogs.

## Why B4 did not take it

Ladder L1, invariant **I1** — one builder, several consumers. The narrowing has
exactly one definition in this tree today: the list store's `effective`, plus
ruling **DD-6**'s display key that item B2b built. Three options were costed:

* **(a) filter inside `rdw.tcl` from `op_annot::descriptor`'s `params`** — no
  fence violation, but a **second** definition of "the annotation list" beside
  DD-6's, which is precisely the silent drift I1 exists to prevent.
* **(b) call the list store's `effective`** — reds row S1 and inherits issue
  **1278**'s unbounded-glob freeze on a path a key press reaches.
* **(c) print a `list: annotation` label in the block** — worse than silence: a
  label naming a list whose content is identical for all three *implies* a
  narrowing that did not happen. That is the DD-1 failure shape.

**Taken: none of them.** The keys select the identity through `rdw::set_list`,
which is what PLAN's B3 section already requires of B4, and the narrowing waits
for the item that owns the store.

## The question for the user

Should key 1 / key 2 narrow what the block PRINTS, and if so, does that
narrowing come from `op_param_lists::effective` (one definition, but reds S1
and needs 1278 fixed first) or from the DD-6 `shown` key the sheet already
draws from?

## Where it should be fixed

Item **B5**, which is the first item allowed to touch the list store, or a new
item after 1278 is closed. Row **K11** of `test_rdw_window_1245.tcl` pins
today's answer (zero occurrences of the store's namespace in `src/rdw.tcl`), so
whichever way this is ruled, the fix reds that row rather than passing in
silence.

> ⚠ **BOTH SENTENCES ABOVE WERE STALE BY THE TIME THE FIX CAME, AND THE SECOND
> ONE MATTERS.** Row **K11** no longer counts the store's namespace at zero —
> item B5 wired the button column and the term moved to row **BT22**, which
> allows the store's thirteen PUBLISHED verbs by name (`effective` among them)
> and golds `op_param_lists::_` at zero instead. `src/rdw.tcl` already had ten
> `effective` call sites before this fix, so option **(b) reds no row**, and
> the fix did not have to move a fence to land. Issue **1278**'s glob freeze is
> also not a blocker: `rdw::_edit` already reaches `effective` from a button
> press, so this widens the exposure from a click to a keystroke rather than
> introducing it, and `governs` evaluates no user glob at all on a settings
> file with no flavor rows. 1278 is still open and should still be fixed.

---

## UPDATE, 2026-09-04 — the keys are still not in the tree, and this ruling gains a THIRD sentence to judge

Items **B4** and **B4-2** were both refuted and reverted, so **nothing above is
running code**: `src/rdw.tcl` and `src/cadence_style_rc` are byte-identical to
`735ea26e`, bare `1`-`4` still reach C's `logic_set`, and this ruling is owed
against the preserved patch
(`doc/claude/op_param_batch/B4-2_working_tree_REVERTED.patch`), not against
behaviour the user can go and press.

**B4-2 proposes a third sentence on the same CIW channel**, and it is the only
one a user should never see:

> Results window: this build cannot report the un-snapped mouse position, so a
> click cannot be resolved to the device under the cursor - press ESC to leave.

It fires only when `xschem get mousex` / `mousey` are missing — a Tcl half newer
than the binary. **The choice was to REFUSE rather than fall back to the
grid-snapped pair**, under invariant **I3**, because that fallback *is* issue
**1303**: measured on the shipped `cmos_inv.sch`, `175.175 -199.612 → M1` and
`180 -200 → R1`, with 0.5% of a whole-sheet sweep naming a different device
silently. **Ratify the refusal, or say it should fall back and be wrong
quietly.**

No new debt id was minted for it; it is on this one. Rule debt **1300**.

## UPDATE, 2026-09-04 (later) — item **B4-3 LANDED**, so this is owed against RUNNING CODE

The keys are in the tree. Everything this file asks the user to ratify is now
something they can go and press: bare `1`/`2`/`3`/`4` on the canvas, **cadence
profile only** (ruling **D-2**), keys 1/2/3 selecting a **list identity** and
rendering byte-identical blocks (no content narrowing), key 4 clearing to the
most recent dump.

**⚠ CORRECTION to the section above: it is not "a third sentence".** The CIW
channel carries **FIVE** literals — `src/rdw.tcl:1292`, `:1295`, `:1451`,
`:1493`, `:1498` — plus one `format` template at `:1099`. Four came from B4, one
(the un-snapped refusal, now at `:1493`) from B4-2. **No fourth sentence was
invented by B4-3**, and none should be: the brief for B4-3 said "do not invent a
fourth", and the count in the paragraph above is simply wrong about the channel,
not about the sentence.

The un-snapped refusal ships **verbatim as quoted above**, at `src/rdw.tcl:1493`.

The owed-ledger row `[1300]` has been rewritten in place (`owed.sh add rule` is
deduped by id) to say the ruling is owed against running code rather than a
preserved patch, and to carry the same correction. **No second debt was
created.**

**Read alongside:** issue **1308**, filed by B4-3, which asks the *same* user
the *same* kind of question about the same window — whether it should hold the
keyboard at all — and must be ruled on together with this one.

---

## UPDATE, 2026-09-05 — **FIXED**, and what the fix did NOT close

The narrowing landed. `rdw::format_answer` reads a `list` and a `class` out of
its context — put there by `rdw::_list_ctx` at `rdw::dump_devpath`, THE SEAM'S
ONLY DOOR, beside the `sim` (issue 1284) and `simtype` (issue 1298) that door
already amended — and filters all three buckets by
`::op_param_lists::effective`, through item R2's existing `rdw::_list_params`.
The block is then re-slotted by `rdw::_reslot_block`, so the pane's order is the
list's order and item R2's Up/Down promise still holds.

**Option (a) stays refused** for the reason filed above. **Option (c) was
re-costed and half-taken**: the block DOES now name its list, because once the
narrowing is real a label naming it stops implying something that did not
happen. The half of (c)'s objection that does NOT lapse — a block is a record
and the store is live, so a later Delete would falsify a present-tense label —
is answered by wording it **past tense**, *"as it stood at this dump"*.

**Read alongside issue 1353**, which carries the four decisions taken on the
user's behalf and the one thing this fix does not close: on a machine with no
`op_param_lists.conf` entries an unowned SUMMARY list falls through to the PDK
seed, so keys 1 and 2 narrow to the same ROWS and differ only in the sentence
that names them. That is the user's second complaint wearing a different cause,
and it is an E question because changing the store's default would change what
the deck saves (ruling DD-4).

**Also read issue 1354**, filed from the same diagnosis: the log line that says
468 save cards were added to a deck that carries none is what sent this batch's
brief at the wrong hypothesis about why the pane "was working OK before".

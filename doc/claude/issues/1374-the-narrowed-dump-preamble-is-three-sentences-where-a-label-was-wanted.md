# 1374 — The narrowed-dump preamble is three sentences where a label was wanted

**Status:** FIXED in the working tree (not committed by this crew).
**Files:** `src/rdw.tcl`, `tests/headless/test_rdw_window_1245.tcl`,
`tests/headless/test_rdw_keys_1245.tcl`.
**Related:** 1300 / 1353 (the decisions whose wording this overrules), 1272 and
ruling DD-1 (the non-convergence fact that survived the cut), 1373 (the class
label the caption reads), 1367 / 1355 (the chrome this cut leans on), 0424
(does not apply — no new file, nothing under `src/Makefile.in` touched).

## THE USER'S WORDS, VERBATIM

> For each devices, is being printed:
>
> Not a complete list: these are the operating-point columns this run saved for
> this device, not everything the device has.
> Narrowed to the mos annotation list as it stood at this dump. 82 columns are
> not in that list and not shown; this run published 88 for this device. Press
> 3 for everything this run published.
>
> This is too verbose! Just say "annotated list" or "summary list"

## WHAT WAS MEASURED

All runs `./src/xschem` with `--logdir` into this crew's own scratch; the GUI
ones through `tests/headless/devdisplay.sh exec` on `:99` (openbox live).

**BEFORE**, in the real pane at the shipped default geometry (`.rdw.p.t` is
`-width 96 -wrap word`):

| line | chars | display lines |
|---|---|---|
| `Not a complete list: …` (`rdw::_incomplete_line`) | 121 | 2 |
| `Narrowed to the … Press 3 for everything …` (`rdw::_narrow_line`) | 190, or 226 with a non-converged withheld column | 2, or 3 |

311 characters over 2 logical lines that wrapped to **four** display lines,
sitting above **six** rows of data, re-emitted per device. Half of what the
user was reading was preamble.

**AFTER**, same widget, same fixture (88 published columns, six in the MOS
annotation list, one withheld column non-finite):

```
M18:/x1/x1
@m.x1.x1.m18
Not everything the device has - only what this run saved.
Narrowed to the MOS annotation list at this dump: 6 of 88 columns. 1 withheld did not converge.
    id  : 10u
    ...
```

57 + 95 characters, **2 logical lines, 2 display lines**. On the user's own
M18 the convergence clause is absent (`wnf == 0`), so their narrow line is 66
characters: **123 characters of preamble against 311**.

## ROOT CAUSE

Two independent note-line builders, each written to a different defensible
ruling, never costed against each other on screen. `rdw::_incomplete_line`
emits ruling DD-1's honesty flag; `rdw::_narrow_line` emits issue 1353's
narrowing decision as three more sentences; `rdw::format_answer` appends both,
in that order, on every narrowed dump. The four ⚠ comment blocks around those
procs argue at length that each clause is obligatory — and every one of those
arguments is about **which facts must appear**, not about how many words state
them. That is the whole gap: the facts are load-bearing, the prose was not, and
the user has now ruled on the prose.

A second finding sharpens it: **the DD-1 sentence's own deixis was FALSE on a
narrowed block.** "these are the operating-point columns this run saved for
this device" points at the six rows on screen while the run saved 88 — and the
very next line then corrected it. Shortening it is a repair, not only a trim.

## THE JUDGEMENT THE BRIEF ASKED FOR: THE CONVERGENCE COUNT STAYS

The brief asked whether a short form can still carry the fact that a withheld
column did not converge. It can, and it does — as a suffix built before the
branch and emitted only when `wnf > 0`. Five reasons, in order of force:

1. **It is a different kind of statement from the one the user struck out.**
   What they quoted are EXPLANATIONS — what the list is, when it was taken,
   where the rest lives. The clause is a RESULT the simulator reported.
   Cutting an explanation to a label is what was asked for; cutting a result is
   data loss.
2. **Measured, it is not what they were complaining about.** Their quoted block
   carries no such clause, because `wnf == 0` for their M18. Deleting it would
   shorten *their* screen by zero characters.
3. **The only way to carry the fact without counting it is to render the
   withheld non-converged rows**, which is strictly more verbose and was
   already refused in 1353 (the pane's length would scale with how badly the
   circuit failed).
4. **It costs 29 characters** and leaves the ordinary shape at 95 — still one
   display line at the shipped width.
5. **It cannot over-promise.** An empty `nonfinite` bucket is not proof of
   convergence (`src/save.c` turns an ASCII NaN into a confident 0 — issue
   1272, still open), so the clause's silence asserts nothing.

"Do not delete a true warning merely to be brief" is honoured by keeping it;
"do not keep a paragraph the user has rejected" is honoured by the other ~250
characters that went.

## WHAT CHANGED

`src/rdw.tcl`, three procs, all pure:

1. **`rdw::_incomplete_line`** → `Not everything the device has - only what
   this run saved.` (57 chars, 1 display line, from 121/2). The `complete`
   gate and the call-site gate are untouched, so DD-1's obligation 1 is intact,
   and the wording no longer points at rows it is not about.
2. **`rdw::_cols_are`** → `1 column` / `N columns`. The agreement moved on to
   the TOTAL and the verb went with the clause that carried it. One caller,
   `rdw::_narrow_line`.
3. **`rdw::_narrow_line`** → one sentence, built once:

   ```tcl
   set nf {}
   if {$wnf > 0} { set nf " $wnf withheld did not converge." }
   set kept [expr {$total - $withheld}]
   set what "$kept of [rdw::_cols_are $total]"
   if {$norder == 0} { set what "empty, $what" }
   set out "Narrowed to the $name at this dump: $what.$nf"
   if {$kept == 0} { append out " Press 3 for all $total." }
   ```

   * **THREE ARMS BECAME ONE.** `withheld == 0` said "Every column this run
     published for this device is in that list" in 122 characters; `6 of 6
     columns` is the same fact in the general shape. One arm fewer is one place
     fewer for the arm-specific omission issue 1360 found (row NW12).
   * **`Narrowed to the` is kept** — it supplies the sentence-initial capital
     that the store's own list name cannot, and auto-capitalising the name
     would print `Mos`, a head-on collision with issue 1373.
   * **`at this dump` is kept**, four words, because it is the whole of what
     makes a standing block's caption true after a later Delete (1353's
     decision 3). Dropping it re-opens issue 1300's option-(c) objection.
   * **`Press 3` survives exactly where the block has NO ROWS** (`kept == 0`),
     which covers both the empty list and a non-empty list that declares
     columns this run never published — the second of which the old empty-list
     arm never reached. Where there are rows, the counts already say rows were
     withheld and the chrome's head reads `Keys 1/2/3: <list>`.
   * **`empty,` is the one word that still tells the two no-row cases apart.**
     An empty list is fixed in the settings file; a list whose columns this run
     did not publish is not.
4. **`rdw::_narrowed_list` is NOT touched** — issue 1373 owns the class word's
   spelling and this caption reads it through that builder rather than minting
   a second one.
5. **`rdw::format_answer` is structurally unchanged**: still two note lines,
   DD-1's (about the RUN) first and the narrowing (about the DISPLAY) second.
   They are not merged, because `complete` is data from the seam and a backend
   that answers `complete 1` must make the first line vanish while the second
   stays.

Comment blocks rewritten because this change falsified them: the DD-1
obligation block, `_cols_are`'s specimen line, all five ⚠ paragraphs around
`_narrow_line` (every decision survives; the specimens and the arm count did
not), the list-identity block at `rdw::_list_name`'s head that re-quoted "as it
stood at this dump", the pane's `-wrap word` comment and `_paint_cursor`'s
parenthetical — the last two named the incompleteness sentence as the thing
that wraps, and at 57 characters it does not. The five silences still do.

## WHICH ROWS FENCE IT

`tests/headless/test_rdw_window_1245.tcl` — **three new rows**, `RW_FLOOR`
**181 → 184**:

* **NW14** — the label's CAP in characters against the pane's own requested
  `-width` (asserted through `rdw::_pane_chars`'s own `set W 96`, so moving
  the pane's width reds the row instead of leaving a cap that fences nothing),
  the five struck-out phrases asserted gone from EVERY shape the builder can
  produce, and the whole preamble asserted at two note lines each inside the
  width. This is the row that reds if the sentence GROWS BACK.
* **NW15** — the one clause that survived the cut: present iff `wnf > 0`, in
  BOTH the rows arm and the no-rows arm, scaling with the count, and built in
  exactly one place. A row set that only measured brevity would grade the
  deletion of this clause a PASS.
* **NW16** — the key-3 pointer's one rule: absent when the block has rows,
  present in BOTH ways a block ends up with none, and the two still told apart.

Re-spelled, not added (a re-spelling moves no count): `RW_INC` (one variable
consumed by 39 rows), `NW_NARROW1`, `NW_NARROW2`, NW4's three legs, NW6's two
probes, `nw_note`'s dispatcher (both arms now open `Narrowed to the`, so its
second pattern had no sentence left to match), NW11, NW12, NW13, and KN1 / KN2
of `tests/headless/test_rdw_keys_1245.tcl` (no new row there; `KX_FLOOR` stays
at **90**).

**One consequential fixture repair.** `cu_block` and `cp_block` of the keys
suite relied on DD-1's 121-character sentence to give line 3 a real WRAP: rows
CU11 (a wrapped line is shaded whole) and CP1 (the control the whole copy
section stands on) assert it, and CP6/CP7 drag between columns 10 and 60 of it.
At 57 characters line 3 stopped wrapping, CU11 and CP1 went red and CP6/CP7
were dragging past the end of the line. The pane is still `-wrap word` and the
long sentences still wrap, so both fixtures now carry ruling DD-5's analysis
sentence (~236 chars) instead — `simtype dc` raises it and `complete 1` drops
the incompleteness line, which is six lines again with a long note on line 3.
Deleting the wrap would have left CU11 and CP1 passing over a fixture that
cannot fail them.

## NON-VACUITY — EIGHT SABOTAGES, RED SETS BY NAME

Each applied to `src/rdw.tcl` alone, suite re-run, then restored by `cp` with
the md5 verified against the pre-sabotage snapshot
(`3b72b79b845bea7eddf24be9bf4f8a8a`).

| # | sabotage | RED (window `--nogui`) |
|---|---|---|
| 1 | restore the whole pre-1374 `_narrow_line` | NW1 NW3 NW4 NW6 NW10 NW11 NW12 NW13 **NW14 NW15 NW16** LX10 — and KN1 KN2 in the keys suite on `:99` |
| 2 | delete the `wnf > 0` suffix | NW1 NW3 NW4 NW6 NW10 NW11 NW12 **NW15** LX10 |
| 3 | make the suffix unconditional | NW4 NW12 NW13 **NW14 NW15 NW16** |
| 4 | build the suffix inside the rows arm only (1360's defect 3) | NW4 NW12 **NW15** |
| 5 | restore the old `_incomplete_line` | 33 rows: EN1 EN3 EN4 EN5 F1 F2 F4 F5 F6 F7 F8 F14 F15 F16 F19 F20 F27 F28 F29 H4 NW1 NW2 NW3 NW4 NW11 NW13 **NW14** NW16 Q1 Q3 Q4 Q6 RE4 |
| 6 | re-grow `_narrow_line` past the cap | NW1 NW3 NW4 NW11 NW12 NW13 **NW14** NW16 |
| 7 | `_pane_chars` `set W 96` → `120` | **NW14** and FZ4 — the cap's coupling, proved with no golden moving |
| 8 | pointer only in the empty-list arm | **NW16 alone** |

Sabotage 2 is the one that matters for the judgement above: it is the deletion
a reader would reach for on a "be brief" instruction, and NW15 is what stops it.

## SUITE RESULTS

| suite | arm | result |
|---|---|---|
| `test_rdw_window_1245.tcl` | `--nogui` | ALL PASS (195), was 192 |
| `test_rdw_window_1245.tcl` | `:99` | ALL PASS (228), was 225 |
| `test_rdw_keys_1245.tcl` | `:99` | ALL PASS (90), unchanged |
| `test_op_param_store_1245.tcl` | both | ALL PASS (135) |
| `test_rdw_seam_1245.tcl` | both | ALL PASS (49) |
| `test_annot_declutter_1244.tcl` | `:99` | ALL PASS (134) |

## WHAT IS THE USER'S TO RULE — rule debt 1374

1. **The list's name.** They typed "annotated list"; the tree says
   **annotation list** in `rdw::_list_name`, `rdw::_narrowed_list`, the window
   title, the chrome line, the scope dialog and the store's own key. Taking
   their literal word means changing all six or shipping two spellings of one
   list. Kept as "annotation list", treating "annotated" as a slip — their
   second example, "summary list", matches the tree exactly. Theirs to settle.
2. **Do the counts stay?** The label prints `6 of 88 columns` — 15 characters
   that turn a label into a warning. Without them a six-row block is
   indistinguishable from a device that published six columns, which is DD-1's
   own failure shape one surface out. The strictly literal reading of their
   ruling is `Narrowed to the MOS annotation list at this dump.` and nothing
   else. This is the one place where "terse" and "does not mislead" pull
   against each other.
3. **The convergence suffix's words**, ` 1 withheld did not converge.` The
   decision to KEEP the fact is argued above and is this crew's; the wording is
   theirs, and so is the wider question of whether they want it at all — it is
   the one clause kept against a general instruction to cut.
4. **`Press 3` surviving only where the block has no rows.** It leans on the
   chrome, and the chrome is measurably one dump behind: `rdw::apply_list_state`
   is called only from `rdw::build` and `rdw::set_list`, and `rdw::push` calls
   neither, so on the FIRST dump of a session the chrome still reads "Select a
   device and press 1". That is issue 1367/1355's surface, not this one's, but
   if the user would rather not depend on it the pointer goes back in the one
   builder (measured cost: +18 characters, still one display line).

Also for the driver, not the user: **rule debt 1353's ledger entry and rule
debt `1245_B3_window_wording` both quote sentences that no longer exist.** The
1353 issue file now carries the overrule; the ledger entries need the same
correction before the user is asked to ratify text that is gone.

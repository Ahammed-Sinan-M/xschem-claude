# 1391 — eight glyphs on the action strip, and not a word between them

**Filed** 2026-09-08, item B of the ASE-L run-guard batch
(`doc/claude/ase_run_guard_batch/CREW_BRIEF.md`).
**Status** FIXED. One rule debt (the wording is the user's to ratify), one look
debt (a tooltip is pixels; a green suite is not a hover).
**Files** `src/ase_window.tcl`, `tests/headless/test_ase_window.tcl` (rows
W1s1–W1s6).

## 1. The user's words, 2026-09-08

> And, add to batch - tooltips for the buttons in the ASE-L

## 2. The defect

The ASE-L session window's right vertical action strip
(`ase_window.tcl`, `ase::ui::open`) is eight buttons and every one of them is a
glyph:

    OP,TR    =    -->    X    N&>    >    !    ~

`N&>` is *Netlist and Run*. `~` is the waveform viewer. `-->` opens the Add
Output editor. None of that is guessable, and none of the eight carried a
tooltip.

⚠ **The plan for this item said `ase_window.tcl` had no tooltip at all — "grep
it, the count is zero". That is false**, and it is recorded here because the
false version was nearly written into a source comment. `ase::ui::rsel_tip`
(`ase_window.tcl` ~:3724) has driven `balloon_show` from a `<Motion>` handler
since R404, for the per-row full path in `Results > Select`. What is true is
narrower and is the interesting half: that one is **per-row**, so it cannot use
`balloon`, which bakes one fixed string into `<Enter>` at attach time. These
eight are **per-button and fixed**, which is precisely `balloon`'s shape. Two
shapes, two call sites, and still no second tooltip mechanism in the tree.

## 3. Why a tooltip here is a *label* problem and not a *tooltip* problem

Five of the eight buttons already have a menubar twin:

| glyph | command | menubar twin |
|---|---|---|
| `OP,TR` | `choose_analyses` | `Analyses > Choose…` |
| `N&>` | `do_run` | `Simulation > Netlist and Run` |
| `>` | `do_run_existing` | `Simulation > Run` |
| `!` | `do_stop` | `Simulation > Stop` |
| `~` | `open_viewer` | `Tools > Waveform Viewer` |

(The brief listed only `=`, `-->` and `X` as twinless. `OP,TR` has a twin too —
`Analyses > Choose…` — and it is minted with the rest.)

A hand-typed tip for any of those is a **second description of one action**, and
this file has already paid for that once: issue **0661** measured, in one
process, a printed remedy reading `Outputs > Save All` beside a menu reading
`Outputs > Save All… > Save device OP parameters (gm, gds, vth, ...)` —
`string match` against both constants returned 0. The fix then was
`ase::ui::lbl_outputs` / `lbl_save_all` / `lbl_save_op_params`, with the menu
**built from** the constants. `annot_lbl_*` (`xschem.tcl:17727`) is the same
pattern one file over.

So this issue mints the strip's labels into that **same section** of
`ase_window.tcl` and builds the menubar from them. The tooltip and the menu
entry are not "kept in sync"; they are one string.

⚠ **Issue 1389 (the run guard, item A of this batch) reads
`ase::ui::menu_path_stop`.** Its refusal of a second launch has to name the way
out, and the way out is the Stop entry the user can actually see. That is why
item B landed before item A in this batch: the constant had to exist first, and
the two items must not mint two.

## 4. What was minted

`ase::ui::lbl_analyses` `lbl_choose` `lbl_simulation` `lbl_netlist_and_run`
`lbl_run` `lbl_stop` `lbl_tools` `lbl_waveform_viewer` — the menubar twins,
and `ase::ui::open` now builds those seven entries from them.

`ase::ui::lbl_add_variable` `lbl_add_output` `lbl_delete_selection`
`lbl_sim_temperature` — the three twinless STRIP buttons plus the temperature
entry, which is not a strip button. `=` and `-->` open a dialog, so
their constant is the dialog's own `wm title` and the two are built from it:
the tip names the window the click produces. `X` opens nothing and gets a bare
action name.

Path composers, `>`-separated like the shipped `ase::ui::remedy_op_params_menu`
and `annot_remedy_menu`: `menu_path_choose_analyses`, `menu_path_netlist_and_run`,
`menu_path_run`, `menu_path_stop`, `menu_path_waveform_viewer`.

`ase::ui::strip_tips` is the one table keyed by each button's widget suffix.
The builder walks it and so does the suite, which is what makes "a button with
no tip is a red row, not a gap" enforceable: a ninth button packed on the strip
without a table entry reds W1s2 rather than shipping bare.

### The tips, as the user reads them

| glyph | tip |
|---|---|
| `OP,TR` | `Analyses > Choose…` |
| `=` | `Add Variable` |
| `-->` | `Add Output` |
| `X` | `Delete Selection` |
| `N&>` | `Simulation > Netlist and Run` |
| `>` | `Simulation > Run` |
| `!` | `Simulation > Stop` |
| `~` | `Tools > Waveform Viewer` |
| *(temperature entry)* | `Simulation temperature` |

**The mixed form is deliberate and it carries information.** Five tips are a
menu path and three are a bare action name — counted by walking the shipped
`ase::ui::strip_tips` table, not off the brief — and that difference tells the
reader whether the action has a MENUBAR route at all. Inventing a path for the
three that have none would be prose, which is the thing §3 exists to forbid.

⚠ **The distinction is menubar-only, and that is a real limit of this mint.**
All three bare-named actions do sit on a per-pane CONTEXT menu, spelled
differently there: `Add…` (`ase_window.tcl:854`, `:866`) against the tips
`Add Variable` / `Add Output`, and `Delete` (`:872`) against `Delete Selection`.
`OP,TR` makes it sharper still — its tip names a menubar path while the same
command also sits on the Analyses pane's context menu as `Add…`. Those entries
are not built from these constants, and a reader hovering a glyph has no way to
know the distinction being drawn is menubar-vs-context. Sweeping the three
context entries into the mint is the follow-up; it was left out of this item
rather than widened into it silently.

## 5. Decisions

**D1 — the temperature entry gets a tip, and arming it cost something.**
`$top.tb` is an unlabelled `entry` beside a `°C` label. The `°C` gives the
unit, not the subject; it is the only widget in the window carrying no word of
its own, so it is armed.

⚠ **MEASURED on `:99` before the code was written**, because `balloon` does a
**plain** `bind` on `<Enter>`, `<Leave>` **and `<FocusOut>`** — and that last
slot already carried `ase::ui::temp_commit`:

    BEFORE FocusOut: puts "COMMIT-FOCUSOUT"
    AFTER  FocusOut: after cancel balloon_show %W {{Simulation temperature}} 1; destroy %W.balloon

The commit was simply **gone**. A temperature typed and then clicked away from
would never reach the deck, with nothing said. So the builder arms the balloon
**first** and the commit bind **appends** (`bind … <FocusOut> +[list …]`).
Order there is load-bearing; row **W1s3** reads the composed script back off
the live widget and reds if either half is missing — which it does, measured:
neutralising the order gave `{… 1 0}` against `{… 1 1}`.

`balloon_off` was **not** reached for. It exists for a tip whose *string
changes* (issue 1384); this one does not, and clearing bindings on a widget
that carries its own is the hazard `balloon_off`'s own comment records.

**D2 — the strip buttons keep their hover highlight.** Also measured on `:99`:
`bind Button <Enter>` is still `tk::ButtonEnter %W` after the call. `balloon`
replaces an *instance* binding, and a Button's highlight is a *class* binding.
Nothing to do; recorded so nobody re-derives it.

**D3 — 300 ms, not the 1000 ms default.** Matching `rdw.tcl:3226`, which took
300 ms on the user's own *"as soon as user hovers over it"*. That figure is
**unratified — rule debt 1368**; this inherits it rather than opening a second
question about the same number.

**D4 — `Choose Analyses` vs `Choose…` is left alone.** The `OP,TR` dialog is
titled `Choose Analyses` while its menu entry reads `Choose…`. That is a second
spelling of one action and it is shipped and pre-dates this issue. A ratified
dialog title is not this issue's to rename, so it is recorded here and not
touched. If it is ever unified, `lbl_choose` is where it lands.

**D5 — the wording is unratified.** All nine strings above are user-visible
copy the user has not seen. Terse, acronyms uppercase (there are none in these).
**Rule debt 1391.**

## 6. Fences — `tests/headless/test_ase_window.tcl`

16 new rows, W1s1–W1s6. Every one reads the shipped artefact back off the
**live widget** and compares it to the constant **and** to a literal golden —
the W1t discipline, because a constant compared to a constant is a tautology
that would pass against a window arming no tip at all.

* **W1s1** ×8 — one row per button, in strip order: the `<Enter>` binding's
  baked string, the constant, the golden.
* **W1s2** — every child of `$top.strip` carries a tip (the gap guard).
* **W1s2b** — `strip_tips`' keys are exactly the packed buttons, in order,
  both directions.
* **W1s3** — the temperature tip **and** the surviving `<FocusOut>` commit.
* **W1s4 / W1s4b / W1s4c** — the five menubar twins are built from the
  constants: live `entrycget -label`, constant, golden.
* **W1s5** — `menu_path_stop` is exactly the two **live** labels in order. This
  is the string issue 1389 prints; a rename of either label moves the refusal
  or reds here, and cannot leave the refusal pointing at a menu path that is no
  longer on screen.
* **W1s6** — the `=` and `-->` tips are the live `wm title` of the dialogs they
  open.

### Discriminators, run 2026-09-08 on `:99`

The suite was neutralised three ways in one pass and re-run:

| neutralisation | reds |
|---|---|
| the `strip_tips` arming loop removed (the pre-1391 tree) | W1s1 ×8 (`NO-TIP`), W1s2 |
| `Stop` typed by hand as `Stop Run` | W1s4b, W1s5, and the pre-existing W1m |
| the temperature tip armed **after** the binds | W1s3 (`1 0` vs `1 1`) |

`RESULT: 14 FAILED (216 passed)` neutralised; `RESULT: ALL PASS (245 checks)`
restored. Baseline before the item was `RESULT: ALL PASS (229 checks)`.

### Suites, run 2026-09-08 on the dev display `:99` (Xvfb + openbox 3.6.1), after `make -C src`

| suite | arm | result |
|---|---|---|
| `test_ase_window` | `:99` | `RESULT: ALL PASS (245 checks)` (was 229) |
| `test_ase_window` | `--nogui` | `RESULT: ALL PASS (32 checks)` |
| `test_ase_interact` | `:99` | `RESULT: ALL PASS (64 checks)` |
| `test_ase_core` | `:99` | `RESULT: ALL PASS (184 checks)` |
| `test_ase_dialogs` | `:99` | `RESULT: ALL PASS (176 checks)` |
| `test_ase_persist` | `:99` | `RESULT: ALL PASS (137 checks)` |
| `test_ase_plot` | `:99` | `RESULT: ALL PASS (151 checks)` |
| `test_annot_show_menu` | `:99` | `RESULT: ALL PASS (36 checks)` |
| `test_ase_optier_0963` | `--nogui` | `RESULT: ALL PASS (103 checks)` |

That set is every headless suite referencing a label, menu or widget this issue
touched (`grep -l` over `tests/headless` for `Netlist and Run`,
`Waveform Viewer`, `mb.sim`, `mb.tools`, `mb.analyses`, `Add Variable`,
`Add Output`, `tb.temp`, `$top.strip`).

⚠ `test_ase_optier_0963` is a **`--nogui` suite** (`full_audit.sh:161`). Run on
`:99` it hangs and times out with no banner at all, which reads exactly like a
crash. It is not one; the arm was wrong. Recorded because the first run of it
here made that mistake.

## 7. Status against the branch's named baseline reds

`test_ase_window` is on the named list, and it **was already green** when this
item took its baseline: `RESULT: ALL PASS (229 checks)`, measured before any
edit. It moved 229 → 245, all pass, entirely by row addition. The floor was
raised, never lowered.

## 8. Debts

* **rule 1391** — the nine tooltip strings and the mixed path/name form (D5).
* **suite `test_ase_window`** — a `:0` run, recorded and **NOT PAID**. There is
  no standing GUI-gate approval (`~/.claude/gui_test_gate/allow_until` does not
  exist), so a `:0` run would block on a human click; it belongs in the
  driver's `owed.sh drain` batch, not in a subagent's transcript.
* **look 1391** — a tooltip is pixels. The suites assert the binding, not the
  hover: `balloon_show` returns early unless the X pointer is physically over
  the widget, so no headless run can prove a tip ever appeared. Suites green,
  please hover.

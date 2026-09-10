# RDW UX batch — Close, the status-bar hint, and per-PDK config

Branch `fluid-editing`. Three items, requested by the user 2026-09-07, verbatim:

> In the RDW, add a Close button to dismiss the window
>
> Add status message in status bar of schematic window for the three RDW print
> modes 1,2,3 key : Is user is in verb-noun mode, pressed key without instance
> selected, she is in command mode, and status bar should suggest "Click on
> instance for annotation/summary/all OP info in Results Display Window" And,
> BTW, if since *that* much space may not be available on the status bar, if
> user hovers on the visible portion of the message in the status bar, can we do
> a tooltip that displays the rest? Doable?
>
> And the 3rd thing: When saving config - such as parameter lists
> Eg. `/home/analog/dev/xschem-claude/.xschem/op_param_lists.conf` - the PDK
> should be taken into account - user might want something different for sky130
> and gf180mcu. A given launch, with a set of libraries will not have more than
> one PDK included

The annotate + Results Display feature set was declared **done** by the user
immediately before this. These three are additions on top of a working feature,
not repairs — so the bar is: **land them without disturbing anything they just
signed off.**

---

## Standing rules (CLAUDE.md; violating one wastes a whole item)

* `./src/xschem` with a **path**, never a bare `xschem` — the PATH one is 3.4.6
  from Jan 2025 and rewrites the user's recent-files list (issue 0924).
* Every launch carries **`--nolog`**, never `--logdir`. One exception:
  `test_ase_log_seam_0207`.
* **Never touch, move, back up or read-modify-write anything under `~/.xschem/`.**
* Never `git checkout --` / `restore` / `stash` / `clean` against uncommitted work.
  Never `git push`, never open a PR.
* `tclsh run_regression.tcl` runs **solo** (issue 0990) — coordinate through the
  driver, never launch it from a crew.
* Suites: `DISPLAY=:99 ./src/xschem --pipe --nolog -q --script tests/headless/<t>.tcl`
  (`--pipe` or the output goes to the CIW, not stdout).
* UI copy is **terse**, acronyms **UPPERCASE** (MOS, SPICE, PDK, RDW, OP).
* A `look` or `rule` debt clears **only** when the user says so. Record one at the
  moment it is incurred — `tests/headless/owed.sh add rule|look|suite`.
* Issue numbers: `doc/claude/issues/NUMBERING.md` is the only authority. Read its
  tail, grep the directory before minting, record the number in the same commit.
  **Next free is 1382.**
* A floor is raised when rows are added and NEVER lowered to make a run pass.

---

## Item A — a Close button on the RDW

`src/rdw.tcl`. The button column today is Up / Down / Delete / Add / Save.

**Established already:**
* `rdw::close` exists, and its own comment records that the window **deliberately
  keeps its dumps across a close** so they can be worked with later. Ruling DD-16
  leans on that (a block can be edited an hour later on a different sheet). So
  Close is a *withdraw*, not a discard — do not "tidy" that away.
* Escape already closes the window under ruling DD-12, and there is a
  `WM_DELETE_WINDOW` protocol. This button is a **third door on the same rule**,
  which is this file's own preferred shape (one rule, several doors) — so it must
  call `rdw::close` and nothing else. A second teardown path is the disagreement
  invariant I1 forbids.

**Decide and state:**
* Where in the column. It is not an edit, so it should not sit among the four
  that are — separate it, and say why in the comment.
* Greying: it should be `normal` on all three lists. `rdw::button_state`'s table
  is the fence; add the row and gold it.
* Whether `rdw::button close` should exist as a command-path door too. Every other
  button is reachable that way and the greying table fences the command path as
  well — follow the file, do not invent an exception.

**Rows owed:** the greying table on all three lists; the button really invokes
`rdw::close`; the dumps SURVIVE the close (press Close, reopen, blocks still
there) — that last one is the one a future "cleanup" would break.

---

## Item B — the status-bar hint for keys 1 / 2 / 3, and a tooltip for the overflow

**The trigger, precisely.** `rdw::key {kind}` (`src/rdw.tcl:4417`) resolves the
selection first, then branches: `one` → `rdw::show $name`; `none` →
`rdw::pick_start`. **The `none` branch is the user's case** — they pressed the key
with nothing selected, so they are now in a pick (command) mode waiting for a
click. Today that mode announces itself in the CIW, not on the sheet.

**RULED BY THE USER, 2026-09-07.** Asked whether to gate the hint on verb-noun
mode, they declined both options and restated the condition in better terms:

> If an instance is selected and user presses 1/2/3, only the selected instance
> is processed. One does not enter command mode in this case. If more than one
> selected, issue a warning in the CIW and refuse.

So **the gate is COMMAND-MODE ENTRY, not the interface.** The hint belongs to the
`none` branch of `rdw::key` and to nothing else. It does not depend on
`intuitive_interface` at all — which is the cleaner rule, because the pick mode is
identical in both interfaces and a hint appearing in only one would itself be a
surprise.

⚠ **THE OTHER TWO BRANCHES ARE A VERIFICATION TASK, NOT A CHANGE.** The user's
sentence describes what `rdw::key` already does — `one` → `rdw::show $name`,
`many` → a CIW refusal naming the problem. **Confirm both by driving them, and
report what you measured.** If either does NOT behave as they describe, that is a
defect they have just reported and it takes priority over the hint itself. Do not
assume the code is right because it reads right.

**The wording**, from the user, one per key:

| key | list | suggested |
|---|---|---|
| 1 | annotation | `Click on instance for annotation OP info in Results Display Window` |
| 2 | summary | `Click on instance for summary OP info in Results Display Window` |
| 3 | all | `Click on instance for all OP info in Results Display Window` |

Keep their words. `OP` stays uppercase. Do **not** silently shorten to fit — the
whole second half of the request is about what to do when it does not fit.

**Which widget.** Two candidates, measure both:
* `.statusbar.10` — the command-mode indicator, written from C
  (`callback.c:390`, `:4575`, `:9902` — `DRAW WIRE!` etc). Idiomatic for a mode,
  but short.
* `.statusbar.1` — a `label` packed `-side left -fill x` (`xschem.tcl:16747`,
  built at `:18629`), the wide one.

`actions.c:5985` already documents a case of the selection info line eating a
`.statusbar.1` message — **read that comment before choosing**, and make sure the
hint is not eaten the same way, or is restored when it is.

**Clearing it.** The hint must disappear when the mode ends — a click, Escape, or
any other exit. A stale "click on instance" on the sheet after the pick is over is
worse than no hint. Find every exit from `rdw::pick_start` and cover them all.

**The tooltip — DOABLE, and the machinery exists.** `proc balloon {w help {pos 1}
{motion_kill 0} {delay 1000}}` at `xschem.tcl:14826`, with `balloon_show` at
`:14841`. It was hardened by **issue 1368** for the RDW's own `aA` button: tips are
pulled back on screen, and widget-anchored (`pos 1`) and pointer-anchored (`pos 0`)
tips are clamped differently because a moved `pos 0` tip lands under the pointer,
gets destroyed by its own `<Leave>`, and flickers forever. Read that whole comment.

Three things the crew must get right:

1. **Re-arm on every text change.** `balloon` bakes the help string into the
   `<Enter>` binding at call time. A status label whose text changes needs the
   binding re-made, or the tip shows the previous mode's sentence.
2. **Only when it is actually clipped.** A tooltip repeating text the user can
   already read in full is noise. Test it: `font measure` the string in the
   label's own font against `winfo width`, and arm the balloon only when it
   overflows. Row this — the negative case (short window, no tip) is the one that
   rots.
3. **The status bar is not the RDW.** These bindings live on the schematic
   window's widgets, which are built per top-level (`pack_widgets {topwin}`) and
   exist in tabs too. Whatever you bind must be right for every window, and must
   not leak a binding into a window that is later destroyed.

**Rows owed:** the three sentences by key; the mode-gate decision, whichever way
it goes; the hint clears on every exit from pick mode; the balloon arms when
clipped and stays silent when not; the sentence survives a text change (the
re-arm); and the `--nogui` arm must not raise.

---

## Item C — the settings file takes the PDK into account

**The user's constraint is the whole design, and it is generous:** *"A given
launch, with a set of libraries will not have more than one PDK included."* So the
PDK is a **per-process constant**. Nothing has to merge two PDKs at runtime; the
question is only which rows apply to this launch and how they are written down.

**Establish the identity first, and this is the crux of the item.** Candidates,
in the order to try them:
* `$env(PDK)` / `$env(PDK_ROOT)` — the open_pdks convention (`sky130A`,
  `gf180mcuD`, `sg13g2`). Both are already in this tree's saved-variable list
  (`xschem.tcl:16267`, `:16276`), so the tree already knows about them.
* the library path (`$::XSCHEM_LIBRARY_PATH`) — what is actually loaded.
* the set of `op_annot` descriptors a PDK registered from its own procs file
  (`xschem.tcl:17414` says a PDK registers from there) — the most *semantically*
  honest, since it is the PDK's own act.

**Report what is actually set in the three PDKs this tree has fixtures for**
(sky130A, gf180mcuD, ihp sg13g2 — there are `test_*_libmgr` suites for each) rather
than assuming. If `env(PDK)` is empty in a real launch, the design has to survive
it — see the no-PDK rule below.

**RULED BY THE USER, 2026-09-07: ONE FILE, PDK SECTIONS.** They were shown both
and picked this shape:

```
# .xschem/op_param_lists.conf

# applies to every PDK
class mos annotation  id gm gds vgs vth vds

[pdk sky130A]
class mos annotation  id gm gds vgs vth vds gmbs
flavor mos *nfet_01v8* annotation  id gm vth

[pdk gf180mcuD]
class mos annotation  id gm gds vth

# PDK section beats the un-scoped rows above it.
```

The exact spelling of the section header is yours to choose and defend — `[pdk
sky130A]` is the shape they were shown, so deviate only with a reason stated in
the issue. The rejected alternative was one file per PDK
(`op_param_lists.sky130A.conf`); record it in the issue as the alternative, with
its argument: no grammar change, and a launch physically cannot read another
PDK's rows.

⚠ **THE GRAMMAR HAS AN OPEN LOOK DEBT ON IT** — `op_param_lists.conf grammar v2 +
the file-order precedence header`. The emitted header explains file-order
precedence among flavor rows. A PDK scope is a SECOND precedence axis, and the
header now has to explain both without becoming a wall of text the user stops
reading. That sentence is a `look` debt of its own the moment you write it.

**Non-negotiables whichever wins:**
* **An existing file must keep working, unchanged, and must not be rewritten into
  a new shape behind the user's back.** The user has a real nine-row summary list
  in `<repo>/.xschem/op_param_lists.conf` right now. Issue 1380 is the reminder
  that this file has already been lost once in this tree's history — do not be the
  second time.
* **A row with no PDK applies to every PDK.** That is what every existing row is,
  so this is what backward compatibility means concretely.
* **PDK-specific beats PDK-neutral**, and the emitted header must say so in the
  same voice as the existing precedence sentence. `rdw::_do_save`'s status line and
  the file's own header must not disagree about which file or section was written.
* **No PDK detected is not an error.** Behave exactly as today. Losing a user's
  lists because an env var was unset would be the 1380 defect wearing a hat.
* `op_param_lists::load` reads the user tier then the project tier and stamps
  nothing (ruling DD-7). Whatever you add keeps that shape.

**Rows owed:** round-trip under each design; an old file loads unchanged; a
neutral row applies under a PDK; a PDK row does not leak to another PDK; the
no-PDK launch; and — the one this feature actually needs and the store has never
had — a **two-process fence**, which is still owed from issue 1380 and belongs
here because this item is exactly about what survives a restart.

---

## Deliverables

Per item: the code, the rows, an issue file under `doc/claude/issues/`, the spec
updated (`doc/claude/specs/op_param_lists.md` for C), a `rule` debt for every
user-visible decision the request did not settle, and a `look` debt for anything
only the user's eyes can judge — items A and B are both pixels.

**Report honestly.** A green suite is not an eyeball, and a row that is green
because of an unstated property of its fixture is a row that will go green again
for the wrong reason.

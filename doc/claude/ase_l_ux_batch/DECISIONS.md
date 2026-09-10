# Decisions — ASE-L UX batch

Numbered so a crew, a suite row and a commit message can all cite the same thing.
A decision marked ⚖ is the USER'S and is recorded on the ledger; the rest are the lead's
and are reversible on a word.

## Item 1 — Save State confirm

**S-1. `save_as_needs_confirm` keeps its D8 contract unchanged.** It goes on answering
exactly "the target IS my own file AND that file is effectively read-only". It is a
documented predicate with pinned rows (`test_ase_dialogs.tcl` section H2)
and a spec paragraph. Widening it to mean two different things would move those rows and
would leave one boolean carrying two sentences.

**S-2. The new case gets its own predicate, `ase::ui::save_as_overwrites_other`.**
It answers 1 iff the resolved target EXISTS and is NOT the session's own state file. The
two predicates are mutually exclusive by construction — S-1's arm requires target == own,
S-2's requires target != own — so `save_state_ok` can ask them in order and never has to
compose a sentence out of two reasons.

**S-3. An UNTITLED session (`ase::session_path` = {}) confirms on any existing target.**
It has no own file, so every existing target is "somebody else's". This is the case where
a clobber is most likely and least expected.

**S-4. Saving onto your own state stays silent.** That is what Save means. The user's
words were *"confirm if overwriting an existing state"*, and the ordinary save is not
what they noticed.

**S-5. A target that does not exist stays silent.** Creating a new state view is not an
overwrite. `ase::ui::do_save_state_as` already creates the directory (D9, row H3).

**S-6. Unwritable-and-different is out of scope — and the write then fails SILENTLY.**
If the target exists but cannot be written, the confirm correctly fires (it exists), the
user says Overwrite, and `ase::ui::do_save_state_as` returns 0 with **nothing surfaced**:
no dialog, no status change, no title change. This sentence first said the write "fails
through the existing error path"; the item-1 adversary drove it at mode 0444 and there is
no such path — a successful overwrite and a failed one are indistinguishable from the
outside. Correcting the claim rather than the code, because reporting a failed save is a
change of its own with its own sentence; it is recorded on the ledger.

⚖ **S-7. The sentence.** `ase::ui::lbl_overwrite_state` mints, in the `lbl_*` family that
already exists at `src/ase_window.tcl:5487-5556`:

> **State `<lib>/<cell>/<view>` exists. Overwrite?**

Title stays `Overwrite State`, the title the read-only arm already uses. Terse, one line,
names the thing it will destroy. **This is the user's ruling and is filed as a rule debt.**
The existing read-only sentence — *"The state `<lib>/<cell>/<view>` was opened read-only.\nOverwrite it?"* —
is moved into the same family unchanged, so both live in one place and neither is a magic
string inside `save_state_ok`.

**S-8. D13 is retired, not amended.** `doc/claude/specs/ase_l.md` and the docstring at
`src/ase_window.tcl:6371` both state D13 as shipped behaviour. Both are rewritten to say
what is now true and to record that the user overruled it, with the date. A spec that
still says "needs NO confirm" next to code that confirms is how the next reader gets it
wrong.

**S-9. Row H2's fourth check keeps its assertion and loses its name.**
`"H2 different target needs no confirm even readonly"` still passes — `save_as_needs_confirm`
is unchanged — but the name now reads as a promise the window no longer makes. Renamed to
name the predicate rather than the outcome. The floor rises; it never falls.

## Item 2 — the font and theme derivation (issue 1398)

**T-1. Four roles, one size, separated by weight and by face.** `AseEntryFont` (data),
`AseBodyFont` (chrome and prose), `AseLabelFont` (headings only, bold), `AseMonoFont`
(machine text). `AseLabelFont` keeps its NAME — six suites, sixteen references, all by
name — and loses its job: it is no longer painted on every Label, Button and Checkbutton.

**T-2. `font configure`, never `font actual`.** `actual` normalises a pixel spelling to
points behind the user's back. Measured: base at `-size -14`, the `configure` copy tracks
18 px → 18 px across a rescale, the `actual` copy goes 17 px → 24 px.

**T-3. The knob refuses, it does not clamp,** and it returns a canonical integer.
`string is integer -strict` accepts `" 8 "`, `+8` and `0x10`; handing any of them back
defeats `_mkfont`'s no-op guard for the life of the process.

⚖ **T-4. `ase::palette` is untouched.** Owning the foreground means setting it FROM the
locked palette, not minting colours. Every hex in the diff is inside a comment.
`disabledfg` on `disabledbg` is still 1.787:1 — that is ruling R-3 in `PLAN.md` Stage 4
and it is the user's, not this item's.

**T-5. A readonly Entry takes `disabledbg`, not `table`.** The first repair gave it
`table`, which made the Simulators row editor's `Name:` field the same white as an
editable one — the affordance gone, and different from the grey the light scheme shipped.
`disabledbg` reads 14.877:1 and is identical in both schemes.

**T-6. The pane overflow gets a scrollbar, not a `wm minsize`.** Deriving the widths and
pinning the narrow columns fixes the ratchet and trades it for a real overflow below
740 px. A minimum size would forbid the small window instead of serving it; a horizontal
bar gives the reach back and closes a defect older than this batch — `build_pane` never
had one. Gridded, so `grid remove` can hide it, and it acts only on a CHANGE of state so
mapping it cannot cascade through its own `-xscrollcommand`.

**T-7. The live knob completes rather than withdraws.** It rescaled the fonts and left
the columns — six of eleven headings clipped after one mutation. `retune_columns` fires
only when the font metric has actually moved, so it can never silently undo a column the
user dragged.

**T-8. The combobox popdown is scoped on the ROOT path component.** Not `winfo toplevel`
(every ASE-L dialog IS a toplevel, so the pattern gained a dot and matched nothing) and
not `ase[0-9]+` (which missed the five waveform-viewer trees `apply_theme` also walks).

**T-9. `test_wave_sigbrowser_0312`'s two reds are pre-existing and are filed, not
carried.** Proved against a shadow tree built with `git show HEAD:` — identical rows,
identical count. Issue 1399. The suite is not in `run_regression.tcl`'s case list, so T1
has never covered it and T1's zero is honest.

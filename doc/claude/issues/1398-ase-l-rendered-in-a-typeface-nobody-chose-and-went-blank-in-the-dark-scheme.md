# 1398 — ASE-L rendered in a typeface nobody chose, and went blank in the dark scheme

**Asked for by the user, 2026-09-09**, after reading the UX audit:

> *"I think fonts, etc could stand to improve. How can we make it slick?"*
> …*"After that, you can do font/theme fix."*

Scope is `doc/claude/ase_l_ux_batch/PLAN.md` Stage 1 and nothing else. Stages 2–8 and
F1–F5 are not in this issue.

## The four measured defects

**1. Two hardcoded families, neither installed.** `ase::theme` named `Arial` and
`Courier`; `fc-list` on this box has neither, so Tk substituted Nimbus Sans and Nimbus
Mono PS while the RDW, the Calculator, the Library Manager, the CIW and the property form
all render in DejaVu through Tk's own base fonts.

**2. The ladder was upside down and everything was bold.** 10 pt bold headings over 13 pt
regular data — headings three points *smaller* than the rows they head. And a census of
the live window found **52 of 53 fonted widgets carrying the bold font**; the single
exception was the temperature entry. Nothing could be emphasised because everything
already was.

**3. `apply_theme` set a background and never a foreground.** So xschem's own shipped
`dark_gui_colorscheme 1` (`src/xschem.tcl:19078`) won every widget ASE-L painted: 58
widgets at **1.119:1** — the whole action strip, the whole status bar, every menu and
every cascade — and the temperature entry at **1.000:1**, white on its own `#ffffff`.

**4. Pixel column widths against point font sizes.** At `tk scaling 2.0` the glyphs grew
40% and the columns did not: `VCCGAUSS` rendered `VCCGAUS`, `Enable` rendered `Enabl`,
`Save Options` rendered `Save Opt`. The columns also *ratcheted*: every column was
`-stretch 1` with no `-minwidth`, so four resize cycles left `#` permanently at 60 px.

## What shipped

Four roles derived from Tk's own bases, never a family literal:

```
AseEntryFont  TkDefaultFont spec, normal    data cells, entries, comboboxes
AseBodyFont   TkDefaultFont spec, normal    menus, buttons, prose, the status bar
AseLabelFont  TkDefaultFont spec, bold      pane titles and column headings ONLY
AseMonoFont   TkFixedFont   spec, normal    the log, netlist text
```

`font configure`, **not** `font actual`: `actual` normalises a pixel spelling to points
behind the user's back. Measured, base at `-size -14`, copies made at scaling 1.388 then
rescaled to 2.0 — the `configure` copy tracks 18 px → 18 px, the `actual` copy goes
17 px → 24 px, 33% adrift from a spelling the user chose.

One knob, `::ase_font_size`, defaulting to "follow `TkDefaultFont`", band 6…32, **refused
not clamped** — a clamp turns a typo into a silent new setting. It takes effect on a
window already open.

Every `apply_theme` arm that writes a background now writes a foreground, from the
**unchanged, USER-LOCKED** `ase::palette`. `Radiobutton` and `Listbox` had no arm at all
and now do. The process-global `option add *TCombobox*Listbox.font` — which reached all 33
`ttk::combobox` call sites in xschem — is now scoped per window.

Column widths derive from `font measure`, with a `-minwidth` of the heading's own ink, so
a column can be dragged narrow but never narrower than the word that names it.

## Four regressions the fix itself introduced, found by its own adversaries

**Owning `-foreground` without `-readonlybackground` and `-disabledbackground` made the
dark scheme worse than it was.** A Tk Entry in `readonly` or `disabled` state paints with
those, not with `-background`. Measured: the Simulators row editor's readonly `Name:`
field went 12.635:1 → **1.662:1**, black on the option database's near-black ground, in
the very scheme the change exists to fix. Both replacements are already in the locked
palette; now 21:1 in both schemes.

**Deriving the widths traded the ratchet for an overflow.** With the narrow columns
pinned, the Outputs pane's `Save Options` column left the viewport below 740 px of window
width and at 560×360 thirty per cent of the pane was unreachable — `build_pane` never had
a horizontal scrollbar. It has one now, gridded (not packed) so `grid remove` can hide it
without re-deriving a layout inside an `-xscrollcommand` callback, and shown only on a
*change* of state so the map/unmap cannot cascade.

**The live knob rescaled the fonts and left the columns.** Driven through the real
gesture — open, set the knob, edit a variable so `populate` runs — `AseEntryFont` went
10 → 16, rowheight 21 → 31, and **six of eleven headings clipped**, the anti-clip floor
itself stale. `ase::ui::retune_columns` re-derives them, and only when the font metric has
actually moved, so a retune can never silently undo a column the user dragged.

**`ase::font_size` returned the raw string.** `string is integer -strict` accepts `" 8 "`,
`+8` and `0x10`; any of those permanently defeats the `_mkfont` no-op guard, because Tk
normalises the stored spec and the equality test can then never be true — four
`font configure` calls on every `ase::theme` call, and `populate` calls it on every
mutation. Canonicalised.

⚠ **And one the lead introduced while fixing the third.** Scoping the combobox popdown on
`winfo toplevel` was wrong: every ASE-L dialog *is* a toplevel, so the pattern became
`*ase4.simdlg*Listbox.font` — a dot mid-pattern, matching nothing — and the ASE-L window's
own popdowns lost their styling, i.e. it broke the case the old `ase[0-9]+` scan got
right. The root path component is correct for both a window and its dialogs.

## Recorded, not fixed

- A runtime `tk scaling` call splits realized from unrealized fonts, so lockstep holds at
  creation and across the supported `tk_scaling` xschemrc knob but not across a live
  rescale. No shipped path does that.
- Nothing clamps the window's natural size to the screen. At `tk scaling 4.0` on
  1920×1080 it asks for 2099×1160 and the WM returns 1920×1017, putting the action strip
  out of reach. Pre-existing; the derived columns make it wider than before.
- `disabledfg #a3a3a3` on `disabledbg #d9d9d9` is **1.787:1** and is now consistent in both
  schemes rather than inheriting the ambient one. The pair is USER-LOCKED and is ruling
  R-3 in `PLAN.md` Stage 4.

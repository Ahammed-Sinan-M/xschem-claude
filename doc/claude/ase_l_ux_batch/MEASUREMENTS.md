# ASE-L UX: what was measured, not guessed

Everything below was driven on the built binary (`./src/xschem`, commit `437a3add`) on
the persistent dev display `:99` (Xvfb 1920x1080x24, openbox 3.6.1), 2026-09-09, against
the user's own bench `sky130_tests_ase/tb_bandgap` state `ngspice_state1` with real
results loaded. Launch line, every time:

```
DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog \
    --script sky130A/cadence_style_rc --command "source <probe>.tcl"
```

Screenshots live in the session scratchpad (`uxshots/`), named in each row.

---

## M1 — The two font families ASE-L asks for are not installed

`ase::theme` (src/ase_window.tcl:182) creates exactly three named fonts:

| name | asked for | resolves to, live | linespace @ scaling 1.39 |
|---|---|---|---|
| `AseLabelFont` | Arial 10 **bold** | Nimbus Sans 10 bold | 15 px |
| `AseEntryFont` | Arial 13 | Nimbus Sans 13 | 19 px |
| `AseMonoFont` | Courier 13 | Nimbus Mono PS 13 | 19 px |

`fc-match Arial` -> Nimbus Sans. `fc-match Courier` -> Nimbus Mono PS. Neither family
is present in the 46 installed families. Tk silently substitutes, so the window renders
in a face nobody chose.

Tk's own defaults on the same display, same moment:

| name | resolves to | linespace |
|---|---|---|
| `TkDefaultFont` / `TkTextFont` / `TkMenuFont` / `TkHeadingFont` | DejaVu Sans 10 | 17 px |
| `TkFixedFont` | DejaVu Sans Mono 10 | 17 px |

⚠ **CORRECTION, 2026-09-09, after two independent judges refuted the first version of
this paragraph.** It said "the menubar of the ASE-L window is drawn in DejaVu Sans 10 and
its panes in Nimbus Sans 13 — one window, two type families." That is **false**, and the
reason is `ase::ui::apply_theme`'s `Menu` arm (src/ase_window.tcl:227-232), which themes
the menubar along with everything else. Re-measured live:

```
.ase4.mb        -font=AseLabelFont   -> Nimbus Sans 10 BOLD
.ase4.mb.launch -font=AseLabelFont            (and all nine cascades)
.menubar        -font=TkMenuFont     -> DejaVu Sans 10          (xschem's own)
.x1.menubar     -font=TkMenuFont                                 (the design window)
.calc.mbar      -font=TkMenuFont                                 (the Calculator)
```

The true statement is sharper, not weaker, and it is two statements:

* **ASE-L's menubar is the only BOLD menubar in the application.** Every other menubar in
  the process — xschem's, each design window's, the Calculator's — is `TkMenuFont`,
  regular. No toolkit sets a menubar in bold.
* **ASE-L's panes are the only 13pt text in the application, in the only family nothing
  else uses.** Everything else is DejaVu Sans 10 or DejaVu Sans Mono 10.

## M2 — ASE-L is the only window in the application not in the system font

Measured by walking each live toplevel and reading every widget's `-font`:

| window | fonts actually carried | derived from |
|---|---|---|
| ASE-L `.ase4` | `AseLabelFont`, `AseEntryFont` | hardcoded Arial / Courier |
| Results Display Window `.rdw` | `TkTextFont`, `TkDefaultFont`, `RdwPaneFont` | **Tk defaults** |
| Calculator `.calc` | `TkMenuFont`, `TkTextFont`, `TkDefaultFont`, `TkFixedFont` | **Tk defaults** |
| Library Manager | `LibMgrBold` = `font actual TkDefaultFont` + bold | **Tk defaults** |
| CIW | `CiwFont -family Monospace -size $sz` | own, with a size knob |
| property form | `slickPropLabel/Value/Header/Hint` | **Tk defaults**, four roles, one size knob |
| waveform viewer | `AseLabelFont`, `AseEntryFont` | ASE-L's |

Screenshot `three_windows.png`: ASE-L, the RDW and the Calculator side by side. The RDW
and the Calculator are the two windows ASE-L itself launches, from its own Results and
Tools menus, and both disagree with their launcher.

## M3 — The idiom ASE-L needs already exists in this tree

`src/property_form.tcl:325` — `slickprop::init_fonts`:

* four named fonts built with `font configure $name {*}[font actual TkDefaultFont]`,
  i.e. **inherit the system UI font**, never name a family;
* roles: Label (regular), Value (**fixed** — the comment says monospace "aligns and
  disambiguates l/1/I, O/0, like an EDA grid"), Header (+1, bold), Hint (-2);
* one user knob, `::slickprop_fontsize`, defaulting to the natural size **+1**;
* `_mkfont` reconfigures an existing name instead of failing on re-create, so a size
  change takes effect live;
* its comment at :321 — "Colors are NOT hardcoded ... so the form inherits the
  dark/light option-db theme".

## M4 — Turning on xschem's own dark GUI makes ASE-L unreadable

`dark_gui_colorscheme` (src/xschem.tcl:19078) is a shipped 0/1 option that rewrites the
Tk option database for the whole application. Driven live with `--tcl "set
dark_gui_colorscheme 1"`, reading colours back off the live widgets:

```
.ase4.tb.temp     (Entry)  bg=#ffffff fg=white     <- the temperature value
.ase4.tb.degc     (Label)  bg=#f2f2f2 fg=white
.ase4.status.*    (Label)  bg=#f2f2f2 fg=white     <- the whole status bar, 9 labels
.ase4.strip.*     (Button) bg=#f2f2f2 fg=white     <- all eight action buttons
.ase4.mb.*        (Menu)   bg=#f2f2f2 fg=white     <- every menu
```

White on `#f2f2f2` is a contrast ratio of **1.119:1**, and white on the temperature
entry's `#ffffff` is **1.000:1** — not faint, absent. Screenshot `ase_dark.png`: the
temperature field is blank, the action strip is blank, the status bar is blank.

⚠ **CORRECTION.** This paragraph first said 1.06:1. That figure was estimated, not
computed; the computed value is 1.119. The temperature entry's 1.000 was not stated at
all and is the sharper number of the two.

Cause: `ase::ui::apply_theme` (src/ase_window.tcl:224) sets `-background` from the
locked palette on Toplevel/Frame/Labelframe/Menu/Button/Label/Checkbutton and never sets
`-foreground`, so the dark option database's `*foreground white` wins.

The census behind it, walked over every widget in the live window that carries a `-font`:
**52 of 53 carry `AseLabelFont`** — the bold one. The single exception is `.ase4.tb.temp`,
the temperature entry. Every label, every button, every checkbutton, the menubar and all
nine of its cascades, all nine status segments, all eight strip captions and the 248
characters of prose in the Simulators dialog are 10pt bold. Nothing in the window can be
emphasised, because everything already is.

## M5 — Pixel column widths against point fonts: ASE-L breaks on HiDPI

Column widths are pixel constants (src/ase_window.tcl:823-827):

```
vars  {name 140 value 120}
ana   {num 30 type 60 enable 60 args 260}
outs  {name 120 value 110 plot 50 save 50 saveopts 90}
```

Font sizes are positive, i.e. points, so they scale with `tk scaling`; the widths do
not. Driven with `--tcl "set tk_scaling 2.0"` (screenshot `ase_scale2.png`): glyph
linespace goes 15/19 -> 21/27 px, the window grows only 798 -> 823 px wide, and

* `VCCGAUSS` renders `VCCGAUS`, `VCCGAU`
* `agauss(1.8, 'ABSVAR', 1)` renders `agauss(1.`
* `TEMPERAT` renders `TEMPER/`
* the `Enable` heading renders `Enabl`, `Save Options` renders `Save Opt`

## M6 — Contrast: the palette is fine except where it has to be read

Computed exactly (WCAG 2.1 relative luminance) over `ase::palette`:

| pair | ratio | AA text 4.5 | AA large 3.0 |
|---|---|---|---|
| fieldfg on table (data) | 21.00 | pass | pass |
| fieldfg on panel (labels, buttons) | 18.76 | pass | pass |
| fieldfg on header (column headings) | 17.14 | pass | pass |
| accent on table (rselect data rows) | 10.01 | pass | pass |
| accent on panel (labelframe titles) | 8.94 | pass | pass |
| selectfg on selectbg (selected row) | 5.76 | pass | pass |
| **disabledfg on disabledbg** | **1.79** | **FAIL** | **FAIL** |
| **disabledfg on panel** | **2.25** | **FAIL** | **FAIL** |

Disabled text is used to carry information the user needs: the greyed `Name:` field in
the simulator row editor holds the entry's name (`simdlg_editor.png`), and the greyed
`Levels:` field in Save All is the one that says what OP-parameter depth will be saved
(`saveall.png`).

Surface separation is also near nil: panel `#f2f2f2` vs table `#ffffff` is **1.119**,
panel vs header `#e8e8e8` is **1.094**. The three surfaces are the same grey to the eye,
so the window has no depth and grouping falls entirely to the maroon labelframe rules.

## M7 — Dialog discipline: sixteen dialogs, almost none of it

Counted over the whole of src/ase_window.tcl (7491 lines):

| primitive | occurrences |
|---|---|
| `wm transient` | **2** (`:399` ask-save-close, `:1403` a confirm) |
| `grab set` | 2 real (`:425`, `:1491`) |
| `-default active` | **0** — no dialog anywhere has a default button ring |
| `wm minsize` | **0** |
| `wm resizable` | **0** |
| `<Return>` bound on the toplevel | 2; the rest bind it per-entry, so Return works in one field and nowhere else |

`ase::ui::dialog_frame` (`:1665`) is `toplevel` + `wm title` + one `grid columnconfigure`
and nothing else, so every editing dialog is a free-floating window the WM places where
it likes. Measured, live: the small dialogs land near the parent (`+77+71`, `+76+58`),
and **every large one lands in the screen's top-left corner** — Simulators
`891x376+0+0`, Load State `541x363+0+0`, Results Select `597x430+0+0`, Log `941x460+0+0`.

`ase::ui::dialog_buttons` (`:1681`) packs OK `-side left` and Cancel `-side right` in a
full-width frame, which is the gulf visible in `outputedit.png`, `saveall.png`,
`analyses.png`, `simdlg_editor.png` and `loadstate.png`.

## M8 — The action strip is eight ASCII placeholders, and the source says so

src/ase_window.tcl:756, comment: *"right vertical action strip (spec 'Action strip'):
text placeholders"*. Eight classic Tk buttons, `-width 5`:

```
OP,TR    =    -->    X    N&>    >    !    ~
```

The Results Display Window, in the same screenshot, solved the same problem with words:
`Up  Down  Delete  Add  Save  ·  aA  ·  Close`.

## M9 — Menus: a dead menu, and two menus with one entry

Read off the live menubar:

```
Launch     -> (placeholder)                      <- one entry, literally that label
Session    -> Design Window | Load State | Save State | Close
Setup      -> Design... | Model Files... | Simulators...
Analyses   -> Choose...                          <- one entry
Variables  -> Edit...                            <- one entry
Outputs    -> To Be Saved > | To Be Plotted > | Save All...
Simulation -> Netlist > | Netlist and Run | Run | Stop | Log | Options...
Results    -> Select... | Direct Plot | Annotate >
Tools      -> Waveform Viewer | Calculator
```

Nine top-level menus, one of which is dead and two of which hold a single item. No Help,
no About.

## M10 — The analysis form is an untyped name/value grid

`Analyses > Choose...` is a 249x126 box: four radio buttons (op / dc / ac / tran), an
Enable checkbox, an `Options...` button, OK, Cancel (`analyses.png`). Behind
`Options...` is a two-column **Name / Value** table with an Add and a Delete
(`chana_opt_tran.png`, `chana_opt_dc.png`, `chana_opt_ac.png`) — no `Stop Time` field,
no `Step` field, no units, no validation, no defaults offered. The user must know
ngspice's own option spellings and type them in.

## M11 — First run says nothing

With the registry cleared and a state carrying no variables, analyses or outputs
(`ase_empty.png`): two entirely blank panes under their column headings, no hint, no
call to action, and a status bar reading `Simulator: ngspice` — the backend name, while
the registry is empty and the run would silently use whatever `ngspice` is on `PATH`.

## M12 — What a font/theme change would cost in tests

| what a suite names | suites | references |
|---|---|---|
| `AseLabelFont` / `AseEntryFont` / `AseMonoFont` | 6 | 16 |
| a palette hex (`#f2f2f2`, `#8b0000`, ...) | 7 | 22 |
| the literal `Arial` or `Courier` | **0** | **0** |
| an action-strip widget path | 4 | — |

No suite in the tree asserts the family names. **Redefining what the three named fonts
resolve to, while keeping the three names, moves no test.**

## M13 — The toolkit census: ASE-L is 92% classic Tk with ttk sprinkled on

Counted constructors in src/ase_window.tcl:

| ttk | n | | classic | n |
|---|---|---|---|---|
| `ttk::treeview` | 5 | | `button` | 37 |
| `ttk::combobox` | 4 | | `label` | 28 |
| `ttk::label` | 1 | | `frame` | 17 |
| `ttk::scrollbar` | 1 | | `menu` | 16 |
| `ttk::panedwindow` | 1 | | `toplevel` | 11 |
| | | | `checkbutton` | 7 |
| | | | **`scrollbar`** | **6** |
| | | | `entry` | 5 |
| | | | `labelframe` | 5 |
| **total** | **12** | | **total** | **136** |

The window is 92% classic Tk. It also disagrees with itself: one `ttk::scrollbar` against
six classic ones. That is why a flat ttk treeview sits inside a 3D-relief scrollbar in
every screenshot.

## M14 — What the toolkit can actually do here (Tk 8.6.17, X11)

Probed live:

* `ttk::style theme names` -> **clam alt default classic**; ASE-L runs on `default`,
  the 3D Motif-ish one. `clam` is the flat one and is present.
* `image create photo -data <base64 PNG>` **succeeds**. Real icons need no new
  dependency and no files on disk.
* Installed families that matter: DejaVu Sans, DejaVu Sans Mono, Ubuntu, Ubuntu Mono,
  Noto Sans Mono, Nimbus Sans, Nimbus Mono PS. **No Liberation, no Noto Sans.**
  Which is the argument for never naming a family: derive from `TkDefaultFont` and
  `TkFixedFont`, as `slickprop::init_fonts` already does.

⚠ `ttk::style theme use` is **process-global** and would reach all 33 `ttk::combobox`
call sites in xschem, not just ASE-L's four. It is not a local decision.

---

# M15 — The Stage 1 change, driven live, before the user rules on anything

`preview_theme.tcl` in this directory **edits no file**. It redefines `ase::theme` and
`ase::ui::apply_theme` in memory, after xschem has sourced them, and then opens the real
window on the real bench. Run it yourself:

```
DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog \
    --script sky130A/cadence_style_rc \
    --command "source doc/claude/ase_l_ux_batch/preview_theme.tcl"
```

What it does, and only this:

1. **Derives the three named fonts instead of naming families.** `AseEntryFont` and
   `AseLabelFont` take `[font actual TkDefaultFont -family]` and its size; `AseMonoFont`
   takes `TkFixedFont`'s. Same three names, so no suite moves (M12). Measured after:
   `AseLabelFont -> DejaVu Sans/10/bold`, `AseEntryFont -> DejaVu Sans/10/normal`,
   `AseMonoFont -> DejaVu Sans Mono/10/normal` — the same face as the menubar above them,
   the RDW beside them and the Calculator they launch.
2. **Rights the ladder.** Data and labels at one size; bold reserved for column headings
   and labelframe titles. The `Label` / `Button` / `Checkbutton` arms of `apply_theme` get
   `AseEntryFont` (regular) instead of `AseLabelFont` (bold), so explanatory prose stops
   shouting.
3. **Sets `-foreground` wherever it sets `-background`,** plus `-activeforeground`,
   `-activebackground` and `-disabledforeground`. This is the whole of the M4 fix.
4. **Measures column widths from the font** — `font measure AseEntryFont <specimen>` —
   instead of the pixel constants at src/ase_window.tcl:823-827, and gives each column a
   `-minwidth` from its own heading, `-stretch 0` on the narrow ones, `-anchor e` on `#`
   and `-anchor center` on the checkbox columns.

Shots: `ase_preview.png` against `ase_main.png`; `ase_preview_small.png` against
`ase_small.png`; `simulators_preview.png` against `simulators.png`.

**And `ase_preview_dark.png`.** The same overrides, run with `--tcl "set
dark_gui_colorscheme 1"` and a dark nine-colour palette, produce a fully legible dark
ASE-L: temperature field, action strip, status bar and all three panes readable. Compare
`ase_dark.png`, which is the same option with the shipped code.

⚠ **The dark palette in that shot is the assistant's invention and is NOT a proposal.**
`ase::palette` is USER-LOCKED. The load-bearing part of M4's fix is only that ASE-L must
OWN its foreground rather than inherit a process-global one; what colours a dark ASE-L
should use is the user's ruling, and none has been asked for.

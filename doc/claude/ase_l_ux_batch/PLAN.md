<!-- Provenance: doc/claude/ase_l_ux_batch. Evidence in MEASUREMENTS.md (15
     measurements taken on the live binary) and FINDINGS.md (126 findings from a
     twelve-lens audit). Nothing in this plan has been implemented; it is a
     proposal, and every ruling in it is still the user's to give. -->

All claims verified against the source and re-measured live. The temporary 192-DPI display is torn down; `:99` untouched.

---

# Making ASE-L slick — a staged plan

**Spine:** Proposal 3, *Finish the Window* — its diagnosis matches the evidence (the CRITICALs really are unfinished-edge items, not one wrong design decision) and its sequencing discipline is the only method that survives ~400 lines of change to a 7,491-line file. Grafted in: Proposal 1's font engineering **verbatim** (all three judges demanded it), Proposal 2's depth programme and its `analysis_line` keystone, and Proposal 1's hard font↔column coupling.

Everything below was re-measured by me on the built binary (`437a3add`, `src/xschem` current) on `:99`, plus a second Xvfb at **192 DPI** started specifically to settle the font argument, against `sky130_tests_ase/tb_bandgap` state `ngspice_state1`.

---

## 0. Corrections — nine claims that did not survive checking

These matter because several of them were about to become the justification in a commit message.

**0.1 — The ASE-L menubar is NOT in DejaVu.** The prompt's headline 1 and all three proposals say ASE-L disagrees with its own menubar. Measured live:

```
.ase4.mb cget -font  ->  AseLabelFont
font actual          ->  -family {Nimbus Sans} -size 10 -weight bold
```

`apply_theme`'s `Menu` arm (`src/ase_window.tcl:227-229`) themes the menubar exactly like everything else, because `menu $top.mb` (`:493`) is a child of the toplevel and `apply_theme $top` (`:832`) walks children. The menubar is Nimbus bold like the rest of the window. **The real disagreement is with the RDW, the Calculator, the CIW, the Library Manager and the property form** — that is what the issue should say. The fix is unaffected and is slightly *better* than advertised: the menubar joins the system face **and** loses its bold.

**0.2 — The font census is worse than "81% bold".** I walked every widget in the live window that carries a `-font`:

```
total 53   AseLabelFont 52   AseEntryFont 1
```

**Fifty-two of fifty-three.** The single widget carrying the data font is `.ase4.tb.temp`, the temperature entry. Everything else in the classic tree — every label, every button, every checkbutton, the menubar and all nine cascades, all nine status segments, all eight strip captions, and the 248 characters of explanatory prose in the Simulators dialog — is 10 pt **bold** Nimbus Sans. Nothing in the window can be emphasised because everything already is.

**0.3 — "Point sizes track `tk scaling`, Tk's defaults don't" is false.** This is Proposal 3's premise for spelling the fonts in pixels. I started a second Xvfb at 192 DPI (`tk scaling` 2.667 against `:99`'s 1.388) and compared fresh processes:

| | `:99` (1.388) | `:98` (2.667) |
|---|---|---|
| `TkDefaultFont` linespace | 17 | **32** |
| shipped `AseLabelFont` | 15 | **28** |
| shipped `AseEntryFont` | 19 | **36** |
| `{*}[font configure TkDefaultFont]` copy | **17** | **32** — exact |
| `{*}[font actual TkDefaultFont]` copy | 17 | 32 — exact *here* |
| `-size -(linespace-3)` fudge | 18 | **34** |

Tk's defaults are point-spelled (`-family sans-serif -size 10`) and track scaling exactly as ASE-L's do. There is no scaling drift to correct. The drift is **family and size**, nothing else. The pixel fudge is 1 px over at `:99` and 2 px over at 192 DPI — **250 px against 230 px for ten `M`s, +8.7%.**

**0.4 — `font actual` is the wrong copy, and for a reason Proposal 2 misstates.** P2 guards against `font actual` returning a negative size. It never does — it *normalises pixels to points*, which is the actual hazard. Measured, with the base spelled in pixels (`font configure TkDefaultFont -size -14`):

```
font configure -> -size -14      derived linespace @ scaling 2.0 = 18   (base: 17)
font actual    -> -size  14      derived linespace @ scaling 2.0 = 34   (base: 17)
```

`rdw.tcl:2562` already records this measurement. **Use `font configure`.**

**0.5 — `ttk::scrollbar` is 2 px *wider*, not 1 px narrower.** Measured: classic `reqwidth` 13, `ttk::scrollbar` 15. Proposal 3's "13 → 12" is wrong; Proposal 1's "+2 px per bar" is right.

**0.6 — `test_rdw_window_1245.tcl:9849` does not forbid what Proposal 1 says it does.** The check (`S1 STRUCTURAL`) requires `ase::backend_hook` to be *present* in rdw.tcl and forbids five literals in rdw.tcl — `::ase::backend::ngspice::`, `raw value`, `sim_capabilities`, `blanket_op_save`, `ase::theme`. It constrains **rdw.tcl**, not `ase_window.tcl`. `ase_window.tcl` calling `rdw::_shade_step` would red nothing. Duplicate the eight lines anyway — but for the honest reason: **load-order coupling.** `ase_window.tcl` must not require `rdw.tcl` to have been sourced.

**0.7 — `rdw::min_floor` and `calc::min_floor` are PINNED, not derived.** `rdw.tcl:2803` is `return {520 260}`; `calculator.tcl:259` is `return {560 680}`. The *raising* is derived: `rdw::apply_minsize` (`:2814-2827`) measures `winfo reqheight` and raises the pin. Copy that shape and describe it correctly — a pinned floor raised by a live measurement, called twice with `update idletasks` between (rdw's own comment at `:2805` says why twice).

**0.8 — `Control-Key-4` is bound on the schematic canvas, not on ASE-L.** `src/cadence_style_rc:311`:

```tcl
bind .drw <Control-Key-4>       {ase::direct_plot_for_current;    break}
```

Putting `-accelerator Ctrl+4` on ASE-L's *Results > Direct Plot* would advertise a key that does nothing while ASE-L has focus — the same class of defect as the Arguments column showing an option the deck drops. Do not do it.

**0.9 — Three contrast numbers are off, and one is worse than reported.** Recomputed (WCAG 2.1):

| pair | plan uses | was quoted |
|---|---|---|
| white on `panel #f2f2f2` (dark-scheme bug) | **1.12:1** | 1.06:1 (MEASUREMENTS.md; FINDINGS.md:1187 already says 1.12) |
| white on the temperature field `#ffffff` | **1.00:1** — literally invisible | — |
| `ase::shade(#f2f2f2)` = `#cacaca` vs panel | **1.46:1** | 1.87:1 |
| black on `#cacaca` | **12.81:1** | 11.6:1 |
| `#dcdcdc` vs panel | **1.22:1** | 1.34:1 |

Consequence for the palette rulings: `#dcdcdc` is *not* enough separation. `#d4d4d4` gives **1.32** against panel, **1.48** against table, black at **14.17:1**. That is the value to put in front of the user.

Also corrected in passing: the deck is `<cell>_ase.spice` (`src/ase.tcl:4830`), not `<cell>.spice`; and `ase::rundir` with no `rundir` key returns `set_netlist_dir 0` (`:4819`) — a single global netlist directory, so it is not even per-cell. The photo names in `src/resources.tcl` are `ximgSimulate` / `ximgNetlist` / `ximgWaves` / `ximgEditDelete`, not `img*` (moot — icons are refused, §Refusals).

---

## 1. LOOK and FUNCTION, separated

You asked how to make it slick. Roughly half of the worst findings are not about looks at all. I am keeping them apart so you can choose.

**LOOK — Stages 1–8.** Typography, colour, chrome, dialog discipline, keyboard, the strip. ~330 lines. Stages 1–3 need **no ruling at all** and move **no test**.

**FUNCTION — Stages F1–F5.** Four verified defects where the window reports something that is not true. ~180 lines, most of the rulings, one data migration.

- **F1/F4** — Analysis Options accepts, displays and *saves* keys the deck never emits. `src/ase.tcl:10962-10966` emits `tran [step] [stop]`, `ac dec [points] [start] [stop]` with `dec` a hardcoded literal, and `dc [source] [start] [stop] [step]`. `ase::ui::arg_summary` (`src/ase_window.tcl:1071`) is a *separate* producer that dumps every key. The source admits it at `:4211-4216`: *"DECK emission of extra keys stays deferred (v1 limit, documented here)."* Type `uic` into a bandgap startup bench, see it confirmed in the Arguments column, and get a run that started from the DC solution.
- **F2** — the Outputs Value column. Measured on your own bench with a completed run and a 69 MB raw: all five cells `{}`, and `ase::session_getattr $key results` is empty. It has exactly one writer in the whole tree (`src/ase_window.tcl:7245`, inside `run_finished`'s `ec == 0` arm), so a third of the window is dead furniture for any session that did not just finish a run in this process.
- **F3** — the status word. `set_status` (`:6968-6981`) has four arms and is only ever called with `running` / `ok` / `fail`; its `default` arm is unreachable. "Ready" means both *nothing has ever run* and *that run succeeded*, and `do_stop`'s SIGKILL lands in the `fail` arm, so the bar says **Error because you pressed Stop**.
- **F5** — two states of one cell share one run directory, one deck, one raw and one log, because `ase::rundir` (`src/ase.tcl:4812`) keys on the cell and `rundir` has **no writer anywhere in the tree** (`grep 'dict set' … rundir` returns nothing).

**The honest sequencing claim:** polish is a trust signal. A window that is slick and still shows you a setting it discards is *more* dangerous than one that looks unfinished. Land Stages 1–3 first because they are the literal ask and cost nothing; land F1 and F2 before Stages 7–8 make the window look finished.

---

# LOOK

## Stage 1 — The four type roles, the foreground, and the column policy

**One commit. No ruling. No suite moves.** This is the whole of what you are looking at when you say the fonts could stand to improve.

### 1a. Derive the fonts; never name a family

Replace `src/ase_window.tcl:184-192` (the nine lines that `font create` three fonts from two uninstalled families) with the block below, and add two helpers immediately above `ase::theme` at `:183`.

```tcl
# Create-or-RECONFIGURE. `font create` on a name that already exists RAISES,
# which is why ase::theme guarded each one with lsearch -- and why a size knob
# would have been dead on arrival: the guard meant a size change could never
# reach a window already open.  slickprop::_mkfont (property_form.tcl:340) is
# the shape.
proc ase::_mkfont {name spec weight} {
  if {$spec eq {}} { return }
  if {[lsearch -exact [font names] $name] < 0} {
    if {[catch {font create $name}]} { return }
  }
  catch {font configure $name {*}$spec -weight $weight \
           -slant roman -underline 0 -overstrike 0}
}

# The user's ASE-L text size, or {} for "follow TkDefaultFont".  Mirrors
# ciw_font (ciw.tcl:391) and rdw::font_size (rdw.tcl:2313): order-independent,
# and an out-of-band value is REFUSED, not clamped -- a clamp turns a typo into
# a silent new setting.
proc ase::font_size {} {
  if {![info exists ::ase_font_size]} { return {} }
  set n $::ase_font_size
  if {![string is integer -strict $n] || $n == 0} { return {} }
  if {$n < 6 || $n > 32} { return {} }
  return $n
}
```

and inside `ase::theme`, in place of `:184-192`:

```tcl
  # --- THE FOUR TYPE ROLES, DERIVED.  No family literal anywhere.
  #
  # This window asked for Arial and Courier.  NEITHER FAMILY IS INSTALLED here
  # (fc-match Arial -> Nimbus Sans; fc-match Courier -> Nimbus Mono PS), so Tk
  # silently substituted and ASE-L became the only window in the application
  # not in the system face -- the RDW, the Calculator, the Library Manager, the
  # CIW and the property form all render in DejaVu.  ASE-L's OWN menubar is in
  # Nimbus too, because apply_theme's Menu arm paints it; it is not the
  # exception, it is part of the same fault.
  #
  # ⚠ `font configure`, NOT `font actual`.  `configure` answers the spec AS
  # SPELLED, so a TkDefaultFont an xschemrc spelled in PIXELS is copied
  # verbatim; `actual` normalises pixels to points behind the user's back
  # (measured: a -14px base gives 34 px against the base's 17 at scaling 2.0 --
  # rdw.tcl:2562 records the same trap).  Measured on a real 192-DPI display,
  # a `font configure` copy reproduces TkDefaultFont EXACTLY: 32 px linespace
  # against 32, where a linespace-3 pixel derivation gives 34.  Nothing to
  # calibrate, on any display, including one that is not :99.
  #
  # ⚠ ONE SIZE, SEPARATED BY WEIGHT.  The old ladder was 10 bold over 13
  # regular -- headings THREE POINTS SMALLER than the rows they head.  Bold is
  # now spent on labelframe titles and column headings and on nothing else.
  if {[llength [info commands font]]} {          ;# --nogui has no `font` at all
    set uispec {} ; set mospec {}
    catch {set uispec [font configure TkDefaultFont]}
    catch {set mospec [font configure TkFixedFont]}
    set want [ase::font_size]
    if {$want ne {} && $uispec ne {}} { dict set uispec -size $want }
    if {$want ne {} && $mospec ne {}} { dict set mospec -size $want }
    ase::_mkfont AseEntryFont $uispec normal   ;# DATA: cells, entries, combos
    ase::_mkfont AseBodyFont  $uispec normal   ;# CHROME: menus, buttons, prose
    ase::_mkfont AseLabelFont $uispec bold     ;# HEADINGS ONLY: titles+columns
    ase::_mkfont AseMonoFont  $mospec normal   ;# MACHINE TEXT: the log
  }
```

**Why these role names.** `AseLabelFont` **keeps its name and keeps its bold** and only loses its job — it now applies to `Labelframe` titles and `Ase.Treeview.Heading` and nothing else. This is deliberately Proposal 1's naming, not Proposal 2's inversion: `src/wave_viewer.tcl` carries `AseLabelFont` on widgets outside ASE-L's theming (`:9252`, `:16233`, `:16683`, `:16983`, `:17066` call `ase::ui::apply_theme` on frames that are not under any `.aseN`), and inverting the name to regular would silently un-bold them. `AseBodyFont` is the one new name and takes everything the bold font used to paint.

**The knob:** `set_ne ase_font_size 0` in `src/xschem.tcl` beside its two siblings (`ciw_font_size` at `:19441`, `rdw_font_size` at `:19454` — there is currently nothing between them for ASE-L). Because `_mkfont` *reconfigures*, re-calling `ase::theme` rescales every open ASE window and dialog with no widget walk. Ship the variable in Stage 1; the `aA` widget is Stage 6.

### 1b. `apply_theme` sets a foreground wherever it sets a background

`ase::ui::apply_theme` (`:224-252`) writes `-background` from the locked palette on Toplevel/Frame/Labelframe/Menu/Button/Label/Checkbutton and **never writes `-foreground`**, so the shipped `dark_gui_colorscheme 1` (`src/xschem.tcl:19078`, which does `option add *foreground white startupFile`) wins. Add `-foreground [ase::theme fieldfg]`, `-activeforeground`, `-disabledforeground [ase::theme disabledfg]` to the arms that already write a background, plus the two missing classes: `Radiobutton` (Choose Analyses' four pills are stock `#d9d9d9` today) and `Listbox` (Load State's browser, carrying `selectbg`/`selectfg`).

**On the shipped light palette this moves zero pixels** — `fieldfg` is `#000000`, which is what every classic widget already renders. It is free, and it is the whole of the dark-scheme fix.

⚠ **One ordering constraint.** The `Labelframe` arm must set `-foreground [ase::theme accent]` **after** the generic `fieldfg`, or `test_ase_window.tcl:551` (`$top.body.vars cget -foreground` == `#8b0000`) reds.

### 1c. The derived active state

The `Button`/`Menu` arm sets `-background [ase::theme panel]` and leaves `-activebackground` at Tk's stock `#f8f8f8`, which is **1.05:1** against `#f2f2f2`. Theming ASE-L *destroyed* a hover step stock Tk had. Add `ase::shade` — an eight-line copy of `rdw::_shade_step`'s arithmetic (`rdw.tcl:2499-2515`: ±40 of 255, direction flipped on a dark ground) with a cross-reference comment — and set `-activebackground [ase::shade [ase::theme panel]]` + `-activeforeground [ase::theme fieldfg]`. On the shipped palette that is `#cacaca`: **1.46:1** against the panel, black on it at **12.81:1**.

Copy rather than share: `ase_window.tcl` must not require `rdw.tcl` to be sourced. (Not, as Proposal 1 claimed, because `test_rdw_window_1245.tcl:9849` would red — see §0.6.)

### 1d. `Ase.TCombobox` gets a state map

`:194` configures `-fieldbackground [ase::palette table]` and declares no map, so ttk's base `map TCombobox -fieldbackground {readonly #d9d9d9 disabled #d9d9d9}` wins and **both readonly comboboxes paint the palette's own disabled grey** — including *"Use this one:"* in the Simulators dialog, the control that decides which binary runs. Two lines, locked values only. The Calculator measured and fixed this identical trap (`test_calc_skeleton.tcl:1271-1292`); ASE-L never got it.

### 1e. Column policy — derive, don't pin. **This must land with 1a.**

`build_pane:851` is `-width <pixel constant> -anchor w -stretch 1` on all eleven columns, with no `-minwidth`. Measured live on the shipped binary: every column is `stretch=1 minwidth=20 anchor=w`, and the analyses widths have already crept from the dict values `{num 30 type 60 enable 60 args 260}` to `32 / 63 / 63 / 262`. ttk distributes slack in absolute pixels and clamps at the 20 px default on the way down, so the clamp is never undone on the way up.

Add a helper and give every column an explicit `-minwidth` and an honest `-stretch`:

```tcl
# A column's width in glyphs of the data font, never below its own heading's
# ink in the heading font.  This is what stops `Enable` rendering `Enabl` and
# `Save Options` rendering `Save Option`.
proc ase::ui::colw {n head} {
  set w [expr {$n * [font measure AseEntryFont 0]}]
  set h [expr {[font measure AseLabelFont $head] + 16}]
  return [expr {$w > $h ? $w : $h}]
}
```

`-stretch 0` on `#`, `Type`, `Enable`, `Plot`, `Save`, `Save Options`, and simulators' `Name`; `-stretch 1` on **exactly one** content column per table — `Arguments`, `Value`, `Program`, `File`. `-anchor center` on the three flag columns, `-anchor e` on `#`. The pattern already exists in this file 3,000 lines away: `rsel_build_list:3896` does `column mark -width 22 -stretch 0` / `column result -width 320 -stretch 1`.

Same treatment at `simulators_dialog:4545` (measured live: `name 140 / path 300 / problem 420`, all `stretch 1` — **420 px for an empty `Problem` column while the ngspice path measures 370**) and at the shared `listdlg:5292`.

**Why this cannot ship separately from 1a.** Measured live: the `Save Options` heading is **89 px** in a **90 px** column today. In the derived bold face it is **104 px**. The font change alone makes that heading clip *worse* than it does now.

### What you see, the moment the window reopens

1. **The whole window changes typeface.** Every pane, label, button, menu and the menubar leaves Nimbus Sans — an Adobe print clone with weak screen hinting that nothing else in the process uses — for the same face already drawing the CIW, the RDW, the Calculator, the Library Manager and every schematic dialog. In `three_windows.png` ASE-L currently reads as a different application from the two windows it launched. That stops.
2. **The bold comes off 52 of 53 widgets.** The menubar, the nine status segments, the eight strip captions and the 248 characters of prose in the Simulators dialog stop shouting. Bold survives only on the three maroon pane titles and the eleven column headings — so for the first time they can be found by eye.
3. **The ladder turns over.** `Name / Value / # / Type / Enable / Arguments / Plot / Save / Save Options` stop being three points *smaller* than the rows they head.
4. **Everything gets tighter and more fits.** Measured: `VCCGAUSS` 101 → **79 px**; `agauss(1.8, 'ABSVAR', 1)` 204 → **174 px**; `source=V2 start=0 stop=1.8 step=0.01` 308 → **281 px**; the ngspice path 410 → **370 px**; the log's 84 mono columns 924 → **672 px**, so the same log window already on screen holds ~115 columns. Row linespace goes 19 px (data) / 15 px (chrome) to 17 px both — about two more rows per pane at the same size.
5. **The `☑`/`☐` glyphs stop being drawn by a third typeface** at 16 px beside 12 px labels.
6. **The flag columns stop hoarding.** Measured: the `Enable` column is 63 px for a 16 px glyph. That width goes to `Arguments`.
7. **Nothing ratchets.** Drag the window four times and `#` no longer grows 32 → 60 px permanently, `Type` no longer bleeds a pixel per cycle, `Save Options` no longer renders `Save Option` forever after one drag.
8. **Every button and every menu entry acknowledges the pointer** — hover goes from 1.05:1 to 1.46:1 with black text at 12.81:1.
9. **`dark_gui_colorscheme 1` becomes legible instead of blank.** Today the temperature entry is white on white (**1.00:1**), and the whole action strip, the whole status bar and every menu are white on `#f2f2f2` (**1.12:1**). Compare `ase_dark.png` with `ase_preview_dark.png`.

### 1f. Two one-liners that ride along

- **Narrow the process-global combobox leak.** `:193` is `option add *TCombobox*Listbox.font AseEntryFont` — an unqualified pattern that permanently changes the popdown font of **every combobox in the application** the moment a bench is opened. Scope it: `option add *ase*TCombobox*Listbox.font AseEntryFont`. (`test_calc_skeleton.tcl:124-125` records the side effect in prose without asserting it, so nothing reds. Note the leak also becomes largely harmless once `AseEntryFont` *is* the system font — narrow it anyway.)
- **The balloon guard.** `ase::ui::populate` ends with `apply_theme $top` (`:1594`) and is called on every state mutation, so a live tooltip — a *child toplevel* `$w.balloon` built by `balloon_show` (`src/xschem.tcl:14948-14958`) with `-background black` and a `lightyellow` label — is repainted to panel grey with no border **while still on screen**. Two lines at the head of `apply_theme`:

```tcl
  if {[string match {*.balloon} $w]} { return }   ;# a live tooltip is not ours
```

That closes the cheapest CRITICAL in the audit.

### Files and lines

| file | where | ± |
|---|---|---|
| `src/ase_window.tcl` | `:183` (two new procs above), `:184-193` (font block + glob), `:224-252` (`apply_theme` + `ase::shade`), `:194` (combobox map), `:823-829` (three width dicts), `:849-853` (`build_pane`), `:3896`, `:4545`, `:5292` | **+96 / −11** |
| `src/xschem.tcl` | `:19454` (`set_ne ase_font_size 0`) | **+1** |

### Suites that move

**None.** Verified individually:

- `test_ase_window.tcl:547-550` asserts the three font *names* exist — all three survive; `AseBodyFont` is additive.
- `test_ase_window.tcl:554-556` asserts `.tb.temp` is `#ffffff` + `AseEntryFont` — unchanged.
- `test_ase_window.tcl:545` (`$top cget -background` `#f2f2f2`) and `:551` (`.body.vars cget -foreground` `#8b0000`) — unchanged, given the ordering constraint in 1b.
- `test_ase_window.tcl:1386` asserts `ttk::style configure Ase.Treeview.Heading -background` is `#e8e8e8` — untouched in this stage.
- `test_wave_sigbrowser_sea.tcl:677-682` derives rowheight as `[font metrics AseEntryFont -linespace] + 4` — derived, follows.
- `test_calc_skeleton.tcl:408` asserts `AseEntryFont` does **not** exist before ASE opens — still true, the fonts are only created inside `ase::theme`.
- No suite in the tree names `Arial` or `Courier` (verified: 0 hits).
- **No suite reads a treeview column's `-width`, `-minwidth` or `-stretch`** (verified: the 10 grep hits are all calculator `panedwindow panecget -stretch`).

### Re-measure on the dev display

```sh
tests/headless/devdisplay.sh start
DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog \
  --script sky130A/cadence_style_rc --command "source <probe>.tcl"
```

Take: the font census (expect `AseBodyFont` ≈ 48, `AseLabelFont` ≈ 4, `AseEntryFont` 1); all eleven column widths and minwidths; a four-cycle resize ratchet test; `Save Options` heading ink vs its column; and the dark-scheme foreground walk. Then repeat the whole Stage 1 probe on **`:98` at `-dpi 192`** — a temporary Xvfb, one line to start — because that is the only way to prove the derivation on a display that is not `:99`'s.

### Rulings in this stage

**One, and it is a `look` debt, not a ruling.** Every pixel of text in the window changes. `:99`'s `tk scaling` is 1.388; your Windows X server's is unknown and is almost certainly different. Record `owed.sh add look ase_l_stage1 "fonts derived; every glyph changes; :99 scaling is not the user's"` and show a before/after **on your display** before calling it done. The lead already drove this live — `doc/claude/ase_l_ux_batch/shots/ase_l_before_after.png` — so the picture exists; what is owed is your eyes on your own screen.

---

## Stage 2 — Dialog discipline and chrome craft

No new sentences. One ruling with two one-line answers, one ruling about the log window.

### What it does

1. **`catch {wm transient $w $top}` + place-over-parent in `dialog_frame` (`:1665-1671`)**, and at the seven hand-built `toplevel` sites (`:3830`, `:4044`, `:4218`, `:4539`, `:5285`, `:6114`) — every one except the log window, pending its ruling. `dialog_frame` today is `toplevel` + `wm title` + one `grid columnconfigure` and nothing else, so **placement is entirely the WM's guess and is not the same guess twice**: the audit measured the Simulators dialog at `891x376+0+0`; I measured the same dialog in the same session with the parent pinned at `798x502+500+300` and got **`891x376+1027+679`**. Neither is near its parent. On your Windows X server a third WM decides. Setting transient *after* mapping does nothing (measured — it must be set before the dialog is mapped), so it belongs in the scaffold. Follow `xschem.tcl:11252` and place explicitly at `+[winfo rootx $top]+40` after `update idletasks`, so the result does not depend on the WM at all.

2. **`dialog_buttons` (`:1681-1694`) — one decision, one place.** Today: `pack proceed -side left` / `pack cancel -side right` in a full-width frame. Measured on the Add Variable dialog: OK is 49 px at x=5, Cancel is 74 px at x=238 — **184 px of dead air between the two halves of one decision, in a 333 px window.** Change to `-width 8` on both, both packed `-side right` adjacent, plus `-default active` on proceed (Tk's default ring is the only "which button does Return press" affordance available without touching the locked palette) and `bind $w <Key-Return> $okcmd` **on the toplevel**. Then delete the nine per-entry `<Return>` bindings the central one replaces (`:1704-5`, `:1755-6`, `:1835-6`, `:4142`, `:4249-50`, `:4369`, `:5058-9`, `:5363`, `:6347`). Today Return works in one field and dies the moment you Tab off it — an inconsistency that is worse than uniform absence, because you cannot form a rule.

3. **`dialog_close_protocol $w $cancelcmd` moved *into* `dialog_buttons`.** The title-bar X bare-destroys eight of the ten dialogs and leaves their per-window `dlg`/`edrow`/`edchk` records set. This is **issue 0651, already filed**, and `save_all_dialog:5733` carries a comment saying exactly why it was not done centrally ("would change WM-close semantics for ~8 dialogs at once, none of them covered by a test"). So it lands **with a check per dialog**.

4. **`ase::ui::min_floor` + `apply_minsize`**, on the shape of `rdw.tcl:2803-2827` — *a pinned pair raised by a live measurement*, called at the head of `build` and again after theming with `update idletasks` between. `wm minsize` is `1 1` today for the session window and all eight dialogs. Measured height sweep: the `~` waveform button is unmapped by **250 px**, the **Stop button by 220 px**, with no scrollbar, no ellipsis and nothing said. Measured width sweep: below **360 px** the `State:` segment and its separator are dropped whole by the packer. A designer who parks ASE-L short beside a waveform viewer has no Stop for a running simulation.

5. **Six classic `scrollbar` → `ttk::scrollbar`** (`:853`, `:1414`, `:3898`, `:4548`, `:5294`, `:7012`), joining the one that already is (`:6123`); the stray `ttk::label` at `:6119` goes the other way to a classic `label`. Style them `ttk::style configure Ase.Vertical.TScrollbar -background [ase::palette panel] -troughcolor [ase::shade ...]`. Cost: **+2 px per bar** (13 → 15, measured). Plus auto-hide on `0 1` fractions using `rdw.tcl:2141`'s `pack forget` idiom — all three main-pane bars are permanently mapped with 3–5 rows in an 8-row table.

6. **One padding scale.** Six padding numbers in the whole 356-line `build`, every one 1 or 2 px, while the same file's dialogs use 8. `pack $top.body -padx 6 -pady {0 4}`; the three labelframes `-padx 4 -pady 4`; `pack $top.strip -padx {4 6} -pady 4`; `pack $top.status -padx 6`. Eight arguments added to existing calls.

7. **Write the widget idiom down in the source.** Classic Tk for chrome; ttk only where classic has no equivalent (Treeview, Combobox); `ttk::scrollbar` as the one named exception. The census is 136 classic to 12 ttk, and the two sibling windows by the same hand (RDW, CIW) are 100% classic. Not the reverse: `$top.status.stat cget -background` is asserted in **six** places across four suites and ttk widgets reject `-background`, so a wholesale ttk migration would lose the status light.

### What you see

Dialogs open **over the window that opened them** instead of somewhere the WM chose. OK and Cancel sit together at equal width instead of 49 px and 74 px at opposite edges. The window says which button Return presses, and Return commits from any focus in all sixteen dialogs — including the Load State View listbox that `loadst_default_to_session:6188` deliberately puts your cursor in and then leaves dead. The title-bar X stops leaking dialog state. The Stop button can no longer be dragged out of the window. Content stops touching the frame on three sides, and the two right-hand tables stop being 4 px apart and reading as one grid. The Motif-era sunken trough with triangular arrows stops butting a flat table in every screenshot, and a bar with nothing to scroll gets out of the way.

### Files, lines, suites

`src/ase_window.tcl` only: `:1665-1694` (the scaffold, ~20 lines), the seven toplevel sites (~7), `min_floor`/`apply_minsize` near `:740` plus two calls in `build` (~22), the six scrollbar constructors + one style block (~14), eight padding arguments, and nine deleted `<Return>` binds. **≈ +75 / −12.**

**Suites:** none should move, but three need watching. **95 references to `$w.btns.proceed` / `.cancel` across 13 suites** drive those buttons *by path*; repacking inside `$w.btns` keeps every path, so they stay green — but this is the largest blast radius in the LOOK half and the reason the change is repack-only. No ASE suite asserts a scrollbar class or a `wm minsize`. The `dialog_close_protocol` move needs one new check per dialog it newly covers (0651's own text says so).

### Re-measure

Dialog geometry and `wm stackorder .` for all seven dialogs, before and after, with the parent pinned; the height/width unmapping sweeps; `winfo reqwidth` of each scrollbar. **And once on `AUDIT_DISPLAY=$DISPLAY`** — your real Windows X server, not `:0` — because dialog placement is precisely the thing a different WM decides differently, and `AUDIT_DISPLAY=:0` gets you Xwayland, not your screen.

### Rulings

- **R-1 (one line either way): button cluster at the trailing edge** — the RDW's shape, `rdw.tcl:7131` — **or contiguous at the leading edge**, which is Cadence's form banner with Help alone at the right. I recommend the RDW's, because it is in this tree and you have lived with it.
- **R-2: the log window.** A transient iconifies with its parent and on most WMs cannot be minimised independently. A designer may want the log parked while a long tran runs. Include `$top.logwin` in the transient set, or not?

---

## Stage 3 — Make the clip reachable

This is the stage that fixes the finding at the top of the audit, and the one the previous stages **do not** fix.

The lead's own preview already carried derived fonts *and* font-measured column widths, and the AFTER panel of `ase_l_before_after.png` still renders `agauss(1.8, 'ABSVA` cut mid-token at the shipped 798 px width. I re-measured why: the derived string is **174 px** and the vars pane's tv is **262 px** total for two columns. Neither the font change nor the stretch policy un-clips it. Only an ellipsis, a tooltip, or horizontal scroll does.

### What it does

1. **Pixel-measured ellipsis + clipped-cell tooltip** on the three panes, the Simulators `Program` column and the status bar's last segment. Both mechanisms are already in the tree: `ase::ui::rsel_tip` / `rsel_tip_text` / `rsel_tip_show` / `rsel_tip_cancel` (`:3728-3760`) for the `<Motion>` balloon, and `balloon_clipped` (`src/xschem.tcl:14935`) for the show-only-if-actually-clipped gate. **The full string stays in the item's `-values`; only the DISPLAY is truncated** — otherwise every `tv set … value` assertion in the ASE suites reads an ellipsis.
2. **A horizontal scrollbar on the log window.** `log_open:7011` is `text $lw.t -height 24 -width 84 -state disabled -wrap none` with a vertical bar only. Keep `-wrap none` (wrapping destroys column alignment in simulator output); add `ttk::scrollbar $lw.hsb -orient horizontal` and regrid `.t`/`.sb` keeping those widget names. Derive `-width` from the font rather than the literal 84, which after Stage 1 buys ~115 columns in the same pixels. The line that matters is `command : /home/analog/dev/ngspice/.../ngspice -b -D casemode=preserve …` — 144 characters, the answer to the only question anyone asks when a run fails, currently off the right edge of a window with no wrap, no hscroll and no way to select-and-scroll.
3. **A horizontal scrollbar per pane**, mapped only when needed, using the same auto-hide idiom as Stage 2.

### What you see

A clipped cell ends in `…` instead of being cut mid-glyph, and hovering shows the whole string. The Monte Carlo variable whose sigma reference and sigma count are exactly the characters that fall off becomes readable without opening a dialog. The ngspice invocation becomes reachable.

**Files:** `src/ase_window.tcl:843-891` (`build_pane`), `:4545`, `:739-754` (status), `:7008-7020` (`log_open`). **≈ +52.**

**Suites:** none, *provided* the truncation is display-only. Watch `test_ase_window.tcl:1381-1383` (`W1p id output row Value blank pre-run`) — an empty cell must not acquire an ellipsis.

**Re-measure:** the clipped-cell tooltip at 798 px and at 560×360; `winfo ismapped` on each hscroll at full and reduced widths; the log at 84 and at the derived width.

**Rulings:** none. The `…` spelling is already shipped elsewhere in this file.

---

## Stage 4 — Depth

Without this, Stages 1–3 leave you with better type on the same flat sheet. Measured: `panel #f2f2f2` vs `table #ffffff` is **1.12:1**; `panel` vs `header #e8e8e8` is **1.09:1**. Three surfaces, one grey, and all the grouping falls on the maroon labelframe rules — which are themselves `groove`/`bd 2`, i.e. a Motif bevel.

### The half that needs no ruling

Give each pane's treeview a real sunken well (a 1 px frame drawn with `ase::shade` as a derived hairline, not a Motif bevel) and a 1 px separator under the heading strip. **Structure without a new colour.** This is most of the perceived depth and it spends nothing the user has to approve.

Also: **tag disabled analysis rows.** `Ase.Treeview` already maps `disabled` → `disabledbg`/`disabledfg`; a per-row `off` tag on unticked rows is four lines. Today `ase_main.png` shows the unticked `dc` and `ac` rows in exactly the same black as the ticked `tran` row, so the Enable checkbox has no visual consequence at all. This is worth having *only after* R-3 below, or it makes unreadable text out of readable text.

### The half that is yours (rulings)

- **R-3 — `disabledfg #a3a3a3` → something readable.** Computed exactly: **1.79:1** on `disabledbg`, **2.25:1** on `panel`. That is within 0.34 of the 1.45:1 you personally rejected in commit `19f8e351` as unreadable, and it carries information you must read — the greyed `Name:` in the simulator row editor holds the entry's name (`simdlg_editor.png`), the greyed `Levels:` in Save All says what OP-parameter depth gets saved (`saveall.png`). Candidates, computed: `#7f7f7f` grey50 → 2.84 / 3.58 (the tree-wide convention: `rdw.tcl:2411`, twelve sites in `calculator.tcl`); `#6e6e6e` → 3.61 / 4.55; `#595959` → **4.96 / 6.26**, both passing AA and still unmistakably greyed beside black body text. **My recommendation: `#595959`.**
- **R-4 — `header #e8e8e8` → a visible strip.** `#dcdcdc` gives only **1.22** against panel (not the 1.34 that has been quoted). **`#d4d4d4` gives 1.32 against panel, 1.48 against table, with heading text at 14.17:1.** The tree has already recorded this exact 1.09 pair as a user-visible failure in your own account at `wave_viewer.tcl:18186-18196`, and `wave_viewer.tcl:13017` had to write an apologetic off-palette literal because *"the locked palette has four entries and none of them is a divider tone."*
- **R-5 — a row-band tone.** 323 px of unbroken white between a row's name and its Save checkbox, with zero banding. This is the one colour omission in the audit that can produce a *wrong answer* rather than an ugly window. `#f7f7f7` is 1.07 against table — conventional banding weight. `ase::shade` would give `#d7d7d7`, which is far too heavy. So this needs either a tenth palette key or a dedicated derivation.
- **R-6 — a dark ASE-L, or not.** After Stage 1b the shipped dark scheme is *readable* but ASE-L is still a light island in a dark application. A real dark palette is nine values you have to choose, and note the accent is a light-only value: `#8b0000` on `#202020` is 1.63:1, so a dark palette needs its own accent — a second decision inside the first.

⚠ **Any new palette key touches three hand-written stubs** — `test_calc_widgets.tcl:1212`, `:1244` and `test_rdw_window_1245.tcl:4570` each build a fixed nine-key dict. They only throw if a code path `dict get`s the new key while a stub is in force, which is conditional, not certain — **check all three and update them in the same commit** rather than finding out.

**Suites that move if R-4 lands:** `test_ase_window.tcl:1386` (asserts `Ase.Treeview.Heading -background` is `#e8e8e8`) and reasoning at `test_wave_tabs.tcl:423`.

**Files:** `src/ase_window.tcl:167` (palette), `:194-220` (styles), `:224-252` (`apply_theme`), `build_pane`. **≈ +30.**

**Re-measure:** the full nine-pair contrast table; the pane-well hairline at both `tk scaling` values; the disabled-row tag against the new `disabledfg`.

---

## Stage 5 — Do not lose my work

Four repairs no other direction had as a set. Small, independent, and each closes a way the window can eat something.

1. **Save State onto a different existing state asks first.** Verified: `save_as_needs_confirm` (`:6375-6385`) returns 1 **only** when the target *is* your own file and it is read-only or unwritable; a different existing state returns 0, and the overwrite happens silently with no existence check and no undo. Widen the predicate to *"the target exists and is not this session's own file → 1"*. The machinery is three lines away — `ase::ui::confirm` (`:4039`) is modeless, themed, Return-commits, ESC-cancels and is already used by the read-only arm. **Six lines.** ⚠ `test_ase_dialogs.tcl:333-334` asserts `ngspice_state9` needs no confirm even when read-only; that fixture never creates state9, so it stays green — but its *name* becomes wrong, and a new check for the new arm belongs beside it.
2. **The checkbox hot zone.** `pane_click` (`:917-935`) toggles the flag on a click **anywhere in the column** and `break`s. Measured: the `Enable` column is 63 px and the glyph is 16 px, so **47 px of every cell silently edits the deck** when you meant to select the row — with no undo, no selection change to show it happened, and no suite covering the gesture. Restrict the hit region to a ~12 px band around the cell's horizontal centre using `$tv bbox`, `-anchor center` on the three flag columns (Stage 1e already does that half), and return 0 otherwise so the class binding selects the row. **~6 lines.**
3. **A visible focus ring.** `-highlightthickness 1 -highlightcolor <c>` in the `Button`/`Entry`/`Checkbutton`/`Radiobutton` arms, overriding the application-wide `option add *highlightThickness 0` (`src/xschem.tcl:19099`) **for ASE-L's tree only** — that line is not touched. Today a focused strip button is pixel-identical to the seven around it. **Ruling R-7: the ring colour.** Recommend `selectbg #4a6984`, already in the dict and already meaning *this is where you are*.
4. **`-takefocus 0` on the three pane scrollbars now**, and on the eight strip buttons **only together with Stage 6's chords, never before**. The measured tab chain is temperature entry → the eight strip buttons → the three panes, so the **fourth** Tab stop is the `X` delete button and the **sixth** is Netlist-and-Run, both of which fire on Space with no confirmation, no undo and no visible focus ring. Taking the strip out of the chain before there is a keyboard route to it would remove the strip from a keyboard-only user entirely.

**Files:** `src/ase_window.tcl:6375-6406`, `:917-935`, `:224-252`, `:855`. **≈ +26.**

**Rulings:** **R-7** (ring colour), and **R-8**: the overwrite confirmation sentence is new user-facing copy. Proposed, terse, unratified: `State <lib>/<cell>/<view> exists. Overwrite?`

---

## Stage 6 — The keyboard, in two halves of very different price

`grep -c -- '-accelerator' src/ase_window.tcl` = **0**. `-underline` = **0**. Twenty-six commands, all mouse-only. The sibling waveform viewer ships 13 accelerators; `xschem.tcl` ships 115.

**Free half, no ruling, no test:** `-underline` on the nine cascades — nine integers. `bind all <Alt-Key>` is already armed via `tk::TraverseToMenu` and F10 already posts the menubar; Alt+letter simply cannot match anything today because no entry carries an underline. Menubar mnemonics are per-menubar, so there is no collision with the schematic window's.

**Priced half — R-9, the chord table.** `ase::ui::install_bindings` creating an `AseL` bindtag on the toplevel, `src/wave_viewer.tcl:14895-14922`'s pattern verbatim, each script ending in `break`, mirrored as `-accelerator` on the twin menu entry so the menubar becomes the legend that teaches the keys.

⚠ **Control chords only, and this is measured, not stylistic.** `$top.tb.temp` takes focus and owns `<Return>` and `<FocusOut>`; a bare `bind $top <Key-r>` fires *while you are typing `r` into the temperature field*, because Entry's class `<KeyPress>` is `tk::EntryInsert` with no `break` and the toplevel is in the entry's bindtags.

⚠ **The source's stated reason for having no chords is false for this window.** `:633` says *"a KEY CHORD would need a csv row AND an `action_registry[]` entry in callback.c"*. That requirement applies to chords on the schematic **canvas**; `wave_viewer.tcl` binds five on a plain Tk bindtag with no csv row and no C entry.

⚠ **Do not label Ctrl+4.** See §0.8 — it is bound on `.drw`, not on ASE-L.

Proposed Tier 1, all yours to pick: `Ctrl+R` Netlist and Run, `Ctrl+Shift+R` Run, `Ctrl+.` Stop, `Ctrl+L` Log, `Ctrl+S` Save State, `Ctrl+O` Load State, `Ctrl+D` Design Window, `Ctrl+W` Close (already bound at `:322` — a label, not a new binding). Two collisions to flag: `Ctrl+D` is Graph > Clear All in the waveform viewer, and `<Control-W>` at `:323` already spends **Ctrl+Shift+W** on a duplicate of Ctrl+W.

**Plus four keys in the panes, all keyboard twins of shipped mouse gestures:** `<Delete>` → `delete_selection` (which already works in exactly one of ASE-L's four tables, the Model Files list at `:5309` — the internal inconsistency is what teaches you to stop trying); `<Key-Return>` → the row's edit dialog, twin of `<Double-1>` at `:865`; `<Key-space>` → toggle the focused row's flag; `<Shift-F10>`/`<Key-Menu>` → post the context menu. The Outputs pane has **two** flags per row, so space is ambiguous there — that is part of R-9.

**And the size knob's widget.** `ase::ui::set_font_size n` re-running `ase::theme`, plus an `aA` control reusing the RDW's already-ratified behaviour and tooltip string verbatim. ⚠ **R-10: where it lives.** `test_ase_window.tcl:1444` and `:1455` (`W1s2`/`W1s2b`) require every child of `$top.strip` to carry a `strip_tips` entry **and** `strip_tips` keys to equal the packed buttons in order — so a ninth strip button reds two checks unless the tip table grows with it. The status bar or a Setup menu entry costs nothing.

**Files:** `:493-700` (labels + accelerators + underlines), one new proc, `build_pane:865-880`. **≈ +85.**

**Suites:** `W1s2`/`W1s2b` if the `aA` goes on the strip. Otherwise none.

---

## Stage 7 — The menubar becomes an inventory, and the tutorial gets a door

**The single clearest "unfinished" tell in the window is `Launch → (placeholder)`** — a permanently disabled cascade at the far left with that literal string as its only entry (`:496-499`).

1. **Drop `Launch`. Add `Help`.** Virtuoso ADE-L's menubar is *Session, Setup, Analyses, Variables, Outputs, Simulation, Results, Tools, Help* — nine cascades, with Help, with no Launch. The transcription is one substitution from correct.
2. **`Help → ASE-L Tutorial`** opens `doc/ase_l_tutorial.html` through the existing in-tree/installed fallback at `xschem.tcl:11787`. Verified: the file is **28,537 bytes**, `doc/Makefile:9` installs it via the `*.html` glob, and the **only** reference to it anywhere in the tree is `tests/headless/test_wave_grid.tcl`. Nothing in `src/` opens it. The schematic window directly below ASE-L in `ase_root.png` ends its menubar at Help; ASE-L ends at Tools. Same fix, same door, for `doc/waveform_viewer_guide.html`.
3. **Fill the two single-entry menus rather than folding them.** Analyses gains Enable / Disable / Delete beside `Choose…`; Variables gains `Add…` and `Delete` beside `Edit…`; Outputs gains `Setup…` / `Edit…` / `Delete` above its two cascades. Every one of those verbs **already exists and is already wired** — to right-click menus and glyph buttons only. Rename nothing.

⚠ **The scoping trap:** `delete_selection` scans **all three panes**, so a menubar Delete under Outputs would happily delete a selected Variables row. Give it a pane argument, or grey it from a `-postcommand`.

**Rulings — R-11:** removing a visible menu and adding one are both yours; every new entry label is user-facing copy (all of them are ADE-L's own words, but they still need ratification); and the About text, if you want an About at all.

**Files:** `:493-700`. **≈ +85.**

**Suites:** `test_ase_window.tcl` W1m asserts the nine cascades in order and that Launch is disabled — **this stage moves that check by design**, and the spec sentence `doc/claude/specs/ase_l.md` "Menu tree (v2)" needs the same edit in the same commit.

---

## Stage 8 — Words on the action strip. Last, deliberately.

Eight classic Tk buttons, `-width 5`, reading `OP,TR = --> X N&> > ! ~`, whose own source comment at `:756` calls them *"text placeholders"*. `N&>` sits **directly above** `>`; they differ by two characters; the wrong one silently simulates a stale deck.

The RDW, one window away in `three_windows.png`, already solved this exact problem with words you have lived with: `Up Down Delete Add Save · aA · Close`.

**Proposed, ADE-L's verbs, terse, acronyms uppercase, unratified:**
`Analyses / Variable / Output / Delete / Netlist+Run / Run / Stop / Waves`

**Costed honestly.** The strip is 72 px of a 798 px window today (9%). A word column at the widest of those labels is 60–80 px *more*, permanently, at every size. Against that: the strip is currently a full-height 452 px column of empty grey at any size above ~500 px tall (measured: `reqheight` 232 in a 452 px slot).

**And the run controls get a state**, which is half the value: no strip button ever changes state today — Stop, Run and Plot are live at all times and report their refusal into a CIW nobody is looking at. Grey `Netlist+Run` and `Run` and un-grey `Stop` while `ase::ui::run_busy $key` is non-empty. That is also what makes the accidental second press — the double-launch race issue 1389 had to be written to survive — rare rather than normal.

**This lands last** because it is the one edit you will experience as *"you changed my window"* rather than *"this got better"*.

**Suites:** `test_ase_window.tcl:1391` (`W1s strip buttons in order`) pins the eight `-text` values and moves. `W1s1`–`W1s6` (the 1391 tooltip table) stay green as long as the widget *names* do not change — they must not.

**Ruling R-12:** eight new labels.

---

# FUNCTION

These are correctness. None of them will read as "slick" in the first ten seconds. I claim they are what you actually meant anyway — the specific complaint about a daily tool is never really about kerning; a window that shows you a setting and then silently does not use it is not an ugly window, it is a window you cannot trust.

## Stage F1 — One producer for the pane and the deck

**The best single idea anywhere in the three proposals, and the only structural close of the window's worst defect.**

Add `analysis_line {a}` as an **optional** backend hook. Optional is already established: `capabilities`, `op_param_set` and `op_param_enumerable` all ride in the backend dict and are absent from `ase::register_backend`'s required loop (`src/ase.tcl:665`, which requires exactly `render_deck run_cmd log_file result_probe raw_file`), so this costs no contract change and only one backend is registered.

- `render_deck`'s three arms (`src/ase.tcl:10961-10966`) call it: `lappend lines [ase::analysis_line $a]`.
- `arg_summary` (`src/ase_window.tcl:1071`) calls it and renders the result, falling back to today's `key=value` dump when the in-force backend declares no hook.

**Land it as a pure refactor whose first version reproduces today's emitter byte for byte.** Prove `gold/cmos_example.spice` unchanged. From that moment on it is *structurally impossible* for the pane to show a setting the deck does not carry.

**What you see:** the Arguments column shows `tran 10n 200u`, `ac dec 10 1 1G`, `dc V2 0 1.8 0.01` — literally the line in the deck — instead of `step=10n stop=200u`.

**Files:** `src/ase.tcl:10961-10966` + the backend dict; `src/ase_window.tcl:1071`. **≈ +34.**

**Suites:** two golden strings move — `test_ase_window.tcl:525` (P4) and `test_ase_dialogs.tcl:492` (G2). Both are display strings, not deck output.

**Ruling:** none. This change is rendering only, by construction.

## Stage F2 — The answer column reads the answers

**Ungated from F5** — deliberately, against Proposal 2's own sequencing. This is small, safe, and it is the column the window exists to show; F5 is a migration that moves every existing raw. Chaining them is how the good one never ships.

One named proc fills the `results` session attr from the raw's log via the existing `log_file` + `result_probe` hooks, called from `ase::ui::open`, from `rsel_commit` (`:3549`) and on state load; `load_state_commit` **clears** it first; the display is gated on `ase::has_results` (`src/ase.tcl:7691`), which already answers *"is this raw at least as new as the deck it claims to describe"* and was written for exactly this class of silent-wrong-data (issue 0838).

**What you see:** open yesterday's bench and `VBG = 1.177085` is in the pane instead of blank. `Results > Select` repoints the column at another run's numbers without re-running — which is what that menu item *means* in ADE-L; today `rsel_commit` regenerates the viewer, writes a status sentence, and never touches `results`. And Load State stops showing the previous state's numbers under matching output names, which in a corner sweep — where states share output names by construction — means reading the wrong corner's answer.

**Files:** `src/ase_window.tcl` — a new proc near `refresh_output_values:1600`, three call sites. **≈ +28.**

**Suites:** `test_ase_window.tcl:1381` (`W1p id output row Value blank pre-run`) must stay green — it will, because a pre-run fixture has no raw and `has_results` returns 0.

**Ruling:** only if you want a stale-result marker.

## Stage F3 — Five real status states

`set_status` (`:6968-6981`) gains a `stopped` arm and a `preparing` arm; `do_stop` sets a session flag that `run_finished` reads instead of scoring CHILDKILLED as failure; `populate` resets a stale `fail` from `ase::has_results`. The three bare X11 colour names (`orange` / `Green` / `red`) move into `ase::palette`.

**Also: the blind gap between press and launch.** `set_status running` fires inside `run_started`, *after* the design routing, the whole hierarchy netlist, `op_annot::save_cards`, the precheck and `sim_probe_run` — whose budget is `ase::cap_budget_ms 30000`, and `src/ase.tcl:3019-3022` records the measurement on your own build: *"447 ms cold, 0 ms warm — and 31.2 seconds for a program that exists, is executable and never answers."* For all of it the bar reads `Status: Ready` and the window does not repaint. Set `preparing` as the first statement of `do_run` **below** `run_busy`'s refusal (above it would redden a session whose earlier run is alive — the exact defect 1389 fixed, pinned by `test_ase_window.tcl:3220`/`:3236`).

**Plus elapsed time.** The clock already exists: `t0 [clock milliseconds]` at `src/ase.tcl:7381`, with exactly one consumer — the log footer `=== exit 0 after 8.12 s ===` (`:7476`), written after the fact into a file. Expose `ase::run_elapsed $key` and tick a `T+MM:SS` segment from an `after 500` reschedule. A transient that normally takes 8 s and today takes 400 s because gmin stepping is thrashing is currently indistinguishable from a live one.

**Suites that move, precisely:** `test_ase_interact.tcl:420`, `test_ase_persist.tcl:649`, `test_ase_plot.tcl:315` (`Status: Ready`), `test_ase_window.tcl:2547` (`Running`), `:2558` (`Ready`), `:2894` (`Error`) — **six checks in four suites** — plus the six light-colour assertions at `test_ase_plot.tcl:316`, `test_ase_interact.tcl:421`, `test_ase_persist.tcl:650`, `test_ase_window.tcl:2546`/`:2557`/`:2892`/`:3236`.

⚠ **Do not touch `ase::ui::status_text`.** It joins five named segments and its exact strings are asserted by `test_ase_savestate_adopt.tcl:162`/`:193`/`:195`, `test_ase_launch.tcl:233`, `test_ase_simdlg_0937.tcl:1101-1158` and `test_ase_window.tcl:1626`. Truncate at the **display** level only.

**Ruling R-13:** the five words (proposed: **Ready / Running / Done / Failed / Stopped**) and three new palette colours (proposed, all >8:1 against the black text they carry: `statusrun #ffb000`, `statusok #7fd67f`, `statusbad #ff8080`). Note the collision this exposes: `accent #8b0000` is currently both "pane title" and, informally, "something is wrong" — do not reach for it as the fail colour.

## Stage F4 — The analysis form stops lying

Extend `analysis_line` to emit ngspice's optional positional tokens only when non-empty and in positional order with the dependency honoured (`tmax` without `tstart` must substitute `tstart 0`, not shift a number into the wrong slot); append non-`{type,enabled,quick-field}` keys as a tail exactly as the `.options` emitter at `src/ase.tcl:10564-10566` already does; and **refuse at OK any option that cannot be emitted, rather than storing it.**

Then give `chana_fields` a real per-type set: **tran** — Stop Time (s), Step (s), Start Time (s), Max Step (s), `[ ] Skip initial DC (UIC)`; **ac** — Sweep Type (dec/oct/lin), Points, Start Freq (Hz), Stop Freq (Hz); **dc** — Sweep Variable, Start, Stop, Step; **op** — nothing, correctly. Two details that cost nothing: the Points label follows the sweep type (`Points/Decade` — today it is hardwired to `Points:` while the number means points *per decade*), and a static unit label sits beside each entry.

Keep the Name/Value bag, demoted to what an escape hatch is for — genuinely unknown keys. It is now honest, because they get emitted.

**Plus two state-machine bugs in the same dialog:** a radio click discards what you just typed (recorded decision D4 at `:4098`) — fix with a per-**dialog-lifetime** cache `dlg($key,anform,<type>)` that only ever feeds the form and never state, plus an **Apply** button; and `chana_ok` searches for the *first* row of the type and edits that, so **the dialog can never create a second `dc`** — a bench sweeping both VIN and temperature cannot say so through any control in the program. `pane_dblclick` already knows the row index and throws it away at `:1006`.

**Rulings — the heaviest cluster in the plan:** every field label, every unit string and the UIC caption are new user-facing sentences (**R-14**); the reversal of recorded decision D4 (**R-15**); and **R-16**, the migration — the 104 committed `.state` files may carry stored keys that would suddenly become **live simulator input**.

## Stage F5 — The state axis exists on disk

`ase::rundir` (`src/ase.tcl:4812`) derives from lib/cell/view instead of falling through to `set_netlist_dir 0`; add a **Run Directory** row to `Setup > Design…` with `dict set st rundir <path>` + `ase::session_update` as its writer — today `rundir` is *read* in two places and has **no writer anywhere in the tree**.

**What it fixes:** two states of one cell stop sharing one deck, one raw and one log. Nominal can sit open beside a corner, both can run, and each window keeps its own numbers, its own log, and its own honest answer to *"are these results current?"*.

**Ruling R-17, and it is a real migration:** existing benches' raws live in the shared directory; this moves where every new one lands, and it touches the waveform viewer's Recent history and the annotation path. Its own timeline, its own evidence.

---

## The ruling ledger — batch these, ask once

Your ledger already stands at **127 rule, 45 look, 7 suite**. Adding thirteen questions one at a time as each stage happens to finish would be the exact failure the ledger was built against. File them as one batch under a single issue (`doc/claude/issues/1396-*`, per `NUMBERING.md`, whose tail says **the next free number is 1396**), then `owed.sh add rule 1396`.

| # | Stage | The question | My recommendation |
|---|---|---|---|
| R-1 | 2 | Dialog button cluster: trailing edge (RDW's shape) or leading edge (Cadence's form banner) | Trailing — it is in this tree and you have lived with it |
| R-2 | 2 | Is the Log window transient with ASE-L, or parkable on its own? | Parkable — exclude it |
| R-3 | 4 | `disabledfg #a3a3a3` (1.79:1) → ? | `#595959` — 4.96 / 6.26, both pass AA |
| R-4 | 4 | `header #e8e8e8` (1.09:1 off panel) → ? | `#d4d4d4` — 1.32 / 1.48, heading text 14.17:1 |
| R-5 | 4 | A row-band tone, and a tenth palette key or a derivation | `#f7f7f7`, 1.07 off table |
| R-6 | 4 | A dark ASE-L palette — nine values, plus its own accent | Defer; Stage 1b already makes the shipped dark scheme legible |
| R-7 | 5 | Focus-ring colour | `selectbg #4a6984` — already in the dict, already means "you are here" |
| R-8 | 5 | The overwrite-confirm sentence | `State <lib>/<cell>/<view> exists. Overwrite?` |
| R-9 | 6 | The chord table, and which key toggles Plot vs Save | Control chords only (measured: a bare letter is typed into the temperature field) |
| R-10 | 6 | Where the `aA` size control lives | Status bar or Setup menu — **not** the strip (`W1s2`/`W1s2b`) |
| R-11 | 7 | Removing `Launch`, adding `Help`, and every new menu label | ADE-L's own taxonomy and words |
| R-12 | 8 | Eight strip labels | `Analyses / Variable / Output / Delete / Netlist+Run / Run / Stop / Waves` |
| R-13 | F3 | Five status words + three status colours | Ready / Running / Done / Failed / Stopped |
| R-14–17 | F4, F5 | Analysis field labels and units; reversing D4; the `.state` key migration; the rundir migration | Their own batch, their own evidence |

**Look debts** (`owed.sh add look`), each cleared only by your eyes on your own display: Stage 1 (every glyph in the window changes; `:99`'s scaling is not yours); Stage 2 (dialog placement is WM-decided and your WM is not openbox); Stage 4 (surface depth is the change a user experiences as *"you redesigned my window"*); Stage 8 (the strip).

---

## What this plan refuses, and why

**No ttk theme swap.** `ttk::style theme use` is **process-global** and would reach every `ttk::combobox` in xschem — 45 constructor lines across eight files, 17 of them in `xschem.tcl`. `clam` would give the whole application a flat look in one line and it is not ASE-L's decision to make. The six scrollbars become ttk so that a table and its own scrollbar are drawn by the *same* theme; the 3D `default` theme stays underneath everything.

**No option-database tier, and no `toplevel -class Ase`.** Proposal 1's tier is well-engineered — I confirmed the class-specificity argument holds — but its own stated user-visible effect is *"None intended: every `cget` answers the same value it does today"*, it is the largest refactor anyone proposed, and its headline justification (the live tooltip) is fixed in **two lines** by §1f. It also opens a process-global of its own: `option add` is additive and never removed, so entries accumulate under a rising N for the life of the process. Revisit it as the *enabling* refactor for R-6, a dark palette — not as a prerequisite for the forty lines that need no ratification. And `-class Ase`, the textbook Tk way to scope it, would silently empty four window enumerators: `test_ase_window.tcl:118` and `:127`, `test_ase_launch.tcl:37`, `test_ase_plot.tcl:231`, `test_wave_viewer.tcl:478` all filter on `winfo class $w eq {Toplevel}`.

**No `ttk::panedwindow` for the three panes.** The frozen 1:2 / 1:1 split is a real defect — Design Variables owns an acre of white at 1500×900 while Outputs is welded to half the right column — but a panedwindow manages only **direct** children, so `$top.body.ana` must become `$top.body.right.ana`. Measured: **30 references across five named suites** (`test_ase_window`, `test_ase_interact`, `test_ase_dialogs`, `test_ase_launch`, `test_ase_persist`) plus **14 in `src/`**, plus `build_pane:844` which derives `$pf` as `$top.body.$pane`. Proposal 2 costed this at zero and claimed the paths survive; they do not. The path-preserving 80% lands in Stage 2 instead: `grid rowconfigure -minsize` and `-weight 2` on the Outputs row.

**No icons on the strip.** Four exact 24×24 photos are already loaded in the process (`ximgEditDelete`, `ximgSimulate`, `ximgNetlist`, `ximgWaves` — note the `x` prefix, `src/resources.tcl:224/529/540/552`) and `image create photo -data <base64 PNG>` is verified working, so this is tempting. Refused because you cannot read `N&>` for want of **words**, not for want of pictures; because three more glyphs would have to be authored, judged by one analog designer; and because an icon strip re-creates the `N&>`-versus-`>` discrimination problem in a new alphabet. The RDW already proved words work here. ⚠ If anyone reaches for it later: `-width 5` is **characters** for a text button and **screen units** for an image button.

**No new message surface under the panes.** The window is genuinely mute — 76 `ase::echo` sites in `ase_window.tcl` and 68 in `ase.tcl`, all posted to a CIW that was not on the desktop in `ase_root.png`, plus 51 sentences in `ase::sim_why` (median 163 characters). The refusal path makes it explicit: `ase::run_refuse` echoes and then calls `ase::run_ciw_raise`, so the remedy for *"you cannot see the message"* is to raise a third window, which with no CIW does nothing at all. Lifting `rdw::status` / `.rdw.s.msg` (`rdw.tcl:2228`) into ASE-L is the right fix and it is an addition, not a repair — its own batch, its own angle.

**No extraction of the shared Library/Cell/View browser**, though ASE-L's is the tree's third copy and the least capable — ~20 checks rewritten against a different widget API.

**No fix for `Setup > Design…`'s missing Run Directory row** outside F5, no `Model Files` / `Simulation Options` button row (their Add/Edit/Delete are hidden on `<Button-3>` with no `<Double-1>` at all, while `Simulators…` one entry away shows real buttons), and no removal of Save All's permanently disabled `Levels:` field (`:5719` builds it, `:5734` kills it after theming). All small, all real, all queued behind the stages above.

**And it refuses to be quick.** Thirty-odd changes across a 7,491-line file is not a weekend. **The discipline is the deliverable:** Stages 1–3 move no test and mint no sentence and can land this week; look debts are recorded and shown before anything is called done; every ruling goes into one ledger you answer once. Anyone who reads "finish the window" as "one afternoon of polish" will land half of it, leave the sequencing broken, and produce a window that is inconsistent in new ways instead of old ones.

---

## Sequencing at a glance

| commit | stages | lines | rulings | tests moved |
|---|---|---|---|---|
| 1 | **1** — fonts, foreground, active state, columns, combobox glob, balloon guard | +97 / −11 | 0 (one `look` debt) | **0** |
| 2 | **2** — dialog discipline, minsize, ttk scrollbars, padding | +75 / −12 | R-1, R-2 | 0 (95 `.btns.` refs stay by path) |
| 3 | **3** — ellipsis, tooltips, horizontal scroll | +52 | 0 | 0 |
| 4 | **F1** — `analysis_line`, byte-identical refactor | +34 | 0 | 2 display strings |
| 5 | **F2** — Value column from disk | +28 | 0 | 0 |
| 6 | **4** + **5** — depth, loss prevention | +56 | R-3…R-8 | 1–2 (`:1386`) |
| 7 | **6** + **7** — keyboard, menubar, Help | +170 | R-9…R-11 | W1m, `W1s2` if `aA` is on the strip |
| 8 | **8** + **F3** — strip words, status states | +36 | R-12, R-13 | `:1391`, plus 12 status checks in 4 suites |
| later | **F4**, **F5** | +54 | R-14…R-17 + migrations | own batch |

**Stage 1 alone is one rebuild, ~97 lines, zero rulings, zero suites moved — and it is the whole of what you are looking at when you say the fonts could stand to improve.** Stage 2 must not be skipped, and Stage 1e must not be split from Stage 1a: derived bold needs 104 px for the `Save Options` heading and its column is pinned at 90.
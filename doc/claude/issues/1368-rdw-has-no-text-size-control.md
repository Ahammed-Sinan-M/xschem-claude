# 1368 — the Results window had no text-size control, and the two obvious ways to add one are both wrong

**Status: FIXED, then REFUTED by adversaries, then REPAIRED.** Subject:
`src/rdw.tcl` (the whole `rdw::font_*` / `rdw::_font*` family, `rdw::build`,
`rdw::_focus_click`'s own sentence), `src/xschem.tcl` (`set_ne rdw_font_size
0`, and the screen clamp in `balloon_show`). Fenced by section **FZ**
(FZ1..FZ18) of `tests/headless/test_rdw_window_1245.tcl`, `RW_FLOOR` 168 → 172
→ **186**.

**Read [What the adversaries found, and what the repair changed](#what-the-adversaries-found-and-what-the-repair-changed)
before the rest of this file** — three of the paragraphs below describe the
build that was refuted, and are marked where they do.

## The user's words, verbatim

> enhancement : add a button to allow user to manipulate font size in RDW. it
> can be the "aa" button you see in e-readers - 2nd a bigger. Key part, as soon
> as user hovers over it, tooltip should be displayed : click to increase font
> one unit. Ctrl+click to decrease font one unit

## What was there

Nothing. `.rdw.p.t` was created `-font TkFixedFont` (`src/rdw.tcl:2552` at the
time) and the `hdr` tag was `set hf [font actual TkFixedFont] ; dict set hf
-weight bold` (`:2567`). There was no size door of any kind, and the two
one-liners that look like they would add one are both defects.

## What was measured

All runs `tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --logdir
<scratch> --script <probe>` on `:99` (Xvfb 1920x1080x24, openbox live), Tcl/Tk
8.6.17, DejaVu Sans Mono. The user's `/tmp/Xschem.log.8` was not written.

### 1. `font configure TkFixedFont -size N` is a GLOBAL control wearing a window-local label

```
bare text   default -font: TkFixedFont     <-- the collateral
bare label  default -font: TkDefaultFont
bare button default -font: TkDefaultFont
```

`TkFixedFont` is the default `-font` of **every bare `text` widget in the
tree**: the attribute editor (`xschem.tcl:10674`, `:10839`), the
symbol-property editor (`:11692`), the text-input dialog (`:13190`), editpaths
(`:9454`), the graph dialog (`:6365`), the notify popup (`ciw.tcl:155`) and the
calculator buffer (`calculator.tcl:1503`). One click on an RDW button would
have resized all eight, with nothing on screen saying so and no suite in the
tree watching any of those fonts. Row **FZ5** is the only fence.

### 2. The `hdr` tag was a FROZEN SNAPSHOT

`font actual TkFixedFont` answers a font *description*, not a *name*.

```
--- after font configure TkFixedFont -size 16 ---
pane   actual: -size 16 ...    linespace 27
hdr TAG font : -size 10 ...    linespace 17      <-- FROZEN
```

Every block's own header line would have stayed small while its body grew. A
test that reads only `.rdw.p.t cget -font` passes throughout. Row **FZ6**
asserts both, and asserts the tag carries a one-word font *name*.

### 3. The window jumps, because the pane is sized in CHARACTER units

```
BEFORE:  .rdw geom=893x498+1025+557
size=20  req=1636x862  wingeom=1757x914+161+141
```

Nearly the whole screen, re-placed across the desktop by the window manager —
and on a size the window is *built* at, it happens at open time with no click.
Recomputing the pane's `-width`/`-height` from the new metrics holds it:

```
size 11 chars  85x23  geom 890x493      size 20 chars  45x13  geom 890x485
size 12 chars  77x22  geom 895x496      size 24 chars  38x11  geom 885x485
size 14 chars  64x18  geom 893x488      size 32 chars  28x8   geom 881x480
size 16 chars  59x16  geom 892x488      size  6 chars 154x44  geom 895x496
size 10 chars  96x26  geom 893x498  <-- returns EXACTLY to stock
```

Sixty real clicks (thirty to the ceiling, thirty to the floor) and four back to
the base returned the toplevel to `893x498`, the position drifting 10 px in x
and 20 px in y — window-manager placement, not the control. Row **FZ9**.

### 4. `font actual <f> -size` is NOT a round trip

```
pixels -14 -> actual size=10          <-- a PIXEL spelling read back as POINTS
after +1 on -14 -> size=11            <-- silently became 11 points
size 0 -> resolves to 12, raises nothing
size 1 -> linespace 3      size 200 -> linespace 325, accepted without error
```

So the model is the integer and the code never reads a size back out of a font.
And `0` is a **live** size, not a neutral one — it is safe as the "not chosen
yet" sentinel only because `rdw::_accept_size` can never answer it. Row **FZ2**.

### 5. `--nogui` has no `font` command at all

```
$ ./src/xschem --nogui --pipe -q --script m7.tcl
Tcl_AppInit() error: ... invalid command name "font"  Line No: 1
```

Which is why the counted half of section FZ is pure model and every row that
asks a real font is display-gated.

### 6. The tree has exactly ONE tooltip mechanism

`balloon` / `balloon_show`, `src/xschem.tcl:14238` and `:14253`. No proc named
`tooltip`, `set_tooltip` or `Balloon` exists anywhere. `balloon` bakes a fixed
string into `<Enter>`, which is exactly the shape this fixed tip needs, so no
new machinery was written.

### 7. …and its tip ran off the screen

Measured **after** the button landed, and it is this item's own deliverable
failing:

```
button rootx 1815, tip 564x24, wanted right edge 2379, screen 1920x1080
```

The aA button sits at the foot of a button column on the **right** edge of its
window and `balloon`'s `pos 1` anchors the tip at the widget's **left** edge, so
more than half of the user's own sentence was off the display — on the part they
called "the key part". `pos 0` is no answer: the pointer is in the same place.

## What changed

### `src/rdw.tcl` — the model (no Tk anywhere in it)

| proc | what it is |
|---|---|
| `rdw::font_limits` | `{6 32}`, the band, in ONE place |
| `rdw::_accept_size` | the ONE admission test — **refuses**, never clamps |
| `rdw::_chosen_size` | the user's choice, or `{}` |
| `rdw::_shared_size` | TkFixedFont's own size, RAW, or `{}` (added by the repair) |
| `rdw::_base_size` | that size, clamped into the band |
| `rdw::font_size` | the effective integer |
| `rdw::set_font_size` | the ONE setter, order-independent |
| `rdw::font_step` | the ONE arithmetic door (`+1` / `-1`) |
| `rdw::_font_tip` | the tooltip string, once |

`rdw::_accept_size` is deliberately **not** called `_clamp_size` (the driver's
plan named it that): a name that says clamp over a proc that refuses is this
file's own documented defect — a comment naming a fence that does not fence —
one layer down.

`rdw::font_step` writes **nothing** on the accepted path: the pane visibly
changing is the confirmation, and a status line per click would evict the button
column's real verdicts. At the two limits it must speak, because a visible,
enabled control that does nothing and says nothing is indistinguishable from a
broken one (`rdw::inert`'s standing obligation):

```
Text size: already the smallest (6).
Text size: already the largest (32).
```

**The cost is real and is recorded here rather than hidden**: a refusal
overwrites whatever verdict the button column had just written and the user may
have been reading. It happens only at the two ends, and silence would be the
worse failure.

### `src/rdw.tcl` — the Tk half

* `rdw::_font {pane|hdr}` → `RdwPaneFont` / `RdwHdrFont`, **private** named
  fonts created on first use from `font configure TkFixedFont` (the spelling as
  *configured*, so a pixel-spelled shared font is copied verbatim rather than
  silently converted to points) and never TkFixedFont itself. The family is
  inherited, so the pane stays monospace — the dumps are column-aligned with
  spaces — and an rc that re-families TkFixedFont before the window opens is
  honoured. **⚠ The first build imposed a size only WHILE a choice stood and
  never put one back; see defect 2 of the repair below.** It now sets the size
  on every call: a choice wins, else the band's answer when the band moved the
  shared size, else TkFixedFont's verbatim spelling.
* `rdw::_pane_chars` → the geometry defence: 96 and 26 scaled by the ratio of
  the reference font's metrics to the private font's, recomputed from the
  constants every time so repeated clicks accumulate no drift. No pixel constant
  appears in it; both metrics are asked of the real fonts, exactly as issue 1362
  rules for the status line. The reference is `rdw::_ref_font` — the shared font
  as it stands, or the shared font at the band's answer when the band refused
  its size — **added by the repair; the first build measured against the raw
  shared font, so the clamp bought nothing geometrically.**
* `rdw::_apply_font` → the ONE painter: both fonts, the pane's `-width`/
  `-height`, and a `rdw::_status_show` re-fit. Called by `rdw::set_font_size`
  and at the foot of `rdw::build`.

### `src/rdw.tcl` — the widget

`.rdw.b.fontsize`, a `::button` (the `::` is not style — `rdw::button` shadows
Tk's `button` in this namespace and the collision once hung a whole suite via
`bgerror`), `-text {aA} -width 8 -command {rdw::font_step 1}`, packed
`-side bottom` in the button column with a gap.

* **`aA`, not two rendered sizes.** A Tk button has exactly one font, so the
  "2nd a bigger" is the capital's cap height against the lowercase x-height.
  The two widgets that could really render two sizes — a canvas and a text — can
  both take the keyboard, which issue 1308 forbids for every widget here.
* **It is NOT in `rdw::_buttons`.** That table feeds `rdw::button_state`,
  `rdw::_active_buttons` and `rdw::_active_phrase`, so an entry there would put
  "aA" into the chrome sentence *"only Up, Down, Delete, Add and Save do
  anything"*. A font control is not a list action; it is never greyed.
* `bind <Control-Button-1> {rdw::_focus_click %W ; rdw::font_step -1 ; break}`.
  Measured: the `break` stops the Button class `<Button-1>`, so `tk::ButtonUp`
  never invokes `-command` and exactly one arm fires under Control,
  Control+NumLock and Control+CapsLock. **Without it a Ctrl+click steps down and
  straight back up.** The 0x4c mask `rdw::_digit` uses is deliberately not
  copied — that mask exists so a chord the *canvas* spends is not swallowed.
  **⚠ The first build said "and a button press has no such conflict", and that
  was measurably wrong** — the conflict is with issue 1369's toplevel
  `<ButtonPress>` binding, live in the same tree: `bindtags .rdw.b.fontsize` is
  `.rdw.b.fontsize Button .rdw all` and a `break` in the widget tag's script
  stops `.rdw` too. Hence the explicit `rdw::_focus_click %W`; see defect 1 of
  the repair below.
* `catch {::balloon .rdw.b.fontsize [rdw::_font_tip] 1 0 300}` — the tree's one
  tooltip mechanism, called **once** (it re-binds `<Enter>`/`<Leave>` on every
  call, `calculator.tcl:1119`).

### `src/xschem.tcl`

* `set_ne rdw_font_size 0` beside `set_ne ciw_font_size 10`, with the same kind
  of comment: `0` means "follow TkFixedFont", so an `~/.xschem/xschemrc` can
  pick the starting size without knowing the window's internals.
* **`balloon_show` now pulls a tip that would not fit back on to the screen.**
  A tip that **already fits** is not moved at all. **⚠ The first build then said
  "so none of the tree's other 43 `balloon` call sites changes placement", and
  that sentence is false** — a tip that does *not* fit is moved, and that is the
  point; measured, the main window at the screen bottom moves `.statusbar.2`'s
  tip from `+101+1075` to `+101+1010`. Worse, the first build slid *every*
  overflowing tip left, which for the two `pos 0` call sites in the file browser
  put the tip **under the pointer**, where `balloon`'s own `<Leave>` destroys it
  in the instant it maps. See defect 3 of the repair below. The shipped rule is
  now: a widget-anchored (`pos 1`) tip slides to the screen edge and **flips
  above** its widget vertically; a pointer-anchored (`pos 0`) tip **mirrors** to
  the other side of the pointer; a final guard pushes any tip that still covers
  the pointer clear of it. Both axes are finally clamped to 0, because a
  negative offset in a Tk geometry string means "from the far edge" — an
  unclamped value would not merely be off-screen, it would be on the wrong side
  of the display.

## The rows that fence it — `tests/headless/test_rdw_window_1245.tcl` section FZ

**Counted (both arms), `RW_FLOOR` 168 → 172 → 186:**

| row | what it fences |
|---|---|
| FZ1 | the band is a named accessor and its three consumers ask it by name |
| FZ2 | `_accept_size` refuses rather than clamps; `0` is unreachable |
| FZ3 | `font_step` walks the **model**, refuses at both ends naming the limit, and is silent on the accepted path |
| FZ4 | order-independence with no window; `font configure TkFixedFont -` appears **nowhere**; the one tooltip mechanism is reused |
| FZ12 | the `aA` label, the foot of the button column, the absence from `rdw::_buttons`, and the Ctrl arm naming `rdw::_focus_click` *(repair)* |
| FZ13 | `_shared_size` / `_base_size` / `_ref_font` answer rather than raise with no `font` command, and each reaches the band by name *(repair)* |

**Display-gated, deliberately uncounted (the floor is the arm that runs fewest
rows):**

| row | what it fences |
|---|---|
| FZ5 | two private named fonts; `font actual TkFixedFont` byte-identical across a step |
| FZ6 | the `hdr` tag is a font NAME and follows the body; header bold, body regular |
| FZ7 | a real `<Enter>`+`<Button-1>`+`<ButtonRelease-1>`+`<Leave>` steps exactly ±1, under seven modifier combinations |
| FZ8 | the `<Enter>` binding carries the user's sentence verbatim through `balloon_show` |
| FZ9 | sixty real clicks leave the toplevel within two character cells and two line heights of where it started |
| FZ10 | a close and a reopen come back at the chosen size, character shape included |
| FZ11 | the rendered tip stays on the screen, and a tip that already fits is not moved |
| FZ14 | a real Ctrl+click spends issue 1369's focus one-shot exactly as a plain click does *(repair)* |
| FZ15 | with no choice recorded the pane RENDERS the number the model REPORTS — after a withdrawal, and at both ends of the band *(repair)* |
| FZ16 | the private fonts are monospace and carry TkFixedFont's family *(repair)* |
| FZ17 | `balloon_show`'s vertical flip and its two zero clamps *(repair)* |
| FZ18 | a `pos 0` tip is pulled back on screen without landing under the pointer *(repair)* |

Rows **FZ7** and **FZ8** were re-spelt rather than added: FZ7 gains the live
`-text` / parent / pack-side legs (an adversary re-labelled the button `Zz` and
both arms stayed green), FZ8 gains the **300 ms** delay — the one number in this
item the user has not ruled on, and therefore the one that most needs watching.

**⚠ The `<Enter>` in FZ7 is load-bearing.** Measured: a
`<Button-1>`/`<ButtonRelease-1>` pair with no preceding `<Enter>` fires
*nothing*, because `tk::ButtonUp` checks `Priv(window)`, which
`tk::ButtonEnter` sets. A row written without it passes on a broken plain-click
arm and on a working one alike.

## Sabotages — each row proved non-vacuous, every restore md5-verified

| # | sabotage | RED |
|---|---|---|
| a | `rdw::_font` answers `TkFixedFont` for both surfaces | FZ5 FZ6 FZ10 |
| b | `set_font_size` also does the obvious one-liner on the shared font | FZ4 FZ5 FZ9 FZ10 FZ11 |
| c | the `hdr` tag goes back to the frozen `font actual` snapshot | FZ5 FZ6 FZ10 |
| d | the Control binding no longer `break`s the Button class binding | FZ7 FZ9 |
| e | `_apply_font` stops recomputing the pane's character shape | FZ9 FZ10 FZ11 |
| f | `build` no longer calls `rdw::_apply_font` on its way out | FZ5 FZ10 FZ11 |
| g | `_accept_size` clamps to the band instead of refusing | FZ2 FZ3 FZ4 |
| h | the band silently widens to the CIW's 4..72 | FZ1 FZ2 FZ3 |
| i | the aA button loses its tooltip | FZ4 FZ8 |
| j | `balloon_show` stops pulling an off-screen tip back | FZ11 |

Every restore was by `cp` from a pre-sabotage copy with an `md5sum -c` on all
three touched files.

**And the red set on the genuinely unmodified source** (`git show HEAD:` of
`src/rdw.tcl` and `src/xschem.tcl` copied in, suite unchanged):

```
:99      RESULT: 11 FAILED (204 passed)   red set exactly FZ1..FZ11
--nogui  RESULT:  4 FAILED (179 passed)   red set exactly FZ1..FZ4
```

Baseline before the change: `ALL PASS (204 checks)` on `:99`, `ALL PASS (179
checks)` under `--nogui` — so the 204 and the 179 that still pass are the same
rows, by name, and the diff is exactly the eleven new ones. After: **215** and
**183**.

⚠ **THOSE FOUR NUMBERS ARE STALE AND ARE KEPT ONLY AS A RECORD OF THE FIRST
BUILD.** Sibling crews added rows to this suite afterwards. Measured at the
repair, both arms, md5-bracketed across every run: **ALL PASS (235 checks)** on
`:99` and **ALL PASS (197 checks)** under `--nogui`, with all eighteen FZ rows
green by name. Re-take a suite number before quoting it; do not carry one
forward.

### ⚠ The first spelling of FZ7 could not fire in the red state

MEASURED while taking the number above: `expr {[rw_ans ::rdw::font_size] - $b}`
with `rdw::font_size` absent raised `can't use non-numeric string as operand of
"-"` at global level, which under `--pipe` stops `Tcl_AppInit` **dead** — the
file died at FZ7 and **FZ7..FZ11 reported nothing at all**, on a run that was
supposed to be the evidence. That is item A2's lesson 6 and the whole reason
`rw_ans` / `rw_w` exist, arriving through arithmetic rather than through a call.
Fixed by `fz_int`, by `fz_click` and `fz_tip_geom` refusing a widget that is not
there (`winfo exists` is the one `winfo` call that never raises) and by
`fz_near` refusing a non-integer metric. The red set above is the re-measurement
after that repair.

## Pure Tcl — issue 0424 does not apply

No new file, so `src/Makefile.in` is not touched, `src/Makefile` cannot go
stale against it, and the installed-binary segfault 0424 records is not
reachable from this change. `grep -c rdw.tcl src/Makefile` is still 2 and row
M1 still asserts which two lines they are.

## What the adversaries found, and what the repair changed

Four adversaries read the landed build. **Nothing they found breaks the shipped
gesture** — the `aA` button, the tooltip and the two arms all worked — but three
real defects and five unfenced surfaces came out of it, and one collateral
regression in a SHARED proc reached a window that has nothing to do with this
item. Every claim below was **re-measured here before anything was changed**;
where an adversary was wrong the measurement that refutes them is given.

All repair measurements: `tests/headless/devdisplay.sh exec ./src/xschem --pipe
-q --logdir <scratch> --script <probe>` on `:99` (Xvfb 1920x1080x24, openbox
live), DejaVu Sans Mono. Sabotage runs were taken in a **private full copy of
the tree** with its own binary, because sibling crews were editing `src/rdw.tcl`
in the shared tree at the same time and an in-tree sabotage corrupts their
evidence as well as its own.

### Defect 1 — the Ctrl arm was the ONE gesture that did not spend issue 1369's focus one-shot

`bindtags .rdw.b.fontsize` is `.rdw.b.fontsize Button .rdw all`. The Ctrl arm's
`break` is there to stop the **Button class** binding (row FZ7), but a `break`
in a *widget* tag's script stops **`.rdw`** as well — and `.rdw` is where issue
1369 binds `<ButtonPress>` → `rdw::_focus_click`, the disarm that tells the
user's own click from the window manager's focus grant.

Re-measured here, on the landed build, through real gestures on `:99`:

```
plain click on .rdw.b.fontsize   armed=1  focus_pending after = 0
Ctrl+click on .rdw.b.fontsize    armed=1  focus_pending after = 1   <-- the defect
click on .rdw.b.up               armed=1  focus_pending after = 0
click in .rdw.p.t                armed=1  focus_pending after = 0
```

Downstream, with the one-shot left armed, the next focus grant into `.rdw` fires
`rdw::_focus_handback` → `rdw::_focus_canvas` and the keyboard ends on `.drw`,
the schematic canvas — where after the plain click it ends on `.rdw`. **Two arms
of one button leaving the keyboard in two different windows.** And
`rdw::_focus_click`'s own comment said the toplevel binding covered "the pane,
the status surface, the five buttons, the `aA` button and the frame", which was
false for the Ctrl arm: a comment naming a fence that does not fence, which is
the exact defect class this item renamed `_clamp_size` to avoid.

**Fixed** by `{rdw::_focus_click %W ; rdw::font_step -1 ; break}` — the script
pays back by hand what its own `break` costs. `rdw::_focus_click` neither
`break`s nor moves the focus, so this is exactly what the toplevel binding would
have done. `rdw::_focus_click`'s comment now names its one hand-caller. After:
`plain 0 / ctrl 0 / ctrl-num 0`, deltas still `+1 / -1 / -1`. Fenced by **FZ14**
(behaviour) and **FZ12** (the script, on both arms).

The alternative shape — moving the Ctrl arm to `<Control-ButtonRelease-1>` and
letting the press fall through — was **rejected**: with `<Control-Button-1>`
unbound the Button class binding runs, `tk::ButtonUp` invokes `-command`, and a
Ctrl+click becomes `+1` then `-1`, i.e. the defect row FZ7 exists about.

### Defect 2 — `rdw::_font` could impose a size but never put one back

It configured the private font's `-size` only while `rdw::_chosen_size` answered
something. The private fonts outlive the widget and the window, so a **withdrawn
choice never reached the screen**. Re-measured on the landed build:

```
rdw::set_font_size 20      model 20   pane 20
set ::rdw_font_size 0      model 10   pane 20   chars 45x13   <-- disagree
next PLAIN click (+1)      model 11   pane 11                 <-- text SHRINKS on '+'
```

The same hole ran the other way through `rdw::_base_size`'s clamp, on a door
this file's own comment advertises as honoured (`an ~/.xschem/xschemrc that
re-sizes … TkFixedFont … is honoured`):

```
font configure TkFixedFont -size 40, no choice made
  rdw::font_size  -> 32      pane renders -> 40
  plain click     -> refuses "Text size: already the largest (32)."  at 40
  Ctrl+click      -> 40 -> 31 in ONE click, under a tooltip promising one unit
```

The suite **knew**: section FZ's clean-up hand-configured `RdwPaneFont` /
`RdwHdrFont` back to `rdw::_base_size` after restoring the sentinel. The
work-around was living in the test instead of in the code.

**Fixed** in three pieces, all one rule:

* `rdw::_shared_size` — the shared font's size, RAW and unclamped, or `{}`.
  Split out so callers can ask whether the band actually *moved* it.
* `rdw::_font` now sets `-size` on **every** call: a choice wins; with none, the
  band's answer wins when the band moved the shared size, and TkFixedFont's
  **verbatim configured spelling** wins when it did not — so a pixel-spelled
  shared font is still not silently converted to points (measured: `-14` stays
  `-14`).
* `rdw::_ref_font` — the metric `rdw::_pane_chars` scales against, under the
  same rule. Without it the clamp bought nothing geometrically: the pane
  rendered the clamped 32 while the reference was still the raw 40, so the
  toplevel asked for **3284x1752** on a 1920x1080 screen.

After the repair, at `font configure TkFixedFont -size 40`: model 32, pane 32,
`_pane_chars` back to `96 26`, toplevel **2717x1434**; at `-size 72`, still
**2717x1434** — the band now caps the growth. Withdrawal: model 10, pane 10,
chars `96 26`, `893x498`. Fenced by **FZ15** (behaviour) and **FZ13** (both
arms). The section clean-up's work-around is deleted and replaced by a call
through `rdw::_font` itself.

**Honest residue, measured:** an rc that sets `TkFixedFont -size 40` still opens
this window wider than a 1920 px screen — 96x26 cells at size 32 is ~2300 px of
pane. That is **not** a regression: the pre-1368 code built the pane
`-width 96 -height 26 -font TkFixedFont`, whose requested size at TkFixedFont 40
measures **3172x1720**. Capping it would need a pixel constant, which issue 1362
forbids in this file. Named here rather than hidden.

### Defect 3 — the shared `balloon_show` broke the file browser's two tooltips

The first build slid **every** overflowing tip left to the screen edge. For a
`pos 0` (pointer-anchored) tip that puts the tip **under the pointer**, and
`balloon`'s own `<Leave>` binding destroys `%W.balloon` — so the tip is torn down
in the instant it maps and the `<Enter>` that follows re-arms it. The tree has
exactly two `pos 0` call sites and both are in the file browser, both with wide
multi-line tips: `src/xschem.tcl:9659` (`.ins.center.leftdir.l`) and `:9674`
(`.ins.center.left.l`), both `0 1 3000`.

Re-measured here on a real widget with a real `balloon` binding — the aA button
itself, `pos 0`, pointer warped on to it at the right of the screen:

```
landed build   shows = 25   tip visible  2/60 samples
repaired       shows =  2   tip visible 58/60 samples
```

And on a listbox carrying `xschem.tcl:9674`'s tip **verbatim**, one process,
same widget, same pointer at x 1851 on a 1920 px screen:

```
mid-1368 (slide every tip)   shows = 16   visible  0/40   geometry never observed
repaired                     shows =  1   visible 38/40   555x104+1276+346
```

and against HEAD's own `balloon_show` at x 1691, which is the other half of the
comparison:

```
HEAD       557x106+1711+346   right edge 2268 on a 1920 px screen  (off-screen)
repaired   555x104+1116+346   fully on screen, left of the pointer
```

`file_chooser(geometry)` is persisted (`xschem.tcl:9923`/`:9956`), so a user who
once parked the browser to the right kept the broken state.

**Fixed**: `pos 1` slides to the screen edge (unchanged, FZ11 still green);
`pos 0` **mirrors** to the other side of the pointer; and a final guard moves any
tip that still covers the pointer clear of it. Fenced by **FZ18**.

### What the adversaries got wrong

* **"`_base_size` clamps instead of refusing"** — the clamp is right and stays.
  A value the user did not choose has nobody to refuse *to*; refusing would make
  both arms of the button dead with a message naming a bound the pane is not at.
  The defect was the *disagreement*, not the clamp, and defect 2 fixes that.
* **"the write-up's balloon claim is false"** — correct about the sentence,
  wrong about the code comment, which already said "a tip that already fits is
  not moved". The sentence in this file is corrected above; the code was right.
* **`rdw::_active_phrase` still says "only Up, Down, Delete, Add and Save do
  anything"** — **rejected, not fixed.** That sentence is rendered only for list
  3 (`rdw::_chrome_text`, `kind eq {all}`), inside `Keys 1/2/3: … press 1 or 2
  to edit a list; …`, and its subject is which buttons **act on this list**. A
  font control is not a list action, is never greyed and never refuses on a list
  identity — which is exactly why it is not in `rdw::_buttons`. Rewording it
  would move issue 1355's copy and its goldens across two suites to make a
  sentence about list actions mention a control that performs none. Row FZ12
  now asserts the phrase never names `aA` — for all three list identities, read
  out of `rdw::_digit_map` rather than spelt — so the reasoning is fenced rather
  than merely argued. Sabotage **S13**, which puts the control INTO
  `rdw::_buttons`, reds **31 rows** including LX12, the row that owns that
  sentence: the table is load-bearing in both directions.
* **the SL11 flake and the contaminated `rdw.tcl.good` snapshot** — neither is
  this item's. Both are recorded for the driver in the crew report; SL11 is
  issue 1365's row and the snapshot belongs to another agent's scratch dir.

### The five unfenced surfaces, now fenced

| what had no witness | how an adversary proved it | row |
|---|---|---|
| the button's `aA` label and its place in the column | `-text {Zz}` → both arms green | FZ7 + FZ12 |
| `_base_size` reading TkFixedFont at all | probe body → bare `set n 10` → both arms green | FZ13 + FZ15 |
| the pane font being MONOSPACE | `-family Helvetica -size 10` → caught only incidentally by FZ4's cell count | FZ16 |
| `balloon_show`'s vertical flip and both zero clamps | all three deleted → both arms green | FZ17 |
| the 300 ms tooltip delay | never asserted anywhere | FZ8 |

### Sabotages for the repair — twenty-one, every row proved non-vacuous

Taken in the private tree copy; every restore by `cp` from a pre-sabotage
snapshot with `md5sum -c` on all three files, all `OK`. Baseline **ALL PASS
(235)** / **ALL PASS (197)**.

| # | sabotage | RED (`:99`) | RED (`--nogui`) |
|---|---|---|---|
| S1 | the Ctrl arm drops `rdw::_focus_click %W` | FZ12 FZ14 | FZ12 |
| S2 | `_font` imposes a size only while one is chosen | FZ13 FZ15 | FZ13 |
| S3 | `_base_size` stops reading the shared font (bare `set n 10`) | FZ13 FZ15 | FZ13 |
| S4 | `_pane_chars` measures the raw shared font again | FZ13 FZ15 | FZ13 |
| S5 | the label becomes `Zz` | FZ7 FZ12 | FZ12 |
| S6 | the tooltip delay reverts to the tree-wide 1000 ms | FZ8 | — |
| S7 | the private font is created `-family Helvetica -size 10` | FZ4 FZ15 FZ16 | — |
| S8 | `balloon_show` loses the vertical flip and both zero clamps | FZ17 | — |
| S9 | a `pos 0` tip slides like a `pos 1` one | FZ18 | — |
| S10 | the button is packed `-side top` | FZ7 FZ12 FZ17 | FZ12 |
| S11 | `set_font_size` also does the global one-liner | FZ4 FZ5 FZ9 FZ10 FZ11 FZ18 | FZ4 |
| S12 | the horizontal clamp is deleted outright | FZ11 FZ17 FZ18 | — |
| a | `_font` answers TkFixedFont for both surfaces | FZ5 FZ6 FZ10 FZ15 | — |
| c | the `hdr` tag goes back to the frozen `font actual` snapshot | FZ5 FZ6 FZ10 | — |
| d | the Control arm drops its `break` | FZ7 FZ9 FZ12 FZ14 | FZ12 |
| e | `_apply_font` stops recomputing the character shape | FZ9 FZ10 FZ11 | — |
| f | `build` no longer calls `rdw::_apply_font` | FZ5 FZ10 FZ11 | — |
| g | `_accept_size` clamps instead of refusing | FZ2 FZ3 FZ4 FZ15 | FZ2 FZ3 FZ4 |
| h | the band widens to the CIW's 4..72 | FZ1 FZ2 FZ3 FZ9 | FZ1 FZ2 FZ3 |
| i | the aA button loses its tooltip | FZ4 FZ8 FZ12 | FZ4 FZ12 |
| S13 | the font control is ADDED to `rdw::_buttons` | 31 rows, incl. FZ12 and LX12 | FZ12 LX4 LX12 LX14 |

The eight lettered rows are the landed build's own sabotages, re-run against the
repaired code so a repair that made an old fence vacuous would show; none did,
and four of them now red MORE rows than before.

**And the red set of the refuted build against the repaired suite** — the
as-landed `src/rdw.tcl` and `src/xschem.tcl` copied into the private tree, suite
unchanged:

```
:99      RESULT: 5 FAILED (230 passed)   FZ12 FZ13 FZ14 FZ15 FZ18
--nogui  RESULT: 2 FAILED (195 passed)   FZ12 FZ13
```

FZ16 and FZ17 pass on the refuted build, correctly: those two fence properties
that were already true and merely unwatched, not defects it had.

**Suites re-run on `:99` after the repair, md5-bracketed across the batch:**
`test_rdw_window_1245` ALL PASS (235) and ALL PASS (197) headless,
`test_rdw_keys_1245` ALL PASS (90), `test_rdw_seam_1245` ALL PASS (49),
`test_op_param_store_1245` ALL PASS (135), and — because `balloon_show` is
shared — `test_calc_skeleton` ALL PASS (545), `test_calc_widgets` ALL PASS
(244), `test_results_dialog` ALL PASS (57), `test_results_select` ALL PASS
(377), `test_ase_window` ALL PASS (228), `test_annot_declutter_1244` ALL PASS
(134).

## What is the USER's to decide (rule debt 1368)

1. **Does the size persist across SESSIONS, and written by what?** Across a
   close and a reopen it persists for free (row FZ10). Across sessions it needs
   a file, and the tree's own precedent is explicit about this kind of write:
   `net_hilight_style` (`xschem.tcl:689-731`) is written **only** by an explicit
   Save, never automatically, because it "could change highlight appearance in
   the user's OTHER projects". A font size has exactly that property. Shipped:
   **(a) no session persistence, rc door only** — `set rdw_font_size 14` in
   `~/.xschem/xschemrc`, or `rdw::set_font_size 14` from a `--script` rc, both
   work by construction. The alternatives are (b) auto-write on every click,
   which silently changes every future session and every project, and (c) an
   explicit Save — note the RDW's existing Save button writes
   `op_param_lists.conf` and must not be overloaded, so (c) means a new control.
2. **What follows the size — the pane only, or the whole window?** Shipped:
   the pane **and its bold header tag**; the status line (`.rdw.s.msg`,
   `-font TkTextFont`), the chrome label `.rdw.hdr` and the button labels keep
   the platform UI font. The pane is the artifact the user selects and pastes
   into a design review (ruling DD-5); the rest is furniture whose scaling
   fights `rdw::_status_refit`, whose entire design (issue 1362) is "ask the
   widget, never a font constant". `rdw::_apply_font` still calls
   `rdw::_status_show`, so the status height re-fits when the pane's resize
   moves its width. **Needs eyes** — it cannot be settled without looking at the
   window at size 20 with a small status line under it.
3. **The band, and where the button sits.** Shipped: 6..32, refusing at both
   ends. The CIW's own band is 4..72 (`ciw.tcl:406`); overruling costs one line
   of `rdw::font_limits` and one golden. Placement: the foot of the right-hand
   button column, visually separated. The alternative is the far right of the
   status bar, where e-readers put it — but that steals ~30 px from the status
   sentence, and issue **1362** exists because that sentence ran out of width.
   **Needs eyes.**

One smaller choice taken without asking, recorded so it can be overruled
cheaply: **the tooltip appears after 300 ms** rather than the tree-wide 1000 ms,
on the user's own words "as soon as user hovers over it". Every other `balloon`
call site in the tree takes the default.

## Everything below was measured on Xvfb only

Every number here is DejaVu Sans Mono as `:99` resolves it, with openbox live.
The user's own display is the Windows X server over TCP (`$DISPLAY` =
`<win-ip>:0`, vendor `HC-Consult`) and may substitute a different family with
different metrics — which is why **no pixel constant enters the code or the
suite**, exactly as issue 1362's comment (`rdw.tcl:1816-1824`) already rules for
the status line. The `aA` glyph itself, and the readability of the band's two
ends, are pixel questions for the user's eyes.

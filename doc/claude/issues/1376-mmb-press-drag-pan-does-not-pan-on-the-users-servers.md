# 1376 — middle-button press-drag does not pan on the user's own servers, and every layer this tree can reach is innocent

**Status: OPEN, NOT REPRODUCED HERE.** Reported by the user against both their
VcXsrv display (`172.20.160.1:0`, vendor `HC-Consult`) and WSLg `:0`, always
running `src/cadence_style_rc`. Subject: `src/callback.c`
(`handle_button_press`'s `button==Button2 && state==0` arm, `start_pan_logged`,
`handle_button_release`'s `STARTPAN` arm), `src/xschem.tcl` (the canvas
`<Button>` / `<Motion>` / `<ButtonRelease>` bindings).

## The user's words

> Panning with MMB press-drag not working. Tried also with WSLg using
> DISPLAY=:0 in addition to VcXsrv. I always run with cadence_style_rc

## ⚠ WHAT THE FIRST ANSWER GOT WRONG, BECAUSE IT IS THE POINT OF THIS FILE

The user was told the gesture worked. The evidence offered was
`xschem callback <win> 4 400 300 0 2 0 0` driven from a script, which **is the C
entry point** and bypasses the Tk binding table, the window manager, the X
server's event delivery and the mouse. It proves the dispatcher and the action.
It proves nothing whatsoever about a gesture, and it must never again be offered
as though it did.

`event generate` is only marginally better and it lies in a way that produced a
false finding before it was caught. MEASURED on Tk 8.6.17: `event generate .drw
<ButtonPress-2> -state N` fires the widget's `<Button>` binding **only for
N == 0**. Shift (1), Lock (2), Control (4), Mod1 (8), Mod2 (16) and Mod3 (32)
all match nothing, and `<ButtonPress> -button 2` matches nothing at any state.
Control-click demonstrably works in the real program, so this is an artifact of
`event generate`, not a rule of Tk's binding table. An intermediate conclusion —
"a lock modifier kills the pan" — was drawn from exactly this artifact and
retracted.

## What was measured, and is therefore ruled out

All on `:99` (Xvfb 1920x1080x24, openbox 3.6.1) with `src/cadence_style_rc`
sourced and the user's own `tb_bandgap` loaded, unless stated.

1. **The C path works.** Press → `ui_state` 512 (`STARTPAN`); motion →
   `xorigin` 19.946 → 163.702; release → `ui_state` 0; further motion does not
   pan. Through the real Tk bindings (`event generate`, state 0) as well as
   through `xschem callback`.
2. **The bindings are present and generic.** `bindtags .drw` is
   `{.drw Frame . all}`, and `.drw` carries `<Button>`, `<ButtonRelease>` and
   `<Motion>`, each forwarding `%b` and `%s` to `xschem callback`.
3. **The commit is in place.** `a9111307` ("middle-button drag-pan logged as
   `xschem pan dx dy`") is on the branch and `callback.c` still carries
   *"Middle button press (Button2) will pan the schematic."* Nothing removed it.
4. **`cadence_style_rc` rebinds no button.** Its only `xschem bind button` line
   is `button 1 ctrl+alt+shift`; the `button 2` line is commented out. Its wheel
   lines bind buttons 4/5.
5. **Lock modifiers are stripped where it matters.** `callback.c` clears
   `Mod2Mask` and `LockMask` before dispatch, and driving the C arm with those
   states really does still pan. `Mod3`/`Mod4`/`Mod5` are NOT stripped and do
   kill the arm — see "still open" below.
6. **NumLock is Mod2 on all three servers**, read out of each server's own
   modifier map with `XGetModifierMapping`: `:99`, `:0` and the user's
   `HC-Consult` display all put `Num_Lock` on Mod2 and `Caps_Lock` on Lock. So
   the hardcoded `Mod2Mask` strip is correct and is not the defect.
7. **A graph on the sheet is not it.** MMB over a graph rect IS the graph pan by
   design (`4db94ddd` moved graph pan off LMB). `tb_bandgap` has **zero**
   `GRIDLAYER` rects, so on the user's sheet MMB can only reach the canvas pan.
   (An earlier "no graphs and yet GRAPHPAN" measurement was a fixture error:
   `xschem get rects 5` was read as the graph layer, and `GRIDLAYER` is **2**.
   The fixture, `greycnt.sch`, has one graph and the click landed inside it.)
8. **A loaded raw does not change it.** With the user's own
   `tb_bandgap_ase.raw` read in, the press still sets `STARTPAN` and still pans.

## What is still open, in the order worth trying

* **What the user's canvas actually receives.** `tests/headless/probe_mmb_pan.tcl`
  logs every `<Button>` / `<Motion>` / `<ButtonRelease>` on `.drw` with its
  button number, decoded state bits, coordinates and the resulting `ui_state`.
  This is the missing measurement and no amount of local testing substitutes for
  it.
* **An immediate release.** `handle_button_release` clears `STARTPAN`, so a
  server or mouse driver that reports a middle-button *click* (press and release
  together, the way buttons 4/5 always arrive) rather than a *hold* would set
  and clear the state in the same instant and drag nothing. This fits the
  symptom exactly and the probe's timestamps settle it.
* **`state == 0` is brittle.** The arm demands an exactly-zero state after only
  the button, `Mod2` and `Lock` masks are removed. Mod3, Mod4 (Super) and Mod5
  therefore each kill the pan silently — MEASURED. No server here reports one at
  rest, but a server that did would produce precisely this report, and the arm
  should arguably use the file's own `EQUAL_MODMASK` discipline instead of a
  bare zero.
* **Middle-button emulation.** VcXsrv can synthesise button 2 from a 1+3 chord;
  the probe's button numbers will say whether button 2 arrives at all.

# 1387 — two Tcl command modes seize one canvas, nobody decides, and neither of them works in a tab

**Branch** `fluid-editing`. **Files** `src/rdw.tcl` (`rdw::pick_start`,
`rdw::_pick_seize`), `src/ase_window.tcl` (`ase::ui::select_on_design`,
`ase::ui::sod_statusbar`, `ase::ui::sod_prompt_pump`).
**Status: NOT FIXED — filed.** Found while repairing issue **1384**; none of it
is 1384's to fix, and all of it was measured in the same runs.

Three defects that share one cause: **the design canvas has two Tcl-level
command modes and no owner**, and both of them identify the canvas by a string
that is not always a widget.

---

## 1. The RDW pick mode does nothing, and says nothing, in a tab

`rdw::pick_start` asks `winfo exists [xschem get current_win_path]` and refuses
when it is 0. In a **tab** that path is a logical name, not a Tk widget.
Measured on :99, shipped `tabbed_interface 1`, one
`xschem schematic_in_new_window force`:

```
xschem get current_win_path   .x1.drw
winfo exists .x1.drw          0        <- tabs share the ONE real .drw
xschem get top_path           {}       <- so C writes the shared .statusbar.10
rdw::pick_start               0
.statusbar.10                 | |      <- nothing on the sheet
```

So pressing `1`, `2` or `3` with nothing selected, in a tab, **does nothing and
reports nothing** — not on the status bar, not in the CIW. Every other refusal
in `rdw.tcl` names itself through `rdw::_ciw`; this one does not, because it is
a `return 0` from a proc whose callers do not check it.

**Two things are wrong and they are separable.** The silence is a bug on its
own — a refusal that changes nothing must still *say* something (this file's own
rule). And the refusal itself is avoidable: the mode does not need the logical
path, it needs the **canvas widget**, which in a tab is the shared `.drw`. The
fix that makes both go away is for the seize to hold the real widget.

⚠ **If it is fixed, issue 1384's status-bar hint has to follow.** Row `HT14` of
`tests/headless/test_rdw_window_1245.tcl` asserts the silence, so it goes red the
day the mode arms in a tab and whoever fixes it is told. `rdw::_hint_slot` is
already right for that world: with `pick(canvas)` a real widget it derives the
bar from `winfo toplevel`, and needs no tab arm at all.

## 2. `ase::ui::sod_statusbar` has the uncorrected arithmetic

```tcl
proc ase::ui::sod_statusbar {cv} {
  regsub {\.drw$} $cv {} top
  return "$top.statusbar.10"
}
```

This is the proc `rdw::_hint_slot` was copied from, and 1384 corrected the copy
without being able to correct the original — `rdw.tcl` deliberately does not
call across into `ase_window.tcl` (that file is a peer it must load without).
For a tab it answers `.x1.statusbar.10`, a widget that does not exist. Whether
it is REACHABLE there depends on what `ase::ui::design_window` hands it, which
is not measured here. **Copying a proc copies its bugs** — that is the standing
cost of the refused dependency, and it is worth writing down where the copy
lives, which `rdw::_hint_slot`'s comment now does.

## 3. The two modes fight over one canvas and one label, and nobody arbitrates

`ase::ui::select_on_design` self-serialises against **another SOD**
(ase_window.tcl:1897, "ONE mode globally") and against nothing else.
`rdw::pick_start` self-serialises against another RDW pick and against nothing
else. Both register with `cmdmode`, but that contract is about a **descend**
suspending and resuming a mode, not about two modes coexisting.

So arming select-on-design and then pressing `1` with nothing selected leaves:

* **`<ButtonPress-1>` seized twice.** `rdw::_pick_seize` latches SOD's own script
  as its predecessor and installs its own, so a click dumps to the Results window
  and never reaches SOD. Last arm wins, silently. (The inverse order is the
  mirror image.)
* **`.statusbar.10` written by two pumps.** `ase::ui::sod_prompt_pump` and
  `rdw::_hint_pump` both write that label on an 80 ms timer and neither reads
  the other.

Before issue 1384's repair pass this was worse than it looks: ASE's prompt won
the label (a timer that fires last wins) while the RDW seize won the click, so
**the status bar was describing a mode that a press would not enter**. 1384's
synchronous re-assert makes the RDW hint win the label as decisively as its
seize wins the click, so the label and the button now agree — an improvement,
but not a decision. The decision is still owed, and it belongs to whichever
layer owns the canvas:

* (a) one Tcl command mode globally, the way SOD already treats its own kind —
  `pick_start` ends a live SOD (and vice versa) and says so in the CIW;
* (b) `cmdmode` grows a claim on the canvas and refuses the second arm by name;
* (c) leave it, and document that the last arm wins.

Whatever wins, the answer must be in ONE place: two procs that both decide who
owns `<ButtonPress-1>` is invariant **I1** one canvas out.

## 4. `ase_window.tcl:1884` states a measured falsehood

The comment above `ase::ui::sod_prompt_pump` reads:

> ~80 ms => a blanking event shows at most a sub-frame flicker before the prompt
> returns; a C ui_state bit would remove even that.

Issue 1384 copied that sentence as precedent and then measured it. On :99, with
a motion timer on `.drw` and the slot sampled every 10 ms, 200 samples a cell:

| main window | motion every 16 ms | 33 ms | 50 ms |
|---|---|---|---|
| 1110x761 | 18 % visible | 16 % | 40 % |
| 1400x800 | 17 % visible | 16 % | 37 % |

It is the **prompt** that shows for a sub-frame. And because `.statusbar.10` is
packed `-side left` with no `-fill x` (xschem.tcl:16834) the slot's width follows
its text, so the same stream swung it 8 ↔ 471 px at ~12 Hz and dragged
`.statusbar.1` — the coordinate readout — between 218 and 275 px.

The measurements above were taken with the RDW hint on the label; ASE's own
prompt is a different string on the same widget under the same blank, so the
duty cycle is the same mechanism and has **not** been re-measured with SOD live.
`rdw.tcl` fixes it with a private binding tag on the canvas that re-asserts in
the same binding invocation C blanked in (100 % visible, both widths constant,
~1.3 ms of CPU per second of moving the mouse). **The same fix is available to
`sod_prompt_pump` and is not applied here** — it is another feature's file and
another feature's suite, and a change to it with no ASE row driving it would be
exactly the kind of unfenced edit this tree keeps paying for.

## What is owed

* A ruling on §3 (which layer owns the canvas, and what the second arm is told).
* §1 is a plain bug and needs no ruling: a refusal must say something.
* §2 and §4 are ASE's file and want an ASE row each.

**Nothing here was fixed.** Issue 1384's suites are green on `:99` with all of
it live, because none of it is reachable from the gestures 1384 owns.

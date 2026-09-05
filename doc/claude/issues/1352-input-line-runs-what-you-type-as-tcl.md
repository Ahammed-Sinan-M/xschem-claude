# 1352 — `input_line`'s OK button runs what you type as Tcl

**Status: FILED, NOT FIXED.** Found by item **P2**'s adversary while measuring
the RDW engineering-notation repair (2026-09-05), re-driven independently by the
driver on `:99`. Subject: `input_line` in `src/xschem.tcl:14146-14152`. **This is
stock xschem code, not something this branch introduced** — it is inherited, and
it is on the branch the user shares.

## The shape

```tcl
button .dialog.f2.ok -text OK  -command  "
  if { {$cmd} ne {} } {
    eval $cmd \[.dialog.f1.e get\]
  }
  ...
"
```

`eval` concatenates its arguments into a script and evaluates it, so the text
the user typed is not passed as a **value** to `$cmd` — it is spliced into the
script and parsed as Tcl.

## Driven, in the real widget

Probe: `scratchpad/inpline.tcl`, run on `:99` through `devdisplay.sh exec`,
filling and invoking the actual OK button from the event loop.

Typing

```
7 ; set ::INJECTED yes
```

into the dialog `input_line {precision} {set_ne ev_precision} 4 12` raises —

```
EVPREC=4
INJECTED=yes
```

— the second command ran. The adversary drove the same thing through the shipped
menu entry **Simulation > Set netlist / graph / annotation precision** and got
the same answer.

## Why it matters more than a validation bug

Every `input_line` caller that passes a `cmd` shares it. **Set top level netlist
name** goes through the same button with `xschem set netlist_name`. So the
question that reaches the user as "should the precision dialog refuse a value it
cannot use?" is smaller than the truth: these dialogs execute their input.

The realistic exposure is not a hostile user typing into their own editor — it
is a value that arrives from somewhere else and passes through one of these
dialogs, and it is a sharp edge on a branch that is handed to other people.

## The fix, and why it is not taken here

`eval $cmd [list [.dialog.f1.e get]]`, or `uplevel #0 [linsert $cmd end [...]]`
— one line, and it makes the typed text a single argument in every case.

It is not taken here for one reason: **`input_line` is a stock proc with many
callers, and any caller relying today on the typed text being *substituted* (a
multi-word value reaching `$cmd` as several arguments) would change behaviour
silently.** That is a survey and a ruling, not a patch, and it is off the RDW
batch's path. Recorded as a rule debt so it reaches the user rather than sitting
in a write-up.

## What is NOT claimed

No path was found by which this fires without someone typing into the dialog.
It is a sharp edge and an inherited one, not a live exploit in the tree.

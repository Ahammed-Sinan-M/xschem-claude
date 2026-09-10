# 1396 — Save State overwrote an existing state with no confirmation

**Reported by the user, 2026-09-09**, after reading the ASE-L UX audit:

> *"let's fix the Save State thing first. I noticed that. Undo not required. Just confirm
> if overwriting an existing state. One commit for this."*

## What was wrong

`Session > Save State` is always a Save-As (`src/ase_window.tcl:511` →
`ase::ui::save_state_dialog` → `ase::ui::save_state_ok`). Its only guard was
`ase::ui::save_as_needs_confirm`, whose docstring recorded decision **D13**:

> *"overwriting a DIFFERENT existing view needs NO confirm in v1 — the spec's only confirm
> trigger is read-only + same-target."*

Measured on the live binary with `sky130_tests_ase/tb_bandgap` state `ngspice_state1`
open and the sibling `debug_st1` present and writable:

```
save_as_needs_confirm(-> debug_st1)      = 0     <- a DIFFERENT, EXISTING state
save_as_needs_confirm(-> ngspice_state1) = 0     <- your own; correct, that is a Save
save_as_needs_confirm(-> zz_brand_new)   = 0     <- does not exist; correct
```

So typing an existing sibling view name into the form destroyed it, with no warning and
no undo. D13 described the shipped window accurately; the user has retired it.

## What shipped

`ase::ui::save_as_needs_confirm` is **unchanged** — it keeps its D8 contract, and its
pinned rows keep passing. A second predicate answers the new question:

```tcl
ase::ui::save_as_overwrites_other {key lib cell view}
```

1 iff the resolved target exists and is not the session's own state file. The two are
mutually exclusive by construction (`target == own` versus `target != own`), so
`save_state_ok` chains them and never composes a sentence out of two reasons.

Both sentences moved into the `lbl_*` family. The read-only one is byte-identical to what
shipped, embedded newline included. The new one is:

> **State `<lib>/<cell>/<view>` exists. Overwrite?**

Title, both arms: `Overwrite State`.

## Two defects the fix itself introduced, found by its own adversaries and fixed here

**A gate that was real for the mouse and theatre for the keyboard.**
`save_state_dialog` binds `<Return>` on all three of its fields, so *type the view name,
press Return* is the sanctioned submit. `ase::ui::confirm` then focuses OK and binds
`<Return>` to `confirm_ok`. Composed: Return raises the popup, Return destroys the file,
with the sentence on screen for the length of one keystroke.
`ase::ui::confirm_safe_default` puts focus on Cancel and points `<Return>` at the
dismissal — at the destructive **caller**, not in the shared `ase::ui::confirm`, whose
"Return = proceed" contract is documented and whose other user is Load State.

**An orphaned confirm outliving the form that raised it.** Escape on the Save-As form —
the documented item-10 dismissal — destroyed the form and left the confirm alive: a live
destructive button aimed at a file, belonging to a dialog the user had just backed out
of, and its OK still wrote. Re-opening the form was the same defect with a second face:
`dialog_frame` destroys the old form, and the screen became a form naming one view above
a confirm naming another. `ase::ui::confirm_owned_by` binds the form's `<Destroy>`.

## Rows

`tests/headless/test_ase_dialogs.tcl` — section H2 extended, new sections H2b/H2c/H2d for
the predicate and the sentences, G8b for the behaviour (the confirm appears, the target is
byte-identical while it is up, Cancel writes nothing) and G8c for the two regressions
above. Floor 176 → 215 on a display, 21 → 37 headless.

`tests/headless/test_ase_savestate_adopt.tcl` — Part B drives an untitled session's real
menu Save-As onto a view Part A created, so the new confirm fires there. It hung for 300 s
waiting for a form that stays up behind the confirm. Wait-and-press added, floor 26 → 27.

## Recorded, not fixed

- The confirm is not `wm transient` for anything and lands ~1100 px from the window the
  user is working in (measured 3/3 on openbox: ASE at `+1121+50`, form at `+389+60`,
  confirm at `+23+81`). Pre-existing for every ASE-L dialog — `doc/claude/ase_l_ux_batch/PLAN.md`
  Stage 2 — but this change is what makes a *destructive* dialog depend on being seen.
- An existing-but-unwritable target confirms, then fails **silently**: no dialog, no
  status change, no title change. Decision S-6.
- Overwriting a state that is open in another ASE-L window says nothing about the other
  window; that session keeps its stale copy, stays dirty, and its next save overwrites the
  file again.
- On a legacy FLAT library, `xschem cellview_path <lib>/<cell> <any non-schematic view>`
  answers `<cell>.sym` (`src/library_defs.tcl:289`), so the predicate reports "exists" for
  a view that does not, and the sentence names it.

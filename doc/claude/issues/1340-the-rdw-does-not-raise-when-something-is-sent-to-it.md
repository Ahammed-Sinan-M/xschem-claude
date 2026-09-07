# 1340 — the Results Display Window did not come to the front when a dump was sent to it

*Item R4 of the RDW batch (`doc/claude/rdw_batch/`). Branch `fluid-editing`.
Filed and fixed 2026-09-05, at HEAD `0122c9a7` (item R2's Up/Down).*

**The user's words:** *"When user sends info to the Results Display Window
(RDW), the RDW needs to be raised (no need to focus, just raise), just as the
Library Manager is raised when one does Ctrl-Alt-S."*

---

## What was wrong

`rdw::push` is the single door every dump goes through — key `1`, key `2`,
key `3`, the pick mode's clicks, all of them land there. It stored the block,
cleared the cursor and repainted the pane, and **said nothing to the window
manager at all**. Once the Results Display Window had slid behind the schematic
— which is where it goes the moment the user clicks back onto the canvas to
select the next device — every subsequent dump landed in a window they could not
see. The feature reported success into an invisible surface.

`rdw::open` does raise, but it is only reached when a dump comes through
`rdw::show`/`rdw::key`, and even there its `raise .rdw` is **the one thing that
does not work on the window manager the user reported from** (see below). A
dump that reached `push` by any other route raised nothing whatsoever.

---

## What was measured, before any source change

Section RA of `tests/headless/test_rdw_keys_1245.tcl` (`:99`, six rows) and
section RH of `tests/headless/test_rdw_window_1245.tcl` (both arms) went in
first. Four rows were red at HEAD `0122c9a7`, on four separate runs with
identical got-vectors:

* **RA1** — `.rdw` open and mapped, parked under a decoy toplevel, keyboard on
  the canvas. One `rdw::push`: `above-after 0`, where `1` was owed. Nothing
  raised at all.
* **RA2** — no re-map and no deferred verify: `{… 0 0 0 …}` where `{… 1 1 1 …}`
  was owed.
* **RA3** — the same on the path the user's hand takes (a real bare `1` over a
  selected `M1`): `rdw::open`'s plain `raise` already satisfied the *stacking*
  leg on `:99`, and the re-map legs were `0 0 0`.
* **RA4** — a dump into an **iconified** window left it `iconic`, and
  `wm stackorder` answered `ERR`.

Two rows were green before and after, and that is their whole job: **RA5** (the
shared helper still activates for its other callers) and **RH2** (its headless
twin). RA5 is also the non-vacuity control for the `activate_window == 0` leg
every red row carries — if the execution trace never attached, those legs are
worthless and RA5 reds.

---

## Two things a plain `raise` cannot do, and one it does by accident

**A plain `raise` is an inert no-op on the user's window manager.** Issue 0054
established this exhaustively: that WM applies stacking ONLY at map time, so
`raise`, `_NET_ACTIVE_WINDOW` and `_NET_WM_STATE_ABOVE` are all ignored once a
window is mapped. The one thing that works is to re-MAP the window
(`wm withdraw` + `wm deiconify`). **`:99` cannot see this defect** — measured, a
prototype using a plain `raise` scores `above 1` here and does nothing there.
That is why rows RA2 and RA3 read the *receipts of the idiom* — real
`Unmap`+`Map` events on `.rdw`, and issue 0843's deferred `_remap_verify`
actually running — and not just the stacking order.

**And the re-map takes the keyboard.** Measured on `:99` under openbox, keyboard
parked on the canvas first, nothing else changed:

| | re-map? | where the keyboard ends up |
|---|---|---|
| plain `raise` | no | stays on `.drw` |
| `wm withdraw` + `wm deiconify` | yes | **moves to `.rdw`, and stays there** |

A window manager grants focus to a newly MAPPED toplevel. So the obvious
implementation of this item takes the keyboard off the schematic on every dump
into an open window — the one thing the user forbade in the same sentence as the
request, and worse here than elsewhere, because the grammar that fills this
window (bare `1`/`2`/`3`/`4` and the command mode's Escape) lives on the design
CANVAS. A stolen focus leaves a mode the user cannot leave.

`rdw::_arm_focus_handback` is the one-shot that already catches exactly that
grant (issue 1306), and it **declined to arm for an already-mapped window** —
correctly, until now: no map was coming, and an armed flag left lying around is
a bounce waiting to happen. A dump now re-maps a mapped window, so a map *is*
coming, and the arm is told so by its caller.

---

## What changed

**`src/xschem.tcl` — `raise_activate_toplevel` split in two, ruling DD-6.**
The body — issue 0054's re-map, the north-west creep note, issue 0843's deferred
`_remap_verify` — becomes `raise_toplevel`. `raise_activate_toplevel` keeps its
name, its two guards and its last line, and now delegates the body.

⚠ **The last line MOVED; it was not deleted.** `xschem activate_window` sets
`_NET_ACTIVE_WINDOW`, which is activation. Deleting it satisfies every red row
in section RA and silently stops the Library Manager, the CIW,
`create_instance`, `copy_form`, `save_as_form`, the wave viewer, ASE and
`alt2_toggle_view` — **fourteen call sites** — taking the focus they *are*
entitled to, on a path no suite in this batch walks. Rows RA5 and RH2 are the
fence, and they were written green-before-and-after for exactly that.

**`src/rdw.tcl` — `rdw::_raise`, called from `rdw::push` after the repaint.**
It arms the existing hand-back with the new `remapping` argument and calls
`raise_toplevel .rdw`. It is behind `rdw::have_tk` *and* `winfo exists .rdw`:

* **behind `have_tk`** because `winfo` and `wm` are not merely absent under
  `--nogui`, they are undefined commands, and `push` is the store's own entry
  point that two suites and every headless dump call (row RH1);
* **behind `winfo exists`** because `rdw::open` is this window's ONE constructor
  (row N1) and the dumps deliberately survive a close. Calling `rdw::open` from
  `push` is the cheap implementation and would conjure back a window the user
  closed. Rows RA4 and RH1 are the fence.

It raises AFTER `render_pane`, so what comes to the front is the block that was
just sent and never the previous one. The raise is `catch`ed: by then the block
is stored and on screen, and a WM that refuses a re-map is not a reason to fail
the dump — rows RA1–RA4 are what say the raise really happens, so the catch
cannot hide a regression from the suite.

**`rdw::_arm_focus_handback {{remapping 0}}`** — the caller says a map is coming
rather than the proc guessing. Every pre-existing caller passes nothing and its
behaviour is unmoved.

---

## Teeth, measured against the landed code

Each sabotage was applied to a COPY, run, restored by `cp`, and the restore
verified with `md5sum`.

| sabotage | what reds |
|---|---|
| `rdw::_arm_focus_handback 1` → `…handback` (the obvious version) | RA1, RA2 — on `focus` = `.rdw` |
| `raise_toplevel .rdw` → `raise .rdw` (right on `:99`, inert on the user's server) | RA2, RA3, RA4 |
| `raise_activate_toplevel` re-derived as `raise $top` + the activation | **RH3 only** — the keys suite stays ALL PASS 59 |

That last row is why the implementing pass added **RH3**. RH1 and RH2 fence what
the split must not do (rdw.tcl must not copy the body; the activation must not
be lost); neither says the two halves are still *joined*, and un-joining them is
the regression this item actually creates. RH3 is structural because the
behaviour needs a WM that DROPS a re-map, which no display here has —
`tests/headless/test_remap_verify.tcl` simulates the drop and is the
behavioural half.

---

## The first open does NOT flicker, measured

The obvious worry about raising from `push` is the FIRST dump of a session:
`rdw::show` builds the window and then dumps into it, so a re-map there would
withdraw a toplevel the user had only just been shown. Probed on `:99` with a
`<Map>`/`<Unmap>` counter armed inside `rdw::build` itself, so the very first
map is counted:

| | Map | Unmap | mapped | `focus` | `focus_pending` |
|---|---|---|---|---|---|
| first-of-session open + dump | 1 | **0** | 1 | `.drw` | 0 |
| a second dump into that window | 1 | 1 | 1 | `.drw` | 0 |

`.rdw` is not yet mapped when `push` runs on the first dump, so `raise_toplevel`
takes its *unmapped* arm — a plain `wm deiconify`, no withdraw and nothing to
flicker. The re-map appears only on the second and later dumps, which is exactly
the case this item is about. Both rows end with the keyboard on the canvas and
the one-shot spent.

---

## What `:99` cannot judge, said out loud

* **The `wm geometry` legs have no teeth here.** They fence issue 0054's ~32px
  north-west creep. Measured against a prototype with the geometry restore
  deleted: openbox on `:99` puts the window back by itself and the suite scores
  ALL PASS 59. Nobody may read a green run here as evidence the geometry is
  safe on the user's server.
* **`:99` cannot reproduce the defect the user reported.** A plain `raise` is
  green here and inert there. The Map/Unmap and `_remap_verify` receipts are
  the substitute, and they are a proxy, not the thing.
* A `look` debt (`the_RDW_raise_behaviour`) carries both.

---

## A cost, stated

The pick mode dumps a block per click, so the window now comes to the front on
every pick. That is what "raised when something is sent to it" means and the
keyboard stays on the canvas throughout, so picking still works — but if the
user has parked the RDW over the schematic it will cover the device they are
about to click. The alternative (raise only when the window is not already
visible) cannot be asked of X: there is no "is this window occluded" question,
only "is it above that one".

---

## Suites

| suite | arm | before | after |
|---|---|---|---|
| `test_rdw_keys_1245` | `:99` | `4 FAILED (55 passed)` | `ALL PASS (59 checks)` ×5 |
| `test_rdw_window_1245` | `--nogui` | `ALL PASS (126)` | `ALL PASS (127)` (+RH3) |
| `test_rdw_window_1245` | `:99` | `ALL PASS (138)` | `ALL PASS (139)` (+RH3) |
| `test_op_param_store_1245` | `--nogui` | `ALL PASS (130)` | `ALL PASS (130)` |
| `test_op_annot` (control) | `--nogui` | `ALL PASS (485)` | `ALL PASS (485)` |
| `test_remap_verify` | `:99` | — | `ALL PASS` |
| `test_ase_plot` | `:99` | — | `ALL PASS (150)` |
| `test_wave_sigbrowser_i11` / `i12` | `:99` | — | `ALL PASS (74)` / `ALL PASS (126)` |
| `test_wave_viewer_geometry` | `:99` | — | `ALL PASS` |
| `test_ase_window` | `:99` | `1 FAILED (227)` W7 | `1 FAILED (227)` W7 |

`test_ase_window`'s W7 (*"simulator produced output before Stop"*) is
**pre-existing and unrelated**: measured red on the HEAD sources restored into
the tree by `git show HEAD:… >`, with the restore verified by `md5sum`.

**T1 at zero, run solo** (issue 0990): `tclsh run_regression.tcl`, exit 0, 57
cases all `Total num fail: 0`, no line matching `FAIL$` / `GOLD?` / `RESULT?` /
`^FATAL`, no `exit 127`. The three `NOGOLD` notices are the documented baseline.

Floors raised in the same commit, never lowered: `KX_FLOOR` 53 → 59,
`RW_FLOOR` 124 → 127.

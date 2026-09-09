# Receipt 01 — item A: the round trip (`src/ase.tcl`)

Scope as briefed: `src/ase.tcl` and `tests/headless/test_ase_core.tcl` only.
Nothing committed. `src/ase_window.tcl` untouched (crew B owns it), no issue
file touched.

---

## 1. What changed, and where

### `src/ase.tcl` — new section `# --- The hierarchy round trip` at **:5932**

| proc | line | what it is |
|---|---|---|
| `ase::hier_instnames {}` | **:5989** | A5. The instance names entered to reach the current level, top-first; `{}` at the top. A **copy** of `cadence::hier_instnames` (`utils/cadence_nav.tcl:45`), not a call — the comment carries the `src/rdw.tcl:4360-4366` citation and says plainly not to de-duplicate it. Wrapped in a `catch` because it is read on `with_design_current`'s error path, where a second raise on top of the first is the last thing wanted. |
| `ase::stack_level {npath}` | **:6016** | A1. Level of this window's stack whose schematic is `npath`, or `-1`. Scans **0 upward**, first match wins (D2); never raises; normalizes both sides. The comment names `ase::session_for_current` (`:8826`) as the deliberately-opposite scan and says why unifying them is a bug waiting for a recursive hierarchy. **Item B's contract — name, signature, `-1`, never raises — is unchanged.** |
| `ase::hier_ascend_to {target}` | **:6044** | The ascent. `go_back 2` (`what&1`=confirm OFF so no modal on a button press, `what&2`=no title flicker), op_annot::_unwind's move-or-break guards, ceiling 64 vs `CADMAXHIER` 40. Returns 1/0. |
| `ase::hier_stranded_msg {inst why}` | **:6059** | One mint for "where you were left", so the three failure arms below cannot describe one accident three ways. |
| `ase::hier_redescend {names target}` | **:6088** | The return. `descend -fallback -inst` (0979, not optional). **Re-reads `currsch` every step instead of counting its own** — a short ascent would otherwise let the replay walk *past* the entry level. Raises a sentence naming the instance and the level the person is standing on. |
| `ase::design_unreachable_msg {design {remedy {}}}` | **:6139** | Batch decision **D6**, raised by crew B. One head (`ase: design <X> is not open in this window`), the tail chosen by the caller. See §5. |
| `ase::with_design_current {dpath script}` | **:6175** | A2/A3/A4. `uplevel #0`. Fast path when `lev == currsch`. Gate, park, no_draw, ascent, script, unconditional restore. |
| `ase::netlist_in_place {state cell}` | **:6356** | A6. The netlist body, split out. `ase::op_cards_capture` stays **inside** it, per A6 and issue 0436. |
| `ase::netlist {state}` | **:6390** | A6. Four arms; see §5. |

### `tests/headless/test_ase_core.tcl` — new section `RT` at **:2815**

13 rows, `RT0`–`RT12` (`:2902`–`:3186`), plus three `note` evidence lines.
Fixture: a second cell pair in the **existing** scratch `aselib`, in the
cadence `lib/cell/view` layout the suite already uses — so nothing in the RT
section touches `::pathlist`, `::XSCHEM_LIBRARY_PATH` or the `library.defs` the
earlier sections depend on.

---

## 2. The A3 decision table as implemented

| entry buffer | `::autosave_backup` | behaviour | measured |
|---|---|---|---|
| clean | either | park the flag at 0 for the trip; restore unconditionally (had/val pair, so "never set" restores to never-set) | ran at `0 rtparent.sch`, back at level 1, `modified 0`, `autosave_backup` back to 1 |
| modified | on | do **not** park; after the last re-descend, restore `readonly`, then `xschem load_backup <entrycell> 0` | ran at `0 rtparent.sch`, back at level 1 in `descend_child.sch`, **`modified 1`**, `readonly 0`, edit present (2 instances vs 1 on disk) |
| modified | off | **REFUSE** before anything moves | `rc 1`, `currsch` unchanged, instance count unchanged, `autosave_backup` untouched |

The row-3 sentence, verbatim from the run:

> `ase: 'descend_child.sch' has UNSAVED edits and autosave backup is off. Netlisting the design from here has to leave this level and come back, and with no autosave backup that round trip silently REVERTS unsaved edits (issue 0626). Save this cell, or turn Options > Autosave backup on, and press it again.`

**Why the park is row-1-only, measured rather than assumed:** `load_backup_as`
early-returns on `!tclgetboolvar("autosave_backup")` at `save.c:6186`. Parking in
the carry row would disable go_back's restore of the ancestors *and* this
trip's own `xschem load_backup`.

**The park is not decoration.** With a `~` beside the design's own cell:
parked trip → back at level 1, `modified 0`; the same ascent unparked → level 0,
`modified 1`. That control is row RT5's second half.

---

## 3. Measured, on the bench, with a throwaway script

`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap`, `cadence_style_rc` sourced
from inside the script, on `:99` (openbox live), binary `./src/xschem`,
`--pipe -q --nolog`.

```
top.netlist.bytes        = 14862        (8 .subckt)     <- matches CREW_BRIEF §1
descend x1, x1           -> ret 1, 1 ; descend_error empty both times
desc.currsch / sch_path  = 2 / .x1.x1.
desc.schname             = .../bandgap_opamp/schematic/bandgap_opamp.sch
here.netlist.bytes       = 4685         <- the defect the guard was protecting
ase::hier_instnames      = x1 x1
ase::stack_level  top/l1/l2/bogus/{}/junk-list = 0 / 1 / 2 / -1 / -1 / -1 (rc 0)
```

The round trip through `ase::with_design_current`:

```
trip.ms (walk + netlist)     = 85.2
walk alone, 5 trips (ms)     = 29.6  28.3  28.1  30.4  29.7
netlist alone (opamp, ms)    = 32.3
trip.drawcount.delta         = 1              <- ONE repaint, at the end
post.currsch / sch_path      = 2 / .x1.x1.
post.schname                 = bandgap_opamp.sch
view before                  = 27.1142493423165 1296.66863652559 1.8076166228211
view after                   = 27.1142493423165 1296.66863652559 1.8076166228211
post.modified / autosave     = 0 / 1
cmp top.spice desc.spice     = 0            <- BYTE-IDENTICAL, 14862 == 14862
```

`ase::with_design_current` with the design **already** current: script ran at
level 0, `currsch` 0 after, netlist `cmp` 0 against the top one.

Unreachable design, from two levels down: raises
`ase: design cell.sch is not open in this window`, `currsch` unchanged.

**On CREW_BRIEF §2's 34 ms:** that is the walk, and I measure the walk at
**28.1–30.4 ms** over five trips — the brief's number stands, slightly high if
anything. The 85.2 ms figure is walk *plus* the top-level netlist and is the
number to compare against a press, not against the brief.

---

## 4. What PLAN.md got wrong or did not settle

**(a) PLAN A3/A4 have no read-only axis, and they need one.**
`src/cadence_style_rc:564` sets `descend_readonly 1`, so in the setup this user
actually runs **every descended level is a read-only browse buffer**
(`actions.c:6410`). A read-only buffer can never be flagged modified
(`set_modify`'s `ro_suppress`, issue 0035), so `xschem get modified` reads 0 at
depth however much is typed — **rows 2 and 3 of the A3 table are only reachable
after a Ctrl-2 / View > Toggle Read Only.** Measured: `ro.after.descend = 1`.

And once someone *has* done that, the trip has to give the flag back, because
the final `descend` re-applies `descend_readonly`. Measured before I added the
snapshot: the carried edits came back correctly (1 instance) while `modified`
came back **0** — `load_backup_as`'s `set_modify(1)` landed on a buffer the
re-descend had just made read-only again. A restored buffer that no longer
reports itself modified is one close-without-prompt away from losing the edit a
second time. Fixed by snapshotting `xschem get readonly` at entry and restoring
it **before** the `load_backup`. Row RT8 pins both directions.

**(b) PLAN A4 gives two conflicting instructions for the both-failed case** —
"re-raise the script's error with `-options`" and "raise a sentence that says
WHERE the user was left". Decided: the **script's** error wins the raise (it is
what the caller asked for and the only one it can act on, and `-options` keeps
its stack), and the stranding goes out on `ase::echo … error` so it is never
silent. If only the re-descend failed, the stranding *is* the raise.

**(c) PLAN A6's arm order (b before c) is kept, and it has a consequence worth
stating.** Headless there is no window to clobber and no user to put back, and
`tests/headless/ase_design_window.tcl` deliberately keeps the self-load arm
exercised — so the round trip is **unreachable under `--nogui`**. Row RT11
therefore fakes `::has_x` (saved/restored) so the same row runs, and passes, in
both arms. That is also why the headless run prints eight
`tcleval(): … sim_is_ngspice failed / invalid command name "winfo"` lines: the
fake makes `set_sim_defaults` (`src/xschem.tcl:4259`) take its Tk path while C's
own `has_x` is still 0. Nothing asserts on them, nothing reddens, and under X
the fake is a no-op. Recorded in the row's comment rather than swallowed.

**(d) A PRE-EXISTING HANG, found while building a fixture, NOT this batch's.**
On a hand-written two-level fixture whose **child has zero instances**,
`descend ; go_back ; xschem netlist` pops the modal
`Please Set netlisting mode (Options menu)` (`scheduler.c:9167-9169`) and a
scripted run **hangs on it forever** — `-noalert` does not suppress it because
it is not the `alert` argument. Cause: `load_schematic()` moves `netlist_type`
aside for a file with `xctx->instances == 0` (`save.c:6469`) and the parent
reload does not put it back. **Reproduced at HEAD with no `ase::` code in the
picture at all**, so it is not the round trip's. It does not reproduce on the
real bench (tb_bandgap's trip is byte-identical). Consequences: the RT rows
drive the trip with a probe rather than a netlist and RT11 stubs
`ase::netlist_in_place`; the RT child fixture is given one instance as
insurance; and someone should file this (I am not permitted to touch
`doc/claude/issues/`).

**(e) D6's mint is now in `src/ase.tcl`, and `src/ase_window.tcl` has not
adopted it yet.** Signature: `ase::design_unreachable_msg {design {remedy {}}}`
→ `ase: design <design> is not open in this window` with `; <remedy>` appended
when non-empty. `ase::netlist` passes the Design-Window tail; a bare
`with_design_current` raise passes none. At my last read, `ase_window.tcl:7300`
still spells the head as a literal — **crew B (or the driver) must wire it**, or
D6 is decided and not done.

**(f) Nothing else in PLAN.md was found wrong.** `-fallback` (0979), the
shallowest-first scan (D2), `uplevel #0`, the entry-bounded unwind (0432 / I6),
`::keep_symbols` left alone (D3), `op_cards_capture` staying inside the body
(0436) — all as written, all implemented as written.

---

## 5. Decisions I took that PLAN.md did not settle

1. **Six procs, not three.** The ascent, the re-descend and the stranding
   sentence are separate named procs (`ase::hier_ascend_to`,
   `ase::hier_redescend`, `ase::hier_stranded_msg`), on op_annot's precedent
   (`_unwind` / `_restore`) and so the suite can drive the failure arm directly
   (row RT10) instead of having to sabotage a live trip.
2. **The re-descend re-reads `currsch` at every step** rather than replaying
   `lrange $names $lev end` blindly. If the ascent stops short — semaphore, a
   `go_back` that refuses — a blind replay walks *past* the entry level into a
   hierarchy the person never opened. `names` is indexed by level, so element
   `$c` is always the instance that leads out of level `$c`.
3. **`no_draw` is parked for the trip and the final view is painted
   explicitly**, and only when the *entry* `no_draw` was 0 (so an outer walk's
   no-draw region is not violated). `draw()` returns immediately while `no_draw`
   is set (`draw.c:10537`), so the last `descend` would not have painted.
   Measured: `drawcount` delta **1** for the whole two-level trip.
4. **The `ase::netlist` body is named `ase::netlist_in_place`**, matching the
   existing header's own word for arm (a).
5. **Error precedence** — §4(b).
6. **The read-only snapshot** — §4(a).

---

## 6. Suites, by name and status

Binary: `./src/xschem`, rebuilt not required (Tcl-only change; `make -C src` not
run because nothing under `src/*.c` moved). Every launch carried `--nolog`.
`tests/run_regression.tcl` was **not** run (issue 0990 — the driver owns it).

| suite | arm | status | checks | baseline |
|---|---|---|---|---|
| `test_ase_core` | `--nogui` | **ALL PASS** | **216** | 203 → floor RAISED by 13 |
| `test_ase_core` | `:99` (devdisplay exec) | **ALL PASS** | **216** | 203 → floor RAISED by 13 |
| `test_ase_final` | `--nogui` | ALL PASS | 82 | 82, unchanged |
| `test_op_dump_altshow` | `--nogui` | ALL PASS | 70 | 70, unchanged |
| `test_op_annot` | `--nogui` | ALL PASS (`OVERALL: ok`) | 485 | 485, unchanged |

Not asked for, run anyway because `ase::netlist` was restructured and these three
are its other callers — all `--nogui`, all unchanged: `test_ase_final_gf180`
**ALL PASS (35)**, `test_ase_persist` **ALL PASS (34)**, `test_ase_view`
**ALL PASS (32)**.

The two `test_ase_core` arms are 216 = 216 for the same reason they were
203 = 203: NT14 and RG6 still cancel, and all 13 RT rows run in both arms.

### The 13 new rows, by name and verdict (identical in both arms)

| row | verdict | what it pins |
|---|---|---|
| RT0 | ok | the fixture resolves through the same `cellview_path` accessor `ase::netlist` uses |
| RT1 | ok | `hier_instnames` `{}` at the top, `x1` at depth, indexed by level |
| RT2 | ok | `stack_level` 0 / 1 / -1, and `rc 0` on `{}`, an unbalanced brace, and a directory |
| RT3 | ok | design already current → runs in place, `drawcount` delta 0 |
| RT4 | ok | **the trip**: script at the design, person back at level 1, same `sch_path`, same view, one repaint |
| RT5 | ok | A3 row 1 — the park, plus the unparked control that makes it non-vacuous |
| RT6 | ok | A3 row 3 — refused, nothing moved, sentence names the cell, 0626 and both remedies |
| RT7 | ok | A3 row 2 — carried, back at level 1, still modified, edit present |
| RT8 | ok | the entry read-only state survives, in both directions |
| RT9 | ok | a design that is nowhere → minted head, nothing moved |
| RT10 | ok | a re-descend that cannot complete names the instance and the level |
| RT11 | ok | all four `ase::netlist` arms, measured by **where the body actually ran** |
| RT12 | ok | D6's head/tail, and `is not the current schematic` is gone from the sentence *and* from `ase::netlist`'s body |

The three `note` lines carry the actual sentences, e.g.

> `RT10 the stranded sentence = {ase: could not put you back where you were: descend into 'no_such_inst' failed (xschem descend -inst: instance not found). You are now in rt_top.sch at hierarchy level 0.}`

> `RT12 the surviving refusal = {ase: design aselib/nfet_clean is not open in this window; open it via Session > Design Window first}`

---

## 7. Hygiene

* Nothing written under `~/.xschem/`; no simulation run.
* Nothing written into `sky130A/` — checked: `git status` on `sky130A` shows only
  the `debug_st1/` directory that was already untracked before this item
  started, and no `*~.sch` newer than the session anywhere under it. The A3
  rows that need a dirty buffer run on a scratch copy of
  `tests/headless/fixtures/descend/`, never on the workarea.
* No commit, no push, no `git stash/restore/clean`.
* Nothing `pkill`ed that I did not start; the two processes I killed were my own
  stalled measurement runs, by PID.

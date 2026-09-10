# 1389 — ASE-L would start a second simulation on top of the first

**Filed** 2026-09-08, item A of the ASE-L run-guard batch
(`doc/claude/ase_run_guard_batch/CREW_BRIEF.md`).
**Status** FIXED. One rule debt (the refusal's severity and wording are the
user's to ratify), one look debt (*raised but not focused* is a claim about the
user's own keyboard and only their eyes can settle it), one suite debt (a `:0`
run of `test_ase_core`).
**Files** `src/ase.tcl`, `src/ase_window.tcl`,
`tests/headless/test_ase_core.tcl` (section **RG**, rows RG1–RG12).

## 1. The user's words, 2026-09-08

> Go ahead and update ASE-L to not be able to launch new sim while one is
> already running (issue refusal text in CIW, which will be raised (but not
> focused!))

## 2. What it cost, measured

The report that produced those words was *"annotates blanks and prints zilch in
RDW"*. Measured on the user's own bench the same morning:

1. **Two runs were launched, overlapping.** `/tmp/Xschem.log.1` carries two
   `xschem netlist` lines and two `This run is starting the simulator…` lines
   **before either** `simulation finished`. Both `Simulation > Netlist and Run`
   and the `N&>` strip button are plain Tk button commands calling
   `ase::ui::do_run`, so a double-click fires it twice — and **nothing anywhere
   checked whether a run was already in flight**: not `do_run`, not
   `do_run_existing`, not `ase::run`, not `ase::run_deck`.

2. **The deck says `set appendwrite`** (issue 0929), so run 2 *appended* its
   Operating Point plot to the raw run 1 had just started writing. The pre-run
   `file delete` in `ase::run_deck` only protects **sequential** runs: run 2
   deleted a file run 1 had not written yet.

        $ strings tb_bandgap_ase.raw | grep -E '^(Plotname|No\. Points|Date):'
        Date: Tue Sep  8 08:14:29  2026   Plotname: Operating Point   No. Points: 1
        Date: Tue Sep  8 08:14:29  2026   Plotname: Operating Point   No. Points: 1

   Same second, because they started together.

3. **`op_annot::opdump_autofill` then refuses to merge**, on its
   `raw points != 1` gate, and it is right to: `show all >` truncates, so the
   `.opinfo` is run 2's while `update_op()` publishes dataset 0, run 1's.
   Merging would paint run 2's `gm` beside run 1's node voltages.

   Control — same deck, same `ngspice-ver50`, same schematic, only the plot
   count differing:

   | raw | `xschem raw points` | after `xschem annotate_op` |
   |---|---|---|
   | 1 dataset | 1 | **8248 vectors** — 212 devices, 7825 params merged |
   | 2 datasets | 2 | 423 vectors — nothing merged, every row blank |

**The merge gate is not the defect. The double launch is.** Nothing in
`opdump_autofill` was touched.

## 3. The shape: one predicate, two consumers

`src/ase.tcl`, in the `--- Run ---` section:

| proc | what it is |
|---|---|
| `ase::run_lock_key {state}` | the absolute results-file path, via the backend's own `raw_file` hook; `{}` when it cannot be worked out |
| `ase::run_in_flight {key}` | **THE PREDICATE.** The execute id still writing `key`, or `{}` |
| `ase::run_lock_set` / `ase::run_lock_clear` | claim / release |
| `ase::run_busy_msg {key}` | the sentence, minted once |
| `ase::run_ciw_raise` | the CIW, raised and not focused |
| `ase::run_refuse {key}` | say it, raise the pane, return the words |

The two consumers of the predicate are `ase::run_deck`'s gate (the authority,
covering every door — both buttons, `ase::run`, `ase::run_existing`, a CIW
paste, any script) and `ase::ui::run_busy`, which serves both ASE-L doors.

### 3a. The key is the RAW PATH

Not the session key and not the button. The resource that must not have two
writers is the **results file**. A key on the widget catches a double-click and
misses both of the other two shapes of the same hazard: two ASE-L sessions open
on one cellview, and `Netlist and Run` racing `Run`. The resolver is the same
`[ase::backend_hook $sim raw_file] $state` that `ase::run_deck` already deletes
through, so the lock and the deletion cannot disagree about which file a run
owns. Row **RG7** is the fence in the other direction: two run directories, one
cell, both locks standing at once and neither refusing.

### 3b. ⚠ The gate is at the TOP of `run_deck`, and the plan was wrong about this

The batch plan asked for the refusal *"just before `set id [eval execute 0
$cmd]`"*. **That would have manufactured issue 0929's symptom out of the fix
for it.** Between that line and the top of the proc `run_deck`:

* `catch {file delete -- [[ase::backend_hook $sim raw_file] $state]}` — **it
  deletes the raw**, i.e. the live run's results file;
* rewrites `<cell>_ase.spice`, the deck the running simulator is reading;
* rewrites the run log header;
* deletes and rebuilds the co-simulation VCDs and `.so` files.

So the gate sits above all of it, beside `ase::run_precheck`, whose own header
already states the rule for the same reason: *"everything before this line only
READS, so a refusal leaves no deck, no raw, no log, no deleted VCD, no rebuilt
`.so` and no started process."* Row **RG3** measures it — deck bytes and raw
bytes unchanged across a refusal.

### 3c. Set after the `-1` check, cleared in `run_done`, self-healing

* The lock is set **after** `if {$id == -1}`. Set before it, one mistyped
  simulator path would brick Run for the whole session, because nothing would
  ever clear a lock whose `run_done` can never fire (row **RG8**).
* It is cleared at the **head** of `ase::run_done`, using the key carried in
  `meta` as `rawlock` rather than resolving the path a second time. Two
  resolves would be taken at different instants over a state the session may
  have edited in between — a changed run directory is one click — and the run
  that leaked its lock would be the one whose settings moved. Row **RG10**
  looks at the lock **table** rather than at the predicate, because the
  self-heal drops a dead lock *as it answers* and so can never tell "`run_done`
  released it" from "nobody has asked yet".
* **A stale lock self-heals.** `::execute(pipe,$id)` is unset by
  `execute_fileevent` at EOF (`xschem.tcl:317`), so its absence means the run
  is over however it ended. Without this arm one crashed completion bricks Run
  for the rest of the session, which is worse than the defect being fixed (row
  **RG9**).

### 3d. The doors ask first, so they can refuse without going red

`ase::ui::do_run` and `do_run_existing` both call
`ase::ui::set_status $key fail` on any raise out of `ase::run`. A refused second
launch has **nothing wrong with it**: the first run is alive and the status must
go on saying `Running`. So each door asks `ase::ui::run_busy` as its **first
statement** — above `do_run`'s design-window routing, which would otherwise
withdraw+deiconify the schematic window on its way to saying no (issue 0616's
cost), and above `ase::netlist`, which deletes and rebuilds `<cell>.spice`
before the authority would ever have seen the launch. Row **RG12** plants a
sentinel in that netlist and spies `set_status`; neutralising the two door
checks turns it into `{fail fail}` plus a rebuilt netlist.

## 4. The CIW: raised, not focused

The user put their own emphasis on the second half, and **the first attempt at
this section got it wrong**. It is recorded here in full, because the wrong
answer is the one the plan told the implementer to write.

**What the plan said, and what was shipped first:** use `raise_toplevel`
(`xschem.tcl:7635`) rather than its sibling `raise_activate_toplevel` (`:7655`),
on the grounds that only the sibling adds `xschem activate_window`, which *is*
the focus. Row RG6 then asserted, structurally, that the sibling was absent —
and a GUI leg spied which of the two helpers had been called.

**Why that was wrong.** `raise_toplevel`'s mapped arm is `wm withdraw` +
`wm deiconify`, and a **re-map is an activation in its own right**. The two
helpers are therefore *indistinguishable* in the property the user cares about,
and a row that spies which one was called could not see the defect — and did
not. Measured 2026-09-08 with a real `.ciw` (built by the shipped `ciw_create`)
and a second toplevel holding the keyboard, on all three X servers on this
machine:

| server | plain `raise` | `raise_toplevel` | `-topmost` pulse |
|---|---|---|---|
| `:99` Xvfb + openbox 3.6.1 | **rises, keyboard stays** | rises, **takes** keyboard | rises, keyboard stays, drops back when cleared |
| `:0` Xwayland (WSLg) | **no-op** | rises, **takes** keyboard | **no-op** |
| the user's own screen — `$DISPLAY` = `172.20.160.1:0`, the Windows X server, `_NET_SUPPORTING_WM_CHECK` **not found**, i.e. no EWMH WM at all | **no-op** | rises, **takes** keyboard | not measured |

So neither existing helper is right on its own: `raise_toplevel` takes the
keyboard everywhere, and the plain `raise` that honours the user's emphasis is
issue 0054's measured no-op on two of the three servers here.

**The shipped order is therefore: plain `raise` first, VERIFY it moved, re-map
only if it did not.** On a real window manager the user gets exactly what they
asked for. Where the server ignores a raise the CIW still comes forward and the
keyboard goes with it — a platform limit, not a policy choice, and the right way
round, because a refusal nobody sees is not a refusal.

* **The verify compares against the toplevel that holds the keyboard**
  (`wm stackorder .ciw isabove $keeptop`), not against `wm stackorder`'s top. At
  refusal time that is the ASE-L window — exactly the thing the CIW has to get
  in front of — and a transient dialog legitimately above everything must not
  push the code onto the focus-stealing arm.
* **A focus restore on the fallback path was tried and rejected on the
  measurement.** `focus -force` back onto the saved widget, both immediately and
  again at 250 ms: on `:0` the compositor re-focuses the freshly mapped window
  after both, so the line never helps and can only yank the keyboard away from
  wherever the user has since moved. A `wm attributes -topmost` pulse was tried
  too — it works on openbox and is the same no-op on `:0`, and it drops the pane
  back down the moment it is cleared.
* **The guard is existence, not visibility.** A closed CIW is **withdrawn**,
  not destroyed (`wm protocol .ciw WM_DELETE_WINDOW {wm withdraw .ciw}`,
  `ciw.tcl:435`), so `xschem::notify_ciw_visible` answers 0 for a pane that is
  perfectly alive. Using that as the gate would drop the refusal into a widget
  nobody can see — the one case where the raise is the whole point. An unmapped
  pane cannot be raised into view at all, so it takes the re-map arm directly.
  **Decision: a CIW the user closed IS re-shown by a refusal.** It is the
  channel the user named, and a refusal nobody sees is not a refusal.

**Row RG6 was rewritten to match.** The structural row now asserts the *order*
(plain raise, then the stackorder verify, then `raise_toplevel` as the fallback,
and `raise_activate_toplevel` / `activate_window` still absent) rather than a
helper name. The GUI leg no longer spies procs: it stands up a real `.ciw` and a
stand-in for the ASE-L window, puts the keyboard in the stand-in, runs the
refusal, and reads **where the CIW ended up and whether the keyboard moved**.
Its strong arm is gated on a probe of *this* server rather than on a display
name, because on a server that ignores a plain raise the keyboard is not ours to
keep. On `:99` the probe answers yes and the strong arm is what runs; with the
fix reverted it reports `{1 0}` — the CIW rose and the keyboard went with it.

Everything in `ase::run_ciw_raise` is guarded and caught: it returns 0 under
`--nogui` (no `winfo`), 0 under `--nolog` (`.ciw` never created), and never
raises — a notice may not break the caller it is reporting to (`ase::echo`'s
own rule, issue 0666), and this one is reporting a refusal.

## 5. The sentence

    ase: a simulation is already running for tb_bandgap_ase.raw; stop it first (Simulation > Stop)

* **The way out is READ, never retyped.** `ase::ui::menu_path_stop` is item B's
  mint (issue 1391) and the Simulation menu is **built** from it, so renaming
  the entry moves this sentence with it. A literal `Simulation > Stop` in
  `ase::run_busy_msg` would be exactly the drift that mint exists to prevent —
  measured once already in this tree as `Outputs > Save All` versus
  `Outputs > Save All… > Save device OP parameters (gm, gds, vth, ...)`, string
  match 0, issue 0661. Row **RG5** asserts the constant, its literal golden
  **and** the absence of a retyped copy in the builder's body.
* The constant is **guarded, not given a fallback string** — a fallback *is* the
  second literal. A tree without the constant loses the remedy clause, not the
  notice.
* It names the **results file**, not the cell: the lock is per results file, so
  the file is the thing the refusal is actually about.

  ⚠ An earlier draft of this section claimed the file name *disambiguates which
  of two ASE-L sessions on one cellview is in the way*. **That is false and it
  was measured false**: two sessions on one cellview share one rundir and one
  raw, so `[file tail $key]` is the identical string for both. The name says
  which FILE, never which session.

### ⚠ 5b. The remedy clause has to be true — and it was not

The sentence tells the reader to press `Simulation > Stop`. Measured 2026-09-08,
before this was fixed, that was a **no-op in exactly the cases the raw-path key
was chosen for**, because `ase::ui::do_stop` was keyed on the session's `run_id`
attr and only the session that launched holds one:

* **Two ASE-L sessions on one cellview** (`ngspice_state1` + `ngspice_state2`,
  one rundir, one raw, therefore one lock — §3a's own hazard). Session B is
  refused, told to press Stop, and B's Stop answers *"ase: no simulation running
  for this session"* over a run that is alive. **B can neither run nor stop.**
* **A run started from the CIW or a script** — a door §3 says the authority
  covers — sets no `run_id` at all.
* **Closing and re-opening the ASE-L window mid-run.** `ase::ui::close` calls
  `ase::session_close` (`ase_window.tcl:335`), which drops every attr: `run_id`
  goes `12` → `{}` for the very session that launched.

`ase::ui::do_stop` now tries the session attr first (it names the exact run this
session started) and falls back to **the lock**, through the same predicate the
refusal used — `ase::run_in_flight`. Measured after the fix: B's Stop kills the
run, the pipe is gone and the lock is released; the reopened session's Stop does
the same; and with nothing running the honest sentence is still printed. Rows
**RG13**. The wording of `do_stop`'s own "nothing to stop" sentence is
unchanged — it is still true when both lookups fail.

### ⚠ 5a. `note`, not `error` — and this is the user's to ratify

Refusing is **not** reporting a failure. Nothing has gone wrong, an earlier run
is healthy and still writing, and an `error` tag would paint the CIW red about a
session that is fine. `note` is `ciw.tcl:452`'s own tag for *"a result the user
must NOTICE without it being an error"* (dark orange). Row **RG4** pins the tag.

Recorded as **rule debt 1389**: the severity tag and the exact wording are
user-visible copy the user has not ruled on.

## 6. Fences — `tests/headless/test_ase_core.tcl` section RG

Nineteen checks, `RESULT: ALL PASS` at **184 → 203**. A `holdsim` backend
(`sleep 30`, the ngspice hooks otherwise) gives a genuinely live run to race;
`sleep` and not a stdin-reading stub, because `execute` opens the pipe in mode
`r` and the child would inherit the suite's own stdin.

| row | claim |
|---|---|
| RG1 | an ordinary launch starts **one** simulator and claims the raw path it is about to write |
| RG2 | a second launch on that raw is refused and **`execute` is not called** |
| RG3 | the live run's deck and results file are byte-unchanged by the refusal |
| RG4 | the refusal reaches the **CIW sink** (spied at `ciw_echo`, not at `ase::echo`), once, tagged `note` |
| RG5 | it names `Simulation > Stop` by reading 1391's constant — constant, golden, and no retyped copy |
| RG6 | the focus-free `raise` is tried FIRST and verified, `raise_toplevel` is only the fallback — structural, plus a GUI leg that measures where the CIW ended up **and whether the keyboard moved** |
| RG7 | two different results files do not block each other |
| RG8 | a launch that failed to start leaves no lock |
| RG9 | a stale lock does not refuse, and is dropped |
| RG10 | an ordinary completion clears the lock **in `run_done`**, not by the sweep |
| RG11 | after Stop the file is free and the next launch really starts |
| RG12 | both doors refuse without starting a simulator, without `set_status fail`, without re-netlisting |
| RG13 | the remedy the sentence names is a way out **for the reader**: Stop from a session holding no `run_id` kills the run and frees the file, and with nothing running Stop still says so |
| RG14 | a raise that **is** the refusal is neither said twice nor allowed to redden a live run — and an ordinary failure still reddens and still speaks |

**RG1, RG7 and RG11 are the counterweights.** A patch that simply broke
launching would satisfy RG2, RG3, RG4, RG5 and RG12 with full marks; those three
are the only rows that can tell *refuses a second run* from *refuses to run*.

### Discriminators, run in two passes

| neutralisation | reds |
|---|---|
| the gate deleted from `run_deck` | RG2, RG3, RG4, RG6, RG6-GUI (+RG7 by cascade) |
| `raise_activate_toplevel` swapped in | RG6, RG6-GUI |
| the `run_lock_clear` deleted from `run_done` | RG10 |
| the lock set **above** the `-1` check | RG8 |
| the self-heal deleted from `run_in_flight` | RG9 |
| both door pre-checks deleted | RG12 (`{fail fail}` + a rebuilt netlist) |
| `run_ciw_raise` reverted to `raise_toplevel` only | RG6 `{0 0 1 0 0 1}`, **RG6-GUI `{1 0}` — the CIW rose and took the keyboard**, which is the defect the old spy-the-helper leg could not see |
| `do_stop`'s lock fallback deleted | RG13 (*"no simulation running for this session"* over a live run) |
| `run_raised`'s refusal arm deleted | RG14 (the sentence echoed a second time, as `error`, and the status went `fail`) |
| both doors re-inlining the redden | RG14 wiring row `{0 0}` |

## 7. What was deliberately NOT done

* **`ase::run` and `ase::run_existing` do not carry a copy of the gate.** One
  predicate — `ase::run_in_flight`, the only reader of the lock table — and
  three *consumers*: `run_deck`'s gate (the authority), `ase::ui::run_busy` (the
  doors), and `do_stop`'s fallback (§5b). Three callers of one answer is
  invariant I1 kept; two procs each deciding what *running* means is what it
  forbids.

  The cost, measured and accepted: a script or CIW paste calling `ase::run`
  during a live run re-netlists `<cell>.spice` on its way to being refused — a
  planted sentinel in that file is replaced by a fresh 331-byte netlist, with
  `execute` called zero times. It is harmless (the running simulator reads
  `<cell>_ase.spice`, and the netlist is deterministic output regenerated from
  the same schematic), and the UI doors — which is how a user gets there — refuse
  before that point, which RG12's sentinel row pins.
* **`ase::ui::run_busy` creates the run directory, and that is left alone.**
  `run_lock_key` → the backend's `raw_file` hook → `ase::rundir`, which does
  `file mkdir` (`ase.tcl:4414`). So pressing a door on a session whose design
  cannot be resolved now creates the rundir before refusing. Measured: rundir
  exists 0 → 1, message unchanged. The obvious tidy — resolve `design_path`
  first — would put the refusal check *below* a `set_status $key fail` arm, i.e.
  it would redden a session whose earlier run is alive and healthy, which is the
  defect this whole item is about. The `mkdir` is idempotent and creates the
  directory `run_deck` would create microseconds later.
* **No lock is taken on a launch that cannot name its results file.**
  `run_lock_key` answers `{}` for a state with no simulator, no design cell, or
  a backend whose `raw_file` hook raises. `{}` is not a lock: a launch that
  cannot say which file it will write cannot be refused for writing one, and
  every such state fails a few lines later for a better-named reason.
* **`opdump_autofill`'s `raw points != 1` gate is untouched.** It was correct.

## 8. Residual risk — and the part of it that turned out to be REACHED

Between the gate and the lock there is one `run_deck` body, and Tcl is
single-threaded, so nothing can interleave **unless something in that body pumps
the event loop**. Nothing on the analog path does (`ase::netlist` is a C call,
`cosim_build` execs synchronously).

⚠ **But `ase::ui::do_run` itself calls `update`, and an earlier draft of this
section wrote that window off as unreached. It is reached by the originating
gesture.** The `update` sits in the design-window routing arm — the arm whose
own comment says it *"fires routinely while the design window is fully visible
and front"*. A second press dispatched inside that `update` re-enters `do_run`,
passes `run_busy` (no lock yet), launches and locks; the outer press then meets
the lock inside `ase::run_deck`. Measured 2026-09-08 with the second press
queued as a real X event (`event generate -when tail`, not a timer; the timer
variant gives byte-identical results):

* one simulator started — **the guard's core job held**;
* the status segment went `running` → `fail`: a red *Error* over a run that was
  alive and healthy;
* the same sentence reached the CIW **twice**, once as `note` and once as
  `error` — the opposite of §5a's decision.

**What was fixed, and what was not.** The race window itself is left open: a
"pending claim" state would need every raising path between claim and launch to
release it, i.e. a new leak class. What is closed is the *outcome*. Both doors
now route a raise out of `ase::run` through `ase::ui::run_raised`, which
recognises the refusal **by the minted sentence itself** — the gate returns
exactly `ase::run_busy_msg` of the key it refused, and `ase::run_lock_set` is
the last statement before `run_deck` returns, so nothing else can raise while
this session's results file is locked. Anything that is not that sentence still
reddens and still speaks. Measured after the fix, same gesture: one `execute`,
status `{running}`, and one CIW line, tagged `note`.

Rows **RG14**, deterministic rather than a re-raced gesture — CLAUDE.md's own
rule that a bug only one environment can reproduce is a test defect too. The
refusal text the rows feed in is taken from a real refused `ase::run_deck`, so
they cannot pass against a hand-typed sentence that has drifted from the one the
gate raises.

## 9. Debts

* **rule 1389** — the refusal's severity tag (`note`, not `error`) and its
  wording, including naming the results file rather than the cell.
* **look 1389** — *the CIW rises and the keyboard stays in ASE-L.* This is
  **no longer** a proxy on `:99`: RG6's GUI leg measures the stacking order and
  the focus, and with the fix reverted it reads `{1 0}`. It stays a look debt
  because of the third row of §4's table — the user's own screen has **no EWMH
  window manager**, and there a plain `raise` is a measured no-op, so the CIW
  can only be brought forward by a re-map, which takes the keyboard. On their
  machine the emphasised half is **not** delivered, and whether that is
  acceptable, or worth chasing further into the Windows X server, is theirs to
  say. Do not report this half as done on a green suite.
* **suite `test_ase_core`** — one `:0` run, per CLAUDE.md's rule for a GUI
  feature. There is no standing GUI-gate approval, so it belongs in the
  driver's `owed.sh drain` batch, not a subagent transcript.

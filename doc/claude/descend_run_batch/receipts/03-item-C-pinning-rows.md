# Receipt 03 — item C: pinning what already works at depth

Scope as briefed: **test files only**, and exactly one moved —
`tests/headless/test_ase_core.tcl`. No `src/` file touched, no
`tests/headless/test_ase_window.tcl` (crew B's), no `doc/claude/issues/*`.
Nothing committed, nothing pushed, no `git checkout/restore/stash/clean`.
No new suite file, so **no `full_audit.sh` change was needed** —
`test_ase_core` is already in `nogui_tests` (`full_audit.sh:161`).

---

## 1. The four rows PLAN item C asks for — what was already there

| PLAN item C row | verdict | where it lives |
|---|---|---|
| 1. pin the annotation basis at depth | **NOT covered — built here** | `DX2` + `DX3` |
| 2. end-to-end descended netlist, byte-identical | **NOT covered — built here** | `DX4` (+ `DX5`, `DX6`, `DX7`) |
| 3. the 0626 refusal (modified + `autosave_backup 0`) | **ALREADY COVERED by crew A** | `RT6` (`test_ase_core.tcl:3035`) |
| 4. the lossless return (modified + `autosave_backup 1`) | **ALREADY COVERED by crew A** | `RT7` (`test_ase_core.tcl:3060`) |

RT6 and RT7 are crew A's implementation of the A3 decision table, and that
table's rows 3 and 2 **are** PLAN item C's rows 3 and 4 — same premise, same
assertions, plus more (RT6 also requires the sentence to name the cell, issue
0626 and both remedies; RT7 also requires the edit itself to still be in the
buffer, not merely the flag). **No duplicate was added.** Crew A also
independently added `RT8`, which PLAN has nowhere: the read-only axis
`cadence_style_rc:564` forces on every descended level, without which rows 3 and
4 are unreachable at all.

So item C's real remaining work was rows 1 and 2, and the anti-vacuity around
them.

---

## 2. What was added

`tests/headless/test_ase_core.tcl`, new section **DX** at `:3216`, last in the
file, inside the big catch — after crew A's `RT`, so nothing above it can be
perturbed by a fixture that loads schematics and registers a session.

**8 rows, `DX0`–`DX7` (`:3400`–`:3552`), plus 3 `note` evidence lines.**
Floor 216 → **224**, both arms.

### The fixture

A three-level hierarchy in the suite's **existing** scratch `aselib`, in the
cadence `lib/cell/view` layout the rest of the file already uses, so nothing
touches `::pathlist`, `::XSCHEM_LIBRARY_PATH` or the scratch `library.defs`:

```
aselib/dx_top  -x1->  aselib/dx_mid  -x1->  aselib/dx_leaf
```

`sch_path` at the bottom is `.x1.x1.` — the user's exact reported shape,
measured, not assumed (`DX0`). The top carries a source (`V1`) and a testbench
net (`TNET`) the leaf has never heard of, which is what makes `DX5`'s
discrimination possible. Every sheet carries at least one instance, because a
zero-instance child is crew A's §4(d) modal hang (issue 1394).

`aselib/dx_fet` is the annotated device, with its **own** `type=dxs8fet` token
so registering a descriptor for it cannot shadow a PDK's `nmos` for any row
above (op_annot's `match` key exists for exactly that collision), and with a
**hierarchy-aware devproc** — the third argument a devproc receives is
`sim_sch_path`, the one seam where the hierarchy enters a device path. A fixture
whose devproc returns a constant cannot see a wrong level at all; the note above
`H1` in `test_annot_hier_0911.tcl` says so about the same trap, and it is the
reason `DX2`/`DX3` read the built path and the rendered block rather than only
the two getters.

**The raw is written into the scratch tree** by the suite (three numbers in a
text file; an operating point needs no simulator). Nothing under `~/.xschem/`
was read or written, and **no simulation was run**.

### The rows, and what each one actually proves

| row | proves |
|---|---|
| **DX0** | the fixture reproduces the report — `currsch 2`, `sch_path .x1.x1.`, standing on `dx_leaf.sch`, `schname 0` still the design — and the design resolves to a registered cellview a session can bind to. Without this row everything below could pass on a hierarchy that never formed. |
| **DX1** | from two levels down, `ase::session_for_current` answers the **design's own level** (`{key 0 aselib dx_top schematic}`), and `ase::ui::design_window` returns 1 having found the **descended** window — `currsch` still 2, `sch_path` still `.x1.x1.`. It is the second half of the user's own gesture, and it must not re-open the design at level 0 and throw the navigation away. |
| **DX2** | **THE PIN.** `op_annot::db_attach $raw <level from the session>` → `{1 {}}`, `xschem get raw_level` **0**, `xschem get sim_sch_path` **`x1.x1.`**, `op_annot::devpath MZZ1` **`@m.x1.x1.mzz`**, and the block renders `id = 10u | gm = 100u | gds = 1u`. This is CREW_BRIEF §3's measurement turned into a regression row: `Simulation > Run` pressed while descended does **not** annotate blanks. |
| **DX3** | **THE NEGATIVE CONTROL — the bare door.** The *same file* through the *same proc* with the level withheld: `raw_level` **2**, `sim_sch_path` **empty**, `devpath` **`@m.mzz`**, block **blank**. Four columns, all different from DX2, so DX2 cannot pass on a constant. |
| **DX4** | **the end-to-end descended netlist.** `ase::with_design_current` + `ase::netlist_in_place` from two levels down produces a `dx_top.spice` **byte-identical** to one `ase::netlist` wrote at the top (871 = 871), and the person comes back to level 2, the same sheet, the same `sch_path`. |
| **DX5** | …and that is not free. The netlist a person gets standing there **without** the round trip is the **leaf alone**: 178 bytes, contains `dx_leaf`, contains **no** `dx_mid`, **no** `TNET`, **no** `V1`. This is the defect the shipped guard existed to prevent (`global_spice_netlist()` netlists `xctx->sch[xctx->currsch]`), and it is what stops DX4 being a tautology. |
| **DX6** | structural: `ase::netlist`'s arm (c) **is** the composition DX4 drives — `ase::with_design_current`, `ase::netlist_in_place $state $cell`, `ase::stack_level $path` — and the shipped `is not the current schematic` sentence is **absent** from the body. If someone re-spells arm (c), DX4 would keep passing about code the product no longer runs; this is the row that goes red. |
| **DX7** | the **real** `ase::netlist`, called from two levels down, end to end. **One row, two premises, and they are the product's own two contracts**: under a display it takes arm (c) and must come back at level 2 on the leaf; headless it takes arm (b) (`xschem load`, deliberately ahead of (c) — see `ase::netlist`'s own header) and ends at level 0 on the design. Byte-identical to the top's deck either way, which is the half both contracts share. |

Neither arm skips DX7, so **224 = 224 stays true**.

---

## 3. A/B — every row was made to fail

Method: the brief forbids editing `src/`, so each sabotage is a **runtime
override of the product proc**, injected into a **scratch copy** of the suite
(`…/scratchpad/ab/ab_S<N>.tcl`; the only other change to the copy is one line so
it resolves its helpers from the real `tests/headless`). `src/` was never
touched — `git status` shows `tests/headless/test_ase_core.tcl` as my only
modified file.

| sabotage | what it breaks | rows that went RED |
|---|---|---|
| **S0** | `dx_descend` descends **once** | DX0 DX1 DX2 DX3 DX4 DX5 — the fixture premise, so everything built on it |
| **S1** | `ase::ui::raise_design_editor` reduced to its **pre-0168 first scan** (match on the window's current `schname` only) | DX1 DX2 DX3 — the design gets re-opened at level 0 and the person's navigation is gone, which then destroys the basis rows too |
| **S2** | `op_annot::db_attach` **drops the level** (the bare door) | **DX2 only** |
| **S3** | `op_annot::db_attach` always passes **level 0** | **DX3 only** |
| **S4** | `ase::with_design_current` runs the script **in place**, no ascent | **DX4 only** headless; DX4 **and DX7** on `:99` (which is itself proof the X arm really takes arm (c)) |
| **S5** | the "bare" deck taken at the **top** instead of at depth | **DX5 only** |
| **S6** | `ase::netlist` replaced by a one-line delegate — same behaviour, different body | **DX6 only** |
| **S7** | the **shipped guard restored** in front of `ase::netlist` (`is not the current schematic; open it via Session > Design Window first`) | DX6 DX7, in **both** arms |

Verbatim, the two that matter most:

```
S2  FAIL: DX2 THE PIN: ... -> {0 {1 {}} 2 {} {@m.mzz} {id = | gm = | gds =}}
         (exp {0 {1 {}} 0 x1.x1. @m.x1.x1.mzz {id = 10u | gm = 100u | gds = 1u}})
S7  FAIL: DX7 ... (a display: arm (c), the round trip) ...
         -> {1 -1 2 .x1.x1. dx_leaf.sch} (exp {0 1 2 .x1.x1. dx_leaf.sch})
```

Every sabotage run's other 216–223 checks stayed green, so no sabotage was
merely knocking the suite over.

---

## 4. Suites, by name and status

Binary `./src/xschem`; `make -C src` → **"Nothing to be done"** (this item is a
test file only, and no `src/*.c` moved under it). Every launch carried
`--nolog`. `tests/run_regression.tcl` and `tests/headless/full_audit.sh` were
**not** run — the driver owns both (issues 0990 / the brief).

| suite | arm | status | checks | floor |
|---|---|---|---|---|
| `test_ase_core` | `--nogui --pipe -q --nolog` | **ALL PASS** | **224** | 216 → **raised to 224** |
| `test_ase_core` | `devdisplay.sh exec … --pipe -q --nolog` (`:99`, openbox 3.6.1 live) | **ALL PASS** | **224** | 216 → **raised to 224** |
| `test_ase_window` | `--nogui` | **ALL PASS** | 49 | 49, unchanged |
| `test_op_annot` | `--nogui` (`OVERALL: ok`) | **ALL PASS** | 485 | 485, unchanged |

Exact commands:

```sh
./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_core.tcl
tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_core.tcl
./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_window.tcl
./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_op_annot.tcl
```

* Zero `FAIL`, zero `UNEXPECTED ERROR` in either `test_ase_core` arm; exit 0.
  The only `SKIPPED` is the pre-existing `NT14` under X.
* Repeated: headless 2/2 identical (224), `:99` 2/2 identical (224). No flake.
* All eight `DX` names appear as `ok:` in **both** arms, and
  `note: DX7 arm taken` reads `0` headless and `1` on `:99` — the row's two
  premises really are being taken.

---

## 5. `untitled~.sch` — confirmed clean, with one honest caveat

`ls untitled~.sch tests/untitled~.sch` after **every** run since:
**both absent.** `find` for any `*~.sch` newer than the session outside
`tests/headless/.scratch/` finds nothing. `git status` shows no new file.

⚠ **My first suite run reported `FAIL: C11 no untitled~.sch was dropped in the
repo root (issue 0609)` and the file was NOT the suite's.** It was left by one
of my own earlier *prototype* scripts — an early measurement that faked
`::has_x`, hit the `winfo` trap in §6(d) below and died mid-script, and whose
dying untitled buffer wrote the backup. Deleted; the suite has been green on
C11 in all four runs since. Worth recording for the next reader: **C11 catches a
leftover from any process, not just its own run**, so a red C11 is a reason to
look at what else has been running in the tree before assuming the suite did it.

---

## 6. What I found wrong or missing in PLAN.md

The driver asked to be told. Five things.

**(a) PLAN item C rows 3 and 4 were already built before item C was
dispatched.** Crew A's A3 decision table produced RT6 and RT7, which are those
two rows with more teeth. PLAN lists all four as item C's, and a crew that took
PLAN literally would have shipped two duplicates. See §1.

**(b) PLAN item C row 2 says the byte-identity row belongs "on that bench"
(tb_bandgap in the `sky130A` workarea), and crew A's RT header repeats it. I did
not use it, deliberately.** Descending into and returning through
`sky130_tests_ase/bandgap_opamp` ends in `set_modify(1)` (CREW_BRIEF §4), and
`set_modify(1)` calls `write_backup()` (`src/actions.c:208` →
`src/save.c:6139`), which writes `<cell>~.sch` **into the repo tree**. My
dispatch brief forbids that, and crew B avoided the same cells for the same
reason. The hermetic three-level fixture proves the same property — byte
identity, `cmp` equivalent, in-process — and gives a **stronger** anti-vacuity
control than the bench could, because I control what only the top has (`V1`,
`TNET`) and can assert their absence from the leaf-alone deck. CREW_BRIEF §2's
own `cmp = 0` on tb_bandgap remains the bench measurement; DX4 is the committed
row.

**(c) PLAN item C row 1 does not mention that its premise depends on issue
0168.** The row calls `ase::ui::design_window`, which finds a descended window
only through `raise_design_editor`'s **second** scan (`xschem windows` field 6,
the window's hierarchy stack). With that scan gone the proc falls through to
`xschem load -gui` and the person is dumped at level 0 — sabotage **S1**, and it
reds DX1, DX2 and DX3 together. Anyone re-deriving this row on a tree without
0168 would conclude the annotation basis was broken when it is the *window
lookup* that is.

**(d) A trap nothing in PLAN or CREW_BRIEF records: `ase::netlist`'s arm (c)
CANNOT be reached from a `--nogui` process by faking `::has_x`, because the fake
breaks the netlister itself.** `set_sim_defaults` (`src/xschem.tcl`) evaluates
`[info exists has_x] && [winfo exists .sim]`, and a `--nogui` process has no
`winfo` command at all, so the fake makes `sim_is_ngspice` / `sim_is_xyce` raise,
which takes the `netlist` Tcl proc with them. Measured, verbatim:

```
tcleval(): evaluation of script: netlist $::__tcl_call_a1 noshow $::__tcl_call_a2 failed
         : invalid command name "winfo"
== nldep = {1 ase: netlist not produced: .../nl_dep/dx_top.spice}
```

Crew A met the soft half of this (receipt 01 §4(c) — the eight stderr lines) and
never hit the hard half because RT11 **stubs** `ase::netlist_in_place`, so no
real netlist ever ran under the fake. It is the whole reason DX4 is driven at the
composition (with DX6 locking that composition to the product's body) and DX7
carries two arm-specific premises instead of one faked one.

**(e) The suite header was left stale by item A and I updated it.** It still
read *"THE CHECK COUNT IS 203 IN BOTH ARMS"* while the file was running 216 —
exactly the kind of number a later crew quotes as a floor. It now reads 224, the
history line runs `173/172 → 184 → 197 → 203 → 216 (RT, item A) → 224 (DX, item
C)`, the `RT*` and `DX*` sections are in the file's own index, and the
"announced skips cancel" paragraph now says explicitly that DX7 does **not**
skip either way.

**Nothing else in PLAN item C was found wrong.** The `sim_sch_path` = `x1.x1.` /
`raw_level` = 0 expectations, the `db_attach $raw {}` negative control, the
"never `~/.xschem/simulations/`" rule and the "pin, do not fix" framing of
CREW_BRIEF §3 all hold exactly as written and are what the rows assert.

### One thing from another receipt, now closed

Crew A's receipt 01 §4(e) flagged that `src/ase_window.tcl` had not adopted D6's
mint. It has: `src/ase_window.tcl:7300-7307` now calls
`ase::design_unreachable_msg` under a comment naming D6. **D6 is decided and
done**; no action left for the driver there.

---

## 7. Hygiene

* Only `tests/headless/test_ase_core.tcl` modified. `src/` untouched;
  `tests/headless/test_ase_window.tcl` untouched; no issue file touched.
* Nothing written under `~/.xschem/`; nothing read from
  `~/.xschem/simulations/`; **no simulation run**.
* Nothing written into the repo tree: the fixture, the raw and every netlist
  artifact live under `tests/headless/.scratch/` (gitignored, self-sweeping).
  Verified `git status` shows no new file and no `*~.sch` anywhere outside it.
* The one `untitled~.sch` that existed was my own prototype's corpse, deleted;
  see §5.
* The binary was always given a path (`./src/xschem` or
  `devdisplay.sh exec ./src/xschem`); every launch carried `--nolog`.
* `run_regression.tcl` and `full_audit.sh` not run (driver owns both).
* Nothing `pkill`ed. The shared `:99` display and its openbox were left exactly
  as found (`state: alive`, `wm: openbox`, same Xvfb pid before and after).
* No commit, no push, no `git checkout/restore/stash/clean`.

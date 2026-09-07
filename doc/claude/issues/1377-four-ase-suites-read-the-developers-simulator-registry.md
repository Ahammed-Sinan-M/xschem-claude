# 1377 — EIGHTEEN suites read the developer's own simulator registry

**Status:** FIXED (2026-09-07), on `fluid-editing`, in the ASE-L registry batch.
**Found by:** the batch driver, while taking the baseline for the registry batch.
**Filed as four suites. The first round made it six. AN EMPIRICAL SWEEP OF ALL
383 HEADLESS SUITES MADE IT SEVENTEEN, plus one isolated as a precaution.** The
count moved twice because the first two surveys were source greps, and a source
grep cannot answer this question — see the survey section, which is the part of
this file that matters most to whoever reads it next.

**Files:** `tests/headless/scratch.tcl` (the shared helper), and the eighteen
suites that call it: `test_ase_core.tcl`, `test_ase_persist.tcl`,
`test_ase_final.tcl`, `test_ase_preflight.tcl`, `test_ase_sod_case.tcl`,
`test_ase_final_gf180.tcl` (round 1) and `test_ase_hier_pick_0161.tcl`,
`test_ase_bus_bits_0159.tcl`, `test_ase_interact.tcl`,
`test_ase_locked_wire_pick_0160.tcl`, `test_ase_log_seam_0207.tcl`,
`test_ase_optier_0963.tcl`, `test_ase_plot.tcl`, `test_ase_unnamed_net.tcl`,
`test_ase_window.tcl`, `test_netlist_case_collision.tcl`,
`test_sod_pick_no_select_0204.tcl`, `test_wave_viewer.tcl` (round 2).
`test_ase_window.tcl` carries a second change, on W7, for the reason the survey
section gives.

## The defect

`~/.xschem/ase_simulators` is read once at startup by `src/xschem.tcl`
(`ase::sim_load_conf`, one line beside the other startup loaders). Every
`--script` suite therefore begins with the **developer's** registry already
loaded into `ase::simulators`, `ase::sim_use` in force, and the resolver
answering `source registry` instead of `source path`.

Four suites read that answer and pin an expectation against it. The moment the
user registers a simulator — which a blog post on this branch now tells new
readers to do — the suites start lying:

| suite | real `HOME` | `HOME` = empty dir |
|---|---|---|
| `test_ase_persist`   | **5 FAILED** (131 passed) | ALL PASS (136) |
| `test_ase_core`      | **7 FAILED** (174 passed) | ALL PASS (181) |
| `test_ase_final`     | **3 FAILED** (78 passed)  | ALL PASS (81)  |
| `test_ase_preflight` | **2 FAILED** (112 passed) | ALL PASS (114) |
| `test_ase_sod_case`  | **11 FAILED** (41 passed) | ALL PASS (52)  |

Same tree, same commit, same binary. The failing rows name the cause themselves:

* `test_ase_core` **E1e** expected `ngspice -b <deck>` in the run log's
  `command :` line and got
  `/home/analog/dev/ngspice/build-ver_50/src/ngspice -b -D casemode=preserve <deck>`;
* `test_ase_core` **C5b / C6 / C8** lose their per-device `.save` cards because
  the registered build measures the `altshow` capability, so `ase::op_save_tier`
  moves from shape `c` to shape `d`;
* `test_ase_final` **F18 / F14 / F15** expected
  `i(@m.xm1.msky130_fd_pr__nfet_01v8[id])` and got
  `i(@M.XM1.Msky130_fd_pr__nfet_01v8[id])` — **the capitals are the case-mode
  feature working**, and the goldens are folded;
* `test_ase_persist` **G3s / G6 / G7 / G8 / G10** read `v(D)` where they pin
  `v(d)`, same cause;
* `test_ase_preflight` **PF215c** says it in words: *"the mode comes from the
  run request (got 'preserve' want 'distinguish')"*, and **PF215d** falls with it;
* `test_ase_sod_case` **SC197 / SC198 / SC200 / SC202b / SC203c / SC204c / SC211
  / SC205 / SC205c / SC206 / SC206b** — eleven rows, every one of them a `fold`
  row reading a PRESERVED spelling: `v(TOPNET)` for `v(topnet)`, `i(V9)` for
  `i(v9)`, `i(E.Xm.Xl.E1)` for `i(e.xm.xl.e1)`, and `SC205 sod_case_mode reads
  the global floor: fold` answering `preserve`. `ase::sod_case_mode` resolves
  through `ase::sim_casemode_requested`, so the entry in force beats the floor
  the row is about. **This suite was already red on the developer's box and was
  not on the batch's list of four.**

**Using the feature reddens the suite that guards it.** And because the four are
exactly the suites that would catch a regression in the registry code, a red
they already carry is a red nobody reads.

## It is worse than "red on this developer's box"

A THIRD registry — a nonsense program with `-casemode distinguish`, written into
a scratch `HOME` for this issue — does not merely move the count. Measured at
`e49d3cc1`, before the fix:

```
test_ase_core       hostile HOME  1 FAILED (121 passed)   <- ABORTED: UNEXPECTED ERROR:
                                    ase: REFUSED — There is no file at /nonexistent/bin/frobnicator
test_ase_final      hostile HOME  1 FAILED (25 passed)    <- ABORTED, same refusal
test_ase_persist    hostile HOME  13 FAILED (53 passed)   <- G4 run never starts;
                                    then UNEXPECTED ERROR: invalid command name ".wvmenubar.cursors"
test_ase_preflight  hostile HOME  ALL PASS (114 checks)   <- passes for the WRONG REASON:
                                    the hostile entry's `distinguish` is what PF215c wanted
test_ase_final_gf180 hostile HOME 1 FAILED (30 passed)   <- ABORTED, same refusal; G9/G10
                                    (the real-simulator rows) never run, 4 checks vanish
test_ase_sod_case   hostile HOME  ALL PASS (52 checks)   <- also for the WRONG REASON:
                                    a registry naming a MISSING program makes sim_status
                                    refuse, so the FLOOR answers and the fold rows pass
```

`test_ase_sod_case` is the sharpest shape of all: it is green under an empty
registry AND green under a broken registry, and red only under a registry that
**works**. No HOME anybody would think to try as a control reproduces it.

Two suites stop measuring 130 and 55 checks early with no verdict on anything
below the abort, and one goes green by coincidence. A count-based reading of any
of those three is worthless.

## The fix

A shared, opt-in helper in `tests/headless/scratch.tcl` — the file all four
already source, and whose own charter block (line 5) is *"a USER_CONF_DIR to keep
xschem's config writes off the developer's real ~/.xschem"*:

```tcl
test_sim_registry_isolate      ;# forget every registered simulator + measured cap
test_sim_registry_state        ;# {entries selected status-entry status-source}
```

`test_sim_registry_isolate` calls `ase::sim_clear` and `ase::sim_caps_clear`,
and empties the rc-layer seeds `::ASE_SIMULATORS` / `::ASE_SIMULATOR` so nothing
can re-seed from them. It touches no file at all: **the user's
`~/.xschem/ase_simulators` is never read, written, moved or backed up** — the
isolation happens in memory, after the startup load, inside the suite.

**Seventeen** of the eighteen call it just below their
`set scratch [test_scratch ...]` — three lines below in sixteen of them and
five below in `test_ase_preflight`, not "on the line after", which is what this
sentence said until the close-out round measured it; the eighteenth, `test_ase_hier_pick_0161`,
**does not call `test_scratch` at all** — the repair added a
`source .../scratch.tcl` line to it purely to reach the helper, and the isolate
call sits directly under that. (Measured 2026-09-07:
`grep -c test_scratch tests/headless/test_ase_hier_pick_0161.tcl` = **0**;
harmless, because `scratch.tcl` only wraps `::exit` for cleanup and that suite
registers no scratch directory. An earlier revision of this line said "each of
the eighteen", which was false for that one file.)

Each of the eighteen carries one new row, `ISO1377`, asserting the invariant by
name so a future reader sees the suite declaring its independence rather than
inheriting it silently.

⚠ **THE TRAILING COMMENT ON THAT LINE IS COPY-PASTED AND OVER-READS IN THREE
SUITES.** It says `# issue 1377: the registry below is OURS, not ~/.xschem's`,
which is exactly right where the suite goes on to call `ase::sim_register` —
but `test_ase_window`, `test_wave_viewer` and `test_ase_plot` register nothing
at all (`grep -c sim_register` = 0 in each, measured 2026-09-07). For those
three the line's real subject is the *floor* they fall back to, not a registry
of their own. Cosmetic; recorded so the next reader does not go looking for a
registration that is not there.

`test_ase_core` carries a second row, `ISO1377b`, which builds a dirty
precondition itself and demands all three clears undo it — measured in the
repair round: neutering only the `ase::sim_caps_clear` line reds `ISO1377b` by
name and nothing else, so that line is fenced and the claim in `scratch.tcl` is
true.

## Why not the other three ways

* **Editing the goldens to match** would pin the suite to *this* developer's
  registry — the same defect facing the other way, and it would delete the
  folded-case coverage `F18`/`G3s` exist for.
* **Skipping when a registry is present** stops the suite measuring exactly when
  the user has the interesting configuration.
* **Moving `~/.xschem/ase_simulators` aside for the run** touches the user's live
  data and loses it on any abort. Forbidden outright by the batch's rule 3.

## Other suites in `tests/headless/` — the exposure survey

### ⚠ THE GREP SURVEY WAS TRIED, IT SHIPPED, AND IT WAS WRONG. Do not redo it.

The first round drew its candidate list by grepping every
`tests/headless/test_*.tcl` for a call that can consult the registry —
`ase::sim_status`, `sim_exe`, `sim_label`, `sim_casemode*`, `sim_nospiceinit`,
`sim_capabilities`, `sim_caps*`, `run_cmd`, `op_save_tier`, `ase::run`. It
returns 18 files, and on that basis this issue was written up as "six exposed,
fifteen isolated and verified".

**The grep missed eleven more suites, and several of them were RED ON THE
DEVELOPER'S OWN BOX at the moment the write-up called the survey complete.** The
worst of them is `test_ase_hier_pick_0161`, **7 FAILED**, whose row literals HP4,
HP5 and HP11 this issue's own text quotes as evidence — the file cited a suite it
had left broken. Also missed: `test_ase_bus_bits_0159` (3 FAILED),
`test_ase_locked_wire_pick_0160` (5), `test_ase_unnamed_net` (2),
`test_sod_pick_no_select_0204` (4), `test_ase_interact` (6),
`test_ase_plot` (3), `test_ase_log_seam_0207` (3),
`test_netlist_case_collision` (12), plus `test_ase_window` and
`test_wave_viewer`, which are green on this box and collapse under a registry
naming a program that WORKS.

**Why a source grep cannot answer this question**, three ways, all measured:

1. **The suite reaches the registry through procs the grep does not name.**
   `test_ase_hier_pick_0161` contains none of the grepped tokens. It gets there
   as `ase::ui::sod_case_mode` → `ase::sim_casemode_requested` →
   `ase::sim_status` — three hops, none of them spelled in the file.
2. **The C side reaches it too**, so a suite with no `ase::` line at all can
   still be steered by the entry in force.
3. **A suite the grep DOES find can be green for the wrong reason**, so the list
   it produces cannot be checked by running it under the obvious control.

### The only sound survey is EMPIRICAL, and the control is the hard part

Run **every** `tests/headless/test_*.tcl` three times — real `HOME`, an empty
`HOME`, and a HOSTILE `HOME` — and compare **name+status**, never counts.

**The hostile registry must name a program that EXISTS AND WORKS.** A registry
naming a MISSING program is a weak control and it is the trap the first round
fell into. `ase::sim_casemode_requested` opens with

```tcl
if {![dict get $s ok]} { return [ase::sim_casemode_floor] }
```

so a refused resolution hands the question straight back to the global floor and
every `fold` row passes — for the wrong reason, indistinguishably from a suite
that really is isolated. The registry used for this survey was

```tcl
ase::sim_register hostile-ver50 /home/analog/dev/ngspice/build-ver_50/src/ngspice \
  -args {} -backend {} -casemode distinguish -nospiceinit 0
ase::sim_select hostile-ver50
```

— a real working build; `-backend {}` so it answers for every backend; and a
case mode that is neither the global floor (`fold`) nor the developer's own
choice (`preserve`), so no row can agree with all three `HOME`s by accident.

**`empty` vs `hostile` is the clean discriminator.** The two scratch `HOME`s are
identical in every way except the presence of `.xschem/ase_simulators`, so a
difference between them is the registry and nothing else. `real` vs `empty`
conflates the registry with everything else in a person's home directory, and
this survey found three suites that differ there for reasons that are NOT this
issue (see "Not fixed here").

**Run each suite the way THAT suite requires.** Two exceptions, both measured,
both of which yield a WRONG verdict when ignored:

* **`test_ase_log_seam_0207` needs `--logdir <scratch>`, NOT `--nolog`** — row
  PS0 is literally *"action log open (needs --logdir)"*. Run with `--nolog` it
  reads **19 FAILED under every `HOME`** and looks like a registry-independent
  standing red. Both the adversary and the driver misclassified it that way.
  Never `--logdir /tmp`: the user's live action log is `/tmp/Xschem.log.*`
  (issue 1359).
* **`test_ase_optier_0963` needs `--nogui`**; its GUI arm hangs for ever
  (issue 1375).

### The sweep, and what it cost

**1,149 runs** — 383 suites × 3 `HOME`s — on `:99` with `GUI_GATE=0`, 2026-09-07
10:34→12:14. Verdicts were taken on NORMALISED name+status.

> ⚠ **THE NORMALISER'S REACH WAS OVERSTATED HERE AND THE SENTENCE IS
> CORRECTED.** This paragraph said "scratch-dir pids, rss figures, **X window
> ids, git hashes** and elapsed times stripped". Re-read in the close-out round
> against the script itself (`scratchpad/nrows.sh`, seven `sed` expressions):
> it strips the two `HOME` paths and `/home/analog`, a scratch-dir `_<name>_<≥4
> digits>` suffix, `<n> kB`, `rss <n>`, `<n>.<nn> ms`, `<n>.<nn> s` and
> `pid <n>`. It strips **neither X window ids nor git hashes** — nothing in it
> matches either. Measured: `test_close_window_force`'s `C1` reads
> `draw=6291732 winfo=0x00600114` under the empty `HOME` and
> `draw=4194580 winfo=0x00400114` under the hostile one, and both survive
> `nrows.sh` untouched.

**Convicted — eleven, all now isolated:**

| suite | real `HOME` | empty `HOME` | hostile `HOME` |
|---|---|---|---|
| `test_ase_hier_pick_0161`       | **7 FAILED** (14)  | ALL PASS (21)  | **7 FAILED** (14) |
| `test_netlist_case_collision`   | **12 FAILED** (28) | ALL PASS (40)  | **20 FAILED** (20) |
| `test_ase_interact`             | **6 FAILED** (57)  | ALL PASS (63)  | **13 FAILED** (50) |
| `test_ase_locked_wire_pick_0160`| **5 FAILED** (11)  | ALL PASS (16)  | **5 FAILED** (11) |
| `test_sod_pick_no_select_0204`  | **4 FAILED** (62)  | ALL PASS (66)  | **4 FAILED** (62) |
| `test_ase_bus_bits_0159`        | **3 FAILED** (36)  | ALL PASS (39)  | **3 FAILED** (36) |
| `test_ase_log_seam_0207`        | **3 FAILED** (45)  | ALL PASS (48)  | **3 FAILED** (45) |
| `test_ase_plot`                 | **3 FAILED** (147) | ALL PASS (150) | **31 FAILED** (78), 42 rows never run |
| `test_ase_unnamed_net`          | **2 FAILED** (26)  | ALL PASS (28)  | **2 FAILED** (26) |
| `test_ase_window`               | ALL PASS (228)     | **1 FAILED** (227) | **5 FAILED** (180), 44 rows never run |
| `test_wave_viewer`              | ALL PASS (401)     | ALL PASS (401) | **1 FAILED (6 passed)**, 395 rows never run |

Read the bottom two rows. **`test_wave_viewer` is green under BOTH `HOME`s
anybody would think to try** and dies after six checks under a registry that
works: the ASE-L preflight refuses the run (*"'-i(v1)' — current 'v1' is not in
the netlist"*) because the entry's `distinguish` reaches the deck, and 395 rows
never happen. Only the count says so, and a count is exactly what rule 7 forbids
reading.

**`test_ase_window` is the other shape, and it is worse.** It passed on this box
**only because** the developer had a fast local ngspice registered. Isolating it
turned W7 *"simulator produced output before Stop"* red under every `HOME` —
deterministically, 3/3. W7 waited 50 × 100 ms. MEASURED on the `/usr/bin/ngspice`
45.2 that an isolated suite actually runs, first output arrives at iterations
**97, 99, 101, 105, 106** over five runs — 9.7–10.6 s, twice the old bound every
time. So the isolation did not break W7; it revealed that **W7 had only ever
passed on one machine's simulator.** The bound is now 300 (30 s, 3× the measured
worst case) and the loop still breaks on the first byte.

**Isolated as a precaution, NOT convicted:** `test_ase_optier_0963`. The sweep
saw it read 1 FAILED (X7) under the hostile registry while reading ALL PASS (102)
under both other `HOME`s. **That did not reproduce**: the unisolated file was
re-run three more times under the same hostile registry and read ALL PASS (102)
every time. X7 is a flake. The isolate line stays — X7 drives a real ngspice and
reads vectors back by name, so a registered entry is in a position to steer it —
but nothing here is evidence that it ever did, and it is not counted among the
eleven.

**Isolated and verified byte-identical, name+status, under all three `HOME`s
(the 18 suites this issue now owns):** the six of the first round —
`test_ase_core` (184), `test_ase_persist` (137), `test_ase_final` (82),
`test_ase_preflight` (115), `test_ase_sod_case` (53), `test_ase_final_gf180` (35)
— plus the twelve of this one: `test_ase_hier_pick_0161` (22),
`test_ase_bus_bits_0159` (40), `test_ase_interact` (64),
`test_ase_locked_wire_pick_0160` (17), `test_ase_log_seam_0207` (49),
`test_ase_optier_0963` (103), `test_ase_plot` (151), `test_ase_unnamed_net` (29),
`test_ase_window` (229), `test_netlist_case_collision` (41),
`test_sod_pick_no_select_0204` (67), `test_wave_viewer` (402).

**The other 365 suites** showed no registry-driven change — but the sentence
that used to stand here overstated *how* that was established, so here is what
was actually measured.

> ⚠ **THIS SAID "after normalisation their name+status is identical between the
> empty and the hostile `HOME`". THAT IS FALSE FOR SIX OF THEM**, re-measured in
> the close-out round over the sweep's own 1,149 logs with the sweep's own
> `nrows.sh`. Six suites outside the eighteen have a normalised name+status that
> is **not** identical between the empty and the hostile `HOME`:
> `test_ase_cosim` (**1** row of 341, `BD22`), `test_close_window_force`
> (**3** of 7, `C1` `C3` `C6`), `test_nh_editor_preview` (**1** of 27, `G5`),
> `test_raw_read_dispatch` (**1** of 94, `ORD7-tilde`),
> `test_raw_read_failure_0306` (**1** of 63, `H3`),
> `test_zero_point_pos_at_0852` (**1** of 41, `R1h`).
>
> ⚠ **THESE SIX COUNTS READ 2, 6, 2, 2, 2, 2 UNTIL THE CLOSE-OUT ROUND — every
> one of them exactly DOUBLE.** The names were always right; the numbers were
> `diff` output lines transcribed as rows, and a changed row contributes two
> lines to a diff. "`test_close_window_force` (6 of 7)" therefore read as six
> of that suite's seven rows moving, when three did. Re-counted as distinct
> changed row NAMES over the sweep's own 1,149 logs with the sweep's own
> `nrows.sh`, which is why each entry now names the rows it is counting.
>
> **Every row of all six PASSes in all three arms** (`FAIL` count 0, measured
> per arm), and five of the six differ only in things `nrows.sh` does not
> strip — X window ids, a source `mtime`, an emergency-save temp name, a
> pid-bearing scratch filename. The sixth, `test_nh_editor_preview`'s `G5`,
> differs in the LENGTH of a rendered fill list (73 `green` entries under the
> empty `HOME`, 72 under the hostile one) and passes in both; **why that list
> is one shorter was not measured.** So the conclusion — no registry-driven
> row moved — stands, and the reader now has the six names to check it against
> rather than a blanket "identical".

**What the sweep did NOT measure, stated plainly.**

> ⚠ **THE PARTITION PRINTED HERE WAS WRONG — IT SAID 318 + 25 + 6, WHICH IS
> 349, NOT 383** — and the paragraph whose whole job is to be right about the
> survey's limits is the worst place for that. Re-counted in the close-out
> round from the sweep's own logs (`nrows.sh` row count and a `grep -c
> '^RESULT: '` per suite, empty arm). The true partition is **two** groups, not
> three:

Of the 383 suites, **318 emit per-row (`ok:`/`FAIL:`) lines** and got a full
row-level comparison across the three `HOME`s; the remaining **65 emit no
per-row lines at all** and were compared on their normalised raw output
instead — **65/65 byte-identical, empty vs hostile**, re-run in the close-out
round because no artifact of the sweep performed that comparison.

Two corrections inside that:

* **"25 print no `RESULT:` banner AND no per-row lines" was two facts fused.**
  25 suites print no banner (excluding the timeouts), but **14 of them do print
  rows** and are inside the 318; only **11** print neither. The other **54** of
  the 65 no-row suites *do* print a banner — so for those 54 the only
  per-suite signal the sweep's row comparison had was the banner text, i.e.
  a **count**, which rule 7 forbids reading. That is what the raw-output
  comparison above is for, and it is why it had to be re-run.
* **The 6 timeout suites are not a third bucket and do not "yield NO
  verdict".** `test_descend_symbol` (37 rows), `test_make_symbol_dialog` (2),
  `test_paste_modify_flag_0244` (272), `test_placement_preview_doors` (35),
  `test_raw_read_dispatch` (94) and `test_shape_draw_gate` (61) all emit rows
  before the 240 s kill, so they sit **inside** the 318 and were row-compared.
  Measured: **zero `FAIL` rows in any arm** for all six. What is genuinely
  unknown is only the part of each suite that never ran — they time out
  identically under every `HOME`, so nothing suggests the registry is involved
  and nothing rules it out for the unrun tail.

### The sweep is not free, and one of its side effects red a suite

Running the whole `tests/headless` directory from the repo root **dropped
`untitled~.sch` and `untitled~.sym` into the repo root** (12:13:42 and 12:13:59,
alongside `test_verb_noun_copy_move` and `test_wire_vertex_grab`). Both are
gitignored, so `git status` says nothing — and `test_ase_core`'s **C11**
(*"no untitled~.sch was dropped in the repo root"*) went red under all three
`HOME`s until they were removed. Two consequences worth recording:

* a whole-directory sweep must re-check the hygiene rows afterwards, or it will
  report a red it caused itself;
* the 2026-09-04 `untitled~.sym` that the section below calls evidence **had its
  mtime overwritten by this sweep**, so its provenance is gone. The two files
  were copied aside before removal rather than deleted outright.

## THE STANDING RED FOUND IN PASSING — now NAMED, and no longer standing

The first round recorded `test_op_dump_altshow` at **1 FAILED (64 passed)** under
all three `HOME`s, blamed a stray `/untitled~.sym` dated 2026-09-04 21:22, and
left the file in place on the grounds that *"until someone knows which run
dropped it the file is evidence"*.

**The repair round found out which runs drop it**, by removing the file and
running candidates one at a time from the repo root:

| suite | leaves behind |
|---|---|
| `test_verb_noun_copy_move` | `untitled~.sym` |
| `test_wire_vertex_grab`    | `untitled~.sch` |
| `test_untitled_reuse`      | `untitled~.sch` |

(`test_zero_point_pos_at_0852` and `test_untitled_name_dir_0323` were checked in
the same way and leave nothing.) Both names are gitignored — `.gitignore:75` and
`:76` — so `git status` never mentions them, which is why the pile survived from
September 4th to September 7th unnoticed.

Two suites read the repo root and go red when it is dirty:
`test_op_dump_altshow`'s **H1** and `test_ase_core`'s **C11**. Both are now
**ALL PASS** — `test_op_dump_altshow` 65, `test_ase_core` 184 — because the files
were removed (copied aside first). ⚠ **THIS IS A CLEANUP, NOT A FIX.** The three
suites above still litter, so the next whole-directory run reds H1 and C11 again.

The provenance the first round wanted to preserve is gone regardless: this
round's own 1,149-run sweep re-created both files at 12:13 on 2026-09-07 and
overwrote the 2026-09-04 mtime. No number is minted here — `NUMBERING.md` is
being edited by other lanes of this batch right now and a number minted without
committing that file is how collisions happen (0420–0432, +80). The driver
should file it with the table above.

## Not fixed here

* Suites still write `geometry` and `simulations/` into the real
  `$USER_CONF_DIR` when run under the developer's `HOME`. That is a separate
  exposure (the conf DIRECTORY, not the registry) and redirecting
  `::USER_CONF_DIR` wholesale moves `ase::rundir`'s default for every design,
  which several rows pin. Worth its own item.
* `ase::sim_load_conf` is still reachable with a default path
  (`$USER_CONF_DIR/ase_simulators`) from inside a suite. Nothing in these
  eighteen calls it, and `test_ase_simreg_0931` always passes an explicit path.
* **Three suites depend on `HOME` for reasons that are NOT the registry**, found
  by the same sweep and left alone because they are a different exposure:
  `test_results_select` loses SEL337/SEL338 (2 rows, both `~`-path rows) under a
  scratch `HOME`; `test_launch_context` and `test_multi_window` differ only in
  window geometry and window ids. Their empty-`HOME` and hostile-`HOME` readings
  are identical, which is what says the registry is not involved. The
  `test_results_select` pair belongs with the `$USER_CONF_DIR` item above.

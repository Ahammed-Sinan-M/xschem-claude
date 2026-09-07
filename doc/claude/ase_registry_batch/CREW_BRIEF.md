# ASE-L registry loose ends — crew brief

**Branch:** `fluid-editing` (the public branch the user shares). **Opened:** 2026-09-07.
**Driver:** the main session. **Nothing is pushed. Agents do not commit.**

## Where this came from

The user asked, verbatim: *"Things seem to work good - both with case and the
annotation and results display window. Is there some backlog you can work on in
batch mode?"* — and then chose this slice from four offered:

> **ASE-L registry loose ends** — 1238 (stock Simulation > Simulate lost its
> exe/casemode composer at the merge, so the menu most users press can run a
> different binary at fold than the one you registered), 1239, 1276 and 1286
> (write_conf reports success when the file went elsewhere), 0960 and 0961.
> Directly downstream of the case-mode work you just confirmed working.

One ruling was taken up front, on issue **1238**, which its own file says is
"not decidable from the code; it is a product call". The user chose
**option 1 — re-teach `simulate` to read the registry.**

## What the driver measured before the crew started (2026-09-07)

The tree was rebuilt first (`make -C src` — "Nothing to be done", the binary is
current at Sep 5 20:05 and only `.tcl` has moved since).

**A NEW DEFECT, FOUND WHILE TAKING THE BASELINE, AND IT IS NOW ITEM 1377.**
Fifteen ASE/sim suites were run on `:99` with `--nolog`. Four of them are red —
and every one of those four goes **ALL PASS** when the only thing that changes
is `HOME`:

| suite | real `HOME` | `HOME` = an empty scratch dir |
|---|---|---|
| `test_ase_persist`   | **5 FAILED** (131 passed) | ALL PASS (136) |
| `test_ase_core`      | **7 FAILED** (174 passed) | ALL PASS (181) |
| `test_ase_final`     | **3 FAILED** (78 passed)  | ALL PASS (81)  |
| `test_ase_preflight` | **2 FAILED** (112 passed) | ALL PASS (114) |

The other eleven are green either way: `test_ase_simreg_0931` 83,
`test_ase_simdlg_0937` 48, `test_ase_simcaps_0948` 84,
`test_sim_casemode_registry` 28, `test_sim_plain_run` 6,
`test_sim_probe` 44, `test_sim_run_profile` 37, `test_ase_launch` 44,
`test_ase_dialogs` 176, `test_op_param_store_1245` 135, and
`test_ase_optier_0963` 102 (`--nogui`; its GUI arm hangs for ever on issue
**1375**, which is filed and not this batch's).

**THE CAUSE, NAMED BY THE FAILING ROWS THEMSELVES:** the suites read the
developer's real `~/.xschem/ase_simulators`. The user registered
`ngspice-ver50 … -casemode preserve` yesterday, so:

* `test_ase_core` E1e expected `ngspice -b <deck>` and got
  `/home/analog/dev/ngspice/build-ver_50/src/ngspice -b -D casemode=preserve <deck>`;
* `test_ase_final` F18/F14 expected `i(@m.xm1.msky130_fd_pr__nfet_01v8[id])` and
  got `i(@M.XM1.Msky130_fd_pr__nfet_01v8[id])` — **the capitals are the
  case-mode feature working**, and the goldens are folded;
* `test_ase_preflight` PF215c: *"the mode comes from the run request (got
  'preserve' want 'distinguish')"*;
* `test_ase_core` C5b/C6/C8 lose their per-device save cards because the
  registered build measures the `altshow` capability and the tier moves.

So **using the feature reddens the suite that guards it**, on the branch the
user shares and immediately after a blog post that tells new readers to register
a simulator. It also masks any real regression this very batch might introduce,
in exactly the files this batch edits.

**A METHOD CORRECTION IN THE SAME MEASUREMENT, so no agent repeats it.** The
driver's first baseline passed `--logdir <scratch>` to every suite and got two
extra reds, `test_ase_core` NT17 and NT18. Those two rows assert an *"HONEST
(empty, `--nolog`) sink list"* — the flag changed the thing under test. **Launch
every suite with `--nolog`, never `--logdir`.** `--nolog` also leaves
`/tmp/Xschem.log.*` alone, which is the other half of why it is the right flag
(issue 1359: the user's live action log lives there).

## The items

| id | file | subject |
|---|---|---|
| **1377** | tests | the four suites above read the developer's registry — isolate them |
| **1239** | `src/ase.tcl` | `ase::expand_path` uses `subst`; point it at the hardened `sim_expand_vars` |
| **1286** | `src/ase.tcl` | `ase::sim_write_conf` has no directory guard and no symlink resolution |
| **0960** | `src/ase.tcl` | a probe folder that cannot be used switches capability warnings off for good, silently |
| **0961** | `src/ase.tcl` | `cap_run`'s relative-path carve-out is wrong for `./name`, and the comment says the opposite |
| **1276** | `src/op_param_lists.tcl` | the same two holes as 1286, in the writer 1286's was copied from |
| **1238** | `src/xschem.tcl` | re-teach stock `proc simulate` to read the registry (user ruling: option 1) |

**FOUR ITEMS SHARE `src/ase.tcl`** (1239, 1286, 0960, 0961). They run **in
series, in that order**, each re-reading the file first. The other three lanes
run concurrently with them because their files are disjoint.

**1276 IS SCOPED, AND THE SCOPE IS DELIBERATE.** Its fix was written once, in a
2,506-line diff that was reverted as one unit and is preserved at
`doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch`. That whole patch
belongs to the op_param batch and **must not be applied here**. Lift **only** the
`_resolve_target` / `_target_why` hunks for `write_conf`. If they will not come
out cleanly, stop and say so — do not reconstruct 2,506 lines and do not
freehand a replacement, because that patch's comment block carries four
measurements the guard ORDER depends on, including the one that **refutes issue
1276's own recommended one-liner** (`file normalize [file link $path]` resolves a
relative target against the **cwd**, not the link's directory).

## Standing rules — every agent, every time

1. **Never a bare `xschem`.** It resolves to `/usr/local/bin/xschem`, 3.4.6 from
   Jan 2025, which predates the `no_recent_files` gate and rewrites the user's
   `~/.xschem/recent_files` (issue 0924). Always `./src/xschem`.
2. **Always `--nolog`.** Never `--logdir /tmp`, never bare (see above).
3. **Never touch `~/.xschem/*`** — not to read-modify-write, not to "clean up",
   not to make a suite pass. The user's registry there is live data and item 1377
   exists precisely because suites reach into it.
4. **`DISPLAY=:99 GUI_GATE=0`**, or `--nogui` where the suite allows it. Never a
   bare run on the user's `$DISPLAY`.
5. **RED FIRST.** Write the acceptance row, run it, paste the RED output, then
   fix, then paste the GREEN. A row that was never red proves nothing.
6. **Prove every new row non-vacuous by sabotage**: break the fix, watch the new
   row go red *by name*, restore with `cp` and verify the md5.
7. **Acceptance is a name+status diff, never a count.** The per-suite numbers
   above are the baseline. A count that matches while a name moved is a fail.
8. **Do not commit, do not push, do not open a PR.** No `git checkout --`,
   `git restore`, `git stash` or `git clean` — there is uncommitted work in this
   tree and those commands eat it.
9. **Do not run `tests/run_regression.tcl`** — it must run solo and the driver
   runs it at the end (issue 0990).
10. C89 in `.c`, `_ALLOC_ID_` for allocations, and **`src/Makefile.in` edits
    oblige a `./configure`** (issue 0424). No new `.c` file is expected here.
11. **UI copy is terse and acronyms are UPPERCASE** (MOS, SPICE, PDK, ERC) — a
    standing user correction, not a style preference.
12. Anything the user must decide goes on the ledger:
    `tests/headless/owed.sh add rule <id> "<why>"`, and a pixel deliverable is a
    `look`, never "done".

# Crew C receipt — persistence, the boundary, and the lint that stops the eighth

Scope as briefed: `tests/headless/test_ase_persist.tcl`, plus the one new suite
the brief allowed. Nothing outside `tests/` was edited; `src/ase.tcl`,
`src/ase_window.tcl` and the four suites owned by crews A and B were read and
never written.

Nothing committed.

Files changed / added:

| file | what |
|---|---|
| `tests/headless/test_ase_persist.tcl` | **+ section R7** (C2), header + floor comment |
| `tests/headless/test_ase_simchoice_1395.tcl` | **NEW** — sections L (C1), B (C3), Q (C4) |
| `doc/claude/ase_simchoice_batch/LEDGER.md` | item 7, the floors table, the hazard paragraph |

---

## 0. The one thing to read first: `~/.xschem/ase_simulators` is untouched

md5 taken before the first edit, after every suite run, and last thing:

```
d66a9afd1a3bf1a32ae1112c3ea88558  /home/analog/.xschem/ase_simulators
-rw-r--r-- 1 analog analog 336 Sep  8 18:03 /home/analog/.xschem/ase_simulators
```

Unchanged throughout, size and mtime included. Every measurement below ran with
`::USER_CONF_DIR` redirected into a scratch directory **before** the first
`ase::sim_register`, and the new suite carries that as an asserted row of its own
(`Z`), not merely as a habit.

---

## 1. Where the lint row lives, and why not in `test_ase_persist.tcl`

**`test_ase_persist.tcl` is the wrong home and the row is not there.**

That file's subject is waveform-viewer persistence and the round-3 acceptance
gate — its name is about the *viewer* dict, not about the simulator registry. A
tree-wide scan of every `tests/headless/test_*.tcl` for test-hygiene has no
relation to anything else in it, and a reader who went looking for "what stops a
suite eating my simulator list" would never open it.

It lives instead in the **new** `tests/headless/test_ase_simchoice_1395.tcl`,
whose whole subject is the boundary the hazard comes from: registering is
environment and therefore *writes*, and that is precisely why a suite that
registers without isolating itself overwrites the user's environment file. The
row sits at the top of that file, under a comment that names the file at risk
and this box's single real entry (`ngspice-ver50`, a build the user made
themselves and cannot get back from any repository).

The suite is named for issue **1395** (already filed by crew D; NUMBERING.md is
at 1396 and was not touched). It needs **no display**, uses **no Tk**, and runs
identically on `full_audit.sh`'s default arm and under `--nogui`, so
`full_audit.sh` was **not** edited — it globs `test_*.tcl` and picks it up.

### The row itself — L1

```
ok:   L1 SOURCE-GREP no headless suite registers a simulator before isolating
      itself from the user's own ~/.xschem/ase_simulators
```

Rule: for every `tests/headless/test_*.tcl`, find the **first uncommented** line
calling a registry *writer* — `ase::sim_register` **or `ase::sim_unregister`**,
the two procs that call `ase::sim_touch` — and red unless one of these appears on
an uncommented line **above** it:

* `set ::USER_CONF_DIR …` (writer still runs, into scratch — for a suite whose
  subject *is* the saving),
* `set ::ase::sim_autosave 0` (the seam; writer does not run),
* `test_sim_registry_isolate` (scratch.tcl's shared helper, which clears the
  seam).

The failure text names **the file and the line**, and says what to add:

```
lintfix_bare.tcl:1 registers a simulator with no ::USER_CONF_DIR redirect, no
`set ::ase::sim_autosave 0` and no test_sim_registry_isolate above it -- it
would write the user's own ~/.xschem/ase_simulators
```

`ase::sim_unregister` is included because it is the *other* writer, and the
version of this hazard nobody has hit yet is worse: an unisolated
`ase::sim_unregister ngspice-ver50` would **delete** the user's only entry from
the file rather than merely adding stubs beside it.

### Non-vacuity, three ways

* **L1 element 2** — the glob matched **383** files (`>= 300` asserted). A glob
  that matched nothing also scans clean.
* **L2** — eight fixtures written as data. Beyond the three accepted spellings
  and the bare offender, it pins the two ways a suite can *look* isolated and not
  be, which are what a hurried author actually writes:

  | fixture | detector says |
  |---|---|
  | `ase::sim_register` alone | line 1 — caught |
  | `set ::USER_CONF_DIR` then register | 0 — accepted |
  | `catch {set ::ase::sim_autosave 0}` then register | 0 — accepted |
  | `test_sim_registry_isolate` then register | 0 — accepted |
  | register **then** `set ::USER_CONF_DIR` | line 1 — **caught** (order is the rule) |
  | isolation only in a **comment**, then register | line 2 — **caught** |
  | `ase::sim_unregister` alone | line 1 — caught |
  | a suite that never registers | 0 |

* **L3** — the helper branch is load-bearing, measured rather than assumed: the
  scan is re-run with the helper spelling removed from the accepted set, and the
  suites that flip from clean to offending are exactly the three the brief named
  (`test_ase_core`, `test_ase_optier_0963`, `test_ase_sod_case`). Asserted as
  "these three are among them, and there are at least three", **not** as an exact
  set, so a crew adding a fourth helper-only suite does not red an inventory it
  never read.
* **L4** — and the helper really does what accepting it assumes:
  `test_sim_registry_isolate` sets `::ase::sim_autosave` to 0 (measured, then the
  suite puts its own seam back to 1, because measuring the live writer is its
  subject).

### The adversarial check the row is really for (measurement, not a row)

Four **real** suites, one per isolation shape, copied to scratch with their
isolation line commented out. In-tree they are clean; stripped, the detector
fires at the exact line of the first registration:

```
  test_ase_core.tcl                in-tree 0      isolation stripped -> 118
  test_ase_simreg_0931.tcl         in-tree 0      isolation stripped -> 257
  test_sim_plain_run.tcl           in-tree 0      isolation stripped -> 149
  test_sim_run_profile.tcl         in-tree 0      isolation stripped -> 154
```

### The tree today, for the record

13 suites call a registry writer; all 13 are isolated. Route per suite
(`conf` = `::USER_CONF_DIR`, `seam` = `sim_autosave`, `helper` =
`test_sim_registry_isolate`), with the line of the first call:

```
  test_ase_core.tcl                  line 118   helper
  test_ase_optier_0963.tcl           line 220   helper
  test_ase_preflight.tcl             line 316   conf helper
  test_ase_result_case.tcl           line 297   conf
  test_ase_simcaps_0948.tcl          line 484   seam
  test_ase_simdlg_0937.tcl           line 480   conf
  test_ase_simreg_0931.tcl           line 257   conf
  test_ase_sod_case.tcl              line 370   helper
  test_op_dump_altshow.tcl           line 239   seam
  test_sim_casemode_registry.tcl     line 88    seam
  test_sim_plain_run.tcl             line 149   seam
  test_sim_probe.tcl                 line 633   conf
  test_sim_run_profile.tcl           line 154   conf
```

The fourteenth file `grep -l` finds is `scratch.tcl`, which only *writes about*
`ase::sim_register` in prose — the comment-stripping arm is what keeps that out,
and it is also what keeps the paragraphs of prose in the suites above from being
read as isolation. Non-`test_*.tcl` helpers in the directory were checked by hand
and none calls a writer.

---

## 2. C2 — round trip and byte identity for `sim_entry`

### 2a. The 104 committed `.state` files, measured independently

Own scan: files enumerated with `git ls-files '*.state'`, each read as bytes,
loaded through `ase::state_load`, re-saved through `ase::state_save` into the
scratchpad, compared byte for byte.

```
STATE FILES: 104
ERRORS: 0
NOT BYTE-IDENTICAL: 0
SIM_ENTRY MENTIONED IN ANY COMMITTED FILE: 0
GITSTATUS-STATE: ?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/tb_bandgap.state
```

No tracked `.state` file modified; the single `git status` entry is the
pre-existing untracked `debug_st1/` from before this session. Agrees with crew A
line for line.

### 2b. The five named byte-identity rows, by name and by suite

`src/ase.tcl:66` names F3/G3/R4/V4/R2. All five green, run individually today:

| row | suite | verdict |
|---|---|---|
| `F3 committed state file round-trips byte-identical` | `tests/headless/test_ase_final.tcl` | ok (ALL PASS, 82) |
| `G3 committed state file round-trips byte-identical` | `tests/headless/test_ase_final_gf180.tcl` | ok (ALL PASS, 35) |
| `R4 load->save byte-identical` | `tests/headless/test_ase_core.tcl` | ok (ALL PASS, 230) |
| `V4 load->save byte-identical to the seeded file` | `tests/headless/test_ase_view.tcl` | ok (ALL PASS, 36) |
| `R2 save->load->save byte-identical with a viewer dict` | `tests/headless/test_ase_persist.tcl` | ok (ALL PASS, 44 / 147) |

(`test_ase_core` and `test_ase_view` also carry rows *named* F3/G3 about other
subjects — expression verbatim, the newview combobox. The five above are the
byte-identity ones.)

### 2c. Section R7 of `test_ase_persist.tcl` — the new rows

Placed after R6 and before the T-E bookkeeping, so it runs on **both** arms.
Pure schema: no display, no ngspice, no registry, nothing written outside the
suite's own scratch dir. It sits in this file, and not beside the registry code
that reads the key, because **R2 is one of the five byte-identity rows and R3 is
the old-state-compat row** — the new key is governed by exactly those two rules,
so its rows go where the rules already live.

```
ok:   R7a sim_entry {} is omitted from the file entirely, and reads back as no choice
ok:   R7b sim_entry none round-trips as the deliberate PATH choice
ok:   R7c sim_entry {name <entry>} round-trips as that registry entry
ok:   R7c the three values produce three different files
ok:   R7d fixture: the pre-batch file carries NO sim_entry line
ok:   R7d it loads and decodes as `no choice of my own`
ok:   R7d re-saving does NOT give it the key, and is byte-identical
ok:   R7e a hand-written bare `sim_entry ngspice-ver50` is that entry
ok:   R7e ...while the bare word `none` is the PATH program, not an entry
ok:   R7e ...and an entry really called `none` is spelled {name none}
```

What each measures:

* **R7a/b/c** are one helper: save the state, read it back, save again; the row's
  value is `{the sim_entry line or {} if absent, the decoded choice, byte-identical}`.
  * `{}` → `{{} {unset {}} 1}` — **no line in the file at all**, which is
    `omit_if_empty` doing its job and is the shape all 104 committed files have.
  * `none` → `{{sim_entry none} {path {}} 1}` — issue 0932's deliberate PATH
    choice, which *is* written out. The asymmetry the encoding is built around.
  * entry → `{{sim_entry {name ngspice-ver50}} {entry ngspice-ver50} 1}`.
  * plus: the three files are three *different* files, so R7a is not passing
    because everything happens to serialize identically.
* **R7d** — the pre-batch file, built the way R3 builds its viewer-less one (key
  removed from the dict before serializing, so the file has never heard of it).
  Loads, decodes `unset`, and re-saves **byte-identically without gaining the
  key**. This is `src/ase.tcl:66`'s rule measured on the new key directly rather
  than inferred from the 104.
* **R7e** — the forgiving reader, on **hand-written** fixtures (the encoder never
  emits the bare form, so a round trip could not reach this): bare
  `sim_entry ngspice-ver50` → `{entry ngspice-ver50}`; the bare word `none` →
  `{path {}}`; `sim_entry {name none}` → `{entry none}`, an entry really called
  `none`, which is the whole reason the entry form has two words.

---

## 3. C3 — the environment/state boundary, eight measurements

All with `::USER_CONF_DIR` redirected into scratch. **The instrument is the
mtime**, not the size and not the content: a writer that rewrote byte-identical
content would still move the mtime, so "mtime unchanged" really does mean "not
written".

Raw capture (scratch paths elided to `…/scratch` for width; the full run is
reproducible with the script in the session scratchpad, and every claim is also a
row of `test_ase_simchoice_1395.tcl`):

```
=== 1. registering writes the conf file immediately, CIW-style ===
before: NO FILE
ase::sim_register ng-alpha -> 1
after 1st: exists=1 size=384
ase::sim_register ng-beta  -> 1
after 2nd: exists=1 size=572
FILE >>>
# xschem ASE-L simulator list -- written by xschem, issue 0931.
# Read once at startup. Edit by hand if you like: it is a plain
# Tcl script of ase::sim_register lines.
ase::sim_register ng-alpha …/scratch/c3/ng-alpha -args {} -backend {} -casemode {} -nospiceinit 0
ase::sim_register ng-beta  …/scratch/c3/ng-beta  -args {} -backend {} -casemode {} -nospiceinit 0
ase::sim_select ng-alpha
<<< END

=== 2. registering does NOT dirty an open session ===
dirty right after open   = 0
ase::sim_register ng-gamma -> 1
dirty after registering  = 0
entries now              = 3
dirty after unregister   = 0

=== 3. sim_load_conf does not change the file's mtime (origin gate) ===
ase::sim_load_conf -> 1
mtime before=1788934011 after=1788934011 UNCHANGED=1 size 572 -> 572

=== 4. sim_clear does not touch the file (teardown is not a choice) ===
ase::sim_clear ; entries in memory = 0
mtime before=1788934011 after=1788934011 UNCHANGED=1 file still there=1 size=572
reloaded from the file: entries=2 in force=ng-alpha default=entry ng-alpha

=== 5. changing the session's choice dirties, and the file does not move ===
dirty before = 0
dirty after  = 1
state sim_entry = {name ng-beta} decoded=entry ng-beta
conf mtime before=1788934011 after=1788934011 UNCHANGED=1 size 572 -> 572

=== 6. session_save clears dirty; the choice comes back on load ===
session_save -> 1
dirty after save = 0
STATE FILE LINE: sim_entry {name ng-beta}
reopened session choice = entry ng-beta
session_load on the first key -> 1
choice after session_load = entry ng-beta dirty=0

=== 7. the file names the DEFAULT while the session runs another entry ===
in force now  = entry ng-beta
sim_default   = entry ng-alpha
conf select line: ase::sim_select ng-alpha
conf mtime UNCHANGED since step 5 = 1

=== 8. a run resolves through the running session's choice ===
apply A       -> entry ng-alpha ; sim_status entry=ng-alpha source=registry exe=ng-alpha ok=1
apply B       -> entry ng-beta  ; sim_status entry=ng-beta  source=registry exe=ng-beta  ok=1
apply A-again -> entry ng-alpha ; sim_status entry=ng-alpha source=registry exe=ng-alpha ok=1
apply {}      -> entry ng-alpha ; sim_status entry=ng-alpha   (sim_default=entry ng-alpha)
apply none    -> path {}        ; sim_status entry={} source=path
```

Step 7 is the ruling in one screen: **the session is running `ng-beta` and the
machine's own file says `ng-alpha`**, because the choice never belonged there.

Two things worth naming beyond the eight asked for:

* **Step 8 goes back to A**, so the row cannot pass on a one-way latch, and it
  covers both fall-through arms — a state with no opinion runs the installation
  default, and `none` runs the program on the PATH with `source path` and an
  empty `entry`.
* **B5 has a second element the brief did not ask for and that the row needs**:
  the only difference between the session's state and its saved copy is
  `sim_entry` (`dict remove` on both sides compares equal). Without it, "the
  choice dirties" could be passing because something unrelated moved.

As rows, in `test_ase_simchoice_1395.tcl`:

```
ok:   B1 registering from the Command window reaches the disk at once -- no explicit save, no dialog
ok:   B1 ...and the file names both entries and the program each one points at
ok:   B2 an open session is clean before, during and after a registration -- registering is environment, not state
ok:   B3 reading the saved list does not rewrite it: sim_load_conf sources ase::sim_register lines and the origin gate stops each one writing back
ok:   B4 sim_clear forgets the registry without deleting it: memory empties, the file is not touched, and the next read brings every entry back
ok:   B5 changing the session's simulator makes it dirty, and moves nothing on disk
ok:   B5 ...and the choice is the ONLY difference between the session and its saved copy
ok:   B6 an explicit save clears the dirty mark, writes the choice into the state file, and a session opened fresh on that file has it
ok:   B7 the installation file names the DEFAULT while the session runs a different entry -- a choice gesture cannot leak into the environment
ok:   B8 the run resolves through the running session's choice: two states naming two entries answer their own entry, both times and back again
ok:   B8 ...a state with no choice of its own runs the installation default, and `none` runs the program on the PATH
```

---

## 4. C4 — the quit prompt, proved headless

`ase::ui::close_request` (`src/ase_window.tcl:440`) and
`ase::ui::prompt_all_on_quit` (`:456`) are gated on `ase::session_dirty` and on
nothing else. **The claim is measured, not read off the source** — a structural
grep of those two procs would say only that the word appears in them, and they
are being edited in this same batch.

No Tk, no widget, no display. Three procs are shimmed and *restored, with the
restoration asserted*: `ask_save_close` (posts the modal), `save_state_modal`
(posts Save-As) and `ase::ui::close` (tears a real window down).
`ase::ui::wins` is given fake toplevel paths, which is all either proc reads it
for. What is left under measurement is exactly the decision logic.

```
ok:   Q1 a clean session closes with no warning and no prompt
ok:   Q2 a session dirty ONLY because the simulator was changed gets the prompt, and Cancel leaves the window standing
ok:   Q2 ...and No closes it, discarding the change
ok:   Q3 Yes offers the save, and a save the user cancels leaves the window standing
ok:   Q3 ...and a save that completes closes it
ok:   Q4 saving the choice stops the prompt: the same session, the same choice, nothing asked
ok:   Q4 ...and so does putting the choice back: dirtiness follows the value, not the fact that it was touched
ok:   Q5 quitting with only clean sessions open proceeds, and asks nobody
ok:   Q6 a session dirty by the simulator choice is warned about on quit, and Cancel ABORTS the quit
ok:   Q6 ...and No lets the quit proceed, closing it
ok:   Q7 with nothing dirty left the sweep is silent again -- the clean session from Q5 is still open and is still not asked about
ok:   Q every shim restored, by name and by body
```

**Q4 is the row that answers the brief's actual question** — that
`session_dirty` is the *only* gate — and it does it in both directions on one
session, with the registry, the window and the choice all held constant:

* set the choice → dirty 1 → `session_save` → dirty 0 → `close_request` asks
  **nobody** and closes. The choice is still there; only its dirtiness changed.
* set the choice → dirty 1 → put it back to `unset` → dirty 0 → asks **nobody**.
  Dirtiness follows the *value*, not the fact that something was touched.

Q2's first element carries the same `dict remove` discriminator as B5, so "dirty
by the choice alone" is a measured claim and not a description of the setup.

**Nothing of crew B's reddened anything of mine.** These rows were run before and
after crew B landed 123 insertions in `src/ase_window.tcl`; `close_request` and
`prompt_all_on_quit` were not among their changes (`git diff` on those two
bodies: nothing), which is the design's own prediction — "once the choice is a
state key the prompt follows for free" — arriving as evidence.

---

## 5. Floors — raised, never lowered

| suite | before | after | why |
|---|---|---|---|
| `test_ase_persist` (headless arm) | **34** | **44** | section R7, 10 rows |
| `test_ase_persist` (display + ngspice) | **137** | **147** | the same 10 rows; R7 is not display-conditional |
| `test_ase_simchoice_1395` | — (new) | **31** | L 6, B 11, Q 12, Z 1, cleanup 1 |

`test_ase_persist` had **no floor comment**; one is added to its header
recording 44 / 147 and the 34 / 137 it came from, including crew A's one-line
`17 → 18` schema-key edit. The new suite's header carries its own.

Verified before/after on both arms:

```
 before (crew A's tree)          after
 ------------------------------  ------------------------------
 test_ase_persist --nogui   34   test_ase_persist --nogui    44   ALL PASS
 test_ase_persist  :99     137   test_ase_persist  :99      147   ALL PASS
                                 test_ase_simchoice_1395 --nogui  31  ALL PASS
                                 test_ase_simchoice_1395  :99     31  ALL PASS
```

Sibling suites run to confirm nothing moved: `test_ase_final` 82,
`test_ase_final_gf180` 35, `test_ase_core` 230, `test_ase_view` 36 — all ALL PASS.

`tests/run_regression.tcl` was **not** run: crews B and D are live in the same
tree and issue 0990 says a T1 number taken beside another crew's suite is not
evidence.

---

## 6. Contradictions with the brief or crew A's receipt

**None of substance.** Four notes, all minor and all corrections *upward*:

1. **"the fourteen suites that register".** `grep -l ase::sim_register
   tests/headless/*.tcl` finds 14 files, but the fourteenth is `scratch.tcl`,
   which only writes *about* the proc in prose — **13 suites call it**. This is
   exactly why the lint row strips comment lines before deciding: the tree's
   suites carry paragraphs naming both `ase::sim_register` and
   `test_sim_registry_isolate`, and a naive scan would be wrong in both
   directions. The count is written correctly in the suite's own comment.

2. **The brief scopes the lint to `ase::sim_register`; the row also covers
   `ase::sim_unregister`.** Both call `ase::sim_touch`, so both are writers, and
   the unregister flavour of this hazard is the worse one — it would *delete* the
   user's only entry rather than add stubs beside it. Nothing in the tree reds on
   the widening (measured: 0 offenders either way).

3. **`test_ase_view` has TWO counts and crew A's table records one of them.**
   32 under `--nogui`, **36** with a display — both ALL PASS, same file, same
   commit (`a250fba7`, untouched by this batch). Not a discrepancy, but the 32 in
   crew A's table is a `--nogui` number and must not be carried forward as *the*
   floor. Same shape as `test_ase_persist`'s 34 / 147, which is why the floor
   comment added to that file names both arms explicitly. (`test_ase_view` also
   does not register a simulator at all — `grep -c sim_register` is 0 — so the
   lint row never scans it for isolation.)

4. **Crew A's §6 note that it edited one line of `test_ase_persist.tcl`** (17 →
   18 schema keys) is correct, was left as it stands, and R1 with the new key is
   green. Recorded in the new floor comment so the next reader sees where 34 came
   from.

Nothing in crew A's landed API needed changing to measure any of the above:
`sim_choice_decode`/`encode`/`of`/`set`, `sim_default_choice`,
`sim_in_force_choice`, `sim_apply_choice`, `sim_touch`, `sim_autosave` all behave
exactly as the receipt describes.

---

## 7. One thing crew C is NOT claiming

The Q rows measure the two proc bodies' decision logic with the dialogs shimmed
out. **They do not measure that a real dialog appears, says the right words, or
that a human pressing Cancel reaches `ask_save_close`.** That is crew B's GUI
half and it is theirs to report. If a future reader wants "the user really sees a
warning", the Q rows are necessary and not sufficient — they are the half that
proves the *gate*, which is what the brief asked crew C for.

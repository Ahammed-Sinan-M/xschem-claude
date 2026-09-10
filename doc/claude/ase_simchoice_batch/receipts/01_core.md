# Crew A receipt — the core split (`src/ase.tcl`)

Scope as briefed: `src/ase.tcl`, rows in `tests/headless/test_ase_simreg_0931.tcl`
and `tests/headless/test_ase_core.tcl`. Three files outside that were touched for
one reason only and it is stated in full under **Out of scope, and why** below:
nothing was allowed to write the user's own `~/.xschem/ase_simulators`.

Nothing committed.

---

## 1. What changed in `src/ase.tcl`

### New public procs (the API crews B and C consume)

| proc | signature | answers |
|---|---|---|
| `ase::sim_choice_decode` | `{v}` | `{kind value}`, kind one of `unset` / `path` / `entry` |
| `ase::sim_choice_encode` | `{kind {name {}}}` | the stored form: `{}` / `none` / `{name <entry>}` |
| `ase::sim_default_choice` | `{}` | the installation default, decoded |
| `ase::sim_in_force_choice` | `{}` | what is in force right now, decoded (`path` for empty) |
| `ase::sim_choice_of` | `{state}` | that state's choice, decoded |
| `ase::sim_choice_set` | `{state kind {name {}}}` | a **new** state dict with `sim_entry` set |
| `ase::sim_apply_choice` | `{state}` | puts the state's choice in force; returns the decoded choice; never raises |
| `ase::sim_touch` | `{}` | persists the registry if the session layer is talking; 1/0 |

### New variables

* `ase::sim_default {}` — the installation default (ENVIRONMENT). Same three-value
  encoding as the state key. Set by `sim_select` from `conf`/`rc`, and by the
  first registration of all.
* `ase::sim_autosave 1` — a **test seam**, and the only one. Nothing in the
  product ever clears it. See §5.

### Changed

* `schema_keys` gains `sim_entry`, immediately after `simulator`; `omit_if_empty`
  gains `sim_entry`; `state_default` gains `sim_entry {}`. All three carry the
  byte-identity rule in the established voice, with the three-value table.
* `ase::sim_select` reads `ase::sim_origin`. `session` → `sim_use` only, and the
  comment now says WHY it writes nothing (the ruling). `conf`/`rc` → also
  `sim_default`, with `ase::sim_select {}` recorded as `none`, not as "no opinion",
  so issue 0932's deliberate-PATH choice survives.
* `ase::sim_register` — seeds `sim_default` on the first registration (never
  steals it later, never touches session state), and calls `ase::sim_touch` last.
* `ase::sim_unregister` — the removed entry is checked against the default as well
  as against what is in force; the default follows the same two arms (empty, or the
  sole survivor) and mints no new sentence. Calls `ase::sim_touch` last.
* `ase::sim_clear` — deliberately does NOT call it; the rule is written into its
  comment (*a mutation that expresses a user's choice persists; a teardown does
  not*). It also clears `sim_default` — memory only; the file keeps every entry.
* `ase::sim_write_body` — writes `sim_default` through the decoder, and can no
  longer see `sim_use` at all (`variable sim_use` removed from it). The 0932
  paragraph is extended, not replaced.
* `ase::run_deck` — one line, `ase::sim_apply_choice $state`, below the in-flight
  refusal and above `run_precheck` / `op_tier_arm` / `cap_report` / `$run_cmd` /
  `run_using_report`.

### Two things found while building it, both fixed here

* **`sim_write_conf` already says its own failure** (`nowrite`, `conf_isdir`,
  `conf_linkloop`, and it returns 0 rather than raising). `sim_touch` therefore
  adds a sentence **only** on the unexpected-raise path. Row **S8** pins the count
  at exactly one.
* **A session with no `::USER_CONF_DIR` at all** said, on *every* registration,
  `"Your simulator list could not be saved to , so the simulators you added will
  be gone when xschem closes"` — a sentence with a hole in it, about a save nobody
  asked for. `sim_touch` now returns 0 silently when there is no conf path, the
  same rule `sim_load_conf` follows for a first run (row E11). Row **S8b**.

---

## 2. Where `ase::sim_apply_choice` went, and why not in `ase::run`

`ase::run_deck` **is** reachable without `ase::run`: `ase::run_existing` (ADE-L's
"Run", which never re-netlists) and any script or CIW paste come straight to it.
It is the one body all three doors share, so the call sits there, once.
`ase::run`'s own netlisting step resolves no simulator (`ase::netlist` →
`netlist_in_place` → `xschem netlist` + `op_cards_capture`; the op-tier probe that
does ask `sim_status` runs inside `run_deck`), so a second call would buy nothing
and would say the stale-entry sentence twice for one gesture. Row **S12** pins the
position structurally, row **S12b** pins the wiring behaviourally.

---

## 3. Floors — raised, never lowered

| suite | before | after | why |
|---|---|---|---|
| `test_ase_simreg_0931` | **95** | **111** | section S (S1-S13) + R8b; E2 and R8 rewritten in place |
| `test_ase_core` | **224** | **230** | section C4, the `sim_entry` key; R1 17 → 18 keys |
| `test_ase_persist` | 34 | 34 | one word: "17 schema keys" → 18 (see §6) |

`test_ase_core`'s floor comment (`:56`, `:61`, `:70`) is updated to 230 and records
what added the rows. `test_ase_simreg_0931` had **no** floor comment; one is added
at `:82` recording 111 and the 95 it came from.

---

## 4. Measurements, verbatim

### 4a. The four the brief asked for

`::USER_CONF_DIR` redirected into the scratchpad for every one of them. The user's
own `~/.xschem/ase_simulators` was md5'd before the first edit and after every
suite run: **`d66a9afd1a3bf1a32ae1112c3ea88558`, unchanged throughout**.

```
--- (a) two ase::sim_register calls, USER_CONF_DIR redirected ---
before: NO FILE
reg a = 1
reg b = 1
after : exists mtime=1788933103 size=552
FILE CONTENT >>>
# xschem ASE-L simulator list -- written by xschem, issue 0931.
# Read once at startup. Edit by hand if you like: it is a plain
# Tcl script of ase::sim_register lines.
ase::sim_register ng-a /tmp/.../scratchpad/measure/ng-a -args {} -backend {} -casemode {} -nospiceinit 0
ase::sim_register ng-b /tmp/.../scratchpad/measure/ng-b -args {} -backend {} -casemode {} -nospiceinit 0
ase::sim_select ng-a
<<< END
names both present: a=1 b=1

--- (b) ase::sim_load_conf on that file does NOT change its mtime ---
load_conf = 1
mtime before=1788933103 after=1788933103 UNCHANGED=1  size 552 -> 552

--- (c) ase::sim_clear does not touch it ---
clear = 1
mtime before=1788933103 after=1788933103 UNCHANGED=1 file still there=1 size=552

--- (d) a session-origin ase::sim_select does not touch it ---
sim_origin = session
select = ng-b
mtime before=1788933106 after=1788933106 UNCHANGED=1
in force now = ng-b ; sim_default = {name ng-a}
FILE STILL NAMES THE DEFAULT, NOT THE CHOICE >>>
# xschem ASE-L simulator list -- written by xschem, issue 0931.
# Read once at startup. Edit by hand if you like: it is a plain
# Tcl script of ase::sim_register lines.
ase::sim_register ng-a /tmp/.../scratchpad/measure/ng-a -args {} -backend {} -casemode {} -nospiceinit 0
ase::sim_register ng-b /tmp/.../scratchpad/measure/ng-b -args {} -backend {} -casemode {} -nospiceinit 0
ase::sim_select ng-a
<<< END
```

The last block is the ruling in one screen: the session is running `ng-b`, and the
machine's own file says `ng-a`, because the choice never belonged there.
(Long scratch paths elided to `/tmp/.../scratchpad` for width; the raw capture is
in the session scratchpad as `measure_final.txt`.)

### 4b. Byte-identity: the 104 committed `.state` files

Every file from `git ls-files '*.state'`, loaded through `ase::state_load` and
re-saved through `ase::state_save`, compared byte for byte:

```
STATE FILES: 104
ERRORS: 0
NOT BYTE-IDENTICAL: 0
SIM_ENTRY MENTIONED IN ANY COMMITTED FILE: 0
```

`git status --porcelain -- '*.state'` lists **no tracked file modified** (the one
entry is the pre-existing untracked `tb_bandgap/debug_st1/`).

### 4c. The five named byte-identity rows, by name and by suite

| row | suite | verdict |
|---|---|---|
| `F3 committed state file round-trips byte-identical` | `test_ase_final` | ok |
| `G3 committed state file round-trips byte-identical` | `test_ase_final_gf180` | ok |
| `R4 load->save byte-identical` | `test_ase_core` | ok |
| `V4 load->save byte-identical to the seeded file` | `test_ase_view` | ok |
| `R2 save->load->save byte-identical with a viewer dict` | `test_ase_persist` | ok |

### 4d. Every suite that registers a simulator, after the change

```
test_ase_simreg_0931           RESULT: ALL PASS (111 checks)
test_ase_core                  RESULT: ALL PASS (230 checks)
test_ase_persist               RESULT: ALL PASS (34 checks)
test_ase_final                 RESULT: ALL PASS (82 checks)
test_ase_final_gf180           RESULT: ALL PASS (35 checks)
test_ase_view                  RESULT: ALL PASS (32 checks)
test_ase_simcaps_0948          RESULT: ALL PASS (110 checks)
test_ase_optier_0963           RESULT: ALL PASS (103 checks)
test_op_dump_altshow           RESULT: ALL PASS (70 checks)
test_sim_casemode_registry     RESULT: ALL PASS (43 checks)
test_sim_plain_run             RESULT: ALL PASS (54 checks, 0 skipped)
test_ase_sod_case              RESULT: ALL PASS (53 checks)
test_ase_preflight             RESULT: ALL PASS (115 checks)
test_ase_result_case           RESULT: ALL PASS (28 checks)
test_sim_run_profile           RESULT: ALL PASS (37 checks)
test_sim_probe                 RESULT: ALL PASS (44 checks)
```

Plus a wider ASE sweep, all ALL PASS: `test_ase_cosim` (341), `test_ase_dialogs`
(21), `test_raw_case_mode` (277), `test_annot_stale_0684` (56),
`test_results_freshness` (21), `test_op_param_store_1245` (165).

`run_regression.tcl` was **not** run: crews B, C and D were live in the same tree
and issue 0990 says a T1 number taken beside another suite is not evidence.

---

## 5. Out of scope, and why — the hazard this change creates

**Making registration persist makes `ase::sim_register` a WRITER of
`~/.xschem/ase_simulators`.** Eleven headless suites register stub simulators
(`/bin/sh`, two-line shell scripts, deliberately broken files). Seven of them
redirected nothing. On the day this landed, every one of those runs would have
replaced the user's real list — which today holds exactly one entry,
`ngspice-ver50`, pointing at their own build — with test stubs. That is
landmine 3 firing from inside the fix.

Three files outside the briefed scope were changed to stop it, and nothing else:

* `tests/headless/scratch.tcl` — `test_sim_registry_isolate` now also clears
  `::ase::sim_autosave`. That helper's own header already promises "NOTHING HERE
  TOUCHES A FILE, AND THAT IS THE POINT"; this is what keeps the promise true now
  that registering writes. Covers `test_ase_core`, `test_ase_sod_case`,
  `test_ase_optier_0963`, `test_ase_preflight`.
* `test_ase_simcaps_0948`, `test_op_dump_altshow`, `test_sim_casemode_registry`,
  `test_sim_plain_run` — one line each, `catch {set ::ase::sim_autosave 0}`, with
  the reason above it. These four call neither the isolate helper nor a
  `USER_CONF_DIR` redirect.
* `test_ase_simreg_0931` (in scope) — `::USER_CONF_DIR` redirected into its own
  scratch. It registers 85 times and is the suite whose SUBJECT is the saving, so
  it keeps the real writer under test rather than opting out.

Already safe, verified by reading the order of their lines: `test_ase_result_case`,
`test_ase_preflight`, `test_sim_run_profile`, `test_sim_probe`,
`test_ase_simdlg_0937` all set `::USER_CONF_DIR` before their first registration.

**A second contamination, caused by the same change and fixed in
`test_ase_simreg_0931`:** `$A_CLEANHOME` is a single directory shared by nine
children. E3's child registers a simulator, which now leaves a real saved list in
that HOME, and every rc-layer row after it inherited a session entry it never asked
for. Measured before the fix: E8 saw 2 entries and read `origin conf` for an entry
an rc had declared; E9's "empty list" was `sess-two`; E13 had one entry left after
removing the only one it knew about; E10 and E12 likewise — **five rows red for one
cause**. `a_cleanhome` now empties it per child.

---

## 6. Rows that had to change meaning, and one file that is another crew's

Two rows asserted the exact behaviour the ruling reverses. Both were rewritten in
place, with the old contract and the reason for the move written above them.

* **E2** used to demand "the same list AND the same choice" back from a saved file.
  It now demands the list field for field, and asserts that what comes back in force
  is the **installation default** — plus, positively, that the file contains
  `ase::sim_select ng-one` and **not** `ase::sim_select ng-two`, the session's pick.
* **R8** (issue 0932) used to make the "none of mine" gesture *in the session* and
  restart. That gesture is now state. R8 keeps 0932's actual guarantee and measures
  it where it still lives: a saved list whose selection line says `ase::sim_select
  {}` comes back with nothing of the user's in force and **not** with the first
  entry silently promoted. **R8b** is new and measures the ruling itself through two
  real starts: register two, pick the second, save nothing → the next start has
  **both** simulators and is running the **first**.

**`tests/headless/test_ase_persist.tcl` is crew C's file and I edited one line in
it**: `"R1 exactly the 17 schema keys"` → 18, with `sim_entry` in the list. It is a
mechanical consequence of the schema key with no design content, and leaving a
standing red is the thing CLAUDE.md is most explicit about. Crew C should know it
moved.

---

## 7. What crew B must fix, measured

`tests/headless/test_ase_simdlg_0937.tcl`, run on the dev display:

```
FAIL: S10b choosing "use the program on my PATH" in the dialog is written down
too, so the next start does not quietly put one of yours back in charge
  -> {{} 0} (exp {{} 1}) : FAIL
RESULT: 1 FAILED (47 passed)
```

That row asserts the pre-ruling contract — the dialog's choice reaching disk — and
is exactly ledger item 6 ("the in-force combobox stops writing to disk; it sets the
state key"). It is crew B's to rewrite; the API it needs is `ase::sim_choice_set` /
`ase::sim_choice_of`, so no encoding is ever spelled by hand in the window file.

---

## 8. Contradictions with the brief, and one gap in the design

1. **The brief says `ase::sim_touch` should report a failure "through
   `ase::sim_say` so the CIW door gets a sentence", and adds "check whether
   `sim_write_conf` already says its own failure".** It does — three kinds, and it
   returns 0 rather than raising. So `sim_touch` says nothing on the ordinary
   failure path and the CIW still gets exactly one sentence, from the writer. Row S8
   measures the count, not the source.

2. **NOTHING IN A SESSION CAN CHANGE `ase::sim_default`.** This follows from the
   design as briefed (A3 sets it only from `conf`/`rc`; A4 seeds it only on the
   first registration) and it is worth stating out loud, because it has a
   user-visible consequence: after the first simulator is ever registered, the
   installation default is pinned to it, and a user who wants their PATH program
   back **as the default** — issue 0932's own gesture, made from the Command window
   with no ASE-L session open — has no way to say so except by hand-editing
   `~/.xschem/ase_simulators`. Within a session it is fine: the choice is state, it
   dirties, it saves, it prompts. Outside one there is now no gesture at all. This
   is not a defect in what was built; it is a hole in the feature set, and it wants
   either a "make this the default" gesture in the Simulators dialog (crew B) or a
   ruling that the installation default is only ever set by the file. **Recorded
   here rather than decided.**

3. **The known limitation the brief asked to record** (two ASE-L windows share one
   `ase::sim_use`) is now bounded rather than open: `ase::sim_apply_choice` at the
   run means the window you pressed Run in wins the thing that actually executes.
   A bar or dialog in the other window may still name the other choice until it
   refreshes. Written into `ase::sim_apply_choice`'s header, pointing at
   `DECISIONS.md` D5.

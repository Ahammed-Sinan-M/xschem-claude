# 1371 — a measured case-mode capability has no GUI door

**Status:** FIXED, then REFUTED by an adversary, then REPAIRED — all in the
working tree (branch `fluid-editing`, uncommitted at the time of writing). The
repair is the section **"What the adversary found, and what was done about
it"** near the bottom; everything above it describes the door as it now stands.
Two rulings are owed to the user.

**Area:** ASE-L simulator registry (`src/ase.tcl`), the Simulators window
(`src/ase_window.tcl`), the stock `sim()` editor's Help text (`src/xschem.tcl`).

---

## The user's words, verbatim

> If the run *is* using ver_50, then why is case-mode support not showing up?
> What needs to be done for that? I plot the VBG net from top level of
> sky130_tests_ase/tb_bandgap and it plots v(vbg) not v(VBG). What's going on?
> I thought we nailed this weeks ago.

---

## The answer, in plain words

What was nailed weeks ago was the **reading** side — the raw-file case reader,
the netlister, and the probe that measures what your build delivers. Your
ver_50 **is** being used and it **was** measured: it delivers `fold`,
`preserve` and `distinguish`. What was never wired is the **asking** side's
GUI. Your registered entry says `-casemode {}`, which means "no request of my
own", so ASE-L falls back to the global default `fold`, and for a `fold`
request it deliberately sends no `-D casemode=` at all. So ngspice runs in its
own default, which is fold, and writes `v(vbg)`.

**TODAY, two ways, both measured working:**

(a) Edit `~/.xschem/ase_simulators` and change `-casemode {}` to
`-casemode preserve` on the `ngspice-ver50` line, then restart xschem; or

(b) type two lines in the ASE-L command window, no restart:

    ase::sim_register ngspice-ver50 /home/analog/dev/ngspice/build-ver_50/src/ngspice -casemode preserve
    ase::sim_write_conf

Either way the run becomes
`ngspice -b -D casemode=preserve <deck>` and VBG comes back as `v(VBG)`.

**WARNING, for the tree as it stood before this item:** after doing that, do
**not** press `Edit…` in Setup > Simulators…. Opening the row editor and
pressing OK without typing anything erased `-casemode preserve` back to `{}`
and saved the erasure (measured, evidence [4] below). That is fixed here.

**AFTER THIS CHANGE**, on a fresh xschem, six clicks — and the fourth one is
the one the first version of this paragraph forgot:

    Setup > Simulators…  →  click the ngspice-ver50 row  →  Edit…
      →  DETECT          (459 ms on your build; the editor tells you to press
                          it — "…/ngspice has not been tried yet, so fold is
                          all that can be offered; press Detect to try it.")
      →  the Case: chooser now offers  fold  preserve  distinguish
      →  pick preserve   →  OK

Saved, survives a restart, and `Edit…` stops erasing anything. Measured end to
end on your own `build-ver_50` on 2026-09-06 — see evidence [11].

**WHY DETECT IS NOT OPTIONAL, AND WHY IT LOOKS LIKE A REGRESSION IF NOBODY SAYS
SO.** The chooser may only offer what your build was MEASURED to deliver (rule
A1), measuring means running your simulator, and opening a dialog must not be a
gesture that starts it. So on a cold session the chooser honestly shows `fold`
alone. The first version of this file told you to open `Edit…` and pick
`preserve`, which on a cold session finds no `preserve` at all — the exact
confusion this item exists to end. The editor now says what it knows and names
the button that changes it, and after any run in the session the chooser is
already full.

**AND AFTER YOU PRESS OK, THE SAME SENTENCE COMES BACK.** Saving an entry means
"something about my simulators changed, look again", so the measurement is
deliberately forgotten (issue 0950; row D10 of `test_ase_simcaps_0948` pins it).
Reopening `Edit…` therefore shows `preserve (not tried yet)` and the press-Detect
sentence. **Your setting is intact** — the saved line still says
`-casemode preserve` and the run still carries `-D casemode=preserve`; the
label is about the program, not about your choice. One Detect (353 ms measured)
puts it back to a plain `preserve`.

---

## Root cause

The case-mode capability is measured, published, persisted and honoured end to
end — **every link works except the one that lets a person ask for it.**

* `ase::sim_casemode_requested` reads the registry entry's `casemode` field.
  The user's entry carries `casemode {}`, so the request falls to the global
  floor `$::sim_case_mode` = `fold` (`src/xschem.tcl`, `set_ne`, rc-only).
* `ase::run_casemode_flag` deliberately emits **no** `-D casemode=` for a
  `fold` request (a released ngspice folds anyway, and appending the flag
  forever would move every committed command golden for nothing).
* `ase::ui::simdlg_editor` built exactly two `dialog_row` calls, `Name:` and
  `Program:`. Nothing in the tree could set that field from a GUI.

`fluid-editing`'s casemode item 13 **did** have the door — a second line per
simulator row: Exe / Args / Case / -n / Test. It was deleted at the annotate
merge (tombstone at `src/xschem.tcl`, `simconf`) on the promise that "those
fields are properties of the ASE-L simulator registry entry now, and ASE-L's
Setup > Simulators… is their one door". **The store moved; the door was never
built.** The stale Help text in the same file still documented the removed
Case / -n / Test controls, so the only surviving user-facing documentation of
the case mode pointed at a dialog that did not have it.

And the omission was not merely passive: `ase::ui::simdlg_ok` rebuilt the entry
from the two visible fields plus `args` and `backend` only, so **opening Edit…
on an entry that HAS a case mode and pressing OK without touching anything
erased `casemode` and `nospiceinit` and saved the erasure.** Its own comment
claimed "EVERYTHING THE DIALOG DOES NOT SHOW IS CARRIED THROUGH", and row S9 of
`test_ase_simdlg_0937.tcl` asserted that claim for `args` and `backend` only —
so the suite was green over the hole. A comment naming a fence that does not
fence is this tree's own documented defect, and this is a clean instance of it.

---

## What was measured

All runs: `./src/xschem` with `--logdir` into a private scratch directory;
GUI runs via `tests/headless/devdisplay.sh exec` on Xvfb `:99` / openbox 3.6.1
/ 1920x1080x24. Every writer redirected through `::USER_CONF_DIR` /
`::netlist_dir` into scratch. `~/.xschem/ase_simulators` md5
`17a24a6f06765158b8e4f2850993055e` before, during and after — unchanged.

**[1] The chain, on the user's live entry** (`--nogui`, their own HOME):

    entry              : name ngspice-ver50 path .../build-ver_50/src/ngspice
                         args {} backend {} origin conf varok 1
                         casemode {} nospiceinit 0 ok 1
    sim_case_mode      : fold
    casemode_detected  : fold preserve distinguish
    casemode_selectable: fold preserve distinguish
    casemode_requested : fold
    run flag           : {}
    dialog_row calls in simdlg_editor:
        set en [ase::ui::dialog_row $w 0 {Name:} name]
        set ep [ase::ui::dialog_row $w 1 {Program:} path]

**[2] The command that is actually built** (`ngspice::run_cmd`):

    as registered today (casemode {}):
      .../build-ver_50/src/ngspice -b /tmp/deck.sp 2>@1
    with -casemode preserve on the same entry:
      .../build-ver_50/src/ngspice -b -D casemode=preserve /tmp/deck.sp 2>@1

**[3] That flag is the whole difference**, measured against the user's own
binary (deck names the node `VBG`, `-b`, ascii raw):

    === default (no -D) ===        === -D casemode=preserve ===
      0  v(vbg)    voltage           0  v(VBG)    voltage
      1  v(netone) voltage           1  v(NetOne) voltage
      2  i(vdd)    current           2  i(vdd)    current

**[4] The Edit… drop, through the real widgets on `:99`** (open Edit…, press
OK, change nothing):

    row editor widgets: .browse .btns .lname .lpath .name .path .status
    BEFORE: ... casemode preserve nospiceinit 1 ok 1
    AFTER : ... casemode {}       nospiceinit 0 ok 1
    SAVED : ase::sim_register mine .../ngstub -args -q -backend ngspice \
              -casemode {} -nospiceinit 0

The erasure was written to the saved list, so it survived the restart too.

**[5] Persistence already worked** — nothing to build there. Process 1 wrote,
process 2 (fresh) read back `casemode preserve`, `requested preserve`,
`run flag {-D casemode=preserve}`.

**[6] The accessor is keyed on the IN-FORCE entry, not the edited row.** Two
entries registered, real ver_50 and a stub; only the *selection* changed
between the two reads:

    in force : real50   ->  selectable(ngspice) : fold preserve distinguish
    in force : plain    ->  selectable(ngspice) : fold

So a door that called `ase::sim_casemode_selectable` while editing a row that
is not in force would offer **the wrong program's modes** — an A1 breach the
door itself would introduce. This is why the fix adds entry- and path-keyed
accessors rather than reusing the in-force one.

**[7] "Unprobed or refused offers `fold` alone" already held:** a stub whose
probe completes but publishes no casemode key answers `fold`; a program whose
file has gone is refused by the resolver and answers `fold`.

**[8] The cost of asking, and it is what shapes the design:**

    cold  sim_casemode_selectable -> {fold preserve distinguish}    447 ms
    warm  sim_casemode_selectable -> {fold preserve distinguish}      0 ms
    after sim_caps_clear          -> {fold preserve distinguish}    343 ms
    a program that does not answer -> {fold}                      31168 ms

(`ase::cap_budget_ms` is 30000.) Re-measured 2026-09-06 against the user's own
`build-ver_50` through the new accessor: **459 ms cold, 0 ms warm.** A chooser
built by calling that proc on dialog-open can therefore freeze Tk for 30 s.

**[9] An invalid mode is refused at the writer, not downgraded**, so the
chooser inherits a validator:

    ase: 'sideways' is not a case mode for simulator 'ngspice-ver50'
    (known: fold preserve distinguish, or empty for the global default)

**[10] Confirmed end to end on the user's real binary after the change**
(scratch conf, `--nogui`): pick `preserve` → entry `casemode preserve` →
`requested preserve` → saved line `-casemode preserve` → fresh process reads it
back → `ngspice -b -D casemode=preserve <deck> 2>@1`.

**[11] AFTER THE REPAIR, the whole gesture through the real widgets on the
user's own `build-ver_50`** (2026-09-06, Xvfb `:99` / openbox, scratch
`::USER_CONF_DIR`, `~/.xschem/ase_simulators` md5 unchanged at
`17a24a6f06765158b8e4f2850993055e`, `/tmp/Xschem.log.8` untouched):

    caps in hand, cold        : 0
    Edit… opens               : 23 ms
      chooser                 : {global default (fold)} fold
      status line             : "…/build-ver_50/src/ngspice has not been tried
                                 yet, so fold is all that can be offered;
                                 press Detect to try it."
      caps in hand after open : 0        (opening started nothing)
    Detect                    : 459 ms
      chooser                 : {global default (fold)} fold preserve distinguish
      status line             : "…/ngspice can hand net names back these ways:
                                 fold, preserve, distinguish."
    pick preserve, OK
      entry casemode          : preserve
      sim_casemode_requested  : preserve
      run_casemode_flag       : -D casemode=preserve
      saved line              : ase::sim_register ngspice-ver50 …/ngspice
                                -args {} -backend {} -casemode preserve
                                -nospiceinit 0
    reopen Edit…              : chooser {global default (fold)} fold
                                        {preserve (not tried yet)}
      status line             : the press-Detect sentence again (the look-again
                                rule; the SETTING is untouched)
    Detect again              : 353 ms → chooser shows a plain `preserve`
    ngspice::run_cmd          : …/build-ver_50/src/ngspice -b
                                -D casemode=preserve /tmp/deck.sp 2>@1

---

## What changed

### `src/ase.tcl` — the model half

The dialog re-implements nothing; that is `ase_window.tcl`'s own standing rule.

* **`ase::sim_entry {name}`** — one registered entry by name, or `{}`. Replaces
  two hand-rolled `foreach e [ase::sim_list]` walks that had grown inside the
  window file.
* **`ase::sim_capabilities` split.** The cache read/stamp/probe/"only a
  `known 1` answer is remembered" body moved unchanged into
  **`ase::sim_capabilities_at {backend resolved eargs}`**. Guards 2 and 3 (empty
  resolved — issue 0935; backend declares no probe) moved *with* the body,
  because they are preconditions of measuring anything; guard 1 ("the resolver
  refused") stays in the in-force wrapper, which is the only place it means
  something. Issues 0935 / 0949 / 0950 / 0951 all still hold and
  `test_ase_simcaps_0948` is green on both arms.
* **`ase::sim_capabilities_path {backend path {eargs {}}}`** — the same
  measurement about a named program, guarded by `ase::sim_check`'s own four
  filesystem facts and `ase::expand_path`. Never raises. The 0935 hazard cannot
  arise on this route: the path always comes from the user (an entry's `path`,
  or the Program field), never from `auto_execok`.
* **`ase::sim_capabilities_for {name {backend ngspice}}`**, and the peeks
  **`ase::sim_caps_have_path`** / **`ase::sim_caps_have`** — *is a fresh answer
  already in hand?* Cache and stamp only; no probe, no launch. This is what lets
  the dialog decide whether asking is free.
* **`ase::casemode_detected_in` / `ase::casemode_selectable_in` /
  `ase::casemode_report`** — the two-empties rule and A1 written **once**,
  against a capability dict, because there are now three ways to ask the
  question and A1 is a rule about the answer. `sim_casemode_detected` and
  `sim_casemode_selectable` become one-liners over them, plus the new
  **`ase::sim_casemode_selectable_path`** and
  **`ase::sim_casemode_selectable_for`**.
* **`ase::sim_casemode_floor`** — the validated global floor in one place;
  `sim_casemode_requested` now reads it in both of the spots that used to
  re-derive it, and the chooser's "global default (…)" label names the same
  mode.
* **Three new mint kinds** in `ase::sim_why`: `casemode_measuring`,
  `casemode_measured` (two arms — an empty measured set is a real answer) and
  `casemode_unmeasured`. Ruling D5-4: the dialog composes no sentences.
  *(The repair took this to nine: `casemode_nokey`, `casemode_noprogram`,
  `casemode_noprobe`, `casemode_slow`, `casemode_noplace` and
  `casemode_nopath`, because every one of those states was measured arriving at
  the user as `casemode_unmeasured` — see the adversary section.)*

### `src/ase_window.tcl` — the door

* `ase::ui::simdlg_editor` now builds **four** rows: `Name:` 0, `Program:` 1
  (Browse… in column 2), **`Case:` 2** (a read-only `ttk::combobox` at
  `$w.casemode`, **Detect** in column 2), **`-n:` 3** (a checkbutton at
  `$w.nospiceinit`, text `--no-spiceinit`, variable `ase::ui::dlg($key,simns)`),
  status 4, buttons 5. No suite row addresses this editor by grid row.
* **`ase::ui::simdlg_case_values`** — the one place A1 is enforced in this file.
  Values = the always-present `global default (<floor>)` line + exactly what the
  **program named in the Program field** was measured to deliver + the entry's
  own stored mode marked `(NOT measured)` when it is outside that set. Keyed on
  the field, not on the entry and not on the simulator in force.
  `simdlg_case_label` / `simdlg_case_value` map label↔value both ways.
  *(The repair added the missing half: the offer is REBUILT whenever that field
  changes — `simdlg_path_validate` — because keying on the field means nothing
  if it is only read twice. And the label's mark became two words for two
  states.)*
* **`ase::ui::simdlg_case_show`** — fills the chooser and selects a mode.
* **`ase::ui::simdlg_detect`** — the only control in the dialog that may start a
  process. Paints `casemode_measuring` and `update idletasks` **before** the
  launch, then rebuilds the values and shows `ase::casemode_report`'s sentence.
* **`ase::ui::simdlg_ok`** now reads the whole entry once through
  `ase::sim_entry` and registers with `-casemode` and `-nospiceinit` from the
  form. Its "EVERYTHING THE DIALOG DOES NOT SHOW IS CARRIED THROUGH" comment —
  the thing that misled the last reader — is rewritten to say what the proc
  actually does and to record what it used to do.
* `simdlg_cancel` / `simdlg_close` drop `dlg($key,simns)` alongside the existing
  records; `ase::ui::close`'s `array unset dlg $key,*` already covers the
  session-level case (row S18).

### `src/xschem.tcl`

* The stock `sim()` editor's Help still described `Exe / Args / Case / -n /
  Test` as "the second line of each row" of a dialog that lost them at the
  annotate merge. Replaced with a short paragraph pointing at ASE-L,
  Setup > Simulators…, and naming `~/.xschem/ase_simulators`.
* The `simconf` tombstone keeps the history and gains the line that the promise
  it recorded went unkept for ten months, and what that cost.

### `doc/claude/specs/ase_l.md`

"Edit shows Name and Program only and carries the extra arguments and the
backend through untouched" was false and was itself the record of the omission.
Rewritten for the four fields, the A1 rule the chooser enforces, and the
never-launch-unasked rule with its measured numbers. The probe's "measured at
~10 ms" was corrected to 447 ms cold (it predates the three case-mode legs).

---

## Which rows fence it

`tests/headless/test_ase_simdlg_0937.tcl` — the suite that already owns this
door. **32 → 41 for the first pass (item 1370 added S32 alongside), 41 → 48 at
the repair; the `--nogui` structural arm 4 → 5.** It carries no check-count
floor (grepped: no `MIN_CHECKS`, no floor, no "AND RAISED" paragraph), so none
was raised.

| row | what it fences |
|---|---|
| **S9** *(extended)* | Edit… leaves **every** field of the entry alone — args, backend, **casemode, nospiceinit**. The regression that would have caught the drop and did not. |
| **S24** | The row editor has a `Case:` chooser, read-only, and what it offers is exactly what THAT program was measured to deliver plus the global-default line. |
| **S25** | A1 against a second program measuring differently: a build with no casemode feature is offered `fold` alone, from the same dialog. |
| **S26** | The chooser describes the row the user clicked, not the row in force (locks evidence [6] — both directions). |
| **S27** | An unmeasured program and one whose file has gone are each offered `fold` alone, **and opening the editor starts nothing** (`sim_caps_have` still 0 afterwards). |
| **S28** | Detect measures the program in the Program field, rebuilds the offer, and reports it in `ase::sim_why`'s own words — no sentence retyped in the window file. |
| **S29** | The whole chain: pick `preserve` **from what is offered**, tick `-n`, press OK → entry → `casemode_requested` → `run_casemode_flag` → the saved file → **a real fresh `--nogui` xschem with its own HOME reads it back**. |
| **S30** | A mode hand-written for an unmeasured program opens shown and MARKED, and OK leaves it exactly as it was. |
| **S31** | STRUCTURAL: exactly one place in `ase_window.tcl` asks what a program may be offered, so A1 cannot be copied behind the dialog. |
| **S33** *(repair)* | Typing another location into the Program field REBUILDS the offer from the program now named there, and the live pick that program cannot deliver is marked. The row the adversary proved did not exist. |
| **S34** *(repair)* | A stored mode a MEASURED program does not deliver is marked with different words from one nobody has measured, and still maps back to the mode. |
| **S35** *(repair)* | After Detect has really tried something, the editor says what happened — answered but silent about spellings / file gone / no location given / tried and delivers none of them — and never "has not been tried yet". Includes the structural term that the empty-field answer is given before anything about a launch is painted. |
| **S36** *(repair)* | The editor says what is known BEFORE anything is tried: it names Detect on a cold program, repeats the measurement on a warm one, says the press-Detect sentence again after a save, and starts nothing to do any of it. |
| **S37** *(repair)* | The "trying it now" sentence is on the label at the instant the launch begins — read from inside a stand-in probe hook — and `update idletasks` sits between the sentence and the measurement. |
| **S38** *(repair, no display)* | What was measured is remembered about a program AND the argv it was started with, in both orders, and the peek can tell two argument lists apart. |
| **S39** *(repair)* | Detect measures the program named in the Program FIELD even when it is not the one the entry was registered with — S28 could not see this, because it presses Detect without touching the field, where the two are the same string. |

Two new stubs make this measurable without a simulator: `ngcase` echoes back
whatever `-D casemode=` asked for (so it measures as delivering all three), and
`ngnocase` answers the way a build with no casemode feature answers (recorded as
`fold` alone). The repair adds a third, `ngargs`, which answers like `ngnocase`
when it is given `-q` and like `ngcase` when it is not — one file, two truths,
which is what row S38 is about — and a **probe stand-in**: two of the states the
adversary found cannot be produced by any stub program (a probe that completes
and recognises nothing, and "what did the status line say at the instant the
launch began"), so the hook itself is renamed aside for one gesture and put
back. The probe's scratch area is redirected to the suite's own
`::netlist_dir`, the same way `test_ase_simcaps_0948.tcl` does it.

### Sabotage table — every new row proved non-vacuous

Each sabotage applied alone to a green tree, suite re-run on `:99`, source
restored with `cp` and `md5sum -c` verified (`src/ase.tcl`
`9f204436bb951ee50e807bba11ca8587`, `src/ase_window.tcl`
`1720e5ed7ff6225ace6b97ae41da8279`).

| sabotage | RED rows, by name |
|---|---|
| **SAB1** `simdlg_case_values` ignores the measurement (`if {0}`) | S24 S25 S26 S28 S29 |
| **SAB2** `simdlg_ok` drops `-casemode`/`-nospiceinit` (the pre-fix body) | S9 S29 S30 |
| **SAB3** `simdlg_detect` measures nothing | S28 |
| **SAB4** the `_for`/`_path` accessors delegate to the in-force one (evidence [6]) | S25 S26 |
| **SAB5** the chooser probes on open (no `sim_caps_have_path` guard) | S27 S28 |
| **SAB6** a second `casemode_selectable` caller inside `simdlg_detect` | S31 |

Restored tree at the first pass: `RESULT: ALL PASS (40 checks)`.

### Sabotage table — the REPAIR's rows, proved the same way

Each sabotage applied alone to the repaired tree, suite re-run on `:99` through
`tests/headless/devdisplay.sh exec`, source restored with `cp` and `md5sum -c`
verified OK after every one of them.

| sabotage | RED rows, by name |
|---|---|
| **SAB-A** the Program field's validation is not wired, so the offer is built only at open | S33 |
| **SAB-B** one mark for both states (`simdlg_case_mark` always `untried`) | S33 S34 |
| **SAB-C** *the adversary's own ADV2b* — both readers re-keyed on the entry's stored path | S33 |
| **SAB-D** `ase::casemode_report` reverted to its two-arm body | S35 |
| **SAB-E** Detect's empty-path guard removed | S35 |
| **SAB-F** the status line is not painted when the editor opens | S36 |
| **SAB-G** *the adversary's own ADV7* — the pre-launch sentence AND the flush deleted | S35 S37 |
| **SAB-H** `ase::cap_key` keyed on the path alone again | S38 |
| **SAB-I** *the adversary's S28 claim* — `simdlg_detect` re-keyed on the entry's stored path | S39 |
| **SAB-1 re-run** `simdlg_case_values` ignores the measurement | S24 S25 S26 S28 S29 **S33 S35 S36 S39** |
| **SAB-5 re-run** the peek guard removed, so the chooser probes on open | S27 S28 S30 **S36 S37 S39** |
| **SAB-2 re-run** `simdlg_ok` drops `-casemode`/`-nospiceinit` (the pre-fix body) | S9 S29 S30 **S33 S36** |

Restored tree: `RESULT: ALL PASS (48 checks)` on `:99`, `ALL PASS (5 checks)`
on the `--nogui` structural arm. The two re-runs at the bottom are the point of
the exercise the other way round: the rows the first pass shipped are STRONGER
after the repair, not weaker — nothing here made an existing fence vacuous.

---

## Suites run, by name

Xvfb `:99` / openbox 3.6.1 / 1920x1080x24, all
`devdisplay.sh exec ./src/xschem --pipe -q --nolog`:

| suite | first pass | after the repair |
|---|---|---|
| `test_ase_simdlg_0937` | ALL PASS (40, then 41 with 1370's S32) | **ALL PASS (48)** |
| `test_ase_simdlg_0937` (`--nogui` structural arm) | ALL PASS (4) | **ALL PASS (5)** |
| `test_ase_simcaps_0948` | ALL PASS (84) | ALL PASS (84) |
| `test_ase_simreg_0931` | ALL PASS (79) | ALL PASS (83, 1370's rows) |
| `test_ase_window` | ALL PASS (228) | ALL PASS (228) |
| `test_sim_run_profile` | ALL PASS (37) | ALL PASS (37) |
| `test_ase_persist` | ALL PASS (136) | ALL PASS (136) |
| `test_sim_probe` | — | ALL PASS (44) |
| `test_sim_casemode_registry` | — | ALL PASS (28) |
| `test_ase_dialogs` | — | ALL PASS (176) |
| `test_ase_launch` | — | ALL PASS (44) |
| `test_ase_preflight` | — | ALL PASS (114) |

---

## Owed to the user

**RULING (no `--eyes` — this is decidable in words): may opening `Edit…` launch
the user's simulator?**

The chooser can only obey A1 if something has measured the binary, and measuring
means running it: 447 ms cold on their own build, 0 ms warm, **31.2 s** worst
case on a program that exists and does not answer, with Tk frozen throughout.
Three shapes, and the choice trades their time against their expectations:

**(a) Cached-first + Detect — implemented.** Never launches unasked. After any
run in the session the chooser is fully populated instantly. Otherwise it offers
`fold` alone plus a `Detect` button that paints its sentence before it blocks.
Cost: on a cold session the user sees `fold` alone, which risks looking like the
very bug being reported.

**(b) Probe on open.** Always right, no extra click; `Edit…` can freeze for up
to 30 s, and opening the editor becomes a gesture that starts the user's
simulator — for a licensed tool, one that may check out a licence. The old
auto-probe gate that guarded exactly this (`probe only when the executable is
named *ngspice*`) was **deleted at the annotate merge** with the note that the
concern "belongs on `capabilities` as a whole", so re-adding it inside the
dialog would contradict a ratified note.

**(c) Probe on open, but only when already cached or the entry is the one in
force.** Covers the user's own bench at the cost of a rule harder to state than
either of the others.

Every piece of (b) or (c) is a one-line change to
`ase::ui::simdlg_case_values`. Recorded with
`tests/headless/owed.sh add rule 1371 "probe-on-open vs Detect"`.

**The repair narrows (a)'s cost rather than removing it.** The editor now says
what it knows and names Detect, so the cold session no longer looks like the
bug; the click is still there.

**SECOND RULING (added at the repair): a mode the chooser marks `(NOT
supported)` is still SAVED when the user leaves it selected.** Retype the
Program field to a program that was measured and cannot deliver the mode that
is picked, and the chooser rebuilds, marks the pick, and OK writes it down.
Two readings, and it is the user's to settle:

* **as shipped** — record it. It is the same rule row S30 already carries for a
  hand-written mode; the mark is in front of the user at the moment they press
  OK; and the run itself is not silent — `ase::run_casemode_verdict` (B4)
  REPORTS a `preserve` that the binary does not deliver and REFUSES a
  `distinguish` one, immediately before the run. It also lets someone set a
  mode for a build they are about to rebuild.
* **refuse or downgrade at OK** — the dialog would then enforce a rule the
  registry itself does not have, mid-gesture, on typing the user may not have
  finished; and it would have to choose between throwing their pick away and
  refusing to close.

Recorded with `owed.sh add rule 1371_marked_mode_is_saved`.

**PIXELS (moved to the `look` queue at the repair).** Three questions about
this dialog need eyes and cannot be answered by a green suite — the `Case:`
chooser's read-only styling, whether the editor grown from three grid rows to
six clips the `Detect` button, and whether the marked labels
(`preserve (not tried yet)`, `preserve (NOT supported)`) fit. They were filed
inside the `suite` debt for `test_ase_simdlg_0937`, which `drain` clears on a
green run — a suite pass answering none of them. Now `owed.sh add look`.

---

## What the adversary found, and what was done about it

Three adversaries read this item after it landed. Everything below was
**re-measured here** before it was acted on — a finding is not a defect because
another agent says so, and two of them were wrong in ways the measurement
shows. Runs: `tests/headless/devdisplay.sh exec ./src/xschem` on Xvfb `:99` /
openbox, `--logdir` into a private scratch, `::USER_CONF_DIR` and
`::netlist_dir` redirected; `~/.xschem/ase_simulators` md5
`17a24a6f06765158b8e4f2850993055e` and `/tmp/Xschem.log.8` (9706 bytes,
2026-09-06 00:17) unchanged start to end.

### ACCEPTED — the offer did not follow the Program field (the item's own "one correction" was false)

The write-up said the chooser is "keyed on the PROGRAM NAMED IN THE PROGRAM
FIELD … because a user who has just typed a NEW location into the Program field
would otherwise be offered the OLD program's modes". It was keyed on the field
and **built only at editor-open and by Detect**, with nothing bound to the
field. Reproduced here through the real widgets:

    entry cm at ngcase (measured fold preserve distinguish)
    open Edit…                     : {global default (fold)} fold preserve distinguish
    pick preserve
    type ngnocase's location in    : {global default (fold)} fold preserve distinguish   <-- UNCHANGED
    what ngnocase can really do    : fold
    press OK                       : saved path=…/ngnocase  casemode=preserve

**Repaired:** the Program entry carries a `-validate key` command
(`ase::ui::simdlg_path_validate`) that rebuilds the offer at the next idle
point — validation fires for typing AND for the programmatic delete/insert
`Browse…` does, so one mechanism covers both doors and neither can be forgotten
separately. The live pick is kept and MARKED rather than moved, because a
half-typed location names no program and a rebuild that reset the selection
would destroy the user's choice one keystroke at a time. After the repair the
same gesture gives `{global default (fold)} fold {preserve (NOT supported)}`
with `preserve (NOT supported)` in the box.

**Fenced by S33**, and the adversary's own sabotage (`SAB-C`: re-key both
readers on the entry's stored path — the shape the write-up says it had to
correct) now reddens S33 where it used to leave the suite at ALL PASS. The same
adversary's separate claim — that S28's clause "Detect measures the program in
the Program field" is a false-fence, because re-keying `simdlg_detect` alone
leaves S28 green — is true, was reproduced, and is **fenced by S39**: S28 never
touches the field, so the two paths are the same string in every gesture it
makes. The symptom S39 protects against is "Detect does nothing", which is what
a user sees when the button measures the program they are replacing.

### ACCEPTED — the mark said "(NOT measured)" about a measurement that had been taken

Two states wore one wording. `preserve (not tried yet)` is now "nobody has
measured this program"; `preserve (NOT supported)` is "it was measured and it
does not deliver this". **Fenced by S34** (and S30 keeps the first).

### ACCEPTED, WITH THE CAUSE CORRECTED — pressing OK relabels the user's own choice

Measured, deterministic, on their own build: Detect → pick `preserve` → OK →
reopen `Edit…` and the chooser said `preserve (NOT measured)` about a program
measured 449 ms earlier. The adversary called it a labelling defect and it is;
what it is NOT is a bug in this item's code. `ase::sim_register` ends in
`ase::sim_caps_clear` — "adding or editing an entry means look at the program
again", issue 0950 — and row **D10 of `test_ase_simcaps_0948` pins exactly the
gesture that would have to change**: "the same name, pointed at the same place.
If only a CHANGED path re-measured, the user who rebuilt in place and re-saved
the entry would still be served the stale answer." So the forgetting stays.

**Repaired where the defect actually was:** the wording (above), and the
silence. The editor now paints `ase::casemode_status` when it opens, so the
state reads "…has not been tried yet, so fold is all that can be offered; press
Detect to try it." instead of nothing at all, and one Detect (353 ms measured)
restores the plain label. The user's **setting is never touched** — reopen and
OK keep `casemode preserve`, measured. **Fenced by S36**, which asserts the
cold sentence, the warm sentence, the after-save sentence and that none of the
three started anything.

### ACCEPTED — Detect's sentence was false in every state but the happy one

Reproduced through the real button, four states, all of which printed
"<path> has not been tried yet … press Detect to try it" **after Detect**:

    a program that answered the probe with no casemode key
        (known 1 usable 0 …, i.e. every executable that is not an ngspice)
    a program whose file has gone
        (while the SAME dialog's Problem column carried the right sentence)
    a backend with no probe hook
    Add… then Detect with the Program field empty
        -> "Trying  now, to find out which spellings…" and " has not been
           tried yet…": two sentences with no subject and a leading space

**Repaired:** `ase::casemode_report` takes the backend, and has an arm per
state — `casemode_nokey`, `casemode_noprogram` (naming what is wrong with the
file), `casemode_noprobe`, `casemode_slow` (the 31.2 s case, which the user has
just waited through), `casemode_noplace` (issue 0949's folder), `casemode_nopath`.
All six are minted in `ase::sim_why`; the window file composes none of them
(ruling D5-4). `casemode_unmeasured` now means only "nobody has asked", and
`ase::casemode_status` is the one proc entitled to say it. **Fenced by S35**,
including the structural term that the empty-field answer is given before
anything about a launch is painted.

### ACCEPTED — the pre-launch sentence was asserted by nothing

`casemode_measuring` appeared in no test file in the tree; the adversary
deleted both the sentence and the `update idletasks` and the suite stayed at
ALL PASS. **Fenced by S37**, which reads the status label **from inside the
probe hook** — a stand-in installed for one gesture — so the ordering is a
measurement and not a reading of the source, plus a structural term for the
flush, which no widget can see.

### ACCEPTED, MECHANISM CORRECTED — the capability cache could answer about the wrong argv

The claim was that a dialog-side measurement makes an in-force entry answer
`{}`. Measured here, that is **not** what happens: the cache is keyed on the
resolved path alone and **the first answer taken wins**, so the second asker
gets an answer about somebody else's argv. Driven both ways on a stub that
reports no case-mode feature under `-q` and all three without it:

    entry -args -q, in force, asked first     : fold
      dialog-side Detect, no args             : fold                 <-- wrong
    the same, dialog first (cold)             : fold preserve distinguish
      in-force accessor immediately after     : fold preserve distinguish  <-- wrong
      after ase::sim_caps_clear               : fold

The second block is the A1 breach at the far end: `preserve` offered — and
requested — for an entry that folds. **Repaired** by keying the cache on the
program AND the argv it was started with (`ase::cap_key`), which is what the
probe has always used (ruling A2, probe with the real argv), and by teaching
the peek `ase::sim_caps_have_path` the same key — a peek that answered "in
hand" for an unmeasured argv would send the editor into the accessor, and the
accessor launches. `test_ase_simcaps_0948` is unchanged at 84. **Fenced by
S38**, which needs no display.

### ACCEPTED — the `--nogui` SKIP line under-reported by nine rows

It named `S1-S12 S14b S15 S17 S18 S20-S23` and never mentioned S24-S32. It now
names the FOUR rows that DO run without a display, which stays true when a GUI
row is added.

### ACCEPTED — a stale row pointer in the source

`src/ase_window.tcl` cited "row S20f"; the row that pins it is S31. Fixed, with
the correction recorded in place.

### ACCEPTED — the pixel questions were on a self-clearing debt

They lived inside the `suite` debt for `test_ase_simdlg_0937`, which `drain`
clears on a green run, and no check measures widget width or clipping. Moved to
`owed.sh add look` (see **Owed to the user**).

### PARTLY REJECTED — "dead accessors"

`ase::sim_capabilities_for`, `ase::sim_casemode_selectable_for` and
`ase::sim_caps_have` do have no production caller: grepped, confirmed. They are
**not** dead, and deleting them would weaken the suite. They are the
ENTRY-KEYED question, and rows S24-S27 and S36 use them as the oracle the
dialog's own offer is compared against; an oracle that re-derived the dialog's
key (the Program field) would stop proving that the offer describes the row the
user clicked. What was wrong was the write-up presenting all four as things the
dialog uses. Fixed in the source, at the proc, in as many words.

### REJECTED — "the probe's error is swallowed silently"

Half true and now moot: `ase::sim_capabilities_path` still catches, because a
stack trace out of a proc that is building a combobox is a dead window, but the
error is echoed to the CIW where every other ASE failure goes. It is not a mint
kind on purpose — it carries a Tcl error message, so it is a defect report to a
developer, not a sentence for the user.

### NOT THIS ITEM — reported to the driver

`test_ase_optier_0963` reds on item 1370's new run sentence (rows Q6 and S11),
and needs more than `run_suites.sh`'s 500 s cap, so that harness reports
TIMEOUT and hides them. Not touched here.

### What the repair changed, by file

* **`src/ase.tcl`** — `ase::cap_key`; the cache read and write and
  `ase::sim_caps_have_path` keyed through it (`{eargs}` added to the peek);
  `ase::sim_has_probe`; `ase::casemode_report` rewritten with a signature that
  takes the backend and an arm per measured state; **`ase::casemode_status`**,
  the never-measures reader the editor paints with; six new `ase::sim_why`
  kinds; the probe error echoed from `ase::sim_capabilities_path`; and the
  entry-keyed accessors' purpose written down at the proc.
* **`src/ase_window.tcl`** — `simdlg_case_label` takes a state word, not a
  boolean, and has two marks; `simdlg_case_ctx` and `simdlg_case_mark` (the
  shared question, worked out once); `simdlg_path_changed` /
  `simdlg_path_validate` (the offer follows the field); `simdlg_case_status`
  (what the editor says before anything is tried); the Program entry's
  `-validate`, its `<FocusOut>`, and the paint at open; `simdlg_detect` guards
  the empty field and calls the new report; `simdlg_browse` repaints the status;
  the S20f pointer corrected.
* **`tests/headless/test_ase_simdlg_0937.tcl`** — rows S33-S39, the `ngargs`
  stub, the probe stand-in (`probe_stub_install` / `probe_stub_remove`), S30's
  mark word, and the SKIP line.
* **`doc/claude/specs/ase_l.md`** — the chooser bullet rewritten for the rebuild
  and the two marks; two new bullets for `casemode_status` / `casemode_report`
  and for the argv-keyed cache.

---

## Adjacent, filed rather than silently fixed

**The global floor `sim_case_mode` has no GUI door either.** It is a `set_ne` in
`src/xschem.tcl` and is settable only from an rc file. Per this item's own
design the *per-simulator* field is the right lever and it is what got built
here; the floor's doorlessness is a separate, smaller question and should get
its own number rather than be swept in. The chooser's `global default (<mode>)`
line at least now *names* the floor, so a user can see what they are deferring
to.

---

## What the re-key cost, and how it was found

**Found by the driver during verification, after every crew had reported green.**

This item re-keyed the capability store from the resolved PATH to
`ase::cap_key {resolved eargs}`, so the row editor can hold one answer per
program-and-arguments. That is right, and nothing in the source was wrong. But
`tests/headless/test_ase_optier_0963.tcl` primes that store **directly** — the
only way to hand `ase::op_save_tier` a capability answer without launching
anything — and it spelled the key by hand:

    set ::ase::sim_caps [dict create $r [list stamp $st caps $caps]]

After the re-key that address no longer existed. Every primed answer became
invisible, every lookup fell through to a **live probe of whatever ngspice the
bench could resolve**, and ten rows measured that binary instead of the fixture:

    T1 T2 T3 T5 T6 T10 T13 Z6   -> {c unsafe}, which is /usr/bin/ngspice's own
                                   answer, where the fixture expected
                                   blanket / unknown / nocap
    S1                          -> op_tier_perdevice for a blanket fixture
    S11                         -> a third sentence kind, minted by the live path

Measured: `RESULT: 10 FAILED (92 passed)` on this tree against
`RESULT: ALL PASS (102 checks)` at HEAD `5dc7b2c8`, taken in a detached
worktree with the same binary so the working tree was never disturbed.

**Fixed** by making the fixture ask for the key instead of spelling it —
`[ase::cap_key $r {}]`, at both priming sites — which puts the next re-key's
cost at zero. Back to `ALL PASS (102)`.

**The process lesson, recorded because it is the reusable half.** Both items of
this chain ran in one tree: 1370 patched this suite for its own new sentence and
ran it green; 1371 then landed the re-key and did not re-run it. A suite that a
chain has already touched must be re-run by the chain's LAST item, not by the
one that touched it.

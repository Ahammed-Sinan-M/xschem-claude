# Crew B receipt — the dialog (`src/ase_window.tcl`)

Scope as briefed: `src/ase_window.tcl`, plus rows in
`tests/headless/test_ase_simdlg_0937.tcl`. Nothing else was touched — not
`src/ase.tcl`, not `src/xschem.tcl`, not `tests/headless/test_ase_persist.tcl`,
not `test_ase_window.tcl` (it needed no row and it did not move), not
`LEDGER.md` (see §7). Nothing committed.

---

## 1. What changed in `src/ase_window.tcl`

### B1 — `ase::ui::simdlg_use`: the pick is the bench's, and it never reaches disk

Was: read the combobox → `ase::sim_select` → `ase::ui::simdlg_commit` →
`ase::sim_write_conf`. The user's choice went straight to
`~/.xschem/ase_simulators` with no save gesture behind it.

Now, three destinations and no fourth:

1. `ase::sim_choice_set [ase::session_state $key] path|entry $v` — the state
   key. No value of the encoding is spelled in this file.
2. `ase::session_update $key $st` — the one write path the panes share; its
   notify is what repaints the title's dirty marker and the bottom bar.
3. `ase::sim_apply_choice $st` — so what is in force *this instant* agrees with
   what the user just picked. **On `$st`, not on `[ase::session_state $key]`**:
   `session_update` answers 0 for a key it does not know, and applying the
   session then would put the OLD choice in force behind a widget showing the
   new one.

`ase::ui::simdlg_commit` is not called on this path, or on any other (§B3).

**The refusal arm is kept and is now guarded rather than incidental.** The old
code got the refusal from `ase::sim_select` raising. `ase::sim_apply_choice`
never raises, so the check moved in front: `[ase::sim_entry $v] eq {}` decides,
and the *sentence* is still asked of `ase::sim_select`, which refuses exactly
this and changes nothing while doing it. No sentence is minted here (ruling
D5-4). The state is left alone on that path — storing an unregistered name
would dirty the bench with a pick that cannot run and would then show it back
as the truth. Row **S46** is new and pins it.

An empty combobox value now takes the same arm as the "(none — …)" label. The
old code mapped it to `sim_select {}` (clear the choice); the new code maps it
to the `path` choice, which is the same meaning in the new encoding.

**The `key` comment.** The brief was precise and so is the fix: the sentence
that said *"`key` is unused on purpose — the registry is process-global"* lived
on `simdlg_commit`, which is gone. Its two halves are now separated, in
`simdlg_use`'s own header: *"`key` IS LOAD-BEARING NOW. It always named the
session whose widgets are being refreshed; as of 1395 it also names the session
whose state is being changed, which is why the choice can differ between two
open windows while the registry cannot."*

### B2 — `ase::ui::simdlg_fill`: the combobox shows the SESSION's choice

`set sel [ase::sim_selected]` → `ase::sim_choice_of [ase::session_state $key]`,
falling back to `ase::sim_default_choice` when that decodes `unset`, and to the
"(none — …)" label when neither has an entry. The comment says why the blank is
not an option: the blank line in this combobox *is* the deliberate-PATH choice,
so a bench that has never been asked would read as one.

`ase::ui::refresh_status_all` and its 1370 comment are untouched — still right,
because a registry mutation still has to repaint every open bar.

### B3 — `ase::ui::simdlg_commit`: **deleted**, with both call sites

Deleted. Crew A's receipt §1 confirms `ase::sim_register` and
`ase::sim_unregister` both call `ase::sim_touch` last, gated on
`sim_origin eq session`; measured here in §4d as well. So the proc was a second
write, by the gesture, of a file the mutation had already written — the same
bytes twice on the good path, and on a failing path a second chance to say a
sentence `sim_write_conf` has already said (crew A's row S8 pins that count at
one).

Deleting it is also what makes this file's own rule at the head of the section
true for the first time: *no validation, no path resolution and no persistence
is re-implemented here.* It had exactly one exception and this was it.

Three comments were updated rather than dropped:

* a **tombstone** where the proc was, recording what it did, that it was the
  tree's only caller of the writer, and that that is precisely why the CIW door
  did not stick;
* the **section header** (`:4477`), whose "and saves through
  `ase::sim_write_conf`" is no longer true and whose proc list named
  `sim_select`, which the dialog now calls only to obtain a refusal;
* the **two call sites**, which carry one line each saying the write already
  happened inside the mutation.

`grep -rn simdlg_commit src/ tests/` → the tombstone and the suite's contract
note. The remaining hits are in `doc/claude/issues/` and crew D's receipt, where
they correctly describe the *before* state.

### B5 — the door comment at `:288`

Extended, not rewritten. Two paragraphs added after 1370's, before the "⚠ NO
ARGUMENT" one: that as of 1395 the CIW door **persists** (register/unregister
call `sim_touch`, so the pair the user's own `ngspice-ver50` entry was made with
survives the restart it was always promised), and that the **choice half does
not** — it dirties the session and waits for an explicit save.

---

## 2. B4 — the failed-save sentence still reaches the dialog

**No bracketing fix was needed, and that is a measurement, not an assumption.**
`ase::ui::simdlg_ok` does its own `ase::sim_said_clear` immediately before
`ase::sim_register` and reads `ase::sim_said` back after the refill; the write
moved *inside* `sim_register`, i.e. inside that bracket, not after it.

**Row S11 is the pixel measurement and it is not new** — it makes `$CONFDIR`
unwritable (`0500`) in the suite's own scratch redirect, adds an entry through
the real row editor, and asserts the dialog's status label is byte-identical to
`ase::sim_said` and contains `could not be saved`. It was green before this
change because `simdlg_commit` wrote the file; it is green after it only because
`sim_register` does. Verified it runs rather than skipping (it skips as root).

Standalone confirmation, `--nogui`, `::USER_CONF_DIR` in the session scratchpad:

```
CONF=<scratch>/b4/conf/ase_simulators
P1_file_after_good=1          a good registration first, so the file really exists
P2_writable=0                 directory chmod 0500
P3_register_rc=0              the registration itself does not raise
P4_said_count=1               EXACTLY ONE sentence, from sim_write_conf
P5_said=Your simulator list could not be saved to <path>, so the simulators you
        added will be gone when xschem closes. Check that the folder exists and
        that you can write to it. The system said: couldn't open
        "<path>.new": permission denied
P6_entry_kept=1               and the entry the user just typed is still there
```

---

## 3. Rows

### B6 — S10b, the red crew A left

It asserted the pre-ruling contract (*the dialog's PATH choice reaching disk*).
**Rewritten in place, not deleted**, with the old wording and the ruling that
reverses it written above it, plus a pointer to where 0932's actual guarantee
now lives (row R8 of `test_ase_simreg_0931`, against the saved file's own
selection line). It now pins: a clean saved bench, the "(none — …)" pick, and
then — in force is the PATH, the bench is dirty, the conf file is **byte-identical**
and its mtime unmoved, it does **not** contain `ase::sim_select {}`, and it
**does** still contain `ase::sim_select mybuild5`, the installation default.

### S21 — the other row whose meaning the ruling reversed

Its last two terms were `0 0` and its comment read *"the witness that no session
update happened on either side of the gesture"*. They now read `0 1`, with the
reversal and the old contract written above them. The first three terms — the
bar follows the gesture — are unchanged, which is what keeps 1370 fenced.

### B7 — the seven new rows (`S40`–`S46`)

| row | what it pins |
|---|---|
| **S40** | the headline: dirty 0 → 1, the combobox and `sim_selected` both move, the state's choice decodes `entry two41`, and the conf file is byte-identical with an unmoved mtime |
| **S41** | the title gains ` *`; the clean title is a prefix of the dirty one and the marker is never retyped here, so a re-wording costs nothing |
| **S42** | `session_save` clears the dirty flag; `session_load` (a real re-read from disk, discarding memory) still answers `entry two41`; the bench file contains `sim_entry` |
| **S45** | the combobox is the bench's, not the program's: state says `one41` while a CIW `ase::sim_select two41` has the process running `two41`, and the bar names `two41` — the witness that they are two different sources (limitation D5) |
| **S46** | the refusal arm: an unregistered name is refused in the registry's own words, the bench keeps the choice it had, the widget goes back to showing it |
| **S44** | a bench naming an entry nobody has registered any more: `sim_apply_choice` does not raise, says **exactly one** sentence (`llength $::ase::sim_said` == 1) equal to the mint's `noentry`, leaves what was in force in force, and the dialog shows the bench's own name rather than substituting one |
| **S43** | the quit sweep: `ask_save_close` stubbed (it is modal; the stub answers Cancel so the window survives for the teardown) — **fires once** on the dirty bench and `prompt_all_on_quit` returns 0; **does not fire** on the clean one and it returns 1. The clean control is half the row |

All seven drive the real widget path (`dlg_use` sets the bound variable then
calls the proc the `<<ComboboxSelected>>` binding calls), so none can pass on a
tree where the gesture is wired elsewhere.

A **floor comment** was added at the head of the suite (it had none): 55 on the
display arm, 5 on the structural one, and what it was raised from.

---

## 4. Measurements

### 4a. The user's own file — the rule that outranks the feature

`md5sum ~/.xschem/ase_simulators` before the first edit and after **every**
suite run and probe below: **`d66a9afd1a3bf1a32ae1112c3ea88558`, unchanged
throughout.** Every measurement redirected `::USER_CONF_DIR` into the session
scratchpad before its first `sim_register`; the suite already did (crew A
verified it) and still does, ahead of its first registration.

⚠ **Noted while probing, not a defect but worth knowing:** redirecting
`::USER_CONF_DIR` *after* startup does not empty the in-memory registry, so the
first `sim_register` writes the user's already-loaded entries into the scratch
file too. Harmless (the write goes to the scratch path, and the content is what
the real file already holds), but it means a scratch conf file that mentions
`ngspice-ver50` is expected, not alarming.

### 4b. The ruling in one screen — the real gesture, `--nogui`

`ase::ui::simdlg_use` needs no dialog window: it reads the bound variable, sets
the state and applies the choice, and `simdlg_fill` self-skips with no widgets.
So the gesture itself can be measured with nothing on screen:

```
--- conf after two registrations   mtime=1788934592 md5=458f0ce9…
  ase::sim_register ngspice-ver50 …
  ase::sim_register ng-a /usr/bin/sh …
  ase::sim_register ng-b /usr/bin/sh …
  ase::sim_select ngspice-ver50
dirty before   = 0
in force before = ngspice-ver50

--- the gesture: the user picked ng-b in the combobox
dirty after    = 1
in force after = ng-b
state choice   = entry ng-b

--- conf after the pick            mtime=1788934592 md5=458f0ce9…   (IDENTICAL)
  … ase::sim_select ngspice-ver50                                   (UNCHANGED)

dirty after save = 0
BENCH FILE: sim_entry {name ng-b}
```

The bench is running `ng-b`, the machine's own file still says
`ngspice-ver50`, the dirty flag rose and only an explicit save cleared it, and
the choice is in the *bench* file. That is the whole ruling on one screen.

### 4c. Floors — raised, never lowered

| suite | before | after | why |
|---|---|---|---|
| `test_ase_simdlg_0937` (display arm) | **48** (47 pass + S10b red) | **55** | S40–S46; S10b and S21 rewritten in place |
| `test_ase_simdlg_0937` (structural arm) | **5** | **5** | no structural row added |
| `test_ase_window` | **267** | **267** | needed no row and did not move |

### 4d. Every suite that could see this change

All run through `tests/headless/devdisplay.sh exec ./src/xschem --pipe -q
--nolog --script …` on the persistent dev display (`:99`, Xvfb, **openbox
3.6.1** live — `devdisplay.sh status` reports it).

```
test_ase_simdlg_0937      ALL PASS (55)   display arm
test_ase_simdlg_0937      ALL PASS (5)    --nogui structural arm
test_ase_window           ALL PASS (267)
test_ase_simreg_0931      ALL PASS (111)  R9 greps THIS file for minted phrases
test_ase_simcaps_0948     ALL PASS (110)
test_ase_dirty            ALL PASS (41)   owns prompt_all_on_quit's DR rows
test_ase_dialogs          ALL PASS (176)
test_ase_core             ALL PASS (230)
test_ase_view             ALL PASS (36)
test_ase_final            ALL PASS (82)
test_ase_launch           ALL PASS (44)
test_ase_savestate_adopt  ALL PASS (26)
test_ase_persist          ALL PASS (147)  crew C's, run only
test_ase_simchoice_1395   ALL PASS (31)   crew C's, run only — incl. its L1 lint row
```

`tests/run_regression.tcl` was **not** run: crews C and D were live in the same
tree and issue 0990 says a T1 number taken beside another suite is not evidence.

---

## 5. Debts recorded

* **`suite test_ase_simdlg_0937`** — every S40–S46 measurement is Xvfb-only.
  Owes one `AUDIT_DISPLAY=:0` run; S41 reads a title after a notify and is the
  row most exposed to Xwayland's 3-vs-1 `<Configure>` traffic. (Suite debts
  dedupe by name and this suite already owed one, so the count stayed at 7 and
  the newer reason replaced the older — which is the ledger's own rule.)
* **`look`** — the pixel deliverable, with the six things to check (marker,
  `~/.xschem/ase_simulators` mtime unmoved, save clears it, quit prompts, two
  windows two combobox answers one bar, the copy is still the mint's). *Suites
  green, please look* — a green suite does not discharge it.
* **`rule 1395-default`** — §6 below. Filed under a distinct id: rule debts
  dedupe by id and `1395` is already taken by D5's, which an `add rule 1395`
  would have silently overwritten.

---

## 6. The question for the user — recorded, NOT answered

Crew A's gap, verified here and **not** built:

**Nothing in a running session can change `ase::sim_default`.** It is set only
by the saved list, by the rc seed, and by the first-ever registration. The
dialog's combobox now sets the *bench's* choice and never the default. So once a
user has registered one simulator, the installation default is pinned to it, and
issue 0932's own gesture — *hand control back to the program my system finds on
my PATH, as the default, for every bench with no opinion* — has no door left but
a hand edit of `~/.xschem/ase_simulators`.

Inside a bench it is fine: pick "(none — use the program my system finds on the
PATH)", it dirties, you save it, and it is prompted for on quit. Outside one
there is now no gesture at all.

The options: **(a)** a "Make this the default" gesture in Setup > Simulators
that writes and persists `ase::sim_default`; **(b)** a ruling that the
installation default is only ever set by the saved list and the rc; **(c)**
something else. **Crew B invented no answer** — no such button was built.
`grep -n 'sim_default' src/ase_window.tcl` returns five lines and not one of
them writes it: two are the `ase::sim_default_choice` fall-back read in
`simdlg_fill` and its comment, and three are an unrelated pre-existing block
about Tcl's own `::set_sim_defaults` (`:1194`-`:1205`).

---

## 7. Contradictions with the brief, and one thing left alone

1. **The brief's "or check `ase::sim_entry` first"** is the arm that was taken,
   and it is the right one for a reason the brief did not state: with
   `sim_apply_choice` doing the refusing, the unregistered name would already be
   in the session state by the time the sentence was said, so the widget's
   "showing the truth" would be showing the bad name back. Checking first keeps
   the bench clean. Row S46 exists because this arm is now code I wrote rather
   than code I kept.

2. **The brief expected `simdlg_commit`'s comment at `:4649` to be *fixed*
   precisely rather than deleted.** The proc it belonged to is gone, so the
   comment could not be fixed in place; its two claims were split — the
   registry-is-process-global half went to the tombstone, the `key` half to
   `simdlg_use`'s header, where it is now the opposite of what it said.

3. **`test_ase_window.tcl` was left untouched.** The brief allowed rows there;
   none belonged there. Its `test_sim_registry_isolate` call clears
   `::ase::sim_autosave` (crew A), so a "the conf file was not written" row in
   that suite would be vacuous — the writer is disarmed. Every B7 row lives in
   `test_ase_simdlg_0937`, which has a live `::USER_CONF_DIR` redirect and a
   live writer, and is the suite whose subject this is. Its floor is unchanged
   at 267 and it is green.

4. **`LEDGER.md` still says "pending B" for this suite's floor.** It is a doc
   file outside this receipt and the brief forbade touching it. The numbers for
   it are §4c: `test_ase_simdlg_0937` **48 → 55** (display), **5 → 5**
   (structural); `test_ase_window` **267**, unmoved.

5. **The known limitation D5 got sharper, not wider.** Row S45 measures it
   directly for the first time: the combobox and the bar can name different
   simulators, because one reads the bench and the other reads the process-wide
   cache. The run resolves it (`ase::run_deck` applies the running bench's
   choice). Nothing was built to close it; it is the standing `rule 1395` debt.

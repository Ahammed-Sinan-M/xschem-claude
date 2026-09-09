# 1395 — registration persists through one door, and the choice persists through one too many

**Filed** 2026-09-08, item D of the ASE-L simulator-choice batch
(`doc/claude/ase_simchoice_batch/CREW_BRIEF.md`).
**Status** OPEN — **being fixed by this batch**, items A (`src/ase.tcl`) and B
(`src/ase_window.tcl`). This file is the record and it was written *first*, so
every measurement below is of the tree BEFORE the fix. Whoever closes it flips
this line to FIXED and names the rows.
**Files** `src/ase.tcl` (`sim_register`, `sim_unregister`, `sim_select`,
`sim_clear`, `sim_write_body`, `schema_keys`/`omit_if_empty`),
`src/ase_window.tcl` (`simdlg_commit`), `src/xschem.tcl` (the Configure
simulators help block), `doc/claude/specs/ase_l.md`.

## 1. The user's words, 2026-09-08

> Yes, registering a simulator (so that future Xschems see the "new" simulator
> instance) is something that can make it to disk right away as soon as done.
> But, registering a simulator is not part of the simulator state that
> accompanies a test-bench cell in the library manager.
>
> *Whether* the "new" simulator just registered gets assigned as "the one to
> use" is an option that is part of the ASE-L state. If changed, that results in
> dirtiness. User must explicitly save and, if user initiates an Xschem
> shutdown, then she must get a warning and a prompt to save.

Two sentences, two halves, and the shipped tree has each of them backwards.

## 2. Half one — registration does not persist through every door

`ase::sim_register` (`src/ase.tcl:1300`) writes **nothing** to disk. Neither
does `ase::sim_unregister` (`:1459`). The registry persists only because the
**gesture** saves: `ase::ui::simdlg_commit` (`src/ase_window.tcl:4649`) is a
two-line proc whose whole body is `catch {ase::sim_write_conf}`, and the
Simulators dialog calls it after every Add, Edit and Remove.

`grep -n sim_write_conf src/*.tcl` returns exactly **one** production call
site — that one. So the dialog is a door that saves and the Command window
(CIW) is a door that does not.

Measured 2026-09-08 with `::USER_CONF_DIR` redirected to a scratch directory
(`./src/xschem --nogui --pipe -q --nolog --script`; nothing under `~/.xschem/`
was touched):

```
P1_conf_after_two_registers_exists=0     ;# two ase::sim_register calls, no file at all
P2_in_force=aa                           ;# the first registration auto-selected itself
P3_conf_after_select_exists=0            ;# a choice gesture writes nothing either
P4_conf_after_writer_exists=1            ;# ase::sim_write_conf, called by hand
P5_select_line=ase::sim_select bb        ;# ...and it wrote the choice down
```

**Two pieces of the tree had already ruled that this is a defect and not a
design choice**, before the user's sentence arrived:

* `src/xschem.tcl:4935-4936` promises persistence unconditionally, with no
  mention of which door you used — *"The saved list is
  ~/.xschem/ase_simulators and it comes back at the next start."* A user who
  reads that and types their registration into the CIW loses it at the next
  start, silently.
* The comment issue **1370** left at `src/ase_window.tcl:288` already treats
  the CIW as a **real door**, in as many words: *"the registry has a second
  door: `ase::sim_register <name> <path>` then `ase::sim_select <name>` typed
  into the Command window, which is the pre-0937 path and the one this user's
  own ngspice-ver50 entry was first created through."* 1370 fixed the
  **display** half of that door — the open session bars now repaint on a
  registry mutation from anywhere. It left the **persistence** half exactly
  where it found it.

So this is not a new claim about how the CIW ought to behave. It is the other
half of a door the tree has already admitted is a door.

## 3. Half two — the choice persists when it should not

The entry in force is the process-global `ase::sim_use` (`src/ase.tcl:711`,
declared in `namespace eval ase`). It is in **no state dict**: `schema_keys`
(`:44`) has no key for it, so:

* changing it does not dirty a session — `ase::session_dirty` (`:8996`) is
  literally `[state_serialize state] ne [state_serialize saved]`, and a value
  that is in no schema key cannot move that comparison;
* it therefore never needs an explicit save;
* and it never prompts on shutdown. Measured by the batch's recon:
  `ase::session_dirty` was **0 before and after** the dialog's in-force
  gesture, and `ase::ui::prompt_all_on_quit` returned **1** with
  `ask_save_close` stubbed to shout — the stub never fired.

And yet the choice **does** reach disk. `ase::sim_write_body` (`:3157`) ends by
writing an `ase::sim_select <name>` line (`:3200`/`:3203`), deliberately and
with a long comment defending it — issue 0932's *"none of mine, use the program
on my PATH is a choice, and it is written down like any other."* That reasoning
was sound while the choice had nowhere else to live. Under the ruling it is
exactly the forbidden thing: an environment file, written by a registration
gesture, carrying a per-test-bench decision. P5 above is it happening.

**Net effect today, stated plainly**: the half the user says *may* go to disk
immediately (registration) reaches disk only from one of two doors, and the
half the user says *must not* (the choice) reaches disk from both, unasked and
without a save.

## 4. ⚠ Do not confuse the two things called "which simulator"

| name | example | what it is | today |
|---|---|---|---|
| state key `simulator` | `ngspice` | the **backend** — which `ase::backend::<sim>::` table renders and runs the deck | already state, already dirties correctly, **not this issue** |
| registry entry | `ngspice-ver50` | **which program on this machine** — the path, its `-args`, its case mode, `--no-spiceinit` | process-global `ase::sim_use`, no state key, **this issue** |

A reader who reaches for `simulator` because the sentence said "which
simulator" will conclude there is no defect here. There is; it is one level
down.

## 5. The fix, as this batch builds it

Summarised from the brief; items A and B own the code.

* **`ase::sim_default`** — NEW process-global beside `sim_use`: the
  **installation** default, what a session expressing no choice of its own
  runs. Set by `sim_load_conf`'s `ase::sim_select` line, by the rc seed, and by
  the first-registration auto-select (P2 above). It is ENVIRONMENT.
* **`ase::sim_use`** keeps its meaning — "what is in force right now" — but
  becomes a **cache** of the active session's choice rather than the store of
  record. Every `ase::sim_status` caller is untouched.
* **`sim_entry`** — NEW ASE-L state key, the store of record for the choice.
  It goes in **`omit_if_empty`** as well as `schema_keys`, because 104
  committed `.state` files must stay byte-identical — that rule is already
  written down at `src/ase.tcl:66` for `cosim` and `save_op_params`. Three
  values:

  | value | meaning |
  |---|---|
  | absent or `{}` | this state makes no choice; use `ase::sim_default` |
  | `none` | deliberately the program on the PATH |
  | `{name <entry>}` | that registry entry |

  The two-word form exists so no registry name has to be reserved: a reader
  meeting a bare one-word value that is not `none` takes it as an entry name (a
  hand-written file is forgiving), and `{name none}` is how an entry actually
  called `none` is spelled. Documented in `doc/claude/specs/ase_l.md`.
* **Persistence moves from the gesture to the mutation.** `sim_register` and
  `sim_unregister` call the writer themselves, gated on
  `ase::sim_origin eq session` so that `sim_load_conf` — which **sources** the
  file, making every line a real `sim_register` call — does not rewrite the
  file it is reading.
* **`ase::sim_clear` is deliberately excluded.** It is teardown ("forget every
  registered simulator and every choice", `:1554`), not a choice, and
  autosaving there would let a test or a stray script blank the user's list.
  The rule, in one line for the comment: *a mutation that expresses a user's
  choice persists; a teardown does not.*
* **`sim_write_body` writes `sim_default`, never the in-force choice.**

## 6. The carried limitation — recorded, not fixed here

Two ASE-L windows open on different test benches still share **one**
`ase::sim_use`. The run path applies the *running* session's `sim_entry`, which
makes "the window you clicked in wins" — correct for the run, and it is the
half that decides which program actually starts. But a status bar or a dialog
in the **other** window may momentarily name the other choice, because the bar
renders from the process-global cache.

Not fixed here, on purpose: closing it means a per-window registry view, which
is a wider change than the ruling asks for and would touch every
`ase::sim_status` caller. Recorded so the next reader does not mistake it for a
regression of this fix. **Rule debt 1395.**

## 7. Debts

* **rule 1395** — the two-window limitation above (§6): whether "the window you
  clicked in wins for the run, and a stale name may sit in the other window's
  bar" is acceptable, or whether the bars must be made per-session too.
* The `sim_entry` spelling shares its name with the existing accessor proc
  `ase::sim_entry` (`src/ase.tcl:1527`, entry name → entry dict). A dict key and
  a proc do not collide in Tcl, and the two mean the same noun, so the
  repetition is deliberate — recorded here so nobody "fixes" it into a second
  vocabulary.

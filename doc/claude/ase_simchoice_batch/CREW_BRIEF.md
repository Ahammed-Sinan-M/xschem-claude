# Batch: the ASE-L simulator registry is environment, the choice is state

## The user's ruling, verbatim

> Yes, registering a simulator (so that future Xschems see the "new" simulator
> instance) is something that can make it to disk right away as soon as done.
> But, registering a simulator is not part of the simulator state that
> accompanies a test-bench cell in the library manager.
>
> *Whether* the "new" simulator just registered gets assigned as "the one to
> use" is an option that is part of the ASE-L state. If changed, that results in
> dirtiness. User must explicitly save and, if user initiates an Xschem
> shutdown, then she must get a warning and a prompt to save.

## What is true today (measured, 2026-09-08, before this batch)

* `ase::sim_register` (`src/ase.tcl:1300`) writes NOTHING to disk. Two
  registrations typed into the Command window (CIW) leave no conf file at all.
  The dialog persists only because `ase::ui::simdlg_commit`
  (`src/ase_window.tcl:4649`) calls `ase::sim_write_conf` after every gesture.
* The choice in force is the process-global `ase::sim_use` (`src/ase.tcl:711`).
  It is NOT in the ASE-L state, so changing it does not dirty a session, does
  not require a save, and does not prompt on quit.
* `ase::sim_write_body` (`:3157`) writes an `ase::sim_select <name>` line, so a
  choice gesture DOES reach disk — the exact thing the ruling forbids.
* The state's `simulator` key is the BACKEND name (`ngspice`), not the registry
  entry. It is real state and already dirties. Do not confuse the two.
* `src/xschem.tcl:4935` promises persistence unconditionally: *"The saved list
  is ~/.xschem/ase_simulators and it comes back at the next start."*
* `src/ase_window.tcl:288` (issue 1370) already names the CIW as a real door and
  records that the user's own `ngspice-ver50` entry was created through it. 1370
  fixed the DISPLAY half of that door and not the PERSISTENCE half.

## The design

**`ase::sim_default`** — NEW process-global beside `sim_use`. The installation
default: what a session that expresses no choice of its own runs. Set by
`sim_load_conf`'s `ase::sim_select` line, by the rc seed, and by the
first-registration auto-select. It is ENVIRONMENT. `sim_write_body` writes THIS,
never `sim_use`.

**`ase::sim_use`** — unchanged meaning ("what is in force right now"), but it is
now a CACHE of the active session's choice, not a store of record. Every
`ase::sim_status` caller keeps working untouched.

**`sim_entry`** — NEW ASE-L state key, the store of record for the choice.
Added to `schema_keys` AND to `omit_if_empty` (`src/ase.tcl:44`/`:66`), because
104 committed `.state` files must stay byte-identical — that rule is already
written down there for `cosim` and `save_op_params`; read it before touching the
list. Three values:

| value | meaning |
|---|---|
| absent or `{}` | this state makes no choice; use `ase::sim_default` |
| `none` | deliberately the program on the PATH |
| `{name <entry>}` | that registry entry |

The two-word form exists so no registry name has to be reserved. A reader that
meets a bare one-word value which is not `none` takes it as an entry name (a
hand-written file is forgiving); `{name none}` is how an entry actually called
`none` is spelled.

**Persistence moves from the gesture to the mutation.** `sim_register` and
`sim_unregister` call the writer themselves, gated on `sim_origin eq session`.
`ase::sim_clear` does NOT — it is teardown ("forget every registered simulator
and every choice"), and autosaving there would let a test or a script blank the
user's list. Write that rule into the comment: *a mutation that expresses a
user's choice persists; a teardown does not.*

## Landmines

1. **`sim_load_conf` sources the file**, so every line in it is a real
   `sim_register` call. Without the `sim_origin` gate the reader rewrites the
   file it is reading. The signal already exists and is already maintained:
   `session` (default), `conf` (`:3220`-`:3222`), `rc` (`:3252`-`:3269`).
2. **Byte-identity.** 104 committed `.state` files and the load->save
   round-trip rows (F3/G3/R4/V4/R2 named at `src/ase.tcl:66`). A new key that is
   not in `omit_if_empty`, or whose default is not `{}`, reds all of them.
3. **`~/.xschem/` IS THE USER'S OWN.** Never write, move, back up or
   read-modify-write anything under it. Redirect `::USER_CONF_DIR` to a
   scratch directory for every measurement. Reading is fine.
4. **`sim_write_conf` already has three defences** — target resolved first
   (1286), temp written BESIDE the real file and never truncating it (0937),
   `CREAT|EXCL` on the temp against a symlink (1378). Do not restructure it.
5. **No sentence is minted in `src/ase_window.tcl`.** Ruling D5-4: every
   user-facing simulator sentence comes from `ase::sim_why` and is only
   RENDERED in the GUI file. Row R9 of `test_ase_simreg_0931.tcl` greps the GUI
   file for minted phrases and reds if one appears.
6. **UI copy is terse; acronyms UPPERCASE** (PATH, CIW, ASE-L, SPICE).
7. **Always give the xschem binary a path** — `./src/xschem`, never a bare
   `xschem`. **Every launch carries `--nolog`.** Route GUI work through
   `tests/headless/devdisplay.sh exec` or `run_suites.sh`.
8. **Floors are raised when rows are added and never lowered.**

## Known limitation to RECORD, not to fix here

Two ASE-L windows open on different test benches still share one `ase::sim_use`.
The run path applying the running session's `sim_entry` (item 8) makes "the
window you clicked in wins", which is correct for the run; a bar or dialog in
the other window may momentarily name the other choice. Record it in
DECISIONS.md and as an `owed.sh add rule` entry. Do NOT widen the batch into
per-window registries.

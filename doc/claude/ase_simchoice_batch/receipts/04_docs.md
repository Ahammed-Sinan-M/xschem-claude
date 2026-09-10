# Crew D receipt — documentation (items D1, D2, D3)

Date 2026-09-08. Branch `fluid-editing`. Nothing under `~/.xschem/` was
written, moved, backed up or read-modify-written. No commit, no
`checkout --` / `restore` / `stash` / `clean`. `src/ase.tcl` and
`src/ase_window.tcl` were READ only — crews A and B own them.

## D1 — issue 1395 filed

**File** `doc/claude/issues/1395-registration-persists-through-one-door-and-the-choice-through-one-too-many.md`
(173 lines).

**Number confirmed free before minting**, two ways:

* `tail doc/claude/issues/NUMBERING.md` → `**The next free number is 1395.**`
* `ls doc/claude/issues/ | grep 139` → `1390` `1391` `1392` `1393` `1394` and
  `0139` only. No `1395`.

**NUMBERING.md** — one `-` entry for 1395 appended in the established style
(the same shape as the 1390–1394 entries: bold title, the batch it came from,
the mechanism with file:line, the fix, the debts), and the trailing line
changed:

```
-**The next free number is 1395.**
+**The next free number is 1396.**
```

**House style matched from** `1390-*.md` and `1391-*.md` (the two same-shape
"filed as an item of a batch" files): `**Filed** / **Status** / **Files**`
header, numbered `## n.` sections, the user's verbatim words first, `⚠` for the
traps. `1393`/`1394` spell their status `STATUS: **OPEN — …**` because neither
is being fixed; 1390/1391 spell theirs `**Status** FIXED.` Neither spelling fits
a file written *before* its own fix lands, so 1395 reads
`**Status** OPEN — **being fixed by this batch**, items A … and B …`, and says
in as many words that every measurement in it is of the pre-fix tree and that
whoever closes it flips the line.

### What the file records

* **Half one** — `ase::sim_register` (`src/ase.tcl:1300`) and `sim_unregister`
  (`:1459`) write nothing; persistence lives on the gesture in
  `ase::ui::simdlg_commit` (`src/ase_window.tcl:4649`). Verified independently
  of the brief: `grep -n sim_write_conf src/*.tcl` returns exactly ONE
  production call site, `ase_window.tcl:4650`. The two pieces of the tree that
  had already ruled this a defect are quoted — `src/xschem.tcl:4935-4936`'s
  unconditional promise, and issue 1370's comment at
  `src/ase_window.tcl:288` naming the CIW a real door and recording that the
  user's own `ngspice-ver50` was created through it.
* **Half two** — the choice is the process-global `ase::sim_use`
  (`src/ase.tcl:711`), in no `schema_keys` entry, so it cannot move
  `ase::session_dirty` (`:8996`, literally a `state_serialize` comparison); and
  `sim_write_body` (`:3157`) writes `ase::sim_select` at `:3200`/`:3203`
  anyway.
* **The `simulator`-vs-registry-entry table**, so nobody reads the sentence
  "which simulator" one level too high.
* **The fix** (5 bullets) with the three-value `sim_entry` table.
* **The carried limitation** (§6) and the debts (§7).

### Re-measured here, 2026-09-08

Not copied from the brief. `::USER_CONF_DIR` redirected to the session
scratchpad; `./src/xschem --nogui --pipe -q --nolog --script <probe>`:

```
P1_conf_after_two_registers_exists=0     two ase::sim_register calls, no file at all
P2_in_force=aa                           the first registration auto-selected itself
P3_conf_after_select_exists=0            a choice gesture writes nothing either
P4_conf_after_writer_exists=1            ase::sim_write_conf, called by hand
P5_select_line=ase::sim_select bb        ...and it wrote the choice down
```

P1/P3 are half one; P5 is half two; P2 is the auto-select the new
`ase::sim_default` has to take over.

The dirty half is cited from the brief's measurement (`session_dirty` 0 before
and after, `prompt_all_on_quit` 1 with `ask_save_close` stubbed) and backed in
the file by the structural reading of `session_dirty`, which needs no run: a
value in no schema key cannot move a comparison of two `state_serialize`
outputs.

## D2 — the help text

`src/xschem.tcl`, the `WHICH PROGRAM RUNS, AND HOW IT TREATS UPPER CASE` block
of the Configure-simulators Help. Only the last sentence of that paragraph was
touched; the surrounding block is unchanged, and no test greps the old string
(`grep -rn "comes back at the next start" tests/` → nothing).

The paragraph now reads, lines 4932–4939 (widths 71/70/74/53/71/66/68/42, in
range with the 60–74 of its neighbours):

```
This window does NOT choose the simulator program. That lives in ASE-L,
under Setup > Simulators..., where each entry carries the program, its
extra arguments, the case mode it asks for (fold / preserve / distinguish)
and whether to pass --no-spiceinit. The saved list is
~/.xschem/ase_simulators: it holds every simulator you have registered,
from the dialog or from the CIW, and comes back at the next start.
Which one a test bench runs is not in that list. That is part of the
ASE-L state and is saved with the session.
```

Four lines unchanged, two rewritten, two new. Acronyms UPPERCASE (ASE-L, CIW);
no acronym spelled out in lower case anywhere in the block. `viewdata`'s braced
argument still balances (nothing added contains `{`, `}`, `$` or `[`), and
`./src/xschem --nogui --pipe -q --nolog --script` still sources `xschem.tcl`
and reaches the script — verified.

## D3 — the spec

`doc/claude/specs/ase_l.md`, three edits.

1. **State file schema (v1)** — `sim_entry {}` added to the example block,
   immediately after `simulator`, with a bullet carrying the three-value table,
   the `omit_if_empty` reason (the 104 committed `.state` files) and the
   `simulator`-is-the-backend distinction.
2. **The 0932 bullet amended in place** rather than rewritten: the
   `ase::sim_select` line the saved list carries now records
   `ase::sim_default`, never a session's own choice. The property 0932 defended
   (a cleared choice is a line, not the absence of one) is stated as unchanged.
3. **New section `### The registry is environment; the choice is state (issue
   1395)`**, placed between the 0931 and 0948 sections — the ruling in one
   paragraph, a four-row environment/state table (what / lives in / when
   written / dirties), the three consequences (persistence on the mutation not
   the gesture and gated on `sim_origin`; `sim_clear` excluded because teardown
   is not a choice; `sim_use` demoted to a cache), and the known two-window
   limitation.

⚠ **ONE THING FOR CREW A TO MATCH.** The spec places `sim_entry` **immediately
after `simulator`** in the key order, and says so ("ordering here follows
`ase::schema_keys`"). Crew A should insert it in the SAME slot, i.e.
`{version simulator sim_entry design rundir …}`. The slot is free to choose —
`omit_if_empty` means no committed state file carries the key, so position
cannot move a golden — but the two must agree, and the brief's own pointer
(`src/ase.tcl:44`, the first line of the `schema_keys` literal) reads the same
way. If crew A lands it elsewhere, one line of the spec needs the same move.

✔ **Cross-checked against crew A's in-flight `src/ase.tcl` (read-only, 22:5x).**
`ase::sim_default` is in place at `:747` and the encoding comment above
`ase::sim_choice_decode` spells the three values `{}` / `none` /
`{name <entry>}` — identical to the table this crew wrote into the spec and
into issue 1395, so the two do not have to be reconciled later. The spec bullet
now also names `ase::sim_choice_decode` as the one decoder for both stores.
`schema_keys` had NOT yet gained `sim_entry` at the time of this read, which is
why the slot note above still stands as a request rather than a confirmation.

## Debts recorded

* **rule 1395** — `owed.sh add rule 1395`, recorded (`owed: recorded rule
  debt: 1395`): the two-window `ase::sim_use` limitation, with the judgement
  stated and a pointer to §6 of the issue for the option set. Not converted
  from or into any other debt kind.
* No `look` debt: this item shipped one help paragraph, and the pixel question
  for it belongs to whichever crew ships the dialog copy, not here.
* No `suite` debt: crew D touched no GUI code.

## Files changed by crew D

```
doc/claude/issues/1395-registration-persists-through-one-door-and-the-choice-through-one-too-many.md   (new)
doc/claude/issues/NUMBERING.md                                                                        (1395 entry + next-free 1396)
doc/claude/specs/ase_l.md                                                                             (3 edits)
src/xschem.tcl                                                                                        (help paragraph, 4932-4939)
doc/claude/ase_simchoice_batch/receipts/04_docs.md                                                    (this file)
```

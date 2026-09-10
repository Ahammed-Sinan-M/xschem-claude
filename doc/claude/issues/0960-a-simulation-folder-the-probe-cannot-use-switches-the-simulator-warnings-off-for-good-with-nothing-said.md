# 0960 — a simulation folder the probe cannot use switches the simulator warnings off for good, and says nothing

**STATUS: FIXED**, 2026-09-07, by the ASE-L registry-loose-ends batch, on branch
`fluid-editing`. **Fix shape 1 only** — `noplace` was given its own sentences;
the fallback of shapes 2 and 3 was NOT taken and is on the user's queue as rule
debt `0960` (`tests/headless/owed.sh show`), together with the wording.

**⚠ THERE WERE TWO REPAIR ROUNDS, NOT ONE.** The second is "The close-out
round" below, and it exists because the first repair shipped a REGRESSION and a
false invariant that was copied into six places. Read that section before
trusting any sentence in this file about `file writable`.

**⚠ THE FIRST LANDING WAS REFUTED AND REPAIRED THE SAME DAY, and the refutation
is part of this record because it was this issue's own defect coming back.**
What shipped first said in three places — this file, the batch summary and the
rule debt — that `ase::sim_why cap_noplace` mints **two** sentences. It mints
**three**. The third, the `default` catch-all, shipped with **no acceptance row
on it at all**, so it could regress to silence with the suite green; and it was
wrong in what it said. See "The repair round" below.

**What shipped.** `ase::cap_workdir` records WHAT was in the way at the moment
it finds out (`ase::cap_noplace_at`: `occupied` / `readonly` / `other`),
`ase::sim_capabilities_at` carries that in the answer as `noplace_why` and
`noplace_at`, and `ase::cap_report` says one of THREE sentences minted in
`ase::sim_why cap_noplace` — the folder or the file is named, never the
program. **Once per place AND per reason** (`ase::cap_noplace_once`, keyed on
`{at why}`), because nothing about the state clears itself, so a sentence per
Run is a sentence per Run for the rest of the session; `ase::sim_caps_clear`
forgets it along with every measured answer, so a folder the user has just
fixed or just broken is reported again. **The folder test runs first, and since
the close-out round it works by TRYING** (`ase::cap_dir_takes_entry` makes an
entry and removes it): only a folder that refuses a new entry AND holds
something at that name answers both, and there "delete or rename that file" is
a fix the user cannot carry out.

Acceptance rows: **N1–N16** of `tests/headless/test_ase_simcaps_0948.tcl`. N1–N8
landed with the first fix, all eight red before it. **N9–N13 are the repair
round**, all five red on the tree the repair found. **N14 and N15 are the
close-out round**, both red on the tree it found; **N16 was never red and says
so** — see below. Row **J8** of the same file,
which used to require that a read-only simulation folder produced NO sentence at
all, was the row that pinned this defect; it now requires the one sentence about
the folder and still forbids the one about the program.

## The repair round (2026-09-07)

Three defects in the first landing, all three measured live through
`ase::sim_capabilities` + `ase::cap_report` on the built binary before anything
was changed.

**1. The catch-all is REACHABLE with ordinary filesystem shapes**, and both of
these were driven live:

* a **dangling symbolic link** at `.ase_probe` — precisely the crashed-run
  leftover this issue is about. `file exists` follows the link and answers 0, so
  `cap_noplace_at`'s `occupied` test cannot see it, and `file mkdir` fails with
  EEXIST. Measured: `caps = {known 0 unmeasured noplace noplace_why other
  noplace_at <folder>}`, `rv = cap_noplace`.
* a **`.ase_probe` directory with no write permission** — it exists and it is a
  directory, so the parent `mkdir` succeeds and all 64 attempts to make a place
  inside it fail. Same answer.

**2. Its sentence was wrong by construction — and the reason given here was
itself wrong; see "The close-out round" below.** What was claimed was that
`ase::cap_noplace_at` tests "not writable" FIRST, so the catch-all is only ever
reached when the simulation folder IS writable. **That inference does not
hold**: the test was `file writable`, which on a directory is POSIX
`access(W_OK)` and ignores the search bit. The sentence that shipped first was
nevertheless wrong for the shapes it was written for, and it said:

> `<folder>` is your simulation folder, and no place to write a test result
> could be made in it. Check that you can write into it.

It names the folder — the one thing in that state that is fine — and tells the
user to check a fact the code has already established. It now names the probe
place and gives an instruction that can be carried out:

> `<folder>/.ase_probe` is where a test result has to go, and it could not be
> made or used. Your simulation folder itself can be written into, so delete
> `<folder>/.ase_probe` or make it writable.

`noplace_at` for `other` is now the probe place rather than the folder, for the
same reason.

**3. The once-per-place key FUSED two arms, which is this issue's own defect
surviving inside its fix.** `readonly` and the catch-all both answered with the
FOLDER, and `ase::cap_noplace_once` was keyed on the place alone. Measured, one
process, no registry edit and no `ase::sim_caps_clear`:

```
A3 step1 folder = <dir> writable=0
A3 step1 rv     = cap_noplace          ("nothing can be written into it")
A3 step2 folder = <dir> writable=1     (the user fixed it; .ase_probe unusable)
A3 step2 caps   = known 0 unmeasured noplace noplace_why other noplace_at <dir>
A3 step2 rv     =                      <-- SILENCE
A3 step2 said   =
```

The user fixes one thing, hits the second, and the second fact is silently
withheld. The key now carries the reason as well as the place.

**What the repair did NOT do.** It did not take fix shape 2 or 3 (the fallback);
that is still the open product call. It did not change the `occupied` or
`readonly` sentences. It did not touch `ase::cap_workdir`'s own logic.

**The third sentence's wording is the assistant's, not the user's**, and is on
the queue as rule debt `0960_catchall_sentence`.

## The close-out round (2026-09-07) — the repair above shipped a REGRESSION

**The invariant the repair round rested on is false**, and it was written into
six places: `src/ase.tcl` twice, `test_ase_simcaps_0948.tcl`, `ase_l.md` twice,
this file, and the rule debt the user is being asked to ratify.

`file writable` on a **directory** is POSIX `access(W_OK)`. It answers about the
write bit and says **nothing** about the SEARCH (`x`) bit, and a create needs
both. Measured, one `tclsh`, both modes:

```
mode 0600 : file writable = 1 | mkdir  -> permission denied
                                touch  -> permission denied  | .ase_probe does not exist
mode 0200 : file writable = 1 | mkdir  -> permission denied
                                touch  -> permission denied  | .ase_probe does not exist
```

So a simulation folder at mode 0600 — what `chmod -R 600 project/` leaves
behind, the reflex after a leaked secret — passed the read-only test and landed
in the **catch-all**. Driven live through `ase::sim_capabilities` +
`ase::cap_report` on the built binary, mode 0600:

```
noplace_why = other      noplace_at = <folder>/.ase_probe      rv = cap_noplace
said = "... <folder>/.ase_probe is where a test result has to go, and it could
        not be made or used. Your simulation folder itself can be written into,
        so delete <folder>/.ase_probe or make it writable."
```

**Both clauses are false**: nothing can be written into that folder, and there
is no `.ase_probe` to delete. **And it is a regression, not merely an uncovered
case** — before the repair the same fixture produced *"`<folder>` is your
simulation folder, and no place to write a test result could be made in it.
Check that you can write into it."*, which names the right object and whose
advice leads to the fix.

**What the close-out changed.**

* `ase::cap_dir_takes_entry` — a new proc that answers "will this folder take a
  new entry?" by **making one and removing it**. Four tries; a name something
  is already at is skipped, never deleted (issue 0951's mistake in miniature).
  `ase::cap_noplace_at`'s first test now calls it. Modes 0600 and 0200 land in
  the folder's own arm, `noplace_at` = the folder.
* **The folder arm's advice changed.** It said "nothing can be written into it.
  Make it writable, or choose another one" — exact for a `ro` mount, useless at
  mode 0600 where the write bit is already set. It now says: *"`<folder>` is
  your simulation folder, and nothing new can be made in it. Give it write and
  search permission, or pick another folder."*
* **The catch-all's sentence is unchanged in words** and now *earns* its claim:
  it is reached only after an entry really was made in the folder and removed.
* **Row N6 was extended from two arms to three.** It was named "each fixed piece
  of THE TWO SENTENCES" and looped `occupied` and `readonly` only. Measured:
  with a catch-all phrase duplicated into a second proc in `src/ase.tcl`, the
  two-arm row stayed **green** and the three-arm row went **red**, naming both
  duplicated phrases.

**Acceptance rows added: N14, N15, N16.** N14 (mode 0600) and N15 (mode 0200)
were **red** on the tree the close-out found, by name, both reporting
`noplace_why other` and the false "can be written into" clause. **N16 was NOT
red and could not have been** — it guards litter from a trial that did not exist
before; it is proved by sabotage instead (drop the delete: N16 reds by name,
N9 and N10 stay green).

**Not measured in this round:** any GUI/pixel path — no dialog was opened; the
`:0` arm was not run; a read-only *mount* and a full disk were not built as
fixtures (only permission shapes were); and no shape was driven against a real
`ngspice` (rows N14–N16 use the suite's `/bin/sh` stub, as N1–N13 do).

---

**Originally filed OPEN.** Found by item S3a's verification pass, reproduced first-hand by
the write-up before filing. It is the honest half of a fix that landed in the same
item — S3a stopped this state ACCUSING the user's program (issue 0949's category
error), and the price is that it now says nothing at all, permanently.

## What the user sees

Nothing. That is the defect.

Their simulation folder cannot be used by the probe — it is read-only (a shared
project area, a mount that came up `ro`), or something already occupies the name
the probe needs. From then on, every warning the 0948 capability feature exists to
give them is switched off. The genuinely useful one goes with it: a build that
**keeps only the last analysis of a run** will now silently throw away every
analysis but the last, on a run with several in it, and the sentence that would
have warned them is never minted.

There is no message, no degraded-mode notice, nothing in the Simulators window,
and nothing that would let them find out — on this Run or any Run for the rest of
the session.

## Measured

Both shapes, on the built `src/xschem`, with the real `/usr/local/bin/ngspice`
registered and selected. `caps` is what `ase::sim_capabilities` answered, `said`
is every sentence that reached the Command window:

```
read-only simulation folder:
  RO press 1 : caps={known 0 unmeasured noplace} kind='' said={}
  RO press 2 : caps={known 0 unmeasured noplace} kind='' said={}
  RO press 3 : caps={known 0 unmeasured noplace} kind='' said={}
  RO writable? 0

a writable folder in which .ase_probe is an ordinary FILE:
  BL press 1 : caps={known 0 unmeasured noplace} kind='' said={}
  BL press 2 : caps={known 0 unmeasured noplace} kind='' said={}
  BL press 3 : caps={known 0 unmeasured noplace} kind='' said={}
  BL writable? 1
```

The second shape is worth its own line: the folder is perfectly writable and the
user has done nothing wrong. One stray file — a leftover from a crashed run, a
`.ase_probe` that was a directory yesterday — disables the feature for good.

## Mechanism

`ase::sim_capabilities` returns `{known 0 unmeasured noplace}` when
`ase::cap_workdir` cannot hand back a place to work, and `ase::cap_report`'s first
arm speaks only for `unmeasured timeout`:

```tcl
if {![dict exists $c known] || [dict get $c known] == 0} {
  if {[dict exists $c unmeasured] && [dict get $c unmeasured] eq {timeout}} {
    ase::sim_say cap_no_answer $backend $path [dict get $c secs]
    return cap_no_answer
  }
  return {}
}
```

Silence there is deliberate and, for the other `known 0` reasons, right: a backend
with no probe, or a resolver that already refused and said why, has nothing to add.
`noplace` is different from all of those, because **something the user could fix is
in the way**, and only this code knows what it is.

Note the section's own contract, written two screens above, for the sibling arm:
"A program that produced NO results at all on the probe's tiny test circuit is
reported whatever the run looks like: **never a silent failure**."

## Fix shape, none of it chosen

1. **Give `noplace` its own sentence**, in the plain-English register the other
   three use, naming the folder and what is in the way — a read-only folder and an
   occupied name are different sentences, and the code already knows which it hit.
   Say it **once per folder**, not once per Run, or it becomes a nag.
2. **Fall back to a scratch place** the tree can always write into (`$::env(TMPDIR)`,
   the user's config dir) and measure there anyway. The measurement is about the
   *program*, not the folder, so nothing about it needs the user's simulation
   folder — this makes the state unreachable rather than merely audible. It changes
   where a probe writes, which S4 should be told about.
3. Both: fall back, and say so quietly the first time.

## Acceptance

* A user whose simulation folder cannot be used either still gets the warnings, or
  is told plainly why they have stopped — once, not on every Run.
* The "keeps only the last analysis" warning in particular is never silently
  switched off, because that one costs the user their results.

---

## DRIVER PASS, 2026-09-07 — a fourth arm, and the two sentences that had no row

The close-out round's adversary refuted its own round on two counts. The driver
took both rather than opening a fourth crew round, because each is small and
specific and another round of prose was the thing generating the findings.

### `notdir` — the arm the round almost shipped wrong

`ase::cap_dir_takes_entry`'s header said a `$dir` that is not a directory "is
not reachable" from `ase::cap_workdir`, reasoning that its base is
`set_netlist_dir 0`, "which creates the folder". **It is reachable.**
`set_netlist_dir` (`src/xschem.tcl`) creates the directory only
`if {![file exist $netlist_dir]}`, so a `::netlist_dir` that already exists **as
a regular file** is handed back verbatim.

What the user got, driven end to end on the built binary before the fix:

```
noplace_why = readonly   noplace_at = <...>/plainfile   isdirectory = 0
said        : "... /<...>/plainfile is your simulation folder, and nothing new
               can be made in it. Give it write and search permission, or pick
               another folder."
```

A regular file called "your simulation folder", with advice that cannot be
carried out on it — **the exact defect class this issue exists to remove,
shipped inside this issue's own fix.** `ase::cap_noplace_at` now answers
`notdir` before it asks whether the folder takes an entry, and the sentence is
*"<path> is a file, not a folder, and a folder is where the simulation has to
work. Point your simulation folder at a directory"*.

**Row N17**, red first on the tree as found — `{... readonly ...} ... 1 1 0`
against `{... notdir ...} ... 0 0 1`, i.e. it said "is your simulation folder"
and offered "search permission" about a regular file. `ALL PASS (109)` after.
Rows N5/N6 now take **four** arms apart, not three.

### N18 — the advice clause had no row and could regress green

The adversary reverted only the folder arm's advice to the old *"Make it
writable, or choose another one"* and the suite stayed **ALL PASS (108)**. N14
and N15 compare what was said against `ase::sim_why`'s own mint, so any wording
satisfies them. That old wording is the one **mode 0600 disproves** — `chmod u+w`
changes nothing there, the missing bit is SEARCH — and it is the sentence the
user is being asked to ratify on rule debt `0960`. **N18** greps the clause
itself; the same revert now reds it by name (`{0 0 1}` against `{1 1 0}`).

### Two false sentences in `ase::cap_dir_takes_entry`'s header, withdrawn

* *"its whole cost falls on a run that is about to say something to the user
  anyway"* — false from the second Run onward, because `ase::cap_noplace_once`
  silences repeats. Measured, three presses: `said=1 trials=1`, `said=0
  trials=1`, `said=0 trials=1`. The trial is now declared as a per-Run cost and
  judged acceptable in the open, rather than argued away.
* the unreachability claim above.

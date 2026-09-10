# 1238 — stock `proc simulate` lost its exe/casemode composer at the annotate merge

**Status:** OPEN (code repaired 2026-09-07, one user ruling outstanding). Filed
2026-09-01, at the `annotate` → `fluid-editing` merge. **The user ruled: OPTION 1
— re-teach `simulate` to read the registry.** The composer is in and has now been
refuted **twice** by adversary passes on the same day: each time the code's shape
stood and its *claims* did not. See "What was done", then "The repair round", then
"The close-out round" at the foot of this file, and
`doc/claude/specs/simulator_profiles.md` §18.6 / §18.6.1 / §18.6.2. It is not
closed because one of the changes is to stock behaviour and is a **product call**,
on the owed ledger as rule `1238`.

## What was lost

Issue **0506** taught `proc simulate` (`src/xschem.tcl`) — **stock xschem's own
Simulation menu, the button most users press** — to compose its command from the
simulator profile, via `sim_profile_compose_cmd`. Before that, it ran
`sim($tool,$def,cmd)` verbatim, so a user could register a case-capable ngspice,
set Case=preserve, press Test, read *"delivers fold preserve distinguish"*, press
Simulate, and get a different binary at `fold`.

At the merge the profile store was retired in favour of `annotate`'s simulator
registry (the user's ruling: two stores describing one machine can disagree with
themselves). `proc simulate` knows nothing about ASE-L, so the bridge went with
the store it read. **`simulate` runs the row's `cmd` verbatim again, as on
`main`.** The 0506 defect above is reachable once more.

**ASE-L's own run path lost nothing.** `ase::run_cmd` composes exe, args, `-n`
and `-D casemode=` from the registry entry, and `ase::run_precheck` still refuses
a `distinguish` request the binary cannot deliver.

## Why it was not just re-pointed in the merge

Three real questions, none of which a merge should answer by itself:

1. **Shape mismatch.** `sim()` is per-TOOL with N rows and a default radio; the
   registry is one in-force entry. Which registry entry composes a `vhdl` row?
2. **Stock xschem must still run** with `ase.tcl` sourced, nothing registered and
   no session anywhere — so the composer needs a "no answer" path that behaves
   exactly as today, which is most of the compatibility contract 0506 carried.
3. **The unplaceable-flags problem is unchanged and was the hard part.** Two
   shipped templates cannot take appended flags at all: row 0's first word is a
   VARIABLE (`{$terminal -e {ngspice -i "$N" -a || sh}}`) and row 4's is a
   wrapper (`mpirun`). 0506's first revision appended anyway and produced
   `xterm -e {ngspice ...} -D casemode=preserve` — flags for the TERMINAL, two
   levels out from the simulator.

## The tests that went with it

`tests/headless/test_sim_plain_run.tcl` kept its C-netlister half (CS218–CS221a,
re-pointed at the registry) and **retired CS200–CS217 plus CS221's simulate
half — eighteen checks, not migrated anywhere**. They are recoverable verbatim:

```sh
git show <merge commit>^:tests/headless/test_sim_plain_run.tcl
```

When the composer returns, so do they.

## The options

1. **Re-teach `simulate` to read the registry.** Ask `ase::sim_status ngspice`
   for the spice tool only, keep every other netlist type verbatim, and re-use
   0506's exe-plan (`sim_profile_cmd_exe_plan`, also recoverable from the merge
   parent) for the declined/unplaceable rules.
2. **Accept the loss** and say so in the docs: ASE-L is where a configured
   simulator runs, and stock Simulate is the "run exactly what I typed" path.
   This has a real argument behind it — 0506 was making the stock button do
   something the string in the box did not say.
3. **Delete the stock path's ambiguity instead**: make Simulate refuse when a
   simulator is registered whose exe differs from the row's first word, pointing
   at ASE-L. Loudest, smallest, and does not re-open the unplaceable question.

Not decidable from the code; it is a product call.

---

## What was done (2026-09-07)

**Option 1, per the user's ruling.** Ten procs in `src/xschem.tcl`, sitting beside
`sim_netlist_casemode` — the registry bridge that survived the merge — and three
lines of wiring in `proc simulate`:

```
sim_registry_row_asks  sim_registry_answer  sim_registry_exe  sim_registry_args
sim_registry_casemode  sim_run_flags        sim_cmd_exe_plan  sim_cmd_takes_flags
sim_compose_cmd        sim_compose_report
```

They are 0506's composer re-pointed at `ase::sim_status` /
`ase::sim_casemode_requested`. Every RULING of 0506 stands word for word; the
store changed, not the reasoning.

### The three questions this file said a merge should not answer by itself

1. **Shape mismatch — which registry entry composes a `vhdl` row?** None. The
   registry is asked only about a `spice` row that is not Xyce; `vhdl`, `verilog`,
   `tedax` and the viewer rows run verbatim and unremarked. **(⚠ "not Xyce" was
   implemented as a substring test over the whole command and was WRONG — see
   the repair round, hole 2.)** **A Xyce row is now
   also verbatim and unremarked, and this is the one answer that MOVED from 0506.**
   0506's tail test would DECLINE `Xyce "$N"` against a registered ngspice, and a
   decline is reported — which was right when an `exe` was typed onto that row,
   and is wrong against one global entry the user never pointed at it. It would
   put an error line on every press of Simulate for a Xyce user who registered an
   ngspice for ASE-L. Row `CS203b` pins the new answer; `CS203` keeps 0506's
   substance with a non-Xyce `mpirun` template.
2. **Stock xschem must still run.** It does, byte-identically **at the shipped
   `fold` floor** — and that qualifier was missing here, which is the repair
   round's hole 3. Two things make the `fold` case hold rather than merely be
   intended: the exe is taken ONLY from a
   `source registry` resolution (with nothing registered `ase::sim_status` still
   answers, about the `PATH` program, and composing from that makes every CLAIM
   false — measured: deleting that one line moves `CS204`, `CS212` and `CS215`),
   and every call into `ase::` is caught, so a tree with no ASE-L composes
   verbatim rather than failing to simulate. An entry whose program has gone
   (`ok 0`) yields no exe either (`CS204b`).
3. **The unplaceable-flags problem.** Unchanged, and unchanged deliberately.
   `$terminal -e {ngspice …}` and every wrapper are DECLINED, never appended to;
   `unplaceable` is reported at tag `error`. **(⚠ INCOMPLETE: a template whose
   FIRST word is the simulator was appended to even when it was a PIPELINE, where
   the flags reach the last stage. Repair round, hole 1.)** Rows `CS202`, `CS202b`, `CS203`,
   `CS210`, `CS211` and `CS215`. `CS202b` is new and is the only row that pins the
   *literal* test: `CS202` passes on the tail test alone, and it took a sabotage
   run to notice — `file tail {$SIMDIR/ngspice}` IS `ngspice`, so a variable first
   word whose tail matches would otherwise be applied to a SUBSTITUTED string
   where one word may have become several.

### The eighteen retired checks

`CS200`–`CS217` and `CS221`'s simulate half are all back, driving the new procs.
**One did not come back in its original form:** `CS203` asserted
`exe_status declined` for the shipped `mpirun … Xyce` row. That row now answers
`none` for the reason in (1) above; `CS203b` asserts the new answer explicitly so
the change cannot rot back, and `CS203` keeps the wrapper-decline substance with
`mpirun /opt/parallel/ngspice "$N"`. Two rows are new: `CS202b` (above) and
`CS222` (a registered `-args` this path cannot place is REPORTED, not swallowed).

`tests/headless/test_sim_plain_run.tcl`: **6 checks → 32, ALL PASS**. Twelve
sabotages each reddened a distinct row by name. (The repair round below takes it
to **47**, and the close-out round to **53** — both counted from a run,
2026-09-07. This line said "45" until the close-out round, disagreeing with the
two other places in this file that said 47.)

### Left open, on the owed ledger

* rule `1238_args_placement` — should the plain path CARRY the registry's `-args`,
  or keep reporting them as not placed?
* rule `1238_composer_sentences` — the three user-visible sentences the report
  mints.

`-n` / `--no-spiceinit` is NOT open: `doc/claude/specs/simulator_profiles.md`
§18.5 already rules it ASE-L-only, and this work honours that.

---

## The repair round (2026-09-07) — three holes an adversary found

The composer above was refuted the same day it landed. The refutation was not
about the composer's shape, which stands; it was that **two of its three answers
were true in the write-up and false in the code**, and a third change was never
declared. All three are repaired; the third needs a ruling.

Spec: `doc/claude/specs/simulator_profiles.md` **§18.6.1**, which carries the
measurement tables. `src/xschem.tcl` gained three procs —
`sim_cmd_program_words`, `sim_cmd_is_xyce_word`, `sim_cmd_trailing_reason` — and
the compose dict gained a `flag_reason` key.

### Hole 1 — a pipeline is not placeable, and the report said the opposite

`sim_cmd_takes_flags` returned 1 whenever the first word was the simulator.
`proc execute` does `open "|$args"`, so Tcl gives trailing words to the **last
stage**: on `ngspice -b "$N" | tee sim.log` the case flags went to `tee`, and the
CIW note read *"Case mode: appending -D casemode=preserve"* — telling the user it
had appended to the simulator while appending to a pipe. Three pipeline shapes
were measured doing exactly that, before the fix.

Repaired: `flag_status` `unplaceable` with `flag_reason` `pipeline`, and its own
sentence. A trailing `&` is covered too (`flag_reason` `background`) — measured:
appending after one stops the run being backgrounded **and** hands the simulator a
stray `&`. A GLUED `a|b` is deliberately NOT covered, because Tcl treats it as one
literal argument and the flags do reach the simulator.

> ⚠ **THIS REPAIR WAS INCOMPLETE ON TWO COUNTS AND THE CLOSE-OUT ROUND BELOW
> CARRIES BOTH.** (a) The test was taken on the RAW template, so a `|` arriving
> through `proc simulate`'s own `subst` reproduced this defect exactly, note and
> all. (b) The sentence that stood here — *"the rule is Tcl's rule, word for
> word"* — was false: the test split on whitespace with no quoting model, so a
> `|` inside quotes or braces answered `pipeline` and lost the case mode on a
> well-formed row.

**The row that a naive fix breaks, and what was done about it.** Two rows already
work today and a careless pipeline test takes one of them away:

* **shipped row 0**, `$terminal -e {ngspice -i "$N" -a || sh}`. Its `unplaceable`
  sentence is TRUE today — it names `$terminal`. A substring test for `|`
  evaluated before the first-word test relabels it `pipeline`, which is false
  (`||` is not a Tcl stage separator). MEASURED: that variant reddens `CS225` and
  `CS223c` by name. **Done about it:** the two reasons are ORDERED, first word
  first, and `CS225` pins the order.
  > ⚠ **`CS225` DOES NOT PIN THE ORDER.** That sabotage changed the trailing test
  > to a SUBSTRING *and* the order in one edit, so the red is attributable to the
  > substring change. Measured in the close-out round: swapping **only** the two
  > `elseif` arms left the suite ALL PASS at 47, not one row moved. `CS225b` is
  > the row that pins it.  
* **the exe substitution on a piped row.** Word 0 of a pipeline IS the first
  stage's program, so a registered exe is correctly applied there today. A fix
  that declined the whole template would silently remove it. **Done about it:**
  only the FLAGS are unplaceable; the exe plan is untouched, and `CS223d` pins
  it — sabotaging the plan to decline pipelines reddens that row by name.

### Hole 2 — the Xyce gate was a substring test over the raw command

`sim_registry_row_asks` matched `[xX]yce` against the entire template. MEASURED:
`ngspice -b -r "/home/u/xyce/out.raw" "$N"` composed `exe_status none
flag_status none mode {}` — the user's registered case-capable ngspice silently
not applied, which is this issue's own defect reached through this issue's own
gate.

Repaired to read **program words**: the leading run of non-option words (word 0
plus what a wrapper hands on), stopping at the first option, matching on
`file tail` minus `.exe`.

**What the rule really is, since the headline justification is narrower than it
reads.** The gate buys silence for a **literally-spelled** xyce only. A Xyce row
written as a variable reference that does not end in the name —
`$XYCE_HOME/bin/simulator "$N"` — is **declined, not none**, so that user DOES get
an error line on every press of Simulate. `CS226d` pins that limit. The gate errs
toward asking on purpose: a row wrongly gated off loses the registered simulator
silently, a row wrongly gated on earns a truthful sentence. `mpirun -np 4
/opt/Xyce "$N"` is the known miss of the second kind.

⚠ **AND THERE IS A KNOWN MISS OF THE FIRST KIND — THE SILENT ONE — WHICH THIS
FILE AND `simulator_profiles.md` §18.6.1 BOTH USED TO DENY.** Both said "an
argument path can never gate a row off". It can, whenever it sits inside the
**leading non-option run**, because only an option boundary stops the scan.
MEASURED 2026-09-07 on the shipped procs, ngspice registered at
`-casemode preserve`:

| raw template | program words | `asks` | `exe_status` | `flag_status` |
|---|---|---|---|---|
| `ngspice /home/u/xyce` | `ngspice /home/u/xyce` | 0 | `none` | `none` |
| `ngspice "$N" /home/u/xyce` | `ngspice "$N" /home/u/xyce` | 0 | `none` | `none` |
| `ngspice -b -r "/home/u/xyce/out.raw" "$N"` | `ngspice` | 1 | `applied` | `appended` |

The first two lose the user's registered simulator **with nothing said** — this
issue's own defect, one notch narrower than `CS226`. **NOT FIXED and NOT
COVERED**: `CS226`/`CS226b`/`CS226e` are all option-preceded. Narrowing the scan
(stop at the first word that is not a known wrapper?) is a design call, so the
close-out round corrected the sentence and left the behaviour to the driver.

### Found while repairing, not one of the three — `file tail` raises on `~name`

MEASURED 2026-09-07, Tcl 8.6: `file tail ~nosuchuser` raises *user "nosuchuser"
doesn't exist* (a tilde followed by a path does not). `sim_compose_cmd` is called
from `proc simulate` with no catch, so that aborts Simulate with a Tcl error and
no run. The gate's new word scan widened the reach; `sim_cmd_exe_plan`'s word-0
`file tail` could already do it. All three `file tail` calls in the composer are
guarded now — `CS226f` (word 0, registered) and `CS226g` (nothing registered,
through `sim_cmd_takes_flags`), each red by name when its guard is removed.

### Hole 3 — an undisclosed behaviour change off the shipped floor — NEEDS A RULING

The compatibility contract was stated as "stock xschem composes byte-identically"
and is true **at the shipped `fold` floor** (`CS200`). Off it, it is not, and
nobody had said so. Nothing registered, global Case floor moved to `preserve`:

| shipped row | before 1238 | now |
|---|---|---|
| 0 `$terminal -e {ngspice …}` — **the DEFAULT row** | verbatim, silent | verbatim, **error line on every press of Simulate** |
| 1 `ngspice "$N" -a` | verbatim, silent | `-D casemode=preserve -D casemodewrite` appended, note |
| 2 `ngspice -b -r "$n.raw" "$N"` | verbatim, silent | appended, note |
| 3 `Xyce "$N"` | verbatim, silent | verbatim, silent |
| 4 `mpirun … Xyce "$N"` | verbatim, silent | verbatim, silent |

There is a real argument for it: the deck is already being WRITTEN in that mode
(`sim_netlist_casemode`, `save.c`'s `sim_case_mode_floor()`), so a run that does
not ask for the same mode produces results the netlist does not describe. There is
a real argument against: the user registered nothing, and the loudest row is the
shipped default. **It is a product call**, on the owed ledger as rule **`1238`**.
`CS227` pins the whole table, whichever way it is answered.

### The rows

New in `tests/headless/test_sim_plain_run.tcl`: `CS223`, `CS223b`, `CS223c`,
`CS223d`, `CS223e`, `CS224`, `CS225`, `CS226`, `CS226b`, `CS226c`, `CS226d`,
`CS226e`, `CS226f`, `CS226g`, `CS227` — **32 → 47, ALL PASS**. Eleven of the
fifteen were RED on the tree as found. `CS226c`, `CS226d` and `CS227` were GREEN
as found, on purpose: they pin behaviour the repair must PRESERVE (the shipped
Xyce rows) or DISCLOSE (the gate's limit, the moved floor) rather than change.
`CS226e` was added after a sabotage run showed the option-stop rule was pinned by
nothing. Twelve sabotage runs reddened every one of the fifteen by name, and no
row that existed before this repair changed name or status.

---

## The close-out round (2026-09-07) — the placement rule read the wrong string, and claimed a model it did not have

The repair round above was refuted by a second adversary pass the same day, on
three points. Again the composer's shape stood and its **claims** did not, and two
of the three claims were covering a live user-visible defect. Spec:
`doc/claude/specs/simulator_profiles.md` **§18.6.2**, which carries the
measurement tables. `src/xschem.tcl` gained one proc, `sim_cmd_run_words`, and
`sim_compose_cmd` now takes the trailing decision on the substituted command.

### F1 — hole 1 was still open, on the substituted command

`proc simulate` calls `sim_compose_cmd $tool $sim($tool,$def,cmd) $cmd`, where
`$cmd` is the template after `subst -nobackslashes`. The repair round decided the
pipeline question on the **raw** template, so a `|` that arrives **through the
subst** was invisible to the test and perfectly visible to `open "|$args"`.

**MEASURED 2026-09-07 against the shipped procs**, registry = `ngspice` at
`-casemode preserve`:

```
raw = ngspice -b -r "$n.raw" "$N" $env(NGPOST)
sub = ngspice -b -r /tmp/x.raw /tmp/x.spice | tee sim.log
  flag_status = appended    exe_status = applied
  cmd = /usr/bin/ngspice -b -r /tmp/x.raw /tmp/x.spice | tee sim.log \
        -D casemode=preserve -D casemodewrite
  REPORT note: Case mode: appending -D casemode=preserve -D casemodewrite
```

Byte for byte the defect hole 1 claimed to close, with the same false note —
flags on `tee`'s argv while the CIW says they went to the simulator. `$env(…)`,
`$terminal` and a `$::name` all resolve in `proc simulate`'s scope, so the route
is an ordinary user's `cmd` string.

**Repaired:** the trailing test reads the **composed, substituted** command — the
exact string `eval execute $st $cmd` hands to `open`. Rows `CS228` (placement)
and `CS228b` (the sentence); both RED on the tree as found, with exactly the
output above.

**And the code now says why the two decisions read different strings**, which was
explained three times for the EXE decision and never once for the PLACEMENT one:
the exe plan must read the RAW template (it is the only string in which
`$terminal` is distinguishable from what it expands to, and `CS202b`'s
`$SIMDIR/ngspice` has a matching tail once substituted); the trailing test must
read the substituted one (`open "|$args"` sees only that).

It is **not** a strict superset, and a first draft of this write-up said it was.
A `$var` cannot delete a `|` already in the template, but a command substitution
can — MEASURED 2026-09-07, Tcl 8.6:
`subst -nobackslashes {ngspice -b [lindex {a | b} 0]}` → `ngspice -b a`. The raw
test calls that a pipeline; the command that runs has one stage, so the raw
answer was a false positive and losing it is the point. *Not measured: whether
any shipped or user row spells a `[...]` that way.*

### F2 — "the rule is Tcl's rule, word for word" was false, and it lost the case mode on a well-formed row

`sim_cmd_trailing_reason` split with `regexp -all -inline` over whitespace — no
quoting model — while `open "|$args"` splits with **Tcl list rules**. A quoted or
braced `|` is therefore not a stage separator.

**MEASURED 2026-09-07, Tcl 8.6, through `open "|$args"` with `args` collected
exactly as `proc execute` collects it:**

```
A one "a | b" -D casemode=preserve -D casemodewrite
  -> A_N=6  A_ARGV[2]=<a | b>  A_ARGV[3]=<-D>  A_ARGV[4]=<casemode=preserve>
A one {a | b} -D casemode=preserve -D casemodewrite   -> identical
A -b deck -c "run | wrdata out v(a)" -D casemode=preserve
  -> A_N=6  A_ARGV[4]=<run | wrdata out v(a)>  A_ARGV[5]=<-D>
```

The flags reach the simulator on all three; the old test answered `pipeline` on
all three, silently dropping the registered case mode and telling the user *"this
command is a pipeline, so trailing words go to its LAST stage"* about a
one-stage command. `-c "run | wrdata out"` is how an ngspice control line is
spelled — this is the mirror of the `a|b` case the repair round was careful about.

**Repaired:** `sim_cmd_run_words` parses with Tcl's own list rules and falls back
to the whitespace scan only for a string that is not a well-formed list — a string
that cannot reach `open` at all, because `eval execute $st $cmd` raises on it
first. Rows `CS229` (quoted), `CS229b` (braced) and `CS229c` (a quoted pipe **and** a
real one on the same line). `CS229` and `CS229b` were RED as found; `CS229c` was
GREEN as found, on purpose — `CS229`/`CS229b` alone are passed by any model that
gives up early, and `CS229c` is what reds when one does. *Not measured: whether a
model that strips quoted text and rescans the remainder is caught by `CS229c`;
the trailing `| tee` survives such a strip, so it probably is not.*

**Not changed, and said out loud:** `sim_cmd_program_words` (the Xyce gate's scan)
still splits on whitespace, because it reads the RAW template — which need not be
a well-formed list — and its subject is the leading program words, which quoting
does not group. *Not measured: whether any real row needs quoting there.*

### F3 — `CS225` did not pin the order it was named for

**MEASURED 2026-09-07:** swapping **only** the two `elseif` arms of
`sim_compose_cmd`, on the tree as it stood before this round and against the
suite as it stood (47 rows), left it **ALL PASS (47)** — not one row moved — while
changing a live user-visible answer:

| template | shipped order | arms swapped |
|---|---|---|
| `cat "$N" \| ngspice -b` | `flag_reason word` | `flag_reason pipeline` |

Shipped row 0 cannot see the order (`||` is not `|` at the word level) and row 0
was the only row the suite drove for this. The repair round's own sabotage
reddened `CS225` by changing the trailing test to a SUBSTRING **and** the order in
one edit, so the red was attributable to the substring change.

**The order matters on the merits**, which is why it needed a row rather than a
removal: on `cat "$N" | ngspice -b` the pipeline's last stage IS the simulator, so
the `pipeline` sentence would be false there while the `word` sentence is true.

**Repaired:** `CS225b` drives that template and moves on the order alone —
sabotage: swapping the two arms gives `1 FAILED (52 passed)`, `CS225b` and nothing
else. `CS225` was **renamed** from
`CS225-the-first-word-reason-outranks-the-pipeline-reason` to
`CS225-row0-is-a-first-word-refusal-not-a-pipeline-one`, because its old name was
a claim it could not test; it keeps pinning row 0's answer.

### F4 — bookkeeping

* "(The repair round below takes it to 45.)" contradicted the two other places in
  this file that said 47. Measured: **47** before this round, **53** after, no
  duplicate names.
* `CS227`'s in-file comment cited a ledger id that was never filed,
  `1238_floor_only_append`. The debt is **`1238`**; `owed.sh list` carries `1238`,
  `1238_args_placement` and `1238_composer_sentences` and nothing else under this
  issue. Corrected in the comment.

### The rows

New in `tests/headless/test_sim_plain_run.tcl`: `CS225b`, `CS228`, `CS228b`,
`CS229`, `CS229b`, `CS229c` — **47 → 53, ALL PASS**. Four of the six were RED on
the tree as found (`CS228`, `CS228b`, `CS229`, `CS229b`); `CS225b` and `CS229c`
were GREEN as found, and each has its own sabotage. Four sabotage runs, each
restored by `cp` with the md5 verified:

| sabotage | reds, by name |
|---|---|
| trailing test back on `$rawcmd` | `CS228`, `CS228b` (2 FAILED / 51 passed) |
| `sim_cmd_run_words` back to the whitespace scan | `CS229`, `CS229b` (2 FAILED / 51 passed) |
| a quoting model that STOPS at the first grouped word | `CS229c`, and `CS223c` collaterally (2 FAILED / 51 passed) |
| the two `elseif` arms swapped | `CS225b` alone (1 FAILED / 52 passed) |

One row that existed before this round changed **name**: `CS225`, deliberately,
for the reason in F3. No row changed **status**.

---

## DRIVER PASS, 2026-09-07 — the `word` sentence was false too

The close-out round fixed the `pipeline` sentence and left a claim beside it
that its own adversary then measured false. On `cat "$N" | ngspice -b` the
comment said the `pipeline` sentence "would be FALSE there while the `word`
sentence is true". Only the first half holds.

The `word` sentence said **"there is nowhere to put -D casemode= where the
simulator would see it"**. On that shape the simulator is the pipeline's LAST
stage, so trailing words *do* reach it — measured through the real
`open "|$args"` path with an argv-echoing stub: `cat deck | A -b -D
casemode=preserve -D casemodewrite` gives `A` four extra argv words. **Both
sentences were false, and the arm order merely chose which falsehood shipped.**

The sentence now says what is actually so, and is true on every shape that
reaches the arm:

> Case mode 'preserve' requested, but this command starts with 'cat', not the
> simulator, so xschem cannot tell where -D casemode= belongs. …

**That a last-stage simulator COULD take the flags is left unfixed on purpose.**
It is a behaviour change — it would make a shape that is declined today
placeable — and it belongs in its own commit with its own measurement, not in a
wording repair.

**Row CS225c** pins it. It exists because **nothing moved when the wording
changed**: the suite was ALL PASS across the edit, so a user-facing sentence was
regressible in silence, the same gap the 0960 pass found on its own advice
clause. Putting the old sentence back now reds CS225c by name
(`nowhere=<1> cannot=<0>`). `test_sim_plain_run` is `ALL PASS (54)`.

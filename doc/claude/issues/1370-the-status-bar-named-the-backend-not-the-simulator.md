# 1370 — the ASE-L status bar named the *backend*, not the simulator the user registered

**Status: FIXED, then REFUTED by an adversary, then REPAIRED.** Subject:
`ase::sim_label` (new) and `ase::run_using_report` (new) in `src/ase.tcl`;
`ase::ui::refresh_status` and `ase::ui::refresh_status_all` (new) in
`src/ase_window.tcl`; plus the four repairs in **the repair** section below —
a fourth term in `sim_label`, a name for the no-name case, a registry notify
seam (`ase::sim_notify`, new), and the run's say moved below the pre-flight
gate.

**Read the repair section before trusting any count or claim above it.** Four
defects and two stale numbers survived the first landing; every one of them is
recorded there, with what was fixed and what was rejected.

## The user's words, verbatim

> /tmp/Xschem.log.8 : which version of ngspice did the most recent run use? It's
> very confusing.. in ASE-L, to know if a change has had desired effect. In the
> ASE-L, in status bar, Simulator: \<name\> should show the correct name. If user
> has designated (registered) a new instance of ngspice named ngspice-ver50, and
> the "use this one:" field shows that, then the status bar in ASE-L should show
> that.

And the rule they gave for the hard cases, from the item brief:

> It must never silently print a name for a simulator that is not going to run —
> a false name is worse than the backend word.

## What was measured

`ase::ui::refresh_status` (`src/ase_window.tcl:6130`) rendered the segment as
`[ase::state_get $st simulator]` — the **state's backend word**, which is the
schema default `ngspice` written once in `ase::state_default`
(`src/ase.tcl:377`) and never touched by the registry. The segment therefore
carried **zero registry information**.

Driven on a live `.ase4` toplevel on the dev display, through the Simulators
dialog's own `simdlg_use` gesture, with the user's own `HOME` (so the
`ngspice-ver50` entry was live):

```
top = .ase4
STATUSBAR_AS_FOUND     = 4 | Status: Ready | T=27 C | Simulator: ngspice | State: ngspice_state1
selected               = ngspice-ver50
after 'none of mine'   = ''
STATUSBAR_AFTER_CLEAR  = 4 | Status: Ready | T=27 C | Simulator: ngspice | State: ngspice_state1
after re-select        = ngspice-ver50
STATUSBAR_AFTER_RESELECT = 4 | Status: Ready | T=27 C | Simulator: ngspice | State: ngspice_state1
```

Three different registry states, one byte-identical bar.

The information was already there and already correct — nothing on the bar's
path asked for it:

```
sim_status_ngspice = ok 1 exe /home/analog/dev/ngspice/build-ver_50/src/ngspice
                     resolved /home/analog/dev/ngspice/build-ver_50/src/ngspice
                     source registry entry ngspice-ver50 why {}
state_default_simulator = ngspice
statusbar_today         = Simulator: ngspice
```

**Two secondary defects fell out of the same measurement.**

*(a) There was no refresh.* None of `simdlg_use`, `simdlg_ok`, `simdlg_remove`
— nor `simdlg_fill`, the one proc all five gestures funnel through — called
`refresh_status`. So even a correct label would have gone stale the moment the
user changed "Use this one:" and stayed stale until `set_status running`, i.e.
until the run they were trying to predict actually started.

*(b) Nothing the user reads named the program.* Their own `/tmp/Xschem.log.8`:

```
build-ver_50     0
ngspice-ver50    0
ase:             16
simulator        14
```

Six completed runs, fourteen occurrences of the word "simulator", and **zero**
occurrences of the name they gave their build. The one place the path was
recorded is the ASE run log's `command :` line — one line under a
`simulator : ngspice` that contradicts it:

```
=== ase run tb_bandgap Sat Sep 05 23:58:34 MST 2026 ===
simulator : ngspice
command   : /home/analog/dev/ngspice/build-ver_50/src/ngspice -b ... 2>@1
```

The behavioural signature is in the same log: `ase::ui::simulators_dialog`
opened **seven times in one session**, because that dialog was the only surface
in the program that named the simulator.

## The history this overturns

This was not an oversight. Issue **0931**'s own problem statement (line 11)
names "the session window's bottom bar shows the backend name, never the
program that will actually be started" as part of the defect; 0931 shipped the
registry without touching the bar; and **0937** then wrote the exclusion down as
a decision (0937 issue file, line 180):

> **The bottom bar still reads `Simulator: ngspice`** — the backend name, never
> the program that will start. Deliberately out of this item's scope; the
> dialog's status line is the surface that names the program.

The user has overturned that rationale directly. 0937's bullet is amended in
place to say so, so the tree stops arguing with itself.

## What changed

### 1. `ase::sim_label {backend}` — one place decides what to call it

New, in `src/ase.tcl` beside `ase::sim_exe`, because ruling **D5-4** puts every
user-facing string about a simulator in `ase.tcl`, row **R9** of
`test_ase_simreg_0931.tcl` greps `ase_window.tcl` for minted phrases, and a pure
proc there is drivable `--nogui`.

* **WHO** is `[dict get $s entry]` — the registered name, which is exactly what
  "Use this one:" shows — falling back to the backend word when it is empty.
  Never `ase::sim_use`: in the ghost arm the resolver deliberately reports
  `entry {}` (pinned by row D2 of 0931's suite), and printing an unregistered
  name would be precisely the false name the user's rule forbids.
* **WILL IT RUN** is **four** terms (three as first landed — see the repair),
  and every one is load-bearing: `ok` **and** a non-empty `resolved` **and**
  the backend being one `ase::backend_names` knows **and**
  `ase::run_composes_registry` answering yes for it.

`ok` alone is *not* the discriminator, because the PATH arm never validates:

```
PATH_before = /usr/bin/ngspice
nothing_registered_normalPATH  ok=1 source=path resolved=/usr/bin/ngspice
PATH_after  =
nothing_registered_emptyPATH   ok=1 source=path resolved=''
run_profile_emptyPATH          ... status ok exe ngspice ...
```

and the membership term catches a generic entry answering for a backend this
program has no hooks for (`ase::backend_hook spectre run_cmd` raises
`ase: unknown simulator 'spectre'`) and the state with **no** `simulator` key at
all, where `ase::sim_status {}` cheerfully answers `entry ngspice-ver50` about a
state `ase::run_deck` refuses with "state has no simulator".

Every state, measured through the shipped proc:

| state | before | after |
|---|---|---|
| the user's bench (`ngspice-ver50` in force) | `Simulator: ngspice` | `Simulator: ngspice-ver50` |
| nothing registered, `ngspice` on PATH | `Simulator: ngspice` | `Simulator: ngspice` |
| registered, program deleted / not `+x` / a folder | `Simulator: ngspice` | `Simulator: <name> — will not run` |
| registered for another backend | `Simulator: ngspice` | `Simulator: <name> — will not run` |
| choice names an entry nobody registered | `Simulator: ngspice` | `Simulator: ngspice — will not run` |
| state backend `spectre` | `Simulator: spectre` | `Simulator: spectre — will not run` |
| generic entry, state backend `spectre` | `Simulator: spectre` | `Simulator: <name> — will not run` |
| state with no `simulator` key | `Simulator: ` (empty) | `Simulator: <name> — will not run` |
| nothing registered, nothing on PATH | `Simulator: ngspice` | `Simulator: ngspice — will not run` |

It never raises — same discipline as `ase::sim_named_path`, for the same reason:
this feeds a label redrawn on every session update.

### 2. The bar asks it, and every open bar follows a gesture

`ase::ui::refresh_status` renders `[ase::sim_label ...]`. New
`ase::ui::refresh_status_all` walks `wins`; it is called from the **last line of
`ase::ui::simdlg_fill`** — the one proc `simdlg_ok`, `simdlg_remove` and both
arms of `simdlg_use` all funnel through, so one insertion covers all five paths
**of the dialog** and none added later can miss it. Because it iterates `wins`,
it also closes the half of 0937's recorded "the registry is process-global while
the dialog is per-session" note that concerns the bar.

> ⚠ **This paragraph used to say "all five paths", full stop, and that was the
> overclaim the adversary broke.** The dialog is not the registry's only door:
> `ase::sim_register` / `ase::sim_select` typed into the Command window is the
> pre-0937 path and is how this user's own `ngspice-ver50` entry was first
> created. Covered now by the `ase::sim_notify` seam — see the repair.

### 3. The run says which one it started, and the run log records it

* New mint kind `run_using` in `ase::sim_why` — *"This run is starting the
  simulator you named `<name>`, and the program it is running is `<path>`."* It
  names **both** halves on purpose: the entry alone is what the user already
  knows, and the program alone is what `command :` already carried.
* New `ase::run_using_report {state}`, called from `ase::run_deck` inside a
  `ase::run_composes_registry` gate and caught there, exactly like its
  neighbour `ase::op_tier_report`. Silent when no entry is in force, so an
  ordinary installation's CIW is byte-identical to before. **As first landed
  the call sat at the TOP of `run_deck`, above `ase::preflight_gate`** — see
  the repair; it is now immediately below the line that composes the command
  and immediately above the launch.
* `ase::run_log_header` gains a `using :` field **beside** `simulator :`, never
  in place of it, and writes nothing when empty.

## Two decisions taken here rather than sent up

* **The naming line fires on every run**, not only when the choice changes. The
  user's question was "which version did the *most recent* run use", which is a
  per-run question, and it is one short line.
* **The run log gains a field rather than re-pointing one.** Row **E1e** of
  `tests/headless/test_ase_core.tcl` asserts the literal `ngspice` in the
  `simulator :` field, and that suite runs under the developer's own `HOME` — a
  re-pointed field would make a shipped suite's expectation depend on whose
  `~/.xschem/ase_simulators` is live.

## One correction to this item's own plan

The plan put the run-naming say in `ase::run_precheck`. It is in
`ase::run_deck` instead, because `run_precheck`'s **silence on a healthy resolve
is asserted on purpose**: row `CS187b` of
`tests/headless/test_sim_run_profile.tcl` pins `said=<0>` for an `ok` resolve and
its own comment calls itself *"the only thing asserting the precheck's
silence"*; `CS180b` pins the same. A say added there would have traded that
control away for a sentence that belongs to the run, not to the gate.

## Still open, and now visible

Issue **0944** is still OPEN: the Simulators dialog's Problem column is blank
for an entry registered for the wrong backend. The bar now marks that entry
`— will not run`, so **the bar is the more truthful of the two surfaces** until
0944 lands.

**And, after the repair, one thing that is still open and is the user's:**
the run's naming sentence is the only ASE line in the action log with **no
`ase: ` prefix** — `#= This run is starting the simulator you named …` sits
beside `#= ase: simulation finished (exit 0), …`. That is consistent with every
other sentence `ase::sim_say` renders (none of them carries the prefix; it
belongs to `ase::echo`'s error path and to raised refusals), so it was not
changed here. But the user's own diagnosis of `/tmp/Xschem.log.8` in the item
brief was done by **counting `ase:` occurrences**, and the one line added to
answer their question is the one line that count would miss. On their queue as
part of ruling 1370.

## The ruling that is the user's

The **wording of the not-going-to-run marker** is on the user's queue
(`owed.sh add rule 1370 … --eyes`). They settled the main case ("the status bar
in ASE-L should show that") and the principle for the bad cases ("never silently
print a name for a simulator that is not going to run"); what they have not
settled is the *form* of the marker, and it is a pixel decision on a
five-segment bar that no suite can settle. Shipped provisionally as (a).

* (a) `Simulator: ngspice-ver50 — will not run` — 28 chars against today's 7
* (b) `Simulator: ngspice-ver50 (unusable)` — shorter, less explicit
* (c) `Simulator: none` — safest against a false name, throws away the one word
  that would let the user fix it
* (d) the name plain, segment coloured red the way `.stat` already colours
  Running/Error — no extra width, but colour alone is weak in a grey bar and is
  invisible to a colour-blind reader
* (e) (a) or (b) plus (d)

**Two more words are theirs to settle, added by the repair:**

* **`(none)`** — what the segment says when there is nothing to name at all
  (nothing registered and no backend word either). Shipped as `(none) — will
  not run`, matching `ase::ui::simdlg_none_label`'s own spelling in the
  dialog's combobox. The alternative is to say the marker alone, which is what
  it did before and which is the `Z8` shape.
* **the `ase: ` prefix** on the run's naming sentence — see *Still open* above.
  This one is a greppability decision about the action log, not a pixel one.

**No suite retypes the marker.** Both suites lift it off one known-broken arm at
run time and pin it structurally — non-empty, written in `ase.tcl` exactly once,
never in `ase_window.tcl`. A re-wording under the ruling costs no test edits.

## The rows that fence it

`tests/headless/test_ase_simreg_0931.tcl`, section **L** (`--nogui`):

| row | what it fences |
|---|---|
| `L0` | the marker is real text, written once in `ase.tcl`, never in `ase_window.tcl` |
| `L1` | THE HEADLINE — the surface names the entry, not the backend word |
| `L2` | nothing registered: plain when the program is really there, marked when it is not (`ok` is not the discriminator) |
| `L3` | deleted / not `+x` / a folder — named **and** marked |
| `L4` | registered for another backend — named and marked |
| `L5` | the ghost — the backend word, and never the name nobody registered |
| `L6` | a backend with no machinery here — marked however healthy the entry |
| `L7` | it never raises |
| `L8` | STRUCTURAL — `run_using` is minted once, in `ase.tcl`, plain, and names both halves |
| `L9` | the run says it once, and says nothing on an ordinary installation |
| `L10` | the run log's `using :` line, and the empty case writing nothing |
| `L11` | the three log lines that used to contradict each other now agree |
| `L12` | **(repair)** a generic entry answering for a backend that starts its own binary is marked — the fourth term |
| `L13` | **(repair)** nothing to name at all still names the absence: `(none)`, never a marker with a double space |
| `L14` | **(repair)** the registry's *other* door tells every open bar, and a broken listener never costs the gesture |
| `L15` | **(repair)** a run the pre-flight refuses never said it was starting |

`tests/headless/test_ase_simdlg_0937.tcl`, rows **S20–S23** (dev display):

| row | what it fences |
|---|---|
| `S20` | the real bottom bar carries the name |
| `S21` | it follows a real "Use this one:" gesture with no session update behind it |
| `S22` | every open session window's bar follows a gesture made in one of them |
| `S23` | a gone program is still named and is marked, and the marker is not written in the window file |
| `S32` | **(repair)** a register+select from the Command window, with the dialog destroyed, moves **both** open windows' bars — and a removal stops both naming it |

Neither suite carries a check-count floor, so none was raised.

## Measured after the fix, on the user's own bench

`./src/xschem --nogui --pipe -q --logdir <scratch>`, the user's own `HOME`, so
the `ngspice-ver50` entry is live:

```
sim_selected           = ngspice-ver50
sim_label ngspice      = ngspice-ver50          <- the bar
run_using_report       = ngspice-ver50
said (tag note)        = This run is starting the simulator you named ngspice-ver50,
                         and the program it is running is
                         /home/analog/dev/ngspice/build-ver_50/src/ngspice.
run log header:
  === ase run tb_bandgap ... ===
  simulator : ngspice
  using     : ngspice-ver50
  command   : /home/analog/dev/ngspice/build-ver_50/src/ngspice -b ... 2>@1
```

The question they asked — *"which version of ngspice did the most recent run
use?"* — is now answered in three places, and the three agree.

## Non-vacuity — the RED sets, by name

**All sixteen new rows RED on the unmodified source**, with every pre-existing
row of both suites still green:

```
test_ase_simreg_0931  RESULT: 12 FAILED (67 passed)   RED: L0 L1 L2 L3 L4 L5 L6 L7 L8 L9 L10 L11
test_ase_simdlg_0937  RESULT:  4 FAILED (28 passed)   RED: S20 S21 S22 S23
```

(28, not 26: `S20a` and `S22a` are the fixture witnesses and pass on any tree —
they exist so a window that did not open is a visible absence.)

Then thirteen single-clause sabotages on top of the fix, each restored by `cp`
from a saved copy with the md5 compared:

| # | sabotage | suite | RED |
|---|---|---|---|
| SAB1 | the bar reverted to `[ase::state_get $st simulator]` | simdlg | `S20 S21 S22 S23` |
| SAB2 | drop the `resolved` clause from `sim_label` | simreg | `L2` |
| SAB3 | drop the `ok` clause | simreg | `L4 L5` |
| SAB4 | drop the `backend_names` clause | simreg | `L6` |
| SAB5 | delete the `refresh_status_all` call from `simdlg_fill` | simdlg | `S21 S22 S23` |
| SAB6 | name from `ase::sim_use` instead of the resolver's `entry` | simreg | `L5` |
| SAB7 | remove the `run_using_report` call from `run_deck` | simreg | `L9` |
| SAB8 | remove the `using :` line from `run_log_header` | simreg | `L10 L11` |
| SAB9 | drop the `catch` around `sim_status` in `sim_label` | simreg | `L7` |
| SAB10 | make the marker empty | simreg | `L0` |
| SAB11 | always fall back to the backend word (never the entry) | simreg | `L0 L1 L2 L3 L4 L5 L6` |
| SAB12 | write the `run_using` sentence in `ase_window.tcl` as well | simreg | `L8` |
| SAB13 | compose the run's sentence at the say-site instead of the mint | simreg | `L9` |

**Two things those numbers say that are worth writing down.**

*`L3` has no single-clause sabotage, and that is a fact about the resolver, not
a weak row.* A registered entry whose program is gone comes back `ok 0` **and**
`resolved {}` — the entry-kind arm sets both — so `ok` and `resolved` each catch
it alone. It is red under SAB11 and on the unmodified source; it is simply
double-covered.

*`SAB10` reds `L0` and nothing else, by design.* Every other row derives the
marker from `L0`'s own lift, so none of them can be reddened by a re-wording —
which is exactly the property the pending user ruling needs. `L0` is the single
row that pins the marker's existence.

## THE REPAIR — what the adversaries found, what was fixed, what was rejected

Three adversaries ran against the landed change. Two returned
`HOLDS_WITH_CAVEAT`, one returned `REFUTED`. **Six of their findings were
real and are fixed below; four were wrong or out of scope and are answered with
the measurement that settles them.** Every number in this section was taken
with an `md5sum` of `src/ase.tcl` and `src/ase_window.tcl` before **and** after
the run, because this checkout is shared and an unbracketed number from it is
not evidence (the adversary who found that had a sabotage silently reverted
under a live measurement; same class as issue **0990**).

### R1 — a run the pre-flight REFUSED said it was starting *(REFUTED, real, fixed)*

`ase::run_using_report` was called at the top of `ase::run_deck`, beside
`ase::run_precheck` — **eleven lines above `ase::preflight_gate` and above the
`open $netlistfile`**. Measured: a pre-flight refusal and a missing netlist file
both emitted

```
This run is starting the simulator you named ngspice-ver50, and the program it
is running is /home/analog/dev/ngspice/build-ver_50/src/ngspice.
REFUSED ... Nothing was generated: no deck, no raw, no log.
```

into the CIW **and the action log** — the one channel the user reads to answer
"which version did the most recent run use?", now carrying starts for runs that
never started. The cited precedent `ase::op_tier_report` is called *after* the
gate; the adversary was right and the placement was wrong.

**Fixed.** The call now sits immediately after `set cmd [$run_cmd $state
$deckpath]` and immediately above the run record — the last instant before the
launch, with the gate passed, the cosim models built, the deck written and the
argument list `execute` is about to be handed already composed. What can still
fail from there is `execute` returning `-1`, and that case writes the run log
this proc is about to write, so the sentence and the header agree about what was
attempted. Fenced by new row **L15**.

### R2 — `test_ase_optier_0963` rows Q6 and S11 were RED because of this item *(REFUTED, real, fixed)*

The first report declared that suite unmeasurable ("hangs at N3") and never saw
them. Reproduced on the unmodified tree, md5-bracketed:

```
FAIL: Q6  ... {tier {This run is starting the simulator you named optier, and the
                     program it is running is .../bin/sim_q_some5.}} ...   (6 hits)
FAIL: S11 ... got {3 {1 1 1}} (exp {2 {1 1}})
```

*Q6* scans every sentence a run says for words out of the code, and the ban list
carries `optier` and `tier`. The `run_using` sentence quotes **the registered
entry's own name**, and this bench registers its fixture as `optier` in a scratch
directory called `_optier0963_<pid>`. So the row was measuring that file's own
fixture naming, not the mint's wording.

*S11* derives its arity from the set of non-`op_tier*` kinds a run says and pins
it at two; `run_using` is a third. Its substantive assertion (each kind minted
exactly once) still held for all three — the row's *shape* was stale, not its
claim.

**Both are test-row repairs, and this file says so per rule 7.** Q6 now lifts
the user data — the registered names and the scratch path — out of each sentence
**before** the ban-word scan, exactly as row `L8` of `test_ase_simreg_0931.tcl`
already does with `a_plaintext $L8S $L8NAME $L8PATH`; the strip is exact-string,
so a code word outside a substitution is still caught. S11 drops a named list of
kinds other items mint into the same stream (`Q_OTHERITEMS {run_using}`); a kind
nobody listed still lands in the count and still reds the arity. Both were
proven still-toothed by sabotage — see the table.

**Measured, same suite, same row positions in the output:**

| | line 101 | line 116 | FAIL rows in the 85 reached |
|---|---|---|---|
| before | `FAIL: Q6` | `FAIL: S11` | 2 |
| after | `ok: Q6` | `ok: S11` | 0 |

### R3 — "the suite hangs at N3" *(REFUTED in part; the adversary is half right)*

They were **right** that Q6 and S11 are reachable well inside any normal
timeout: both print inside **40 seconds**, at output lines 101 and 116 of 123.
Nothing about those reds needs 900 s and the first report should have measured
them.

They were **wrong** that the hang does not happen. Reproduced **four times** on
this box — twice on the unmodified tree, twice after the repair — always at the
same place: the last row printed is `N3`, and the stall is inside `N4`'s
`catch {xschem load $N_BG}` on the bandgap bench. Measured while stalled:

```
xschem  0.0% CPU, State: S (sleeping), main thread wchan = futex_do_wait,
second thread in poll_schedule_timeout, no child processes,
fd 3 = the X socket, no window mapped on :99 beyond the 1x1 Info window
SIGTERM epilogue: "while editing: bandgap"
```

The adversary's own 420 s run got through it, so it is intermittent rather than
a certainty. **It is not this item's**: it is identical before and after, and it
is downstream of every row this item touches. Recorded, not fixed.

### R4 — the bar went stale on a registry change made outside the dialog *(CAVEAT, real, fixed)*

Measured live: with an ASE-L window open reading `Simulator: ngspice-ver50`,
typing `ase::sim_register ciwsim <path>; ase::sim_select ciwsim` — the pre-0937
Command-window path, and how this user's own entry was first created — left the
bar reading `ngspice-ver50` while `ase::sim_label ngspice` already answered
`ciwsim`. The bar was then naming a simulator that would **not** run, which is
the exact class the user's rule forbids, until the run itself healed it — the
moment the bar exists to predict.

**Fixed with a seam, not a call from the mutators into the window file.** New
`ase::sim_notify` (single slot, default `{}`) and `ase::sim_notify_fire`
(`catch {uplevel #0 ...}`), fired by all four mutators — `sim_register`,
`sim_unregister`, `sim_select` (both arms) and `sim_clear` — after the change
has landed. `ase_window.tcl` points it at `ase::ui::refresh_status_all` beside
where it already points `session_notify`. Same single-slot discipline, same
guard, and for the same reason: nothing in `ase.tcl` may depend on the window
file existing, and these mutators run once per line of the user's
`~/.xschem/ase_simulators` at startup — a raising GUI hook must never cost them
their simulator list. Fenced by new rows **L14** (headless: the fires, the
broken-hook control, the wiring) and **S32** (real pixels: two open windows,
the dialog destroyed first).

### R5 — a latent FALSE NAME the three-term test could not see *(CAVEAT, real, fixed)*

`ase::backend_names` answers `{ngspice}` today and ngspice is the one backend
that composes its command from the registry, so `known` and "composes from the
registry" coincided and nothing was wrong. Register a **second** backend with
its own hardcoded `run_cmd` (the shape `ase::run_composes_registry` exists to
detect; `test_ase_core`'s E2 backend is one) and a **generic** entry beside it
(`-backend {}`, which is exactly how this user's `ngspice-ver50` is registered),
and all three terms answer yes about a run that starts the *other* backend's
binary. Measured through the shipped proc:

```
ok = 1   resolved = <the stub, non-empty>   known = 1   composes = 0
label before the fourth term : gen-l12                <- a false name
label after                  : gen-l12 — will not run
```

The nine-row state table above gets its sibling case ("generic entry, state
backend `spectre`") right only because `spectre` has no hooks at all, which hid
this rather than closed it. **Fixed**: `ase::run_composes_registry $backend` is
the fourth `&&`. Fenced by new row **L12**, whose last four terms are the
witnesses that the first three all said yes.

### R6 — the marker printed with no name in front of it *(REFUTED as a nit, real, fixed)*

`ase::sim_label {}` on an installation with nothing registered rendered
`Simulator:  — will not run` — a marker with no name and a **double space**
where the name should be. Only reachable from a hand-written state file
(`ase::state_load` merges over `ase::state_default`) plus an empty registry, but
it is byte for byte the shape row `Z8` of `test_ase_optier_0963.tcl` exists to
forbid of a *sentence*, and the bar owes the user the same. **Fixed**: `who`
falls back once more, to `(none)` — the same spelling
`ase::ui::simdlg_none_label` already uses in the dialog's own combobox, so the
two surfaces name an absence the same way. Fenced by new row **L13**.

### R7 — the structural pins on L9 and L10 were over-tight *(CAVEAT, real, loosened)*

`L9` pinned the literal call text `catch {set using [ase::run_using_report
$state]}` and `L10` the literal `using $using`. Renaming the local variable, or
reflowing the catch across two lines, would have reddened both with zero change
to anything a user sees — and this repair *did* reflow that call. Both now match
the **shape**: `catch\s*\{\s*set\s+\w+\s+\[ase::run_using_report\s+\$\w+\]\s*\}`
and `\yusing\s+\$\w+`. Everything the rows are about is still pinned: SAB-H
(drop the `catch`) reds `L9` alone and SAB-I (drop the field from the run
record) reds `L10` alone.

### R8 — the stale suite counts *(CAVEAT, real, corrected)*

The acceptance paragraph said `test_ase_simdlg_0937` "26 -> 32". The file is
now **41** checks (26 base + 6 from this item + 8 that issue 1371 landed in the
same file afterwards + `S32` from this repair). `test_ase_simreg_0931`'s
"67 -> 79" was exact and is now **83**. Corrected in the suites section below.

### Rejected, with the measurement

* **"Give the run's sentence an `ase: ` prefix so `grep -c 'ase:'` finds it."**
  Not this item's, and not an accident: **no** sentence `ase::sim_say` renders
  carries that prefix — the prefix belongs to `ase::echo`'s error path and to
  raised refusals, not to the mint. Adding it to `run_using` alone would make
  one of thirty-odd mint sentences spell itself differently; adding it to all of
  them changes every sentence in this feature area and reds rows in four suites.
  The user's own diagnosis of `/tmp/Xschem.log.8` did count `ase:` occurrences,
  so the question is real — **recorded as a ruling for them**, not decided here.
* **"L2–L6 do not enforce the marker, they only lift it from L0."** True, and
  deliberate: it is what keeps the pending user ruling on the marker's *wording*
  free of test edits. It is not a false fence — the marker's existence is pinned
  by `L0` (simreg) **and** `S23` (simdlg), two rows in two suites, and SAB-J
  below reds both. Left as it is, documented here.
* **"`test_ase_simreg_0931` does not redirect `::netlist_dir`, so running it
  bumps mtimes under `~/.xschem`."** Real, pre-existing, and not this item's —
  it belongs to whoever owns that suite's fixture. Measured this session:
  `~/.xschem/ase_simulators` is byte-identical throughout
  (`17a24a6f06765158b8e4f2850993055e`, 330 bytes), `recent_files` untouched,
  `/tmp/Xschem.log.8` untouched, and the only movement under `~/.xschem` is the
  directory mtimes of `op_annot/` and `simulations/` — every file inside still
  dates Sep 5 or earlier, including the user's 69 MB `tb_bandgap_ase.raw`.
  Filed here so the next crew does not mistake it for data loss.

### The repair's own non-vacuity — RED sets by name

Every run below is bracketed by an `md5sum` of `src/ase.tcl` and
`src/ase_window.tcl` taken before **and** after, restored by `cp` from
`.../scratchpad/r1370/good/`, with the md5 verified equal to
`59dfb1e801a038689b45a4d963c7e29b` / `c6614fad165cf4034c7f498ebd160e51` after
every restore.

| # | sabotage | suite | RED |
|---|---|---|---|
| SAB-A | drop the fourth term (`&& $composes`) from `sim_label` | simreg | `L12` |
| SAB-B | drop the `(none)` fallback | simreg | `L13` |
| SAB-C | the four mutators stop firing `ase::sim_notify_fire` | simreg | `L14` |
| SAB-D | move the say back above `ase::preflight_gate` (the pre-repair position) | simreg | `L15` |
| SAB-E | the window stops subscribing to the seam | simdlg / simreg | `S32` / `L14` |
| SAB-F | a banned code word in the `run_using` mint, outside the substitutions | optier | `Q6` |
| SAB-G | the run says an **unlisted** kind (`in_force` in place of `run_using`) | optier | `S11` |
| SAB-H | drop the `catch` around the call | simreg | `L9` |
| SAB-I | drop `using` from the run record | simreg | `L10` |

`SAB-A` through `SAB-E` and `SAB-H`/`SAB-I` each reddened **exactly one row**
with `RESULT: 1 FAILED (82 passed)` and no collateral. `SAB-F` and `SAB-G` each
reddened exactly one row among the 85 the optier suite reaches before its
pre-existing `N4` stall — and together they are the proof that the two Q6/S11
repairs above did **not** neuter the rows they touched: the strip removes the
user's substitutions and nothing else, and the filter drops a named kind and
nothing else.

## Suites run, by name

Green and unchanged against their own pre-change baseline (all
`devdisplay.sh exec ./src/xschem --pipe -q --nolog`, Xvfb `:99`, openbox 3.6.1,
1920x1080x24):

`test_ase_simreg_0931` 67 -> 79 -> **83**, `test_ase_simdlg_0937` 26 -> 32 ->
40 (issue 1371's rows, same file) -> **41**,
`test_sim_run_profile` 37, `test_ase_simcaps_0948` 84, `test_ase_window` 228,
`test_ase_persist` 136, `test_ase_preflight` 114, `test_ase_result_case` 28,
`test_ase_savestate_adopt` 26, `test_ase_view` 36, `test_ase_plot` 150,
`test_op_param_store_1245` 130, `test_ase_sod_case` 52,
`test_ase_unnamed_net` 28, `test_ase_print_bracket_0167` 12,
`test_ase_launch` 44, `test_ase_dialogs` 176, `test_ase_final` 81,
`test_ase_cosim` 341, `test_op_annot` 492, `test_ase_bus_bits_0159` 39,
`test_ase_current_repair` 54, `test_ase_dirty` 41, `test_ase_final_gf180` 34,
`test_ase_hier_pick_0161` 21, `test_ase_hier_plot_0168` 31,
`test_ase_interact` 63, `test_ase_locked_wire_pick_0160` 16.

Three carried a pre-existing condition **identical before and after** — none of
them is this item's:

* `test_ase_core` — re-measured at the repair, both directions, with the whole
  repair reverted by `cp` and put back: **`7 FAILED (174 passed)` before and
  after, byte-identical red set `C5b C6 C6 C6 C6 C8 E1e`.** (The first landing
  reported 8; 7 is what this tree gives now.) `E1e` is red because the suite
  runs under the developer's own `HOME`, so the run command is the ver_50 path
  where the row expects a bare `ngspice`; the `simulator :` field it also
  asserts is still the literal `ngspice`, which is the whole reason `using :`
  was added beside it rather than in place of it.
* `test_op_dump_altshow` — `1 FAILED`, `H1 HYGIENE`, an `untitled*` left in the
  repo root by a concurrent worktree.
* `test_ase_optier_0963` — stalls inside row `N4`'s `catch {xschem load $N_BG}`
  (the last row PRINTED is `N3`), reproducibly, four times on this box, before
  and after the repair. **But it is measurable, and the first landing was wrong
  to treat it as unmeasurable**: 85 rows including `Q6` and `S11` print inside
  40 seconds. Zero FAIL among those 85 after the repair; two before it. See R2
  and R3.

`test_ase_log_seam_0207` — re-measured on its **documented `--logdir` arm**
(the gap the first landing admitted): `RESULT: ALL PASS (48 checks)`. Its
`--nolog` `19 FAILED` is that suite refusing an arm it says in its own header
is fatal, not a result.

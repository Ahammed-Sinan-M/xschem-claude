# 0961 — a simulator whose location is written `./name` cannot be measured once the probe changes folder, and the code comment says the opposite

**STATUS: FIXED**, 2026-09-07, by the ASE-L registry-loose-ends batch, on branch
`fluid-editing`. The fix landed in the first pass and is unchanged; the RECORD
of it was wrong and was rewritten in the repair round the same day.

**⚠ IT WAS NOT LATENT, AND THIS FILE SAID IT WAS — four times, in four
documents.** The first write-up asserted "THIS WAS AND STAYS LATENT", "this
never cost a user anything and still cannot", and "the broken branch is
reachable only by calling `ase::cap_run` directly, which nothing in the tree
does". The reachability claim is false and the route is ordinary. It is stated
exactly, with a measurement, in **"How it is reached"** below. Every sentence
of that claim has been removed from `src/ase.tcl`, from
`doc/claude/specs/ase_l.md`, from issue 0949 and from `NUMBERING.md`, and the
route is now a check (row **K5e**) rather than a sentence.

**What shipped.** One predicate and one comment in `ase::cap_run`
(`src/ase.tcl`). The carve-out is now "no separator in it at all" rather than
"`[file dirname]` is `{.}`":

```tcl
set sepd [expr {[string first / $prog] >= 0}]
if {!$sepd && $::tcl_platform(platform) eq {windows}} {
  set sepd [expr {[string first \\ $prog] >= 0}]
}
if {[file pathtype $prog] eq {relative} && $sepd} { set prog [file normalize $prog] }
```

The backslash counts **only on Windows**, where it is a separator; on Unix it is
an ordinary character in a file name, so `a\b` stays a bare name and stays a
PATH lookup. The comment now states that rule, carries the two measured lines
that name the defect, and says why `./ng` is not a PATH lookup.

## How it is reached — stated exactly, and measured

The registry half of the old claim is **true** and stays: `ase::sim_register`
normalizes, so nothing added in **Setup > Simulators** or from the Command
window reaches the branch, and `ase::sim_capabilities_path` (the Program field
and the Detect button, issue 1371) normalizes too. Confirmed again on this
tree: registering `./relng` stores an absolute path.

**The route that does reach it is the one where nothing is in force.** With
nothing registered — or with the choice deliberately cleared —
`ase::sim_status` takes its PATH arm and puts `[lindex [auto_execok $backend]
0]` into `resolved`. `ase::sim_capabilities` hands `resolved` straight to
`ase::sim_capabilities_at`, which hands it to the backend probe, which hands it
to `ase::cap_run`. Nothing on that path makes it absolute.

**And `auto_execok` answers a relative `./name`.** Tcl's own implementation
maps an EMPTY `$PATH` element to `.` (`if {$dir eq ""} {set dir .}`) and then
returns `[file join $dir $name]`. Measured, tcl 8.6.17, with the program in the
current directory:

```
leading  ":/usr/bin:/bin"  auto_execok ngfake -> ./ngfake
doubled  "/usr/bin::/bin"  auto_execok ngfake -> ./ngfake
trailing "/usr/bin:/bin:"  auto_execok ngfake -> ./ngfake
literal  ".:/usr/bin"      auto_execok ngfake -> ./ngfake
relative "bin:/usr/bin"    auto_execok ngfake -> bin/ngfake
```

A leading, doubled or trailing `:` in `$PATH` is an ordinary shell
misconfiguration, and a `.` in `$PATH` is an ordinary shell *configuration*.

**What it cost, driven live on this tree with the pre-fix predicate put back**
(`ase::sim_capabilities ngspice`, nothing registered, `PATH=":/usr/bin:/bin"`,
the program in the current directory):

```
auto_execok    : ./ngspice
sim_status ok  : 1
sim_status src : path
sim_status res : './ngspice'
capabilities   : known 1 usable 0 appendwrite 0 blanket_op_save 0 hier_op_names 0
probe starts   : 0
```

`known 1 usable 0` with the program **started zero times** is not a missing
answer — it is a verdict about a simulator nobody ran, which is issue 0929's
symptom arriving through the PATH door, and it is what
`ase::cap_report` would have said out loud. On the fixed tree the same gesture
gives `known 1 usable 1 appendwrite 1 blanket_op_save 0 hier_op_names 1` and
three probe starts.

**What is still NOT claimed:** no user is known to have hit this, and nothing
here measures how many users have an empty `$PATH` element. "Reachable by an
ordinary route" is the claim; "somebody hit it" is not.

**A residue on the same PATH arm, now measured, and it costs a cache MISS and
not a wrong answer.** The capability cache is keyed on the *relative* string
(`ase::cap_key ./ngspice`), so two different current directories each holding a
`./ngspice` do share one cache entry. That much is true. But the stored value
carries a stamp, and `ase::cap_stamp` records `path [file normalize $path]`, so
the two entries' stamps are NOT the same and `ase::cap_stale` refuses the
remembered answer. MEASURED 2026-09-07 through `./src/xschem`, two scratch
folders each holding an executable `ngspice` of identical size and mtime, so the
normalized path is the only field that can differ:

```
keyA = <./ngspice {}>   keyB = <./ngspice {}>   same_key = 1
stampA = path <...>/resA/ngspice mtime 1788819588 size 17
stampB = path <...>/resB/ngspice mtime 1788819588 size 17
ase::cap_stale stampA stampB = 1
```

So the shared key cannot serve one folder's answer for another folder's
program: it re-probes. **This is therefore not a defect and no number was
minted for it.** An earlier revision of this paragraph left it at "not measured
further" and a companion write-up asked the driver for an issue number; the
check was fifty lines away in the same file and took one script.

**What is still not measured here:** whether a shared key can cost anything at
all beyond that re-probe — for instance whether a *third* asker with a matching
stamp could be served from an entry it did not write. Nothing was driven for
that.

**Acceptance rows, in `tests/headless/test_ase_simcaps_0948.tcl`:**

* **K5b** — `./name` is started too, and is not looked for inside the probe's
  own folder. **RED before the change**: `{0 OK 1 0 0}` against `{0 OK 0 1 1}`
  — rc 1, the program never started, no results file.
* **K5c** — the carve-out itself is still there: a name with no separator is
  still the PATH lookup it was. Green before and after **by design** — it is the
  guard a wrong fix trips. Proven non-vacuous: normalizing every relative name
  reddens it by name.
* **K5d** STRUCTURAL — the rule the comment states and the rule the code tests
  are the same rule. **RED before the change**: `{1 0 1 1}` against `{1 1 0 0}`
  — the comment did not say "separator", it did say "no folder in it", and the
  body still decided it with `[file dirname]`.

Row **K5** was left as it was: it builds a multi-segment repo-root-relative
name and takes the branch that always worked, which is why it could not see
this.

**Added in the repair round, same file, same day:**

* **K5e** — the route above, driven end to end: nothing in force,
  `PATH=":/usr/bin:/bin"`, the stand-in named `ngspice` in the current
  directory. Asserts `auto_execok` answered `./ngspice`, that `sim_status`
  put that relative string in `resolved` on its `path` arm, that the answer is
  `known 1 usable 1`, and that the program was **started**. GREEN on the fixed
  tree; RED by name with the predicate reverted —
  `{./ngspice path ./ngspice 1 0 0}` against `{./ngspice path ./ngspice 1 1 1}`.
* **K5f** STRUCTURAL — the note above `ase::sim_capabilities_at` no longer
  claims every caller names the path itself, and says where `auto_execok`
  supplies it instead. **RED on the tree as found**: `{1 1 1 0}` against
  `{1 0 1 1}`.
* **K5g** STRUCTURAL — `ase::cap_run`'s own header names that route and never
  calls it latent. **RED on the tree as found**: `{0 0}` against `{1 0}`.
* **K5h** — the Windows backslash gate, behaviourally: a Unix program whose
  file NAME carries a backslash and no slash is still a PATH lookup. Self-skips
  loudly on Windows.
* **K5i** STRUCTURAL — and the backslash counts on Windows: exactly one
  backslash test, and the line above it is the platform gate. K5h cannot see
  that clause deleted outright; this row can.

**THE WINDOWS GATE WAS GUARDED BY NOTHING UNTIL K5h AND K5i.** The adversary
deleted `&& $::tcl_platform(platform) eq {windows}` from the predicate and no
row moved. Re-run after the repair, the same deletion reds two rows by name:

```
FAIL: K5h a backslash is an ordinary character in a Unix file name, so a name carrying one and no slash is still the PATH lookup it was -> {1 0 OK 1 0 0} (exp {1 0 OK 0 1 1}) : FAIL
FAIL: K5i STRUCTURAL the backslash counts as a separator on Windows only, and the platform gate is the line that says so -> {OK 1 0} (exp {OK 1 1}) : FAIL
```

Deleting the whole backslash clause reds K5i alone (`{OK 0 0}`), which is the
case K5h is blind to on this platform.

`test_ase_simcaps_0948` 100 → 105, ALL PASS, five names added (K5e–K5i) and
none lost; `test_ase_simreg_0931` 91 ALL PASS, name-for-name identical. (The
first pass's "92 → 95" was against a tree that item 0960 has since added rows
to; 100 is the baseline this repair was measured against.)

---

**Originally filed OPEN, and LATENT — not reachable through the Simulators window.**
Found by item S3a's verification pass, reproduced first-hand by the write-up
before filing.

## What it is

Item S3a fixed issue 0949 by running the probe with the probe's own scratch folder
as the program's current directory — the only form measured to survive a space, a
dollar, a bracket, a quote and a semicolon in a simulation folder's name. Anything
resolved relative to the *caller's* folder therefore has to be made absolute
first, and `ase::cap_run` does that:

```tcl
if {[file pathtype $prog] eq {relative} && [file dirname $prog] ne {.}} {
  set prog [file normalize $prog]
}
```

The carve-out is for a **bare name** like `ngspice`, which Tcl's `exec` looks up
on the PATH and which the folder change cannot affect. But `[file dirname ./ng]`
is also `.`, and `./ng` is **not** a PATH lookup — Tcl treats any name containing
a separator as a path. So `./ng` falls into the carve-out, is left alone, and is
then resolved against the probe's scratch folder, where it does not exist.

The comment above it states the opposite as fact: *"A bare name with no folder in
it is left alone: that is a PATH lookup, which the move cannot affect."* For
`./ng` neither clause is true.

## Measured

Two forms of the same program, same session, same probe folder. Only the spelling
of the location differs:

```
C  ./fast     rc=1 out=/usr/bin/timeout: failed to run command './fast': No such file or directory
C  bin/fast   rc=0 out=I-RAN
```

## Why it was FILED as latent, and why that was wrong

**This section is kept as filed, and corrected in place** — it is the sentence
the whole repair round is about.

*As filed:* "`ase::sim_register` runs `file normalize` on the location it is
given, so a simulator added through **Setup > Simulators** or from the Command
window is stored absolute and never reaches this branch. Confirmed: registering
`./relng` stores `/tmp/.../bin/relng`. The broken branch is reachable only by
calling `ase::cap_run` directly, which nothing in the tree does with a relative
name. So this costs the user nothing today."

**⚠ CORRECTED 2026-09-07.** The first two sentences are true and still are. The
third is FALSE and the fourth followed from it. The filing pass checked the
registry door, found it closed, and did not enumerate the others: with nothing
in force, `ase::sim_status`'s PATH arm puts `auto_execok`'s answer in
`resolved`, `ase::sim_capabilities` hands that to the probe, and `auto_execok`
answers a relative `./name` on an ordinary `$PATH`. See **"How it is reached"**
at the top, which carries the measurement. The lesson is the filing method, not
the code: *closed door found* is not *no door*, and reachability is a claim that
has to be enumerated and measured like any other.

## Why no test row catches it

Row **K5** of `tests/headless/test_ase_simcaps_0948.tcl` is the row for relative
program locations, and it builds its relative name as a multi-segment,
repo-root-relative path (`tests/headless/.scratch/...`), which takes the branch
that works. It never builds a `./name`. The row is honest — it self-skips loudly
when the stand-in is not below the working folder — but it cannot see this.

## Fix shape

One line and one comment. Normalize whenever the name contains a separator at all,
which is exactly Tcl's own rule for "this is a path, not a PATH lookup":

```tcl
if {[file pathtype $prog] eq {relative} && [string match {*/*} $prog]} { ... }
```

(plus the Windows separator, on the platform this file already guards for). Then
correct the comment to say what the carve-out really is: a name with **no
separator in it**. Row K5 grows a `./name` case.

## Acceptance

* `ase::cap_run ./prog ... $workdir $secs` starts the same program as
  `ase::cap_run [pwd]/prog ...`.
* A bare `ngspice` is still found on the PATH after the folder change.
* The comment describes the rule the code implements.

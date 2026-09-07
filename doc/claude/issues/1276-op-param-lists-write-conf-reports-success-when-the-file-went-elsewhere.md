# 1276 — `op_param_lists::write_conf` returns success when the settings went somewhere else

**Status: the DIRECTORY and RELATIVE-SYMLINK cases were fixed in commit
`21fcece6` on 2026-09-03 (item B2c) — BEFORE the ASE-L registry batch opened.
A THIRD CASE OF THE SAME BUG, THE TILDE, WAS STILL OPEN AFTER THAT, and was
fixed on 2026-09-07 by this batch's REPAIR ROUND (item R1). A FOURTH, issue
**1378** (`<path>.new` itself being a symlink), was fixed on the same day by
this batch's CLOSE-OUT ROUND (item F3) — and in BOTH writers, not just this
one. This header said "A fourth, issue 1378, is still open" until the truth
sweep; that was true when written and stale by the end of the day.**

⚠ **THIS HEADER SAID "FIXED AND LANDED … RE-VERIFIED INDEPENDENTLY" ON
2026-09-07 AND THAT WAS PARTLY FALSE, so read the correction before the
history.** Two things were run together into one sentence and both were
overstated:

* the **landing** was not this batch's work at all. `21fcece6` predates the
  batch; the pass that rewrote this header lifted nothing and found nothing
  left to lift, and said so correctly further down. What it did was *discover
  that this file was stale*.
* the **re-verification** was real but INCOMPLETE. It re-ran the two cases this
  file names and did not ask the third: a symlink whose stored target begins
  with a **tilde**. `file join` and `file normalize` expand a leading tilde and
  the kernel does not, so `_resolve_target` answered a path in the user's
  **home directory** and `write_conf` overwrote whatever unrelated file was
  there — **rc 1, zero reports, bytes somewhere else**, which is this issue's
  own headline symptom arriving through this issue's own fix. Two independent
  adversaries measured it. A green suite said nothing about it because no row
  asked.

**The tree is fixed for the three cases named above** as of the repair round;
see **"THE TILDE — REPAIR ROUND"** at the very end of this file. Everything
below the first horizontal rule is the record of how it got here, including two
attempts that were reverted as collateral; read it as history, not as a
description of the tree.

Originally: found by item B2's adversary pass on B2's own new code, 2026-09-03,
before anything calls the writer. Two cases, one proc, one fix site.

**Severity: this is the writer's headline contract failing in the direction
nobody tests for.** Issue 0937's whole lesson is that a *truncated* file is
worse than no write. This is worse still: the write reports **success**, the
user's Save line says the path it did not write, and the settings are gone with
no sentence anywhere.

## What is claimed

`src/op_param_lists.tcl`'s writer, copied in shape from `ase::sim_write_conf`
(`src/ase.tcl:1999-2036`), documents itself as *"Returns 1, or 0 with a report;
never raises."* Item B2's ACCEPT row is *"an interrupted write never
truncates"*, and that row **holds** — the failure here is on the other side of
the same contract.

## The measurement (2026-09-03, this tree, `src/op_param_lists.tcl` md5 `bf0230751de375be37e876aea53e8956`)

### Case 1 — the target path is a directory

```tcl
file mkdir $S/w/dirtarget
op_param_lists::set_list class mos annotation {{id ids 0}}
set rc [op_param_lists::write_conf $S/w/dirtarget]
```

```
DIRTARGET rc=1 reports=0 path_is_dir=1
$ ls $S/w/dirtarget/
-rw-r--r-- 1 analog analog 706 Sep  3 12:54 dirtarget.new
```

`file rename -force $tmp $path` with an existing **directory** destination does
not fail — Tcl moves the source *into* it. So the writer returns **1** with
**zero** reports while the settings land at `<path>/<basename>.new`, a name no
reader ever looks at. A following `load_conf` says *"no settings file at
`<path>`"* and the list is silently the PDK seed again.

### Case 2 — the settings file is a symlink

```
SYMLINK rc=1 link_still_link=0 real_size_before=0 real_size_after=0 link_size=706
$ ls -la
-rw-r--r-- 1 analog analog 706 Sep  3 12:54 link.conf     <-- was a symlink
-rw-r--r-- 1 analog analog   0 Sep  3 12:54 real.conf     <-- the intended target
```

The rename replaces the **link** with a regular file and leaves the real target
untouched. This is inherited from the copied `ase::sim_write_conf` shape and is
tolerable there; it is not tolerable here, because **symlinking the project
conf at a team-shared file in git is the obvious use of a file whose headline
feature is shareability** (the user's own words: *"shareable with teammates"*).

## Why the suite did not see it

`tests/headless/test_op_param_store_1245.tcl` row **W1** makes `$path.new` a
directory — it tests the *temp* being unopenable, which is the truncation arm.
Nothing in the suite makes the **target** a directory or a symlink:
`grep -c symlink` = 0, and the one `isdirectory` hit is W1's own trick. 39/39
green is a statement about that fence. (B1's lesson, one item later.)

## Recommended fix — one guard before the open, one after the rename

In `write_conf`, before `open $tmp w`:

```tcl
if {[file isdirectory $path]} {
  _say "cannot save the parameter lists to $path: it is a directory. The file you already had is untouched."
  return 0
}
```

and resolve a symlink to its target before choosing `$tmp`, so the temp is
written beside the **real** file and the rename replaces the real file:

```tcl
if {![catch {file link $path}]} { set path [file normalize [file link $path]] }
```

(resolve first, then take `[file dirname $path]` and `_tmpname`, so the
permission capture and the rename both act on the resolved path).

**Rejected: checking the rename's *result*.** `file rename` succeeded; there is
nothing to check. The guard has to be a precondition, not a postcondition.

**Rejected: refusing to follow symlinks at all.** That breaks the shared-file
use case this feature exists for.

## Acceptance rows this needs, in `test_op_param_store_1245.tcl` section W

* W5 — target is an existing directory: `write_conf` returns **0**, reports in
  plain English, and creates nothing inside the directory.
* W6 — target is a symlink to a regular file: the link is **still a link**
  afterwards and the **real** file carries the new bytes.
* W7 (counterweight) — an ordinary path in a directory that does not exist yet
  still succeeds, so the guard is not mistaken for a refusal (this is row W2
  today; keep it).

## Who inherits this

**Item B5**, which wires Save. Until this is fixed, B5's Save can tell a user
the file was written and be wrong. Fix it at B2's seam, not in the button.

---

# ITEM B2a — **ATTEMPTED, MEASURED, AND REVERTED**, 2026-09-03

> **STATUS: NOT FIXED. The code below was written, verified green, and then
> REVERSE-APPLIED out of the tree.** The item's adversary pass refuted the
> batch's central claim and the write-up agent reproduced three of its attacks
> independently, so item B2a is **[F]** and `src/op_param_lists.tcl`,
> `src/rdw.tcl` and both suites are byte-identical to commit `825cd3bd`.
>
> **The work is not lost and must not be retyped.** The full 2,506-line diff is
> preserved at `doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` and
> applies clean to `825cd3bd`. The next crew's job is
> **apply + fix the named holes + re-verify**, not reconstruct.
>
> Everything below this banner is a record of THE ATTEMPT — what it changed and
> what it measured. Read it as evidence, not as a description of the tree. The
> reasons for the revert are under **"Why this was reverted"** at the end of
> this section; the three defects that forced it are in issues 1277, 1281 and
> 1284, and 1276/1278/1279/1280/1282/1283 were reverted as **collateral**,
> because a 2,506-line diff is one unit and splitting it at write-up time would
> ship a code change no verifier ever saw.

## What the attempt did (item B2a — **FIXED**, 2026-09-03)


`src/op_param_lists.tcl`. Three new procs in front of `write_conf`, and four
lines inside it.

* **`_resolve_target {path}`** walks a symlink chain, bounded at 16 hops,
  returning the file the write should actually land on (or `{}` for a chain
  deeper than that, which is what a loop looks like from here).
* **`_target_why {path target}`** is the precondition, named once so it has a
  single sabotage point: `{}` when the resolved target may be written, and the
  sentence otherwise. It refuses a **directory** in plain English and says the
  file you already had is untouched.
* **`_path_tier {path}`** is issue 1281's, and shares the same block.

`write_conf` now resolves **before** the directory guard, before `file mkdir`,
before the permission capture and before `_tmpname`, because all three
measurements below say it must.

## ⚠ THIS ISSUE'S OWN RECOMMENDED ONE-LINER IS REFUTED, MEASURED

The sentence refuted is, verbatim from §5 above:

> resolve a symlink to its target before choosing `$tmp`:
> `if {![catch {file link $path}]} { set path [file normalize [file link $path]] }`

Measured on this tree for the **relative** target `real.conf` of a link living
at `<dir>/sub/link.conf`:

```
file normalize [file link $path]                                  -> <cwd>/real.conf          WRONG
file normalize [file join [file dirname $path] [file link $path]] -> <dir>/sub/real.conf      RIGHT
```

`file normalize` resolves against the **cwd**, not the link's own directory, and
a relative target is the natural spelling of the shared case
(`ln -s ../team/op_param_lists.conf .xschem/op_param_lists.conf`). Row **W7**
creates its link from a different cwd with a relative target precisely so the
one-liner reds there as loudly as no fix at all. Three more measured facts the
guard **order** depends on, all recorded in the code comment: `file normalize`
does not resolve a path's final component; a symlink to a **directory** answers
`file isdirectory` 1; and a **dangling** symlink answers exists=0/isfile=0/
isdirectory=0 while `file link` still succeeds.

## Red before green

| row | red on | green after |
|---|---|---|
| `W6` directory | `{1 1 0 0 w6dir.new 1 1}` (rc=1, zero reports, bytes at `<dir>/w6dir.new`) | `{1 0 1 1 {} 1 1}` |
| `W7` relative symlink | `{0 1 file 0 {} {}}` (link replaced, real file empty) | `{0 1 link 1 {} {}}` |
| `W7b` chain + dangling | `{0 0 1 file link 0 1 file 0}` | `{0 0 1 link link 1 1 link 1}` |

Sabotage, each red on its own fence with the fix in place:

* `SB-NO-SYMLINK-RESOLVE` (`_resolve_target` → identity) → **W7, W7b red**,
  `RESULT: 2 FAILED (54 passed)`.
* `SB-NO-TARGET-GUARD` (`_target_why` → `{}`) → **W6 red**,
  `RESULT: 1 FAILED (55 passed)`.

## Not fixed here, and why

`ase::sim_write_conf` (`src/ase.tcl:1999-2034`), the precedent this writer was
copied from, carries **both** holes structurally. It is another item's file, so
it is filed as issue **1286** rather than fixed here.

## Why this was reverted

**This issue's own fix was not refuted, and nothing below was measured wrong.**
It was reverted as **collateral**. Item B2a was implemented as one 2,506-line
diff across four files; the adversary pass refuted the batch's central claim on
three *other* issues — **1277**, **1281** and **1284** — and the write-up agent
reproduced all three independently before deciding. Splitting a diff that size
into a "sound" half and an "unsound" half at write-up time would have committed
a code change that no Measure, Verify-A, Verify-B or Verify-C pass had ever
seen, which is precisely the failure mode this batch has already paid for in
items B1, B2 and B3.

**The work is preserved and must not be retyped.**
`doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` applies clean to
`825cd3bd`. The next crew's job is **apply → fix the three named holes →
re-verify**, and this issue's portion should survive that pass unchanged.

---

## Item B2a-2 — REVERTED A SECOND TIME, 2026-09-03, AGAIN AS COLLATERAL

**This issue's own fix was still not refuted.** Item **B2a-2** re-applied
B2a's patch unchanged, re-fixed the three holes, added ruling **DD-6**'s display
key, and went green everywhere — store **39→71**, RDW window **32→49** headless
and **42→59** on `:99`, `test_op_annot` **485/492** and
`test_annot_declutter_1244` **134** all unmoved, audit back at the 367/12/0/2
baseline with an empty non-PASS diff.

**It was reverted anyway**, because the adversary refuted the central claim on
**1277**, **1281** and **1285** and the write-up agent reproduced **four**
attacks first-hand. Same reasoning as the first revert: the diff was one
2,838-line change across eight files, and splitting it at write-up time would
commit code no verification pass had ever seen.

**The work is preserved and must not be retyped.**
`doc/claude/op_param_batch/B2a-2_working_tree_REVERTED.patch` (md5
`1977a39e5d419d31fcbbbc3932c2606f`, 3,573 lines, eight files) **applies clean to
`849f2231`** — verified with `git apply --check` in both directions. It contains
**both** attempts: B2a's six sound fixes *and* B2a-2's re-fixes. This issue's
portion should survive the third pass unchanged; apply the patch and fix only
what §"Still open after B2a-2" in **1277**, **1281** and **1285** names.

---

## ATTEMPT 3 — item B2c, 2026-09-03: FIXED IN THE PATCH, NOT LANDED

**The fix is right and has now survived three adversary passes without a
counterexample.** It is in
`doc/claude/op_param_batch/B2c_working_tree_REVERTED.patch` and must be applied
rather than retyped. The item was reverted for issue **1294**, which is in a
different proc and does not touch this one.

### What the patch does

`_resolve_target {path}` — a **16-hop bounded** symlink walk resolving each hop
as `file normalize [file join [file dirname $p] $tgt]`. That expression is the
**relative-target correction this issue's own recommended one-liner gets
wrong**: for a link at `<d>/sub/link.conf` → `real.conf`, `file normalize [file
link $path]` gives `<d>/real.conf` while the corrected form gives
`<d>/sub/real.conf`. Re-verified on this tree.

`_target_why {path target}` — the named precondition: `{}` when writable, a
plain-English sentence otherwise. Refuses a directory and a chain deeper than 16
hops.

**Both run BEFORE `file dirname`, `file mkdir`, `_tmpname` and the permission
capture** — mandatory, because a symlink to a directory answers `file
isdirectory` **1** and a dangling link answers `exists` **0** while `file link`
still succeeds. All three platform facts re-verified 2026-09-03.

`_path_tier`, which shared the block in B2a-2's patch, was **not** copied: it is
issue 1281's provenance and DD-7 deletes it.

### Measured after (rows W6, W7, W7b, W8)

| case | before (HEAD) | after |
|---|---|---|
| target is a **directory** | rc=**1**, 0 reports, bytes at `<dir>/dirtarget.new` | rc=**0**, a sentence naming it a directory, **nothing created inside** |
| target is a **relative-target symlink** made from another cwd | rc=1, 0 reports, the **link replaced** by a 706-byte regular file, real target 0 bytes | rc=1, **still a link**, the **real file** carries the rows, no stray `real.conf` in cwd or parent |
| **dangling** link | — | resolves and writes the real path |
| **20-hop** chain | — | rc=0, the `>16 links` sentence, nothing written |
| target exists but is **unreadable** (0000) | rc=1, overwrites a file it never read | rc=0, a sentence, bytes intact |

The last row is **new with DD-7** and is not in this issue's original scope: once
the writer *reads* the file it is about to write, an unreadable-but-existing
target must report and return 0, because proceeding would write the session's
few changed keys over a file whose other rows were never seen — DD-7's own
failure mode arriving through the fix.

### ⚠ One observability gap, found by sabotage and fixed in the patch

Neutering `_target_why` initially left the suite **79/79 green**: DD-7's read
guard covers the directory case on its own, because `open` on a directory also
fails, so a build with **no directory guard at all** still returns 0 and still
leaves the directory empty — while telling the user *"it already exists but
could not be read"*. **Row W6 must assert the report's TEXT**, not just the
verdict. It does now.

---

# LANDED AND RE-VERIFIED — 2026-09-07, the ASE-L registry batch

**This item was scheduled a fourth time because THIS FILE said "NOT LANDED"
and the tree said otherwise.** The B2c fix went in with commit `21fcece6`
(*"fix(1276,1277,1281,1288,1294,1296): the settings file stops eating rows the
user typed (B2c)"*); `src/op_param_lists.tcl` at md5
`14a20c65f492721cf81d95925dae9c6e` carries `_resolve_target`, `_target_why` and
the four lines inside `write_conf` that use them, and
`tests/headless/test_op_param_store_1245.tcl` carries rows **W6 W7 W7b W8 W9**.
Nothing was lifted out of `B2a_working_tree_REVERTED.patch` this pass; there was
nothing left to lift. The staleness was the whole cost of the item, so it is
corrected at the top of this file.

## Re-measured against the tree, WITHOUT the suite

The suite could in principle be wrong about its own subject, so both original
cases were re-run from a bare `tclsh` that sources `src/op_param_lists.tcl` and
calls the writer directly (probe kept out of tree, in the session scratch):

```
CASE1 DIRTARGET rc=0 reports=1 path_is_dir=1 inside={}
CASE1 said: cannot save the parameter lists to <S>/w/dirtarget: it is a
      directory, not a settings file. Nothing was written inside it, and the
      file you already had is untouched.
CASE2 SYMLINK mk=0 rc=1 reports=0 link_type=link real_size_before=0
      real_size_after=1689 link_size=1689 stray_in_cwd=0
CASE2 real_has_row=1
CASE3 FRESHDIR rc=1 reports=0 isfile=1 has_row=1
```

Case 2's link is made with a **relative** target from a **different cwd**, which
is the shape that refutes this issue's own recommended one-liner; `stray_in_cwd=0`
is the term that would red if anyone reintroduced it. Case 3 is the
counterweight (row W2's shape): a path in a directory that does not exist yet
still succeeds, so the guard is not a blanket refusal.

## The rows are non-vacuous — two sabotages, by name

`test_op_param_store_1245` baseline: **ALL PASS (135 checks)**, `--nolog`, `:99`.

| sabotage | suite verdict | rows red BY NAME |
|---|---|---|
| `SB-NO-SYMLINK-RESOLVE` — `_resolve_target` → `return $path` | `RESULT: 3 FAILED (132 passed)` | **W7** `{0 1 file 0 0}`, **W7b**, and **BE9** (issue 1327's Save-through-a-symlink row, which rides the same resolution) |
| `SB-NO-TARGET-GUARD` — `_target_why` → `return {}` | `RESULT: 2 FAILED (133 passed)` | **W6** `{0 1 0 0 1}` — red on the **third** term, the sentence, and **BE6** |

The second one reproduces, exactly, the observability gap recorded in the
ATTEMPT-3 section above: with `_target_why` gone the writer **still** returns 0
and **still** leaves the directory empty, because ruling DD-7's read guard also
fails to `open` a directory — but it tells the user *"it already exists but
could not be read (… illegal operation on a directory)"*. Only W6's **text**
term catches it. That term is load-bearing and must not be trimmed.

Restored from a `cp` of the pristine file after each sabotage; md5 back to
`14a20c65f492721cf81d95925dae9c6e` and `git diff` empty both times.

## ⚠ ONE SIBLING HOLE FOUND AND DELIBERATELY NOT FIXED HERE — issue 1378
##    (HISTORY — it WAS fixed later the same day, close-out item F3; see below)

The same adversary pass measured a third way this writer can return **1** with
**zero reports** while the settings land somewhere else: when the temp name
`<path>.new` is itself a **symlink**. `open` follows it, `file rename` does
not, so the user's regular settings file is REPLACED BY A LINK and an unrelated
file is truncated and overwritten. It is filed as **1378** rather than fixed,
because this item's scope was an explicit lift of two named hunks and the guard
ORDER in `_resolve_target`'s comment block is not a place to freehand a third.
No acceptance row was added for it either: a row for an unfixed hole would put
the suite off its ALL-PASS baseline.

---

# THE TILDE — REPAIR ROUND, 2026-09-07 (item R1)

The 2026-09-07 pass recorded above was refuted by the batch's adversary on the
case it did not ask. Fixed here, in **both** copies of the resolver at once —
`op_param_lists::_resolve_target` and `ase::sim_conf_target` (issue **1286**) —
because the two procs being copies that drift apart is the defect 1286 exists
about, and this was that drift arriving a third time.

## What was wrong

`file join` and `file normalize` **expand a leading tilde**; the **kernel does
not**. A link whose stored target is literally `~/notes.conf` is, to the
operating system, a link into a directory *named* `~` beside the link —
`readlink` prints `~/notes.conf` and the link reads as **dangling**. Measured
in `tclsh`:

```
[file join /a/b {~/x}]                    ->  ~/x
[file normalize [file join /a/b {~/x}]]   ->  /home/analog/x        <-- the hole
[file normalize [file join /a/b {./~/x}]] ->  /a/b/~/x              <-- the kernel's answer
```

So `_resolve_target` answered a path in `$HOME` and `write_conf` wrote the
settings **over an unrelated file there**, returning **1** with **zero
reports**, leaving the link dangling and the next `load_conf` saying there is
no settings file.

Second half: `file normalize` **raises** on a `~user` that no password entry
matches (`user "nosuchuser_xschem" doesn't exist`), out of a writer whose
contract is *"Returns 1, or 0 with a report; never raises."*

## The remedy, measured rather than invented

Neutralise the tilde before joining:

```tcl
if {[string index $tgt 0] eq "~"} { set tgt ./$tgt }
```

Checked against all five target shapes — `~/x` → `/a/b/~/x`,
`~nosuchuser/q` → `/a/b/~nosuchuser/q` (no raise), `sub/y` → `/a/b/sub/y`,
`/abs/z` → `/abs/z` (an absolute target still wins), `../up.conf` →
`/a/up.conf`.

## And the bound was off by one

`_target_why`'s sentence says *"a symbolic link chain more than 16 links
deep"*. The loop spent one pass per link and needed one further pass to see
that the last thing is **not** a link, so it refused a chain of **exactly 16**.
Measured before the repair: 15 saved, 16 refused. The loop is now `$i <= 16`,
and 16 saves while 17 is refused.

## Red before green — verbatim, `--nolog` on `:99`

Baseline `test_op_param_store_1245`: **ALL PASS (135 checks)**. With the three
new rows on the **as-found** resolver:

```
FAIL: W7c a link whose stored target starts with a tilde is followed the way the system follows it — as an ordinary folder named ~ beside the link — so the settings land there and an unrelated file of the same name in your home directory is left byte-for-byte as it was -> {0 1 link NOFILE {# KEEP ME: an unrelated file that happens to share the name
list class mos annotation
param class mos annotation w7crow w7crow 0
}} (exp {0 1 link 1 {# KEEP ME: an unrelated file that happens to share the name
}}) : FAIL
FAIL: W7d a link pointing into the home directory of a user who does not exist does NOT raise — this writer's contract is that it never does — and the settings land in a directory literally named ~nosuchuser_xschem beside the link, never under any real home -> {0 {RAISED:user "nosuchuser_xschem" doesn't exist} 0 link NOFILE 0} (exp {0 1 0 link 1 0}) : FAIL
FAIL: W7e a chain of exactly sixteen links still saves and only the seventeenth is refused — the number the refusal sentence names and the number the resolver allows are the same number -> {0 0 link 0 1 0} (exp {1 1 link 0 1 0}) : FAIL
RESULT: 3 FAILED (135 passed)
```

W7c's RED line is the whole issue in one place: the user's unrelated home file
**contains the settings** the writer claimed to save elsewhere.

After the repair: **`RESULT: ALL PASS (138 checks)`**, and the name+status diff
against the baseline is three added `ok:` lines and nothing moved.

`HOME` is overridden for the duration of W7c's call and restored, so the row
neither depends on nor writes into the developer's real home directory.

## Non-vacuous — sabotage, by name

| sabotage | suite verdict | rows red BY NAME |
|---|---|---|
| drop `if {[string index $tgt 0] eq "~"} …` from `_resolve_target` | `RESULT: 2 FAILED (136 passed)` | **W7c**, **W7d** |
| `$i <= 16` back to `$i < 16` | `RESULT: 1 FAILED (137 passed)` | **W7e** |

Restored from a `cp` after each; `md5sum src/op_param_lists.tcl` back to
`cce5bd0cad711f9abd8a38c83a03152c`.

## What this repair did NOT measure

* **The `catch` around `file normalize` is insurance with no row behind it.**
  Removing it while keeping the `./` guard left the suites **ALL PASS** —
  measured. After the guard, a tilde can only reach `file normalize` from the
  *caller's own* path, and `file link` raises on that first and returns. The
  code comment says so; do not read the suite as proving that line.
* ~~**Issue 1378 is still open** — `<path>.new` itself being a symlink.
  Untouched by this repair.~~ **CLOSED in the close-out round, 2026-09-07** —
  and it was in **both** writers, not just this one. See the section below.
* No `:0` / Xwayland run, no GUI arm: both writers are pure Tcl file I/O and
  every row above is headless.


---

# THE TEMPORARY FILE WAS NEVER GUARDED — close-out round, 2026-09-07 (F3)

`_resolve_target` guards `$path`. **Nothing guarded `[_tmpname $path]`.** The
temp name is deterministic, `open <tmp> w` **follows** a symbolic link and
`file rename` does **not**, so a stale `<conf>.new` left behind as a link wrote
the settings **through** the link into an unrelated file and then moved the
**link itself** onto the user's settings file — rc **1**, **zero reports**. It
is the **fifth** and last member of this issue's family: directory target,
symlink target, tilde target, chain bound, **temp-name symlink**. (It read
"fourth" over a list of five until the close-out round's adversary counted
them.)

RED on the tree as found, verbatim:

```
FAIL: W7f a stale temporary file left behind as a symlink is not written through — your settings file stays a real file of its own instead of quietly becoming a link, and the unrelated file that link pointed at keeps its own bytes -> {0 1 link 1 0 2 0} (exp {0 1 file 1 1 0 0}) : FAIL
```

**Both writers were repaired in one change** — `op_param_lists::write_conf` and
`ase::sim_write_conf` — because these two drifting apart is the defect issue
**1286** exists about. The repair, the measured platform facts it rests on, the
sabotage table and the list of what was **not** measured all live in issue
**1378**; they are not duplicated here.

## The rows added here

`tests/headless/test_op_param_store_1245.tcl`: **W7f W7g W7h W7i**
(ALL PASS 138 → **142**, four added `ok:` lines and nothing moved).

**Only W7f was RED on the tree as found.** The other three were **GREEN as
found** and say so in their own comment blocks:

* **W7g** is the counterweight — an ordinary leftover **regular** `<conf>.new`
  must still be replaced and the save must still succeed, or the user gets a
  Save that can never work again. Its sabotage is dropping the removal and
  keeping the exclusive create: `RESULT: 2 FAILED (140 passed)`, **W7f** and
  **W7g** red by name.
* **W7h** is a fence against the obvious *wrong* fix. Row W1 puts a
  **directory** at `<path>.new` on purpose, and an unconditional
  `file delete -force` would delete a user's directory whole — a new hole of
  this issue's own family. W7h's directory has a file inside it that has to
  still be there. Sabotage: `RESULT: 2 FAILED (140 passed)`, **W1** and **W7h**
  red by name, W7h reading `{1 0 RAISED 0 0 1}` — the save succeeded, nothing
  was said, and the directory and its contents are gone.
* **W7i** covers the tilde shape no row reached. W7c uses `~/x`, which
  **dangles**; W7d uses `~nosuchuser/x`, which **raises**;
  `~<a user who really exists>/x` does **neither** — `file normalize` hands back
  that account's real home directory (measured: `[file normalize [file join /a/b
  {~root/x}]]` → `/root/x`). `root` is used deliberately: its home is
  unwritable for the user these suites run as, so dropping the `./` guard reds
  the row on the **return value** instead of by putting a file somewhere real.
  Sabotage: `RESULT: 3 FAILED (139 passed)`, **W7c**, **W7d** and **W7i** red by
  name.

## The `..` residual — measured, and deliberately left alone

`file normalize` collapses `..` **lexically**. Measured on this tree,
`tclsh 8.6.17`, against the kernel:

| path | `file normalize` | the kernel |
|---|---|---|
| `<base>/./sub/../x`, `sub` a **link** to `<d>/elsewhere` | `<d>/x` | `readlink -f` → `<d>/x` — **agree** |
| `<base>/./~/../x`, **no** `~` beside the link | `<base>/x` | `cat` → **ENOENT** — disagree |
| `<base>/./~/../x`, `~` present as a real directory | `<base>/x` | `cat` → `<base>/x` — **agree** |

An *existing* component, directory **or symlink**, is resolved before the `..`
and there is no divergence at all; it needs a `..` immediately after a component
that **does not exist**. **Left as it is and pinned by no row**: in that state
the link is **broken**, this writer writes through broken links by design (row
`W7b`), and `<base>/x` is exactly the path the kernel names once the missing
component appears as an ordinary directory. Not covered: that component
appearing later as a **link elsewhere**. The measurement is in the code beside
the `./` guard so it is not re-derived.

## Suites, `--nolog` on `:99`

`test_op_param_store_1245` ALL PASS (138) → **ALL PASS (142)**;
`test_ase_simreg_0931` ALL PASS (91) → **ALL PASS (95)**;
`test_ase_persist` and `test_ase_simdlg_0937` unchanged at ALL PASS (137) and
(48), with **no name+status diff** in either.

## Not measured

The unlink/create window was **not raced** — no row plants a link between the
`file delete` and the exclusive create; the safety argument rests on the
measured `CREAT|EXCL` behaviour tabled in issue 1378. No `:0` / Xwayland run and
no GUI arm: pure Tcl file I/O. Nothing measured under `root`.

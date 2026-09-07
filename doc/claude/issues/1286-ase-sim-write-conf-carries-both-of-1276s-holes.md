# 1286 — `ase::sim_write_conf` carries both of issue 1276's holes

**Status: FIXED 2026-09-07** (ASE-L registry batch: item 1286, then repair
round R1, then close-out item F3) — **except** the missing-parent-folder
question below, which is a **RULING the user still owes**, not a bug. The
paragraph below is how it was filed; read the four dated sections at the end in
order, because each one corrects the one before it. Filed by item **B2a**,
2026-09-03. It is the writer `op_param_lists::write_conf` was **copied from**,
so fixing the copy and leaving the original is exactly the drift this tree keeps
paying for.

## The claim

`ase::sim_write_conf` (`src/ase.tcl:1999-2034`) uses the same
write-beside-and-move idiom (issue 0937) and guards the same one thing —
that the **temp** is openable — and nothing about the **target**:

* **No directory guard.** `file rename -force <tmp> <path>` with `<path>` an
  existing directory does **not** fail; Tcl moves the temp *into* it. The writer
  returns success, the user's Save line names a path it did not write, and the
  settings sit at `<dir>/<basename>.new`, a name no reader looks at. Measured on
  `write_conf` as it stands at `825cd3bd` (B2a measured a fix for the sibling and was reverted): `rc=1 reports=0 path_is_dir=1
  inside={dirtarget.new}`.
* **No symlink resolution.** The rename replaces the **link** with a regular
  file and leaves the real target at size 0. Measured on `write_conf` before the
  fix: `rc=1 link_is_still_link=0 real_size=0 link_size=706`.

## Why it is filed and not fixed here

`src/ase.tcl` is another item's file; item B2a owns
`src/op_param_lists.tcl`, `src/rdw.tcl` and their two suites. Fixing it needs
its own suite rows, and `ase::sim_write_conf`'s callers and file shape are not
this item's to measure.

## The fix, already written next door

`op_param_lists::_resolve_target` + `_target_why` in
`src/op_param_lists.tcl` are exactly the two procs this needs, and their comment
block carries the four measurements the guard order depends on — including the
one that **refutes issue 1276's own recommended one-liner** (`file normalize
[file link $path]` resolves a relative target against the **cwd**, not the
link's directory). Copy the shape; do not re-derive it.

## Acceptance rows this will need

Mirrors of `W6`, `W7` and `W7b` in
`tests/headless/test_op_param_store_1245.tcl`: a directory target refused with
nothing created inside it, a **relative** symlink written through from a
different cwd, and a chain plus a dangling link.

---

## Item B2a-2, 2026-09-03 — unchanged, and the written fix is now in the second patch too

Item **B2a-2** was also forbidden to edit `src/ase.tcl` (item **B1**'s landed
seam), so this issue is untouched: **still FILED, NOT FIXED**. Its written fix —
`_resolve_target` + `_target_why` — is preserved in **both**
`doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` and
`doc/claude/op_param_batch/B2a-2_working_tree_REVERTED.patch`, in the
`op_param_lists.tcl` copy of the writer. Whoever fixes `ase::sim_write_conf`
should lift it from there rather than rewrite it.

---

## FIXED 2026-09-07 — ASE-L registry batch, item 1286

⚠ **PARTLY. This section was written before the batch's adversary refuted it,
and the resolver it describes shipped with a THIRD case of the same bug — the
tilde — plus an off-by-one at the chain bound and a defended line no row
proved. Read the section "THE TILDE, THE BOUND, AND THE UNPROVEN LINE" at the
end of this file before trusting anything below.** What follows is accurate
about the shape that was lifted and about the two holes it did close.

`_resolve_target` / `_target_why` were lifted in shape (not re-derived) from
the landed `src/op_param_lists.tcl` copy — which is itself the copy this writer
was copied *from*, so the two now say the same thing about the same two holes.
They arrive in `src/ase.tcl` as:

* **`ase::sim_conf_target {path}`** — walks the symlink chain, joining each
  relative target against **the link's own directory** (`file normalize [file
  join [file dirname $p] $tgt]`), bounded at 16 hops; answers empty for a chain
  deeper than that, which is what a loop looks like from here. ⚠ *As shipped
  this bound was off by one and the tilde was unhandled — see the last section.*
* **`ase::sim_conf_target_why {path target}`** — the target's preconditions,
  returning a `kind` in the same shape as `ase::sim_check`: `conf_linkloop`,
  `conf_isdir`, or empty. **The empty path is explicitly not a link loop** —
  `ase::sim_conf_file` answers empty when there is no `USER_CONF_DIR`, and that
  case still falls through to the writer's own reporting rather than being
  described to the user as a chain of symbolic links.

Both new `kind`s get their sentence in `ase::sim_why`, beside `nowrite`.
`ase::sim_write_conf` calls them **first** — before the temp name, before the
permission capture — and reassigns `path` to the resolved target, so the temp
is built beside the **real** file and the move stays atomic even when the link
crosses a filesystem.

### The rows, in `tests/headless/test_ase_simreg_0931.tcl`

`R11b` · `R11c` · `R11d` · `R11e`, sitting with `R11`/`R12`, the other two rows
about this writer. Measured RED on the unfixed writer, verbatim:

```
FAIL: R11b ... -> {1 0 1 1} (exp {0 1 0 1})
FAIL: R11c ... -> {0 1 file 0 0} (exp {0 1 link 1 0})
FAIL: R11d ... -> {0 0 0 0 1 file 0 1 file 0 1 0 0 0 0} (exp {0 0 0 0 1 link 1 1 link 1 0 1 0 0 0})
RESULT: 3 FAILED (84 passed)
```

`R11e` is the counterweight and is green either way by design; the sabotage that
proves it non-vacuous is an over-refusing directory arm.

**A stray measured while sabotaging, and now a term of `R11d`.** With the
relative-target join replaced by issue 1276's own one-liner, the three writes
landed as `hop1`, `dangreal` and `l1` **in the repo root** — the cwd the suite
runs from. `R11d` now saves from the scratch tree and asserts that nothing named
after a link *target* appears where the save was made from.

## STILL OPEN, AND IT IS A RULING, NOT A BUG — does saving create the folder?

The two writers now agree about symlinks and directories and still **disagree
about a missing parent folder**:

* `op_param_lists::write_conf` does `file mkdir` and saves.
* `ase::sim_write_conf` does not, and row **E4** of
  `tests/headless/test_ase_simreg_0931.tcl` pins the refusal — *"saving to
  somewhere that cannot be written says so and gives up cleanly"*.

The batch brief for this item asked for a counterweight row in which a path in a
folder that does not exist yet **succeeds**. That would have moved E4, so it was
not done: the two holes this issue names are the directory guard and the symlink
resolution, and growing a `file mkdir` is a separate, user-visible choice about
what a Save is allowed to create. `R11e`'s second half pins the current answer
so the choice cannot be made by accident.

Options, for the user:

1. **Leave it.** Saving never creates a folder; a path in a folder that is not
   there is refused with a sentence. The two writers stay different, and the
   difference is written down here.
2. **Give `ase::sim_write_conf` the same `file mkdir`** the sibling has, and
   rewrite E4 to be about a folder that cannot be *created* rather than one that
   does not exist.
3. **Take the `file mkdir` out of `op_param_lists::write_conf`** instead, so
   neither writer ever creates a folder, and both refuse alike.

---

# THE TILDE, THE BOUND, AND THE UNPROVEN LINE — repair round, 2026-09-07 (R1)

The batch's adversary refuted the section above, and the same refutation landed
on issue **1276** — which is the point of this issue: the two resolvers are
copies, so a hole in one is a hole in both. Both were repaired in one change.

## 1. The tilde — the hole that made this a data-loss bug again

`file join` and `file normalize` **expand a leading tilde**; the **kernel does
not**. A link whose stored target is literally `~/notes` is, to the operating
system, a link into a folder *named* `~` beside the link: `readlink` prints
`~/notes` and the OS reports the link as **dangling**. Measured in `tclsh`:

```
[file join /a/b {~/x}]                    ->  ~/x
[file normalize [file join /a/b {~/x}]]   ->  /home/analog/x      <-- the hole
[file normalize [file join /a/b {./~/x}]] ->  /a/b/~/x            <-- the kernel's answer
```

So `ase::sim_conf_target` answered a path in the user's **home folder**, and
`ase::sim_write_conf` **overwrote whatever unrelated file was there** while
returning 1 — the exact symptom this issue and 1276 exist about, arriving
through their own fix.

Second half: `file normalize` **raises** on a `~user` with no password entry
(`user "nosuchuser_xschem" doesn't exist`), out of a writer whose own doc
comment six lines above says it *never raises*. Measured before the repair:
`ase::sim_write_conf` raised.

**The remedy is measured, not invented** — neutralise the tilde before joining:

```tcl
if {[string index $tgt 0] eq "~"} { set tgt ./$tgt }
```

Checked against all five target shapes: `~/x` → `/a/b/~/x`,
`~nosuchuser/q` → `/a/b/~nosuchuser/q` (no raise), `sub/y` → `/a/b/sub/y`,
`/abs/z` → `/abs/z` (an absolute target still wins), `../up` → `/a/up`.

## 2. The bound was off by one, and disagreed with its own sentence

`ase::sim_why`'s `conf_linkloop` sentence says *"a chain of symbolic links more
than 16 deep"*. The loop spent one pass per link and needed one further pass to
see that the last thing is **not** a link, so a chain of **exactly 16** was
refused with a sentence saying it was more than 16. Measured: 15 saved, 16
refused. The loop is now `$i <= 16`; 16 saves, 17 is refused.

## 3. The line nothing proved

Last round's **sabotage D** deleted the `$path ne {} &&` qualifier from
`ase::sim_conf_target_why`'s empty-path arm and the suite stayed **ALL PASS
(87)**. Row **R11i** now distinguishes it, and repeating that sabotage reds it
by name.

## Red before green — verbatim, `--nolog` on `:99`

⚠ **THREE OF THE FOUR NEW ROWS WERE RED AS FOUND, NOT ALL FOUR.** This round's
own hand-off said "seven new rows, all RED on the tree as found" across the two
writers, and that sentence was wrong: **R11i was GREEN as found**. The
`$path ne {} &&` qualifier it is about already existed — last round's sabotage D
is what *removed* it — so R11i is a **distinguisher for a sabotage**, not a
red-first row, and its non-vacuity comes from the sabotage table below and from
nothing else. Corrected in the close-out round, 2026-09-07.

Baseline `test_ase_simreg_0931`: **ALL PASS (87 checks)**. With the four new
rows on the **as-found** resolver (R11f, R11g, R11h red; R11i green):

```
FAIL: R11f a link whose stored target starts with a tilde is followed the way the system follows it -- as an ordinary folder named ~ beside the link -- so the list lands there, and an unrelated file of the same name in your home folder is left exactly as it was -> {0 1 link 0 0 2 0} (exp {0 1 link 1 1 0 0}) : FAIL
FAIL: R11g a link pointing into the home folder of a user who does not exist is refused with a sentence and does NOT raise, which is what this writer promises it never does, and your link is still a link -> {0 {RAISED:user "nosuchuser_xschem" doesn't exist} 0 link 0} (exp {0 0 1 link 0}) : FAIL
FAIL: R11h a chain of exactly sixteen links still saves and only the seventeenth is refused -- the number the refusal names and the number the resolver allows are the same number -> {0 0 1 0 1 0} (exp {1 1 1 0 1 0}) : FAIL
RESULT: 3 FAILED (88 passed)
```

R11f's RED reads left to right: the link was made (0), the writer said success
(1), the link is still a link — and the settings are **not** at the
kernel-identical place (0), the `KEEP ME` bystander in the fake home is **gone**
(0) and **contains the new list twice** (2).

After the repair: **`RESULT: ALL PASS (91 checks)`**; the name+status diff
against the baseline is four added `ok:` lines and nothing moved.

`HOME` is overridden for the duration of R11f's call and restored, so the row
neither depends on nor writes into the developer's real home folder.

## Non-vacuous — sabotage, by name

| sabotage | suite verdict | rows red BY NAME |
|---|---|---|
| drop `if {[string index $tgt 0] eq "~"} …` | `RESULT: 1 FAILED (90 passed)` | **R11f** `{0 1 link 0 0 2 0}` |
| `$i <= 16` back to `$i < 16` | `RESULT: 1 FAILED (90 passed)` | **R11h** `{0 0 1 0 1 0}` |
| last round's **sabotage D** — drop `$path ne {} &&` | `RESULT: 1 FAILED (90 passed)` | **R11i** `{conf_linkloop conf_linkloop}` |

Restored from a `cp` after each; `md5sum src/ase.tcl` back to
`4db64aefb74359333c2575d1b4d863dc` every time.

## What this repair did NOT measure

* **The `catch` around `file normalize` is insurance with no row behind it.**
  Removing it while keeping the `./` guard left the suite **ALL PASS (91)** —
  measured, deliberately, and recorded in the code comment beside the line.
  After the guard a tilde can only reach `file normalize` from the *caller's
  own* path, and `file link` raises on that first and returns above. Do not
  read the suite as proving that line.
* The **missing-parent-folder ruling** above is untouched and still the user's
  to make.
* ~~Issue **1378** (`<path>.new` itself being a symlink) applies to the sibling
  writer and was not looked at here.~~ **THIS SENTENCE WAS FALSE AND IS
  WITHDRAWN.** It applies to **both** writers, `ase::sim_write_conf` included,
  by the same mechanism — the temp name is still `$path.new`, and `open`
  FOLLOWS a symlink while `file rename` does not. Measured on
  `ase::sim_write_conf` directly and **fixed in both** in the close-out round;
  see the last section of this file and issue **1378**.
* No `:0` / Xwayland run and no GUI arm: this writer is pure Tcl file I/O and
  every row is headless.


---

# THE TEMPORARY FILE WAS NEVER GUARDED — close-out round, 2026-09-07 (F3)

## 1. The sentence this file got wrong

The repair section above ends with *"Issue 1378 (`<path>.new` itself being a
symlink) applies to the sibling writer and was not looked at here."* **That was
false.** The batch's adversary measured it, and this round measured it again on
`ase::sim_write_conf` directly: the hole is in **both** writers, by the same
mechanism, because the temp name is still `$path.new` in both and `open`
**follows** a symlink while `file rename` does **not**. A stale `<conf>.new`
left behind as a link meant the simulator list was written **through** the link
into an unrelated file and then the **link itself** was moved onto the user's
list — rc **1**, **nothing said**.

RED on the tree as found, verbatim:

```
FAIL: R11j a stale temporary file left behind as a symbolic link is not written through -- your simulator list stays a real file of its own instead of quietly becoming a link, and the unrelated file that link pointed at keeps its own content byte for byte -> {0 1 link 1 0 2 0} (exp {0 1 file 1 1 0 0}) : FAIL
```

**Both writers were repaired in one change**, which is the whole point of this
issue: a hole fixed in the copy and left in the original is the drift this file
exists about. The measurements, the sabotage table and what was *not* measured
are all in issue **1378**; they are not duplicated here.

## 2. The tilde shape no row covered

`R11f` uses `~/x`, which **dangles**. `R11g` uses `~nosuchuser/x`, which
**raises**. Neither is the shape that goes quietly wrong:
`~<a user who really exists>/x` **neither dangles nor raises** — `file
normalize` hands back that account's real home directory. Measured in `tclsh
8.6.17`: `[file normalize [file join /a/b {~root/x}]]` → **`/root/x`**, against
`/a/b/~root/x` once the `./` guard is applied.

Row **R11m** (and **W7i** next door) covers it. It was **GREEN as found** — the
`./` guard landed last round and closes this shape too; the row exists because
nothing had ever *asked*. `root` is the account used deliberately: it exists on
every one of these machines and no test may write into its home, so if the
guard is ever dropped the row reds on the **return value** — the operating
system refuses the save — rather than by putting a file somewhere real.
Sabotage: dropping `if {[string index $tgt 0] eq "~"} …` gives
`RESULT: 3 FAILED (92 passed)` with **R11f**, **R11g** and **R11m** red by name.

## 3. R11g was passing under the wrong mechanism, and now it is not

`R11g`'s third term was `[expr {[string length $R11GSAID] > 0}]` — *some*
sentence was said. Under the sabotage that drops the tilde guard but keeps the
`catch`, `file normalize` raises, the catch answers `{}`,
`ase::sim_conf_target_why` calls `{}` a link loop, and the user is told **"a
chain of symbolic links more than 16 deep"** about a link that is **one link
long** — and the row stayed **GREEN**. Measured, both ways, in this round:

| R11g's terms | tilde-guard sabotage | verdict |
|---|---|---|
| round 2's (`[string length $said] > 0`) | dropped | **GREEN** — `RESULT: 2 FAILED (93 passed)`, only R11f and R11m red |
| this round's (names the folder, is not the loop sentence) | dropped | **RED by name** — `RESULT: 3 FAILED (92 passed)`, `{0 0 0 1 link 0}` |

The two terms that replaced it name the sentence instead of counting it: it has
to mention `~nosuchuser_xschem`, the place the write was actually refused at,
and it must **not** contain `more than 16`.

## 4. The `..` residual — measured, and deliberately left alone

`file normalize` collapses `..` **lexically**, so a stored target of `~/../x`
resolves to `<linkdir>/x`. Measured on this tree, `tclsh 8.6.17`, against the
kernel:

| path | `file normalize` | the kernel |
|---|---|---|
| `<base>/./sub/../x`, `sub` a **link** to `<d>/elsewhere` | `<d>/x` | `readlink -f` → `<d>/x` — **agree** |
| `<base>/./~/../x`, **no** `~` beside the link | `<base>/x` | `cat` → **ENOENT** — disagree |
| `<base>/./~/../x`, `~` present as a real directory | `<base>/x` | `cat` → `<base>/x` — **agree** |

So the divergence is **narrower than it sounds**: an *existing* component,
directory **or symlink**, is resolved before the `..` and there is no divergence
at all. It needs a `..` immediately after a component that **does not exist**.

**Decision: left as it is, and not pinned by any row.** In that state the link
is **broken**, and this writer writes through broken links **by design** —
`R11d` / `W7b` assert exactly that. `<base>/x` is also precisely the path the
kernel names once the missing component is created as an ordinary directory
(measured, third row above). What is **not** covered, and no row says anything
about it, is the missing component later appearing as a **link to somewhere
else**; that would move the kernel's answer and not the resolver's. The
measurement is recorded in the code beside the `./` guard in both resolvers so
the next reader does not re-derive it.

## 5. What this round did NOT measure

* **The unlink/create window was not raced.** No row plants a link between the
  `file delete` and the exclusive create. The claim that the window is safe
  rests on the measured `CREAT|EXCL` behaviour tabled in issue 1378, not on a
  row that reproduces the race.
* **The missing-parent-folder ruling** in the section above is still untouched
  and still the user's to make.
* **No `:0` / Xwayland run and no GUI arm.** Pure Tcl file I/O; every row is
  headless.
* **Nothing was measured under `root`**, and `R11m` is not fenced against being
  run as `root` the way `W8` next door is fenced against its `chmod` not biting.

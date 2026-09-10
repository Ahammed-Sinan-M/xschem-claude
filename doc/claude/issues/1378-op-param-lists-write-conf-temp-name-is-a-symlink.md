# 1378 — `op_param_lists::write_conf` turns the user's settings file into a symlink when `<path>.new` is one

**Status: FIXED 2026-09-07 in BOTH writers** — ASE-L registry batch,
close-out item F3. See the section "FIXED — and it was in both writers"
at the end of this file. The title says `op_param_lists::write_conf`
because that is where it was found; the same hole was measured in
`ase::sim_write_conf` and both were repaired in one change.
Originally found 2026-09-07 by the ASE-L registry
batch's adversary pass on item **1276**, on 1276's own landed fix
(`src/op_param_lists.tcl`, md5 `14a20c65f492721cf81d95925dae9c6e`, commit
`21fcece6`). It is the **third** member of 1276's family — a write that returns
**1** with **zero reports** while the bytes land somewhere the user never named —
and it was deliberately left unfixed so 1276's scoped lift stayed a lift.

## What is claimed

`write_conf` writes beside-and-moves: bytes to `[_tmpname $path]` = `$path.new`,
then `file rename -force $tmp $path`. **`open` follows a symlink; `file rename`
does not.** So if `$path.new` already exists **as a symlink**:

* `open $tmp w` truncates and writes **the link's target**, not `$path.new`;
* `file rename -force $tmp $path` moves the **link itself** onto `$path`.

The result is that the user's regular settings file becomes a **symbolic link**
to an unrelated file, that unrelated file has been truncated and overwritten
with the settings, and the writer reports success.

Row **W1** of `tests/headless/test_op_param_store_1245.tcl` makes `$path.new` a
**directory**, which is the arm where `open` FAILS and the writer correctly
reports. Nothing anywhere makes it a **link**, which is the arm where `open`
SUCCEEDS — the same "the fence was built around the case we thought of" shape
1276 itself was filed for.

## The measurement (2026-09-07, this tree, bare `tclsh` sourcing the writer)

Setup: a directory holding the user's `op_param_lists.conf` (a regular file, one
comment line) and an unrelated `notes.txt`; a stale
`op_param_lists.conf.new` left behind as `ln -s notes.txt`. The temp name is
**deterministic**, so nothing has to be guessed to arrange this.

```
BEFORE conf_type=file conf=# the settings file the user has
BEFORE other_type=file other=an unrelated file the user also keeps here
SETUP  newlink_type=link -> notes.txt

AFTER  rc=1 reports=0
AFTER  conf_type=link link=notes.txt
AFTER  other_first_line=# the settings file the user has
AFTER  other_has_settings=1
AFTER  original_comment_survives=1        (only because it is now READ THROUGH the link)
AFTER  unrelated_note_survives=0          <-- notes.txt's own content is GONE
```

So: **rc=1, no sentence**, `op_param_lists.conf` is now a link, and a file that
had nothing to do with xschem was silently destroyed.

## Why it matters more than its likelihood suggests

The feature's headline is shareability — *"shareable with teammates"* — so the
settings file's directory is exactly the kind of place that collects other
people's leftovers, and `<conf>.new` is a name this writer itself creates and
(on a mid-write failure) can leave behind. It is also the general shape of a
predictable-temp-name symlink attack in a shared or group-writable project
directory: the attacker chooses the target, xschem does the truncating with the
user's own credentials.

## The same idiom is in `ase::sim_write_conf`

`src/ase.tcl` is the writer `op_param_lists`' was copied from and uses the same
`open <tmp> w` / `file rename` pair. Issue **1286** is already open against it
for 1276's two holes; this one belongs on that list too. **Not verified there**
when this was filed — `src/ase.tcl` was another agent's file in the batch that
found this, and it was not touched.

⚠ **IT WAS VERIFIED THERE ON 2026-09-07 AND IT IS THE SAME BUG.** Row `R11j` of
`tests/headless/test_ase_simreg_0931.tcl` measured it on `ase::sim_write_conf`
directly, RED, verbatim:

```
FAIL: R11j a stale temporary file left behind as a symbolic link is not written through -- your simulator list stays a real file of its own instead of quietly becoming a link, and the unrelated file that link pointed at keeps its own content byte for byte -> {0 1 link 1 0 2 0} (exp {0 1 file 1 1 0 0}) : FAIL
```

Read left to right: the link was made (0), the writer said **success** (1), the
user's simulator list is now a **`link`** (want `file`), the bystander is **not**
byte-identical (0) and **contains the simulator list twice** (2).

## Candidate fix as filed — SUPERSEDED by the FIXED section at the end

Refuse or clear a temp path that is not what the writer expects, before `open`:
a `file exists`/`file link`-aware check on `$tmp` (a leftover `.new` of any kind
is already suspect), or open with an exclusive create and fall back to a fresh
name. **Ordering matters and is not obvious** — `_resolve_target` /
`_target_why` already run first and their comment block records four measured
platform facts the order depends on, so a third guard has to be placed against
that record rather than dropped in.

## Acceptance rows this needed — DELIVERED, and in both suites

Section **W** of `tests/headless/test_op_param_store_1245.tcl`, beside W1:

* the temp path `<path>.new` is a **symlink** to an unrelated existing file →
  `write_conf` reports and returns 0 (or writes the real target safely), the
  settings file is **still a regular file**, and the unrelated file's bytes are
  **unchanged**;
* counterweight: an ordinary leftover **regular** `<path>.new` is still
  overwritten and the save still succeeds, so the guard is not mistaken for a
  refusal.


---

# FIXED — AND IT WAS IN BOTH WRITERS — 2026-09-07, ASE-L registry batch item F3

The tree said this applied to one writer. It applied to **both**, by the same
mechanism, and both were repaired in **one** change — `ase::sim_write_conf`
(`src/ase.tcl`) and `op_param_lists::write_conf` (`src/op_param_lists.tcl`) —
because these two procs drifting apart is the defect issue **1286** exists
about. This is the last member of the family 1276/1286 had open: directory
target, symlink target, tilde target, chain bound, **temp-name symlink**.

## The repair, and it is two lines in each writer

```tcl
if {![catch {file type $tmp} tkind] && $tkind ne {directory}} { catch {file delete $tmp} }
if {[catch {open $tmp {WRONLY CREAT EXCL} 0666} fp]} { ...report and return 0... }
```

**Why not just one of the two.** The `file delete` alone is the shape the issue
warned about — "do not assume `file delete` then `open` is safe". The `CREAT
EXCL` alone would refuse the *ordinary* leftover `<conf>.new` this writer itself
drops on a mid-save failure, and the user would then have a Save that can never
succeed again with no way to clear it from inside xschem (measured: sabotage A2
/ B2 below reds `R11k` / `W7g` by name).

**What was done about the window.** The window between the unlink and the create
is **still there** and ordering does not close it. What closes the *data-loss*
outcome is `CREAT|EXCL`: POSIX requires it to fail on an existing path
**including a symbolic link, dangling or not**, so anything planted in the
window makes the create FAIL and the user is told, instead of the write being
followed somewhere else. Measured on this tree, `tclsh 8.6.17`:

| probe | answer |
|---|---|
| `open <link to a real file> {WRONLY CREAT EXCL} 0666` | raises `file already exists`; the target keeps its bytes |
| `open <DANGLING link> {WRONLY CREAT EXCL} 0666` | raises `file already exists`; the target is **not** created |
| `open <DANGLING link> w` | succeeds and **creates the target** |
| `open <directory> {WRONLY CREAT EXCL} 0666` | raises `file already exists` (`w` raises `illegal operation on a directory`) |
| `file delete <symlink>` | removes the **link**; the target keeps its bytes |
| `file delete <EMPTY directory>` (no `-force`) | **removes it** |
| `file delete <NON-EMPTY directory>` (no `-force`) | raises `directory not empty` |
| `open <p> {WRONLY CREAT EXCL} 0666` vs `open <p> w`, fresh | both land at `00644` under this shell's `umask 0022` |

The last row is why row `R12` (permissions survive a save) does not move: the
explicit `0666` is the mode Tcl's `w` was already passing.

**⚠ THE REMOVAL IS `file delete`, NEVER `file delete -force`, AND THE TYPE
GUARD IS NOT DECORATION.** Rows `R11`/`W1` put a **directory** at `<path>.new`
on purpose, an empty one, which a plain `file delete` still removes — so
without the `$tkind ne {directory}` test those two rows red. Worse, a user's
**non-empty** directory at that name would be deleted whole by a `-force`, which
would be a *new* hole of the very family this issue is about. `R11l` / `W7h`
are the fence for exactly that, and sabotage A3 / B3 below shows what it
catches.

## The rows

`tests/headless/test_ase_simreg_0931.tcl`: **R11j R11k R11l R11m**
(ALL PASS 91 → **95**).
`tests/headless/test_op_param_store_1245.tcl`: **W7f W7g W7h W7i**
(ALL PASS 138 → **142**).

**Only R11j and W7f were RED on the tree as found.** The other six were GREEN as
found and say so in their own comment blocks — they are a counterweight
(`R11k`/`W7g`), a fence (`R11l`/`W7h`) and a coverage row for a tilde shape no
row reached (`R11m`/`W7i`). Their non-vacuity is the sabotage table, not a red
first run.

## Non-vacuous — sabotage, by name

| sabotage | suite verdict | rows red BY NAME |
|---|---|---|
| `ase.tcl`: both lines back to `open $tmp w` | `RESULT: 1 FAILED (94 passed)` | **R11j** `{0 1 link 1 0 2 0}` |
| `ase.tcl`: keep `CREAT EXCL`, drop the `file delete` | `RESULT: 2 FAILED (93 passed)` | **R11j**, **R11k** |
| `ase.tcl`: replace the guarded delete with `file delete -force` | `RESULT: 2 FAILED (93 passed)` | **R11**, **R11l** `{1 0 RAISED 0 0 2}` |
| `op_param_lists.tcl`: both lines back to `open $tmp w` | `RESULT: 1 FAILED (141 passed)` | **W7f** `{0 1 link 1 0 2 0}` |
| `op_param_lists.tcl`: keep `CREAT EXCL`, drop the `file delete` | `RESULT: 2 FAILED (140 passed)` | **W7f**, **W7g** |
| `op_param_lists.tcl`: replace the guarded delete with `file delete -force` | `RESULT: 2 FAILED (140 passed)` | **W1**, **W7h** `{1 0 RAISED 0 0 1}` |

`R11l`'s red under the third sabotage is the whole reason the fence exists,
read left to right: the save **succeeded** (1), **nothing was said** (0), the
user's directory is **gone** (`RAISED` from `file type`), the file that was
inside it is **gone** (0), and the **simulator list** was rewritten (0, then 2).
(`R11l` lives in `tests/headless/test_ase_simreg_0931.tcl` and is about
`ase::sim_write_conf`. "Settings file" is `op_param_lists`' noun — that arm is
`W7h` — and this sentence carried it until the close-out round's adversary
caught the swap.)

Restored from a `cp` after every sabotage; `md5sum` back to
`4da84a382e89466d37d636cbbb17f9f9` (`src/ase.tcl` before the residual comment
below was added) and `8100414ccfbd84f51c9e4893474dbfa1`
(`src/op_param_lists.tcl`) every time.

## Suites, `--nolog` on `:99`, name+status diff not counts

| suite | baseline | after |
|---|---|---|
| `test_ase_simreg_0931` | ALL PASS (91) | **ALL PASS (95)** — four added `ok:` lines, nothing moved |
| `test_op_param_store_1245` | ALL PASS (138) | **ALL PASS (142)** — four added `ok:` lines, nothing moved |
| `test_ase_persist` | ALL PASS (137) | **ALL PASS (137)** — no name+status diff |
| `test_ase_simdlg_0937` | ALL PASS (48) | **ALL PASS (48)** — no name+status diff |

## What this repair did NOT measure

* **No `:0` / Xwayland run and no GUI arm.** Both writers are pure Tcl file
  I/O and every row above is headless.
* **The window itself was not raced.** No row plants a link between the unlink
  and the create — the argument that the window is safe rests on the measured
  `CREAT|EXCL` behaviour in the table above, not on a row that reproduces the
  race. A row that did would need a second process and a scheduler it can pin.
* **Nothing was measured about a `.new` that is a link to a directory, a
  device, a FIFO, or a file on another filesystem.** The type guard passes all
  of those to `file delete` and then to the exclusive create; only the regular
  file, the link-to-a-regular-file, the dangling link and the directory arms
  have rows.
* **Nothing was measured under `root`.** `R11m` / `W7i` use `~root` precisely
  because that account's home is unwritable for the user these suites run as; a
  run as `root` would give those two rows a different mechanism and they are
  not fenced against it the way `W8` is.

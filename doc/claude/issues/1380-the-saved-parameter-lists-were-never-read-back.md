# 1380 — Save wrote the parameter lists and nothing ever read them back

**Status: FIXED** (`src/xschem.tcl`, one call). Reported by the user while
working through the look-debt digest, in these words:

> "'Save' modified list (annotation or summary) for RDW is not surviving
> session. RDW claims saved, and the file exists while Xschem still up. But,
> relaunch and: `No such file or directory`."

Subject: `op_param_lists::load`, and the seam at `src/xschem.tcl` that sources
`op_param_lists.tcl`.

## Two different bugs wearing one report

The user's sentence describes **two** failures and only the first is this issue.

1. **The lists did not survive a session.** Real, and the subject here.
2. **The file itself was missing on relaunch.** NOT a defect in this tree —
   the assistant had moved `<repo>/.xschem/` to a quarantine directory twenty
   minutes earlier, mistaking the user's own Save for test litter left by its
   own probe runs. Restored intact, mtime preserved. Recorded here so the
   measurement below is not read as evidence for something it does not show.

## What was measured

At `f25eb4a5`, in a fresh process, with the user's saved file present:

```
project conf path = /home/analog/dev/xschem-claude/.xschem/op_param_lists.conf
file exists       = 1
summary list AS FOUND at startup =                       <- empty
load returned: /home/analog/.xschem/op_param_lists.conf
               /home/analog/dev/xschem-claude/.xschem/op_param_lists.conf
summary list AFTER load = {id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2}
                          {vth vth 2} {vds vds 2} {gmbs gmbs 1}
                          {vdsat vdsat 1} {cgs cgs 1}
```

The loader is **complete and correct**. It reads the user-global tier then the
project tier, dedupes two tiers that resolve to one file through a symlink
(issue 1327), treats a missing file as the ordinary first-run case, and stamps
nothing so that a later Save of one tier still rewrites only the keys this
session touched (ruling DD-7). Called by hand it restored the user's nine-row
summary list exactly.

It simply had **no callers**:

```
$ grep -rn "op_param_lists::load" src/ | grep -v load_conf
$          (nothing)
```

So `rdw::_do_save`'s sentence — *"wrote the operating-point parameter lists to
&lt;path&gt;"* — was **true and useless**. The bytes landed; nothing ever picked
them up. Every session began with an empty store and re-seeded from the PDK
declaration, which is indistinguishable, from the user's chair, from a Save
that silently did nothing.

## Why it survived

`src/xschem.tcl`'s own comment above the source line says the file "reads no
file and touches op_annot:: not at all until called". That is a true and
deliberate statement about `op_param_lists.tcl` — proc definitions only at
source time — and it reads as if the deferral were the whole design. The call
that was supposed to follow it was never written, and no suite noticed because
every suite that exercises the store **sets its lists in memory** and never
restarts a process. A round trip needs two processes, which is a shape this
tree's headless suites do not have.

## The fix

One guarded call at the source seam, with the reasoning in place:

```tcl
source $XSCHEM_SHAREDIR/op_param_lists.tcl
catch {::op_param_lists::load}
```

**At the seam, not lazily at first use**: `load` is *defined* as the session's
initial state, so a lazy load would make "initial" depend on which door the user
happened to open first. It may precede the PDK's declarations because a STORED
list wins over a declared one. `catch` because a missing file is the ordinary
first-run case, and because a raise here would run inside `Tcl_AppInit()`, which
continues after a failed source and leaves the installed binary segfaulting
(issue 0423).

Verified in a fresh process: the nine-row summary list is present at startup.

## What this still owes

* **A two-process fence.** Every existing store row is single-process, which is
  exactly why this shipped. The row wanted writes a conf, starts a SECOND
  xschem, and reads the list back — the only shape that can fail when a caller
  goes missing again.
* **`.xschem/` in the repo root now reds `BT9`**, whose leg asserts
  `[file isdirectory [file join $repo .xschem]]` is 0. That was reasonable when
  nothing created the directory; it is wrong now that the feature legitimately
  creates it in whatever directory xschem was launched from — including this
  repo, when the user runs `./src/xschem` from the tree. A suite that reds
  because the user saved their own settings is a standing red waiting to be
  waved through. Needs its own number and a fix that distinguishes "the suite
  dropped a file" from "the user has one".

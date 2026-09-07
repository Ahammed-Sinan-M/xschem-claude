# 1359 — `run_regression.tcl`'s display arm overwrites the user's `/tmp/Xschem.log.*`

**Status: FIXED.** Measured and *caused* on 2026-09-05 by the pass that filed
it, which said so rather than hiding it; fixed by the driver the same day,
after it destroyed `/tmp/Xschem.log.5` a **second** time — the log the whole
RDW batch was diagnosed from, and one that had already been restored by hand
once.

## The fix

`tests/run_regression.tcl`'s display arm now makes
`tests/results/.actionlogs/` and passes `--logdir $dlogdir` on the one launch
line that starts a GUI child. Under the results directory rather than a temp
dir, because a display-arm case that *wants* its action log can then read it,
and a stray log left behind is then a test artifact where a reader expects
test artifacts.

**Fenced by row V57 of `tests/headless/test_op_annot.tcl`**, which already owned
the claim "what this launch line must contain" — an eighth leg rather than a
second reader of the same line. Proved non-vacuous: removing ` --logdir
$dlogdir` gives `RESULT: 1 FAILED (484 passed)` with V57 answering
`{1 1 1 1 1 1 1 0}`, and the tree was restored by `cp` with the md5 verified
(`21d1a3fd26670f6fca594bca4b01fcf9`).

**Verified end to end**: md5 of every `/tmp/Xschem.log.*` taken before and
after one solo `tclsh run_regression.tcl` — `rc=0`, zero counted failures, and
the diff of the two md5 listings is **empty**. The arm's own logs landed in
`tests/results/.actionlogs/` instead.

## What happens

`tests/run_regression.tcl:217` launches the display arm as

```tcl
exec $dd exec $xschem_cmd --pipe -q --script ${dc}.tcl > ${dc}.disp.log 2>@1
```

with **no `--logdir`**. A GUI xschem with no `--logdir` writes its action log to
`/tmp/Xschem.log.N`, taking the lowest free N — which is exactly where the
user's own interactive sessions put theirs. There are ~20 display-arm cases, so
one T1 run claims the first ~20 slots and overwrites whatever is in them.

The `--nogui` arms (`:176` and `:238`) are safe: a headless run without
`--logdir` creates no log at all (that is `test_action_log.sh`'s own case 4).
**It is only the display arm.**

## The measured loss, in this session

md5 of every `/tmp/Xschem.log.*` taken before any work, and again after one
solo `tclsh run_regression.tcl`:

| file | before | after | verdict |
|---|---|---|---|
| `.1` | `e8fee913…` 263 B | `f1e8a781…` 33010 B | **DESTROYED** — now `test_annot_show_menu.tcl`'s log |
| `.2` | `c6ad17e8…` 360 B | unchanged | survived |
| `.3` | `ebca7757…` 263 B | `eac6509c…` | **DESTROYED** |
| `.4` | `2f6ada34…` 263 B | `f77c25ce…` | **DESTROYED** |
| `.5` | `31802f60…` 5621 B | **unchanged** | survived — *this is the log the whole RDW batch was diagnosed from* |
| `.6` | `ebca7757…` 263 B | unchanged | survived |
| `.7` | `21082e40…` 140 B | unchanged | survived |
| `.8` | `dfd71f8b…` 263 B | `fae052a2…` | **DESTROYED** |
| `.9` | `ebca7757…` 263 B | `c29d72e1…` | **DESTROYED** |

Five files, all 263-byte stubs, timestamped 14:07–14:11 — the same window as the
user's own `.2`, `.5` and `.7`, so at least some of them were theirs. `.3` and
`.9` carried the same md5 as the surviving `.6`, whose header names a *previous
agent's* probe (`scratchpad/CRITIC_1300/g7.tcl`), so those two were agent
litter; `.1`, `.4` and `.8` cannot be attributed and must be assumed the
user's.

**Nothing was restored.** The rule this repo works under is that nothing writes
into `/tmp/Xschem.log.N`, and putting bytes back there would break it a second
time to hide the first.

## Why it will keep happening

CLAUDE.md makes a solo `run_regression.tcl` the acceptance signal for every
change on this branch, and the crew brief for the RDW batch mandates it too. So
every agent that follows the instructions correctly destroys these files. The
warning in the brief — *"a crew in the previous round launched xschem with the
default logdir and OVERWROTE /tmp/Xschem.log.5"* — reads as a warning about
careless per-agent invocations; it is also true of the harness the instructions
require.

## The fix, and why this pass did not take it

One argument on `:217`, a scratch directory under the run's own results tree.
It was **not taken here** because it is outside this pass's item, because the
harness has no fence that would catch a regression in it, and — the real
reason — because at least one suite in the display list may itself be about the
log's default placement, and changing the harness under it needs its own
verification pass rather than a drive-by. Whoever takes it should check the
display-arm list against `test_action_log.sh` and `test_ciw_actionlog_output`
first.

## A WORKAROUND THAT WORKS TODAY, MEASURED 2026-09-05 (issues 1360/1361 pass)

`src/util.c:370-373` defaults the action log to `$TMPDIR`, else `/tmp`, so
`TMPDIR=<somewhere private> tclsh run_regression.tcl` moves every display-arm
log out of `/tmp` without touching `tests/run_regression.tcl` at all: the
children inherit the environment, and `devdisplay.sh exec` passes it through.
MEASURED over one full solo run (rc=0, 57 cases, zero counted failures): all
nine `/tmp/Xschem.log.*` byte-identical by md5 before and after, and
`Xschem.log` .. `Xschem.log.5` created inside the private `TMPDIR` instead.
This is a caller-side mitigation, not the fix -- it protects whoever remembers
it, which is exactly the thing a `--logdir` argument in the harness would stop
depending on.

**AND THE NEXT PASS PROVED THAT SENTENCE, 2026-09-05 (issue 1362).** Its brief
carried "NEVER WRITE INTO /tmp/Xschem.log.N" as a hard rule in capitals; it ran
its BASELINE T1 before it had read this file, and six of the ten slots changed
md5. The content lost was already test output from an earlier run the same
afternoon, so nothing of the user's died a second time -- but a rule in capitals
plus a mitigation in a file nobody has read yet is not a defence. Its own final
T1 used `TMPDIR` and every slot came back byte-identical.

## SECOND MEASURED INSTANCE, 2026-09-05 18:17-18:18 (issue 1354's pass)

It happened again, to a pass whose own brief carried *"⚠ NEVER WRITE INTO
`/tmp/Xschem.log.N`"* as a hard rule and which passed `--logdir` on every single
direct `xschem` invocation it made. **`tests/run_regression.tcl` is the only
door left, it has no `--logdir` knob, and the same brief required T1 be run
solo** — so the rule and the requirement contradict each other until this is
fixed. `XSCHEM_AL_LOGDIR` is no escape hatch: `grep -rn XSCHEM_AL_LOGDIR src/`
returns nothing, it is a convention `test_action_log_libmgr.tcl` reads and the
binary honours `--logdir` alone.

md5 of every `/tmp/Xschem.log.*` before any work and after one solo
`tclsh run_regression.tcl`:

| file | before | after | verdict |
|---|---|---|---|
| `.1` | `c29d72e1…` | unchanged | survived |
| `.2` | `eb98cb09…` | `1062f10c…` 3053 B | **OVERWRITTEN** |
| `.3` | `ddef12c9…` | unchanged | survived |
| `.4` | `f77c25ce…` | same bytes, mtime 18:17:38 | rewritten, content identical |
| `.5` | `17e437dd…` 3182 B | **unchanged** | survived — *the log this whole RDW batch was diagnosed from* |
| `.6` | `f77c25ce…` | `c29d72e1…` 213 B | **OVERWRITTEN** |
| `.7` | `eac6509c…` | unchanged | survived |
| `.8` | `fae052a2…` | `d2e782e7…` 33010 B | **OVERWRITTEN** |
| `.9` | `c29d72e1…` | `eac6509c…` 170 B | **OVERWRITTEN** |

**No user content was lost this time, and that is luck rather than design.**
Every before-value that was overwritten was itself a test-run log from an
earlier session — `.6`'s `f77c25ce` was a duplicate of `.4`'s, `.9`'s
`c29d72e1` a duplicate of `.1`'s 213-byte stub, and `.8`'s `fae052a2` is the
value this issue's own first table records as *already* destroyed by the run
that filed it. The one file with real user history in it, `.5`, survived both
runs for the same accidental reason: it is 3182 bytes and the slot-picker got
to it after the cases ran out.

Still **FILED, NOT FIXED**. Every T1 run keeps rolling the same dice.

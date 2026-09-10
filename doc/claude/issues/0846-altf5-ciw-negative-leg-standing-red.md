# 0846 — `test_altf5_ciw` fails its NEGATIVE leg: un-bound Alt-F5 still raises the CIW

Status: **OPEN — filed, not fixed.** Found 2026-08-26 while running the CIW suites
as neighbours of the CIW-font change. **The original "pre-existing" attribution is
WRONG — see the 2026-09-08 section at the end, which bisects it to `cc92d0b6`,
the CIW-font commit itself, and answers the "two candidate causes" question.**

## Measured

```
FAIL - un-bound Alt-F5 no longer raises CIW
RESULT: FAIL
```

Dev display `:99`, Xvfb 1920x1080x24, openbox 3.6.1 live, `--pipe -q --logdir`.

**Baselined against HEAD**: `git show HEAD:src/ciw.tcl`, `HEAD:src/xschem.tcl` and
`HEAD:src/cadence_style_rc` restored into the tree gave the **identical single
failure**, so nothing in the CIW-font work (`ciw_font` / `ciw_set_font_size`, the
named `CiwFont`) causes it. Files restored afterwards.

## What the leg asserts

`tests/headless/test_altf5_ciw.tcl` checks the default `Alt-F5 → tools.raise_ciw`
binding is **user-overridable**: after `xschem unbind`, pressing Alt-F5 must leave
the CIW where it was. It does not — the CIW comes up anyway.

## Two candidate causes, neither eliminated

1. **A real unbind defect** — `xschem unbind` not actually clearing
   `tools.raise_ciw`, so the canvas keypress still dispatches.
2. **The test's own settle window.** The file carries a long comment about
   `wm state` being asynchronous: the negative leg deliberately polls for the
   full ~5 s window so a *leaked* raise cannot hide behind the 0–2920 ms lag
   measured on `:0`. If the CIW was already `normal` when the leg started, that
   same window would report a raise that never happened. The suite's own note
   says the false-green it hardens against was **never reproduced**, which is
   exactly the shape of a leg that can also false-RED.

Distinguishing them costs one measurement: record `wm state .ciw` immediately
before the negative leg's keypress. If it is already `normal`, the leg is testing
nothing and (2) is the answer.

## Why it is filed rather than carried

CLAUDE.md: a standing red is a defect, and the one place a real regression hides
in plain sight. This one is named, dated, baselined and attributed — not counted
forward as "a known 1 FAIL".

## Neighbours, all green in the same batch

`test_ciw` (50), `test_ciw_actionlog_output` (25), `test_ciw_autocomplete`,
`test_ciw_interactive_load` (12), `test_ciw_puts_capture`,
`test_ase_log_seam_0207` (48). Note the last three print `PASS: <name>` rather
than a `RESULT:` banner — a `grep -E '^RESULT'` reader scores them as *silent*,
which is how two of them briefly looked dead in this batch.


---

## 2026-09-08 — bisected, and both open questions answered

Found again as an incidental red while auditing the `descend_run_batch`. Two
things above are now settled, and one of them reverses this issue's own headline.

### 1. It is NOT pre-existing. It arrives with `cc92d0b6`.

Measured by `git worktree add --detach <commit>` with HEAD's binary copied in
(the change is Tcl-only, and `XSCHEM_SHAREDIR` resolves to the worktree's `src/`,
so each tree runs its own Tcl):

| commit | | result |
|---|---|---|
| `577ef5bc` | before the notify channel | **ALL PASS** |
| `5dd68128` | notify channel (0650) | **ALL PASS** |
| `36a9b375` | notify (0658) | **ALL PASS** |
| `eec684ff` | notify (0664+0665+0666) | **ALL PASS** |
| `cc92d0b6` | **feat(ciw): make the CIW text size settable** | **FAIL** |
| `89cd3409` | 200-odd commits later | FAIL |
| `19f8e351` | HEAD | FAIL |

`cc92d0b6` is `eec684ff`'s successor for these files and touches exactly four:
`src/ciw.tcl` (+42), `src/xschem.tcl` (+7), `src/cadence_style_rc` (+9), and
**this issue file** (+54).

**And that last one is why the original A/B cleared it.** The section above says
the leg was "baselined against HEAD" by restoring `HEAD:src/ciw.tcl`,
`HEAD:src/xschem.tcl` and `HEAD:src/cadence_style_rc`. But this issue file was
committed *in* `cc92d0b6`, so at the moment that A/B was run **HEAD already WAS
`cc92d0b6`** — the three files were restored to their post-change state. The
change was compared against itself, and of course it looked innocent. A restore
from `HEAD` is a control only when HEAD is the parent.

### 2. The "two candidate causes" question: it is (1), and (2) is refuted.

This issue asked for one measurement — "record `wm state .ciw` immediately before
the negative leg's keypress; if it is already `normal`, the leg is testing
nothing". Run 2026-09-08 on `:99` (openbox live), HEAD binary, `--logdir`:

```
after withdraw #1                 : withdrawn
after Alt-F5 (still bound)        : normal        <- positive leg works
after withdraw #2                 : withdrawn     <- THE ANSWER: not normal
xschem unbind ...                 : rc=0, result "1"   (reports success)
state right after unbind          : withdrawn
immediately after unbound Alt-F5  : withdrawn
after a 1 s settle                : normal        <- the leak
```

So the leg is testing something real (candidate **2 is refuted**), and the
`unbind` reports success while the keypress still raises the pane
(candidate **1 confirmed**).

**A third fact neither candidate predicted, and it is the lead:** the raise is
**DEFERRED**. The CIW is still `withdrawn` immediately after the keypress and is
`normal` a second later. A synchronous dispatch through a binding that was not
really removed would raise it at once. Something *schedules* the raise — an
`after`/idle handler, or a second channel reacting to the keypress — so the next
step is to find what defers it rather than to keep auditing `xschem unbind`.

### Not fixed here

Out of scope for the batch that found it: unrelated file, unrelated subject. It
is recorded rather than carried, per CLAUDE.md's rule that a standing red is a
defect and not furniture — and it is now a *bounded* one, with its cause
narrowed to one commit and one of its two hypotheses eliminated.

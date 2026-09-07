# 1343 — the RDW's raise works on Xvfb and on Xwayland, and not on the server the user actually looks at

*Found by item R3's crew while paying ruling **DD-8** (`doc/claude/rdw_batch/DECISIONS.md`).
Branch `fluid-editing`. Filed 2026-09-05 at HEAD `01fdebc5`. **NOT FIXED.**
It belongs to item R4 / issue 1340, which is closed as FIXED on the strength of
a `:99` run.*

---

## What was measured

`tests/headless/test_rdw_keys_1245.tcl` section **RA** (six rows, item R4's) is
`ALL PASS` on `:99` (Xvfb + openbox). Run against the **user's own X server** —
`$DISPLAY` = `172.20.160.1:0`, vendor string `HC-Consult`, the VcXsrv named in
the report that started this batch — five of the six fail:

```
GUI_GATE=0 ./src/xschem --pipe -q --nolog --script tests/headless/test_rdw_keys_1245.tcl

FAIL: RA1 -> {0 0 0 1 1 .drw 0 1 1 1 0 .drw 0 1 1} (exp {1 0 0 1 0 .drw 0 1 1 1 1 .drw 0 1 1})
FAIL: RA2 -> {0 0 1 1 1 1 1 1 .drw 0}              (exp {1 0 1 1 1 1 1 1 .drw 0})
FAIL: RA3 -> {0 1 summary 0 1 annotation 1 1 1 1 1 1 1 .drw 0}
                                                   (exp {1 1 summary 0 0 annotation 1 1 1 1 1 1 1 .drw 0})
FAIL: RA4 -> {0 0 1 0 1 normal 0 1 normal 1 .drw 0} (exp {0 0 1 1 0 iconic 0 1 normal 1 .drw 0})
FAIL: RA5 -> {0 0 1 1 0}                            (exp {1 0 1 1 0})
```

**Pre-existing, and proved so rather than assumed.** The same run with item R3's
`src/rdw.tcl` replaced by `git show HEAD:src/rdw.tcl` (restored afterwards, `cp`
+ `md5sum` verified) produces the five reds **byte-identically**. R3 changed
nothing about the raise and this is not R3's regression.

Note RA4's own leg: `wm state` answers `normal` where the row asked for
`iconic` — this server does not honour `wm iconify` the way openbox does — and
RA5, the row that checks the shared raise still **activates** for its other four
callers, fails too. So the failure is broader than "the RDW is not on top": the
window-manager side of `raise_toplevel` / `raise_activate_toplevel` behaves
differently on VcXsrv than on either server the batch measured against.

---

## Why this matters more than a display quirk

Ruling **DD-8** exists because *"selection and clipboard are precisely where
servers differ, and the user named VcXsrv in the report"*. That argument is not
special to R3. Issue **1340**'s whole subject is a message to the window
manager, and it is closed FIXED on a `:99` number. Item R4's own suite debt was
recorded for `:0` — which is **WSLg's Xwayland**, a third server, and not the
one the user looks at (CLAUDE.md's three-server table). Neither of those runs is
evidence for the server the request came from.

The user asked for this because *"the Library Manager is raised when one does
Ctrl-Alt-S"* — on **their** screen. If the raise does not happen there, the
feature is not delivered, however green the suites are.

---

## What is NOT yet known

* Whether the Library Manager's own `Ctrl-Alt-S` raise works on that server. If
  it does not either, this is issue **0054**'s territory and older than R4.
* Whether the five reds are one cause or several — RA1/RA2/RA3 are stacking,
  RA4 is `wm state`, RA5 is activation.
* Whether the `wm withdraw` + `wm deiconify` idiom (issue 0054's, which
  `raise_toplevel` carries) is what this server dislikes, or the `after`-deferred
  `_remap_verify` (issue 0843) landing on a different schedule.

The next crew should start by asking whether the Library Manager raises there,
because that answer decides which issue this really is.

---

## Where it lives

`src/xschem.tcl` — `raise_toplevel` / `raise_activate_toplevel` (item R4's
split). `src/rdw.tcl` — `rdw::_raise`, the caller. Rows RA1–RA6 of
`tests/headless/test_rdw_keys_1245.tcl`.

**Status: FILED, NOT FIXED.** A `look` debt is recorded so the user is asked to
watch a dump arrive on their own screen.

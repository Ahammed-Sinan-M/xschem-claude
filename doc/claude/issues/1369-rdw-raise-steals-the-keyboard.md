# 1369 — the RDW's raise kept the keyboard after one click in the window, so the next canvas click sent no dump

**Status: FIXED.** Subject: `src/rdw.tcl` (`rdw::_focus_handback`, the new
`rdw::_focus_click`, one binding in `rdw::build`, three comment blocks). Fenced
by rows **F5** and **F6** of `tests/headless/test_rdw_keys_1245.tcl`
(`KX_FLOOR` 88 → 90) and row **K18** of
`tests/headless/test_rdw_window_1245.tcl` (`RW_FLOOR` 172 → 173); rows **F3**,
**F4** and **KD1** of the keys suite are the fence over the second half of the
fix, and **K16** is re-stated.

## The user's words, verbatim

> Few things broken. When user is in print to RDW mode (1,2,3 key) and then
> clicks on an instance, RDW needs to be raised, but focus should return to the
> schematic window. Else, another click to look at another device's OP info does
> not have intended effect - it just focuses the schematic window and doesn't
> send the OP info for that device to RDW

And, from item 1372's sentence in the same report, the gesture that puts them in
the broken state:

> I put cursor on cgs and the clicked Add button

## What was there — the machinery was complete and its DECISION was wrong

Every part the symptom needs already existed: `rdw::_raise` arms a one-shot,
`raise_toplevel` re-maps the window, `rdw::_focus_handback` catches the window
manager's map-time grant on `.rdw`'s own `<FocusIn>`, and `rdw::_focus_canvas`
gives the keyboard back to the design canvas. Rows RA1–RA4 fence the raise and
rows F1–F4 fence the hand-back, and all of them were green.

The hand-back decided on **exact equality**:

```tcl
set land {} ; catch {set land [focus]}
if {$land ne {.rdw}} { return 0 }        ;# src/rdw.tcl, before this fix
```

**Tk keeps a focus record PER TOPLEVEL.** Once any window *inside* `.rdw` has
held the Tk focus, every later grant to that toplevel is resolved by Tk to that
child: the toplevel receives a `FocusIn` with detail `NotifyVirtual` while
`[focus]` already reads the child. So from the user's first click in this window
onwards, the equality was never true again — the hand-back declined every grant,
the one-shot stayed armed for ever, and the Results window kept the keyboard
after every dump. On a click-to-focus window manager the next canvas click is
then spent re-activating the schematic and never reaches `rdw::pick_click`:
*"it just focuses the schematic window and doesn't send the OP info"*.

## What was measured

All runs on Xvfb + openbox 3.6.1 (`:99`, and a private `:77` for the numbers
below, because the shared dev display had other crews' suites on it and they
flake each other's focus rows). Every launch carried
`--logdir <scratch>/1369`; `/tmp/Xschem.log.8` was never written. Nothing was
mapped on the user's own display; only read-only `xdpyinfo`/`xprop` were aimed
at it.

### 1. Tk's per-toplevel focus record, in a minimal two-toplevel Tk program

Keyboard parked in the other toplevel before each re-map, a real openbox
map-time grant each time:

    record clean          re-map -> FocusIn .t  d=NotifyAncestor  [focus] = .t
    after ONE pane click  re-map -> FocusIn .t  d=NotifyVirtual   [focus] = .t.p

With the shipped decision in that program the dump left the keyboard on `.t.p`
— the user's sentence, reproduced.

### 2. One ordinary gesture writes the record, and `-state disabled` does not stop it

`tk::TextButton1` calls `focus $w` **unconditionally**
(`/usr/share/tcltk/tk8.6/text.tcl:579`); only `tk::EntryButton1` skips a
`disabled` widget (`entry.tcl:356`). So a single Button-1 in `.rdw.p.t` takes
the keyboard, and so does one in `.rdw.s.msg`, which is `-takefocus 0` **and**
`-state disabled`. Measured in xschem itself:

    click on .rdw.p.t    -> [focus] = .rdw.p.t
    click on .rdw.s.msg  -> [focus] = .rdw.s.msg

`src/rdw.tcl` asserted the opposite in a comment ("tk::TextButton1 takes the
keyboard only when the state is `normal`, exactly as tk::EntryButton1"), and
that wrong belief is why the hole was invisible. The comment is repaired.

### 3. The ORDER of `FocusIn` and `ButtonPress` — which the plan called unmeasurable here

Measured through **XTEST** (`libXtst.so.6` via ctypes), so openbox's own passive
grab on Button-1 is really involved. A real click on the pane of an unfocused
toplevel:

    clean record     FocusIn .t d=NotifyAncestor -> ButtonPress .t.p -> FocusIn .t.p
    polluted record  FocusIn .t d=NotifyVirtual  -> FocusIn .t.p     -> ButtonPress .t.p

So on a real click-to-focus WM **the FocusIn arrives BEFORE the press**: a
press-disarm cannot pre-empt the hand-back there. It does not need to — the
click still wins, because `tk::TextButton1`'s own `focus $w` takes the keyboard
straight back. Four candidate decisions driven through real XTEST clicks, with
the record polluted first:

| variant | dump (re-map, armed) | deliberate real click, armed | click, unarmed | dump then click |
|---|---|---|---|---|
| `[focus] eq .rdw` (shipped) | **.t.p, still armed** | .t.p | .t.p | .t.p |
| `winfo toplevel` | .txt, spent | .t.p | .t.p | .t.p |
| `winfo toplevel` + press disarm | .txt, spent | .t.p | .t.p | .t.p |
| `winfo toplevel` + pointer veto | .txt, spent | .t.p | .t.p | .t.p |

Row 1 is the defect; the pointer veto is unnecessary and is not taken (it would
also red F3, whose fixture parks the pointer off every window on purpose).

### 4. Why `:99` cannot reproduce the symptom END TO END, and what that means

Measured in the same minimal program:

    bare re-map                                  -> keyboard moves to the re-mapped toplevel
    re-map + the client's own `focus -force`     -> keyboard stays put, NO FocusIn ever arrives

The dump path ends in `rdw::_focus_canvas`'s `focus -force`, so on this server
the client beats the window manager's map-time grant and the grant never lands.
The consequence for testing is the point: a row that *waited* for the grant
would pass while the defect is live. Rows F5/F6 therefore reproduce the
hand-back's three decision inputs verbatim — `%W` is `.rdw`, `[focus]` is the
child the user's own click left the keyboard on, the one-shot is armed — and
deliver the toplevel `FocusIn` with the detail Tk itself uses for a re-routed
grant.

### 5. The user's own server, read-only

`xdpyinfo -display $DISPLAY` → `vendor string: HC-Consult`, release 210116001.
`xprop -root` → `_NET_SUPPORTING_WM_CHECK: not found`, `_NET_ACTIVE_WINDOW` not
in `_NET_SUPPORTED`, `xwininfo -root -children` → `0 children`. There is no
EWMH window-manager client at all: the window manager lives inside the Windows
X server, so `xschem activate_window` is a no-op there by construction and its
focus rules are not openbox's.

### 6. The interim workaround, before this fix lands

`rdw::close` **destroys** `.rdw`, which frees Tk's record. Measured: after a
close and reopen the dumps hand the keyboard back correctly again — until the
next click in the window.

## What changed

1. **`rdw::_focus_handback` asks which toplevel the landing BELONGS TO.**

   ```tcl
   set land {} ; catch {set land [focus]}
   if {$land eq {} || ![winfo exists $land]} { return 0 }
   set top {} ; catch {set top [winfo toplevel $land]}
   if {$top ne {.rdw}} { return 0 }
   ```

   `winfo toplevel`, not `string match .rdw*`: the glob was already refuted by
   issue 1306 (it matches the pane) and it would also match a sibling toplevel
   named `.rdwfoo`. The `focus_pending` early return and the `%W` cut are
   untouched and stay above it — `--nogui` has no `focus` command at all and
   this proc survives the headless arm only by returning before it gets there.

2. **A new `rdw::_focus_click`, bound to `<ButtonPress>` on `.rdw` in
   `rdw::build`.** A widened landing test can no longer tell the window
   manager's grant from the user's own click into the pane, so the
   discriminator moved to the gesture: a press anywhere in this window spends
   the one-shot without moving the keyboard. It does not `break` and it does not
   touch the focus — the Text class binding after it sets the insert mark and
   the selection anchor that items R3/1339/1344 depend on.

3. **Three comment blocks repaired**, each of which had become false: the
   `-state disabled` claim about `tk::TextButton1`; the hand-back's "the grant
   lands on the TOPLEVEL … every deliberate landing lands on a CHILD"; and the
   "COST, STATED" paragraph, whose wart (a flag left armed for ever bouncing a
   later click) the press disarm deletes.

Not changed, deliberately: `rdw::_raise`'s use of `raise_toplevel`'s
withdraw+deiconify. That re-map is issue 0054's WSLg/Weston workaround and it is
what invites the grant at all — see the ruling below.

## Which rows fence it

| row | file | what it holds |
|---|---|---|
| **F5** | `test_rdw_keys_1245.tcl` | after ONE real Button-1 in the results pane, a dump's grant still hands the keyboard to the canvas and spends the one-shot |
| **F6** | `test_rdw_keys_1245.tcl` | the same for `.rdw.s.msg`, the `-takefocus 0` status surface that pollutes identically |
| **F3/F4** | `test_rdw_keys_1245.tcl` | issue 1306's requirement, now held by the press disarm: the deliberate click keeps the keyboard and can still copy. F3's last leg moves 1 → 0 — the click now SPENDS the one-shot instead of leaving it armed |
| **KD1** | `test_rdw_keys_1245.tcl` | the digit driven at the focus the user's own click leaves — red without the disarm |
| **K18** | `test_rdw_window_1245.tcl` | structural, both arms: `winfo toplevel`, the empty-landing guard, `rdw::_focus_click` present, spending the flag without a `break` and without moving focus, and bound to `<ButtonPress>` in `rdw::build` |
| **K16** | `test_rdw_window_1245.tcl` | re-stated: the shape that outlived the change (a landing read from `[focus]`, no glob, below the headless early return, one-shot spent) |

### Non-vacuity, by sabotage (private display `:77`, md5 restored each time)

| sabotage | RED, by name |
|---|---|
| the whole fix removed (HEAD) | keys **F3, F5, F6**; window **K18** (both arms). F5 → `{1 .rdw.p.t 1 .rdw.p.t 1}`: the window keeps the keyboard, the flag stays armed |
| landing test back to the equality, press disarm kept | keys **F5, F6**; window **K18** |
| `<ButtonPress>` disarm removed, landing test kept | keys **F3, F4, F5, F6, KD1**; window **K18** — issue 1306's defect returns |

## Suites run

`test_rdw_keys_1245.tcl` ALL PASS (90) ×5 on `:77`; `test_rdw_window_1245.tcl`
ALL PASS (184) `--nogui` and ALL PASS (216) on `:77`;
`test_op_param_store_1245.tcl` ALL PASS (130) both arms;
`test_rdw_seam_1245.tcl` ALL PASS (49) both arms.

⚠ The shared dev display `:99` gave 4 different red sets in 8 runs of the keys
suite while other crews' suites were live on it — F1, F3, F4, F5, V3, RA1, RA3,
RA4, RA6 in various combinations, all with `[focus]` reading `{}`. On a private
Xvfb+openbox the same binary and the same suite are 5/5 ALL PASS. A focus row
measured on a shared display while another agent's suite is running is not
evidence.

## The ruling that is the user's (on the owed ledger, `--eyes`)

Whether the RDW's raise should keep using the WSLg re-map idiom on the user's
own screen. `rdw::_raise` calls `raise_toplevel`, whose withdraw+deiconify
exists for WSLg/Weston (issue 0054) — and it is that re-map that makes a window
manager hand the results window the focus in the first place. The user's screen
is a different server: vendor HC-Consult over TCP with **no EWMH window manager
client at all**, so its focus and stacking rules are the ones 0054's measurement
was never taken against. One look settles it: with the Results window buried
under the schematic, does a plain `raise` bring it forward there? If it does,
the raise should take the cheap half on that server — the precedent is
`ase::ui::raise_window_entry`'s `ifhidden` arm (`src/ase_window.tcl:6272`),
whose own comment says a plain raise is what keeps this true "on every other X
server (including the user's own, which is a Windows X server over TCP, not
WSLg)" — and the focus theft disappears at its source instead of being repaired
after the fact. If it does not, the fix above is the whole of what this tree can
do, and the user should say whether one eaten click per dump still happens after
it lands.

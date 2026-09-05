# 1361 — the RDW's chrome line said three things that were not true, and two of its own stated properties were fenced by nothing

**Status: FIXED** (commit on `fluid-editing`, with issue 1360).
**Subject:** `rdw::_chrome_line`, `rdw::_selection_note`, `rdw::build` in
`src/rdw.tcl` — the label issue 1355 added above the pane.
**Why it matters:** rule debt **1355** was in the user's queue asking them to
RATIFY these sentences. Two of the three chrome variants were measurably false;
had the debt reached them first they would have ratified untrue text.

## (a) "Keys 1/2/3:" named a keyboard that does not exist outside the cadence profile

`src/xschem.tcl:17638` adds `Tools > Results Display Window` **unconditionally**;
the four bare-digit binds live in `src/cadence_style_rc:181-184` alone (ruling
D-2). MEASURED on `:99` with no cadence rc sourced: the Tools entry is present
and its command is `rdw::open`; `bind .drw <Key-1>`, `<Key-2>`, `<Key-3>` and
`<Key-4>` are all the EMPTY STRING (and `bind all <Key-1>` too); real Key-1/2/3
events on `.drw` leave `::rdw::listkind` where it stood — and the window
displayed `Keys 1/2/3: ...` anyway. False on **every** open of this window
outside that profile, and NEW (pre-fix there was no label at all).

**FIXED**: `rdw::_keys_bound` asks the canvas's own bindings for `rdw::key` —
the one thing those binds call, and it has no other caller — and
`rdw::_chrome_text` takes the answer as an argument, so the prefix and the
`press 1 or 2 to edit a list` advice appear only where the keys do. Without
them the line opens `Showing ...`. **REJECTED**: gating on a profile flag; the
binds are what the user's fingers meet, and an rc that rebinds them, a profile
that does not source cadence_style_rc, and a future menu route all then give the
same honest answer.

## (b) "only Add works here" was false — Save is enabled on list 3 and writes to disk

`rdw::button_state` returns `normal` for `save` on **every** kind. MEASURED on
the user's own `tb_bandgap` with list 3 in force: `up=normal down=normal
delete=disabled add=normal save=normal`; a real press on Save answered
`Save: wrote the operating-point parameter lists to <dir>/.xschem/
op_param_lists.conf` and the file existed, **1627 bytes**. Two of five buttons
do something on list 3 and the one the sentence excluded writes a settings file.

**And nothing in the tree tested Save's success arm at all** — `grep -rn
'_do_save|wrote the operating-point parameter lists' tests/headless/*.tcl`
returned nothing — which is why the false literal could be golded with no row to
contradict it. **PROVED BACKWARDS**: an adversary edited the sentence to be TRUE
and got `1 FAILED (162 passed)`, RED = `LX4` exactly, on both arms. One row
golded the falsehood and nothing else in either suite had an opinion.

**FIXED**: `rdw::_active_buttons` is the ONE answer to "which buttons do
something on this identity" (greyed, or refusing on identity grounds like Up and
Down on list 3), `rdw::_active_phrase` words it in the button column's own
labels, and the chrome quotes it. The sentence now reads
`only Add and Save do anything here.`

## (c) "the buttons edit this list" was false on the summary list

`rdw::_edit_list add summary` answers `annotation` (spec 4.2 B7). Row **LX2**
golds exactly that; row **LX3** golds the scope dialog sentence that says it out
loud; **LX4**, three rows away, golded a chrome literal asserting the opposite —
and Add is ENABLED on summary, so the user sees the button under the false
sentence. A real press answers `Add: id is already in the mos annotation list.`

**FIXED**: `rdw::_chrome_add_note` derives the exception from the same
`rdw::_edit_list` / `rdw::button_state` pair, so the summary line carries
`Add writes the annotation list.` and the annotation line — where Add is greyed
— states no exception. If issue **1357** is ever ruled the other way the
sentence follows the code.

## (d) FENCE GAP: `rdw::_selection_note`'s `< 2` boundary

The proc is documented and defended as "silent at 0 and 1 lines". `BT31`'s
control leg removes the `sel` tag entirely and `LX11`'s legs are `{}` / `0`, so
only the ZERO case was ever driven. An adversary changed `< 2` to `< 1` and both
suites stayed green — `test_rdw_window_1245` ALL PASS (179),
`test_rdw_keys_1245` ALL PASS (85) — while an ordinary drag WITHIN one row
(`sel 5.0 5.8`, one line, the select-a-value-to-copy-it gesture this window
exists for) now appended the whole lecture to every verdict.

**FIXED**: `rdw::_selection_note_for {n}` is the pure boundary and row **LX15**
drives it at 0, 1, 2 and 16 on both arms.

## (e) FENCE GAP: `rdw::build`'s two `listkind` reads were dead, behind a comment naming a fence that does not fence

`build`'s own `wm title .rdw [rdw::_title $listkind]` and
`.rdw.hdr -text [rdw::_chrome_line $listkind]` are unreachable in effect:
`build` ends in `rdw::apply_list_state`, which sets both. Their source comment
claimed row LX7/LX8's close-and-reopen leg as their fence; an adversary gutted
both lines and every suite stayed green **and** the live close+reopen came back
byte-identical, because the leg was really fencing `apply_list_state`. By this
file's own standard (LX4's "a sentence that outlives its fact is this file's own
1312 scar") a comment claiming a fence that does not fence is the same species
one layer down.

**FIXED by deleting them**, which is invariant I1's own answer — one setter for
one fact. `.rdw.hdr` is created with no `-text` and nothing between there and
`apply_list_state` pumps the event loop, so the label is never painted empty.
Row **LX16** asserts `build` names neither builder, reads `listkind` not at all,
and calls `apply_list_state` exactly once.

## Fences added
`LX12`, `LX13`, `LX14`, `LX15`, `LX16` of
`tests/headless/test_rdw_window_1245.tcl` (both arms; `RW_FLOOR` 154 -> 162 with
issue 1360's three rows) and `LK3` of `tests/headless/test_rdw_keys_1245.tcl`
(`KX_FLOOR` 87 -> 88), which takes the prefix off the REAL binds of the REAL
canvas — removing them, watching the label drop the prefix, and putting them
back.

**LX4 is now a wording row, not a fence.** It golds the exact literals at
`keyed 1`, and its own comment says so: LX12, LX13 and LX14 assert each clause
against the code it describes, because a golden is not a fence for a sentence.

## Sabotages, each restored by `cp` with the md5 verified after
| sabotage | red |
|---|---|
| `SB4b` `_active_buttons` drops `save` on lists 1 and 2 | `LX12` exactly |
| `SB4` `_active_buttons` stops consulting the greying table | `LX12` `LX14` `LX4` |
| `SB9` `rdw::button` stops routing Save to `rdw::_do_save` | `LX12` exactly |
| `SB5` `_chrome_add_note` returns `{}` while `_edit_list` still sends Add to annotation | `LX13` `LX4` |
| `SB6` `_keys_bound` always answers 1 | `LX14` exactly (window); `LK3` exactly (keys, `:99`) |
| `SB7` the note's boundary moves to `< 1` | `LX15` exactly |
| `SB8` a second `wm title` setter back in `build` | `LX16` exactly |

## One thing this fix changes on screen, and it is the user's call
The summary chrome line is 30 characters longer, and the label's requested width
drives the toplevel. MEASURED on `:99` (Xvfb 1920x1080x24, openbox 3.6.1),
non-cadence wording: the window is **893x498 on lists 1 and 3 and 971x498 on
list 2**, so it grows 78 px when the user presses 2 and shrinks back on 1. In
the cadence profile the summary label measures 978 px, so the window would be
about 986. Side effect: the status entry grows 887 -> 965 px on the summary
list, which is 80 px short of the 1045 px issue 1356's own sentence needs.
Recorded as look debt `rdw_1361_chrome_width_measured`; NOT decided here.

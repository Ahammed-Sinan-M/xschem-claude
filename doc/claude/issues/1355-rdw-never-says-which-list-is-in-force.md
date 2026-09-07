# 1355 — the Results window never says which list is in force, and the scope dialog names no list on lists 1 and 2

**Status: FIXED, 2026-09-05.** The user's SECOND complaint, in their own words:

> When I use **2 key**, the RDW doesn't say "summary" view, so it's not clear.
> The fact that the Delete button is NOT greyed out is a clue. … I … press
> Delete and get the pop up dialog asking where to apply, but it doesn't say
> "summary list" — which would be good for the user to know.

## What was measured, at HEAD `d81b4b24`, after the narrowing (issue 1353) had landed

On the user's own `M18:/x1/x1` of `tb_bandgap`, driven on `:99` through
`devdisplay.sh exec` with the user's own raw and `.opinfo`:

* the window **title** was `Results Display Window` on all three identities;
* the **status line** was EMPTY on the whole dump path — `rdw::key` →
  `rdw::show` → `rdw::dump` → `rdw::dump_devpath` → `rdw::push` calls
  `rdw::status` on no arm;
* `.rdw` had exactly three children — `.rdw.s .rdw.b .rdw.p` — and none of them
  named a list;
* the **real scope dialog** raised by a real Delete was **byte-identical on
  annotation and on summary**: `.rdw.scope.q` = *"Delete on M18: which devices
  should this change?"*, two scope radiobuttons, OK, Cancel, and **no `.q2` at
  all**. The word `summary` appeared nowhere in it. Only list 3 named a list,
  and only because it has to ASK.

So the entire on-screen encoding of a three-valued identity was
`rdw::button_state`'s two booleans over five buttons, wordlessly — and lists 1
and 2 differ by exactly ONE of them, the **Add** button. The Delete grey the
user reached for separates list 3 from the other two and says nothing about 1
versus 2. **Their clue was true evidence for "not list 3" and no evidence at all
for "I am on summary."**

## What the block already said, and why it was not enough

Issue 1353's `rdw::_narrow_line` names a list — *"Narrowed to the mos summary
list as it stood at this dump"* — and row NW10 deliberately put it **in the
block**, because the block is what the user pastes into a design review.

That is a **different fact**. It is PAST tense and it is about THE BLOCK. The
chrome is PRESENT tense and about THE BUTTONS: `::rdw::listkind` is what Up,
Down, Delete and Add obey, and a key press moves it **without re-rendering
anything**. Press `2` without re-dumping and the pane still says `annotation`
over buttons acting on `summary`. That gap is the failure the user fell into,
and no wording of the block's sentence closes it.

## The fix

Three surfaces, **one builder each and no fourth**:

* `rdw::_list_name` / `rdw::_list_gloss` / `rdw::_list_phrase` — the list's
  name and its parenthetical, one table each. The scope dialog's two
  radiobuttons had been carrying those two glosses as **literals**; they now
  read the accessor, so the strings exist once.
* `rdw::_chrome_line` → a new `::label` **`.rdw.hdr`**, full width, above both
  the pane and the button column.
* `rdw::_title` → `wm title`, the SECOND surface: it survives the pane being
  scrolled or the window being small, and it is what an alt-tab shows.
* `rdw::_scope_statement` → **`.rdw.scope.q2`** as a **STATEMENT** on lists 1
  and 2, in the exact slot and with the exact padding list 3 uses for its
  QUESTION. The dialog now names a list in all three states instead of one.

Both new surfaces are refreshed by **`rdw::apply_list_state`** — the proc that
was `rdw::apply_button_states`, renamed because it now does more than buttons.
It is the **one** proc `rdw::set_list` calls, so a key press cannot move the
buttons without moving the words (invariant **I1**).

**`rdw::build` now reads the `listkind` it has DECLARED since item B4 and never
used.** The consequence was measurable: `::rdw::listkind` outlives the window,
so a window closed on the summary list and reopened came back titled for no
list at all.

## ⚠ The statement names the list the edit will WRITE, not the identity in force

Spec §4.2 B7's Add cell: *"summary list (2): **add to annotation**"*. MEASURED
on the user's own M18, standing on summary with the dialog naming no list:
`Add: gm is already in the mos annotation list` — a verdict about a list the
window had given them no reason to think they were editing. Naming
`::rdw::listkind` in the dialog would have printed *"the summary list"* over a
write into the annotation one, which is worse than the silence it replaces. So
`rdw::_edit_list` is the ONE answer to "which list", read by `rdw::button`'s
default, by `rdw::scope_dialog`'s pre-set choice and by the statement. Whether
Add SHOULD behave that way is **issue 1357**.

## ⚠ What the chrome deliberately does NOT say

The diagnosis that proposed this line proposed a second sentence — *"The pane
shows every row this run published"* — and said in the same breath that it must
be **deleted** when the narrowing landed. **The narrowing landed first (issue
1353), so the sentence was never written.** A window that went on telling the
user the pane is wider than the list after it stopped being true would be the
same defect this file already carries a scar from: `rdw.tcl`'s status line
citing a FIXED issue 1312 as its reason. Row **LX4** is the fence.

## What was rejected

* **The status line.** Cheap (one golden), and it is already the only place the
  word `summary` reaches the screen today — but only AFTER a successful edit
  (*"Delete: removed gm from the summary list…"*), which is the complaint
  restated: the window tells you which list you were on once it is too late to
  check. It is also the **button column's receipt channel** (this file's own
  comment: a button that does something and says nothing cannot be told from a
  broken one), and MEASURED, the very first button press replaces the field —
  so a list label written at key time is destroyed exactly when the user is
  pressing the buttons whose meaning depends on it.
* **A per-block label** (issue 1300's option (c), re-costed). Half of it landed
  in 1353 as the past-tense narrowing sentence; the other half — a present-tense
  label on a standing record — is what the chrome exists to avoid.
* **More or different button greying.** The greying is DERIVED state and it is
  correct: spec 4.2 B7 says Delete removes from the summary list, and a real
  Delete on summary really does move the store (measured). What was missing is
  the state it is derived FROM. The Add-greyed-versus-absent choice remains the
  user's, on the standing ledger row `1245_B3_add_greyed_on_list1`.

## Fences

Section **LX** of `tests/headless/test_rdw_window_1245.tcl` (LX1..LX11, eight of
them on both arms), row **BT31** of the same file, and section **LK** of
`tests/headless/test_rdw_keys_1245.tcl` (LK1, LK2 — the real keys and the real
modal). `RW_FLOOR` 144 → 152 and `KX_FLOOR` 83 → 85 in the same commit. Every
row proved by a sabotage that reds it; row **W1**'s title golden moved with the
change and is the only pre-existing golden this fix touched.

## The decisions taken on the user's behalf — rule debt 1355

1. **The exact wording** of the three chrome sentences and the two dialog
   statements. User-visible text; the user has ruled on every other sentence in
   this window (`1245_B3_window_wording`, `1245_B5-2_ten_button_sentences`).
2. **The title as a second surface**, at the cost of one golden row.
3. **"Keys 1/2/3:" as the chrome's opening**, i.e. a claim about the IDENTITY
   the keys chose rather than about the CONTENT on screen.
4. **Naming the TARGET list rather than the identity in force** in the dialog.

**Read alongside issue 1300** (the standing `[1300]` ledger row, which carries
other ratifications this does not touch), **1353** (the narrowing), **1356**
(what Delete acts on) and **1357** (which list an Add writes).

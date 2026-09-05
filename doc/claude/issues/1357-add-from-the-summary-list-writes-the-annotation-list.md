# 1357 — Add pressed on the SUMMARY list writes the ANNOTATION list

**Status: FILED, NOT FIXED. The behaviour is the spec's and is unchanged; what
changed is that the dialog now says so.** Rule debt **1357**.

## What was measured

On the user's own `M18:/x1/x1`, `:99`, real widgets, at HEAD `d81b4b24`:
standing on the **summary** list, cursor on `gm`, press **Add**. The scope
dialog named **no list at all** (issue 1355), and the verdict came back:

> Add: gm is already in the **mos annotation list**.

`rdw::button`'s `deflist` was `[expr {$id eq {add} ? {annotation} : $listkind}]`
— hardcoded `annotation` — while `rdw::scope_dialog` had simultaneously pre-set
`::rdw::list_choice` to `summary`. The second value is inert (the radio group
exists only on list 3), but the two disagreed about the same fact, which is one
refactor away from being live.

## It is the spec

`doc/claude/specs/op_param_lists.md` §4.2 **B7**, the Add row:

| button | annotation list (`1`) | summary list (`2`) | all (`3`) |
|---|---|---|---|
| **Add** | — | **add to annotation** | add to **annotation or summary** (the dialog asks which) |

So the code is conformant and this issue changes no behaviour.

## What issue 1355 did about it

* `rdw::_edit_list {op kind}` is now the ONE answer to "which list will this
  edit write", read by `rdw::button`'s default, by `rdw::scope_dialog`'s pre-set
  choice and by the dialog's own statement — three consumers, one builder.
* The dialog **says it out loud** on lists 1 and 2:

  > This changes the annotation list (drawn on the sheet). Add writes there even
  > from the summary list - press 3 first to choose the list.

Row **LX2** golds the accessor; sabotaging it (`_edit_list` answering the
identity in force) reds **LX2, LX3, BT16 and BT27** — so the accessor really is
the live decision and not decoration.

## THE RULING OWED

**Should an Add pressed while the SUMMARY list is in force add to the summary
list instead?** A user standing on summary reasonably expects it to. Against
that:

* the spec was written the other way on purpose, and the `all` list's dialog is
  where the choice belongs;
* since the narrowing (issue 1353) the pane on lists 1 and 2 shows **only rows
  the list already declares**, so an Add from a narrowed pane can only ever
  answer *"already in the list"* whichever list it targets. **The working path
  is: press 3, click the row, press Add** — and the chrome line added by 1355
  now says so on list 3.

Changing it costs one line of `rdw::_edit_list`, one golden row (LX2), the B7
table cell, and a re-word of the dialog statement's second sentence. **Not taken
without the user**, because it is their spec and their expectation that
disagree, not the code and the spec.

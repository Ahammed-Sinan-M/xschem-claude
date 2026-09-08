# 1381 — three decisions the multi-row press had to take, and the hygiene rows that read a user's own settings file as litter

**Status: BUILT and MEASURED; three decisions await a ruling. The hygiene half
is FIXED.** Rule debt **1381**.

## Part 1 — the three unratified decisions

The user's instruction (issue 1356) was:

> When multiple lines of parameters are selected and user presses Add or
> Delete, those should get processed the same way that a single line would get
> processed.

That settles *what happens to the selected rows*. It does not settle three
things the build had to decide anyway. Each is user-visible, each has a
defensible alternative, and each is shipped in the reading below — but the
choice was the user's to make, so it is recorded here rather than left in a
commit message.

### D1 — a selection covering ONE parameter row wins over the shaded row

**Shipped:** the selection is the target whenever it covers **at least one**
parameter row. No threshold.

**The alternative:** require **two or more** parameter rows before the selection
takes over, so a one-row drag stays the copy gesture and the shaded row keeps
the buttons. That is not arbitrary — `rdw::_selection_note_for`'s own boundary
is at two lines, for the stated reason that "one line is the
select-a-value-to-copy-it gesture this window exists for".

**Why the shipped reading:** a threshold puts a discontinuity where the user
cannot see one — drag over one row and the shaded row is edited, drag over two
and the selection is. Acting on what is visibly highlighted is the reading that
cannot surprise. **The cost:** a user who highlights a value to copy it and then
presses Delete without clearing the highlight edits the highlighted row rather
than the shaded one. The status line names what it did, so the surprise is
visible immediately and is one Add away from being undone — but it is a real
change to a gesture that has shipped.

### D2 — a partial batch proceeds and reports, rather than refusing whole

**Shipped:** every row the core can act on is acted on; every row it refuses is
named with the core's own reason. Ruling DD-10 is the one exception, and it is
asked of the whole batch **before the first write**, so the destructive partial
case — five deleted, refused on the sixth, no undo — cannot happen.

**The alternative:** all-or-nothing. Any row the core would refuse refuses the
whole press.

**Why the shipped reading:** the promise made when the feature was a ruling was
specifically about *invisible* partial application. Selecting six rows of which
one is a column no list declares, and being refused entirely because of it, is
frustrating in a way the DD-10 case is not — nothing is lost by proceeding, and
the sentence says exactly what did not happen and why.

### D3 — a multi-row press leaves no cursor

**Shipped:** after a batch of more than one, the shading is cleared.

**The alternative:** shade the first row of the batch, or the row the press
started from.

**Why the shipped reading:** ruling DD-1's own argument, one case further on. The
press acted on N rows; shading any one of them is a cursor the user did not put
there, chosen by nothing but list order, and the next press would act on it
without a word. A batch of ONE keeps today's behaviour exactly.

### Not a decision — stated for completeness

A selection crossing two dumps is **refused**. This is not really a choice:
`rdw::scope_dialog` names one instance in its question, one cell on its narrow
radiobutton and one class on its broad one, so a press that answered that
question and then wrote for a second device would make the dialog a false
statement. The sentence names the classes when they differ and the dump count
when they do not. Row **BT40**.

## Part 2 — the hygiene rows that read a user's own settings file as litter

**FIXED in the same change.**

Three rows asserted that `<repo>/.xschem` — or the file inside it — did not
exist:

| suite | row |
|---|---|
| `test_rdw_window_1245` | `BT9` (`[file isdirectory [file join $repo .xschem]]` → 0) |
| `test_rdw_keys_1245` | `SD4` (`[file exists .../op_param_lists.conf]` → 0) |
| `test_op_param_store_1245` | `H1` (`[file isdirectory ...]` → 0) |

That was true only for as long as nothing ever **saved** one. It is a legitimate
user artifact: the RDW's Save button with project scope writes exactly
`<pwd>/.xschem/op_param_lists.conf` by design, and since issue **1380**
`op_param_lists::load` reads it back at startup. So a developer who had used the
feature in their own tree redded three suites *for having used the feature*.

**And the obvious way to green them again is to delete the user's file.** That
is not hypothetical — it happened in this session, on 2026-09-07 at 20:14: the
assistant quarantined `<repo>/.xschem/` having decided from a red row and a
glance at the file's header that it was litter from its own probe runs. It was
the user's Save: a nine-parameter summary list for class MOS. It was restored
with its mtime intact and nothing of theirs had been overwritten, but the "No
such file or directory" the user then hit was the assistant, not the tree.

**The fix is a snapshot, not an absence.** Each suite takes the file's identity
(size + mtime, or the token `ABSENT`) before anything runs and compares it at
the hygiene row. What the rows actually mean is "this suite wrote nothing here",
which is true whether or not the developer has a file of their own, and which no
longer has a green state that costs the user data.

## Still owed

* **A two-process fence for issue 1380.** No suite caught a save that was never
  read back, because a round trip needs two processes and every store row in
  this tree is single-process.
* **A pixel look at the multi-row press.** The suites drive real widgets on
  `:99`, but nobody has watched a real drag over real rows on a real screen.
  Recorded as a `look` debt.

## Read alongside

Issue **1356** (the ruling and what was built), **1380** (the save that was
never read back — the same file, the other direction), **1338** (the open half:
blocks already in the pane follow a list edit), and ruling **DD-10** in
`doc/claude/specs/op_param_lists.md`.

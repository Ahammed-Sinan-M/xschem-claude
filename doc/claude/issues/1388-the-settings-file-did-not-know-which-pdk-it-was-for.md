# 1388 — the settings file did not know which PDK it was for

**Filed** 2026-09-08, item C of the RDW UX batch
(`doc/claude/rdw_ux_batch/CREW_BRIEF.md`).
**Status** FIXED, with one live rule debt and one look debt.
**Files** `src/op_param_lists.tcl`, `sky130A/cadence_style_rc`,
`gf180mcuD/cadence_style_rc`, `ihp-sg13g2/cadence_style_rc`,
`tests/headless/test_op_param_store_1245.tcl` (section PK),
`doc/claude/specs/op_param_lists.md` §4.4.

## 1. The user's words, 2026-09-07

> And the 3rd thing: When saving config - such as parameter lists
> Eg. `/home/analog/dev/xschem-claude/.xschem/op_param_lists.conf` - the PDK
> should be taken into account - user might want something different for sky130
> and gf180mcu. A given launch, with a set of libraries will not have more than
> one PDK included

Shown two shapes, they **RULED: one file, PDK sections**, spelled `[pdk
sky130A]`, and *"PDK section beats the un-scoped rows above it"*.

The rejected alternative is **one file per PDK**
(`op_param_lists.sky130A.conf`). Its argument is real and is recorded here so
it is not re-derived: it needs **no grammar change at all**, and a launch
**physically cannot read another PDK's rows** because it never opens that file.
It loses on the two things the user actually asked for — one file to find, hand
edit and share, and a place to see all your PDKs' lists side by side — and it
multiplies the two-tier path resolution (issues 1273, 1325, 1327) by the number
of PDKs.

## 2. What was actually measured, because three of the four candidates die

The brief named four candidate identities. Measured 2026-09-08 by sourcing each
of this tree's three workarea rcs in a live `./src/xschem` on `:99` and printing
what is set:

| workarea | `env(PDK)` | `env(PDK_ROOT)` | `::PDK` | `::PDK_ROOT` | `XSCHEM_LIBRARY_PATH` | descriptors |
|---|---|---|---|---|---|---|
| `sky130A` | `sky130A` | **UNSET** | `sky130A` | `/home/analog/eda/tools/share/pdk` | **`{}` (EMPTY)** | `nmos pmos` |
| `gf180mcuD` | `gf180mcuD` | **UNSET** | UNSET | UNSET | **`{}` (EMPTY)** | `nmos pmos` |
| `ihp-sg13g2` | `ihp-sg13g2` | **UNSET** | UNSET | UNSET | **`{}` (EMPTY)** | `nmos pmos vertical_npn` |

1. **`env(PDK)` wins.** All three rcs set it (`if {![info exists ::env(PDK)]} {
   set ::env(PDK) <name> }`), the values are distinct, and they are the names a
   person types. Note the IHP one is **`ihp-sg13g2`**, not `sg13g2`.
2. **`env(PDK_ROOT)` is set by none of them.** `sky130A` sets a *Tcl global*
   `::PDK_ROOT`, and its value is the directory that **holds** PDKs. It is a
   **location, not an identity**: with sky130 and gf180 installed side by side
   in one open_pdks tree it is the same string for both, so keyed on it every
   PDK would share one section called `pdk`. Rejected.
3. **`$::XSCHEM_LIBRARY_PATH` is EMPTY in all three.** Every workarea is
   registry-only Cadence mode and sets `set XSCHEM_LIBRARY_PATH {}`. It does
   not distinguish the three PDKs; it distinguishes **nothing**.
   `XSCHEM_LIBRARY_DEFS` does differ, but it is a path to a `library.defs`, and
   taking a PDK *name* out of it means guessing which path component is the
   PDK — the invention ruling D-4 forbids. Rejected.
4. **The registered `op_annot` descriptors cannot tell sky130A from gf180mcuD,
   which is the user's own example.** Both register exactly `{nmos pmos}` and
   both declare byte-identical `{id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2}
   {vth vth 2} {vds vds 2}`. Only IHP differs. The most *semantically honest*
   candidate is the one that cannot answer the question that was asked.
   Rejected.

## 3. The defect the identity work uncovered, and it is the real one

**The PDK is not known when the settings file is read.**

`catch {::op_param_lists::load}` (`src/xschem.tcl:17550`) runs while
`xschem.tcl` is being **sourced**. A PDK workarea is entered with `--script
<ws>/cadence_style_rc`, which `xinit.c:3793` sources **after** that. Measured:
the probe printed `env(PDK) = <UNSET>` at the *top of the `--script` phase*,
which is already later than the load. This tree's own **PDK launcher**
(`tools/launcher/pdk_launcher.tcl`) launches exactly that way and does not
export `PDK` either.

So a per-PDK settings file, done naively, would have skipped every section as
"some other PDK's" for **every launch this tree can make**, and every row of a
suite that drove the store directly would still have been green.

**Two supported orders, both real:**

* **(a) `PDK` exported in the environment before launch** — the open_pdks
  convention. `load` sees it; no code needed. Row PK21 drives this end to end
  in three fresh processes.
* **(b) the workarea rc declares it** — `op_param_lists::set_pdk`, which
  **re-reads the two tiers** because the first read could not have known. The
  three shipped `cadence_style_rc` files now call it, guarded, beside the
  `env(PDK)` line they already had. Row PK11 pins the wiring; row PK7 pins that
  the re-read is *exact* (byte-identical to a process that knew its PDK from
  the start).

Rejected: making `load` lazy so it happens after the rc.
`xschem.tcl:17532`'s own comment rules that out — "initial state" would then
depend on which door the user opened first.

### 3a. …and the second defect, which only a real launch found

`set_pdk` first asked *"did `pdk` change across my own write?"* — before and
after its own `set pdkoverride`. **The shipped rcs set `env(PDK)` FIRST and
declare SECOND**, so by the time `set_pdk` ran, `pdk` already answered
`sky130A` out of the environment: before and after were **equal**, the re-read
was skipped, and the section was silently lost. Measured end to end in a
project directory whose conf carried a `[pdk sky130A]` section, launched
against the real `sky130A/cadence_style_rc`:

```
AT-STARTUP pdk=          mos={id id 0} {gm gm 1}
AFTER-RC   pdk=sky130A   mos={id id 0} {gm gm 1}      <- the section LOST
```

**Every store row was green for it.** The suite's fixture declared through the
override alone — never through the environment — so "before" really was empty
there. This is the batch's own warning arriving in person: *a row that passes
for an unstated reason is a row that will pass again for the wrong reason.*

The fix is not a better comparison, it is a **different question**. "Has the
PDK changed" is a question about **the rows in the store** — *they were read
under X, the launch is now Y* — so the store records `loadedpdk`, the PDK the
last `load` actually ran under, and `set_pdk` compares against **that**.
`reset` clears it (the rows are gone); it is *not* the same as un-declaring the
PDK, which `reset` deliberately does not do. Row **PK7b** drives the rc's exact
order; with the old comparison put back, **PK7b is the only row that reds**.

After the fix, the same three launches over the same file:

```
sky130A     AFTER-RC pdk=sky130A     mos={id id 0} {gm gm 1} {gmbs gmbs 1}
gf180mcuD   AFTER-RC pdk=gf180mcuD   mos={id id 0} {vth vth 2}
ihp-sg13g2  AFTER-RC pdk=ihp-sg13g2  mos={id id 0} {gm gm 1}     (no section)
```

## 4. What was built

* **`[pdk <name>]` section headers**, and **`[pdk *]`** to return to the rows
  that apply to every PDK. Rows above the first header are un-scoped.
* **A row with no PDK applies to every PDK.** That is what every row in every
  existing file is, so backward compatibility needed no migration and gets
  none.
* **PDK-specific beats PDK-neutral, as a RANK, not as file order** — the
  section wins wherever it sits. Implemented by reading the file in **two
  passes** (un-scoped rows, then this PDK's) so the *existing* "first touch of
  a key clears what came before" machinery answers it with no rank field
  anywhere. An earlier draft made it file order and "PDK section beats the
  un-scoped rows" was then false for exactly the user who puts their section
  first.
* **A row for another PDK is never parsed into the store at all** — the same
  structural move DD-7 makes about provenance. No store key gains a PDK field,
  nothing merges two PDKs, and `effective`, `governs` and `apply` are
  untouched. The user's own constraint (one PDK per launch) is what buys that.
* **A malformed header poisons its section** rather than leaving its rows
  un-scoped: applying rows the user wrote for one PDK to *every* PDK is the
  leak this whole item is about, so applying them to nothing is the safe
  direction. Reported once, on the header's own line.
* **A section that is not this launch's is reported once, as information** —
  "read and not applied", naming both PDKs. Silence about a dozen skipped rows
  would be the first question the user asks.
* **No PDK detected is not an error.** A PDK-less launch reads the un-scoped
  rows and `[pdk *]`, and behaves exactly as before.
* **The version does not move.** `version 2` files are completely correct under
  this grammar; a bump would report a mismatch at every launch about a file
  with nothing wrong with it, and DD-11 would then rewrite the user's version
  line for no behavioural reason. **The price, stated:** an *older* xschem
  reading a sectioned file reports the header as an unknown keyword, skips it,
  and then applies the section's rows to every PDK. A sectioned file is
  shareable with a teammate on this build or newer, and wrong-not-broken on an
  older one.

## 5. The rule debt — WHICH SCOPE A SAVE WRITES INTO

> ⚠ **The ledger entry for rule debt 1388 now carries TWO questions.** This
> section is question 1. Question 2 arrived with the repair pass and is
> §8.3's stated price: a launch with **no PDK at all** is no longer told at
> startup why its `[pdk ...]` sections did not apply. Both are the user's.


**What was built (option 2):** a Save **edits the rows where they already
are** — in this launch's `[pdk ...]` section when the file already has rows for
that list there, otherwise in the un-scoped rows, which is byte-for-byte what
it did before this item. **It never invents a section.** Per-PDK lists are
opted into by typing one header, once; the emitted header says so in one line.

Chosen because the batch's first non-negotiable is that an existing conf keeps
working unchanged and is not rewritten into the new shape behind the user's
back — and this file has already been lost once in this tree's history (issue
1380/1381). The user's real nine-row file is untouched by every path here.

**The options, for the user to settle:**

1. **A Save under a PDK always writes into that PDK's section**, creating it.
   Delivers their sentence most literally. Costs: a file whose owner never
   asked for per-PDK anything grows a `[pdk sky130A]` section on their first
   Save; the un-scoped rows are stranded as a stale list that a PDK-less launch
   still reads back; and the status line then has to name the section, which
   today it deliberately does not (it makes no scope claim at all, so it cannot
   disagree with the file's own header).
2. **Edit the rows where they are** — what shipped.
3. **A middle: any `[pdk ...]` header anywhere in the file flips that file into
   option 1.** One hand-edit opts the whole file in. Rejected for now because
   the rule is spooky at a distance — a header at the bottom silently changes
   where an unrelated list is written — and cannot be stated in one line of the
   emitted header.

If option 1 or 3 wins, `rdw::_do_save`'s status line must gain the section it
wrote; that is the same question, not a second one.

## 6. The look debt

**The emitted header now has TWO precedence axes to explain.** They are
**two short labelled paragraphs**, not one interleaved one: `PDK SCOPE:` sits
above the existing `PRECEDENCE among 'flavor' rows:` paragraph, which is
untouched **including its `e.g.` lines** because suite row F5 reads that worked
example back out of a freshly written file and builds its case from it.

Only the user's eyes can say whether the header is still readable rather than a
wall of text. A green suite is not an eyeball. **An existing file never gains
the new paragraph** — the prose is the user's, only the `version` line is
xschem's (DD-11) — so the look debt is about what a *fresh* file says.

## 7. Rows (section PK of `tests/headless/test_op_param_store_1245.tcl`)

`OL_FLOOR` 135 → **151**; the suite runs 158 and is ALL PASS on both arms.

PK0 the identity as the shipped workareas declare it · PK1 one definition of
this launch's PDK · PK2 an old file loads unchanged **and silently** · PK3
neutral applies everywhere, a PDK row beats it, and it leaks to no other PDK ·
PK4 the axis is a rank, not file order · PK5 a malformed header poisons its
section · PK6 `[pdk *]` really un-scopes · PK7 a late declaration re-reads
exactly, and never over the user's own edits · **PK7b the shipped rcs' own
environment-then-declare order still re-reads** — the row minted by §3a · PK8
Save edits the rows where
they are and invents no section · PK9 an appended list gets the un-scoped scope
back · PK10 another PDK's section is never rewritten · PK11 the three workarea
rcs really declare it · PK12 what did not move · **PK20 / PK21 the two-process
fence**.

**The fence is what issue 1380 was owed.** Every other row in this file, and
every row of section T, proves something about *one* process; 1380's defect was
that `op_param_lists::load` had **zero callers in `src/`**, so Save wrote the
file, said so truthfully, and the next session started empty — and a green
suite said nothing. PK20/PK21 write in one process and read in another, through
the **startup path alone**: the children call neither `load` nor `load_conf`.

**Adversary, six sabotages, every one caught by the row that names the
property:**

| sabotage | red |
|---|---|
| `_scope_applies` always 1 (the PDK filter is dead) | PK3 PK4 PK6 PK7 PK9 PK10 PK21 |
| one pass instead of two (the axis becomes file order) | PK3 PK4 PK7 PK10 PK21 |
| no `[pdk *]` restore before an append | PK9 |
| the writer always edits the un-scoped rows | PK8 |
| one workarea stops declaring its PDK | PK11 |
| **`catch {::op_param_lists::load}` commented out — the 1380 defect itself** | **PK20 PK21** |
| `set_pdk` compares `pdk` before/after its own write (§3a's defect) | **PK7b, and PK7b alone** |

PK2 stays green under the first two, correctly: an old file has no sections, so
the filter and the pass order are irrelevant to it. That is the row doing
exactly what it says.

---

## 8. THE REPAIR PASS, 2026-09-08 — what an adversary found after §7 was written

Sixteen rows were green, the feature worked end to end in three real workareas,
and **two blockers and two majors were live**. Every one of them was a place
where the code was right about the PDK and wrong about something the PDK work
sat on top of. They are recorded here in full, because the shape repeats: *a
new axis that borrows an old axis's machinery inherits that axis's answers.*

### 8.1 BLOCKER — the two passes inverted flavor file order (axis 3)

`keyorder` is the list `governs` walks to decide **which flavor glob wins on a
cell**, and ruling DD-8's answer is FILE ORDER. It was being appended to by the
two phase passes that implement the PDK rank, so it became **phase** order: a
`flavor` row inside *this launch's own* `[pdk ...]` section was always tried
**after** every un-scoped one. It lost while sitting **first** in the file and
while being the PDK-specific row — the exact shape of the brief's own example.

```
version 2
[pdk sky130A]
param flavor mos *nfet_01v8_lvt* annotation A id 0
[pdk *]
param flavor mos *              annotation B gm 1
```

| file | `governs mos annotation sky130_fd_pr__nfet_01v8_lvt` |
|---|---|
| as above | `flavor {mos *}` — the broad, lower, **un-scoped** row |
| both headers deleted | `flavor {mos *nfet_01v8_lvt*}` |

That made **the prose the writer stamps into every new settings file** — "THE
FIRST ONE IN THIS FILE WINS … put the row you want to win ABOVE the other one"
— measurably false for every sectioned file. A file lying to its own reader is
the exact failure `_header_lines`' own comment records two earlier attempts
making, and the sentence fence built to prevent it (row **F5**) stayed green
because **F5's fixture has no sections**.

**Fixed** by seeding `keyorder` **in file order, in one pass, before** the two
phase passes, with `_row_id` — the same row recogniser the writer uses. The two
axes now answer in different places: **axis 2 decides which rows fill a key,
axis 3 decides which key answers a cell.** Rows **PK13** (F5's own worked
example read back out of the emitted header and driven through a sectioned
file, in both orders, plus the no-PDK launch) and **PK13b**.

### 8.2 BLOCKER — the same two files answered differently on the rc path

`set_pdk`'s re-read ran **on top of** the existing store, on the strength of
"first touch of a key clears what came before". That rebuilds every key's
**content** and leaves `keyorder` holding the first read's positions with the
second read's new keys appended after them.

| how the PDK arrived | winner — user tier `[pdk sky130A] flavor mos *nfet_01v8_lvt*`, project tier un-scoped `flavor mos *` |
|---|---|
| `PDK=sky130A xschem` — environment first, one read | `*nfet_01v8_lvt*` |
| the shipped `cadence_style_rc` — read, **then** declare | `*` |

and **the rc is the default path for all three PDKs this tree ships**. This
falsified `set_pdk`'s own comment ("the end state is identical to a launch that
knew its PDK all along") and PK7's word "byte-identical"; PK7 and PK7b were
green because their fixtures have one `class` key and no flavor key in the user
tier.

**Fixed** by making the re-read `reset` first — safe, because `set_pdk` already
refuses when anything is dirty, and `reset` deliberately keeps `pdkoverride`
(the declaration) and `applied` (issue 1292's undo). Row **PK13b** compares the
two arrival orders' **key order**, not only their contents.

### 8.3 MAJOR — every rc launch printed a FALSE sentence about the user's own PDK

The startup `catch {::op_param_lists::load}` runs before the rc can name the
PDK, so it reported **every** section as skipped "because this launch has no
PDK" — including the one applied one line later — and `set_pdk`'s re-read then
reported the remaining sections **again**. Measured, three sections:

```
:3: the rows under `[pdk sky130A]`    … this launch has no PDK      <- FALSE
:5: the rows under `[pdk gf180mcuD]`  … this launch has no PDK
:7: the rows under `[pdk ihp-sg13g2]` … this launch has no PDK
:5: the rows under `[pdk gf180mcuD]`  … this launch is PDK sky130A  <- again
:7: the rows under `[pdk ihp-sg13g2]` … this launch is PDK sky130A  <- again
```

**Fixed** two ways, because there are two duplications:

* `load_conf` gained an optional trailing **`provisional`** (required arity
  unchanged, row J5). A read is provisional when it has **no PDK and nothing
  has been read yet** — i.e. the startup restore, the one read a `--script` rc
  can still supersede. A provisional read says **nothing about sections**. The
  `bad`-header arm is *not* gated: an unreadable header is a fact about the
  FILE, true whoever reads it.
* `_say` gained an **echo gate** (`echoskip`, filled by `set_pdk` for the
  duration of its own re-read) so a **row's** complaint — a malformed line, an
  unknown keyword — reaches the terminal once instead of twice. It gates the
  echo only; `said` still receives every sentence, so nothing that counts
  reports moved and no existing row changed.

Measured after, all three shipped workareas, over a conf with three sections
and one malformed row:

```
sky130A     :5 gf180mcuD  :7 ihp-sg13g2     mos={SKYROW sky 1}
gf180mcuD   :3 sky130A    :7 ihp-sg13g2     mos={GFROW gf 2}
ihp-sg13g2  :3 sky130A    :5 gf180mcuD      mos={IHPROW ihp 1}
```

Two lines each, one per **other** section, none naming its own. Row **PK14**
counts them in a **child process**, because the echo is stderr and a
buffer-only assertion would score the duplicate green.

⚠ **PRICE, STATED AND UNRATIFIED-BY-NOBODY-BUT-WORTH-SAYING.** A launch with no
PDK **at all** — someone who started outside their workarea with sections in
their file — is no longer told at startup why those sections did not apply. The
no-PDK wording stays live for a direct `load_conf` (an import is nobody's
provisional read). The alternative was a false sentence on every workarea
launch this tree ships. If the user wants the startup diagnostic back it is one
`elseif`, and it would have to name the uncertainty ("no PDK **yet**").

### 8.4 MAJOR — the writer's protection against an unreadable header was unfenced

`_scope_applies`'s `bad` arm is the only thing stopping the **writer** rewriting
rows under a header this reader could not parse. **PK5 looks like that fence and
is not**: the reader had a *second* mechanism (its phase loop tested `[lindex
$scope 0] ne $phase`, and `bad` matches neither pass), so with `_scope_applies`
sabotaged to accept everything, PK5 stayed green, the whole suite stayed green,
and the writer **destroyed the user's rows**:

```
### shipped                            ### with the sabotage (suite ALL PASS)
[pdk sky 130A]                         [pdk sky 130A]
list  class mos summary                list  class mos summary
param class mos summary OLD old 0      param class mos summary NEW new 1  <- OLD GONE
[pdk *]
list  class mos summary
param class mos summary NEW new 1
```

**Fixed** on both sides. The reader now asks **one** predicate —
`_scope_applies`, then the new `_phase_of` purely as a *partition of scopes
that already apply* — so the same sabotage now reds PK5 as well (measured: 12
red with `_phase_of`, 11 red with the old two-test form, and PK5 is the
difference). Row **PK5b** is the writer's own fence and reds either way.

### 8.5 The minors, and what happened to each

| minor | disposition |
|---|---|
| `_pdk_why`'s comment claimed whitespace was "the one refusal" while a second (`]`) sat under it, and deleting the `]` arm left the suite green | **FIXED.** The comment now states both refusals *as one rule* — a name this file could not write back — and row **PK1b** drives the round trip `_scope_header` → `_section_of` in both directions. |
| `_scope_header`'s `pdk` arm has **zero production callers** | **STANDS, now fenced.** It is the writing half of the one place a header is spelled, and rule debt 1388 option 1 is its caller the moment the user rules for it. Deleting it would leave the reader able to parse a shape the writer has no word for — how `_row_id` and `_parse_line` drifted in issue 1294. **PK1b is its caller until then**, and the comment says so. |
| `forget_pdk`'s "⚠ IT DOES NOT RE-READ" unfenced — replacing the body with `return [load]` left the suite green | **FIXED.** Row **PK1c**: after `forget_pdk` the identity is gone and the ROWS are not. (It also reds PK5b, which is fine — the row is specific about which half it owns.) |
| the tier/PDK interaction is unreported, unrowed, and absent from the emitted header | **FIXED.** Three lines added to the header's PDK paragraph, and row **PK15** holds the code and the sentence to each other. The interaction itself — the tier is outermost, so a project-tier **un-scoped** row beats a user-tier `[pdk X]` one — is **unchanged and deliberate**; it is now stated where the user reads it instead of only in the source. |

### 8.6 What the repair pass did NOT change

* The user's real `<repo>/.xschem/op_param_lists.conf` — `b44502645a24de79d225d3a64db55d5b` before and after every run in this pass, and `~/.xschem/op_param_lists.conf` `5096063f37cf4424665e9c93aed5eb6e`, untouched.
* The grammar version (**2**), the section spelling, `[pdk *]`, the conservative Save, the poisoning of malformed headers in the reader, and "no PDK is not an error".
* The **rule debt** of §5 — which scope a Save writes into — is still live and still the user's.
* `effective`, `governs` and `apply` still take no PDK argument and no store key gained a PDK field.

**`OL_FLOOR` 151 → 158.** Seven new row names (PK1b, PK1c, PK5b, PK13, PK13b,
PK14, PK15), fifteen sabotages caught, all on both arms.


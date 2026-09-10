# Why the operating-point annotation feature produced 351 issue files

*A teaching post-mortem. The subject is a feature that works — it puts the right
numbers on the right transistors — and that cost **351 of this tracker's 956
numbered issue files (37%)** to get there, over **23 days**. The reader is assumed to be a
competent engineer who did not live through it. The goal is that they finish able
to recognise these shapes in their own work, in code that has nothing to do with
schematics or SPICE.*

*Two narrow companions already exist and are not repeated here:*
`1243_op_values_differ_between_runs.md` *(a reported wrong-number that turned out
to be `agauss` in the testbench, and the discipline that established it) and*
`1244_op_param_list_measurements.md` *(the measurement transcript the parameter-list
feature was specified on top of). The general lesson about green suites predates
this feature by six weeks:* `lessons_green_is_not_correct.md`, *commit `568297ed`,
2026-07-03. Read that one first if you only read one.*

---

## 1. What the feature is

A circuit designer draws a schematic, runs a SPICE simulation, and wants the
operating point of every transistor written **on the sheet, next to the
transistor** — drain current, transconductance, threshold voltage — plus the same
numbers in a side window they can copy out of. That is the whole product.

The chain that does it, end to end:

| # | stage | code |
|---|---|---|
| 1 | user presses `6`, or a menu item, or a `tclcommand=` button drawn on the schematic | `utils/annot_mode.tcl`, `src/xschem.tcl:18080` and `:18523`, 61 committed `.sch` files |
| 2 | the simulator layer renders a SPICE deck, emitting one `.save` card per device per parameter — **468 cards** on the user's bandgap bench | `src/ase.tcl` |
| 3 | ngspice runs and writes a `.raw` file | third party |
| 4 | a C reader parses the raw into `xctx->raw` — `names[]`, `values[][]`, `cursor_b_val[]` | `read_raw_data_block()`, `src/save.c:639`+ |
| 5 | `update_op()` publishes one point into the per-instance annotation slots | `src/save.c:3590`+ |
| 6 | a Tcl layer formats the rows; three render back ends draw them | `src/op_annot.tcl` (3,962 lines), `src/draw.c`, `svgdraw.c`, `psprint.c` |
| 7 | a Results Display Window shows the same numbers, editable and copyable | `src/rdw.tcl` (6,823 lines), `src/op_param_lists.tcl` (2,040 lines) |

Two facts about this chain shape everything below.

**The first is that the naming convention lives in ngspice's head.** A FET's
transconductance in a raw file is spelled
`@m.x1.xm1.msky130_fd_pr__nfet_01v8[gm]`. There is no schema, no header, no
declaration; the prefix, the device-class letter, the model name and the
bracketed parameter are a convention you learn by reading raws. Every layer that
needs a name therefore *reconstructs* it. The spec's central rule, **invariant
I1** (`doc/claude/specs/op_annotation.md:534`), exists exactly for that: *"the
save-card generator and the display derive their names from the same builder …
If they ever build names independently they will disagree, and the failure is
silent."*

**The second is that "which parameters?" has more than one answer, and the
feature never wrote down how many.** By the end there were four consumers of one
stored field:

| consumer | asks | code |
|---|---|---|
| `op_annot::register` | *what did the PDK declare?* | `src/op_annot.tcl:507` |
| `op_annot::_cards_for` | *what should the simulator compute?* | `:3159` |
| `op_annot::text` | *what should the sheet draw?* | `:2049` |
| `op_param_lists::seed` / `_params` | *what is the PDK's own list, to reset to?* | `src/op_param_lists.tcl` |

Those are four different questions. For three weeks they read one field. Section
3.2 is the story of what that cost.

The feature does work. Measured on `tb_bandgap`:
`id = 4.944u | gm = 7.749u | gds = 9.592u | vgs = 1.805 | vth = 1.017`, with all
365 node voltages surviving. **346 issue files is not 346 broken things** — and
the next section says what it is instead.

---

## 2. The numbers

**Scope.** Measured on the **committed** tree at `b0d19af9`, because the tracker
grows while you read it — this number moved three times during the writing of this
document, once because a live crew added a file mid-audit. So it is stated with
the command that produces it, and a reader who gets a different answer should
trust their own run and the sha, not this paragraph:

```sh
git ls-tree -r --name-only HEAD doc/claude/issues/ | sed 's|.*/||' \
  | grep -cE '^[0-9]{4}'                                    # 956  numbered files
for f in $(git ls-tree -r --name-only HEAD doc/claude/issues/); do
  git show HEAD:"$f" | grep -qE 'op_annot|op_param_lists|rdw::|rdw\.tcl|read_raw_data_block|update_op|annotate_op|annot_show' \
    && echo "$f"
done | wc -l                                                # 351  of them
```

**351 of 956 = 37% of the whole tracker for one feature.** Three files under
`doc/claude/issues/` are not numbered issues at all — `NUMBERING.md`, `status.md`
and `status_annotate.md` — and are excluded from the denominator; two of them
match the pattern and are excluded from the numerator too.

⚠ **956 files carry only 948 distinct numbers.** Six numbers own two files each
and one owns three (`0054`, `0264`, `0436`, `0442`, `0466`, `0494`). That is worth
noticing before you quote either figure: "how many issues" and "how many issue
files" are different questions in this tracker, and the gap is itself a small
instance of §7's point about the tracker indexing conclusions rather than facts.

**Distribution by number block** (blocks are roughly chronological; 0500–0599 and
0700–0799 are reserved for other branches):

| block | files | what was being built |
|---|---|---|
| 0000–0299 | 5 | the substrate: the raw reader, ASE-L, the waveform viewer |
| 0300–0699 | 130 | the name builder, the PDK descriptors, the save-card emitter, the chords, the visibility mask |
| 0700–0999 | 92 | what a number *means*: which plot, which run, which corner — then the deck and the simulator registry |
| 1000–1399 | 124 | the declutter, the parameter-list store, the Results Display Window, and first contact with a user |

Sum: **351**. The blocks are coarse on purpose — 0500–0599 and 0700–0799 are
reserved for other branches and hold a handful of matching files each, so a finer
table invites the reader to read chronology into a numbering scheme that does not
carry it.

**Status,** parsed from the first `Status` line of each file, testing the
keywords in the order OPEN → "not fixed" → FIXED → SUPERSEDED → CLOSED:
**109 FIXED, 127 OPEN, 29 "NOT FIXED", 8 CLOSED, 4 SUPERSEDED**, and 69 with no
parseable status. ⚠ **That split moves by tens if you test the keywords in a
different order** — many headers say both ("OPEN … not fixed"), so this tally is
a shape, not a measurement. And the OPEN count is unreliable in both directions
for a second reason — see §5.5.

**Timeline.** First commit `44f1c886` (2026-08-16, "the one raw-vector name
builder"); last in scope `a7cfa479` (2026-09-07, "this tree could not photograph
its own dialogs"). 374 commits on the branch from that first
date through HEAD (369 strictly between the two shas); 52 of them touch the three
Tcl files above.

**Test mass.** Seven suites, **41,761 lines**, against ~12,800 lines in the three
core Tcl files plus the C changes — 3.3:1, or 2.6:1 if you also count
`utils/annot_mode.tcl`'s 3,047 lines, which stage 1 of the table above does.
Red-before-green and sabotage variants on most rows either way.

| suite | lines |
|---|---|
| `tests/headless/test_op_annot.tcl` | 16,381 |
| `test_rdw_window_1245.tcl` | 8,944 |
| `test_op_param_store_1245.tcl` | 5,222 |
| `test_rdw_keys_1245.tcl` | 4,862 |
| `test_annot_declutter_1244.tcl` | 4,423 |
| `test_rdw_seam_1245.tcl` | 1,077 |
| `test_op_dump_altshow.tcl` | 852 |

**The defect rate did not fall as the feature matured — it fell when the batch
stopped.** Dating issues 1238–1381 by the commit that added each file: 25, 24, 39
and 35 over 2026-09-02 to 09-05, then 9 and 5 as the batch wound down. Four days
at a steady 24–39 a day, on a feature already three weeks old. What changed over
that window was not the rate but *who found them*.
Issues 1238–1336 are 97 files, issues 1337–1381 are 45. Grepping each set for
the user-report idioms ("reported by the user", "in the user's own words", …)
gives **2 of 97 (2%)** in the first and **17 of 45 (38%)** in the second — a
keyword proxy, and the classification is soft at the margins, but the step is far
larger than the proxy's error. The first phase
was mostly about a store nobody was calling yet.

**And a large fraction of the count is scrutiny, not breakage.** The 0800–0999
block holds 200 issue files, and 116 of them name a verification, sabotage or
adversary pass in their body — an over-count, because some merely cite one, but
the "Found by" line names such a pass far more often than it names a user. Reading the raw issue count as a
quality signal would be a serious misreading of this tracker. Reading the *open*
count as a backlog, however, is fair, and that number is the uncomfortable one.

**Outstanding at HEAD:** `tests/headless/owed.sh count` → **115 rule debts, 47
look debts, 4 suite debts**. A rule debt is a user-visible decision the machine
took and queued for a human to ratify. A look debt is a pixel deliverable nobody
has looked at. **39 of the 47 look debts name the RDW, the declutter or the
parameter lists outright**; four more are the same feature under other words
(two RDW items known only by their item numbers, the `Waves > Op Annotate` entry,
and the 1364 annotate-on-your-own-bench debt), leaving four that are not this
feature at all.

---

## 3. The failure shapes

Ranked by what they cost — crew runs burned, user-visible damage, days open.

---

### 3.1 Failure is a legal value

**The shape.** At every layer, a failure is encoded as something the next layer
cannot distinguish from a measurement. The result is that this feature's failure
mode is not an error dialog. It is a confident wrong number on a schematic, in a
design review.

**The instance: issue 0299, still live at HEAD.** `read_raw_data_block()` reads a
binary raw. The block comes up short. Here is what it does, at
`src/save.c:711-721` — two arms of one `if`, four lines apart:

```c
    if(binary) {
      if(fread(tmp, sizeof(double), rawvars, fd) != rawvars) {
        dbg(0, "Warning: binary block is not of correct size\n");
      }
    } else {
      if(read_raw_ascii_point(ac, tmp, rawvars, fd) != rawvars) {
         dbg(0, "Warning: ascii block is not of correct size\n");
         res = 0; /* issue 0213: a short point is a read failure */
         break;
      }
    }
```

The ASCII arm refuses. The binary arm warns and carries on with a **reused
buffer**, so the final point is a byte-level splice of the previous one, the
header's point count is still reported in full, `xschem raw read` returns success,
and every consumer downstream sees a complete dataset. **ngspice writes binary by
default.** The arm that was hardened is the arm fixtures use; the arm that ships
is the one that fabricates numbers.

**Why the structure invited it.** Two independent causes, and neither is
negligence.

*The reader was inherited.* `git log -1 b7e39700` → stefan schippers, **2024-11-06**,
"add ability to read ASCII raw files" — twenty-one months before this project's
first annotation commit. Upstream's error policy for a malformed raw is "log it
and carry on", which is entirely defensible for a **waveform viewer**, where a
bad point is a bad pixel. The annotation feature layered a *decision* on top of
it — publish this number onto the schematic, or don't — without ever giving the
reader a way to refuse. Nobody chose this. It arrived with the substrate.

*The report and the answer travel on different wires.* Note that the warning is
not suppressed. `src/util.c:265`:

```c
void dbg(int level, char *fmt, ...)
{
  if(debug_var>=level) { ... vfprintf(errfp, fmt, args); ... }
}
```

`debug_var` defaults to 0 and `errfp = stderr` (`src/xinit.c:1252`), so all **65**
`dbg(0, …)` sites in `save.c` really do fire on every run. They fire to a stream
a GUI user launched from a desktop menu does not have. *"Add a warning" was never
the fix, and "raise the debug level" would have changed nothing.* The tree's
eventual answer — build a notice channel the user can actually see (0650, 0653,
0658) — cost three days and produced nine defects of its own (0664–0667,
0674–0677, 0699).

And under the C, the value type has no representation for absent. `cursor_b_val`
is `my_calloc`'d, so an unfilled slot holds `0.0`, which is also a perfectly good
voltage. The type is the bug.

**Other instances.**

| issue | what a failure looked like |
|---|---|
| 0861 | the shipped `devices/scope_ammeter.sym` printed a confident **`0`** — zero amps through the branch — whenever nothing had been published. Fixed `57eaa18d` |
| 0922 | its unfixed sibling: an expression trace's new column initialises to 0.0 while `annot_p` stays 0, so 0861's guard is true and the number is still invented |
| 0807 | `annotate_op` **destroys** the loaded database on a truncated read and returns `TCL_OK` with the path. `raw loaded` goes 0 → −1 and `raw switch op` still answers 1 over the emptied slot |
| 0429 | ngspice's own silence: one `.save` card for a device the deck does not contain writes a **full column of `0.0` named exactly what was asked for**, at exit 0. Under the `.control`/`write` idiom every shipped PDK bench uses, it writes **no raw at all**, also at exit 0 |
| 0157 | `resolved_net {A,B,GND,VCC}` answers `VCC` — every element resolved before a global is silently discarded, because the global branch *replaces* the accumulator where the normal branch appends |
| 0856 / 0862 | a transient's t=0, and a DC sweep's first step, published as "the operating point" |
| 1330 | `rdw::_apply_now` wraps three calls in bare `catch`es and returns `{}`; the status line reports success. Measured `APPLY_NOW_RC = 0`, `EDIT_BEFORE_APPLY = 1` |
| 1276 / 1286 / 1378 | `write_conf` returns 1 with zero reports while the bytes land somewhere the user never named |

**How to recognise it elsewhere.** Ask of every component you adopt: *what does
it return when it fails, and is that value on the same wire as its answer?* If
the answer and the failure travel on different wires, every caller you write is
already wrong. Three specific tells:

- an accessor that answers the empty string for both "you asked wrong" and "the
  value is empty" (`xschem get <unknown-key>` does exactly this — issue 0392: a
  typo, `xschem get selection`, silently answered 0 and every gate built on it
  passed);
- a numeric type with no NaN discipline and no per-column validity bit, feeding a
  renderer;
- a function that reports success **by convention** rather than by measurement.
  That is the silent-failure engine, and it needs no logging level to hide.

The tree's eventual countermeasure is worth stealing. **Ruling D5-1**: never a
number displayed next to a thing it was not measured for — cited by 54 of the 200
issue files in one era, which makes it the era's single dominant defect class.
And a **three-state** rendering, so absence is visible: `-` = nothing loaded,
blank = refused, digits = published. Never a shared `0`.

---

### 3.2 One field, N readers. One verb, N doors.

**The shape.** A decision assigns a meaning to a stored field, or wires a
behaviour into "the one place" something happens, without enumerating who else
reads that field or reaches that place. This is the shape that burned the most
crew time in the whole project.

**The instance: DD-4 → DD-6 → DD-13, the same mistake three times.** The batch
driver wrote the confession himself, and it is the single most portable paragraph
in this tree. `doc/claude/op_param_batch/DECISIONS.md:494`:

> ### ⚠ THE PATTERN, STATED PLAINLY, BECAUSE IT IS MINE
>
> * **DD-4** said `apply` writes the union into `params` and the display narrows.
>   One field, two meanings. Refuted: `op_annot::text` and `_cards_for` read the
>   same list.
> * **DD-6** split off a display key. Two fields. Refuted: `seed`/`_params` reads
>   `params` too, and it is a **third** consumer with a **third** meaning.
> * **DD-13** splits off the declaration. Three fields.
>
> Each time I reasoned about what the lists *mean* and did not enumerate **every
> reader of the field** before ruling. […] **The rule for any future ruling that
> assigns meaning to a stored field: grep every reader FIRST, list them, and say
> what each one will now see.** Two of the three refutations here cost a full
> crew run.

The consequences were not theoretical. Issue **1280** — *"the most consequential
of the six B2 seam defects, because its symptom is a blank number on a schematic
with no report anywhere"* — is `apply` silently narrowing the deck's `.save`
cards. Issue **1314** is the wired Delete button destroying the PDK's own
declaration while it removed a row. Issue **1285** was filed by the item
*implementing* DD-4, *against* DD-4.

Note what the winning design does. In DD-13's three fields, `declared` is written
by `op_annot::register` **only**, and `apply`'s body never names that key — so
`apply` is *structurally incapable* of destroying a declaration. The guarantee is
built, not asserted.

**The same shape in control flow: issue 1364.** Issue 1333 wired the blanket
operating-point dump into `op_annot::db_attach`, and justified the placement in a
source comment:

> `db_attach` is the **one** place that puts an operating point onto a window.

Issue 1364's verdict: **"That sentence was false, and its falseness was the
defect."** Its door table has nine rows. Two reached `db_attach`. The seven that
did not include 61 committed schematics' launcher buttons, both *Annotate
Operating Point into schematic* menu items (built twice, once per menubar),
`Waves > Op Annotate`, `results::select`, and the raw carried into a new tab. The
measured consequence, on a real run that exited 0 with a perfect raw:

```
    xschem annotate_op <raw> 0 op
    op_annot::text M1  ->  id  = 409.7u
                           gm  =
                           gds =
                           vgs =
                           vth =
                           vds =
```

Five of six blank — **issue 0617 restored**, on a run that exited 0 with a
perfect raw. (0617 is the right citation and the wrong verb: its *emit* half was
closed by S3+S4, its *display* half has read "STILL OPEN" since an attempt was
refuted on 2026-08-23, and 1364 is the symptom arriving through a third door
while both halves stood. A symptom can return without its issue ever having been
closed, which is worse, not better.) And the one row that *did* appear is an
accident, not the feature: `.options savecurrents`
puts `i(@dev[id])` in the raw with no card present. The value that arrives by
chance survived; the feature's own five vanished.

The fix moved the merge into `update_op()`, the tree's actual choke point, and
the comment it left behind is the lesson (`src/save.c:3561`):

> ⚠ WHY HERE. `update_op()` is this tree's own choke point […] **Wiring the doors
> one at a time is what issue 1364 IS.**

**The chain tell.** This shape announces itself: the follow-up issue's title is a
count.

| chain | what each link found |
|---|---|
| 1252 → 1260 → 1266 | the declutter gate fresh at one `symbol_bbox()` caller and stale at **the other 38**; then two more doors plus the mask half; then a **fifth** door that does not call `symbol_bbox()` at all, which is why the choke-point fix could not reach it |
| 1276 → 1286 → 1378 | `write_conf` reports success when the bytes go elsewhere. Fixed for directories and relative symlinks; then found in `ase::sim_write_conf`, **the writer it was copied from**; then a third case (`<path>.new` itself a symlink) **in both writers**. Four days first fix to last |
| 0163 → 0164 → 0166 | three issues on one loop in one function, each opened because the previous fix was measured against the wrong authority. **0166 is still OPEN**; two implementations of the same lookup are still live, `src/hilight.c:2903` reading `hier_attr[level-1].templ` against `src/token.c:4432` reading `hier_attr[currsch-1].templ` |
| 0511 / 0513 / 0853 | one line of C, three issue numbers, and a fourth derivation recorded as a worked-around hazard in a `save.c` comment. §5.1 |

**And the subtler axis: two builders can agree on the spelling and disagree on
the basis.** Issue 0436 reverted a complete S3 implementation because
`devpath`'s hierarchy prefix comes from `sim_sch_path`, which is relative to *the
level where the raw was loaded* — the right basis for reading a vector, the wrong
one for writing a deck-absolute save card. The spec's amendment is blunt
(`op_annotation.md:3515`): *"'one builder' was under-specified and it reverted a
complete implementation. **One builder, but it must take a BASIS.**"* They
coincide only when no raw is loaded or the raw is at the top, which is the only
state 85 green checks ever exercised.

**How to recognise it elsewhere.**

1. Before any ruling that assigns meaning to a stored field: grep every reader,
   list them, write what each will now see. A field with N readers is N contracts
   until proven otherwise.
2. Before writing "X is the one place that does Y" in a comment: produce the
   caller table and paste it into the commit. That sentence is a **census**, and
   a census taken by grep is not a census — indirection, a language boundary and
   a suite that is green for the wrong reason each defeat source reading
   independently. (Issue 1377 was filed as "four suites", a first grep round made
   it six, and an **empirical sweep of all 383 headless suites made it
   eighteen**. `test_ase_hier_pick_0161` — 7 FAILED — contains none of the
   grepped tokens; it reaches the registry through three proc hops, none spelled
   in the file.)
3. When you declare "one builder", write its **signature**. A prohibition is
   satisfiable by a function with the wrong parameter list.
4. When you copy a function, the defects come with it. Fix the original in the
   same commit, or file it with a number that same hour.

**And the uncomfortable corollary about I1 itself.** The invariant was written to
prevent silent **drift** — two builders answering one question differently by
accident. It was then read as a prohibition on **divergence** — two consumers
legitimately asking different questions. The user's own word for this feature is
*declutter*: draw fewer rows while still saving them. That is divergence, and it
is correct. Because I1 forbade a second builder, the design reached for a second
*meaning on one field* instead, which is strictly worse: a field with two meanings
has no owner and no test can state its contract. **The invariant was a
contributing cause of the defect it was written to prevent.** If your invariant
says "one X, never two", name the consumers and ask whether they are allowed to
want different answers. If they are, the invariant belongs on the *builder* and
the divergence belongs in the *data* — a second field, named, owned and tested.

---

### 3.3 The green fence around nothing

**The shape.** A check can be green because the code is right, or green because
the fixture cannot reach the code at all. From outside they are identical.

**The instance: five attempts at one step, three of them green.** Step S3 — the
save-card emitter — was implemented, verified, and **reverted four times**:

| attempt | outcome |
|---|---|
| 1 | 85 checks, 11 sabotage variants. Reverted: raw-relative names where the deck needs absolute (`f3bded23`, issue 0436) |
| 2 | 96 checks, 8 sabotage variants. Reverted: it filtered **three of the netlister's seven drop classes** while asserting in a boxed source comment that it "EMITS ONLY WHAT THE NETLISTER WOULD" (`cc7a4083`, issue 0442) |
| 3 | interrupted before Verify ran; preserved as a `.patch` (`ce07064e`) |
| 4 | **275 headless / 281 xvfb checks against a 241/246 baseline, with 17 of 17 sabotage variants red.** Reverted (issue 0494) |
| 5 | landed 2026-08-22, `7088e8a8` |

Attempt 4 is the sharpest datum in the record. It was not refuted by more tests.
It was refuted by running it on `sky130_tests_ase/tb_bandgap_opamp` — **a shipped
bench** — instead of the synthetic hierarchy the suite used.

**Why the structure invited it.** Rows are written after the code, by the person
who wrote the code, against whatever fixture is nearest. Three distinct ways a
row goes hollow, all of them documented here:

*A fixture that cannot exhibit the answer.* Issue 0499: row W19 asserted the
"never modifies the schematic" invariant against a `.sch` the test itself wrote at
`file_version 1.2`, where it holds; on a shipped 3.4.8RC bench the same assertion
fails. Section X called `save_cards` at `currsch 0`, where the read basis and the
deck basis produce the same empty prefix — so the exact defect that killed
attempt 1 was structurally invisible to it.

*A row whose name claims a property its body does not test.* Issue 1283: the
RDW's new suite pushed **one** block and asserted it was at index 0 — true under
either ordering. The store's newest-first order had no headless witness at all.

*A row measuring a proxy.* Issue 1248 is the cleanest specimen in the tree. Row
I2 of `test_annot_declutter_1244.tcl` carries in its own source
`## ⚠ ITEM A3 MUST REPLACE I2 — after A3 the two exports MUST differ`, and
asserts the SVG export is byte-identical at `annot_show` 1 and 9. It is. So is
*every* pair, because the fixture `xschem_library/examples/nand2.sch` has no
operating point loaded:

```
VACUITY nand2 fixture, bytes 25405: 0=1 1=1 2=1 3=1 8=1 9=1 11=1
```

The row written to force the next item to replace it could not notice that item
at all. In the same file, sabotage SB5 was predicted to red six rows and redded
**one — a source grep, not a behaviour**, because the proc's own
`catch {xschem update_all_sym_bboxes}` tail repairs the mirror one statement
after the sabotage.

**The rule this tree wrote, and then footnoted.** `op_annotation.md:3749`,
landmine 11:

> ⚠ **A CORRECT ORACLE ASKED THE WRONG FIXTURE PROVES NOTHING** — this is how
> BOTH S3 attempts shipped a refuted deliverable past a green suite.

The operative half is the corollary: **a sabotage variant whose predicted red
does not appear is a fixture defect, to be fixed before the change lands — not a
lucky pass and not a prediction error to be footnoted.** Attempt 4 produced three
such tells and footnoted all three.

**How to recognise it elsewhere.** Three habits, all cheap:

- **The non-vacuity control.** Before asserting that A and B produce the same
  output, prove your fixture can make them produce *different* output. A row that
  would pass on an empty file is not a row.
- **Make the name and the body assert the same property.** To test an ordering,
  push two objects.
- **Run one acceptance row against a shipped artefact**, not a synthetic one.
  Sabotage coverage proves your rows can see *your code*; it says nothing about
  whether your fixture is shaped like a user's design.

And check the structural questions first — each of these took one grep and each
was worth more than a hundred green checks: *is my suite in the runner?* (0465:
`grep -c op_annot tests/run_regression.tcl` → **0**, with the whole feature's only
guard behind it) *does my fixture exist in a fresh clone?* (0634: a row depending
on a gitignored, untracked `bandgap_opamp~.sch`) *does my seam get counted before
or after the early returns?* (0474: `annot_overlay_count` bumps before three
early returns, so it cannot distinguish "drew it" from "decided to draw it and
then culled it").

---

### 3.4 The arm you tested is not the arm that ships

**The shape.** For almost every axis of this feature, the fixtures pinned a
variable to the value that is easiest to build by hand — and the value that ships
is the other one. Each choice was locally reasonable. Each removed the one
variable the defect lived in.

| axis | the arm fixtures use | the arm that ships | the defect |
|---|---|---|---|
| encoding | ASCII raw | **binary** (ngspice's default) | 0299 — a truncated raw reads as success with a fabricated point |
| process count | one `xschem --script` | write, quit, relaunch | **1380** — the Save button had never been read back |
| display | `--nogui`, no Tk | a live screen | 0891 — `ALL PASS (447)` headless, `2 FAILED (451 passed)` on a display |
| X server | Xvfb `:99` | the user's VcXsrv | 1343 — the RDW raise works on Xvfb and Xwayland and not on the server the user looks at |
| `$HOME` | the developer's | anyone else's | 1377 — 18 suites read `~/.xschem/ase_simulators` |
| analyses | OP only | op + tran | 0929 — ngspice's `write` stores only the current plot |
| tree | in-tree (`XSCHEM_SHAREDIR` = `src/`) | installed | 0424 — 275 in-tree checks green, installed binary SIGSEGV at startup |

**The instance: issue 1380.** The user wrote:

> *"'Save' modified list (annotation or summary) for RDW is not surviving
> session. RDW claims saved, and the file exists while Xschem still up. But,
> relaunch and: `No such file or directory`."*

`op_param_lists::load` was complete, correct, and had **zero callers**:
`grep -rn "op_param_lists::load" src/ | grep -v load_conf` returned nothing. Save
wrote the file correctly and no session ever read it. Every session re-seeded
from the PDK declaration, which is indistinguishable from a Save that did
nothing. The fix is one guarded line at `src/xschem.tcl:17448` —
`catch {::op_param_lists::load}`, at the source seam.

**And the sharpest part is that the store suite already had the shape and still
could not see it.** `tests/headless/test_op_param_store_1245.tcl` is 5,222 lines
and ~140 checks, and row **P5** (`:1186`) really does `exec` a second
`--nogui --pipe` xschem to prove a UTF-8 label survives a reader and a writer
under `LC_ALL=C`. But that child *calls `op_param_lists::load_conf` itself*. The
row proves the loader works when someone calls it; the defect was that nobody
did. **A second process is necessary and not sufficient — the child has to reach
the state through the door a real session uses**, which here is startup, and no
row ever let a child just start up and look.

**Why the structure invited it.** The harness's atomic unit is one process
(`tests/headless/full_audit.sh:49`; `run_regression.tcl` likewise). But the shape
*and the reason for it* existed, one file away:
`tests/headless/test_ase_simreg_0931.tcl:799` states outright *"E6 and E8–E10 are
REAL child xschem processes. Nothing in-process can prove 'survives a restart'"*
and ships an `a_child` helper (`:319`). The store suite carried across the
`exec`; it did not carry across the sentence.

**The sharpest single measurement in the era** is 1377's, because it shows how
much of "green" is environment:

| suite | real `HOME` | `HOME` = empty dir |
|---|---|---|
| `test_ase_persist` | **5 FAILED** (131 passed) | ALL PASS (136) |
| `test_ase_core` | **7 FAILED** (174 passed) | ALL PASS (181) |
| `test_ase_sod_case` | **11 FAILED** (41 passed) | ALL PASS (52) |

Same tree, same commit, same binary.

**How to recognise it elsewhere.** For every axis your fixture pins to a
constant — encoding, display, analysis count, process count, `$HOME`, path
length, circuit size — write down which value ships and whether *any* row uses
it. Two corollaries:

- **A suite that is green in one arm and red in another is not flaky.** It is
  telling you which arm it was written in.
- **When you harden one branch of an `if(binary) … else …`, the other branch is
  now the bug.** `src/save.c:713` has been the un-fixed twin of a fixed line
  since 2026-08-09.

And record the arm beside every number — display, `$HOME`, flags, binary mtime —
or the number is not evidence.

---

### 3.5 The artifact is a process, not a value

**The shape.** Every consumer treated the `.raw` file as a finished document with
a schema. It is a file being written by another process, and it passes through
states that are each individually well-formed.

**The instance: issue 0836.** ngspice writes `No. Points: 0` into the raw header
when a run starts and backfills the real count only when it ends. **For the
entire duration of every simulation, the file on disk is a legitimate,
untruncated, zero-point raw.** `read_dataset()` reads it as a success;
`my_realloc(…, 0)` frees and NULLs every `raw->values[v]` while `raw->values`
itself stays non-NULL, so the one guard that existed
(`if(xctx->raw && xctx->raw->values)`) passes and the dereference of
`values[i][0]` segfaults. Reachable from a shipped verb, with no crafted
arguments and no truncation. Its twin in `get_raw_value()` is 0852 (fixed
`28587ba2`); its third door, `raw switch` gating on the outgoing database's point
count, is 0853 and is still open.

The same file has a **content** lifecycle the deck controls, and that is issue
0929 — the defect the user *had actually been hitting for days*, while 0927 and
0928 were fixed upstream of it and neither helped. The generated `.control` block
ended with a single `write`, and ngspice's `write` stores only the plot the
simulator is currently standing in. An op+tran bench computed the operating point
and threw it away; `6` had nothing to read.

**Why the structure invited it.** A reader is written against a completed file,
because a completed file is the only kind a test fixture ever produces by hand.
The ownership boundary hides the rest: the file is written by a foreign process on
its own schedule and nothing in the API forces anyone to name the states.

**How it was found is worth as much as what was found.** By the Verify-C adversary
driving a *real* still-being-written 2.9 MB ngspice raw instead of a crafted one.
That adversary then crashed before writing a report, and the crew summary recorded
"verify-C produced nothing" — the finding was recovered from its leftover scratch
file. Had it not been, the 0807 fix (tier-green, full sabotage matrix caught)
would have shipped a SIGSEGV. **Treat a crashed adversary as an adversary that
found something: sweep its scratch directory before assigning a status.**

**How to recognise it elsewhere.** When you consume an artifact another process
writes, enumerate its states **over time**, not its schema. Write down what the
file looks like at t=0, mid-write, after a crash, after a re-run — then build a
fixture for each.

---

### 3.6 The sentence is a second implementation of the operation

**The shape.** About a fifth of the 12xx-era issues are the tool saying something
untrue — not a wrong number, a wrong *sentence*. The mechanism is nearly always
the same: the sentence describing what happened is composed independently of, and
usually **before**, the thing it describes.

This is invariant I1 — two constructions of one fact, which drift, silently —
applied to prose instead of to vector names. The tree never noticed the family
resemblance.

**The instance: issue 1379, found in the first photograph ever taken of the
window.** The chrome line read *"No device has been sent here yet"* while two
rendered blocks stood beneath it (`x1.M1:/tb_bandgap/x1`, `x1.M2:/tb_bandgap/x1`).
The diagnosis: *"No existing row reads the WIDGET after a push, which is how the
same sentence came to be false in both directions."* Its mirror, issue 1367, is
the chrome claiming to be *"Showing"* an empty pane.

**And it had already been measured.** `src/rdw.tcl:408-410`, landed in `a2104a35`
on 2026-09-06 — *one day before 1379 was filed*:

```
# ⚠ THE CHROME IS ONE DUMP BEHIND, THOUGH (measured:
# `rdw::apply_list_state` is called only from `rdw::build` and `rdw::set_list`,
# and `rdw::push` calls neither), so on the FIRST dump of a session it still
# reads "Select a device and press 1".
```

A defect written into a source comment is not tracked. Nobody was owed it,
nothing scheduled it, and the next person met it as new.

**Why the structure invited it.** The status text was treated as *presentation*,
so it was written next to the button rather than derived from the operation's
return value. `rdw::_apply_now` wraps three calls in bare `catch`es and returns
`{}` unconditionally (`src/rdw.tcl:6252`); `rdw::button` builds the whole sentence
from the decision core `rdw::_edit` and only *then* calls it (`:6539`). The
sentence is structurally incapable of reporting the act.

The same inversion appears everywhere in the family: a scope dialog **raised
before the check that refuses**, so the user answered a two-part modal and was
then told the whole thing was impossible (1372 §3.2); a log line composed from a
separate call to the same decision (1354, 1366); the window saying *"(did not
converge)"* when its own formatter merely declined to format a value (1345).

**And goldens make it worse.** Issue 0888: *"Every affected sentence has a
byte-exact golden … and the goldens were written from the rendered output. **A
golden the crew wrote from the code cannot tell the crew the code says the wrong
thing.**"*

**How to recognise it elsewhere.**

- A sentence that reports an action is **part of the action**, not part of the
  view. Derive it from the operation's return value, after the operation runs, in
  one place.
- Never wrap the act in a bare `catch` while the words are built from the plan.
- Never ask the user a modal question before running the check that can refuse.
- Assert against the **widget**, not the model that feeds it — `$w get 1.0 end`
  beside `_chrome_line`, in the same row, would have caught 1379 and 1367 at once.
- Never write a golden by pasting the program's current output. Write the sentence
  you want, from the requirement, then make the code emit it.

The worst consequence of this shape is not a wrong sentence. It is issue **1361**:
rule debt 1355 was sitting in the user's queue asking them to **ratify sentences
that were measurably false**. An unratified decision aging in a ledger is not
neutral; it can decay into a false statement the user is being asked to bless.

---

### 3.7 A control that changes generated input to a foreign tool is not a display control

**The shape.** A checkbox about what to *draw* changed what was *simulated*, what
the results file *cost*, and then — via the simulator — what a different part of
the UI *displayed*.

**The instance: 0927 → 0928 → 0964 → 0967.**

| step | change | consequence |
|---|---|---|
| 0927 (`d3f97f01`) | device-OP annotation on by default — a *display* default | 468 `.save` cards in every deck |
| 0928 (`bbd693d9`) | those cards rode analyses that cannot use them | measured: `.op` +0.03 s / +107 KB (free); `.tran` over 10,068 points **+8.6 s / +242 MB, 6.94×**. Filed by its own authors as *"a live regression introduced by 0927"* |
| 0964 | move the cards inside `.control`, which forces the operating point to run **last**, because ngspice's save list is sticky forward-only and `unsave` does not exist | −4.08 s, −74.9 MB |
| 0967 | `print` reads whichever plot the simulator is standing in | the Outputs pane's Value column silently switched from empty to `1.800000e+00` — a number that appeared next to a row **because of a checkbox about something else entirely** |

**Why the structure invited it.** The predicate that knows whether these numbers
can ever be read — `ase::op_analysis_enabled` — existed, and had exactly one
caller: the **gate-off nudge**, the message shown when the feature is off. The one
function that could have separated the two decisions was consulted only on the
path where no cards are emitted.

**A note against a tempting misreading.** Fusing deck and display was not an
accident here; it was **ruled**, deliberately, by invariant I1 and by S3's
decision D2 — *"the descriptor's `params` list is the single source of truth
shared by the save side and the read side, and an emitter that silently dropped a
parameter the display still reads would be a second, drifting policy"* (0434). The
later DD-4/DD-6/DD-13 rulings are the tree **un-doing** that fusion. Anyone
reading this history forward from the middle would look for the wrong defect.

**How to recognise it elsewhere.** Any control that changes generated input to a
foreign tool is not a display control, however it is labelled. Cost it, and label
its downstream effects. And if a predicate exists that says whether an output can
ever be consumed, it belongs on the **emit** path, not only on the
**explain-why-it-is-off** path. A predicate with one caller on the wrong side is a
defect waiting for a default to flip.

---

### 3.8 Every fix has a shadow

**The shape.** A defect is invisible because a *second* defect prevents the code
from reaching it. Fixing the second one ships the first.

**The instance: 0807 attempt 2 → 0836.** `annotate_op`'s cache dedup (issue 0814)
meant HEAD adopted a cached same-path entry **without reading the file**, so HEAD
could not crash on a zero-point raw no matter what the file contained. Attempt 2
of 0807 removed that dedup — which is precisely how it closed 0814 "by
construction" — and every leg then performed a real read, straight into 0836's
SIGSEGV in the shipped arrangement. The A/B was airtight, the suite went 358 →
384 checks, the eight-variant sabotage matrix was fully caught, and the verdict
was *"incomplete, not wrong"*. Reverted at `2d4dafaf`. 0807 was reverted **twice
in two days** (`3d30be01`, `2d4dafaf`), both times after passing every tier.

**Others.** 0856 → 0863 + 0861 (before the gate, annotate-on-a-transient published
t=0, *"which on many benches is close enough to the operating point that nobody
looked"*; the correct gate made a reader limitation visible for the first time and
routed the ordinary menu flow into a fabricated `0`). 0927 → 0928 (harmless while
the default was off). 0951 → 0962 (the pre-fix code deleted two results files at
the top of the probe, which masked the new row's own claim: its headline assertion
passes identically on the defective tree).

**Why the structure invited it.** Nobody asks what a bug is *preventing*. Sabotage
matrices test whether a guard can be deleted; they do not test whether removing an
unrelated accident makes another path reachable. And the shadow crosses item
boundaries by definition — the masking defect and the masked one are owned by
different issues and different crews.

**How to recognise it elsewhere.** If the defect you are fixing is a **cache**, a
**short-circuit**, a **pre-delete** or an **early return**, removing it makes code
reachable that has never run in production. Audit the newly-reachable path as
*new* code. And expect the shadow to live in someone else's issue file: a fix
whose blast radius crosses an item boundary needs the two items in one commit,
which is exactly the thing the scope rules forbid. §5.2.

---

## 4. How defects escaped the tests

The suites were not thin. 41,761 lines, red-before-green, sabotage variants on
most rows. They caught a great deal — and every one of this feature's headline
defects went past them. Test *volume* was never the constraint.

Here are the escape classes, each with the specific test that would have caught
it. They are worth reading as a checklist against your own suite.

| # | escape class | named instances | the row that would have caught it |
|---|---|---|---|
| E1 | **single-process, or a child that cheats** — nothing ever restarted *through the door a session uses* | 1380, 0932 | write, **exit the process**, start a new one, and let it reach the state the way a session does. Not "set it and read it back" (passes with the loader disconnected), and not a child that calls the loader by hand — the store suite's row P5 does exactly that and 1380 walked past it |
| E2 | **in-tree only** — the installed artefact is a second process too | 0424 | `grep -c <newfile> src/Makefile` expecting 2 (an install line and an uninstall line); one `make install` into `DESTDIR` and a startup smoke test |
| E3 | **headless only** — `draw()`'s whole body is inside `if(has_x)`, so stubbing `draw.c` reds nothing | 0891, 0474 | the same suite in both arms, with the difference treated as a finding. `run_regression.tcl:73-93` now carries a second `dcases` list for exactly this |
| E4 | **the wrong X server** | 1343, 1376 | run on the server the report came from. This box has three (`:0` is WSLg's Xwayland, `$DISPLAY` is the user's Windows X server, `:99` is Xvfb) and they disagree about raise, iconify and `<Configure>` counts |
| E5 | **the developer's `$HOME`** | 1377 (18 suites) | run every suite under a real, an empty and a hostile `HOME`, and compare **name+status**, never counts |
| E6 | **synthetic fixture, shipped artefact ships** | 0494, 0499 (row W19), 1248 | one acceptance row against a shipped bench. Attempt 4 died on `tb_bandgap_opamp`, not on a new assertion |
| E7 | **one encoding** — ASCII fixtures, binary ships | 0299 | a fixture per branch of every `if(format) … else …` |
| E8 | **one analysis** — with one analysis, "write the last plot" and "write every plot" are the same deck | 0929 | a two-analysis deck. `test_wave_viewer` V1 came closest: it enabled two analyses and asserted *"exactly one write line"* — it was **pinning the defect as the contract** |
| E9 | **the suite is in no runner** | 0465, 1336, 0206 | `grep -c <suite> tests/run_regression.tcl tests/headless/full_audit.sh`. 0465 proved it the hard way: with **17 deliberately red rows committed**, a full T1 run reported exactly the pre-existing 3 FAIL / 0 GOLD? / 0 FATAL — *"T1 cannot see the feature at all, in either direction"* |
| E10 | **the row cannot fail** | 1248, 0630, 1316, 1283 | the non-vacuity control, and landmine 11: a predicted red that does not appear is a **blocking fixture defect** |
| E11 | **asserting the model, not the widget** | 1379, 1367 | `$w get 1.0 end` in the same row as the builder call |
| E12 | **goldens written from the output** | 0888, 0889, 0887 | write the sentence from the requirement first. (0887 is the sharpest: three rows plus 386 combinations measured a status line with `string length` over a pure-ASCII fixture, so *"every one of A11-10's 386 combinations agreed with the budget **about the wrong unit**"*) |
| E13 | **the harness itself** | 0147, 0990, 0936/0994, 0424 | see below |

**E13 deserves its own paragraph, because a broken instrument does not read as
broken — it reads as a partially-passing suite, and a human will spend weeks
reading it as signal.**

Issue **0147**: for an unknown period ending 2026-07-25 the regression harness
never launched a binary. `tests/test_utility.tcl:24` held `set xschem_cmd
"xschem"` — a bare name resolved through `PATH`, with nothing installed. 21
headless cases never ran; 2,654 golden jobs died with `exit 127` and contributed
**zero** counted failures; a week-old `create_save.log` was re-greped every run
and re-reported as current. The asymmetry is what made it deceptive: golden cases
fail **open** (`print_results` early-returns silently when `<case>/gold` is
missing) and headless cases fail **closed**. It had hidden a genuine red since
2026-07-24. Fixed in `866ad2ff`.

It was found not by a test but by an agent writing a routine "pre-existing
failures" paragraph — *a paragraph that was, because of this defect, wrong twice.*
**That is what the sourcing discipline is for**: someone wrote down what they
believed and discovered they could not source it.

Two more that are still live. Issue **0990**: two concurrent `run_regression.tcl`
runs corrupt each other, because `tests/open_close.tcl:38` uses a fixed
`results/.work` with no pid and `:108` deletes it out from under a run still
reading it; `test_utility.tcl:119` scores the missing status file as `-1`, so the
victim prints `FATAL: 10` in the one suite whose baseline is ZERO. And **no test
harness builds** — `full_audit.sh:49` runs `$REPO/src/xschem` as it finds it — so
`git stash` → build → test → `git stash pop` leaves a correct tree and a stale
binary producing a *plausible* audit with the right suite names and the wrong
answers.

---

## 5. The process causes

Several of these defects were not caused by the problem being hard. They were
caused by the process. This section is the uncomfortable one, and it is the part
most likely to transfer.

### 5.1 Filing instead of fixing

`CLAUDE.md` already records two four-times filings: the `run_regression.tcl`
completion sentinel (0420 → 0492 → 0629 → **0689**) and the IHP libmgr golden
(0421 → 0455 → 0491 → **0690**). Eight issue files, four correct independent
diagnoses each, zero fixes until the last one. Both were finally closed in
`237fc966`, which took T1 from three counted FAIL lines to zero in one commit.

**The worst case is not in the harness. It is one line of C in the feature
itself.** `xschem raw switch` snapshots `Raw *raw = xctx->raw` at the top of the
dispatcher, then gates the operating-point republish on the **outgoing**
database's point count while reading the **incoming** one's `sim_type` — one
condition straddling two databases:

| filing | date | cites the others? |
|---|---|---|
| 0511 | 2026-08-19 | no. Self-rates severity *"low today (both operands usually agree)"* |
| 0513 | 2026-08-19 | no |
| 0853 | 2026-08-26 | no. Filed by the 0836 crew: *"one of the three doors to that crash"* |
| a `save.c` comment | — | records the straddle as a hazard it had to work around, and files nothing |

Fixed 2026-09-01 (`d8151021`). The trigger was **none of those four
measurements** — it was the user hitting it from the other end, thirteen days
after it was first measured, and reporting that after Alt-Shift-6 there was no way
back to annotating the operating point. At HEAD the code is fixed; **0511 and
0853 both still read OPEN.**

The same shape, twice more: **0936 and 0994** are the same finding — three suite
baselines recorded under a command that cannot produce them — filed a day apart,
and `grep -c` shows **neither cites the other**. 0936 says it was *"measured
independently by three agents in one session"*; 0994 says *"found independently
four times in one item"*. Roughly seven derivations, two filings, one fix, and the
fix was a text edit.

**And re-derivation is not free.** It is a fresh chance at a wrong diagnosis by a
reader with strictly less context than the last one:

- **0455's first diagnosis** read the extra library as untracked litter and
  pointed at **deleting it** — 140 tracked files across 49 cells, a deliberately
  migrated test library, to make one check green. The file corrected itself; the
  0689+0690 crew then re-confirmed the correction five independent ways before
  touching the golden.
- **0420, 0492 and 0629 all recommended the same class of fix** — relax the
  sentinel anchor (`{^OVERALL: ok\M}` in 0420 and 0492, the barer
  `{^OVERALL: ok}` in 0629) — and 0689 §4 **measured it to be a regression**:
  `--nogui --pipe` exits 0 on an uncaught mid-script Tcl error, so a suite that
  printed a counted banner and then *died* was being caught only by accident, by
  the count breaking the anchor. Three careful readers each recommended the same
  measurably wrong remedy.

**Why the structure invited it, and this is the part that stings: the cause is a
good rule.** Every crew brief demands a diff scoped to its step, and every filing
says so in nearly identical words:

> 0420/0421 — *"S1 is a Tcl-only feature step and must not carry an unrelated
> harness change into its diff."*
> 0423 — *"the fix is in C, S1 is a pure-Tcl step, and no crew step in this run
> owns `alloc_xschem_data()`."*
> 0424 — *"the fix is `./configure`, a **build action**, and this crew's hard
> rules bar every agent but Implement from running one."*
> 0994 — *"the numbers live in a harness file another hand already has
> uncommitted edits in."*
> 1378 — *"deliberately left unfixed so 1276's scoped lift stayed a lift."*

Each decision is correct in isolation. **Scope hygiene is a per-item virtue that
composes into a permanent defect, because a cross-cutting bug is never in anyone's
scope by construction.** Two amplifiers make it worse: *"pre-existing, not caused
by us"* is read as a discharge rather than as a finding, and **a well-written
issue file is emotionally indistinguishable from a fix.** A directory of them
reads as coverage. 0629 says outright that it is filed *"so a later crew does not
chase it"* — a note to a reader who never grepped.

**What makes a defect re-derivable.** Three properties, all fixable:

1. it sits on a **seam between two owners** — every crew that met 0513 was passing
   through on the way somewhere else;
2. **the tracker indexes conclusions, not symptoms.** 947 files, no index, one
   2,595-line append-only `NUMBERING.md`, and filenames that describe the author's
   diagnosis ("gate mixes pre and post switch state" / "publish gate reads the
   previous database" / "gates update_op on the outgoing database's point count"),
   so three names for one bug never collide;
3. **severity is judged from inside one layer**, where it genuinely looks minor.
   0511 self-rated it "low". It was the reason a user could not get back to their
   operating point.

The remedies follow directly: index by the **code touched** (file plus function),
not by the story of how you found it; a mandatory duplicate search on the symptom
*and* the source line before minting a number; and treat "this defect keeps being
met in passing by crews going elsewhere" as **the severity signal it is**.

**One honest counterweight.** The 1200–1399 era, run as a driver-plus-crew batch,
produced **142 issues and not one duplicate number** — `NUMBERING.md` was
maintained in the same commits as the filings and the reserved block for
1244/1245 was honoured. The re-filing disease is fixable, and this tree fixed it.
What replaced it is worse in one specific way, and is §5.4.

### 5.2 Deferral without scheduling

The subtler half of the same problem. A defect is found by an adversarial pass,
measured to the byte, written up beautifully, explicitly declared out of scope —
and then **nothing schedules it**.

The census: grep the deferral idiom
(`deliberately not fixed` / `deliberately left unfixed` / `not fixed here`) across
0018–0299 and eight files carry it — 0158, 0167, 0172, 0201, 0243, 0245, 0268,
0297 — spread across the raw reader, the signal browser and the modal-gesture
work, so this is a habit of the tree and not of one crew. The sharpest specimen
is a single two-day adversarial pass on 2026-08-08/09 that produced **0296, 0297,
0298, 0299 and 0300**. All five are still open a month later, and three of the
five (0298, 0299, 0300) are in **one reader**. **0298 alone carries three measured
SIGSEGVs with verbatim reproductions.**

The scope discipline behind each deferral is genuinely correct — widening a bounds
fix in the ASCII reader to also change what the **binary** path does with a short
block is a different decision with a different blast radius (every binary raw
xschem has ever opened), and taking it silently inside a bounds fix would be a
scope expansion. 0297, 0298 and 0299 all cite 0290's precedent **by name** for
exactly this.

What is missing is the other half. **A deferral is only safe if something
schedules it.** The tracker records; it does not schedule. So *"deliberately not
fixed here"* reliably becomes *"not fixed"*, and the file that records the
deferral reads like progress.

Two operational rules fall out:

- Make "file it" cost something: an issue filed against a file no current item
  owns must name an **owner or a date**, or it is not filed, it is deferred.
- When one adversarial pass produces three issues in the same reader, that is a
  signal about **the reader**. Schedule the function; do not file three children
  and move on. (0298/0299/0300 are all `read_raw_ascii_point` and its neighbours;
  a month on, all three are open and one of them fabricates numbers.)

### 5.3 Standing reds read as furniture

For nine days every crew report carried *"T1 3 FAIL — pre-existing"* and every
reader, the branch lead included, waved it through. All three were the harness
(§5.1). `CLAUDE.md` now says **"a standing red is a defect, not furniture"** — and
`git log -S "standing red" -- CLAUDE.md` returns exactly one commit: `237fc966`,
**the commit that fixed them.** The rule is a scar, not a guard. It did not exist
during the nine days it describes.

The rule is still not enforced. Issue **0206** — `test_ase_plot` P4, six
deterministic failing legs, proven pre-existing by a stash-rebuild-rerun, with a
cheap discriminating measurement written down — has been red and un-diagnosed
since **2026-08-01**. Its suite is in no audit list at all:
`grep -c test_ase_plot tests/headless/full_audit.sh` returns **0**. It is the
cleanest available example of the rule going unenforced because the red is not in
front of anyone.

**A suite nobody runs is worse than a suite that does not exist, because its
existence is cited as coverage.**

### 5.4 Decisions taken silently

The owed ledger stands at **115 rule debts and 47 look debts**. A rule debt is a
user-visible decision the machine took and queued for a human. That is not
"display leaked into deck in a few places" — it is a feature substantially
designed by its implementer, with the person who knows what the numbers are *for*
asked afterwards.

The one time the user did drive the real bench, a shipped decision reversed within
two days. Issue **0678**: branch currents were on `Alt-6` and belong on `6`. The
file states the class exactly — **"A RULING REVERSAL, not a coding slip. The code
did exactly what decision D4 said."** D4 was a decision about what a human sees,
taken by people who had not seen it.

That is the cheapest defect-finding instrument in this whole record and it was
used least. The first eyes-on session came **six days and twelve plan steps** into
the feature (`e4e215b2`, 2026-08-22) and produced a cluster inside 48 hours — and
not one of them was about whether a number was correct. `Ctrl-6` leaves node
voltages on so "everything off" is false (0613); node voltages use the **same
layer number** as the OP block so the two are indistinguishable (0615, the user's
words: *"for node voltage display, use white, not same color as the OP info"*);
the overlay lands on top of the symbol's own texts (0605); a missing vector shows
`-` where the invariant says blank (0625).

**Why the structure invited it.** The plan's acceptance criteria were all
machine-checkable, because machine-checkable criteria are the ones a crew can be
measured against. *"Does the block read as clutter?"* and *"can you tell a node
voltage from a device parameter?"* have no assertion, so they were never in a
step's brief, so nothing owed them and no step was blocked on them.

And the tree could not photograph its own dialogs until **2026-09-07** — no
`import(1)`, no `xwd`, no `scrot`, no `maim`, no PIL, no Tk Img, measured not
assumed (`a7cfa479`). A pixel deliverable could only be described in prose. Issue
**1337** is the shape of the problem: the user's requirement was *"clicking on any
line makes the entire line a shade darker **(noticeably)**"*, and the fix ships a
measurable colour (`#d7d7d7` on `#ffffff` in the light theme, `1337:47`). A
machine can verify the hex. Nothing in the tree can verify *noticeably*. **A
machine cannot pay a look debt.**

The corrective, when it arrived, cost one afternoon and found issue 1379 in the
**first photograph taken**.

### 5.5 The tracker decays, in both directions

An issue file's Status field is not reliable, and every reader who trusts it
inherits the error.

| file | says | truth |
|---|---|---|
| 0465 | `Status: OPEN (measured by S9's RED pass, not fixed)` | `grep -c op_annot tests/run_regression.tcl` → **4**. Wired in as a side effect of `e31975e7` (2026-08-27) and never marked |
| 0511, 0853 | OPEN | fixed 2026-09-01 in `d8151021` |
| 1276 | header carried *"FIXED AND LANDED … RE-VERIFIED INDEPENDENTLY"* | partly false — the re-verification re-ran the two cases the file named and never asked the third (1378) |
| 1377 | title says *"four ase suites"* | body says **eighteen**; the count moved twice because the first two surveys were source greps |

The status tally in §2 is therefore soft in both directions. **When you close a
defect, grep for every other number describing the same code and close those too,
in the same commit.** A duplicate left open after its twin is fixed is worse than
the original duplicate.

Two more decay channels worth naming. **A defect recorded in a source comment is
not tracked** — `src/rdw.tcl:409` had 1379's mechanism, measured, a day before
1379 was filed as new. And **a citation to a file that does not exist**: the spec
cites 0443 as one of the three failed S3 attempts, and 0443 exists only as
`0443-attempt-3-interrupted.patch`, so a maintainer following the citation can
read two of three (issue 0487).

---

## 6. What actually worked

This tree developed real countermeasures. Some of them earned their keep and are
worth copying; some are ceremony. The distinction matters more than the list.

### Earned its keep

**The adversary role — the single biggest win in the record.** A separate agent
whose job is to disbelieve the number, run after the implementer and the verifier
are both green. `git log --grep 'is \[F\]'` returns **14 refuted items in three
days** (2026-09-02 to 2026-09-04). `doc/claude/rdw_batch/ADVERSARY_FINDINGS.md:4`:

> **Four of five REFUTED.** The suites were green when they did it — window 134,
> keys 71, store 130, control 485 — which is this batch's oldest lesson arriving
> again: *a suite fences the questions its author thought of.*

820 green checks across four items, four refutations. **If you take one thing
from this document, take this: fund the adversary, not the coverage.** Adding rows to a suite written by
the author of the change buys less than one person told to break it.

Note also that this is why the issue count looks alarming. A large share of the
12xx-era files are defects **introduced by the crew's own fixes and caught by the
crew's own adversary before reaching the user** — the 14 `[F]` verdicts above are
its visible half, each one a green item refuted before it shipped. High issue
count, in this tracker, is substantially a measure of how much was caught.

**Measure before you rule.** `864c51ec` is the model: a 329-line measurement
transcript taken *first* (`1244_op_param_list_measurements.md`), and the spec
written on top of it. It established, before a line of code, that one schematic
instance is not one SPICE primitive, that saving every parameter costs +1.2 s and
500 KB, and that `Ctrl-Alt-6` currently fires `Alt-6` because Tk matches modifier
subsets. `1243_op_values_differ_between_runs.md` is the same discipline applied
to a bug report: three candidate causes, two cleared by measurement, the answer
found in the testbench's own `agauss` — against a background of genuine
wrong-number defects, that is not a small thing to get right.

**Comments that carry measurements and rejected alternatives.** The 29-line block
at `src/save.c:3550` (above a 10-line `op_annot_autofill`) and the 88-line block
above `rdw::_narrow_line` (`src/rdw.tcl:414`) are far longer than the functions
they precede, and every
paragraph is a scar with an issue number on it. This is real documentation: it
tells the next person *why here*, what was tried, and what a change would cost.
The one caveat is §5.5's — a comment is not a tracked defect.

**Reverting green work, and recording refutations of your own claims.**
`3d30be01`, `2d4dafaf`, `f3bded23` and `cc7a4083` revert changes that passed every
tier and the full sabotage matrix, each explaining itself in the subject line.
`DECISIONS.md:494` is the driver naming his own repeated error in capitals. 0866
exists solely so a false claim is not re-derived; 0965 §1 is headed *"The cause is NOT the
one the item guessed, and the guess is worth recording"*; 0989 says of its own
first filing, *"The filed cause was wrong, and the real one is worse"*
(`0989:64`). **1376 is the file to hand a new engineer first**: a user
reported that middle-button pan did not work, the first answer told them it worked
on the evidence of a synthesized `xschem callback` event — *which is the C entry
point and bypasses the Tk binding table, the window manager, the X server's event
delivery and the mouse* — and the actual cause was a failing mouse button. Every
layer in this tree was innocent. The file is kept in full, closed as NOT A DEFECT,
*"because the investigation's method errors are the reusable part."*

**Extracting a rule into one file with a locking test.** `237fc966` did not just
fix the sentinel; it moved the rule into `tests/banner_rule.tcl` and locked it
against the two shell readers with 19 rows in `test_audit_classifier.tcl` section
K. That is the shape of a fix that stays fixed.

**The choke point.** `update_op()` as the one door, with the caller table written
into the comment beside it (`src/save.c:3561`). Compare 1333's one-door
assumption, which cost 0617 a second life.

**Building the guarantee instead of asserting it.** DD-13's `declared` key, which
`apply` cannot destroy because `apply`'s body never names it. And the deliberate
refusal in the 0965 fix to leave an alias under the old private spelling —
*"an alias would have let the next one be written without anybody noticing"*
(`src/op_annot.tcl:972-975`).

**Structural tests over comments.** `src/op_annot.tcl:977` carries *"⚠ THIS IS
THE ONE PLACE IN THIS FILE THAT ASKS WHAT A DEVICE'S MODEL IS (invariant I1)"* —
and row **NM5** of `tests/headless/test_op_annot.tcl:16289` greps the
comment-stripped file to keep it true. A comment cannot go stale silently if a
row reads it. This is the answer to §3.2: **enforce "one owner" with a test that
counts definitions, not with a sentence.**

### Mixed

**Invariant I1.** Right about names, and a contributing cause of the worst data
model failure in the feature when applied by reflex to content (§3.2). It also
spent its whole life measurably violated and the spec says so: two name builders
in two languages, `op_annot::_wrap` in Tcl hand-mirroring `get_fqdevice()` in C,
*"a later step that trusts the invariant literally will be surprised"*. An
invariant everyone cites and nobody can satisfy is worse than no invariant,
because it is quoted as an argument.

**The owed ledger** (`tests/headless/owed.sh`). It earned its keep on one axis:
it made the debts **countable**, it batched them instead of scattering them, and
it enforces the one rule that matters — *a rule or look debt clears only when the
user says so; no command converts one kind into another, and `drain` does not so
much as open the other two lists.* A green suite cannot discharge an eyeball.
That is exactly right. But 115 rule and 47 look debts unpaid means the ledger
**recorded** rather than **drained**, and §3.6's 1361 shows a ledger entry can
decay into a false statement the user is asked to bless. A queue with no drain
rate is a measurement of a problem, not a solution to it.

**The DD ruling numbers.** The numbering earned its keep — DD-4 → DD-6 → DD-13 is
a public, auditable correction trail, and the batch could not have hidden it if it
wanted to. The ruling *process* did not: three corrections, two full crew runs,
one cause (§3.2).

**Sabotage matrices.** They prove your rows can see your code, which is worth
having. They do not prove your fixture resembles a user's design, and attempt 4's
17-of-17 is the proof. The half that earns its keep is landmine 11 — *a predicted
red that does not appear is a blocking fixture defect* — and it was footnoted
three times before it was applied.

### Ceremony

**"Pre-existing, not caused by us"** as a status. It answers the blame question,
which nobody asked, and leaves the defect question open. §5.1.

**A count carried forward as a known quantity.** *"T1 3 FAIL — pre-existing"* in
nine consecutive reports is the sound of a suite being decommissioned by
consensus. Name the case and the reason, per case, or the number is noise.

**Writing the lesson down.** This is the most uncomfortable finding in the
document. `lessons_green_is_not_correct.md` was committed **2026-07-03, six weeks
before this feature started**, and says precisely what went wrong. Landmine 11
says a missing predicted red is a blocking defect *"not a footnote"*; attempt 4
footnoted three. The "standing red" rule was written **in the commit that fixed
the standing red**. "Grep the issues directory before minting" arrived
2026-09-02, after 1,243 issues had been filed.

**Writing the lesson down is not the same as installing the mechanism.** The
mechanisms that actually worked in this record are the ones with teeth: a
different agent whose job is refutation; a test that greps for the number of
definitions; a key one function structurally cannot write; a rule extracted into a
file that three readers must agree with. Prose in a doc did not stop anything.

---

## 7. If you are about to touch this code

A checklist, ordered by how often skipping it cost something here.

**Before you write a line**

1. `grep` every reader of every field you are about to give a meaning to. List
   them. Write down what each will now see. (§3.2)
2. If you are about to write "X is the one place that does Y", produce the caller
   table first and paste it into the commit. Drive every door; a grep is not a
   census. (1364, 1377)
3. Ask what your bug is *preventing*. If it is a cache, a short-circuit, a
   pre-delete or an early return, the newly-reachable path is new code. (0807 →
   0836)
4. Read `doc/claude/WIRING.md` if wires are involved, and
   `doc/claude/specs/op_annotation.md` §5 (the invariant table) if annotation is.
   Note the I1 amendment: **one builder, but it must take a basis.**

**While you write**

5. Absence needs a representation before values need a renderer. A failure must
   change the **shape** of the answer, not its magnitude. Never a bare `catch`
   around the act while the words are built from the plan. (§3.1, §3.6)
6. The sentence that reports the operation is part of the operation. Derive it
   from the return value, after the call, in one place.
7. When you fix one arm of a two-arm `if`, fix both arms or file the other in the
   same commit. `src/save.c:713` has been the un-fixed twin of `:717` since
   2026-08-09.
8. When you copy a function, copy its bugs. Fix the original in the same commit.
   (1276 → 1286 → 1378)

**Before you believe your suite**

9. `grep -c <suite> tests/run_regression.tcl tests/headless/full_audit.sh` —
   expect nonzero. (0465)
10. `grep -c <newfile> src/Makefile` — expect **2**, an install line and an
    uninstall line, and re-run `./configure` if you edited `Makefile.in`. (0424)
11. Run the **non-vacuity control**: prove your fixture can make the two states
    differ before asserting that it does. (1248)
12. A predicted sabotage red that does not appear is a **fixture defect to fix
    before landing**, not a footnote. (landmine 11, 0499)
13. Run one acceptance row against a **shipped** bench, not a synthetic one.
    (0494)
14. Name the arm beside every number: display, `$HOME`, flags, binary mtime. Then
    change one and re-run. (0891, 1343, 1377)
15. Rebuild before any audit that is meant to be evidence. No harness builds.
    (`full_audit.sh:49`)
16. For persisted state: write, **exit the process**, relaunch, and read it the
    way a session would — not by calling the loader from the child. (1380)
17. For anything a human's eye or hand is the sensor for: a synthesized event is
    not a gesture and a prose description is not a photograph. Record a `look`
    debt and say *"suites green, please look"*. (1376, 1337, 1379)

**Before you file instead of fix**

18. Grep the tracker for the **symptom and the source line**, not for your
    diagnosis. (0511/0513/0853, 0936/0994)
19. If you defer, name an **owner or a date**. "Deliberately not fixed here" with
    neither is a more expensive way of saying "ignored". (§5.2)
20. When you close a defect, close every other number describing the same code in
    the same commit. (§5.5)
21. If your fix is blocked by a **green** check, that is a finding: write down
    which check and why, and treat "the test asserts an implementation property"
    as a defect in the test. (0154, 0161)
22. If a decision is about what a person sees, it is not yours. Record a rule
    debt, and do not let a green suite discharge it. (0678)

---

*Written 2026-09-08 against HEAD on `fluid-editing`. Every claim above carries an
issue number, a `file:line` verified with `git show HEAD:`, or a commit sha
verified with `git log -1`. Where a number is soft — the OPEN/FIXED tally in §2 —
the document says so.*

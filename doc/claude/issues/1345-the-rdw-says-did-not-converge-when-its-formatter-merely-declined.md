# 1345 — the Results Display Window says "(did not converge)" when its own formatter merely declined

*Found by item R5's adversary (verify #4 of run `wf_2a267b11-e28`,
`doc/claude/rdw_batch/ADVERSARY_FINDINGS.md`), which **REFUTED** R5 while every
suite was green — window 138, keys 74, store 130, control 485.
Branch `fluid-editing`. Filed and fixed 2026-09-05, on top of `5e18a8ee`.
**FIXED.**
Item R5's mechanism is right and nothing of it is reverted here: the window
still formats through `op_annot::eng_or_blank`, the schematic's own proc, so
the two surfaces still cannot print different numbers. What was wrong is that
the window read that proc's EMPTY answer as a verdict about the circuit.*

---

## The defect

`rdw::_value_text` decided *"this value is non-finite"* by seeing an **empty
string** come back from `op_annot::eng_or_blank`. That proc returns empty for
**two** different reasons, and the caller could not tell them apart:

* the value really is `nan` / `inf` — `op_annot::_finite` said no; **or**
* `to_eng` **declined a perfectly finite number**, and `eng_or_blank` caught
  the raise internally and answered `{}`.

The second reason is **reachable from a shipped menu.**
`Simulation > Set netlist / graph / annotation precision`
(`src/xschem.tcl:17738-17740`) is a bare `input_line` free-text entry with **no
validation**, and its OK button runs `eval set ev_precision [.dialog.f1.e get]`
— so whatever is typed sticks. Measured on this binary, all eight of

```
-1    2.5    abc    4x    +4    0x4    6.    6.0
```

stick, and all eight make `format %.${pr}g` raise inside `to_eng`
(`src/xschem.tcl:1928/1930`). From that moment **every finite, correctly
measured value in the pane printed `(did not converge)`** — a claim about the
**circuit**, for a number the simulator computed perfectly well, on the one
surface this feature exists to have pasted into a design-review document.
Invariant **I3** (a plausible wrong number is the worst failure) in its
sharpest form.

It also broke item R5's own headline promise. In that state the **sheet**
blanks the row (`op_annot.tcl:2125` emits `id =`) while the **window** asserted
a non-convergence — so the two surfaces **did** disagree, which is the one
thing ruling **DD-7** and item R5 exist to stop.

### Driven, before the fix, in the live pane on `:99`

Same device, same numbers, same raw, one session; stored blocks keep their
rendered text, so the pane holds a **mixture** and reads exactly like a circuit
that stopped converging partway through:

```
M1:/xdut/xbg
@m.x1.m1
Not a complete list: ...
    id  : (did not converge)
    gm  : (did not converge)
    vth : (did not converge)

M1:/xdut/xbg
@m.x1.m1
Not a complete list: ...
    id  : 11.1u
    gm  : 1m
    vth : 0.75
```

Headless, across all eight precisions
(`scratchpad/p2_repro.tcl`, `./src/xschem --nogui --pipe -q --script`):

```
ev_precision=4   : 1.11e-05=>11.1u    0.001=>1m       0.75=>0.75
ev_precision=-1  : 1.11e-05=>(did not converge)  0.001=>(did not converge)  ...
ev_precision=2.5 : ... all eight identical ...
```

**Pre-existing?** No. Before item R5 the proc body was
`return [rdw::_oneline $v]`, so the window printed the true value whatever
`ev_precision` was. This is harm R5's own new code created.

**Why no row saw it.** `EN6` was the only row that touched `ev_precision`, and
it drove **4 and 6** — two values at which `to_eng` works.

---

## The fix: ask the question, do not infer it

`src/rdw.tcl`, `rdw::_value_text`. The discriminator was already in the tree
and is already what `eng_or_blank` gates on itself — `op_annot::_finite`
(`src/op_annot.tcl:1179`) — so consulting it adds **no second opinion** about
what non-finite means, which is the drift item R5 exists to remove.

```tcl
    set fin 1
    if {[catch {::op_annot::_finite $v} fin]
        || ![string is boolean -strict $fin]} { set fin 1 }
    if {!$fin} { return [rdw::_nonfinite_text $v] }
    ## FINITE FROM HERE DOWN, so an empty answer is the FORMATTER declining and
    ## nothing else, and the fallback is the raw text -- unformatted but TRUE.
    set e {}
    catch {set e [::op_annot::eng_or_blank $v]}
    if {$e ne {}} { return [rdw::_oneline $e] }
    return [rdw::_oneline $v]
```

Asking the predicate **first** also subsumes the old `NOFMT` sentinel: once
finiteness is settled, an empty answer can only be the formatter declining, and
the fallback is the raw text — unformatted but **true**, which is exactly what
the old missing-formatter arm did and what the file's own comment already
argued for.

After the fix, same drive:

```
ev_precision=-1  : 1.11e-05=>1.11e-05  0.001=>0.001  0.75=>0.75
                   nan=>(did not converge)  inf=>(did not converge)
```

and the live pane on `:99` reads `id : 1.11e-05 / gm : 0.001 / vth : 0.75` in
the block pushed at the broken precision, `11.1u / 1m / 0.75` in the other.
Both true.

### Two costs, recorded not decided — rule debt `1345_window_prints_what_the_sheet_blanks`

1. **In that state the window prints a number where the sheet prints a blank.**
   Every alternative is worse: `(did not converge)` is false, and a blank in
   this window means *"the raw names that column but the simulator did not
   compute it"* — its footnote would then lie about a measured value. The
   window is strictly more informative than the sheet here; it does not
   contradict it.
2. **The real upstream cause is not fixed here.** The precision menu accepts
   anything, and `xschem.tcl`'s `to_eng` is the whole tree's formatter, not
   this window's to redefine. Worse than a raise: measured at `ev_precision`
   `4x`, `to_eng 0` does **not** raise — `format %.4xg 0` answers the string
   **`0000g`**, a plausible-looking value, and the **sheet prints that too**.
   Validating the menu, or hardening `to_eng`, is a tree-wide user-visible
   change and wants a ruling.

---

## The three rows added

`tests/headless/test_rdw_window_1245.tcl`, section EN. Floor 131 → 134.

* **EN8** behavioural, the defect. Drives all eight precisions the shipped menu
  accepts. Every finite value must print what the **sheet** prints for it, or
  its own raw text where the sheet has no answer at all; never blank, never
  `(did not converge)`; a genuine `nan`/`inf` must **still** say the words at
  every one of those precisions (a repair that flattened the vocabulary would
  silently undo issue 1272); and one hard literal — at `-1`, `1.11e-05`.
* **EN9** the rebasing, pinned as **agreement**. See below.
* **EN10** structural. `_value_text` names `op_annot::_finite` and consults it
  **before** it reaches for `(did not converge)`; `src/rdw.tcl` contains no
  second spelling of the finiteness test (`*0.0`, `-Inf`, `to_eng` all zero in
  the comment-stripped file).

**RED before green**, against `git show HEAD:src/rdw.tcl` swapped in by `cp`
and restored by `cp` with `md5sum` verified:
`RESULT: 2 FAILED (139 passed)` — EN8, EN10. EN9 was green before and after,
and saying so is the point: it fences the *fix*, not the code.

**Three sabotages, all caught** (run on a copy, restore `md5sum`-verified):

| sabotage | what it is | caught by |
|---|---|---|
| `SB-OWNPREDICATE` | `regexp {^[-+]?(nan\|inf)}` instead of `op_annot::_finite` — a second spelling living in this file | **EN4** (`1e400` stops saying the words) and **EN10** |
| `SB-BLANK` | the declined-formatter fallback returns `{}` | **EN8** |
| `SB-WORDS` | the fallback returns `(no value reported)` | **EN8** |

---

## Also in the adversary's finding, judged on their merits

### `to_eng` rebases numeric literals — the COMMENT was corrected, the code was not

`src/rdw.tcl:455-459` claimed the `string is double -strict` gate was *"a
SECOND lock ... so a value that reached it unguarded would EVALUATE at global
scope"*. That is true only for **non-numeric** strings. `to_eng` is
`uplevel #0 expr [join $args]`, so every string that **passes** the gate still
reaches `expr` at global scope, and expr **rebases numeric literals**.
Measured on this binary, window and sheet alike:

```
010 -> 8     007 -> 7     00000000012 -> 10     0x10 -> 16     0b101 -> 5
08  -> not a double at all, takes the verbatim arm     09 -> likewise
1_000 -> not a double on Tcl 8.6.17 (an 8.7 tree would rebase it)
```

**Decision: correct the comment, do not harden here.** Normalising the literal
in `rdw.tcl` would print `10` where the sheet prints `8` — the exact
disagreement ruling **DD-7** forbids — and `to_eng` belongs to the whole tree.
Latent as shipped: the only registrant of the `devices` bucket
(`src/ase.tcl:9098`) fills it from `xschem raw value` through
`op_annot::raw_class`, i.e. C-formatted decimals that never carry a leading
zero. The plausible way in is a future **text-parsing** producer such as the
blanket `set altshow` dump (issues 1333–1336). Row **EN9** pins the agreement
and the five measured values, so a one-sided hardening reds rather than drifts.

### Row EN6 hard-depended on the shipped default — fixed, and so did fifteen others

`EN6` asserted `$EN6_SAVE` equals the literal `4`, so the suite depended on the
very preference the row advertises. `set_ne ev_precision 4`
(`src/xschem.tcl:18540`) is only a **default**.

Measured with `--preinit 'set ev_precision N'` (which lands before `xschemrc`'s
`set_ne`, so it reproduces a `~/.xschem/xschemrc` carrying the value):

| reader's `ev_precision` | `test_rdw_window_1245` before | `test_op_param_store_1245` before |
|---|---|---|
| 6 | **1 FAILED** — EN6 | **6 FAILED** — D1 D2 D4 D6 D8 D10 |
| 2 | **11 FAILED** — F1 F3 F8 F14 F15 F19 Q1 Q6 K8 EN1 EN2 | 6 FAILED |

So the fragility was never EN6's alone. **Both suites now state the precision
they measure at** (`set ::ev_precision 4` beside `set ::netlist_dir`) and put
the reader's own value back before the verdict, and **EN6 drives 4 and 6 itself
and asserts neither is the shipped value** — its subject was always that the
two differ and that the window reads the global live rather than caching it.
After: **ALL PASS at default, 6, 2, -1 and `abc`**, both suites.

**Not fixed, and said loudly:** `test_op_annot` — the batch's **control** —
has the same latent fragility, **7 rows** (S5 S10 S16 S17 K10 K11 XR4) red at
`ev_precision 6`. It is **pre-existing**, it is not item R5's doing, and
editing the control suite would compromise the one signal this batch measures
acceptance against. Recorded here so it is not re-derived.

### The `1341_nonfinite_in_the_devices_bucket` rule debt describes a DEAD arm

The adversary is right, and it is now **measured** rather than read.
`ase::backend::ngspice::op_param_set` — the **only** registrant
(`ase::register_backend`, one call, `src/ase.tcl:9119`) — classifies every
vector through `op_annot::raw_class`, which routes a non-finite to the
`nonfinite` bucket before it can reach `devices`. Driven by stubbing
`xschem raw value` and restoring it (`scratchpad/p2_deadarm.tcl`):

```
nan -nan NaN inf -inf Inf INF Infinity 1e400 1e309  ->  bucket `nonfinite`
1.11e-05  0  -0.0                                   ->  bucket `value`
```

`rdw::format_answer` renders the `nonfinite` bucket through
`rdw::_nonfinite_text` **directly** (`src/rdw.tcl:626-627`), never through
`_value_text`. So the non-finite arm of `_value_text` that row **EN4** fences
**has no live producer on the shipped seam**, and before this fix the one
reachable way to make it fire *was this very bug*.

**What that means for the user's ruling:** the option set on rule debt
`1341_nonfinite_in_the_devices_bucket` — (a) `(did not converge)`, (b) the raw
`nan`, (c) a blank — is about a **defensive arm**, not about anything the
shipped ngspice backend can produce. It is still worth a ruling, because it
becomes live the moment a second backend, or a text-parsing producer, fills
`devices` from something other than `raw_class`; but it is **not** describing
what the user will see on a run today. Recorded in the debt's own issue file
(`1341-...md`) so the ruling is not asked about nothing.

---

## Files

* `src/rdw.tcl` — `rdw::_value_text`, and the two comment paragraphs that
  overstated the gate and mis-stated what an empty answer means.
* `tests/headless/test_rdw_window_1245.tcl` — EN8, EN9, EN10; EN6 rewritten;
  suite-wide `ev_precision` pin; floor 131 → 134.
* `tests/headless/test_op_param_store_1245.tcl` — suite-wide `ev_precision`
  pin. No rows added; floor unchanged at 130.
* `doc/claude/issues/1341-...md` — the dead-arm note.

## Suites

| suite | how | before | after |
|---|---|---|---|
| `test_rdw_window_1245` | `--nogui` | ALL PASS (138) | **ALL PASS (141)** |
| `test_rdw_keys_1245` | `:99` | ALL PASS (74) | **ALL PASS (74)** |
| `test_op_param_store_1245` | `--nogui` | ALL PASS (130) | **ALL PASS (130)** |
| `test_op_annot` *(control)* | `--nogui` | ALL PASS (485) | **ALL PASS (485)** |
| T1 `run_regression.tcl` | solo | 0 counted | **0 counted** |

Every one printed a `RESULT` line; the counts above are read from it.

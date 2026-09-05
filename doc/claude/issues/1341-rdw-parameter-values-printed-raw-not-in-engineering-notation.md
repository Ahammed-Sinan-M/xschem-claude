# 1341 — the Results Display Window printed raw exponents where the schematic prints engineering notation

*Item R5 of the RDW batch (`doc/claude/rdw_batch/`). Branch `fluid-editing`.
Filed and fixed 2026-09-05, at HEAD `62391a3f` (item R4's raise).*

**The user's words:** *"Display of parameters in the RDW should be using
engineering notation - just like annotation on the schematic."*

---

## What was wrong

`rdw::_value_text` (`src/rdw.tcl:419`) is the **only** door a `devices` value
goes through on its way into the pane (`rdw::format_answer`, the `foreach pv`
at :553). It said, in full:

```tcl
proc rdw::_value_text {v} {
    if {[string trim $v] eq {}} { return {(no value reported)} }
    return [rdw::_oneline $v]
}
```

— the raw string, whatever the seam handed it. So the same transistor read

```
    id    : 1.11e-05          on screen in the Results Display Window
    id    = 11.1u             on the schematic, two inches away
```

and the number the user pastes into a design review is the one that does not
look like the sheet. That is not a cosmetic mismatch: the window exists to be
pasted **out of**, and a document that quotes `1.11e-05` next to a screenshot
reading `11.1u` makes the reader do the conversion to check they are the same
measurement.

---

## What was measured, before any source change

Section EN of `tests/headless/test_rdw_window_1245.tcl` (six rows, both arms —
R5 is pure rendering and needs no Tk) and the moved golden BE0 of
`tests/headless/test_op_param_store_1245.tcl` went in first. At HEAD
`62391a3f`, unmodified tree:

```
window --nogui   RESULT: 20 FAILED (113 passed)
window :99       RESULT: 20 FAILED (125 passed)
store  --nogui   RESULT:  1 FAILED (129 passed)
```

The 20 are the five new rows **EN1 EN2 EN4 EN5 EN6** plus fifteen existing
goldens that spell out what the window prints (`F1 F3 F4 F5 F7 F8 F14 F15 Q1 Q3
Q4 Q6 K8 BT0 RE4`); the store's one is `BE0`. **EN3 was green before the change
and says so in the file** — it is the fence against the *fix*, not against the
code, and its red-before evidence is a sabotage run rather than the shipped
tree.

`EN7` was added later, by the implementing pass; see "the input no row saw"
below.

---

## Why it is a wrapper and not a one-liner

Ruling **DD-7** (`doc/claude/rdw_batch/DECISIONS.md`) rejects the obvious
version, `set v [::op_annot::eng_or_blank $v]` at the call site. That proc
returns **empty for everything that is not a finite double**, and this window's
values frequently are not one. Four arms, measured:

| arriving value | prints | why not blank |
|---|---|---|
| `{}` or whitespace | `(no value reported)` | issue 1284: a value-less pair is not an absent column |
| a finite number | `[::op_annot::eng_or_blank $v]` | the sheet's own proc — the whole item |
| a non-finite number | `[::rdw::_nonfinite_text $v]` | issue 1272: `nan` blanked is a silent loss |
| anything else | `[::rdw::_oneline $v]`, verbatim | a model name, `-`, `1.5u`, `1.5 2.5`, `50%` |

The third arm is the one that is **not purely notation**, and it is on the owed
ledger as a rule debt (below).

---

## The safety gate, and the value that made it visible

`to_eng` (`src/xschem.tcl:1902`) is

```tcl
proc to_eng {args} { ... uplevel #0 expr [join $args] ... }
```

so it **evaluates its argument at global scope**. A `devices` value arrives
from a raw file. `op_annot::eng_or_blank`'s `_finite` gate is what stops that,
which is why row EN2's structural leg counts names in the comment-stripped
`src/rdw.tcl`: **`eng_or_blank` at least once, `to_eng` exactly zero times**.
The suite's sabotage variant `SB-UNGATED` (a bare `to_eng $v`) fired the
canary — a raw file's string really did reach `uplevel #0 expr`.

The sharpest input is **`1e400`**. MEASURED on this binary:

```
string is double -strict 1e400  -> 1        (it parses)
to_eng 1e400                    -> infT     (it "converts")
op_annot::eng_or_blank 1e400    -> {}       (_finite's $v*0.0 == 0.0 raises)
rdw::_value_text 1e400          -> (did not converge)
```

`infT` reads like a measurement and would paste into a design review as one.

---

## What changed

One proc, `src/rdw.tcl`:

```tcl
proc rdw::_value_text {v} {
    if {[string trim $v] eq {}} { return {(no value reported)} }
    if {![string is double -strict $v]} { return [rdw::_oneline $v] }
    set e {NOFMT}
    catch {set e [::op_annot::eng_or_blank $v]}
    if {$e eq {NOFMT}} { return [rdw::_oneline $v] }
    if {$e ne {}} { return [rdw::_oneline $e] }
    return [rdw::_nonfinite_text $v]
}
```

Nothing else in `src/` moved, and the plan's three reasons hold as written:
`rdw::_row_param` (:2264, R2's row reader) matches only the name before the
colon, so a unit suffix does not cost the window its rows (EN1's last leg reads
every parameter name back out of the re-formatted block); the column width in
`format_answer` is computed from parameter **names** only, so alignment is
unaffected; and `_reslot_block` / `_reorder_shown` reuse already-rendered lines.

Load order is not a new dependency: `src/xschem.tcl:16780` sources
`op_annot.tcl` before `:16821` sources `rdw.tcl`, and `rdw.tcl` already calls
`::op_annot::devpath` (:670) and `::op_annot::type` (:883).

**The `NOFMT` sentinel is not decoration.** `catch` leaves it in place only when
the call **raised** — an `op_annot` that never loaded — and that arm falls back
to the raw text. Answering `(did not converge)` there would invent a
non-convergence for a number the simulator computed perfectly well. MEASURED by
renaming `eng_or_blank` away in a live interpreter: `1.11e-05` -> `1.11e-05`,
`nan` -> `nan`, and both come straight back when it is renamed home. The cost,
recorded in the comment: in that (unreachable-as-shipped) arm a `nan` prints raw
again, exactly as it did before this item, because telling it apart without the
sheet's proc would mean a second spelling of "is this finite" in this file —
the drift the item exists to remove.

---

## The measured conversion table (this binary, shipped `ev_precision` 4)

```
1.11e-05 -> 11.1u    0.001 -> 1m      1e-15 -> 1f      1.2e9 -> 1.2G
-1.11e-05 -> -11.1u  0.75 -> 0.75     0 -> 0           1.2e-05 -> 12u
2.5e-3 -> 2.5m       4.7e-12 -> 4.7p  1.234567e-05 -> 12.35u (12.3457u at 6)
nan / inf / -inf / 1e400 -> (did not converge)
sg13g2_lv_nmos, -, 1.5u, {1.5 2.5}, 50%, [set ::en_canary 1] -> verbatim
```

A genuine `0` still prints `0` (F12's row): invariant I3 forbids fabricating a
number for a missing vector, not showing a real zero.

---

## The input no row saw — row EN7, added by the implementing pass

The crew brief asks: *"write down the input most likely to break your change,
and check whether any row would see it."* The answer here was a value **outside
`to_eng`'s SI ladder**, and no row saw it. MEASURED at `ev_precision` 4:

```
1e-321  -> 9.98e-304a     (denormal, below atto: an exponent AND a suffix)
1e20    -> 1e+08T         (above tera: the same mixed form at the top)
0x10    -> 16   0b101 -> 5   +5 -> 5   5. -> 5   .5 -> 0.5
```

Two of those read oddly and one silently rebases a hex literal — and **none of
it is this item's doing**: it is `to_eng`, and the sheet prints the same thing
for the same value. That is the point of the shared proc, so **EN7 asks for the
equality** (`rdw::_value_text` == `op_annot::eng_or_blank`, byte for byte) plus
the two invariants that must hold whatever `to_eng` answers: never blanked,
never `(did not converge)`. It is written as an equality on purpose — pinning
`9.98e-304a` as a literal would fence a libm denormal this item does not own and
would red on the day someone improves `to_eng`'s ladder, at which point **both
surfaces move together**. EN7 is red before the change too (`1e-321` printed raw
is not what the sheet prints for it), proved in memory by restoring the old body
into a live interpreter — the tree was not touched.

---

## Result

```
test_rdw_window_1245      --nogui  ALL PASS (134)   was 127, and 20 red with the rows in
test_rdw_window_1245      :99      ALL PASS (146)   was 139
test_op_param_store_1245  --nogui  ALL PASS (130)   unmoved (BE0's golden moved with it)
test_rdw_keys_1245        :99      ALL PASS  (59)   unmoved
test_op_annot  (control)  --nogui  ALL PASS (485)   unmoved
```

**FIXED** — but a number's format is a pixel judgement and no count settles it.
Look debt `the_RDW_engineering_notation` carries "suites green, please look".

---

## What is owed

* **Rule debt `1341_nonfinite_in_the_devices_bucket`** — the one decision here
  that is beyond notation. DD-7 forbids the blank; invariant I3 forbids the raw
  `nan`; the crew took the window's existing words. Three options, the user's
  call.
* **Look debt `the_RDW_engineering_notation`**, updated in place.

## What this item did NOT touch

Issue **1330** (`rdw::_apply_now` swallows an apply failure) and issue **1331**
(the narrow arm's space-in-path refusal). R5 changes no status line and calls no
`apply`, so it goes near neither.

⚠ **1330's own issue file still reads `Status: FILED, NOT FIXED`, and that is
now stale**: item R2 carried the fix (`src/rdw.tcl:2997` says so in its own
comment, and NUMBERING.md's 1338 entry claims it). Recorded here rather than
edited, because 1331 and 1330 are not this item's files and a crew that quietly
re-statuses another item's issue is how a batch loses track of what was
actually measured.

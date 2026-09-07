# 1239 — `ase::expand_path` still uses `subst`, and now expands SIMULATOR paths

**Status:** FIXED 2026-09-07 (ASE-L registry loose-ends batch), **in two passes
the same day** — the first closed the execution hole, the second closed the
silent-literal family the first one opened going the other way (see
**SECOND PASS**, at the end of this file). Filed 2026-09-01, at the
`annotate` → `fluid-editing` merge.
Pre-existing on `annotate`; the merge did not create it but **did make it more
reachable**, which is why it is filed now rather than left where it was.

## The hole

`ase::expand_path` (`src/ase.tcl`) is:

```tcl
proc ase::expand_path {p} {
  if {[catch {uplevel #0 [list subst -nocommands -nobackslashes $p]} out]} {
    return -code error "ase: cannot expand model path '$p': $out"
  }
  return $out
}
```

**`subst -nocommands` is not a sandbox.** MEASURED on Tcl 8.6.14:

```tcl
set ::RAN 0
subst -nocommands -nobackslashes {$A([set ::RAN 1])/x}
;# ::RAN is now 1
```

Tcl still evaluates a `[...]` sitting inside the **array index** of a variable
substitution, because the index is parsed as a script word before the
(suppressed) command-substitution pass ever applies. This was driven end to end
on this tree by `fluid-editing`: an `exe` of
`$env([exec touch /tmp/.../PWNED])/ngspice` created the file during what was a
pure *staleness query* — the caller returned `{}` and looked innocent.

## What the merge changed

`ase::sim_register` calls `ase::expand_path` on the simulator's path, and the
merge made the registry **the only** route from a configured simulator to a run.
So the expander now sits on the path of every registered simulator, not only
model files — reached from `Setup > Simulators…`, from the Command window, and
replayed by `ase::sim_load_conf` at startup for every location already saved.

**⚠ AND THAT LAST CLAUSE USED TO SAY MORE THAN IT SHOULD.** It read "from
`ase::sim_load_conf` **at startup**, on a file that is a plain Tcl script in
`$USER_CONF_DIR`", which reads as *the hostile conf file is a route this fix
closes*. It is not. `ase::sim_load_conf` (`src/ase.tcl`) does
`uplevel #0 [list source $path]`: a hand-written hostile `ase_simulators` is a
Tcl script with unrestricted execution at global level long before any expander
sees a string, and hardening the expander buys **nothing** against it.

The routes that ARE closed, exactly:

* **a `.state` file, which is DATA.** `ase::state_load` reads it as a flat Tcl
  list and merges a dict — it sources nothing — and its `models` `file`,
  `includes` `file` and `pre_commands` `cmd` reach `ase::expand_path` when the
  deck is composed — the `.include` card, the `.lib` card and `pre_commands`,
  all three inside `ase::render_deck` (cited here as `src/ase.tcl ~9139–9150,
  ~9406` until the close-out round, which matched no version that has ever
  existed: those lines are signal-browser caption code and cosim cache
  commentary. Named by PROC now, because a line number in prose rots silently
  and this file has now been wrong about one twice). Opening someone else's
  testbench ran what their state file said. This is the one that crosses a
  privilege boundary.
* **the LOCATION field of `Setup > Simulators…`.** Four procs —
  `ase::casemode_status`, `ase::casemode_report`, `ase::sim_caps_have_path` and
  `ase::sim_capabilities_path` — expand it under a `catch` merely to
  RENDER status, and `ase::sim_register` expands it to record it — text that had
  only been typed, never run, was executed.

What `sim_load_conf` contributes is **reach, not privilege**: it replays the
saved `ase::sim_register` lines at startup, so a location recorded earlier is
re-expanded with nobody present. That is a reason the thing on that path must be
a parser rather than an evaluator; it is not a reason to call the conf file a
closed hole.

## The fix exists in this tree

`sim_expand_vars` (`src/xschem.tcl`, kept from `fluid-editing` under a name that
no longer claims a profile) is the hardened expander: `$name`, `${name}` and
`$name(index)` at global level, literal index characters only, and an index
carrying `[`, `$` or a backslash **refused outright** rather than resolved. It is
currently **callerless on purpose** — its last caller went with the profile
layer, and deleting the tree's one fix at the commit that made the registry the
only path to a simulator would have been moving the hole somewhere more
reachable and throwing the fix away.

`tests/headless/test_sim_casemode_registry.tcl` section D (CS157k/l/m) drives it
and is what stops it being removed as dead code.

## What it needs

Point `ase::expand_path` at `sim_expand_vars`, then decide the one behavioural
question it raises: **an index this expander refuses is currently an error, and
model paths in the wild may contain shapes it refuses.** So the change needs a
survey of the committed `.state` fixtures' model paths before it lands, or a
compatibility arm that falls back to the literal rather than raising.

Not done at the merge because it is a behaviour change to model loading and
belongs in its own commit with its own measurement.


## What was done (2026-09-07)

`ase::expand_path` (`src/ase.tcl`) now calls `::sim_expand_vars` and nothing
else. It keeps its own error wrapper, so the message a caller sees is unchanged
in shape (`ase: cannot expand model path '<p>': …`).

### The survey, which is what gated the change

"An index this expander refuses is currently an error, and model paths in the
wild may contain shapes it refuses" was settled by measurement, not by argument.
Every one of the **104 committed `.state` files** was parsed and each `models`
`file`, `includes` `file` and `pre_commands` `cmd` expanded through BOTH the old
`subst -nocommands -nobackslashes` and `sim_expand_vars`, with the referenced
variables stubbed so the comparison was of the EXPANSION and not of a lookup:

* **22 distinct strings**
* **0 refused** by the new expander
* **0 expanding differently**

Two findings from it are load-bearing and are now written into the code and the
spec:

* the shipped mixed-signal `pre_commands` carry **literal `[ %s ]`** — ngspice
  `auto_bridge` cards — and they go through this same proc. A hardening spelled
  "refuse any bracket" would have passed every other row in
  `test_sim_casemode_registry` and broken those benches. The refusal is scoped to
  the **array index**, not to the character, and that is why;
* `$::180MCU_MODELS/sm141064.ngspice` starts its variable name with a **digit**.
  Both expanders accept it (`[A-Za-z0-9_]+` allows a leading digit), so the
  gf180 benches are unaffected.

The shipped `xschemrc` files were checked too: `::MODELS_NGSPICE`,
`::SG13G2_OSDI`, `::SKYWATER_MODELS`, `::180MCU_MODELS`, `::SKYWATER_STDCELLS`,
`::PDK_ROOT` and `::PDK` are all set to plain absolute paths built with
`file join`, so no expansion result feeds another one.

### Landed plain — no compatibility fallback

Nothing in the tree is refused, so the issue's own first branch applies. The
callers for which a bad location is a fact about the user's disk rather than a
defect — `ase::sim_register`, `ase::sim_capabilities_path`,
`ase::sim_caps_have_path`, `ase::casemode_report`, `ase::casemode_status` —
already `catch` this and fall back to the literal (issues 0938 and 0945). The
model, `.include` and `pre_command` callers raise, exactly as they already did
for an unset variable.

**The residue is on the ledger as a `rule` debt (`owed.sh add rule 1239`)**,
because it is a user-visible choice about paths that are NOT in this tree. It
has **two directions**, and the first pass recorded only one of them:

* **REFUSAL (recorded at the first pass).** A model path in the wild whose array
  index carries `[`, `$` or a backslash is now an ERROR where it used to expand
  (and, in the `[` case, EXECUTE).
* **THE OTHER DIRECTION (added by the second pass, below).** Shapes the OLD
  expander *raised* on came back from the new one **silently, as a literal, with
  the dollar still in the path** — `$(V)/x`, `${}/x`, `$::/x`, an unterminated
  brace form — or **half-expanded**: `$V::/x` became `<value>::/x` and `$V(/x`
  became `<value>(/x`. That is now an error too. And one shape went the other
  way again: `$:::name` (a colon run of three or more) *did* resolve under
  `subst` and is now refused rather than given a second spelling of the
  namespace separator.

Shipped as the loud refusal in every direction; the alternative the user may
still prefer, for either direction, is a compatibility arm that falls back to
the literal rather than raising.

### Rows

`tests/headless/test_sim_casemode_registry.tcl`, section D, **CS157n..CS157v** —
nine rows. **Three of them were red before the change** (`CS157n`, `CS157o`,
`CS157v`); the other six were green already and are regression guards, kept
because they cover the half of the change most likely to break benches. The first
pass reports a sabotage per row; the second pass did not re-run those six
sabotages and does not restate them as its own measurement.

| row | what it measures |
|---|---|
| `CS157n` | a command substitution inside an array index is refused AND the flag it would set stays 0 |
| `CS157o` | …and the file the payload would create does not exist |
| `CS157p` | `$name` still expands |
| `CS157q` | `${name}` and `$::name` still expand |
| `CS157r` | `$env(index)` still expands |
| `CS157s` | a plain absolute path comes back verbatim |
| `CS157t` | an unset variable is still an ERROR, not a silent empty path |
| `CS157u` | all seven shapes the committed `.state` fixtures contain still expand |
| `CS157v` | STRUCTURAL: the proc delegates to the refusing expander and evaluates nothing itself |

(An earlier revision of this file said "nine rows, all red before the change" two
lines above and "only CS157n, CS157o and CS157v were red" here. The second was the
true one; the first is corrected.)

---

## SECOND PASS (2026-09-07, same day) — the fix opened a door the other way

The first pass is not in doubt: `ase::expand_path` delegates, two end-to-end
exploit drives PWNED on HEAD and are clean on the fix, and a differential fuzz
found `new_executions = 0`. What the first pass did **not** disclose is that the
same fuzz's divergences were all **one family running the opposite way**.

### The family, enumerated

Measured with the two expanders side by side in `tclsh` (Tcl 8.6.14), `::V` set:

| shape | old `subst -nocommands` | new expander, before this pass |
|---|---|---|
| `$(V)/x` | `can't read "(V)"` | returned **verbatim** |
| `$()/x` | `can't read "()"` | returned **verbatim** |
| `${}/x` | `can't read ""` | returned **verbatim** |
| `${abc/x` (unterminated) | `missing close-brace for variable name` | returned **verbatim** |
| `$::/x` | `can't read "::"` | returned **verbatim** |
| `$V::/x` | `can't read "V::"` | `/V::/x` — **half-expanded** |
| `$V:::W/x` | `can't read "V:::W"` | `/V:::W/x` — half-expanded |
| `$::V::/x` | `can't read "::V::"` | `/V::/x` — half-expanded |
| `$V(/x` | `missing )` | `/V(/x` — half-expanded |
| `$V(k` | `missing )` | `/V(k` — half-expanded |
| `$V(a(b))/x` | `can't read "V(a(b)"` | `/V(a(b))/x` — half-expanded |
| `$:::V/x` | `/V/x` — **expanded fine** | returned verbatim |

**It is two mechanisms, not twelve shapes**, and that is why an enumeration by
example would have missed some:

* **M1, no match at all.** The `$` was emitted as a literal and the scan moved
  on. But Tcl's own parser *does* read `$(idx)` (a variable whose NAME is empty),
  `${}`, an unterminated brace form and a bare `$::` as references, and raises on
  every one.
* **M2, a match SHORTER than Tcl's.** The reference expanded and the remainder
  became literal text. `$V::` is the name `V::` to Tcl; `$V(` is an unterminated
  index. Both raised there; here they half-expanded.

A model path that used to fail loudly at load became a filename with a `$` in it,
which fails later, somewhere else, with a worse message.

### Scale

A differential fuzz over **54,240 strings** (exhaustive to length 3 over a
17-character alphabet chosen to hit every parser branch, plus every length-5
`$abcd`): **4,186** in this family — 4,003 M1 (dollar survives) and 183 M2 (no
dollar left but the path is still wrong) — plus **1** shape that expanded
differently (`$:::V`). The rest of the divergences, 1,614 of them, were both
raising with a different message, which is not a behaviour change.

### The decision, and why it is not an escalation

**A silent literal is wrong**, so the shapes raise again. The argument is not
taste: the whole reason `ase::expand_path` raises on an unset variable — a rule
this tree already shipped and CS157t already guards — is that a path that cannot
be resolved must fail at the point it is read, not become a filename. A `$` that
the expander declined is exactly the same condition wearing different clothes.
`sim_expand_vars` now refuses at both seams:

* a `$` it declined **that Tcl would have read** — the next character is `{` or
  `(`, or the next two are `::`;
* a bare name it stopped short of **that Tcl would have continued** — `::` or `(`
  immediately after it. Scoped to the bare-name-without-index case, because a
  completed `(idx)` and the braced form are whole references to Tcl too
  (`${V}::` and `$A(k)(j)` mean the same to both expanders and must keep working).

**A `$` that Tcl itself leaves literal is still literal here** — `$/x`, `$$V`,
`$V:x` (ONE colon ends a name for Tcl too), `$V-2`, a trailing `$`. Tightening
those would refuse paths both expanders always accepted, about which no defect
was ever reported. `CS157z` is the row that stops that over-reach **on the M1
side, and only there**.

⚠ **THE M2 SCOPING GUARD IS COVERED BY NO ROW, AND THE SENTENCE ABOVE USED TO
READ AS IF IT WERE.** The second bullet's scoping — `if {!$braced && !$hasidx}`
in `sim_expand_vars` — is the line that keeps `${V}::`, `${V}(k)` and
`$A(k)(j)` working, and NOTHING in the suite asserts their expansion.
MEASURED 2026-09-07 by deleting it (`if {1} {`), then restoring by `cp` with
the md5 re-checked (`22accd59d10a5a9186bdb6407c9df4a0`):

```
${CS157V}::/x    shipped -> /CS157/varset::/x   sabotaged -> RAISES
${CS157V}(k)/x   shipped -> /CS157/varset(k)/x  sabotaged -> RAISES
$CS157VA(k)(j)/x shipped -> KV(j)/x             sabotaged -> RAISES

  ⚠ THE THIRD LINE NAMED `CS157V` UNTIL THE CLOSE-OUT ROUND AND DID NOT
  REPRODUCE AS PRINTED. `CS157V` is the SCALAR the first two lines need, so
  `$CS157V(k)(j)/x` RAISES `can't read "CS157V(k)": variable isn't array` on the
  shipped tree as well -- no differential at all. The third shape needs its own
  ARRAY variable, written `CS157VA` above. The FINDING is unchanged and was
  re-driven independently: with the scoping deleted, all three shapes stop
  expanding, and four suites stay ALL PASS with zero FAIL names.

test_sim_casemode_registry ALL PASS (43)   test_ase_simcaps_0948 ALL PASS (108)
test_ase_simreg_0931       ALL PASS (95)   test_sim_plain_run    ALL PASS (53)
```

Not one row moved in four suites. `CS157z`'s six shapes are all M1
(`$/x`, `$$V/x`, `$V:x`, `$V-2/x`, `/plain/$`, `$V/a$`) and none is braced or
indexed; `CS157aa` is a LOOSENING detector by construction (`if {$orc &&
!$nrc}`), so a TIGHTENING is invisible to it — which is exactly what deleting
the scoping is. All three shapes already sit in the `CS157aa` corpus as
strings; they are simply never asserted as *expansions*. **The fix is one row**
(add them to `CS157z`, or a `CS157ac` beside it); it was not written in the
close-out round because that round may not add behaviour or rows, and it is
recorded here rather than left for a reader to re-derive.

**The ledger debt is extended rather than replaced** (see above): the user is now
ruling on both directions, which is what the first pass should have asked for.

### Re-measured after the fix

* the same 54,240-string fuzz: **0** shapes where the old raised and the new
  returns a value, **0** where both succeed with different results. The single
  remaining behavioural divergence is `$:::V` — old resolved it, new refuses —
  which is the stricter direction and is pinned by `CS157ab`;
* an independent **200,000-case random fuzz** (lengths 2–9, same alphabet, no
  `[` — the old expander is the oracle and a bracket in an index *is* the
  payload): same result, 8 hits, all of them `$:::name`;
* **the `.state` survey re-run against the tightened parser**: 104 committed
  files, 22 distinct strings, **0 refused, 0 differing** — unchanged;
* the shipped `cadence_style_rc` `ASE_DEFAULT_INCLUDES` / `ASE_DEFAULT_PRE_COMMANDS`
  strings (`$::180MCU_MODELS/design.ngspice`, `pre_osdi $::SG13G2_OSDI/*.osdi`):
  identical under both expanders.

### Rows added — `CS157w`..`CS157ab`

| row | what it measures | red before this pass? |
|---|---|---|
| `CS157w` | a `$` this expander cannot read is an ERROR, not a literal in a path (5 M1 shapes) | **RED** |
| `CS157x` | a reference the parser stops short of is an ERROR, not a half-expansion (6 M2 shapes) | **RED** |
| `CS157y` | …and the half-expansion is really gone, message and all, not merely flagged | **RED** |
| `CS157z` | a `$` Tcl itself leaves literal is still passed through (6 shapes) — the anti-over-reach guard **for the M1 seam only; the M2 scoping has no row, see above** | green (guard) |
| `CS157aa` | DIFFERENTIAL: over a 36-shape corpus, no shape the OLD expander refused comes back from the new one as a value | **RED** |
| `CS157ab` | a colon run of three or more is REFUSED where `subst` resolved it — the stricter direction, pinned so it is not a surprise | **RED** |

`CS157z` was green on arrival, as an anti-over-reach guard must be; it is proven
non-vacuous by sabotage S4 below. Five of the six were red first.

### Sabotage, one per row

| # | what was broken | row that went red, by name |
|---|---|---|
| S1 | M1 refusal disabled | `CS157w`, `CS157aa`, `CS157ab` |
| S2 | M2 `::` refusal disabled | `CS157x`, `CS157y`, `CS157aa` |
| S3 | M2 `(` refusal disabled | `CS157x`, `CS157aa` |
| S4 | M1 refusal made to fire on EVERY unmatched `$` (over-reach) | `CS157z` |
| S5 | colon run narrowed to exactly two colons | `CS157ab` |
| S6 | refusal wording changed | `CS157y` |

`src/xschem.tcl` was restored with `cp` after each and the md5 verified
(`82d2a1e40f7eb5eb8bf170cf9dc7b005`).

### Suites

`test_sim_casemode_registry` 37 → **ALL PASS 43** (six added, no name moved);
`test_ase_simreg_0931` **ALL PASS 91** before and after; `test_ase_persist`
**ALL PASS 137** before and after.

# ASE-L: the device operating-point probe (transistor + R/L/C/D)

Clicking a **device body** in ASE-L's Select On Design mode opens a dialog of
that device's ngspice operating-point parameters and queues the ticked ones as
session Outputs, saved and/or plotted like any other output row.

For a **transistor** that's `gm`, `id`, `cgs`, `vth`, `gds`, `vdsat`, … — the
gm/ID design workflow: the quantities a designer sizes a device against are
internal device parameters, not node voltages, and before this they could not
be reached from the schematic at all.

For a **resistor, capacitor or inductor** it's the two quantities that make a
two-terminal passive a probe target at all: the **current through** it and the
**voltage across** it (§8). A **diode** gets the same current+voltage pair plus
its small-signal `gd`/`cd`, mirroring the transistor table's shape.

Related: `ase_l.md` (the window, the menus, Select On Design v1 scope),
`simulator_profiles.md` §13 (case modes).

---

## 0. What this replaces

`ase_l.md` recorded a deliberate v1 restriction:

> Per-terminal currents of OTHER devices are deferred: ngspice needs
> `.options savecurrents` plus `@m.x<inst>.<subdev>[id]`-style names that depend
> on subcircuit internals invisible to the schematic click.

A click on a transistor therefore produced a notice and queued nothing.

**The restriction was over-cautious.** The name *is* derivable from the click,
because the two pieces it needs are both on the symbol: the instance's
`spiceprefix`+`name` (what the netlister will call it) and the callee named in
the symbol's own `format` string (what subcircuit it instantiates). Neither
needs the model file, and neither needs a run. §1 measures the result.

What was genuinely right in that paragraph is that the *inner device* name is a
PDK convention rather than an ngspice guarantee — §2 records the convention, and
§5 records the escape hatch that keeps a PDK which breaks it from being a dead
end.

---

## 1. RECEIPT: the four naming forms

ngspice addresses an internal device parameter as `@<dev>[<param>]`, where
`<dev>` is the device name qualified by the instance chain it sits in, **with
the device letter hoisted to the front**.

All four forms measured with **ngspice-47**, sky130A models
(`sky130.lib.spice`, `tt`), before any code was written:

| case | schematic | ngspice name |
|---|---|---|
| top-level primitive | `M1` | `@m1[gm]` |
| top-level PDK subckt | `XM1` | `@m.xm1.msky130_fd_pr__nfet_01v8[gm]` |
| nested primitive | `X1` / `M2` | `@m.x1.m2[gm]` |
| nested PDK subckt | `X1` / `XM1` | `@m.x1.xm1.msky130_fd_pr__nfet_01v8[gm]` |

Deck used for rows 3–4:

```spice
.subckt amp d g
XM1 d g 0 0 sky130_fd_pr__nfet_01v8 L=0.15 W=1 nf=1 mult=1 m=1
M2  d g 0 0 nch w=1u l=0.15u
.ends
X1 d g amp
```

```
@m.x1.xm1.msky130_fd_pr__nfet_01v8[gm] = 1.708952e-04
@m.x1.m2[gm]                           = 1.611778e-18
```

**The unified rule** (`devparam_join`): with no instance path the bare device
name stands alone; with a path, the name becomes
`<first letter of dev>.<path><dev>`. A top-level primitive is the only form
that takes no hoist, because it has no path.

---

## 2. RECEIPT: which parameters exist

Probed one at a time with `print @m.xm1.m…[<p>]` after an `op`, ngspice-47 +
sky130A BSIM4.

**Available** (and therefore what the dialog offers):

| group | parameters |
|---|---|
| Currents | `id` |
| Voltages | `vgs` `vds` `vbs` `vth` `vdsat` |
| Conductances | `gm` `gds` `gmbs` |
| Capacitances | `cgg` `cgs` `cgd` `cgb` `cdd` `cds` `cbs` `cbd` |
| Charges | `qg` `qd` `qs` `qb` |

**Refused** — `Error: no such parameter` — and deliberately NOT offered:

```
is   ig   ib   idb   isb   gmb   ron   beta
```

> **The table is model-class-specific, not universal.** `is`, `ig` and `ib` DO
> exist on a level-1 MOSFET (`show m1 : all` lists them) and do NOT exist on
> BSIM4. The shipped table is the BSIM4 set, because that is what every modern
> PDK uses. A level-1 device will therefore be offered entries it cannot
> deliver. The honest fix, if that ever matters, is to read the list from a
> loaded raw — **not** to widen the table hopefully.

### 2a. The inner-device convention

sky130's `sky130_fd_pr__nfet_01v8` subckt contains

```spice
Msky130_fd_pr__nfet_01v8  d g s b nshort_model l={l} w={w} …
```

i.e. the inner device is `M` + the subckt's own name. That is a **PDK
convention**, not something ngspice guarantees, and it is the one guess in this
feature. §5 is the escape hatch.

---

## 3. RECEIPT: the deck spelling and the raw spelling DIFFER

This is the trap the whole feature is built around, and both halves were
measured.

**`.save` accepts only the bare form.** With a `.tran`:

```spice
.save v(d) @m.xm1.m…[gm] @m.xm1.m…[id] @m.xm1.m…[cgs]   → all four vectors present
.save i(@m.xm1.m…[id]) v(@m.xm1.m…[vth]) @m.xm1.m…[gm]  → id is SILENTLY DROPPED
```

The second run **succeeds** — `rc=0`, no warning, no error — and the raw simply
comes back without the `id` vector. The `v(…)` wrap around `vth` was accepted;
the `i(…)` wrap around `id` was not.

**The raw then names those same vectors wrapped.** From the first deck's raw
header:

```
0  time                                     time
1  v(d)                                     voltage
2  @m.xm1.msky130_fd_pr__nfet_01v8[gm]      admittance
3  i(@m.xm1.msky130_fd_pr__nfet_01v8[id])   current
4  @m.xm1.msky130_fd_pr__nfet_01v8[cgs]     capacitance
```

Saving the full parameter set gives the complete mapping:

| parameter type | raw name |
|---|---|
| current-typed (`id`) | `i(@dev[p])` |
| voltage-typed (`vgs` `vds` `vbs` `vth` `vdsat`) | `v(@dev[p])` |
| conductance / capacitance / charge | **bare** `@dev[p]` |

The discriminator is the **parameter's first letter**, which is why `vth` and
`vdsat` land correctly despite naming no terminal pair.

### 3a. Consequence for the code

Two spellings, two places, and they must never be collapsed into one:

* **`sod_expr`** emits the **bare** form → this is what reaches `.save`.
* **`plot_map_expr`** converts bare → **wrapped** → this is what the viewer
  resolves against the raw.

A "simplification" that unifies them loses either the save or the trace,
**silently**. `test_ase_devparam.tcl` DP43/DP44 are the pair that pins it.

---

## 4. The gesture

Entered exactly like the existing picks, through **every** door onto the pick
mode — then click a transistor:

* **Outputs > To Be Saved > Select On Design** — flavor `{save 1 plot 0}`
* **Outputs > To Be Plotted > Select On Design** — flavor `{save 1 plot 1}`
* **Add/Edit Output dialog > "From Design…"** (also the `-->` strip button) —
  flavor taken from that dialog's own Save/Plot checkboxes, with save coerced
  to 1 when BOTH are unticked (a row with neither is one `render_deck` emits
  nothing for)
* **Results > Direct Plot** — `plot` mode: traces, no output rows written

Nothing special was needed to make From Design work: it computes a flavor and
calls the same `select_on_design` in the same default `outputs` mode, and
`sod_click` cannot tell which door armed it — it reads only
`sod($key,flavor)` and `sod($key,mode)`. The flavor arithmetic is pinned by
`test_ase_devparam` DP50–DP53 and the integration — real session, real sky130
nfet, real `select_on_design` — by `test_ase_interact` I6c.

**Click ordering is deliberate.** `sod_click` tries, in order:

1. a source-class instance (`vsource`/`ammeter`) → `i(<inst>)`, unchanged;
2. anything resolving to a **net** under the cursor → `v(<net>)`, unchanged;
3. **(new)** an instance whose symbol `type` has a parameter table → this probe;
4. otherwise the scope notice.

Because the net attempt comes first, **a click on or near a transistor's
terminal still queues that terminal's node voltage**, exactly as before — the
device probe only claims clicks on the device **body**, which previously
produced nothing but a notice. The new arm strictly replaces the notice path
and changes no gesture that already worked.

Coverage is symbol `type` ∈ {`nmos`, `pmos`, `resistor`, `capacitor`,
`inductor`, `diode`} (§8). A plain subcircuit, BJT, or any other `type` still
falls through to the notice — devparam_table returning `{}` for it is exactly
what `sod_click` tests to decide whether a click is a device pick at all.

---

## 5. The dialog

Title **Select Device Outputs**; opened per click, modal.

* An **editable `ngspice device:` field**, prefilled with the derived
  `@<dev>` string.
* **Checkbuttons grouped** by the §2 categories. Checkbuttons rather than the
  bus dialog's listbox: ~22 entries across five semantic groups, of which the
  user picks a scattered handful (`gm` + `id` + `cgs` live in three different
  groups). A listbox would flatten that into one scrolling column needing
  Ctrl-click, and would lose the grouping that makes the list readable.
* **All / None**, **OK / Cancel**. Nothing is ticked when it opens, so OK with
  an empty selection is a no-op — the same contract `bus_dialog` has.
* Selection is returned in **table order**, never `array names` order.

**Why the device field is editable.** It is the escape hatch for the one guess
in this feature (§2a). When a PDK names its inner device something other than
`m`+subckt, the user retypes the base once and everything downstream — save,
plot, raw lookup — follows the corrected string. The alternative was a feature
that silently does not work on that PDK with no way to find out why.

---

## 6. What rides along for free

Because a device parameter becomes an **ordinary output row**, everything the
Outputs pane already does applies without new code:

* dedupe/merge on the exact expression — re-picking `gm` under To Be Plotted
  ORs the plot flag into the existing row rather than duplicating it;
* the case mode (`fold`/`preserve`/`distinguish`) is resolved **once per
  gesture** and applied to every parameter of that click, so two parameters
  from one click cannot disagree about spelling;
* hierarchy: names are measured from the **session's own design level**
  (issue 0168), so a descended pick matches that session's deck;
* Direct Plot's colour cue (issue 0153) paints the **instance** — a device
  parameter has no net to colour;
* bus expansion leaves it alone: `bus_expr_bits` matches `^v\(…\)$` only, so
  `@m1[gm]`'s brackets are never mistaken for a bus subscript.

---

## 8. RECEIPT: the R/L/C/D extension

Resistor, capacitor, inductor and diode add a second, smaller shape to the
probe: **current through** and **voltage across** the two-terminal device.

### 8a. Current: the SAME `@dev[param]` pipeline, one generalization

`@r1[i]`, `@c1[i]`, `@l1[i]` and `@d1[id]` were all MEASURED working on
ngspice-47 and coming back **current-typed** in the raw — the identical
mechanism §1/§3 already built for transistors. The only thing that pipeline
had wrong for a non-mosfet device was `devparam_base`'s PDK-subckt branch,
which hard-coded the hoisted device letter as `m` because transistors were the
only ctype it had ever seen. `devparam_devletter {ctype}` replaces the literal
with a per-ctype table (`nmos`/`pmos` → `m`, `resistor` → `r`, `capacitor` →
`c`, `inductor` → `l`, `diode` → `d`), so a PDK-style subckt-wrapped passive
hoists correctly too — pinned by `test_ase_devparam` DR35/DR36 against a
stand-in PDK resistor symbol (`dp_pdkres.sym`, mirroring `dp_pdkfet.sym`'s
role for §1's PDK forms).

`devparam_raw`'s existing first-letter discriminator needed **no change**: `i`
and `id` both start with `i` and fold to the same wrapped raw name §3 already
describes for transistor currents.

### 8b. Voltage: NOT the `@dev[param]` pipeline — MEASURED why not

A transistor has clean v-typed internal parameters (`vgs`, `vds`, `vth`, …).
**R/L/C do not**, and this was measured rather than assumed. Probed on
ngspice-47 against a resistor/capacitor/inductor/diode test circuit
(`.save`+ascii-raw, the same technique §3 used):

| expression | raw type |
|---|---|
| `@r1[i]` / `@c1[i]` / `@l1[i]` / `@d1[id]` | `current` (clean, used for §8a) |
| `@d1[vd]` | `voltage` (clean — but see below) |
| `@r1[resistance]` | `voltage` — **not actually a voltage** |
| `@l1[inductance]` | `current` — **not actually a current** |
| `@r1[ac]`, `@r1[dtemp]`, `@l1[nt]`, `@l1[flux]`, … | `voltage` (a generic
  fallback ngspice hands any real-valued parameter it has no specific type
  information for, not a meaningful classification) |

So a `@dev[param]`-style "voltage" for a resistor or inductor would either not
exist or would carry a **misleading raw type inherited from ngspice's generic
parameter typing**, not from the quantity's actual units. `@d1[vd]` IS clean
and numerically equals the diode's terminal-pair voltage — but this probe does
**not** use it, so "Voltage" means one thing for every device class it covers
rather than `@dev[vd]` for diodes and something else everywhere else.

**Voltage-across is instead built exactly like an ordinary net-voltage
pick**: `v(pin1_net,pin2_net)`, using the clicked instance's own two terminal
nets.

* `devparam_pin_net {n idx}` gets the net at pin index `idx` (0-based, symbol
  pin order) by **coordinate**, via `xschem instance_pin_coord` →
  `xschem flylines at` — the same resolution a terminal click already goes
  through (`sod_net_at`). By coordinate, not by pin **name**, because the
  standard library does not agree on one: `devices/res.sym` names its pins
  `P`/`M`, `devices/capa.sym`/`ind.sym`/`diode.sym` name theirs lower-case
  `p`/`m` — MEASURED off the symbol files, not assumed.
* `devparam_vacross_expr {n1 n2 mode}` folds each net token the way `sod_expr`
  folds an ordinary voltage pick (strip a leading `#`, `string tolower` unless
  the mode is `preserve`/`distinguish`) and joins them as `v(a,b)`. Either side
  missing → `{}`, the same "offered but undeliverable" contract
  `devparam_expr`'s empty-base case already has.
* `devparam_vacross {n baselvl mode}` hierarchy-qualifies each net through the
  same `sod_qualify voltage` issue-0161/0168 machinery an ordinary net-voltage
  pick uses, then calls the two procs above. Computed **once per click**, in
  `sod_device_pick`, only when the ctype's table actually offers `vacross` —
  never for a transistor pick, which never reaches the pin/net lookup at all.

`v(a,b)` is not an `@`-form, so it needs **no bridge**: `plot_map_expr` and
`output_kind` already pass a plain `v(...)` expression through unchanged (the
same code path an ordinary voltage pick already takes), and `sod_expr`'s
`devparam` arm applies only the case fold, no wrap. Pinned by
`test_ase_devparam` DR60–DR64.

### 8c. The dialog: `vacross` arrives pre-built

`devparam_dialog_build`/`devparam_dialog`/`devparam_dialog_done` gained one new
optional parameter, the pre-computed `vacross` expression string (`{}` when
the ctype's table has no `vacross` entry, or when it does but the pins could
not be resolved). `devparam_dialog_done` substitutes it directly for the
`vacross` key instead of running it through `devparam_expr` — `vacross` has no
`<base>[param]` shape, so it is the ONE parameter key this dialog does not
build from the editable device field. Pinned by DR50–DR54.

### 8d. Table

| ctype | groups |
|---|---|
| `resistor` / `capacitor` / `inductor` | Current `{i}`, Voltage `{vacross}` |
| `diode` | Current `{id}`, Voltage `{vacross}`, Conductance `{gd}`, Capacitance `{cd}` |

`vd` is deliberately **not** offered alongside `vacross` for diodes (DR06b) —
see §8b's reasoning: one meaning per group, not two spellings of the same
number.

---

## 7. Limits, stated plainly

* **The parameter sets beyond current/voltage-across are not measured for
  R/L/C.** `@r1[resistance]`, `@c1[c]`, `@l1[inductance]` etc. exist but come
  back mistyped in the raw (§8b) and are deliberately not offered — the
  "widen the table" trap §2 already warns about, now measured for a second
  device family.
* **The BSIM4 parameter set is assumed** for transistors, per §2 — a level-1
  device is offered entries it cannot deliver.
* **The dialog does not consult a loaded raw.** It shows what the device class
  offers, not what this particular run actually saved. Reading the real vector
  list from a loaded raw would make "available" literally true and would also
  fix both bullets above; it needs the raw-DB loan machinery
  (`ase::cosim_db_inventory`) and was left out of this pass.
* **The inner-device name is a convention** (§2a, generalized by §8a's
  `devparam_devletter`), mitigated by §5's editable field, not solved.
* **BJT is still not covered.** `type=npn`/`pnp` symbols fall through to the
  notice exactly as before — a sixth ctype devparam_table does not list.

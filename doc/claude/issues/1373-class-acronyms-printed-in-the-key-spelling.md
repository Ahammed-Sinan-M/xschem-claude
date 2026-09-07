# 1373 — Device-class acronyms printed in the internal lower-case spelling

**Status:** FIXED in the working tree (not committed by this crew).
**Area:** `src/op_param_lists.tcl` (the new display-name accessor),
`src/rdw.tcl` (the fifteen surfaces that printed the key).
**Ruling owed:** yes — see §7. `tests/headless/owed.sh add rule 1373`.

---

## 1. The user's words, verbatim

> I put cursor on cgs and the clicked Add button and said add to all mos (why is
> that not uppercase? MOS is an acronym!) for summary list, but, later, when I
> send summary list with 2 key, it never shows up.

The parenthesis is this item. (The Add-never-lands half is item **1372**.)
Their standing rule for this round, recorded in the crew brief: **UI copy is
terse, and acronyms are upper case.** `mos` is an internal key; `MOS` is what a
person reads.

---

## 2. The bench

Everything below was measured with the user's own `HOME`, from the repo root,
`./src/xschem` never a bare `xschem`, every launch carrying
`--logdir <scratch>`, GUI probes through `tests/headless/devdisplay.sh exec`
on `:99` (Xvfb, openbox 3.6.1, 1920x1080x24).

No user file written: `/tmp/Xschem.log.8` untouched (mtime still
**2026-09-06 00:17:08**), `~/.xschem/op_param_lists.conf` untouched
(**2026-09-04 17:27:01**).

---

## 3. Root cause

**The Results Display Window had no display-name layer for a device class at
all.** Every surface interpolated `$cls` — the store's raw primary key —
straight into prose.

* `::op_param_lists::class` is a pure classmap lookup that answers the **key**
  and nothing else, and the classmap's right-hand side is exactly five
  lower-case tokens: `bipolar capacitor diode mos resistor`.
* Its **identity fallthrough mints more** class keys from any PDK's `type=`
  tokens. Measured on the shipped trees: `npn`, `pnp`, `varactor`,
  `pwell_resistor`, `p_diffusion_resistor`, `n_diffusion_resistor`,
  `high_precision_p`, `subcircuit` (sky130); `inductor`, `esd` (IHP). Plus a
  measured asymmetry — `high_precision_poly_p` maps to `resistor` while
  `high_precision_p` does **not**.
* `rdw::_subject` stores that key in the subject dict under `class`, and
  **fifteen interpolation sites in four procs** printed it verbatim:
  `rdw::_narrowed_list` (2), `rdw::_shadow_why` (1), `rdw::_edit` (11) and
  `rdw::scope_dialog_build` (1). No other file in `src/` prints a device class
  to a user; the C sources print none.

So the user's two sentences — the radiobutton `every device of class mos` and
the verdict `gm is already in the mos annotation list` — are the **same missing
layer twice**.

`rdw.tcl` had already solved this exact problem one concept over:
`rdw::_list_name` / `_list_gloss` / `_list_phrase` exist precisely because
"four surfaces read these strings and four literals would drift". Classes never
got that treatment. And the drift was already on paper: the spec writes **MOS**
in §2.2 and §3.4 while the implementation printed `mos`.

### 3.1 The sharp constraint, and why this is not `string toupper`

Two separate reasons, both measured:

1. **Class keys are case-sensitive**, so `MOS` is genuinely a *different key*:

       get_list class mos annotation -> {gm gm 1}
       get_list class MOS annotation -> ''      owns -> 0
       governs  mos annotation foo.sym -> flavor {mos foo*}
       governs  MOS annotation foo.sym -> ''    (_flavor_matches_class uses `eq`)

   The key is also a **field the user types by hand** into
   `op_param_lists.conf` (`list class mos annotation`, `class nmos mos`).
   `MOS` has no space, so unlike a two-word gloss it *looks* like a key — a
   user who reads "the MOS annotation list" and writes `list class MOS
   annotation` gets a silently dead entry.

2. **A blind case fold shouts the wrong things.** The identity fallthrough
   really does produce `pwell_resistor`, `high_precision_p` and `subcircuit`;
   `string toupper` would print `PWELL_RESISTOR`. The user's rule is *acronyms
   upper case*, not *everything upper case*.

---

## 4. What changed

### 4.1 `src/op_param_lists.tcl` — ONE accessor, in the store

New `::op_param_lists::class_label {cls}`, immediately after `set_class`: a
**literal namespace array + a pure proc**, so the file's source-time purity
contract (bare `source`, twice, into an interpreter with no `xschem` command)
still holds. The array is guarded with `if {![array exists classlabel]}` exactly
as `classmap` is, so a second source is a no-op rather than a silent reset of a
user's overrides. `set_class_label` is the rc extension door, matching
`set_class`; it deliberately does **not** `_mark_dirty`, because a display name
is not a settings-file row for the writer to round-trip.

Shipped table — **only rows whose display differs from the key**:

    mos MOS   npn NPN   pnp PNP   esd ESD

`resistor`, `capacitor`, `diode` and `bipolar` are already their own human
spelling and reach the reader through the **same identity return an unmapped
key takes**.

It lives in the store, and **there is no `rdw::_class_name` wrapper** — that
would be the second door. `op_param_lists.tcl` may not call `rdw::` (purity),
so an accessor over there could never be reached by the store's own sentences,
and a second copy is the exact drift this item exists to remove.

**Sites deliberately NOT routed**, with a comment at the accessor saying so:
`_dup_why`, `set_list`'s key reports, `_key_why`, `seed`'s divergence report
and the parser's reports. Every one prints the class as a **settings-file field
the user types back**. `seed`'s report also names the type tokens beside the
class, which is a second reason it keeps the key spelling.

### 4.2 `src/rdw.tcl` — all fifteen sites routed

* `rdw::_narrowed_list` — resolved once at the top (`set d [...]`), both arms.
* `rdw::_shadow_why` — the broad clause.
* `rdw::_edit` — resolved once beside `set cls`, as `set dcls`, and used at all
  eleven sentence sites. **`$cls` itself stays the argument to every
  `::op_param_lists::` call** (`_write_key`, `effective`, `governs`,
  `_find_triple`, `_shadow_why`); a new ALL-CAPS comment at the head of the
  proc says so, because that is the line a later reader will cross.
* `rdw::scope_dialog_build` — the `.sc.broad` radiobutton, the ONE Tk `-text`
  in this feature that carries a class.
* Two of `_edit`'s refusals **point at that radiobutton** ("Choose every device
  of class MOS instead"), so a comment at those two lines states the coupling
  and names row CL8 as its fence.

### 4.3 The sentences, measured after the change

    _narrowed_list mos annotation {}      -> MOS annotation list
    _narrowed_list, flavor arm            -> annotation list for cells matching
                                             sky130_fd_pr__nfet_01v8* of class MOS
    _narrowed_list pwell_resistor ...     -> pwell_resistor annotation list  (unchanged)
    add    gm  -> refused: gm is already in the MOS annotation list.
    up     gm  -> refused: gm is already the first row of the MOS annotation list.
    down   gds -> refused: gds is already the last row of the MOS annotation list.
    up     id  -> refused: id is not in the MOS annotation list. ...
    delete gm  -> ok: removed gm from the annotation list for class MOS.
    narrow del -> ok: ... The sheet still draws the MOS class list - a per-cell
                  display list cannot be expressed yet (issue 1310).
    no cell    -> refused: ... Choose every device of class MOS instead.
    glob cell  -> refused: ... Choose every device of class MOS instead.
    _shadow_why broad -> The MOS class list moved, but the device-flavor entry
                  foo* in the settings file also matches this cell and wins ...
    .rdw.scope.sc.broad -text -> every device of class MOS

And, immediately afterwards, the store still answers under the **key**:

    get_list class mos annotation -> {{gds gds 1}}   owns 1
    get_list class MOS annotation -> {}              owns 0

---

## 5. Why this needed new rows: the change is invisible to every existing golden

**Zero existing goldens move, and that is a trap dressed as good news.** Every
sentence golden in both suites uses a **synthetic** class — `nwcls`, `nwfcls`,
`nwmcls`, `b5cls`, `bs_pdev`, `bs_ndev` — which an identity-fallback accessor
prints unchanged. Measured: the whole change passes the pre-existing 177 + 130
checks while doing nothing at all. A fence had to name a **real** class, and
`mos` is the only real key whose display differs from it.

---

## 6. The rows that fence it, and the sabotages that prove them

`tests/headless/test_op_param_store_1245.tcl`, **section CL** (`OL_FLOOR`
130 → 135):

| row | what it fences |
|---|---|
| **CL1** | `mos` reads MOS; the other four classmap classes come back untouched through the identity return |
| **CL2** | acronyms up (NPN PNP ESD); every snake_case / part-number / unmapped key and the empty string byte-identical |
| **CL3** | after a real write at `class mos`, the store answers **nothing** under the display name — `get_list` empty, `owns` 0, `governs` silent |
| **CL4** | source-time purity (bare interp, second source does not reset an override) **and** no `toupper`/`totitle`/`string map` in the body |
| **CL5** | the rc extension door, and the two tables staying two (no `_mark_dirty`) |

`tests/headless/test_rdw_window_1245.tcl`, **section CL** (`RW_FLOOR`
177 → 181; CL10 is `live_tk`-gated and deliberately not counted):

| row | what it fences |
|---|---|
| **CL6** | the narrowed-dump name, class arm and flavor arm, with an unmapped key beside them |
| **CL7** | the user's own verdict word for word, the three other class-naming refusals, the success clause — **and** the store read proving the key did not move |
| **CL8** | the anti-drift fence: both button-pointing refusals carry `every device of class MOS` byte-for-byte, and neither reaches the store |
| **CL9** | the shadow clause — the one sentence that names a class without naming a list |
| **CL10** | the phrase read off the **live** `.rdw.scope.sc.broad` widget |

**Non-vacuity, by name.** `md5sum src/op_param_lists.tcl` and `src/rdw.tcl`
verified identical to the pre-sabotage copies after every restore.

* **Sabotage A** — `class_label` returns the key (the "did nothing" fix):
  store **CL1 CL2 CL3 CL4 CL5** red; window **CL6 CL7 CL8 CL9 CL10** red.
  *All ten rows.*
* **Sabotage B** — `class_label` returns `string toupper $cls` (the obvious
  wrong fix): store **CL1 CL2 CL4 CL5** red; window **CL6** red, and it also
  reds the pre-existing synthetic-class goldens **NW1 NW3 NW4 NW10 NW11 NW12
  NW13 LX10 BT6 BT28 BT30**.
* **Sabotage C**, one production proc at a time, to prove each routing site is
  individually fenced: `_narrowed_list` → **CL6**; `_edit`'s `set dcls` →
  **CL7 CL8**; `_shadow_why` → **CL9**; `scope_dialog_build` → **CL10**.
* **Sabotage D** — the *wrong-direction* fix, routing a key-shaped store
  message (`_dup_why`) through the accessor: pre-existing row **RD4** reds,
  which is what the "must not be routed" comment at the accessor points at.

**Suites after restore** (`./src/xschem` from the repo root, `--logdir` scratch;
`:99` runs via `devdisplay.sh exec`):

| suite | `--nogui` | `:99` |
|---|---|---|
| `test_rdw_window_1245` | ALL PASS (192) | ALL PASS (225) |
| `test_op_param_store_1245` | ALL PASS (135) | ALL PASS (135) |
| `test_rdw_keys_1245` | SKIP (needs Tk, by design) | ALL PASS (90) |
| `test_rdw_seam_1245` | ALL PASS (49) | ALL PASS (49) |

---

## 7. The user's decisions — NOT invented here (rule debt 1373)

Two vocabulary questions, both about the user's own domain:

**(a) How far does the table reach?** Shipped is the middle option: the five
classmap classes plus the three **acronym** keys the identity fallthrough
really mints (`npn`, `pnp`, `esd`). The alternatives are

  * *(i)* the classmap's five only — the RDW would then say "every device of
    class npn", which is the same complaint one device over;
  * *(ii)* **what shipped** — the stated rule "acronyms upper case" applied
    exactly, adding no invented prose;
  * *(iii)* (ii) plus prose spellings for the snake_case sky130 identity keys
    (`pwell_resistor` → "p-well resistor", `p_diffusion_resistor` →
    "p-diffusion resistor", `high_precision_p` → ?). That starts writing a
    device vocabulary the tree has never had, and `high_precision_p`'s own name
    is ragged.

**(b) Is `bipolar` the word?** The classmap's class name is `bipolar` and the
shipped tokens under it are `vertical_npn` / `vertical_pnp`. The user may want
**BJT** — an acronym, and their rule would then apply. Shipped as `bipolar`: it
is a word, not an acronym, and it is also the settings-file key, so keeping the
two identical is one less thing to confuse. But it is their vocabulary.

No `--eyes`: both are settled by reading a sentence, not by looking at pixels.

---

## 8. Residual, filed rather than fixed

The settings file has **no reader that reports an unmatched class key as
suspicious**. A user who types `list class MOS annotation` gets a stored,
syntactically valid, permanently inert row and is told nothing. Out of scope
here; worth its own issue.

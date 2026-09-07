# 1372 — Add from list 3 into the summary list never shows up on key 2

**Status:** FIXED in the working tree (not committed by this crew).
**Area:** `src/rdw.tcl` (the RDW button column), `src/ase.tcl` (the results seam),
`src/op_annot.tcl` (the kind table's inverse).
**Ruling owed:** yes — see §7. `tests/headless/owed.sh add rule 1372`.

---

## 1. The user's words, verbatim

> I put cursor on cgs and the clicked Add button and said add to all mos (why is
> that not uppercase? MOS is an acronym!) for summary list, but, later, when I
> send summary list with 2 key, it never shows up.

(The upper-case half of that sentence is item **1373**, not this one.)

---

## 2. The bench

Everything below was measured on the user's own bench, with their own `HOME`, so
the `ngspice-ver50` registry and `~/.xschem/op_param_lists.conf` are live:

* `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch`,
  descended `x1` → `x1`, device **M18**
  (`@m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt`).
* `xschem annotate_op` of the run's own raw
  (`~/.xschem/simulations/tb_bandgap_ase.raw`).
* Every launch: `tests/headless/devdisplay.sh exec ./src/xschem --pipe -q
  --logdir <scratch> --script <t>.tcl` from the repo root. No bare `xschem`, no
  run on the user's screen, `--logdir` always into scratch.
* No user file written: `/tmp/Xschem.log.8` untouched (mtime still
  2026-09-06 00:17), `~/.xschem/op_param_lists.conf` untouched (2026-09-04 17:27),
  `~/.xschem/op_annot/` still empty.

The run publishes **88** operating-point columns for M18; the sky130 declaration
(`sky130A/sky130_procs.tcl:452`, `op_annot::register`) names **six**:

    {id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}

`cgs` is not among them.

---

## 3. What was measured — the defect

**The Add never wrote anything, and nothing downstream dropped it.**

`rdw::_find_triple` was the ONLY source of the `{label param kind}` triple an Add
inserts, and it looked in exactly three places:

1. `op_param_lists::effective <cls> annotation <cell>`
2. `op_param_lists::effective <cls> summary <cell>`
3. `op_param_lists::seed <cls>`

On this bench **all three answer the same six triples**, because
`~/.xschem/op_param_lists.conf` owns no rows at all (it is the header comment plus
`version 2`, nothing else), so `effective` falls through `governs` to `seed` for
BOTH lists. `cgs` is not among the six, `_find_triple` returned `{}`, and
`rdw::_edit`'s add arm returned `refused`. Driven end to end:

    == cgs at block entry 60 : |    cgs      : -110.7f|
    == subject: instname M18 type nmos class mos cellname sky130_fd_pr/nfet_01v8_lvt
    ---- STORE BEFORE
         (nothing owned)
         effective mos summary = {id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}
    == scope_dialog called: op=add listname=all -> answering {scope broad list summary}
    == statusmsg: Add: cgs is published by this run, but no list and no PDK
       descriptor declares it - so this window cannot tell which raw-name shape
       it has, and it will not guess one. ...
    == _find_triple mos <cell> cgs -> ||          <-- THE LINK THAT DROPS IT
    ---- STORE AFTER
         (nothing owned)                          <-- BYTE-IDENTICAL
    ---- KEY 2 BLOCK ----
         id / gm / gds / vgs / vth / vds          <-- the user's report, reproduced

Every other candidate is ruled out **by measurement**, not by argument: there is
no wrong store key (there was no write at all), `effective` resolves the class
entry correctly for the summary list once one exists, the key-2 narrowing does
NOT intersect `cgs` out, nothing re-reads from disk, and `_apply_now` does not
fail — in the counterfactual where the triple exists, the very same press
succeeds and key 2 renders `cgs : -110.7f`.

### 3.1 Scale — the button could not succeed at all

Sweeping Add over every one of the 88 rows list 3 offers for M18, on both target
lists:

| target list | accepted | already in the list | no declaration |
|---|---|---|---|
| annotation, broad | **0** | 6 | 82 |
| summary, broad | **0** | 6 | 82 |

The user did not hit an edge case. They hit the only behaviour the button had.

### 3.2 Order — the dialog came first

`rdw::button` raised `rdw::scope_dialog` and only afterwards reached
`rdw::_edit`. So the user answered a two-part modal question — which devices,
which list — and was THEN told, once, into a four-line status pane, that the
whole thing was impossible. That is why the report reads *"it never shows up"*
rather than *"it refused"*.

### 3.3 The refusal's stated reason is not true of this code

The ALL-CAPS invariant above `rdw::_find_triple` said:

> ⚠ ADD MINTS NO `kind`, EVER … so a guessed one writes a `.save` card that
> matches nothing, and one bogus card destroys the whole operating point.

**Measured, and false.** `op_annot::_cards_for` (`src/op_annot.tcl`) emits
`.save ${dev}[${param}]` and never reads the kind at all — a kind-0 row and a
kind-1 row produce byte-identical cards, so no kind can make a card bogus. The
kind is read only at READ time, by `op_annot::_wrap` / `_wrap_alts`, and
`_wrap_alts` already falls back to the bare spelling.

### 3.4 The kind is MEASURABLE from the run, not guessable

    raw spelling for cgs on M18: @m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt[cgs]
    raw spelling for id  on M18: @m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt[id]

Every merged column is **bare**, i.e. kind 1 by `op_annot::_wrap`'s own table —
even `id` (declared kind 0) and `vgs` (declared kind 2), which come back bare and
render only because `_wrap_alts` falls back. Source:
`op_annot::opdump_read` injects `@${dev}[${k}]` through `xschem raw add`, because
this registry's `ase::op_save_tier` answers **tier d, reason dump, ncards 0** —
the 88 columns come from the sidecar `show all` dump, not from per-device cards.

---

## 4. What changed

All five edits are pure Tcl. No new file, so the issue-0424 `Makefile.in` trap
does not apply.

1. **`op_annot::_kind_of_vector {v}`** — new, immediately beside
   `op_annot::_wrap` (`src/op_annot.tcl`). The one inverse of `_wrap`'s
   token.c:4524-4525 table: prefix `i(` → 0, nothing → 1, `v(` → 2; `{}` for a
   name that is not a device-parameter vector or that carries a wrapper the
   table does not name. It lives beside `_wrap` and not in the caller because a
   second file deciding that `i(` means 0 would be a second copy of that table
   (invariant I1), and `ase::op_param_split`'s own comment already refuses to
   re-encode it for exactly this reason.

2. **`ase::op_vector_for {devpath param}`** — new, beside `op_param_split` and
   `op_dev_covers` (`src/ase.tcl`), the two verbs it is made of. Answers the
   whole vector NAME this run published for that device's column, or `{}`. It
   answers the NAME and not the kind, which is the same invariant-I1 line
   `op_param_split` draws. It exists because the backend's `op_param_set` throws
   the spelling away one line after reading it, and the spelling is the only
   measured evidence of the shape.

3. **`rdw::_find_triple {cls cell param {devpath {}}}`** — the three declared
   lookups are byte-for-byte where they were and still win. Only when all three
   are silent, and only when a `devpath` was supplied, does `rdw::_run_triple`
   get its turn.

4. **`rdw::_run_triple {devpath param}`** and
   **`rdw::_subject_devpath {subject}`** — new named callees. `_run_triple`
   returns `{param param <kind read off the run's spelling>}` or `{}`.
   `_subject_devpath` returns `{}` unless the block's stamped `schname` equals
   `[xschem get schname]` — issue 1322's own axis, because blocks deliberately
   outlive the raw and the sheet they came from — otherwise
   `op_annot::devpath <instname>`, caught. So a STALE block mints nothing and
   gets a refusal that names the way back; a LIVE one mints from the run the row
   was actually read out of.

5. **`rdw::_add_why {subject param}`** and the pre-dialog call in
   `rdw::button` — the rule (`_find_triple` answers `{}`) is asked in one place
   and worded in one place, and `rdw::button` asks it BEFORE
   `rdw::scope_dialog`. `rdw::_edit` keeps its own check unchanged: one rule,
   two doors, the shape `op_param_lists::reduce_why` and `governs` already set.
   Only the LIST-INDEPENDENT half is pre-checked — "already in the list" is what
   the dialog is being raised to determine, so that one still costs a dialog.

6. **`rdw::_mint_note {op cls cell param}`** — one clause, on the mint arm of a
   successful Add only, appended at the same single place `_sheet_note` and
   `_drawn_note` are. It is COMPUTED in the add arm, before the store call,
   because `set_list` puts the minted triple into the very list `effective`
   reads — the same question asked one line later answers "declared" for every
   accepted Add and the clause would be vacuous and green.

7. **Comment repairs.** The ALL-CAPS invariant above `rdw::_find_triple` and the
   old header of row BT18 are REWRITTEN, not deleted — a deleted invariant is
   how the next reader re-derives it — and both now name the hazard the old
   wording misnamed (§7). `doc/claude/specs/op_param_lists.md` §4.2 B7 gains an
   AS-BUILT block; `test_op_param_store_1245.tcl`'s two comments naming
   `_find_triple`'s "LAST fallback is `seed $cls`" are corrected.

### 4.1 The result, on the user's own gesture

    == statusmsg: Add: added cgs to the summary list for class mos. No list and
       no PDK descriptor declares it, so the raw-name shape was read from what
       this run published.
    ---- STORE AFTER
         class mos summary = ... {vds vds 2} {cgs cgs 1}
    ---- KEY 2 BLOCK ----
         id / gm / gds / vgs / vth / vds / cgs : -110.7f

and the sweep over all 88 rows now reads **ok=82, already=6, no-declaration=0**.
`op_annot::text M18` is byte-identical — the SHEET does not move, correctly:
`_show_set` filters the sheet by the ANNOTATION list.

---

## 5. Which rows fence it

All five run on **both** arms of
`tests/headless/test_rdw_window_1245.tcl` (`RW_FLOOR` **173 → 177**; BT18 is
rewritten rather than added, so it does not change the count). The section builds
its own one-device raw carrying all three spellings —
`@m.m1[vgs]`, `i(@m.m1[cgs])`, `v(@m.m1[cbb])` — attached inside these rows and
cleared on the way out, so no row outside the block sees a database it did not
ask for.

| row | what it fences |
|---|---|
| **BT18** (rewritten, verdict reversed) | an Add of a run-published, undeclared column is ACCEPTED and the stored kind is the one the RUN's spelling carries — bare → 1, `i(` → 0, `v(` → 2 — with label and param both the column's own name |
| **BT33** | a parameter no list, no declaration and no column of this run names is STILL refused; the mint answers nothing and the sentence says it will not guess |
| **BT34** | the sheet stamp gates the MEASUREMENT — a stale block mints nothing and is refused with a sentence naming the way back, while the SAME parameter on a live-stamped block is accepted |
| **BT35** | an Add that cannot be written raises NO scope dialog and still names the button, while one that can raises exactly one |
| **BT36** | the mint clause is said once, on the mint arm only, and is absent from a declared Add — and it survives the write because it is asked before it |

### 5.1 Sabotage — the red set, by name

Seven sabotages, each restored by `cp` with the md5 re-verified afterwards
(`src/rdw.tcl` `a18b7e5f28c1b1d6797889b82b36f1b2`, `src/ase.tcl`
`9f204436bb951ee50e807bba11ca8587`, `src/op_annot.tcl`
`9ae527926ea6a92917517da11a034205`):

| sabotage | RED rows |
|---|---|
| `rdw::_run_triple` → `{}` | BT18 BT34 BT35 BT36 |
| `op_annot::_kind_of_vector` → `{}` | BT18 BT34 BT35 BT36 |
| `ase::op_vector_for` → `{}` | BT18 BT34 BT35 BT36 |
| `rdw::_subject_devpath`'s `schname` compare dropped | **BT34** |
| the pre-dialog `_add_why` call removed from `rdw::button` | **BT35** |
| `rdw::_mint_note` → `{}` | **BT36** |
| `_run_triple` mints without asking the run (the over-reach direction) | BT18 **BT33** BT35 |

---

## 6. Suites run, by name

| suite | arm | result |
|---|---|---|
| `tests/headless/test_rdw_window_1245.tcl` | `--nogui` | **ALL PASS (188)** — was 184 |
| `tests/headless/test_rdw_window_1245.tcl` | `:99` | **ALL PASS (220)** |
| `tests/headless/test_op_param_store_1245.tcl` | both | **ALL PASS (130)** |
| `tests/headless/test_rdw_seam_1245.tcl` | both | **ALL PASS (49)** |
| `tests/headless/test_rdw_keys_1245.tcl` | `:99` | **ALL PASS (90)** (SKIP headless, as designed) |
| `tests/headless/test_op_dump_altshow.tcl` | `:99` | 1 FAILED — **not this item**, see §8 |
| `tests/headless/test_ase_optier_0963.tcl` | `:99` | 1 FAILED — **not this item**, see §8 |

---

## 7. The ruling this item owes the user

**(a) May an Add accept a column the run published that no list and no PDK
descriptor declares?**

The answer shipped here is *yes*, because the invariant that said *no* gave a
reason measurement refutes (§3.3) and because on the user's own bench the button
succeeded for 0 of 88 rows. But the invariant was protecting something real that
it **misnamed**, and that part is still live:

> An accepted row joins `op_param_lists::_save_set`'s annotation+summary union,
> `apply` writes that union into the descriptor's `params`, and
> `op_annot::_cards_for` turns `params` into the NEXT deck's `.save` cards.
> **MEASURED: an accepted summary Add of `cgs` grew `_cards_for M18` from six
> cards to seven.** On this registry `ase::op_save_tier` answers tier d and no
> card is emitted today — but spec `op_param_lists.md` §3.2 / rule R5 record that
> `show`'s catalogue is a **superset** of the savable set (`ib` is the named
> example), that good cards plus ONE bogus card give a silent zero column, and
> that an all-bogus set makes ngspice write no raw at all.

So this is a trade between a button that works and a risk to a future run on a
different registry. The options, in the order this crew would present them:

* **(i) ACCEPT, kind read off the run's own spelling, nothing guessed.** What
  shipped. Fixes the report as filed; carries the deck risk on other registries.
* **(ii) ACCEPT INTO THE SUMMARY LIST ONLY.** It draws nothing on the sheet
  today — but it still feeds `_save_set`, so it does **not** avoid the risk, and
  it puts two rules at one door, which is the disagreement issue 1288 exists to
  remove. Not recommended.
* **(iii) ACCEPT ONLY WHILE THE RUN'S SAVE TIER EMITS NO PER-DEVICE CARDS**
  (`ase::op_save_tier` → tier d today), refusing otherwise with a sentence naming
  the tier. Closes the risk exactly, at the cost of a button whose availability
  depends on the registered simulator.
* **(iv) KEEP REFUSING.** Then the request is declined and the deliverable is the
  honest sentence plus §4 item 5 (no dialog in front of a refusal), and list 3's
  82 unaddable rows should be marked.

**(b) Should the Add button stop raising the scope dialog for a press it cannot
write?** Shipped as *yes* under every arm of (a) — being asked two questions and
then told the whole thing was impossible is a defect on its own — but it changes
the shipped gesture, so it is the user's call.

Neither needs pixels, so no `--eyes`.

---

## 8. Adjacent, measured, and deliberately not swept in

* **`tests/headless/test_ase_optier_0963.tcl` row S11 is RED and it is issue
  1370's, not this one.** S11 counts the `ase::sim_why` mint kinds a run reports
  and expects two; it now sees three, because the 1370 crew added a `run_using`
  kind at `src/ase.tcl:779` in this same working tree. Nothing in this item mints
  a `sim_why` kind. The suite also takes over 500 s on `:99`.
* **`tests/headless/test_op_dump_altshow.tcl` row H1 is RED for a stray file, not
  for a code change.** H1 asserts no `untitled*` in the repo root; the tree
  carries `untitled~.sym` dated **2026-09-04 21:22**, two days before this
  session. Untracked leftover from an earlier crew.
* **The residual this fix can be wrong in, stated:** if a raw carries a column
  ONLY as `i(@dev[p])` while some other spelling was written first,
  `ase::op_vector_for` answers first-in-raw-order and the minted kind reads that
  other column. `_wrap_alts` for kind 1 tries the bare spelling alone, so the
  cost is a **blank row** — an error in the empty direction, never a wrong
  number — and only on the annotation list, since `_show_set` filters the sheet
  by that list.
* **The symlink cost, stated:** `_subject_devpath`'s comparison is a plain string
  compare, for `rdw::_sheet_note`'s own three recorded reasons (issues 1327,
  1329, row BT22). A sheet opened through a symlink therefore mints nothing and
  the Add is refused — empty in the empty direction.

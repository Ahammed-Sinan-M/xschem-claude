# ASE-L UX batch — 2026-09-09

Asked for: *"a detailed analysis of brokenness in UX of the ASE-L. I think fonts, etc
could stand to improve. How can we make it slick?"*

Nothing here has been implemented. `src/` is untouched. This is analysis and a proposal.

| file | what it is |
|---|---|
| `MEASUREMENTS.md` | 15 measurements taken on the built binary on the dev display, against the user's own `sky130_tests_ase/tb_bandgap` bench. Two carry ⚠ CORRECTION blocks where a first claim was refuted and re-measured. |
| `FINDINGS.md` | all 126 findings from a twelve-lens audit, untriaged, severity-ordered within each lens. 24 are marked critical. |
| `PLAN.md` | the deliverable: eight LOOK stages and five FUNCTION stages, sequenced into eight commits, with line counts, the suites each moves, and seventeen rulings batched into one ask. Opens with nine corrections to claims that did not survive checking — including two of the lead's own. |
| `preview_theme.tcl` | edits no file. Redefines `ase::theme` and `ase::ui::apply_theme` in memory so Stage 1 can be seen before it is built. |
| `shots/` | 46 PNGs of the live window: the main window at three sizes, every dialog, the shipped dark colour scheme, `tk_scaling 2.0`, ASE-L beside the RDW and the Calculator, and the Stage 1 before/after composite. |

Run the preview:

```sh
tests/headless/devdisplay.sh start
DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog \
    --script sky130A/cadence_style_rc \
    --command "source doc/claude/ase_l_ux_batch/preview_theme.tcl"
```

## The one-paragraph version

The window renders in a typeface nobody chose (`Arial` and `Courier` are named in
`ase::theme` and neither is installed), at a size nothing else in the application uses,
with 52 of its 53 fonted widgets set in **bold** — so nothing can be emphasised because
everything already is. Its column widths are pixel constants while its font sizes are in
points, so it clips on any display that is not this one. It sets `-background` without
`-foreground`, so xschem's own shipped dark colour scheme renders the temperature field
at a contrast ratio of 1.000:1. And three of its surfaces report things that are not
true: the analysis Options form displays settings the deck never emits, every state of
every cell shares one run directory, and Save State overwrites an existing state with no
confirmation. Stage 1 of `PLAN.md` — 97 lines, no ruling, no test moved — fixes the first
three of those.

## Not filed yet, deliberately

`PLAN.md` ends with seventeen rulings. They are **not** in `owed.sh` and no issue has
been minted, because nothing has shipped and a ledger entry is a record of an unratified
decision that is already in the tree. When the work starts, they go in as one issue
(next free number is **1396**, per `doc/claude/issues/NUMBERING.md`) and one
`owed.sh add rule 1396`, per the ledger's own batching rule.

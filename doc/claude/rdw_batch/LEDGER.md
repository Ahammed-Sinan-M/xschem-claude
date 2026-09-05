# RDW batch — ledger

Baseline taken 2026-09-05 at `a5e15dda`, every suite asserted to have printed a
RESULT line:

| suite | baseline | how |
|---|---|---|
| `test_rdw_window_1245` | ALL PASS (109) | `--nogui` |
| `test_rdw_keys_1245` | ALL PASS (41) | `:99` |
| `test_op_param_store_1245` | ALL PASS (130) | `--nogui` |
| `test_annot_declutter_1244` | ALL PASS (134) | `:99` |
| `test_op_annot` *(control)* | ALL PASS (485) | `--nogui` |
| `test_ase_core` | **1 red** (C11) | the `untitled~` phantom, issue 0609 |
| `test_op_dump_altshow` | **1 red** (H1) | the same phantom |

**Acceptance is a name+status diff, never a count.** The two reds above are one
pre-existing environmental cause and are not to be made green by deleting the
user's files.

## Items

| item | issue | subject | state |
|---|---|---|---|
| R1 | 1337 | the line cursor | not started |
| R2 | 1338 | Up/Down move the row and the sheet follows | not started |
| R4 | 1340 | raise the window when something is sent to it | not started |
| R5 | 1341 | engineering notation | not started |
| R3 | 1339 | select and copy | not started |

Order is deliberate: R2 needs R1's cursor for its subject; R3 is last because it
is the only one that cannot be finished without a run on the user's real X
server (DD-8).

## Rows

<!-- crews append here, one row per item -->

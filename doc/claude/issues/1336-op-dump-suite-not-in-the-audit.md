# 1336 — `test_op_dump_altshow` was not in `full_audit.sh`, so the audit could not see it

**Status:** FIXED (this branch)
**Files:** `tests/headless/full_audit.sh`

`full_audit.sh:161` carries an **explicit** `nogui_tests=` list; there is no
discovery. A suite absent from it never runs in the audit, and the audit reports
the same totals whether the feature works or not.

This is the CREW_BRIEF's "a blank result is not a pass" trap one level up: not a
suite that printed nothing, but a suite the audit never asked.

Added to the list. The audit's `of N` total moves by one; the new name is
expected **red on H1** until the `untitled~.sch` phantom (issue 0609, the same
cause as `test_ase_core`'s C11) is settled — a pre-existing, gitignored file in
the repo root, deliberately left in place, that two suites now trip over.

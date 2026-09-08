# Look-debt digest — crew brief

## The user's words

> "What is something you can work on for the next one hour in batch mode?"

and, chosen from a four-way menu: **the look-debt digest**.

## The problem

`tests/headless/owed.sh count` reads **46 look debts**, the oldest 6 days old.
A look debt is paid only by the user's eyes and cleared only by the user's word
(`owed.sh clear look <id>`). Today they are 46 scattered ledger lines, each
several hundred words of context, in no order, with no pixels attached. Paying
them means the user re-deriving 46 separate setups. That is why none has been
paid.

## The deliverable

ONE page. Per debt: the question in one sentence, what "fine" and "wrong" look
like, and either
  * **pixels attached** — a PNG this batch captured, or the exact text the
    widget draws, or
  * **a numbered recipe** of at most six steps for the debts that genuinely
    need the user's own hands and their own X server.

## What this batch must NOT do

* **Never `owed.sh clear look`.** Nothing here pays a debt. The page makes the
  debts payable; the user pays them.
* **Add no new rule or look debt** unless the work genuinely creates one; the
  point of this batch is to shrink the user's queue, not grow it.
* **No product code changes.** This is a reporting batch. If a debt turns out
  to describe a live defect, FILE it (NUMBERING.md is the only authority) and
  say so — do not fix it here.

## Standing rules (from CLAUDE.md and this session)

1. **Always give the binary a path.** `./src/xschem`, never a bare `xschem`
   (a bare one is 3.4.6 from Jan 2025 and rewrites the user's recent_files).
2. **Every launch carries `--nolog`.** The user's live action log is
   `/tmp/Xschem.log.*`; `--logdir` would tread on it. (Exception, not relevant
   here: `test_ase_log_seam_0207`.)
3. **Never touch anything under `~/.xschem/`.**
4. **Never** `git checkout --` / `restore` / `stash` / `clean` against
   uncommitted work. Never push, never open a PR.
5. GUI work goes to a virtual display — the shared dev display `:99`
   (`tests/headless/devdisplay.sh`) or your own private Xvfb. Never a bare
   run on the inherited `$DISPLAY`: that is the user's real screen.
6. Acceptance is a name+status diff, never a count.

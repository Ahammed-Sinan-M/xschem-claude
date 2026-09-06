# 1367 — the chrome claimed to be *Showing* an empty pane, and looked for the keys where they no longer were

**Status: FIXED.** Two faces of one commit pair, both measured by the driver on
the dev display after the repair round landed. Subject: `rdw::_chrome_text`,
`rdw::_chrome_line` and `rdw::_keys_bound` in `src/rdw.tcl`.

## A — `Showing` is a claim about the pane, and the pane can be empty

Issue **1355** replaced the chrome's `Keys 1/2/3:` head — false in a profile
that does not source `src/cadence_style_rc` — with `Showing`. That fixed a
false statement about the KEYS by minting a false statement about the PANE.

MEASURED, stock profile, through the Tools entry `src/xschem.tcl:17638` adds
unconditionally:

```
keys_bound  : 0
chrome      : Showing the annotation list (drawn on the sheet) -
              the buttons edit this list, not the block you are reading.
pane chars  : 1          <- the Tk text widget's mandatory trailing newline
blocks      : 0
```

Two false statements in one sentence: nothing was being shown, and there was no
block to be reading. The wording it replaced was false for its own reason, so a
third wording that is false in a fourth way would not have been progress — the
emptiness is now **asked about** rather than assumed.

`rdw::_chrome_text` takes a third argument, `filled`, and the three heads say
only what is true of the state they are in:

| state | head |
|---|---|
| filled | `Showing <list>` — a claim the pane now backs |
| empty, keyed | `No device has been sent here yet - <list>. Select a device and press <n>.` |
| empty, unkeyed | `No device has been sent here yet - <list>.` |

The digit in that sentence comes from `rdw::_digit_for`, which reads
`rdw::_digit_map` — the one answer row **KB1** already locks against
`src/cadence_style_rc` — and never from a second literal.

## B — `_keys_bound` asked the canvas after the keys had moved to the window

`rdw::_keys_bound` tested `.drw`'s bindings alone. That was right until issue
**1358** bound the same four digits on `.rdw` itself so the window could hear
its own refresh keys. After that a stock profile answered **0** while the
digits really worked, with the keyboard inside the window.

It now asks **both** widgets, and knows **both spellings of the one door**: the
canvas binds call `rdw::key` directly, the window's binds go through
`rdw::_digit`, whose only act is to call `rdw::key`.

Measured after the fix, same stock probe:

```
keys_bound  : 1
chrome      : No device has been sent here yet - the annotation list
              (drawn on the sheet). Select a device and press 1.
```

## The rows

* **LX17** — the chrome does not claim to be showing an empty pane; all four
  `keyed` × `filled` combinations asserted on the arm with no display at all,
  plus the structural terms that `_chrome_line` consults the store and
  `_digit_for` reads the map.
* **LX18** — `_keys_bound` names both widgets and both spellings, and
  `rdw::_digit` really does call `rdw::key`, so the two names name one thing.
* **LK3** rewritten: stripping the canvas binds alone must leave the answer
  **1**, because the keys genuinely still work in the window; only stripping
  both may make it 0. The old row demanded 0 there, i.e. demanded the sentence
  lie in the other direction.
* **LX7** and **LX12/LX13** re-pointed: LX7 compares the live label against the
  live builder, LX12/LX13 assert clauses of the *filled* sentence and so ask
  the pure builder for it.
* `RW_FLOOR` 166 → 168 in the same commit.

**Non-vacuous, each caught by exactly the row that claims it**, applied to the
repo file and restored by `cp` with the md5 verified
(`88959a76ce761924317b5d6abffb235e`), `git status --short` clean after:

| sabotage | result |
|---|---|
| the chrome ignores emptiness again | `1 FAILED (178 passed)` — **LX17** |
| `_keys_bound` asks the canvas only again | `1 FAILED (178 passed)` — **LX18** |

## Verification

`test_rdw_window_1245` ALL PASS (179 `--nogui`, 204 on `:99`);
`test_rdw_keys_1245` ALL PASS (88) on `:99`, two consecutive runs;
`test_op_param_store_1245` ALL PASS (130); `test_op_annot` ALL PASS (485).

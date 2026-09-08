# Poses — pre-built states for photographing the Results Display Window

Each `rdw_*.tcl` here leaves one window up in one state and blocks. They are run
by `tests/headless/lookshot.sh`, which takes the picture and then kills xschem:

```sh
tests/headless/lookshot.sh out.png doc/claude/lookdebt_batch/poses/rdw_status.tcl \
    -name Results
```

`lk_prelude.tcl` is the shared half: three helpers that build a realistic answer
dict and push it through the real `rdw::format_answer` + `rdw::push`, so what is
photographed is the shipped renderer and not a mock-up.

**A pose is not the real door.** These push blocks directly; a person reaches
`rdw::push` through `rdw::dump_devpath` after a real annotate. Everything the
renderer draws is therefore faithful, but anything set by the surrounding
gesture is not — which is how **issue 1379** was found: the chrome line above
the pane is written only by `rdw::build` and `rdw::set_list`, so it still reads
"No device has been sent here yet" over a pane holding two blocks. That one
reproduces through the real door too (`dump_devpath` ends at `push` and calls
nothing else). Check before reporting a pose artifact as a defect, and check
again before dismissing one as a pose artifact.

**No annotation poses here, deliberately.** Photographing an annotated FET needs
an OP raw carrying MOS device vectors (`@m.x1.m1[gm]` and friends), and the tree
ships none — `doc/claude/casemode_batch/fixtures/op_*.raw` are divider circuits
with node voltages only. The annotation look debts stay on the user's own bench.

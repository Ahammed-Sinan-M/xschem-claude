# Look debts closed 2026-09-09 — annotation, and registering a simulator

Closed on the user's instruction: "Close out all look debt related to annotation
and registering of the simulator, if any." A look debt clears ONLY when the user
says so; this file is the receipt, so the text of each closed item survives the
`rm` that `owed.sh clear look` performs.

## Annotation (8)

### 1244_A3_declutter_per_pdk

`id: 1244_A3_declutter_per_pdk.1788363404.1608131`  ·  recorded 2026-09-02

annotation + declutter on, per PDK: an annotated FET should draw its name and its OP block and nothing else. Suites green (82 checks incl. rows A27/A28 on the real sky130A / gf180mcuD / ihp-sg13g2 symbols); please look at the pixels.

### 1244 declutter survives Ctrl-6? (on screen)

`id: 1244_declutter_survives_Ctrl-6___on_screen_.1788343959.937635`  ·  recorded 2026-09-02

RULING D-8 makes the declutter a bit on annot_show, so Ctrl-6 clears it with everything else. Measured, not decided: after 6 -> Ctrl-Alt-6 -> Ctrl-6 -> 6 the parameters are back and Ctrl-Alt-6 must be pressed again. That follows from D-8 and is left to be judged on screen rather than argued about. (Judgeable only once item A3 makes something actually disappear.)

### DD-6 narrowing on the schematic

`id: DD-6_narrowing_on_the_schematic.1788485268.1494261`  ·  recorded 2026-09-03

The DD-6 display key (shown) landed: op_annot::text now draws 'shown' when a descriptor carries it and 'params' otherwise, and op_param_lists::apply writes BOTH (the union into params, the annotation list into shown). NOTHING CALLS apply YET, so this is invisible until item B5 wires the button -- but the moment it does, the on-sheet block SHRINKS and the declutter gate's answer changes with it. Suites green (test_op_annot 485/492 and test_annot_declutter_1244 134 all UNMOVED); please look at a decluttered sheet once B5 lands. Paired with ledger entry 1245_DD6_display_field.

### op_1364_annotate_on_your_own_bench

`id: op_1364_annotate_on_your_own_bench.1788663267.1206154`  ·  recorded 2026-09-05

Please confirm the fix on YOUR bench, with YOUR ngspice-ver50, through the gesture you actually use -- I could not: every measurement here is Xvfb and a scratch HOME. Open sky130_tests_ase/tb_bandgap, descend x1 -> x1, run, then annotate M18 the way you normally do (6, or Simulation > Graphs > Annotate Operating Point into schematic, or a launcher button on the sheet). BEFORE this fix that path rendered 'id' and left gm/gds/vgs/vth/vds BLANK on your registry; it should now render all six. The numbers I measured on the smaller committed cell test_nfet_final were id 409.7u / gm 503.3u / gds 69.57u / vgs 1.737 / vth 0.7813 / vds 0.8734. A green suite cannot tell you your own design annotates.

### op_param_lists.conf emitted header with TWO precedence axes (PDK SCOPE + flavor file order)

`id: op_param_lists.conf_emitted_header_with_TWO_precedence_axes__PDK.1788863830.2709051`  ·  recorded 2026-09-08

issue 1388, UPDATED IN PLACE 2026-09-08 by the repair pass -- one debt for one header, not a second filing. THE HEADER NOW CARRIES A LABELLED `PDK SCOPE:` PARAGRAPH OF NINE LINES above the untouched `PRECEDENCE among flavor rows:` one; the repair pass added the LAST THREE of those nine: 'The TIER still wins first: your personal file is read before this project's, so a row here replaces one there for the same list whatever section either is in. A section never changes the flavor file-order rule below.' They were added because that interaction is the one that SURPRISES (a project-tier UN-SCOPED row beats a personal-tier `[pdk sky130A]` one -- the LESS specific row wins, because read order settles the tier before the PDK rank orders rows within one file) and the file said nothing about it. The flavor paragraph and its worked `e.g.` lines are untouched, deliberately: suite row F5 reads that example back out of a freshly written file. ONLY YOUR EYES CAN SAY whether the block is still readable rather than a wall of text -- it is now ~20 comment lines before `version 2`. WHAT TO DO: in a project with no .xschem/op_param_lists.conf, change any list in the RDW and Save, then open the file that appears and READ THE TOP OF IT. A FRESH FILE ONLY -- ruling DD-11 means your existing file never gains the paragraph, which is itself worth judging: your own file at <repo>/.xschem/op_param_lists.conf still has the OLD header and no PDK paragraph at all, so it does not explain a feature it can use.

### op_param_lists.conf grammar v2 + the file-order precedence header

`id: op_param_lists.conf_grammar_v2___the_file-order_precedence_heade.1788502281.1918911`  ·  recorded 2026-09-03

Item B2c rewrote the whole header block every settings file carries, and the precedence rule it states is now TRUE of the code that emits it (row F5 reads the sentence back out of a freshly written file and builds the case it describes). THE FILE TO READ: <project>/.xschem/op_param_lists.conf -- write any flavor row, save, open it. THE SENTENCE TO JUDGE: 'PRECEDENCE among `flavor` rows: when two globs of the SAME class both match a cell name, THE FIRST ONE IN THIS FILE WINS. Nothing is ranked and nothing is measured for narrowness: put the row you want to win ABOVE the other one.' plus its worked e.g. line, the 'a flavor row answers ONLY for the class named in its own row' line, the cross-tier line ('your personal file is read BEFORE this project's'), and the new closing line 'xschem edits only the rows it changed and leaves everything else in this file exactly as you wrote it'. SUPERSEDES look debt [op_param_lists.conf_precedence_comment], which describes B2a-2's REFUTED narrowness ranking -- that sentence is gone from the tree. Suites green (test_op_param_store 79 checks, test_op_annot 485/492, test_annot_declutter_1244 134 unmoved); please look.

### op_param_lists.conf precedence comment

`id: op_param_lists.conf_precedence_comment.1788485268.1494249`  ·  recorded 2026-09-03

B2a-2 rewrote the seven comment lines every settings file carries about flavor-glob precedence. Suites green; please READ THE EMITTED FILE and say whether the sentence is clear to a teammate who receives it: write any flavor row, save, and open <project>/.xschem/op_param_lists.conf. Paired with rule debt 1277_precedence_sentence.

### the merged Waves > Op Annotate entry, on the real screen

`id: the_merged_Waves___Op_Annotate_entry__on_the_real_screen.1788311440.495383`  ·  recorded 2026-09-01

it now carries two guards in one expression; the cadence refusal and the no-binding refusal are different sentences and both were only ever driven headless

## Registering a simulator (5)

### ASE-L Setup > Simulators: the simulator choice is now the bench's, not the machine's (issue 1395)

`id: ASE-L_Setup___Simulators__the_simulator_choice_is_now_the_bench_.1788934733.3590646`  ·  recorded 2026-09-08

SUITES GREEN (test_ase_simdlg_0937 55/55 on Xvfb :99 with openbox 3.6.1), PLEASE LOOK -- a green suite does not discharge this. WHAT TO DO: open an ASE-L window on a test bench, note the title, open Setup > Simulators..., and pick a different entry in 'Use this one:'. WHAT TO CHECK: (a) the title immediately gains its ' *' dirty marker and the bottom bar's 'Simulator:' segment changes at the same instant -- no run needed; (b) 'ls -l --time-style=full-iso ~/.xschem/ase_simulators' shows the SAME mtime as before the pick, i.e. your saved simulator list was not touched (that used to be written on every pick); (c) Session > Save State clears the marker, and re-opening the bench comes back on the simulator you chose; (d) close xschem with a pick unsaved -- the save prompt must stop the quit and name that bench; (e) with two ASE-L windows open on two benches, each combobox shows its OWN bench's choice, while the bottom bar of both still names whichever one is in force process-wide (that last divergence is the open rule debt 1395); (f) the wording on the dialog's status line after each gesture still reads like the rest of xschem -- none of it is new copy, it is all ase::sim_why's.

### 1371 the Case chooser and the widened row editor

`id: 1371_the_Case_chooser_and_the_widened_row_editor.1788726246.1637226`  ·  recorded 2026-09-06

Issue 1371's door, repaired after an adversary refuted it. Suites green (test_ase_simdlg_0937 47 on :99 / 5 --nogui, simcaps 84, simreg 83, window 228, dialogs 176, persist 136, probe 44, casemode_registry 28, run_profile 37, launch 44, preflight 114) and eight sabotages red by name -- but no check can measure a pixel. Setup > Simulators... -> click a row -> Edit...: (1) does the read-only Case: combobox look read-only in your theme; (2) the editor grew from three grid rows to six -- is the Detect button clipped, and does the dialog still size sensibly; (3) do the marked labels fit -- 'preserve (not tried yet)' and 'preserve (NOT supported)', which are the two states a mode outside the offer can be in; (4) the status line under the fields now carries a sentence the moment the editor opens (press-Detect on a cold program, the measured list on a warm one) -- is that line legible and not clipped at 420px wraplength. These three questions were filed inside the SUITE debt for test_ase_simdlg_0937, which drain clears on a green run; they are here now because a green suite answers none of them.

### the ASE-L bottom bar's Simulator segment on the user's own screen

`id: the_ASE-L_bottom_bar_s_Simulator_segment_on_the_user_s_own_scree.1788710654.1500028`  ·  recorded 2026-09-06

issue 1370: the segment is now 'Simulator: ngspice-ver50' on their bench and 'Simulator: <name> - will not run' in the four bad arms. Two things only eyes can settle: whether the em dash renders on their X server's font, and whether the 28-character segment pushes 'State:' off or widens the toplevel. Same class as the RDW chrome-width look debt.

### stock xschem Simulate lost its exe/casemode composer (issue 0506)

`id: stock_xschem_Simulate_lost_its_exe_casemode_composer__issue_0506.1788306342.180023`  ·  recorded 2026-09-01

the profile store it read is gone; ASE-L keeps everything. Re-teach simulate to read the registry, or accept the loss

### run_cmd word order: -b before the user's args, not after

`id: run_cmd_word_order__-b_before_the_user_s_args__not_after.1788306342.180035`  ·  recorded 2026-09-01

annotate's goldens move one token; fluid's order mirrors the probe

## Deliberately NOT closed — annotation only by way of the Results Display Window

Two entries mention the annotation feature but their subject is a Results Display
Window surface, and the whole RDW family (rdw_*, 1245, 1300, 1337-1382) was not in
the instruction's scope. Left standing:

- `DD-5 analysis sentence in the Results Display Window` — the wording that says the
  numbers come from a dc first point rather than a standalone operating point.
- `the RDW dump header spelling (spec op_param_lists.md Q6)` — the M2B:/xdut/xbg/xamp1
  spelling question; the spec is the annotation spec, the pixels are the RDW's.

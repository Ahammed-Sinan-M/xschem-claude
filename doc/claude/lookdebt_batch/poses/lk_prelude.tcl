proc lk_ctx {hdr dp {sty op} {inst M1} {sim ngspice}} {
  return [dict create header $hdr devpath $dp simtype $sty instname $inst sim $sim]
}
proc lk_ansd {devices absent nonfinite complete state} {
  return [dict create devices $devices absent $absent nonfinite $nonfinite \
                      complete $complete state $state]
}
proc lk_push {hdr dp inst devs {absent {}} {nonfin {}} {complete 1} {state ok}} {
  rdw::push [rdw::format_answer [lk_ansd $devs $absent $nonfin $complete $state] \
                                [lk_ctx $hdr $dp op $inst]]
}
proc lk_two {} {
  lk_push {x1.M2:/tb_bandgap/x1} {@m.x1.m2} M2 \
    [dict create {@m.x1.m2} {{id 1.234e-05} {gm 2.15e-04} {gds 1.07e-06} {vth 4.51e-01}}]
  lk_push {x1.M1:/tb_bandgap/x1} {@m.x1.m1} M1 \
    [dict create {@m.x1.m1} {{id 9.87e-06} {gm 1.98e-04} {gds 8.80e-07} {vth 4.48e-01}}]
}

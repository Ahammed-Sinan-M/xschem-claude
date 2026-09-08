source [file join [file dirname [info script]] lk_prelude.tcl]
rdw::open
update idletasks
lk_push {x1.M9:/tb_bandgap/x1} {@m.x1.m9} M9 {} {} {} 0 no_raw
lk_push {x1.M8:/tb_bandgap/x1} {@m.x1.m8} M8 \
  [dict create {@m.x1.m8} {{id 1e-05}}] {gm gds} {vth} 0 ok
update
vwait forever

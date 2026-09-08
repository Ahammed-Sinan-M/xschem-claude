source [file join [file dirname [info script]] lk_prelude.tcl]
rdw::open
update idletasks
lk_two
for {set i 0} {$i<6} {incr i} {rdw::font_step 1}
update
vwait forever

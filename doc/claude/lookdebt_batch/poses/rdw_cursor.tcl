source [file join [file dirname [info script]] lk_prelude.tcl]
rdw::open
update idletasks
lk_two
rdw::set_row 3
update
vwait forever

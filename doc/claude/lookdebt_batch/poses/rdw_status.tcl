source [file join [file dirname [info script]] lk_prelude.tcl]
rdw::open
update idletasks
lk_two
rdw::set_row 3
rdw::status "Up: moved gds up in the annotation list for class mos, flavor *nfet* - this reorder was written to the settings file and every stored block of that class follows it, including the ones already on screen."
update
vwait forever

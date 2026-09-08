ase::ui::open lk sky130_tests_ase tb_bandgap schematic
update idletasks
after 400 {catch {ase::ui::simulators_dialog lk}}
vwait forever

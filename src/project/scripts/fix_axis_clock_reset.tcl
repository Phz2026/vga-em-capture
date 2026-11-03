# Apply this repair to an already-created V2.2 Vivado project if needed.
# Run from the Vivado Tcl Console with full_v24.xpr open.
set root [file normalize [file join [file dirname [info script]] ..]]
set bd_file [get_files -quiet */vga_em_bd.bd]
if {[llength $bd_file] != 1} {
  error "Expected exactly one vga_em_bd.bd in the open project"
}

open_bd_design $bd_file
set reset_pin [get_bd_pins -quiet axis_clock/resetn]
set run_high  [get_bd_pins -quiet one/dout]
if {[llength $reset_pin] != 1 || [llength $run_high] != 1} {
  error "axis_clock/resetn or one/dout was not found"
}

set old_net [get_bd_nets -quiet -of_objects $reset_pin]
if {[llength $old_net] != 0} {
  disconnect_bd_net $old_net $reset_pin
}
connect_bd_net $run_high $reset_pin
validate_bd_design
save_bd_design
generate_target all $bd_file
update_compile_order -fileset sources_1

puts "AXIS_CLOCK_RESET_FIX_APPLIED"
puts "axis_clock/resetn is now tied high; regenerate synthesis, implementation, BIT and LTX."

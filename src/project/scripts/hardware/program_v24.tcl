set root [file normalize [file join [file dirname [info script]] ../..]]
set bit [file join $root output bitstream full_v24.bit]
set ltx [file join $root output bitstream full_v24.ltx]
if {![file exists $bit] || ![file exists $ltx]} {error "V2.4 BIT/LTX not found"}

open_hw_manager
connect_hw_server -allow_non_jtag -url localhost:3121
set targets [get_hw_targets]
if {[llength $targets] != 1} {error "Expected one JTAG target; found [llength $targets]"}
current_hw_target [lindex $targets 0]
open_hw_target
set devices [get_hw_devices -filter {PART =~ xczu27dr*}]
if {[llength $devices] != 1} {error "Expected one XCZU27DR device; found [llength $devices]"}
current_hw_device [lindex $devices 0]
set_property PROGRAM.FILE $bit [current_hw_device]
set_property PROBES.FILE $ltx [current_hw_device]
set_property FULL_PROBES.FILE $ltx [current_hw_device]
program_hw_devices [current_hw_device]
refresh_hw_device -update_hw_probes false [current_hw_device]
puts "V24_PROGRAM_PASS bit=$bit probes=$ltx"
close_hw_target
disconnect_hw_server
close_hw_manager

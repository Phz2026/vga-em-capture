set root [file normalize [file join [file dirname [info script]] ../..]]
source [file join $root scripts hardware session.tcl]

vga_connect
vga_check
vga_rfdc_start
vga_rfdc_diag

vga_set_ddc_target 195.0 1
set at195 [vga_get_ddc]
vga_set_ddc_target 205.0 1
set at205 [vga_get_ddc]
vga_set_ddc_target 195.0 1

if {abs([lindex $at195 0]-195.0)>0.001} {error "195 MHz DDC readback failed"}
if {abs([lindex $at205 0]-205.0)>0.001} {error "205 MHz DDC readback failed"}
puts "V24_HARDWARE_SMOKE_PASS version=0x00020700 ilas=[llength [get_hw_ilas]] hw_axis=[llength [get_hw_axis]]"
close_hw_target
disconnect_hw_server
close_hw_manager

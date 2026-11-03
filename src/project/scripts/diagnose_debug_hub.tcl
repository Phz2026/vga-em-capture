set root [file normalize [file join [file dirname [info script]] ..]]
open_checkpoint [file join $root output reports implemented.dcp]

set hubs [get_debug_cores -quiet dbg_hub]
puts "DEBUG_CORES=[get_debug_cores -quiet]"
puts "DBG_HUB_COUNT=[llength $hubs]"
if {[llength $hubs] == 1} {
  set hub [lindex $hubs 0]
  puts "DBG_HUB_USER_CHAIN=[get_property C_USER_SCAN_CHAIN $hub]"
  puts "DBG_HUB_CLK_INPUT_FREQ_HZ=[get_property C_CLK_INPUT_FREQ_HZ $hub]"
  set clk_pin [get_pins -quiet dbg_hub/clk]
  puts "DBG_HUB_CLK_PIN=$clk_pin"
  puts "DBG_HUB_CLK_NET=[get_nets -quiet -of_objects $clk_pin]"
  puts "DBG_HUB_CLK_OBJECTS=[get_clocks -quiet -of_objects $clk_pin]"
}
close_design
exit

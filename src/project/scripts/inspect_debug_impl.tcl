set root [file normalize [file join [file dirname [info script]] ..]]
open_checkpoint [file join $root output reports implemented.dcp]
puts "DEBUG_CORES=[get_debug_cores]"
set hubs [get_debug_cores -quiet dbg_hub]
if {[llength $hubs] != 1} {error "Expected one dbg_hub; found [llength $hubs]"}
set hub [lindex $hubs 0]
puts "DBG_HUB_SCAN_CHAIN=[get_property C_USER_SCAN_CHAIN $hub]"
puts "DBG_HUB_CLK_INPUT_FREQ_HZ=[get_property C_CLK_INPUT_FREQ_HZ $hub]"
set clk_pin [get_pins -quiet dbg_hub/clk]
puts "DBG_HUB_CLK_PIN=$clk_pin"
puts "DBG_HUB_CLK_NET=[get_nets -quiet -of_objects $clk_pin]"
set hub_clocks [get_clocks -quiet -of_objects $clk_pin]
puts "DBG_HUB_CLOCKS=$hub_clocks"
foreach c $hub_clocks {puts "DBG_HUB_CLOCK_PERIOD($c)=[get_property PERIOD $c]"}
puts "DBG_HUB_CLK_ROOTS=[get_cells -quiet -of_objects [get_pins -quiet -leaf -of_objects [get_nets -quiet -of_objects $clk_pin]] -filter {IS_PRIMITIVE && (REF_NAME =~ BUFG* || REF_NAME =~ PS*)}]"
close_design

# Run with XSDB while Vivado Hardware Manager is disconnected.
# This initializes the PS clocks required by pl_clk0, releases PL isolation,
# and toggles the PS-to-PL reset. It does not program the FPGA bitstream.
set root [file normalize [file join [file dirname [info script]] ../..]]
set psu_init_file [file join $root build vivado_full_v1 full_v24.gen sources_1 bd vga_em_bd ip vga_em_bd_ps_0 psu_init.tcl]
if {![file exists $psu_init_file]} {
  error "Generated PS initialization file not found: $psu_init_file"
}

connect
puts "Available XSDB targets:"
targets
targets -set -nocase -filter {name =~ "*PSU*"}
source $psu_init_file

# Do not call psu_init here.  This board's DDR/MIO preset is not part of the
# PL-only project, and the generated full initialization can wait forever in
# DDR PHY bring-up.  The debug fabric only needs the PS PLL/clock registers.
puts "Initializing PS PLLs and clock registers (DDR is intentionally skipped)..."
set saved_force_mode [configparams force-mem-accesses]
configparams force-mem-accesses 1
init_ps [subst {$psu_pll_init_data $psu_clock_init_data}]
configparams force-mem-accesses $saved_force_mode
puts "Powering the PL domain and removing PS-to-PL isolation..."
psu_ps_pl_isolation_removal
puts "Releasing the PS-to-PL reset..."
psu_ps_pl_reset_config

# Give the generated PL clock and the automatically inserted Debug Hub time to
# become stable before Hardware Manager scans USER1.
after 100

set pl0_value [mrd -force 0xFF5E00C0]
set pll_status [mask_read 0xFF5E0040 0x00000001]
set pl0_active [mask_read 0xFF5E00C0 0x01000000]
if {$pll_status == 0} {error "IOPLL is not locked; PL0 clock cannot run"}
if {$pl0_active == 0} {error "PL0 reference clock is not enabled"}
puts "PS_INIT_FOR_JTAG_PASS"
puts "PL0_REF_CTRL=$pl0_value"
puts [format "IOPLL_LOCK=%d PL0_CLOCK_ACTIVE=%d" \
  [expr {$pll_status != 0}] [expr {$pl0_active != 0}]]
puts "NEXT: open/refresh Hardware Manager without programming the FPGA again"
disconnect
exit

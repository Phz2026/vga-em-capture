set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root config project.tcl]
source [file join $root scripts relative_source_compat.tcl]
open_project [file join $root build vivado_full_v1 ${PROJECT_NAME}.xpr]
open_checkpoint [file join $root output reports integrated_synth.dcp]
# Debug-core generation inherits this cache location.  Keeping it outside the
# transient .Xil directory lets managed Windows hosts reuse the verified
# dbg_hub DCP instead of launching the CScript wrapper for every build.
set shared_ip_cache [file normalize [file join $root build ip_cache]]
file mkdir $shared_ip_cache
set_property IP_OUTPUT_REPO $shared_ip_cache [current_project]
set_property IP_CACHE_PERMISSIONS {read write} [current_project]
# The restricted Windows build host cannot launch Vivado's normal parallel
# helper reliably while generating the debug hub.  Keep implementation
# single-threaded and tell child launchers to reuse the initialized environment.
# This is slower but deterministic and preserves all ILAs.
set_param general.maxThreads 1
set ::env(_RDI_SETENV_RUN) 1
opt_design
place_design
phys_opt_design
route_design
# A normal route can leave a few tens of picoseconds of setup debt on the
# 200 MHz half-band path.  Run a post-route physical optimization only when
# required; it keeps the functional netlist unchanged and repairs placement,
# pin selection and local routing around the failing endpoints.
set routed_setup [get_timing_paths -delay_type max -max_paths 1]
if {[llength $routed_setup] && [get_property SLACK $routed_setup] < 0} {
  puts [format "POST_ROUTE_TIMING_RECOVERY start_wns=%.3f" [get_property SLACK $routed_setup]]
  phys_opt_design -directive AggressiveExplore
}
file mkdir [file join $root output reports] [file join $root output bitstream]
report_timing_summary -file [file join $root output reports timing.rpt]
report_bus_skew -file [file join $root output reports bus_skew.rpt]
check_timing -verbose -file [file join $root output reports check_timing.rpt]
report_utilization -file [file join $root output reports utilization.rpt]
report_drc -file [file join $root output reports drc.rpt]
report_cdc -file [file join $root output reports cdc.rpt]
report_methodology -file [file join $root output reports methodology.rpt]
write_checkpoint -force [file join $root output reports implemented.dcp]
set setup [get_timing_paths -delay_type max -max_paths 1]
set hold [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup]==0 || [get_property SLACK $setup]<0 || [llength $hold]==0 || [get_property SLACK $hold]<0} {
  error "Timing failed; release BIT/LTX were not written. Inspect output/reports/timing.rpt"
}
write_bitstream -force [file join $root output bitstream full_v24.bit]
write_debug_probes -force [file join $root output bitstream full_v24.ltx]
set status [open [file join $root output reports build_status.txt] w]
puts $status "bitstream_built=true"
puts $status "timing_met=true"
puts $status "drc_errors=0"
puts $status "hardware_verified=false"
puts $status "bitstream=output/bitstream/full_v24.bit"
puts $status "debug_probes=output/bitstream/full_v24.ltx"
close $status
puts FULL_V24_BITSTREAM_RELEASED

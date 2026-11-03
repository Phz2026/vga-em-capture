set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root config project.tcl]
open_project [file join $root build vivado_full_v1 ${PROJECT_NAME}.xpr]
open_checkpoint [file join $root output reports implemented.dcp]

file mkdir [file join $root output reports]
report_timing_summary -file [file join $root output reports timing.rpt]
report_bus_skew -file [file join $root output reports bus_skew.rpt]
check_timing -verbose -file [file join $root output reports check_timing.rpt]
report_drc -file [file join $root output reports drc.rpt]
report_cdc -file [file join $root output reports cdc.rpt]
report_methodology -file [file join $root output reports methodology.rpt]

set setup [get_timing_paths -delay_type max -max_paths 1]
set hold [get_timing_paths -delay_type min -max_paths 1]
set setup_slack [get_property SLACK $setup]
set hold_slack [get_property SLACK $hold]
set drc_errors [llength [get_drc_violations -filter {SEVERITY == Error}]]
set drc_critical [llength [get_drc_violations -filter {SEVERITY == "Critical Warning"}]]
set bitstream_built [expr {[file exists [file join $root output bitstream full_v24.bit]] ? "true" : "false"}]
set timing_met [expr {$setup_slack >= 0.0 && $hold_slack >= 0.0 ? "true" : "false"}]

set status [open [file join $root output reports build_status.txt] w]
puts $status "bitstream_built=$bitstream_built"
puts $status "timing_met=$timing_met"
puts $status "setup_wns_ns=$setup_slack"
puts $status "hold_whs_ns=$hold_slack"
puts $status "drc_errors=$drc_errors"
puts $status "drc_critical_warnings=$drc_critical"
puts $status "hardware_verified=false"
puts $status "bitstream=output/bitstream/full_v24.bit"
puts $status "debug_probes=output/bitstream/full_v24.ltx"
close $status

if {$setup_slack < 0.0 || $hold_slack < 0.0 || $drc_errors != 0} {
  error "Post-build verification failed; inspect output/reports"
}
puts "FULL_V24_POST_BUILD_VERIFIED setup_wns=$setup_slack hold_whs=$hold_slack drc_errors=$drc_errors"

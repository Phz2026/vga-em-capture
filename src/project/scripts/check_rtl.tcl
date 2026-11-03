set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root config project.tcl]
file mkdir [file join $root output reports]
foreach top {rfdc_pair_capture cdc_flag full_control spectrum_engine raw_iq_capture frame_event_detector processing_core} {
  create_project -in_memory -part $PART
  set_property XPM_LIBRARIES {XPM_MEMORY} [current_project]
  if {$top eq "frame_event_detector"} {
    read_verilog -sv [glob [file join $root rtl {frame_event_detector.sv}]]
  } elseif {$top eq "processing_core"} {
    read_verilog -sv [glob [file join $root rtl {halfband_decimator2.sv}]]
    read_verilog -sv [glob [file join $root rtl {leakage_demod.sv}]]
    read_verilog -sv [glob [file join $root rtl {feature_extract.sv}]]
    read_verilog -sv [glob [file join $root rtl {frame_event_detector.sv}]]
    read_verilog -sv [glob [file join $root rtl {raster_frame_buffer.sv}]]
    read_verilog -sv [glob [file join $root rtl {raw_iq_capture.sv}]]
    read_verilog -sv [glob [file join $root rtl {processing_core.sv}]]
  } else {read_verilog -sv [file join $root rtl $top.sv]}
  synth_design -top $top -part $PART -mode out_of_context
  report_utilization -file [file join $root output reports ${top}_utilization.rpt]
  puts "RTL_SYNTH_PASS=$top"
  close_project
}
puts ALL_RTL_SYNTH_PASS

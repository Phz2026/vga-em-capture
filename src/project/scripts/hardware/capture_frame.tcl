source [file join [file dirname [info script]] session.tcl]
proc capture_frame {directory {pending_only 0}} {
  vga_check
  set feature_gain [reg_rd [expr {$::CTRL_BASE+0x2c}]]
  set feature_mode [reg_rd [expr {$::CTRL_BASE+0x40}]]
  set ddc [vga_get_ddc]
  if {$feature_gain==0} {error "FEATURE_GAIN is zero; call vga_set_feature_gain before capture"}
  puts [format "Capturing with FEATURE_GAIN=%.3fx (Q8=0x%04X), FEATURE_MODE=%d" [expr {$feature_gain/256.0}] $feature_gain $feature_mode]
  set directory [file normalize $directory]
  if {[file exists $directory]} {error "Use a new output directory"}
  if {!$pending_only && ([reg_rd [expr {$::CTRL_BASE+0x58}]] & 1)} {
    error "Event mode is enabled; use capture_event_frame or disable event mode"
  }
  if {!$pending_only} {
    reg_wr [expr {$::CTRL_BASE+8}] 0x02
    reg_wr [expr {$::CTRL_BASE+8}] 0x01
  }
  set deadline [expr {[clock milliseconds]+($pending_only ? 60000 : 5000)}]
  while {([reg_rd [expr {$::CTRL_BASE+0x0c}]]&0x04)==0 && [clock milliseconds]<$deadline} {after 50}
  if {[clock milliseconds]>=$deadline} {error "Frame capture timeout"}
  file mkdir $directory
  set event_status [reg_rd [expr {$::CTRL_BASE+0x5c}]]
  set event_metric [reg_rd [expr {$::CTRL_BASE+0x60}]]
  set event_lag [reg_rd [expr {$::CTRL_BASE+0x64}]]
  set ilas [get_hw_ilas -filter {CELL_NAME =~ *image_ila*}]
  if {[llength $ilas]!=1} {error "Cannot uniquely identify image_ila"}
  set ila [lindex $ilas 0]
  set valid [get_hw_probes -of_objects $ila -filter {NAME =~ *image_valid* || NAME =~ *probe2*}]
  set trig  [get_hw_probes -of_objects $ila -filter {NAME =~ *image_trigger* || NAME =~ *probe3*}]
  set_property CONTROL.TRIGGER_POSITION 0 $ila
  set_property CONTROL.DATA_DEPTH $::IMAGE_ILA_DEPTH $ila
  set_property CONTROL.CAPTURE_MODE BASIC $ila
  set_property CAPTURE_COMPARE_VALUE "eq1'b1" $valid
  set_property TRIGGER_COMPARE_VALUE "eq1'b1" $trig
  set total [expr {$::VGA_LINE_SAMPLES*$::VGA_FRAME_LINES}]
  set segments [expr {($total+$::IMAGE_SEGMENT_BYTES-1)/$::IMAGE_SEGMENT_BYTES}]
  for {set s 0} {$s<$segments} {incr s} {
    reg_wr [expr {$::CTRL_BASE+0x28}] $s
    run_hw_ila $ila
    reg_wr [expr {$::CTRL_BASE+8}] 0x08
    if {[catch {wait_on_hw_ila -timeout 30 $ila} reason]} {error "Segment $s timeout: $reason"}
    set data [upload_hw_ila_data $ila]
    write_hw_ila_data -csv_file [file join $directory [format "segment_%02d.csv" $s]] $data
  }
  set f [open [file join $directory metadata.txt] w]
  puts $f "line_samples=$::VGA_LINE_SAMPLES\nframe_lines=$::VGA_FRAME_LINES\nsegments=$segments\nframe_counter_at_export=[reg_rd [expr {$::CTRL_BASE+0x34}]]\nfeature_gain_q8=$feature_gain\nfeature_mode=$feature_mode\niq_order=I_then_Q_when_mode_3\nddc_target_mhz=[lindex $ddc 0]\nddc_mixer_mhz=[lindex $ddc 1]\nddc_phase_inc=[lindex $ddc 2]\nddc_control=[lindex $ddc 3]\nevent_status=$event_status\nevent_metric_q16=$event_metric\nevent_best_lag=$event_lag"
  close $f
  if {$pending_only} {reg_wr [expr {$::CTRL_BASE+8}] 0x02}
  puts "FRAME_EXPORTED=$directory"
}

proc capture_frame_mode {mode gain_x directory} {
  vga_set_feature_mode $mode
  vga_set_feature_gain $gain_x
  capture_frame $directory
}

proc capture_frame_target {rf_mhz mode gain_x directory} {
  vga_set_ddc_target $rf_mhz 1
  capture_frame_mode $mode $gain_x $directory
}

proc capture_event_frame {directory} {
  # Export the already frozen bank and acknowledge it only after all segments
  # are written.  A supplemental bank stays queued for the next call.
  capture_frame $directory 1
}

proc capture_event_series {directory_prefix count} {
  if {![string is integer -strict $count] || $count < 1} {
    error "count must be a positive integer"
  }
  for {set i 1} {$i <= $count} {incr i} {
    set directory [format "%s_%03d" $directory_prefix $i]
    capture_event_frame $directory
  }
  puts "EVENT_SERIES_EXPORTED=$count"
}

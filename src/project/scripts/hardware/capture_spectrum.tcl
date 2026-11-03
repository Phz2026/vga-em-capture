source [file join [file dirname [info script]] session.tcl]
proc capture_spectrum {directory} {
  vga_check
  set directory [file normalize $directory]
  if {[file exists $directory]} {error "Use a new output directory"}
  set ilas [get_hw_ilas -filter {CELL_NAME =~ *spectrum_ila*}]
  if {[llength $ilas]!=1} {error "Cannot uniquely identify spectrum_ila"}
  set ila [lindex $ilas 0]
  set valid [get_hw_probes -of_objects $ila -filter {NAME =~ *replay_valid* || NAME =~ *probe2*}]
  set trig  [get_hw_probes -of_objects $ila -filter {NAME =~ *replay_trigger* || NAME =~ *probe3*}]
  set_property CONTROL.TRIGGER_POSITION 0 $ila
  set_property CONTROL.DATA_DEPTH $::SPEC_ILA_DEPTH $ila
  set_property CONTROL.CAPTURE_MODE BASIC $ila
  set_property CAPTURE_COMPARE_VALUE "eq1'b1" $valid
  set_property TRIGGER_COMPARE_VALUE "eq1'b1" $trig
  run_hw_ila $ila
  reg_wr [expr {$::CTRL_BASE+8}] 0x04
  set deadline [expr {[clock milliseconds]+15000}]
  while {([reg_rd [expr {$::CTRL_BASE+0x0c}]]&0x10)==0 && [clock milliseconds]<$deadline} {after 100}
  if {[clock milliseconds]>=$deadline} {error "Spectrum calculation timeout"}
  reg_wr [expr {$::CTRL_BASE+8}] 0x10
  if {[catch {wait_on_hw_ila -timeout 30 $ila} reason]} {error "ILA timeout: $reason"}
  set data [upload_hw_ila_data $ila]
  file mkdir $directory
  write_hw_ila_data -csv_file [file join $directory spectrum.csv] $data
  puts "SPECTRUM_EXPORTED=$directory"
}

# Host-driven snapshot loop.  The interval is a minimum start-to-start delay:
# ILA upload over JTAG may take longer, so actual cadence is printed and must
# be measured rather than assumed to meet a 2-5 s display target.
proc capture_spectrum_series {directory_prefix count {interval_ms 3000}} {
  if {![string is integer -strict $count] || $count < 1} {
    error "count must be a positive integer"
  }
  if {![string is integer -strict $interval_ms] || $interval_ms < 0} {
    error "interval_ms must be a nonnegative integer"
  }
  for {set i 1} {$i <= $count} {incr i} {
    set start_ms [clock milliseconds]
    capture_spectrum [format "%s_%03d" $directory_prefix $i]
    set elapsed_ms [expr {[clock milliseconds]-$start_ms}]
    puts [format "SPECTRUM_SNAPSHOT=%d CAPTURE_ELAPSED_MS=%d" $i $elapsed_ms]
    if {$i < $count && $elapsed_ms < $interval_ms} {
      after [expr {$interval_ms-$elapsed_ms}]
    }
  }
  puts "SPECTRUM_SERIES_EXPORTED=$count"
}

source [file join [file dirname [info script]] session.tcl]
proc capture_raw_iq {directory {samples 32768}} {
  vga_check
  if {[lsearch -exact {1024 2048 4096 8192 16384 32768} $samples]<0} {
    error "samples must be an ILA-supported power of two: 1024, 2048, 4096, 8192, 16384, or 32768"
  }
  vga_set_raw_capture_length $samples
  set directory [file normalize $directory]
  if {[file exists $directory]} {error "Use a new output directory"}
  file mkdir $directory

  reg_wr [expr {$::CTRL_BASE+8}] 0x40
  set deadline [expr {[clock milliseconds]+5000}]
  while {([reg_rd [expr {$::CTRL_BASE+0x0c}]]&0x8000)==0 && [clock milliseconds]<$deadline} {after 20}
  if {[clock milliseconds]>=$deadline} {error "Raw I/Q capture timeout"}
  set actual [reg_rd [expr {$::CTRL_BASE+0x50}]]
  if {$actual!=$samples} {error "Raw I/Q captured $actual samples; expected $samples"}

  set ilas [get_hw_ilas -filter {CELL_NAME =~ *raw_iq_ila*}]
  if {[llength $ilas]!=1} {error "Cannot uniquely identify raw_iq_ila"}
  set ila [lindex $ilas 0]
  set valid [get_hw_probes -of_objects $ila -filter {NAME =~ *raw_replay_valid* || NAME =~ *probe3*}]
  set trig  [get_hw_probes -of_objects $ila -filter {NAME =~ *raw_replay_trigger* || NAME =~ *probe4*}]
  set_property CONTROL.TRIGGER_POSITION 0 $ila
  set_property CONTROL.DATA_DEPTH $samples $ila
  set_property CONTROL.CAPTURE_MODE BASIC $ila
  set_property CAPTURE_COMPARE_VALUE "eq1'b1" $valid
  set_property TRIGGER_COMPARE_VALUE "eq1'b1" $trig
  run_hw_ila $ila
  reg_wr [expr {$::CTRL_BASE+8}] 0x80
  if {[catch {wait_on_hw_ila -timeout 30 $ila} reason]} {error "Raw I/Q ILA timeout: $reason"}
  set data [upload_hw_ila_data $ila]
  write_hw_ila_data -csv_file [file join $directory raw_iq.csv] $data

  set ddc [vga_get_ddc]
  set f [open [file join $directory metadata.txt] w]
  puts $f "format=signed_q16_i16"
  puts $f "source=post_halfband_pre_ddc"
  puts $f "sample_rate_hz=$::IMAGE_RATE_HZ"
  puts $f "samples=$actual"
  puts $f "rf_center_mhz=[expr {abs(double($::NCO_MHZ))}]"
  puts $f "ddc_target_mhz=[lindex $ddc 0]"
  close $f
  puts "RAW_IQ_EXPORTED=$directory samples=$actual"
}


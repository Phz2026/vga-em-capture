# Source this file in a persistent Vivado Hardware Manager Tcl console.
set vga_root [file normalize [file join [file dirname [info script]] ../..]]
source [file join $vga_root config project.tcl]
proc vga_connect {} {
  open_hw_manager
  connect_hw_server -url localhost:3121
  set targets [get_hw_targets]
  if {[llength $targets]!=1} {error "Expected one JTAG target; found [llength $targets]"}
  current_hw_target [lindex $targets 0]; open_hw_target
  set devices [get_hw_devices -filter {PART =~ xczu27dr*}]
  if {[llength $devices]!=1} {error "Expected one XCZU27DR device"}
  current_hw_device [lindex $devices 0]
  vga_attach
}
proc vga_attach {} {
  set devices [get_hw_devices -filter {PART =~ xczu27dr*}]
  if {[llength $devices]!=1} {error "Expected one XCZU27DR device"}
  current_hw_device [lindex $devices 0]
  set probes [file join $::vga_root output bitstream full_v24.ltx]
  if {![file exists $probes]} {error "Debug probes file not found: $probes"}
  set_property PROBES.FILE $probes [current_hw_device]
  set_property FULL_PROBES.FILE $probes [current_hw_device]
  # The integrated debug hub uses USER1.  Hardware Manager does not preserve
  # this mask across fresh GUI sessions, so apply it before every refresh.
  set_property BSCAN_SWITCH_USER_MASK 0001 [current_hw_device]
  refresh_hw_device [current_hw_device]
  if {[llength [get_hw_axis]]!=1 || [llength [get_hw_ilas]]!=4} {
    error "Debug Hub is not active. Keep the FPGA programmed, disconnect Hardware Manager, run scripts/prepare_opt_hardware.ps1, then reconnect and call vga_attach without programming again"
  }
  set ::vga_master [lindex [get_hw_axis] 0]
  puts [format "VGA_DEBUG_ATTACHED probes=%s ilas=%d hw_axis=%d" $probes [llength [get_hw_ilas]] [llength [get_hw_axis]]]
}
proc reg_rd {addr} {
  set tx [create_hw_axi_txn vga_read $::vga_master -type read -address [format %08X $addr] -len 1]
  try {run_hw_axi $tx; scan [get_property DATA $tx] %x value; return $value} finally {delete_hw_axi_txn $tx}
}
proc reg_wr {addr value} {
  set tx [create_hw_axi_txn vga_write $::vga_master -type write -address [format %08X $addr] -data [format %08X $value] -len 1]
  try {run_hw_axi $tx} finally {delete_hw_axi_txn $tx}
}
proc vga_check {} {
  if {[reg_rd $::CTRL_BASE]!=0x56474132} {error "Wrong bitstream or register map"}
  set version [reg_rd [expr {$::CTRL_BASE+4}]]
  if {$version!=0x00020700} {
    error [format "Wrong design version 0x%08X; expected V2.1 event-export version 0x00020700" $version]
  }
  reg_wr [expr {$::CTRL_BASE+0x3c}] 0x1234ABCD
  if {[reg_rd [expr {$::CTRL_BASE+0x3c}]]!=0x1234ABCD} {error "JTAG-to-AXI scratch readback failed"}
  puts [format "VGA_REGISTER_TEST_PASS version=0x%08X" $version]
}
proc vga_set_event_mode {enable {threshold_q16 2048}} {
  reg_wr [expr {$::CTRL_BASE+0x54}] $threshold_q16
  reg_wr [expr {$::CTRL_BASE+0x58}] [expr {$enable ? 1 : 0}]
  puts [format "EVENT_MODE=%d THRESHOLD_Q16=%d" $enable $threshold_q16]
}
proc vga_force_export {} {
  reg_wr [expr {$::CTRL_BASE+0x58}] 0x03
  puts "EVENT_FORCE_EXPORT=1"
}
proc vga_get_event_status {} {
  set s [reg_rd [expr {$::CTRL_BASE+0x5c}]]
  set m [reg_rd [expr {$::CTRL_BASE+0x60}]]
  set l [reg_rd [expr {$::CTRL_BASE+0x64}]]
  puts [format "EVENT_STATUS=0x%08X METRIC_Q16=0x%04X BEST_LAG=%d" $s $m $l]
  return [list $s $m $l]
}
proc vga_set_feature_mode {mode} {
  switch -nocase -- $mode {
    magnitude - mag {set value 0}
    i {set value 1}
    q {set value 2}
    iq - interleaved {set value 3}
    default {error "mode must be magnitude, i, q, or iq"}
  }
  reg_wr [expr {$::CTRL_BASE+0x40}] $value
  set actual [reg_rd [expr {$::CTRL_BASE+0x40}]]
  if {$actual!=$value} {error "FEATURE_MODE readback mismatch"}
  puts [format "FEATURE_MODE=%s (%d)" $mode $actual]
  return $actual
}
proc vga_get_feature_mode {} {
  set value [reg_rd [expr {$::CTRL_BASE+0x40}]]
  set names {magnitude i q iq}
  puts [format "FEATURE_MODE=%s (%d)" [lindex $names $value] $value]
  return $value
}
proc vga_set_feature_gain {gain_x} {
  if {$gain_x <= 0 || $gain_x >= 256} {
    error "gain_x must be greater than 0 and less than 256"
  }
  set q8 [expr {int(round(double($gain_x)*256.0))}]
  if {$q8 > 65535} {set q8 65535}
  reg_wr [expr {$::CTRL_BASE+0x2c}] $q8
  set actual [reg_rd [expr {$::CTRL_BASE+0x2c}]]
  if {$actual != $q8} {error "FEATURE_GAIN readback mismatch"}
  puts [format "FEATURE_GAIN=%.3fx (Q8=0x%04X)" [expr {$actual/256.0}] $actual]
}
proc vga_get_feature_gain {} {
  set q8 [reg_rd [expr {$::CTRL_BASE+0x2c}]]
  puts [format "FEATURE_GAIN=%.3fx (Q8=0x%04X)" [expr {$q8/256.0}] $q8]
  return $q8
}
proc vga_set_ddc_target {rf_mhz {filter_enable 1}} {
  if {$rf_mhz < 135.0 || $rf_mhz > 265.0} {error "rf_mhz must be within 135..265 MHz"}
  set mixer_mhz [expr {abs(double($::NCO_MHZ))-double($rf_mhz)}]
  set phase_word [expr {wide(round($mixer_mhz*4294967296.0/($::IMAGE_RATE_HZ/1.0e6))) & 0xffffffff}]
  reg_wr [expr {$::CTRL_BASE+0x44}] $phase_word
  reg_wr [expr {$::CTRL_BASE+0x48}] [expr {$filter_enable ? 3 : 1}]
  after 20
  set actual [reg_rd [expr {$::CTRL_BASE+0x44}]]
  if {$actual!=$phase_word} {error "DDC phase increment readback mismatch"}
  puts [format "DDC_TARGET_RF=%.6f MHz MIXER=%+.6f MHz PHASE_INC=0x%08X FILTER=%d" $rf_mhz $mixer_mhz $actual $filter_enable]
  return $actual
}
proc vga_set_ddc_bypass {} {
  reg_wr [expr {$::CTRL_BASE+0x48}] 0
  puts "DDC_BYPASS mixer=0 filter=0"
}
proc vga_get_ddc {} {
  set word [reg_rd [expr {$::CTRL_BASE+0x44}]]
  set ctrl [reg_rd [expr {$::CTRL_BASE+0x48}]]
  set signed_word [expr {$word>=0x80000000 ? $word-0x100000000 : $word}]
  set mixer_mhz [expr {$signed_word*($::IMAGE_RATE_HZ/1.0e6)/4294967296.0}]
  set target_mhz [expr {abs(double($::NCO_MHZ))-$mixer_mhz}]
  puts [format "DDC_TARGET_RF=%.6f MHz MIXER=%+.6f MHz PHASE_INC=0x%08X MIXER_EN=%d FILTER_EN=%d" $target_mhz $mixer_mhz $word [expr {$ctrl&1}] [expr {($ctrl>>1)&1}]]
  return [list $target_mhz $mixer_mhz $word $ctrl]
}
proc vga_set_raw_capture_length {samples} {
  if {$samples<1 || $samples>$::RAW_IQ_CAPTURE_DEPTH} {error "samples must be 1..$::RAW_IQ_CAPTURE_DEPTH"}
  reg_wr [expr {$::CTRL_BASE+0x4c}] $samples
  if {[reg_rd [expr {$::CTRL_BASE+0x4c}]]!=$samples} {error "RAW_CAPTURE_LENGTH readback mismatch"}
  puts "RAW_CAPTURE_LENGTH=$samples complex samples"
}
proc vga_rfdc_diag {} {
  set tile [expr {$::RFDC_BASE+0x14000+0x4000*$::ADC_TILE}]
  puts [format "RFDC_ADC_TILE%d_BASE=0x%08X" $::ADC_TILE $tile]
  foreach {name offset} {
    RESTART       0x004
    RESTART_STATE 0x008
    CURRENT_STATE 0x00c
    CLOCK_DETECT  0x080
    COMMON_STATUS 0x228
  } {
    puts [format "%-14s=0x%08X" $name [reg_rd [expr {$tile+$offset}]]]
  }
}
proc vga_rfdc_start {{timeout_ms 5000}} {
  vga_check
  set tile [expr {$::RFDC_BASE+0x14000+0x4000*$::ADC_TILE}]
  set state [expr {[reg_rd [expr {$tile+0x0c}]]&15}]
  if {$state!=15} {
    set old [reg_rd [expr {$tile+8}]]
    reg_wr [expr {$tile+8}] [expr {($old&0xffff0000)|0x010f}]
    reg_wr [expr {$tile+4}] 1
  }
  set deadline [expr {[clock milliseconds]+$timeout_ms}]
  while {[clock milliseconds]<$deadline} {
    set state [expr {[reg_rd [expr {$tile+12}]]&15}]
    if {$state==15 && !([reg_rd [expr {$tile+4}]]&1)} {puts RFDC_TILE_READY; return}
    after 50
  }
  vga_rfdc_diag
  error "RFDC startup timeout, state=$state; inspect CLOCK_DETECT and COMMON_STATUS above"
}

# Explicit IP-XACT packaging keeps the generated block design deterministic.
proc package_vga_ip {root name rtl_files ports has_axi clk rst} {
  set dir [file join $root build local_ip $name]
  file mkdir $dir
  set core [ipx::create_core user.org vga_em $name 1.0]
  set_property root_directory $dir $core
  set_property display_name $name $core
  set_property supported_families {zynquplus Production} $core
  foreach src $rtl_files {file copy -force [file join $root rtl $src] [file join $dir $src]}
  foreach kind {xilinx_anylanguagesynthesis xilinx_anylanguagebehavioralsimulation} {
    set g [ipx::add_file_group $kind $core]
    set_property model_name $name $g
    foreach src $rtl_files {
      set f [ipx::add_file $src $g]
      set_property type systemVerilogSource $f
    }
  }
  foreach {n d w} $ports {
    set p [ipx::add_port $n $core]
    set_property direction $d $p
    if {$w>1} {set_property size_left [expr {$w-1}] $p; set_property size_right 0 $p}
  }
  foreach {n type role} [list $clk clock CLK $rst reset RST] {
    set b [ipx::add_bus_interface $n $core]
    set_property bus_type_vlnv xilinx.com:signal:$type:1.0 $b
    set_property abstraction_type_vlnv xilinx.com:signal:${type}_rtl:1.0 $b
    set_property interface_mode slave $b
    set m [ipx::add_port_map $role $b]; set_property physical_name $n $m
    if {$type eq "reset"} {
      set p [ipx::add_bus_parameter POLARITY $b]; set_property value ACTIVE_LOW $p
    } else {
      set p [ipx::add_bus_parameter ASSOCIATED_RESET $b]; set_property value $rst $p
      if {$has_axi} {set p [ipx::add_bus_parameter ASSOCIATED_BUSIF $b]; set_property value S_AXI $p}
    }
  }
  if {$has_axi} {
    set b [ipx::add_bus_interface S_AXI $core]
    set_property bus_type_vlnv xilinx.com:interface:aximm:1.0 $b
    set_property abstraction_type_vlnv xilinx.com:interface:aximm_rtl:1.0 $b
    set_property interface_mode slave $b
    foreach sig {AWADDR AWVALID AWREADY WDATA WSTRB WVALID WREADY BRESP BVALID BREADY ARADDR ARVALID ARREADY RDATA RRESP RVALID RREADY} {
      set m [ipx::add_port_map $sig $b]; set_property physical_name s_axi_[string tolower $sig] $m
    }
    set p [ipx::add_bus_parameter PROTOCOL $b]; set_property value AXI4LITE $p
    set mm [ipx::add_memory_map S_AXI $core]
    set ab [ipx::add_address_block reg0 $mm]
    set_property range 256 $ab; set_property width 32 $ab; set_property usage register $ab
    set_property slave_memory_map_ref S_AXI $b
  }
  ipx::save_core $core
  ipx::unload_core [file join $dir component.xml]
}

package_vga_ip $root rfdc_pair_capture {rfdc_pair_capture.sv} {
 axis_clk in 1 axis_resetn in 1 i_data in 32 q_data in 32 i_valid in 1 q_valid in 1
 i_ready out 1 q_ready out 1 fifo_data out 64 fifo_valid out 1 fifo_ready in 1 loss out 1
} 0 axis_clk axis_resetn
package_vga_ip $root cdc_flag {cdc_flag.sv} {clk in 1 rstn in 1 async_flag in 1 synced_flag out 1} 0 clk rstn
package_vga_ip $root processing_core {halfband_decimator2.sv leakage_demod.sv feature_extract.sv frame_event_detector.sv raster_frame_buffer.sv raw_iq_capture.sv processing_core.sv} {
 clk in 1 rstn in 1 sample_data in 64 sample_valid in 1 feature_gain in 16 feature_mode in 2
 ddc_phase_inc in 32 ddc_control in 2
 capture_start in 1 frame_ack in 1 line_samples in 16 frame_lines in 16 segment_sel in 8
 image_replay_start in 1 clear_error in 1 event_enable in 1 event_force in 1 event_threshold in 16
 raw_capture_start in 1 raw_replay_start in 1 raw_capture_length in 16
 decim_data out 32 decim_valid out 1
 capture_busy out 1 frame_pending out 1 frozen_bank out 1 frame_id out 32
 image_replay_busy out 1 image_data out 8 image_addr out 21 image_valid out 1
 image_trigger out 1 image_done out 1 range_error out 1 raw_capture_busy out 1 raw_capture_pending out 1
 raw_replay_busy out 1 raw_replay_done out 1 raw_range_error out 1 raw_captured_count out 16
 event_busy out 1 event_decision_valid out 1 event_changed out 1 event_metric_q16 out 16 event_best_lag out 16
 event_debounce_history out 3 event_reference_valid out 1 event_ack_copy_busy out 1
 raw_replay_i out 16 raw_replay_q out 16 raw_replay_addr out 15 raw_replay_valid out 1 raw_replay_trigger out 1
} 0 clk rstn
package_vga_ip $root spectrum_engine {spectrum_engine.sv} {
 clk in 1 rstn in 1 sample_data in 32 sample_valid in 1 arm in 1 replay_start in 1 clear_error in 1
 busy out 1 done out 1 average_count out 3 overflow_error out 1
 fft_cfg_data out 8 fft_cfg_valid out 1 fft_cfg_ready in 1
 fft_in_data out 32 fft_in_valid out 1 fft_in_last out 1 fft_in_ready in 1
 fft_out_data in 32 fft_out_valid in 1 fft_out_last in 1 fft_out_user in 24 fft_out_ready out 1
 fft_status_data in 8 fft_status_valid in 1 fft_status_ready out 1
 event_frame_started in 1 event_tlast_unexpected in 1 event_tlast_missing in 1
 event_status_halt in 1 event_data_in_halt in 1 event_data_out_halt in 1
 replay_busy out 1 replay_data out 8 replay_addr out 16 replay_valid out 1 replay_trigger out 1 replay_done out 1
} 0 clk rstn
package_vga_ip $root full_control {full_control.sv} {
 clk in 1 rstn in 1 stream_loss in 1 frame_pending in 1 capture_busy in 1 frozen_bank in 1 frame_id in 32
 image_replay_busy in 1 image_done in 1 image_range_error in 1 spectrum_busy in 1 spectrum_done in 1
 spectrum_average_count in 3 spectrum_overflow_error in 1 spectrum_replay_busy in 1 spectrum_replay_done in 1
 raw_capture_busy in 1 raw_capture_pending in 1 raw_replay_busy in 1 raw_replay_done in 1 raw_range_error in 1 raw_captured_count in 16
 event_busy in 1 event_decision_valid in 1 event_changed in 1 event_metric_q16 in 16 event_best_lag in 16
 event_debounce_history in 3 event_reference_valid in 1 event_ack_copy_busy in 1
 capture_start out 1 frame_ack out 1 spectrum_arm out 1 image_replay_start out 1 spectrum_replay_start out 1 clear_error out 1
 raw_capture_start out 1 raw_replay_start out 1
 line_samples out 16 frame_lines out 16 active_width out 16 active_height out 16 crop_x out 16 crop_y out 16
 segment_sel out 8 feature_gain out 16 feature_mode out 2 diff_threshold out 16
 event_enable out 1 event_force out 1 event_threshold out 16
 ddc_phase_inc out 32 ddc_control out 2 raw_capture_length out 16
 s_axi_awaddr in 8 s_axi_awvalid in 1 s_axi_awready out 1 s_axi_wdata in 32 s_axi_wstrb in 4
 s_axi_wvalid in 1 s_axi_wready out 1 s_axi_bresp out 2 s_axi_bvalid out 1 s_axi_bready in 1
 s_axi_araddr in 8 s_axi_arvalid in 1 s_axi_arready out 1 s_axi_rdata out 32 s_axi_rresp out 2
 s_axi_rvalid out 1 s_axi_rready in 1
} 1 clk rstn
set_property ip_repo_paths [file join $root build local_ip] [current_project]
update_ip_catalog

set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root config project.tcl]
source [file join $root scripts relative_source_compat.tcl]
set work [file join $root build vivado_full_v1]
set xpr [file join $work ${PROJECT_NAME}.xpr]
file mkdir [file join $root output reports]
create_project -force $PROJECT_NAME $work -part $PART
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
source [file join $root scripts package_local_ip.tcl]
create_bd_design $BD_NAME
proc ip {name kind} {return [create_bd_cell -type ip -vlnv xilinx.com:ip:$kind:* $name]}
proc wire {a args} {set pins [list [get_bd_pins $a]]; foreach b $args {lappend pins [get_bd_pins $b]}; connect_bd_net {*}$pins}

# RFSoC ADC Tile 1, ADC01.  The RFDC emits I and Q as two 32-bit AXI streams.
ip rfdc usp_rf_data_converter
set_property -dict [list CONFIG.ADC0_Enable 0 CONFIG.ADC_Slice00_Enable false \
  CONFIG.ADC1_Enable 1 CONFIG.ADC_Slice10_Enable true CONFIG.ADC1_PLL_Enable true \
  CONFIG.ADC1_Refclk_Freq $ADC_REF_MHZ CONFIG.ADC1_Sampling_Rate $ADC_FS_GSPS \
  CONFIG.ADC_Decimation_Mode10 $ADC_DECIMATION CONFIG.ADC_Mixer_Type10 2 \
  CONFIG.ADC_Mixer_Mode10 0 CONFIG.ADC_Data_Type10 1 CONFIG.ADC_Data_Width10 $ADC_WORD_SAMPLES \
  CONFIG.ADC_NCO_Freq10 [expr {$NCO_MHZ/1000.0}] CONFIG.Axiclk_Freq $PL_MHZ] [get_bd_cells rfdc]
if {$ADC_TILE != 1} {error "This board revision is wired for ADC Tile 1 ADC01."}
set rf_mhz [get_property CONFIG.ADC1_Outclk_Freq [get_bd_cells rfdc]]
set axis_mhz [get_property CONFIG.ADC1_Fabric_Freq [get_bd_cells rfdc]]

ip axis_clock clk_wiz
set_property -dict [list CONFIG.PRIM_IN_FREQ $rf_mhz CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $axis_mhz \
  CONFIG.PRIM_SOURCE No_buffer CONFIG.RESET_TYPE ACTIVE_LOW] [get_bd_cells axis_clock]
ip zero xlconstant; set_property CONFIG.CONST_VAL 0 [get_bd_cells zero]
ip one xlconstant;  set_property CONFIG.CONST_VAL 1 [get_bd_cells one]
# The Clocking Wizard reset is active-low.  Leaving this pin unconnected makes
# IP Integrator tie it low, which permanently resets the RFDC AXIS clock and
# leaves the RFDC tile at state 0xE.
wire one/dout axis_clock/resetn
ip reset_pl proc_sys_reset
ip reset_axis proc_sys_reset
foreach r {reset_pl reset_axis} {
  set_property CONFIG.C_AUX_RESET_HIGH 0 [get_bd_cells $r]
  wire one/dout $r/aux_reset_in
  wire zero/dout $r/mb_debug_sys_rst
}
wire one/dout reset_pl/dcm_locked
wire one/dout reset_axis/ext_reset_in
wire rfdc/clk_adc1 axis_clock/clk_in1
wire axis_clock/clk_out1 rfdc/m1_axis_aclk reset_axis/slowest_sync_clk
wire axis_clock/locked reset_axis/dcm_locked
wire reset_axis/peripheral_aresetn rfdc/m1_axis_aresetn

# PS supplies the 200 MHz PL processing clock.  No Linux software is required.
ip ps zynq_ultra_ps_e
set_property -dict [list CONFIG.PSU__FPGA_PL0_ENABLE 1 \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL IOPLL \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ $PL_MHZ CONFIG.PSU__USE__M_AXI_GP2 0] [get_bd_cells ps]
set ps_mhz [get_property CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ [get_bd_cells ps]]
if {abs($ps_mhz-$PL_MHZ)>0.01} {error "PS pl_clk0 is $ps_mhz MHz, requested $PL_MHZ MHz"}
wire ps/pl_resetn0 reset_pl/ext_reset_in

# JTAG-to-AXI is the command/status path; it does not carry sample streams.
ip jtag_axi jtag_axi; set_property CONFIG.PROTOCOL 2 [get_bd_cells jtag_axi]
ip interconnect axi_interconnect; set_property CONFIG.NUM_MI 2 [get_bd_cells interconnect]
connect_bd_intf_net [get_bd_intf_pins jtag_axi/M_AXI] [get_bd_intf_pins interconnect/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins interconnect/M00_AXI] [get_bd_intf_pins rfdc/s_axi]

create_bd_cell -type ip -vlnv user.org:vga_em:rfdc_pair_capture:1.0 pair
create_bd_cell -type ip -vlnv user.org:vga_em:cdc_flag:1.0 loss_cdc
create_bd_cell -type ip -vlnv user.org:vga_em:processing_core:1.0 processing
create_bd_cell -type ip -vlnv user.org:vga_em:spectrum_engine:1.0 spec_eng
create_bd_cell -type ip -vlnv user.org:vga_em:full_control:1.0 control
connect_bd_intf_net [get_bd_intf_pins interconnect/M01_AXI] [get_bd_intf_pins control/S_AXI]

ip stream_fifo axis_data_fifo
set_property -dict [list CONFIG.TDATA_NUM_BYTES 8 CONFIG.FIFO_DEPTH 1024 CONFIG.IS_ACLK_ASYNC 1 \
  CONFIG.HAS_TKEEP 0 CONFIG.HAS_TLAST 0] [get_bd_cells stream_fifo]
ip fft xfft
set_property -dict [list CONFIG.transform_length $FFT_LENGTH \
  CONFIG.implementation_options pipelined_streaming_io \
  CONFIG.target_clock_frequency $PL_MHZ CONFIG.target_data_throughput 65 \
  CONFIG.data_format fixed_point CONFIG.input_width 16 CONFIG.phase_factor_width 16 \
  CONFIG.scaling_options block_floating_point CONFIG.rounding_modes convergent_rounding \
  CONFIG.aresetn true CONFIG.xk_index true CONFIG.output_ordering natural_order] [get_bd_cells fft]

# Clocks and resets.
foreach p {reset_pl/slowest_sync_clk jtag_axi/aclk interconnect/ACLK interconnect/S00_ACLK \
 interconnect/M00_ACLK interconnect/M01_ACLK rfdc/s_axi_aclk control/clk processing/clk \
 spec_eng/clk loss_cdc/clk stream_fifo/m_axis_aclk fft/aclk} {
  connect_bd_net [get_bd_pins ps/pl_clk0] [get_bd_pins $p]
}
wire reset_pl/peripheral_aresetn jtag_axi/aresetn interconnect/ARESETN interconnect/S00_ARESETN \
  interconnect/M00_ARESETN interconnect/M01_ARESETN rfdc/s_axi_aresetn control/rstn \
  processing/rstn spec_eng/rstn loss_cdc/rstn fft/aresetn
wire axis_clock/clk_out1 pair/axis_clk stream_fifo/s_axis_aclk
wire reset_axis/peripheral_aresetn pair/axis_resetn stream_fifo/s_axis_aresetn

# RFDC clock domain -> coherent pair -> asynchronous FIFO -> 200 MHz PL domain.
wire rfdc/m10_axis_tdata pair/i_data
wire rfdc/m11_axis_tdata pair/q_data
wire rfdc/m10_axis_tvalid pair/i_valid
wire rfdc/m11_axis_tvalid pair/q_valid
wire pair/i_ready rfdc/m10_axis_tready
wire pair/q_ready rfdc/m11_axis_tready
wire pair/fifo_data stream_fifo/s_axis_tdata
wire pair/fifo_valid stream_fifo/s_axis_tvalid
wire stream_fifo/s_axis_tready pair/fifo_ready
wire stream_fifo/m_axis_tdata processing/sample_data
wire stream_fifo/m_axis_tvalid processing/sample_valid
wire one/dout stream_fifo/m_axis_tready
wire pair/loss loss_cdc/async_flag
wire loss_cdc/synced_flag control/stream_loss

# Image pipeline and control/status.
wire control/feature_gain processing/feature_gain
wire control/feature_mode processing/feature_mode
wire control/ddc_phase_inc processing/ddc_phase_inc
wire control/ddc_control processing/ddc_control
wire control/capture_start processing/capture_start
wire control/frame_ack processing/frame_ack
wire control/line_samples processing/line_samples
wire control/frame_lines processing/frame_lines
wire control/segment_sel processing/segment_sel
wire control/image_replay_start processing/image_replay_start
wire control/clear_error processing/clear_error spec_eng/clear_error
wire control/raw_capture_start processing/raw_capture_start
wire control/raw_replay_start processing/raw_replay_start
wire control/raw_capture_length processing/raw_capture_length
wire control/event_enable processing/event_enable
wire control/event_force processing/event_force
wire control/event_threshold processing/event_threshold
wire processing/capture_busy control/capture_busy
wire processing/frame_pending control/frame_pending
wire processing/frozen_bank control/frozen_bank
wire processing/frame_id control/frame_id
wire processing/image_replay_busy control/image_replay_busy
wire processing/image_done control/image_done
wire processing/range_error control/image_range_error
wire processing/raw_capture_busy control/raw_capture_busy
wire processing/raw_capture_pending control/raw_capture_pending
wire processing/raw_replay_busy control/raw_replay_busy
wire processing/raw_replay_done control/raw_replay_done
wire processing/raw_range_error control/raw_range_error
wire processing/raw_captured_count control/raw_captured_count
wire processing/event_busy control/event_busy
wire processing/event_decision_valid control/event_decision_valid
wire processing/event_changed control/event_changed
wire processing/event_metric_q16 control/event_metric_q16
wire processing/event_best_lag control/event_best_lag
wire processing/event_debounce_history control/event_debounce_history
wire processing/event_reference_valid control/event_reference_valid
wire processing/event_ack_copy_busy control/event_ack_copy_busy

# FFT pipeline and block-floating-point status handling.
wire processing/decim_data spec_eng/sample_data
wire processing/decim_valid spec_eng/sample_valid
wire control/spectrum_arm spec_eng/arm
wire control/spectrum_replay_start spec_eng/replay_start
wire spec_eng/busy control/spectrum_busy
wire spec_eng/done control/spectrum_done
wire spec_eng/average_count control/spectrum_average_count
wire spec_eng/overflow_error control/spectrum_overflow_error
wire spec_eng/replay_busy control/spectrum_replay_busy
wire spec_eng/replay_done control/spectrum_replay_done
wire spec_eng/fft_cfg_data fft/s_axis_config_tdata
wire spec_eng/fft_cfg_valid fft/s_axis_config_tvalid
wire fft/s_axis_config_tready spec_eng/fft_cfg_ready
wire spec_eng/fft_in_data fft/s_axis_data_tdata
wire spec_eng/fft_in_valid fft/s_axis_data_tvalid
wire spec_eng/fft_in_last fft/s_axis_data_tlast
wire fft/s_axis_data_tready spec_eng/fft_in_ready
wire fft/m_axis_data_tdata spec_eng/fft_out_data
wire fft/m_axis_data_tvalid spec_eng/fft_out_valid
wire fft/m_axis_data_tlast spec_eng/fft_out_last
wire fft/m_axis_data_tuser spec_eng/fft_out_user
wire spec_eng/fft_out_ready fft/m_axis_data_tready
wire fft/m_axis_status_tdata spec_eng/fft_status_data
wire fft/m_axis_status_tvalid spec_eng/fft_status_valid
wire spec_eng/fft_status_ready fft/m_axis_status_tready
wire fft/event_frame_started spec_eng/event_frame_started
wire fft/event_tlast_unexpected spec_eng/event_tlast_unexpected
wire fft/event_tlast_missing spec_eng/event_tlast_missing
wire fft/event_status_channel_halt spec_eng/event_status_halt
wire fft/event_data_in_channel_halt spec_eng/event_data_in_halt
wire fft/event_data_out_channel_halt spec_eng/event_data_out_halt

# ILA 0: input health. ILA 1: complete 65536-bin spectrum. ILA 2: one 128 KiB image segment.
ip raw_ila ila
set_property -dict [list CONFIG.C_MONITOR_TYPE Native CONFIG.C_NUM_OF_PROBES 3 \
  CONFIG.C_DATA_DEPTH $RAW_ILA_DEPTH CONFIG.C_PROBE0_WIDTH 64 CONFIG.C_PROBE1_WIDTH 1 CONFIG.C_PROBE2_WIDTH 1] [get_bd_cells raw_ila]
wire ps/pl_clk0 raw_ila/clk
wire stream_fifo/m_axis_tdata raw_ila/probe0
wire stream_fifo/m_axis_tvalid raw_ila/probe1
wire loss_cdc/synced_flag raw_ila/probe2

ip spectrum_ila ila
set_property -dict [list CONFIG.C_MONITOR_TYPE Native CONFIG.C_NUM_OF_PROBES 4 \
  CONFIG.C_DATA_DEPTH $SPEC_ILA_DEPTH CONFIG.C_EN_STRG_QUAL 1 \
  CONFIG.C_PROBE0_WIDTH 8 CONFIG.C_PROBE1_WIDTH 16 CONFIG.C_PROBE2_WIDTH 1 CONFIG.C_PROBE3_WIDTH 1] [get_bd_cells spectrum_ila]
wire ps/pl_clk0 spectrum_ila/clk
foreach {idx sig} {0 replay_data 1 replay_addr 2 replay_valid 3 replay_trigger} {wire spec_eng/$sig spectrum_ila/probe$idx}

ip image_ila ila
set_property -dict [list CONFIG.C_MONITOR_TYPE Native CONFIG.C_NUM_OF_PROBES 6 \
  CONFIG.C_DATA_DEPTH $IMAGE_ILA_DEPTH CONFIG.C_EN_STRG_QUAL 1 \
  CONFIG.C_PROBE0_WIDTH 8 CONFIG.C_PROBE1_WIDTH 21 CONFIG.C_PROBE2_WIDTH 1 \
  CONFIG.C_PROBE3_WIDTH 1 CONFIG.C_PROBE4_WIDTH 32 CONFIG.C_PROBE5_WIDTH 1] [get_bd_cells image_ila]
wire ps/pl_clk0 image_ila/clk
wire processing/image_data image_ila/probe0
wire processing/image_addr image_ila/probe1
wire processing/image_valid image_ila/probe2
wire processing/image_trigger image_ila/probe3
wire processing/frame_id image_ila/probe4
wire processing/frozen_bank image_ila/probe5

# ILA 3: 32768 coherent post-halfband, pre-DDC complex samples at full 16-bit precision.
ip raw_iq_ila ila
set_property -dict [list CONFIG.C_MONITOR_TYPE Native CONFIG.C_NUM_OF_PROBES 5 \
  CONFIG.C_DATA_DEPTH $RAW_IQ_ILA_DEPTH CONFIG.C_EN_STRG_QUAL 1 \
  CONFIG.C_PROBE0_WIDTH 16 CONFIG.C_PROBE1_WIDTH 16 CONFIG.C_PROBE2_WIDTH 15 \
  CONFIG.C_PROBE3_WIDTH 1 CONFIG.C_PROBE4_WIDTH 1] [get_bd_cells raw_iq_ila]
wire ps/pl_clk0 raw_iq_ila/clk
wire processing/raw_replay_i raw_iq_ila/probe0
wire processing/raw_replay_q raw_iq_ila/probe1
wire processing/raw_replay_addr raw_iq_ila/probe2
wire processing/raw_replay_valid raw_iq_ila/probe3
wire processing/raw_replay_trigger raw_iq_ila/probe4

foreach n {adc1_clk vin1_01 sysref_in} {make_bd_intf_pins_external [get_bd_intf_pins rfdc/$n]}
assign_bd_address -offset $RFDC_BASE -range 256K -target_address_space [get_bd_addr_spaces jtag_axi/Data] [get_bd_addr_segs rfdc/s_axi/Reg] -force
assign_bd_address -offset $CTRL_BASE -range 4K -target_address_space [get_bd_addr_spaces jtag_axi/Data] [get_bd_addr_segs control/S_AXI/reg0] -force
validate_bd_design
save_bd_design
set bd [get_files */${BD_NAME}.bd]
generate_target all $bd
set wrapper [make_wrapper -files $bd -top]
set_property source_mgmt_mode None [current_project]
add_files -norecurse $wrapper
set_property top ${BD_NAME}_wrapper [current_fileset]
add_files -fileset constrs_1 [file join $root constraints top.xdc]

set fh [open [file join $root output reports generated_configuration.txt] w]
puts $fh "Vivado=[version -short]\npart=$PART\nversion=$EVENT_VERSION\nadc=Tile1_ADC01\nref_mhz=$ADC_REF_MHZ\nfs_gsps=$ADC_FS_GSPS\nrfdc_decimation=$ADC_DECIMATION\ncomplex_rate_msps=[expr {$ADC_FS_GSPS*1000/$ADC_DECIMATION}]\npl_halfband_decimation=2\nimage_rate_msps=65\naxis_clock_mhz=$axis_mhz\npl_clock_mhz=$ps_mhz\nnco_mhz=$NCO_MHZ\nfft_length=$FFT_LENGTH\nfft_averages=$FFT_AVERAGES\nraw_iq_depth=$RAW_IQ_CAPTURE_DEPTH\nevent_export=row_profile_circular_shift_2of3_ack_supplement\nbuild_status=output/reports/build_status.txt"
close $fh
puts FULL_V24_PROJECT_CREATED
close_project

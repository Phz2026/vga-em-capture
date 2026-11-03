module processing_core (
  input  wire        clk,
  input  wire        rstn,
  input  wire [63:0] sample_data,
  input  wire        sample_valid,
  input  wire [15:0] feature_gain,
  input  wire [1:0]  feature_mode,
  input  wire [31:0] ddc_phase_inc,
  input  wire [1:0]  ddc_control,
  input  wire        capture_start,
  input  wire        frame_ack,
  input  wire [15:0] line_samples,
  input  wire [15:0] frame_lines,
  input  wire [7:0]  segment_sel,
  input  wire        image_replay_start,
  input  wire        clear_error,
  input  wire        event_enable,
  input  wire        event_force,
  input  wire [15:0] event_threshold,
  input  wire        raw_capture_start,
  input  wire        raw_replay_start,
  input  wire [15:0] raw_capture_length,
  output wire [31:0] decim_data,
  output wire        decim_valid,
  output wire        capture_busy,
  output wire        frame_pending,
  output wire        frozen_bank,
  output wire [31:0] frame_id,
  output wire        image_replay_busy,
  output wire [7:0]  image_data,
  output wire [20:0] image_addr,
  output wire        image_valid,
  output wire        image_trigger,
  output wire        image_done,
  output wire        range_error,
  output wire        raw_capture_busy,
  output wire        raw_capture_pending,
  output wire        raw_replay_busy,
  output wire        raw_replay_done,
  output wire        raw_range_error,
  output wire [15:0] raw_captured_count,
  output wire [15:0] raw_replay_i,
  output wire [15:0] raw_replay_q,
  output wire [14:0] raw_replay_addr,
  output wire        raw_replay_valid,
  output wire        raw_replay_trigger,
  output wire        event_busy,
  output wire        event_decision_valid,
  output wire        event_changed,
  output wire [15:0] event_metric_q16,
  output wire [15:0] event_best_lag,
  output wire [2:0]  event_debounce_history,
  output wire        event_reference_valid,
  output wire        event_ack_copy_busy
);
  wire [7:0] feature;
  wire feature_valid;
  wire [31:0] image_baseband_data;
  wire image_baseband_valid;

  halfband_decimator2 decimator (
    .clk(clk), .rstn(rstn), .in_data(sample_data), .in_valid(sample_valid),
    .out_data(decim_data), .out_valid(decim_valid)
  );
  leakage_demod image_demod (
    .clk(clk), .rstn(rstn), .complex_data(decim_data),
    .complex_valid(decim_valid), .phase_inc(ddc_phase_inc),
    .mixer_enable(ddc_control[0]), .filter_enable(ddc_control[1]),
    .baseband_data(image_baseband_data),
    .baseband_valid(image_baseband_valid)
  );
  feature_extract feature_i (
    .clk(clk), .rstn(rstn), .complex_data(image_baseband_data),
    .complex_valid(image_baseband_valid), .gain_q8(feature_gain),
    .feature_mode(feature_mode),
    .feature(feature), .feature_valid(feature_valid)
  );
  raster_frame_buffer frame_i (
    .clk(clk), .rstn(rstn), .feature(feature), .feature_valid(feature_valid),
    .capture_start(capture_start), .frame_ack(frame_ack),
    .line_samples(line_samples), .frame_lines(frame_lines),
    .segment_sel(segment_sel), .replay_start(image_replay_start),
    .clear_error(clear_error), .event_enable(event_enable), .event_force(event_force),
    .event_threshold(event_threshold),
    .capture_busy(capture_busy), .frame_pending(frame_pending),
    .frozen_bank(frozen_bank), .frame_id(frame_id),
    .replay_busy(image_replay_busy), .replay_data(image_data),
    .replay_addr(image_addr), .replay_valid(image_valid),
    .replay_trigger(image_trigger), .replay_done(image_done),
    .range_error(range_error), .event_busy(event_busy),
    .event_decision_valid(event_decision_valid), .event_changed(event_changed),
    .event_metric_q16(event_metric_q16), .event_best_lag(event_best_lag),
    .event_debounce_history(event_debounce_history),
    .event_reference_valid(event_reference_valid), .event_ack_copy_busy(event_ack_copy_busy)
  );
  raw_iq_capture raw_capture_i (
    .clk(clk), .rstn(rstn), .sample_data(decim_data), .sample_valid(decim_valid),
    .capture_start(raw_capture_start), .replay_start(raw_replay_start),
    .clear_error(clear_error), .capture_length(raw_capture_length),
    .capture_busy(raw_capture_busy), .capture_pending(raw_capture_pending),
    .replay_busy(raw_replay_busy), .replay_done(raw_replay_done),
    .range_error(raw_range_error), .captured_count(raw_captured_count),
    .replay_i(raw_replay_i), .replay_q(raw_replay_q),
    .replay_addr(raw_replay_addr), .replay_valid(raw_replay_valid),
    .replay_trigger(raw_replay_trigger)
  );
endmodule

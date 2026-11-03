`timescale 1ns/1ps

// Regression for the spectrum replay boundary.  A complete replay must emit
// every address exactly once and return replay_busy low after the final word.
module tb_spectrum_replay;
  localparam integer N = 8;
  reg clk = 1'b0;
  reg rstn = 1'b0;
  reg replay_start = 1'b0;
  wire replay_busy, replay_valid, replay_trigger, replay_done;
  wire [7:0] replay_data;
  wire [15:0] replay_addr;
  integer i;
  integer received = 0;

  always #2.5 clk = ~clk;

  spectrum_engine #(.FFT_SIZE(N), .AVERAGES(1)) dut (
    .clk(clk), .rstn(rstn),
    .sample_data(32'd0), .sample_valid(1'b0),
    .arm(1'b0), .replay_start(replay_start), .clear_error(1'b0),
    .busy(), .done(), .average_count(), .overflow_error(),
    .fft_cfg_data(), .fft_cfg_valid(), .fft_cfg_ready(1'b0),
    .fft_in_data(), .fft_in_valid(), .fft_in_last(), .fft_in_ready(1'b1),
    .fft_out_data(32'd0), .fft_out_valid(1'b0), .fft_out_last(1'b0),
    .fft_out_user(24'd0), .fft_out_ready(),
    .fft_status_data(8'd0), .fft_status_valid(1'b0), .fft_status_ready(),
    .event_frame_started(1'b0), .event_tlast_unexpected(1'b0),
    .event_tlast_missing(1'b0), .event_status_halt(1'b0),
    .event_data_in_halt(1'b0), .event_data_out_halt(1'b0),
    .replay_busy(replay_busy), .replay_data(replay_data),
    .replay_addr(replay_addr), .replay_valid(replay_valid),
    .replay_trigger(replay_trigger), .replay_done(replay_done)
  );

  initial begin
    repeat (3) @(posedge clk);
    rstn = 1'b1;
    for (i=0; i<N; i=i+1) dut.spectrum_mem[i] = i + 8'h20;
    // done is sticky in ST_IDLE, so a deposit is sufficient for this isolated
    // replay test without running the FFT datapath.
    dut.done = 1'b1;
    @(posedge clk); replay_start = 1'b1;
    @(posedge clk); replay_start = 1'b0;

    while (!replay_done) begin
      @(posedge clk); #1;
      if (replay_valid) begin
        if (replay_addr !== received[15:0])
          $fatal(1, "address mismatch: got %0d expected %0d", replay_addr, received);
        if (replay_data !== (received + 8'h20))
          $fatal(1, "data mismatch at %0d", received);
        if ((received == 0) != replay_trigger)
          $fatal(1, "trigger mismatch at %0d", received);
        received = received + 1;
      end
    end
    if (received != N) $fatal(1, "replay emitted %0d of %0d words", received, N);
    if (replay_busy) $fatal(1, "replay_busy remained asserted");
    $display("SPECTRUM_REPLAY_TEST_PASS words=%0d", received);
    $finish;
  end

  initial begin
    #1000 $fatal(1, "timeout");
  end
endmodule

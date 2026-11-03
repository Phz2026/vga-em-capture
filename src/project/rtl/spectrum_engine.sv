// Snapshot spectrum engine for the 65 MSPS complex stream.
// Four 65536-point FFT frames are block-float aligned and power-averaged.
// The final 8-bit log spectrum is replayed to an ILA on command.
module spectrum_engine #(
  parameter integer FFT_SIZE = 65536,
  parameter integer AVERAGES = 4
) (
  input  wire        clk,
  input  wire        rstn,
  input  wire [31:0] sample_data,
  input  wire        sample_valid,
  input  wire        arm,
  input  wire        replay_start,
  input  wire        clear_error,
  output reg         busy = 1'b0,
  output reg         done = 1'b0,
  output reg  [2:0]  average_count = 3'd0,
  output reg         overflow_error = 1'b0,

  output reg  [7:0]  fft_cfg_data = 8'h01,
  output reg         fft_cfg_valid = 1'b0,
  input  wire        fft_cfg_ready,
  output wire [31:0] fft_in_data,
  output wire        fft_in_valid,
  output wire        fft_in_last,
  input  wire        fft_in_ready,
  input  wire [31:0] fft_out_data,
  input  wire        fft_out_valid,
  input  wire        fft_out_last,
  input  wire [23:0] fft_out_user,
  output wire        fft_out_ready,
  input  wire [7:0]  fft_status_data,
  input  wire        fft_status_valid,
  output wire        fft_status_ready,
  input  wire        event_frame_started,
  input  wire        event_tlast_unexpected,
  input  wire        event_tlast_missing,
  input  wire        event_status_halt,
  input  wire        event_data_in_halt,
  input  wire        event_data_out_halt,

  output reg         replay_busy = 1'b0,
  output reg  [7:0]  replay_data = 8'd0,
  output reg  [15:0] replay_addr = 16'd0,
  output reg         replay_valid = 1'b0,
  output reg         replay_trigger = 1'b0,
  output reg         replay_done = 1'b0
);
  // Keep the memory read, block-exponent alignment, accumulation and
  // logarithmic compression in separate cycles.  The first implementation
  // put all four operations on one 200 MHz path and missed timing.
  localparam [3:0] ST_IDLE=0, ST_CONFIG=1, ST_FEED=2,
                   ST_WAIT=3, ST_READ=4, ST_SHIFT=5, ST_ALIGN=6,
                   ST_SUM=7, ST_LOG=8, ST_WRITE=9;
  reg [3:0] state = ST_IDLE;
  reg [15:0] input_count = 0;
  reg [16:0] output_count = 0;
  reg output_last_seen = 0;
  reg status_seen = 0;
  reg [4:0] block_exp = 0;
  reg [15:0] process_index = 0;
  reg [31:0] temp_rd = 0;
  reg [39:0] accum_rd = 0;
  reg [63:0] shifted_power = 0;
  reg [39:0] normalized_power = 0;
  reg [39:0] base_accum = 0;
  reg [40:0] power_sum = 0;
  reg [7:0] compressed_power = 0;

  // Two-stage FFT power pipeline.  Explicit registers allow the two
  // multipliers and their adder to use the DSP48 pipeline at 200 MHz.
  reg [31:0] re_square = 0, im_square = 0;
  reg [31:0] bin_power_pipe = 0;
  reg [15:0] fft_index_d0 = 0, fft_index_d1 = 0;
  reg fft_valid_d0 = 0, fft_valid_d1 = 0;
  reg fft_last_d0 = 0, fft_last_d1 = 0;

  (* ram_style = "block" *) reg [31:0] temp_power [0:FFT_SIZE-1];
  (* ram_style = "block" *) reg [39:0] accum_power [0:FFT_SIZE-1];
  (* ram_style = "block" *) reg [7:0] spectrum_mem [0:FFT_SIZE-1];

  reg [15:0] replay_issue = 0;
  reg replay_issuing = 1'b0;
  reg replay_read_valid = 1'b0;
  reg [15:0] replay_addr_d0=0;
  reg [7:0] replay_rd = 0;

  wire signed [15:0] fft_re = fft_out_data[15:0];
  wire signed [15:0] fft_im = fft_out_data[31:16];
  wire [15:0] fft_index = fft_out_user[15:0];
  // The XFFT halt indicators are throughput diagnostics.  This snapshot
  // engine deliberately pauses its input while it post-processes each frame,
  // so event_data_in_halt is expected and must not be reported as corruption.
  // TLAST errors and an actual input-ready violation are the functional faults.
  wire fft_error_event = event_tlast_unexpected | event_tlast_missing;

  assign fft_in_data = sample_data;
  assign fft_in_valid = (state == ST_FEED) && sample_valid;
  assign fft_in_last = (input_count == FFT_SIZE-1) && fft_in_valid;
  assign fft_out_ready = 1'b1;
  assign fft_status_ready = 1'b1;

  function automatic [7:0] log_compress(input [40:0] value);
    integer k;
    reg [7:0] result;
    begin
      result = 0;
      for (k=0; k<41; k=k+1)
        if (value[k]) result = k * 6;
      log_compress = result;
    end
  endfunction

  always @(posedge clk) begin
    if (!rstn) begin
      state<=ST_IDLE; busy<=0; done<=0; average_count<=0;
      overflow_error<=0; fft_cfg_valid<=0; input_count<=0;
      output_count<=0; output_last_seen<=0; status_seen<=0;
      replay_busy<=0; replay_valid<=0; replay_trigger<=0; replay_done<=0;
      replay_issue<=0; replay_issuing<=0; replay_read_valid<=0;
      fft_valid_d0<=0; fft_valid_d1<=0; fft_last_d0<=0; fft_last_d1<=0;
    end else begin
      replay_valid<=0; replay_trigger<=0; replay_done<=0;
      if (clear_error) overflow_error<=0;
      if (fft_error_event && busy) overflow_error<=1;

      fft_valid_d0 <= fft_out_valid && busy;
      fft_valid_d1 <= fft_valid_d0;
      if (fft_out_valid && busy) begin
        re_square <= $signed(fft_re) * $signed(fft_re);
        im_square <= $signed(fft_im) * $signed(fft_im);
        fft_index_d0 <= fft_index;
        fft_last_d0 <= fft_out_last;
      end
      if (fft_valid_d0) begin
        bin_power_pipe <= re_square + im_square;
        fft_index_d1 <= fft_index_d0;
        fft_last_d1 <= fft_last_d0;
      end
      if (fft_valid_d1) begin
        temp_power[fft_index_d1] <= bin_power_pipe;
        output_count <= output_count + 1;
        if (fft_last_d1) output_last_seen <= 1'b1;
      end
      if (fft_status_valid && busy) begin
        block_exp <= fft_status_data[4:0];
        status_seen <= 1'b1;
      end

      case (state)
        ST_IDLE: begin
          fft_cfg_valid<=0; busy<=0;
          if (arm) begin
            done<=0; busy<=1; average_count<=0;
            input_count<=0; output_count<=0;
            output_last_seen<=0; status_seen<=0;
            fft_cfg_valid<=1; state<=ST_CONFIG;
          end
        end
        ST_CONFIG: if (fft_cfg_valid && fft_cfg_ready) begin
          fft_cfg_valid<=0; input_count<=0; state<=ST_FEED;
        end
        ST_FEED: if (sample_valid) begin
          if (!fft_in_ready) begin overflow_error<=1; busy<=0; state<=ST_IDLE; end
          else if (input_count == FFT_SIZE-1) begin input_count<=0; state<=ST_WAIT; end
          else input_count<=input_count+1;
        end
        ST_WAIT: if (output_last_seen && status_seen && output_count == FFT_SIZE) begin
          process_index<=0; state<=ST_READ;
        end
        ST_READ: begin
          temp_rd <= temp_power[process_index];
          accum_rd <= accum_power[process_index];
          state <= ST_SHIFT;
        end
        ST_SHIFT: begin
          shifted_power <= {32'd0,temp_rd} << {block_exp,1'b0};
          base_accum <= (average_count == 0) ? 40'd0 : accum_rd;
          state <= ST_ALIGN;
        end
        ST_ALIGN: begin
          normalized_power <= (|shifted_power[63:40]) ?
                              40'hffffffffff : shifted_power[39:0];
          state <= ST_SUM;
        end
        ST_SUM: begin
          power_sum <= {1'b0,base_accum} + {1'b0,normalized_power};
          state <= ST_LOG;
        end
        ST_LOG: begin
          compressed_power <= log_compress(power_sum);
          state <= ST_WRITE;
        end
        ST_WRITE: begin
          if (average_count == AVERAGES-1)
            spectrum_mem[process_index] <= compressed_power;
          else
            accum_power[process_index] <= power_sum[39:0];
          if (process_index == FFT_SIZE-1) begin
            if (average_count == AVERAGES-1) begin
              average_count<=AVERAGES; busy<=0; done<=1; state<=ST_IDLE;
            end else begin
              average_count<=average_count+1; output_count<=0;
              output_last_seen<=0; status_seen<=0; input_count<=0;
              fft_cfg_valid<=1; state<=ST_CONFIG;
            end
          end else begin process_index<=process_index+1; state<=ST_READ; end
        end
        default: state<=ST_IDLE;
      endcase

      if (replay_start && !replay_busy && done) begin
        replay_busy<=1; replay_issue<=0;
        replay_issuing<=1; replay_read_valid<=0;
      end else if (replay_busy) begin
        // spectrum_mem has one registered read cycle.  Track issuance and the
        // pending read explicitly so address 65535 is emitted before stopping.
        // The old two-bit shift pipeline dropped that final sample, leaving a
        // 65536-deep ILA permanently one qualified sample short.
        if (replay_read_valid) begin
          replay_data<=replay_rd; replay_addr<=replay_addr_d0; replay_valid<=1;
          if (replay_addr_d0==0) replay_trigger<=1;
          if (replay_addr_d0==FFT_SIZE-1) begin
            replay_busy<=0; replay_done<=1; replay_read_valid<=0;
          end
        end
        if (replay_issuing) begin
          replay_rd <= spectrum_mem[replay_issue];
          replay_addr_d0 <= replay_issue;
          replay_read_valid <= 1'b1;
          if (replay_issue == FFT_SIZE-1) replay_issuing<=0;
          else replay_issue <= replay_issue+1;
        end
      end else begin
        replay_issuing<=0; replay_read_valid<=0;
      end
    end
  end
endmodule

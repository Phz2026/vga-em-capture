// V2.1 event detector.
//
// Each completed frame contributes one row-energy profile.  The profile is
// compared against the last acknowledged frame with a circular row shift and
// a gain-invariant cross-product metric:
//
//   d(k) = sum(abs(Pnew(i)*Sref - Pref(i+k)*Snew))
//   metric = dmin/(2*Sref*Snew), reported as Q16.
//
// The profile memories are deliberately separate from the pixel URAM.  They
// are small (1024 x 24 bits per bank plus one reference profile) and let the
// host export a frozen bank while the other bank continues to be filled.
module frame_event_detector #(
  parameter integer MAX_LINES = 1024
) (
  input  wire        clk,
  input  wire        rstn,
  input  wire        event_enable,
  input  wire        force_export,
  input  wire [15:0] threshold_q16,
  input  wire [15:0] frame_lines,
  input  wire        frame_start,
  input  wire        frame_start_bank,
  input  wire        profile_we,
  input  wire        profile_bank,
  input  wire [9:0]  profile_index,
  input  wire [23:0] profile_value,
  input  wire        frame_done,
  input  wire        completed_bank,
  input  wire [31:0] completed_sum,
  input  wire        frame_ack,
  input  wire        frozen_bank,
  output reg         busy = 1'b0,
  output reg         decision_valid = 1'b0,
  output reg         changed = 1'b0,
  output reg [15:0]  metric_q16 = 16'hffff,
  output reg [15:0]  best_lag = 16'd0,
  output reg [2:0]   debounce_history = 3'd0,
  output reg         reference_valid = 1'b0,
  output reg         ack_copy_busy = 1'b0
);
  localparam [2:0] ST_IDLE=3'd0, ST_FETCH=3'd1, ST_ISSUE=3'd2,
                   ST_FLUSH=3'd3, ST_DIVIDE=3'd4, ST_COPY=3'd5;
  reg [2:0] state = ST_IDLE;

  (* ram_style = "distributed" *) reg [23:0] profile0 [0:MAX_LINES-1];
  (* ram_style = "distributed" *) reg [23:0] profile1 [0:MAX_LINES-1];
  (* ram_style = "distributed" *) reg [23:0] reference_profile [0:MAX_LINES-1];
  reg [31:0] bank_sum0 = 0, bank_sum1 = 0, reference_sum = 0;

  reg [10:0] active_lines = 11'd900;
  reg        eval_bank = 1'b0;
  reg [31:0] eval_sum = 0;
  reg [15:0] lag = 0;
  reg [15:0] row = 0;
  reg [63:0] lag_accum = 0;
  reg [63:0] best_diff = 64'hffff_ffff_ffff_ffff;
  reg [15:0] best_lag_r = 0;
  reg [9:0] ref_row_addr = 0;
  reg [63:0] product_new = 0, product_ref = 0;
  reg        product_valid = 1'b0;
  reg        force_pending = 1'b0;
  reg        ack_pending = 1'b0;
  reg        copy_bank = 1'b0;
  reg [10:0] copy_index = 0;
  reg [79:0] divide_remainder = 0;
  reg [63:0] divide_denominator = 0;
  reg [4:0]  divide_bit = 0;
  reg [15:0] divide_result = 0;

  wire [10:0] lines_clamped = (frame_lines == 0) ? 11'd1 :
                               (frame_lines > MAX_LINES) ? MAX_LINES[10:0] : frame_lines[10:0];
  wire [23:0] current_new = eval_bank ? profile1[row[9:0]] : profile0[row[9:0]];
  wire [15:0] ref_row = ((row + lag) >= active_lines) ?
                        (row + lag - active_lines) : (row + lag);
  wire [23:0] current_ref = reference_profile[ref_row_addr];
  wire [63:0] diff_product = (product_new >= product_ref) ?
                              (product_new - product_ref) : (product_ref - product_new);
  wire [63:0] lag_total = lag_accum + diff_product;
  wire [63:0] chosen_best = (lag_total < best_diff) ? lag_total : best_diff;
  wire [79:0] divide_trial = ({16'd0, divide_denominator} << divide_bit);
  // Include the current metric hit together with the two previous decisions.
  // A changed event is asserted only when at least two of those three hits
  // exceed the configured threshold.
  wire metric_hit_hi = ((divide_result | 16'h0001) > threshold_q16);
  wire metric_hit_lo = (divide_result > threshold_q16);
  wire [2:0] history_next_hi = {debounce_history[1:0], metric_hit_hi};
  wire [2:0] history_next_lo = {debounce_history[1:0], metric_hit_lo};
  wire [1:0] history_count_hi = {1'b0,history_next_hi[0]} +
                                 {1'b0,history_next_hi[1]} +
                                 {1'b0,history_next_hi[2]};
  wire [1:0] history_count_lo = {1'b0,history_next_lo[0]} +
                                 {1'b0,history_next_lo[1]} +
                                 {1'b0,history_next_lo[2]};

  always @(posedge clk) begin
    if (!rstn) begin
      state <= ST_IDLE;
      busy <= 1'b0; decision_valid <= 1'b0; changed <= 1'b0;
      metric_q16 <= 16'hffff; best_lag <= 0; debounce_history <= 0;
      reference_valid <= 1'b0; ack_copy_busy <= 1'b0;
      bank_sum0 <= 0; bank_sum1 <= 0; reference_sum <= 0;
      force_pending <= 1'b0; ack_pending <= 1'b0; product_valid <= 1'b0;
    end else begin
      decision_valid <= 1'b0;
      changed <= 1'b0;

      if (force_export) force_pending <= 1'b1;
      if (frame_ack) begin
        ack_pending <= 1'b1;
        copy_bank <= frozen_bank;
      end
      if (frame_start) begin
        if (frame_start_bank) bank_sum1 <= 0;
        else bank_sum0 <= 0;
      end
      if (profile_we) begin
        if (profile_bank) begin
          profile1[profile_index] <= profile_value;
          bank_sum1 <= bank_sum1 + profile_value;
        end else begin
          profile0[profile_index] <= profile_value;
          bank_sum0 <= bank_sum0 + profile_value;
        end
      end
      if (frame_done) begin
        if (completed_bank) bank_sum1 <= completed_sum;
        else bank_sum0 <= completed_sum;
        if (event_enable && state == ST_IDLE && !ack_pending) begin
          eval_bank <= completed_bank;
          eval_sum <= completed_sum;
          active_lines <= lines_clamped;
          force_pending <= 1'b0;
          if (!reference_valid || force_pending || force_export) begin
            metric_q16 <= 16'hffff;
            best_lag <= 0;
            decision_valid <= 1'b1;
            changed <= 1'b1;
          end else begin
            lag <= 0; row <= 0; lag_accum <= 0;
            best_diff <= 64'hffff_ffff_ffff_ffff;
            best_lag_r <= 0; product_valid <= 1'b0;
            state <= ST_FETCH; busy <= 1'b1;
          end
        end
      end

      case (state)
        ST_IDLE: begin
          // Keep capture blocked from the ACK edge through the reference
          // profile copy.  Otherwise the old frozen bank can be reused one
          // cycle before ST_COPY becomes visible to the frame buffer.
          busy <= ack_pending || frame_ack;
          ack_copy_busy <= 1'b0;
          if (ack_pending) begin
            ack_pending <= 1'b0;
            copy_index <= 0;
            state <= ST_COPY;
            busy <= 1'b1;
            ack_copy_busy <= 1'b1;
          end
        end
        ST_FETCH: begin
          // Isolate the circular-address arithmetic from the profile read
          // and DSP multiply; this was the worst 200 MHz routed path.
          ref_row_addr <= ref_row[9:0];
          state <= ST_ISSUE;
        end
        ST_ISSUE: begin
          // The previous product is accumulated while the next pair is
          // issued.  ST_FETCH inserts one address stage per row.
          if (product_valid) lag_accum <= lag_accum + diff_product;
          product_new <= current_new * reference_sum;
          product_ref <= current_ref * eval_sum;
          product_valid <= 1'b1;
          if ((row + 1) >= active_lines) begin
            state <= ST_FLUSH;
          end else begin
            row <= row + 1'b1;
            state <= ST_FETCH;
          end
        end
        ST_FLUSH: begin
          // Consume the final product for this lag, then either start the
          // next lag or turn the minimum into a Q16 metric.
          if (chosen_best < best_diff) begin
            best_diff <= chosen_best;
            best_lag_r <= lag;
          end
          if ((lag + 1) >= active_lines) begin
            divide_remainder <= ({16'd0, chosen_best} << 16);
            divide_denominator <= (reference_sum * eval_sum) << 1;
            divide_bit <= 15;
            divide_result <= 0;
            state <= ST_DIVIDE;
          end else begin
            lag <= lag + 1'b1;
            row <= 0;
            lag_accum <= 0;
            product_valid <= 1'b0;
            state <= ST_FETCH;
          end
        end
        ST_DIVIDE: begin
          if (divide_denominator == 0) begin
            // Both dark profiles are equal; one dark and one nonzero profile
            // is a change, still subject to the same 2-of-3 debounce.
            metric_q16 <= (reference_sum == 0 && eval_sum == 0) ? 16'd0 : 16'hffff;
            best_lag <= best_lag_r;
            decision_valid <= 1'b1;
            debounce_history <= {debounce_history[1:0],
                                 !(reference_sum == 0 && eval_sum == 0)};
            changed <= (({1'b0,debounce_history[0]} +
                         {1'b0,debounce_history[1]} +
                         {1'b0,!(reference_sum == 0 && eval_sum == 0)}) >= 2);
            state <= ST_IDLE;
            busy <= 1'b0;
          end else if (divide_remainder >= divide_trial) begin
            divide_remainder <= divide_remainder - divide_trial;
            divide_result[divide_bit] <= 1'b1;
            if (divide_bit == 0) begin
              metric_q16 <= divide_result | 16'h0001;
              best_lag <= best_lag_r;
              decision_valid <= 1'b1;
              changed <= (history_count_hi >= 2);
              debounce_history <= history_next_hi;
              state <= ST_IDLE; busy <= 1'b0;
            end else divide_bit <= divide_bit - 1'b1;
          end else if (divide_bit == 0) begin
            metric_q16 <= divide_result;
            best_lag <= best_lag_r;
            decision_valid <= 1'b1;
            changed <= (history_count_lo >= 2);
            debounce_history <= history_next_lo;
            state <= ST_IDLE; busy <= 1'b0;
          end else divide_bit <= divide_bit - 1'b1;
        end
        ST_COPY: begin
          if (copy_bank) reference_profile[copy_index] <= profile1[copy_index];
          else reference_profile[copy_index] <= profile0[copy_index];
          if (copy_index + 1 >= active_lines) begin
            reference_sum <= copy_bank ? bank_sum1 : bank_sum0;
            reference_valid <= 1'b1;
            state <= ST_IDLE;
            busy <= 1'b0;
            ack_copy_busy <= 1'b0;
          end else copy_index <= copy_index + 1'b1;
        end
        default: state <= ST_IDLE;
      endcase
    end
  end
endmodule

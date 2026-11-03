// Selectable 8-bit complex feature and Q8 programmable gain.
// mode 0: magnitude; mode 1: signed I; mode 2: signed Q;
// mode 3: I/Q interleaved from the same complex sample, I first.
module feature_extract (
  input  wire        clk,
  input  wire        rstn,
  input  wire [31:0] complex_data,
  input  wire        complex_valid,
  input  wire [15:0] gain_q8,
  input  wire [1:0]  feature_mode,
  output reg  [7:0]  feature = 8'd0,
  output reg         feature_valid = 1'b0
);
  wire signed [15:0] i_s = complex_data[15:0];
  wire signed [15:0] q_s = complex_data[31:16];
  wire [16:0] abs_i = i_s[15] ? (~{i_s[15],i_s}+17'd1) : {1'b0,i_s};
  wire [16:0] abs_q = q_s[15] ? (~{q_s[15],q_s}+17'd1) : {1'b0,q_s};
  wire [16:0] hi = (abs_i >= abs_q) ? abs_i : abs_q;
  wire [16:0] lo = (abs_i >= abs_q) ? abs_q : abs_i;
  wire [17:0] mag = hi + (lo >> 1);
  wire signed [16:0] gain_s = {1'b0,gain_q8};

  // Register multiplier outputs.  This breaks the RFDC/demod-to-feature
  // combinational path at the DSP output and leaves only rounding/saturation
  // between pipeline stages.
  reg [33:0] scaled_r = 34'd0;
  reg signed [32:0] i_product_r = 33'sd0;
  reg signed [32:0] q_product_r = 33'sd0;
  reg [1:0] mode_r = 2'd0;
  reg product_valid_r = 1'b0;

  // The input supplies at most 65 M complex samples/s in a 200 MHz clock
  // domain.  A small byte FIFO serializes mode-3 samples as I,Q without
  // pairing components from adjacent samples or depending on free-running
  // phase.  Depth 32 also absorbs short AXI-valid bursts.
  localparam integer FIFO_DEPTH = 32;
  reg [7:0] byte_fifo [0:FIFO_DEPTH-1];
  reg [4:0] fifo_wr = 0, fifo_rd = 0;
  reg [5:0] fifo_count = 0;
  wire fifo_pop = (fifo_count != 0);
  wire [1:0] enqueue_count = product_valid_r ? ((mode_r==2'd3) ? 2 : 1) : 0;
  wire [6:0] count_after = fifo_count - (fifo_pop ? 1 : 0) + enqueue_count;

  // gain_q8 is unsigned Q8 (1.0 == 16'h0100), so remove eight
  // fractional bits after the registered multiply.
  wire [25:0] level_r = scaled_r >> 8;
  wire signed [32:0] i_level_r = i_product_r >>> 8;
  wire signed [32:0] q_level_r = q_product_r >>> 8;

  function automatic [7:0] signed_to_offset8(input signed [32:0] value);
    begin
      if (value > 33'sd127)
        signed_to_offset8 = 8'hff;
      else if (value < -33'sd128)
        signed_to_offset8 = 8'h00;
      else
        signed_to_offset8 = value[7:0] + 8'd128;
    end
  endfunction

  always @(posedge clk) begin
    if (!rstn) begin
      feature <= 8'd0;
      feature_valid <= 1'b0;
      scaled_r <= 34'd0;
      i_product_r <= 33'sd0;
      q_product_r <= 33'sd0;
      mode_r <= 2'd0;
      product_valid_r <= 1'b0;
      fifo_wr <= 0;
      fifo_rd <= 0;
      fifo_count <= 0;
    end else begin
      product_valid_r <= complex_valid;
      if (complex_valid) begin
        scaled_r <= mag * gain_q8;
        i_product_r <= i_s * gain_s;
        q_product_r <= q_s * gain_s;
        mode_r <= feature_mode;
      end

      feature_valid <= fifo_pop;
      if (fifo_pop) begin
        feature <= byte_fifo[fifo_rd];
        fifo_rd <= fifo_rd + 1'b1;
      end

      if (product_valid_r && count_after <= FIFO_DEPTH) begin
        case (mode_r)
          2'd1: byte_fifo[fifo_wr] <= signed_to_offset8(i_level_r);
          2'd2: byte_fifo[fifo_wr] <= signed_to_offset8(q_level_r);
          2'd3: begin
            byte_fifo[fifo_wr] <= signed_to_offset8(i_level_r);
            byte_fifo[fifo_wr+1'b1] <= signed_to_offset8(q_level_r);
          end
          default: byte_fifo[fifo_wr] <= (level_r > 26'd255) ? 8'hff : level_r[7:0];
        endcase
        fifo_wr <= fifo_wr + enqueue_count;
      end
      fifo_count <= (count_after <= FIFO_DEPTH) ? count_after[5:0] : fifo_count - (fifo_pop ? 1'b1 : 1'b0);
    end
  end
endmodule

// Pair both RFDC output ports. The physical format is preserved verbatim.
module rfdc_pair_capture (
  input  wire        axis_clk,
  input  wire        axis_resetn,
  input  wire [31:0] i_data,
  input  wire [31:0] q_data,
  input  wire        i_valid,
  input  wire        q_valid,
  output wire        i_ready,
  output wire        q_ready,
  output wire [63:0] fifo_data,
  output wire        fifo_valid,
  input  wire        fifo_ready,
  output reg         loss = 1'b0
);
  assign i_ready    = 1'b1;
  assign q_ready    = 1'b1;
  assign fifo_data  = {q_data, i_data};
  assign fifo_valid = i_valid && q_valid;

  always @(posedge axis_clk) begin
    if (!axis_resetn)
      loss <= 1'b0;
    else if ((i_valid != q_valid) || (fifo_valid && !fifo_ready))
      loss <= 1'b1;
  end
endmodule

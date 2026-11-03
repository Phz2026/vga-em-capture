// Seven-tap symmetric low-pass followed by decimation by two.
// Input beat layout: {Q1,Q0,I1,I0}; the two samples are chronological.
// Coefficients [-4,0,36,64,36,0,-4] / 128 give unity DC gain.
module halfband_decimator2 (
  input  wire        clk,
  input  wire        rstn,
  input  wire [63:0] in_data,
  input  wire        in_valid,
  output reg  [31:0] out_data = 32'd0,
  output reg         out_valid = 1'b0
);
  wire signed [15:0] i0 = in_data[15:0];
  wire signed [15:0] i1 = in_data[31:16];
  wire signed [15:0] q0 = in_data[47:32];
  wire signed [15:0] q1 = in_data[63:48];

  reg signed [15:0] id0=0,id1=0,id2=0,id3=0,id4=0;
  reg signed [15:0] qd0=0,qd1=0,qd2=0,qd3=0,qd4=0;
  reg signed [23:0] acc_i;
  reg signed [23:0] acc_q;
  reg signed [23:0] acc_i_r=0, acc_q_r=0;
  reg acc_valid_r=0;

  function automatic signed [15:0] sat16(input signed [23:0] value);
    reg signed [23:0] rounded;
    begin
      rounded = value + 24'sd64;
      if (rounded > 24'sd4194239)       sat16 = 16'sh7fff;
      else if (rounded < -24'sd4194304) sat16 = 16'sh8000;
      else                              sat16 = rounded >>> 7;
    end
  endfunction

  // Multiplication is written explicitly so the expression is widened before
  // the additions.  Shifting a 16-bit value first would truncate in Verilog.
  always @* begin
    acc_i = -($signed(id0) * 24'sd4) + ($signed(id2) * 24'sd36) +
             ($signed(id3) * 24'sd64) + ($signed(id4) * 24'sd36) -
             ($signed(i1)  * 24'sd4);
    acc_q = -($signed(qd0) * 24'sd4) + ($signed(qd2) * 24'sd36) +
             ($signed(qd3) * 24'sd64) + ($signed(qd4) * 24'sd36) -
             ($signed(q1)  * 24'sd4);
  end

  always @(posedge clk) begin
    if (!rstn) begin
      id0<=0; id1<=0; id2<=0; id3<=0; id4<=0;
      qd0<=0; qd1<=0; qd2<=0; qd3<=0; qd4<=0;
      acc_i_r<=0; acc_q_r<=0; acc_valid_r<=0;
      out_data<=0; out_valid<=0;
    end else begin
      // Register the five-tap sum before rounding and saturation.  This
      // breaks the former DSP-output-to-saturation path at 200 MHz while
      // preserving the valid pulse and chronological sample order.
      out_valid <= acc_valid_r;
      if (acc_valid_r) out_data <= {sat16(acc_q_r), sat16(acc_i_r)};
      acc_valid_r <= in_valid;
      if (in_valid) begin
        acc_i_r <= acc_i;
        acc_q_r <= acc_q;
        id0<=id2; id1<=id3; id2<=id4; id3<=i0; id4<=i1;
        qd0<=qd2; qd1<=qd3; qd2<=qd4; qd3<=q0; qd4<=q1;
      end
    end
  end
endmodule

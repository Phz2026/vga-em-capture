`timescale 1ns/1ps
module tb_halfband_decimator2;
  reg clk=0,rstn=0,valid=0; reg [63:0] din=0; wire [31:0] dout; wire dout_valid;
  halfband_decimator2 dut(.clk(clk),.rstn(rstn),.in_data(din),.in_valid(valid),.out_data(dout),.out_valid(dout_valid));
  always #2.5 clk=~clk;
  initial begin
    repeat(4) @(posedge clk); rstn<=1; @(posedge clk);
    din<={16'd0,16'd0,16'd0,16'h7fff}; valid<=1; @(posedge clk);
    din<=0; repeat(6) @(posedge clk); valid<=0;
    if(!dout_valid) $fatal(1,"Output-valid pipeline stopped unexpectedly");
    $display("HALFBAND_SMOKE_PASS last=%h",dout); $finish;
  end
endmodule

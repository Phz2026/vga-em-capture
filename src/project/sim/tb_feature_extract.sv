`timescale 1ns/1ps
module tb_feature_extract;
  reg clk=0, rstn=0;
  reg [31:0] complex_data=0;
  reg complex_valid=0;
  reg [15:0] gain_q8=16'h0100;
  reg [1:0] feature_mode=0;
  wire [7:0] feature;
  wire feature_valid;

  feature_extract dut (
    .clk(clk), .rstn(rstn), .complex_data(complex_data),
    .complex_valid(complex_valid), .gain_q8(gain_q8),
    .feature_mode(feature_mode),
    .feature(feature), .feature_valid(feature_valid)
  );
  always #5 clk=~clk;

  task automatic push_sample(
    input signed [15:0] i,
    input signed [15:0] q,
    input [15:0] gain,
    input [1:0] mode
  );
    begin
      @(negedge clk); complex_data={q,i}; gain_q8=gain; feature_mode=mode; complex_valid=1;
      @(negedge clk); complex_valid=0;
    end
  endtask

  task automatic expect_byte(
    input [7:0] expected
  );
    integer timeout;
    begin
      timeout=0;
      while (!feature_valid && timeout<12) begin @(posedge clk); #1; timeout=timeout+1; end
      if (!feature_valid || feature !== expected)
        $fatal(1,"feature mismatch: got=%0d expected=%0d",feature,expected);
      @(posedge clk); #1;
    end
  endtask

  initial begin
    repeat(3) @(posedge clk);
    rstn=1;
    push_sample(16'sd100,16'sd0,16'h0100,2'd0); expect_byte(8'd100);
    push_sample(16'sd100,16'sd0,16'h0080,2'd0); expect_byte(8'd50);
    push_sample(16'sd100,16'sd0,16'h0200,2'd0); expect_byte(8'd200);
    push_sample(16'sd200,16'sd0,16'h0200,2'd0); expect_byte(8'd255);
    push_sample(-16'sd80,16'sd40,16'h0100,2'd0); expect_byte(8'd100);
    push_sample(16'sd20,-16'sd30,16'h0100,2'd1); expect_byte(8'd148);
    push_sample(16'sd20,-16'sd30,16'h0100,2'd2); expect_byte(8'd98);
    push_sample(16'sd20,-16'sd30,16'h0100,2'd3); expect_byte(8'd148); expect_byte(8'd98);
    push_sample(16'sd200,16'sd0,16'h0100,2'd1); expect_byte(8'd255);
    push_sample(-16'sd200,16'sd0,16'h0100,2'd1); expect_byte(8'd0);
    $display("FEATURE_EXTRACT_SIM_PASS");
    $finish;
  end
endmodule

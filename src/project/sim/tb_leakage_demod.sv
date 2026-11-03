`timescale 1ns/1ps
module tb_leakage_demod;
  reg clk=0, rstn=0;
  reg [31:0] complex_data=0;
  reg complex_valid=0;
  reg [31:0] phase_inc=32'h13B13B14;
  reg mixer_enable=1;
  reg filter_enable=1;
  wire [31:0] baseband_data;
  wire baseband_valid;
  leakage_demod dut(.*);
  always #2.5 clk=~clk;

  function automatic signed [15:0] cos13(input integer p);
    case(p)
      0:cos13=32767;1:cos13=29014;2:cos13=18614;3:cos13=3950;
      4:cos13=-11619;5:cos13=-24526;6:cos13=-31815;7:cos13=-31815;
      8:cos13=-24526;9:cos13=-11619;10:cos13=3950;11:cos13=18614;
      default:cos13=29014;
    endcase
  endfunction
  function automatic signed [15:0] sin13(input integer p);
    case(p)
      0:sin13=0;1:sin13=15228;2:sin13=26967;3:sin13=32528;
      4:sin13=30638;5:sin13=21729;6:sin13=7842;7:sin13=-7842;
      8:sin13=-21729;9:sin13=-30638;10:sin13=-32528;11:sin13=-26967;
      default:sin13=-15228;
    endcase
  endfunction

  integer n, samples=0;
  integer signed i_sample, q_sample, i_out, q_out;
  integer signed sum_i=0, sum_abs_q=0;
  always @(posedge clk) if(baseband_valid && samples>=80) begin
    i_out=$signed(baseband_data[15:0]);
    q_out=$signed(baseband_data[31:16]);
    sum_i=sum_i+i_out;
    sum_abs_q=sum_abs_q+((q_out<0)?-q_out:q_out);
  end
  always @(posedge clk) if(baseband_valid) samples=samples+1;

  initial begin
    repeat(8) @(posedge clk); rstn=1;
    // A -5 MHz complex carrier at Fs=65 MHz: exp(-j*2*pi*n/13).
    for(n=0;n<260;n=n+1) begin
      i_sample=(12000*$signed(cos13(n%13)))>>>15;
      q_sample=-(12000*$signed(sin13(n%13)))>>>15;
      complex_data={q_sample[15:0],i_sample[15:0]};
      complex_valid=1;
      @(posedge clk);
    end
    complex_valid=0;
    repeat(8) @(posedge clk);
    if(samples<250) $fatal(1,"Too few output samples: %0d",samples);
    if((sum_i/(samples-80))<11500 || (sum_i/(samples-80))>12200)
      $fatal(1,"DDC I level incorrect: %0d",sum_i/(samples-80));
    if((sum_abs_q/(samples-80))>100)
      $fatal(1,"DDC residual Q too large: %0d",sum_abs_q/(samples-80));
    $display("LEAKAGE_DEMOD_SIM_PASS mean_i=%0d mean_abs_q=%0d samples=%0d",
      sum_i/(samples-80),sum_abs_q/(samples-80),samples);
    $finish;
  end
endmodule

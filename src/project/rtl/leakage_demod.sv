// Runtime-programmable complex DDC for leakage-band discovery.
// phase_inc is a signed two's-complement tuning word at 65 MS/s:
//   phase_inc = round(mixer_hz / 65e6 * 2^32)
module leakage_demod (
  input wire clk, input wire rstn, input wire [31:0] complex_data,
  input wire complex_valid, input wire [31:0] phase_inc,
  input wire mixer_enable, input wire filter_enable,
  output reg [31:0] baseband_data=0, output reg baseband_valid=0
);
  wire signed [15:0] i_in=complex_data[15:0], q_in=complex_data[31:16];
  reg [31:0] phase_acc=0, phase_inc_d=0;
  reg mixer_enable_d=0, filter_enable_d=0;
  function automatic signed [15:0] quarter_sin(input [6:0] index);
    begin case(index)
        7'd0: quarter_sin = 16'sd0;
        7'd1: quarter_sin = 16'sd804;
        7'd2: quarter_sin = 16'sd1608;
        7'd3: quarter_sin = 16'sd2410;
        7'd4: quarter_sin = 16'sd3212;
        7'd5: quarter_sin = 16'sd4011;
        7'd6: quarter_sin = 16'sd4808;
        7'd7: quarter_sin = 16'sd5602;
        7'd8: quarter_sin = 16'sd6393;
        7'd9: quarter_sin = 16'sd7179;
        7'd10: quarter_sin = 16'sd7962;
        7'd11: quarter_sin = 16'sd8739;
        7'd12: quarter_sin = 16'sd9512;
        7'd13: quarter_sin = 16'sd10278;
        7'd14: quarter_sin = 16'sd11039;
        7'd15: quarter_sin = 16'sd11793;
        7'd16: quarter_sin = 16'sd12539;
        7'd17: quarter_sin = 16'sd13279;
        7'd18: quarter_sin = 16'sd14010;
        7'd19: quarter_sin = 16'sd14732;
        7'd20: quarter_sin = 16'sd15446;
        7'd21: quarter_sin = 16'sd16151;
        7'd22: quarter_sin = 16'sd16846;
        7'd23: quarter_sin = 16'sd17530;
        7'd24: quarter_sin = 16'sd18204;
        7'd25: quarter_sin = 16'sd18868;
        7'd26: quarter_sin = 16'sd19519;
        7'd27: quarter_sin = 16'sd20159;
        7'd28: quarter_sin = 16'sd20787;
        7'd29: quarter_sin = 16'sd21403;
        7'd30: quarter_sin = 16'sd22005;
        7'd31: quarter_sin = 16'sd22594;
        7'd32: quarter_sin = 16'sd23170;
        7'd33: quarter_sin = 16'sd23731;
        7'd34: quarter_sin = 16'sd24279;
        7'd35: quarter_sin = 16'sd24811;
        7'd36: quarter_sin = 16'sd25329;
        7'd37: quarter_sin = 16'sd25832;
        7'd38: quarter_sin = 16'sd26319;
        7'd39: quarter_sin = 16'sd26790;
        7'd40: quarter_sin = 16'sd27245;
        7'd41: quarter_sin = 16'sd27683;
        7'd42: quarter_sin = 16'sd28105;
        7'd43: quarter_sin = 16'sd28510;
        7'd44: quarter_sin = 16'sd28898;
        7'd45: quarter_sin = 16'sd29268;
        7'd46: quarter_sin = 16'sd29621;
        7'd47: quarter_sin = 16'sd29956;
        7'd48: quarter_sin = 16'sd30273;
        7'd49: quarter_sin = 16'sd30571;
        7'd50: quarter_sin = 16'sd30852;
        7'd51: quarter_sin = 16'sd31113;
        7'd52: quarter_sin = 16'sd31356;
        7'd53: quarter_sin = 16'sd31580;
        7'd54: quarter_sin = 16'sd31785;
        7'd55: quarter_sin = 16'sd31971;
        7'd56: quarter_sin = 16'sd32137;
        7'd57: quarter_sin = 16'sd32285;
        7'd58: quarter_sin = 16'sd32412;
        7'd59: quarter_sin = 16'sd32521;
        7'd60: quarter_sin = 16'sd32609;
        7'd61: quarter_sin = 16'sd32678;
        7'd62: quarter_sin = 16'sd32728;
        7'd63: quarter_sin = 16'sd32757;
        7'd64: quarter_sin = 16'sd32767;
      default: quarter_sin=16'sd0;
    endcase end
  endfunction
  function automatic signed [15:0] sin_from_phase(input [7:0] p);
    reg [5:0] x;
    begin x=p[5:0]; case(p[7:6])
      2'd0: sin_from_phase=quarter_sin({1'b0,x});
      2'd1: sin_from_phase=quarter_sin(7'd64-{1'b0,x});
      2'd2: sin_from_phase=-quarter_sin({1'b0,x});
      default: sin_from_phase=-quarter_sin(7'd64-{1'b0,x});
    endcase end
  endfunction
  wire [7:0] phase_index=phase_acc[31:24];
  wire signed [15:0] sin_q15=sin_from_phase(phase_index);
  wire signed [15:0] cos_q15=sin_from_phase(phase_index+8'd64);
  // Pipeline the NCO lookup, multipliers and complex add/subtract.  The
  // first implementation placed RAM lookup + two DSP stages + saturation
  // in one 5 ns path.  These explicit registers preserve one sample/cycle
  // throughput while separating that path into independently timed stages.
  reg signed [15:0] lut_i=0,lut_q=0,lut_sin=0,lut_cos=0;
  reg lut_valid=0;
  reg signed [31:0] prod_ic=0,prod_qs=0,prod_is=0,prod_qc=0;
  reg signed [15:0] bypass_prod_i=0,bypass_prod_q=0;
  reg prod_valid=0;
  reg signed [32:0] rot_i_full=0,rot_q_full=0;
  reg signed [15:0] bypass_rot_i=0,bypass_rot_q=0;
  reg rot_valid=0;
  function automatic signed [15:0] sat_rot(input signed [32:0] value);
    reg signed [32:0] shifted;
    begin shifted=value>>>15;
      if(shifted>33'sd32767) sat_rot=16'sh7fff;
      else if(shifted< -33'sd32768) sat_rot=16'sh8000;
      else sat_rot=shifted[15:0];
    end
  endfunction
  reg signed [15:0] mix_i=0,mix_q=0;
  reg mix_valid=0;
  integer k;
  reg signed [15:0] delay1_i[0:7],delay1_q[0:7],delay2_i[0:7],delay2_q[0:7];
  reg [2:0] wr_ptr=0;
  reg signed [20:0] sum1_i=0,sum1_q=0,sum2_i=0,sum2_q=0;
  wire signed [20:0] mix_i_ext={{5{mix_i[15]}},mix_i};
  wire signed [20:0] mix_q_ext={{5{mix_q[15]}},mix_q};
  wire signed [20:0] old1_i_ext={{5{delay1_i[wr_ptr][15]}},delay1_i[wr_ptr]};
  wire signed [20:0] old1_q_ext={{5{delay1_q[wr_ptr][15]}},delay1_q[wr_ptr]};
  wire signed [20:0] sum1_i_next=sum1_i-old1_i_ext+mix_i_ext;
  wire signed [20:0] sum1_q_next=sum1_q-old1_q_ext+mix_q_ext;
  wire signed [15:0] avg1_i=sum1_i_next>>>3, avg1_q=sum1_q_next>>>3;
  wire signed [20:0] avg1_i_ext={{5{avg1_i[15]}},avg1_i};
  wire signed [20:0] avg1_q_ext={{5{avg1_q[15]}},avg1_q};
  wire signed [20:0] old2_i_ext={{5{delay2_i[wr_ptr][15]}},delay2_i[wr_ptr]};
  wire signed [20:0] old2_q_ext={{5{delay2_q[wr_ptr][15]}},delay2_q[wr_ptr]};
  wire signed [20:0] sum2_i_next=sum2_i-old2_i_ext+avg1_i_ext;
  wire signed [20:0] sum2_q_next=sum2_q-old2_q_ext+avg1_q_ext;
  wire signed [15:0] avg2_i=sum2_i_next>>>3, avg2_q=sum2_q_next>>>3;
  wire config_changed=(phase_inc!=phase_inc_d)||(mixer_enable!=mixer_enable_d)||(filter_enable!=filter_enable_d);
  always @(posedge clk) begin
    if(!rstn) begin
      phase_acc<=0;phase_inc_d<=0;mixer_enable_d<=0;filter_enable_d<=0;
      lut_i<=0;lut_q<=0;lut_sin<=0;lut_cos<=0;lut_valid<=0;
      prod_ic<=0;prod_qs<=0;prod_is<=0;prod_qc<=0;prod_valid<=0;
      bypass_prod_i<=0;bypass_prod_q<=0;
      rot_i_full<=0;rot_q_full<=0;rot_valid<=0;
      bypass_rot_i<=0;bypass_rot_q<=0;
      mix_i<=0;mix_q<=0;mix_valid<=0;wr_ptr<=0;sum1_i<=0;sum1_q<=0;sum2_i<=0;sum2_q<=0;
      baseband_data<=0;baseband_valid<=0;
      for(k=0;k<8;k=k+1) begin delay1_i[k]<=0;delay1_q[k]<=0;delay2_i[k]<=0;delay2_q[k]<=0;end
    end else if(config_changed) begin
      phase_acc<=0;phase_inc_d<=phase_inc;mixer_enable_d<=mixer_enable;filter_enable_d<=filter_enable;
      lut_valid<=0;prod_valid<=0;rot_valid<=0;mix_valid<=0;
      wr_ptr<=0;sum1_i<=0;sum1_q<=0;sum2_i<=0;sum2_q<=0;baseband_valid<=0;
      for(k=0;k<8;k=k+1) begin delay1_i[k]<=0;delay1_q[k]<=0;delay2_i[k]<=0;delay2_q[k]<=0;end
    end else begin
      lut_valid<=complex_valid;
      prod_valid<=lut_valid;
      rot_valid<=prod_valid;
      mix_valid<=rot_valid;
      baseband_valid<=0;
      if(complex_valid) begin
        lut_i<=i_in;lut_q<=q_in;lut_sin<=sin_q15;lut_cos<=cos_q15;
        if(mixer_enable) phase_acc<=phase_acc+phase_inc;
      end
      if(lut_valid) begin
        prod_ic<=lut_i*lut_cos;prod_qs<=lut_q*lut_sin;
        prod_is<=lut_i*lut_sin;prod_qc<=lut_q*lut_cos;
        bypass_prod_i<=lut_i;bypass_prod_q<=lut_q;
      end
      if(prod_valid) begin
        rot_i_full<=$signed(prod_ic)-$signed(prod_qs);
        rot_q_full<=$signed(prod_is)+$signed(prod_qc);
        bypass_rot_i<=bypass_prod_i;bypass_rot_q<=bypass_prod_q;
      end
      if(rot_valid) begin
        if(mixer_enable) begin
          mix_i<=sat_rot(rot_i_full);mix_q<=sat_rot(rot_q_full);
        end else begin mix_i<=bypass_rot_i;mix_q<=bypass_rot_q;end
      end
      if(mix_valid) begin
        if(filter_enable) begin
          delay1_i[wr_ptr]<=mix_i;delay1_q[wr_ptr]<=mix_q;sum1_i<=sum1_i_next;sum1_q<=sum1_q_next;
          delay2_i[wr_ptr]<=avg1_i;delay2_q[wr_ptr]<=avg1_q;sum2_i<=sum2_i_next;sum2_q<=sum2_q_next;
          wr_ptr<=wr_ptr+1'b1;baseband_data<={avg2_q,avg2_i};
        end else baseband_data<={mix_q,mix_i};
        baseband_valid<=1;
      end
    end
  end
endmodule


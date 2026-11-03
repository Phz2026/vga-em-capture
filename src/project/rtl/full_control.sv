// AXI4-Lite register bank and one-cycle command pulse generator.
module full_control (
  input wire clk, input wire rstn,
  input wire stream_loss, input wire frame_pending, input wire capture_busy,
  input wire frozen_bank, input wire [31:0] frame_id,
  input wire image_replay_busy, input wire image_done, input wire image_range_error,
  input wire spectrum_busy, input wire spectrum_done,
  input wire [2:0] spectrum_average_count, input wire spectrum_overflow_error,
  input wire spectrum_replay_busy, input wire spectrum_replay_done,
  input wire raw_capture_busy, input wire raw_capture_pending,
  input wire raw_replay_busy, input wire raw_replay_done,
  input wire raw_range_error, input wire [15:0] raw_captured_count,
  input wire event_busy, input wire event_decision_valid, input wire event_changed,
  input wire [15:0] event_metric_q16, input wire [15:0] event_best_lag,
  input wire [2:0] event_debounce_history, input wire event_reference_valid,
  input wire event_ack_copy_busy,
  output reg capture_start=0, output reg frame_ack=0, output reg spectrum_arm=0,
  output reg image_replay_start=0, output reg spectrum_replay_start=0,
  output reg raw_capture_start=0, output reg raw_replay_start=0,
  output reg clear_error=0,
  output reg [15:0] line_samples=16'd1344,
  output reg [15:0] frame_lines=16'd900,
  output reg [15:0] active_width=16'd1024,
  output reg [15:0] active_height=16'd768,
  output reg [15:0] crop_x=16'd0, output reg [15:0] crop_y=16'd0,
  output reg [7:0] segment_sel=0, output reg [15:0] feature_gain=16'h0100,
  output reg [1:0] feature_mode=2'd0,
  output reg [15:0] diff_threshold=16'd8,
  output reg [31:0] ddc_phase_inc=32'h13B13B14,
  output reg [1:0] ddc_control=2'b11,
  output reg [15:0] raw_capture_length=16'd32768,
  output reg event_enable=1'b0, output reg event_force=1'b0,
  output reg [15:0] event_threshold=16'h0800,
  input wire [7:0] s_axi_awaddr, input wire s_axi_awvalid, output wire s_axi_awready,
  input wire [31:0] s_axi_wdata, input wire [3:0] s_axi_wstrb,
  input wire s_axi_wvalid, output wire s_axi_wready,
  output reg [1:0] s_axi_bresp=0, output reg s_axi_bvalid=0, input wire s_axi_bready,
  input wire [7:0] s_axi_araddr, input wire s_axi_arvalid, output wire s_axi_arready,
  output reg [31:0] s_axi_rdata=0, output reg [1:0] s_axi_rresp=0,
  output reg s_axi_rvalid=0, input wire s_axi_rready
);
  reg aw_full=0, w_full=0;
  reg [7:0] wa=0; reg [31:0] wd=0, scratch=0; reg [3:0] ws=0;
  integer j;
  assign s_axi_awready=rstn && !aw_full && !s_axi_bvalid;
  assign s_axi_wready=rstn && !w_full && !s_axi_bvalid;
  assign s_axi_arready=rstn && !s_axi_rvalid;
  always @(posedge clk) begin
    if (!rstn) begin
      aw_full<=0; w_full<=0; s_axi_bvalid<=0; s_axi_rvalid<=0;
      s_axi_bresp<=0; s_axi_rresp<=0; scratch<=0;
      line_samples<=1344; frame_lines<=900; active_width<=1024; active_height<=768;
      crop_x<=0; crop_y<=0; segment_sel<=0; feature_gain<=16'h0100; feature_mode<=0; diff_threshold<=8;
      ddc_phase_inc<=32'h13B13B14; ddc_control<=2'b11; raw_capture_length<=16'd32768;
      event_enable<=0; event_force<=0; event_threshold<=16'h0800;
      capture_start<=0; frame_ack<=0; spectrum_arm<=0;
      image_replay_start<=0; spectrum_replay_start<=0; raw_capture_start<=0; raw_replay_start<=0; clear_error<=0;
    end else begin
      capture_start<=0; frame_ack<=0; spectrum_arm<=0; event_force<=0;
      image_replay_start<=0; spectrum_replay_start<=0; raw_capture_start<=0; raw_replay_start<=0; clear_error<=0;
      if (s_axi_awvalid && s_axi_awready) begin wa<=s_axi_awaddr; aw_full<=1; end
      if (s_axi_wvalid && s_axi_wready) begin wd<=s_axi_wdata; ws<=s_axi_wstrb; w_full<=1; end
      if (s_axi_bvalid && s_axi_bready) s_axi_bvalid<=0;
      if (aw_full && w_full && !s_axi_bvalid) begin
        aw_full<=0; w_full<=0; s_axi_bvalid<=1; s_axi_bresp<=0;
        case (wa)
          8'h08: if (ws[0]) begin
            capture_start<=wd[0]; frame_ack<=wd[1]; spectrum_arm<=wd[2];
            image_replay_start<=wd[3]; spectrum_replay_start<=wd[4]; clear_error<=wd[5];
            raw_capture_start<=wd[6]; raw_replay_start<=wd[7];
          end
          8'h10: begin if(ws[0]) line_samples[7:0]<=wd[7:0]; if(ws[1]) line_samples[15:8]<=wd[15:8]; end
          8'h14: begin if(ws[0]) frame_lines[7:0]<=wd[7:0]; if(ws[1]) frame_lines[15:8]<=wd[15:8]; end
          8'h18: begin if(ws[0]) active_width[7:0]<=wd[7:0]; if(ws[1]) active_width[15:8]<=wd[15:8]; end
          8'h1c: begin if(ws[0]) active_height[7:0]<=wd[7:0]; if(ws[1]) active_height[15:8]<=wd[15:8]; end
          8'h20: begin if(ws[0]) crop_x[7:0]<=wd[7:0]; if(ws[1]) crop_x[15:8]<=wd[15:8]; end
          8'h24: begin if(ws[0]) crop_y[7:0]<=wd[7:0]; if(ws[1]) crop_y[15:8]<=wd[15:8]; end
          8'h28: if(ws[0]) segment_sel<=wd[7:0];
          8'h2c: begin if(ws[0]) feature_gain[7:0]<=wd[7:0]; if(ws[1]) feature_gain[15:8]<=wd[15:8]; end
          8'h30: begin if(ws[0]) diff_threshold[7:0]<=wd[7:0]; if(ws[1]) diff_threshold[15:8]<=wd[15:8]; end
          8'h3c: for(j=0;j<4;j=j+1) if(ws[j]) scratch[j*8+:8]<=wd[j*8+:8];
          8'h40: if(ws[0]) feature_mode<=wd[1:0];
          8'h44: for(j=0;j<4;j=j+1) if(ws[j]) ddc_phase_inc[j*8+:8]<=wd[j*8+:8];
          8'h48: if(ws[0]) ddc_control<=wd[1:0];
          8'h4c: begin if(ws[0]) raw_capture_length[7:0]<=wd[7:0]; if(ws[1]) raw_capture_length[15:8]<=wd[15:8]; end
          8'h54: begin if(ws[0]) event_threshold[7:0]<=wd[7:0]; if(ws[1]) event_threshold[15:8]<=wd[15:8]; end
          8'h58: begin if(ws[0]) begin event_enable<=wd[0]; if(wd[1]) event_force<=1'b1; end end
          default: s_axi_bresp<=2'b10;
        endcase
      end
      if (s_axi_rvalid && s_axi_rready) s_axi_rvalid<=0;
      if (s_axi_arvalid && s_axi_arready) begin
        s_axi_rvalid<=1; s_axi_rresp<=0;
        case(s_axi_araddr)
          8'h00: s_axi_rdata<=32'h56474132;
          8'h04: s_axi_rdata<=32'h00020700;
          8'h08: s_axi_rdata<=0;
          8'h0c: s_axi_rdata<={12'd0,raw_range_error,raw_replay_done,raw_replay_busy,
            raw_capture_busy,raw_capture_pending,spectrum_average_count,spectrum_replay_done,
            image_done,spectrum_overflow_error,image_range_error,frozen_bank,
            spectrum_replay_busy,image_replay_busy,spectrum_done,spectrum_busy,
            frame_pending,capture_busy,stream_loss};
          8'h10: s_axi_rdata<={16'd0,line_samples};
          8'h14: s_axi_rdata<={16'd0,frame_lines};
          8'h18: s_axi_rdata<={16'd0,active_width};
          8'h1c: s_axi_rdata<={16'd0,active_height};
          8'h20: s_axi_rdata<={16'd0,crop_x};
          8'h24: s_axi_rdata<={16'd0,crop_y};
          8'h28: s_axi_rdata<={24'd0,segment_sel};
          8'h2c: s_axi_rdata<={16'd0,feature_gain};
          8'h30: s_axi_rdata<={16'd0,diff_threshold};
          8'h34: s_axi_rdata<=frame_id;
          8'h38: s_axi_rdata<=32'd0;
          8'h3c: s_axi_rdata<=scratch;
          8'h40: s_axi_rdata<={30'd0,feature_mode};
          8'h44: s_axi_rdata<=ddc_phase_inc;
          8'h48: s_axi_rdata<={30'd0,ddc_control};
          8'h4c: s_axi_rdata<={16'd0,raw_capture_length};
          8'h50: s_axi_rdata<={16'd0,raw_captured_count};
          8'h54: s_axi_rdata<={16'd0,event_threshold};
          8'h58: s_axi_rdata<={31'd0,event_enable};
          8'h5c: s_axi_rdata<={24'd0,event_ack_copy_busy,event_reference_valid,event_debounce_history,
            event_changed,event_decision_valid,event_busy};
          8'h60: s_axi_rdata<={16'd0,event_metric_q16};
          8'h64: s_axi_rdata<={16'd0,event_best_lag};
          default: begin s_axi_rdata<=0; s_axi_rresp<=2'b10; end
        endcase
      end
    end
  end
endmodule

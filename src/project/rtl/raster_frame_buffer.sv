// Two-bank 8-bit frame buffer packed eight pixels per 64-bit UltraRAM word.
// Packing avoids the severe depth waste caused by an 8-bit-wide UltraRAM.
module raster_frame_buffer #(
  parameter integer LINE_MAX=1344, parameter integer FRAME_MAX=900,
  parameter integer SEGMENT_BYTES=131072,
  parameter integer FRAME_PIXELS=LINE_MAX*FRAME_MAX,
  parameter integer WORDS_PER_FRAME=(FRAME_PIXELS+7)/8,
  parameter integer MEMORY_WORDS=2*WORDS_PER_FRAME
) (
  input wire clk, input wire rstn,
  input wire [7:0] feature, input wire feature_valid,
  input wire capture_start, input wire frame_ack,
  input wire [15:0] line_samples, input wire [15:0] frame_lines,
  input wire [7:0] segment_sel, input wire replay_start, input wire clear_error,
  input wire event_enable, input wire event_force, input wire [15:0] event_threshold,
  output reg capture_busy=0, output reg frame_pending=0, output reg frozen_bank=0,
  output reg [31:0] frame_id=0,
  output reg replay_busy=0, output reg [7:0] replay_data=0,
  output reg [20:0] replay_addr=0, output reg replay_valid=0,
  output reg replay_trigger=0, output reg replay_done=0, output reg range_error=0,
  output wire event_busy, output wire event_decision_valid, output wire event_changed,
  output wire [15:0] event_metric_q16, output wire [15:0] event_best_lag,
  output wire [2:0] event_debounce_history, output wire event_reference_valid,
  output wire event_ack_copy_busy
);
  localparam integer WORD_ADDR_W=19;
  localparam [2:0] RP_IDLE=0, RP_ISSUE=1, RP_WAIT1=2, RP_WAIT2=3,
                   RP_WAIT3=4, RP_BYTES=5;
  reg write_bank=0;
  reg [20:0] pixel_count=0, captured_pixels=FRAME_PIXELS;
  reg [17:0] word_count=0;
  reg [2:0] pack_index=0;
  reg [63:0] pack_reg=0, pack_next;
  reg [15:0] line_sample_index=0;
  reg [9:0] line_index=0;
  reg [23:0] line_accum=0;
  reg [31:0] frame_energy=0;
  reg last_completed_bank=0;
  reg supplemental_pending=0, supplemental_bank=0;
  wire [31:0] requested_now=line_samples*frame_lines;
  reg [WORD_ADDR_W-1:0] mem_addra=0, mem_addrb=0;
  reg [63:0] mem_dina=0;
  reg mem_ena=0, mem_wea=0, mem_enb=0;
  wire [63:0] mem_doutb;
  reg [2:0] replay_state=RP_IDLE, replay_byte_index=0;
  reg [20:0] segment_base=0, segment_count=0, replay_count=0;
  reg [63:0] replay_word=0;
  wire [31:0] segment_base_now=segment_sel*SEGMENT_BYTES;
  wire [24:0] line_sum_next = {1'b0,line_accum} + feature;
  wire line_end = capture_busy && feature_valid && ((line_sample_index + 1'b1) >= line_samples);
  wire frame_end = capture_busy && feature_valid && ((pixel_count + 1'b1) >= captured_pixels);
  // Wait one cycle after the detector's decision so pending/frozen-bank and
  // write-bank updates have taken effect before another frame can start.
  wire auto_start = event_enable && !frame_ack && !capture_busy && !event_busy &&
                    !event_decision_valid &&
                    !(supplemental_pending && frame_pending);
  wire capture_request = (capture_start || auto_start) && !frame_ack &&
                         !capture_busy && !event_busy;

  frame_event_detector #(.MAX_LINES(1024)) event_i (
    .clk(clk), .rstn(rstn), .event_enable(event_enable), .force_export(event_force),
    .threshold_q16(event_threshold), .frame_lines(frame_lines),
    .frame_start(capture_request), .frame_start_bank(write_bank),
    .profile_we(line_end), .profile_bank(write_bank), .profile_index(line_index),
    .profile_value(line_sum_next[23:0]), .frame_done(frame_end),
    .completed_bank(write_bank), .completed_sum(frame_energy + feature),
    .frame_ack(frame_ack), .frozen_bank(frozen_bank), .busy(event_busy),
    .decision_valid(event_decision_valid), .changed(event_changed),
    .metric_q16(event_metric_q16), .best_lag(event_best_lag),
    .debounce_history(event_debounce_history), .reference_valid(event_reference_valid),
    .ack_copy_busy(event_ack_copy_busy)
  );

  always @* begin
    pack_next=pack_reg;
    case(pack_index)
      0:pack_next[7:0]=feature; 1:pack_next[15:8]=feature;
      2:pack_next[23:16]=feature; 3:pack_next[31:24]=feature;
      4:pack_next[39:32]=feature; 5:pack_next[47:40]=feature;
      6:pack_next[55:48]=feature; 7:pack_next[63:56]=feature;
    endcase
  end

  xpm_memory_tdpram #(
    .ADDR_WIDTH_A(WORD_ADDR_W),.ADDR_WIDTH_B(WORD_ADDR_W),.AUTO_SLEEP_TIME(0),
    .BYTE_WRITE_WIDTH_A(64),.BYTE_WRITE_WIDTH_B(64),.CLOCKING_MODE("common_clock"),
    .ECC_MODE("no_ecc"),.MEMORY_INIT_FILE("none"),.MEMORY_INIT_PARAM("0"),
    .MEMORY_OPTIMIZATION("true"),.MEMORY_PRIMITIVE("ultra"),
    .MEMORY_SIZE(MEMORY_WORDS*64),.MESSAGE_CONTROL(0),
    .READ_DATA_WIDTH_A(64),.READ_DATA_WIDTH_B(64),.READ_LATENCY_A(1),.READ_LATENCY_B(2),
    .READ_RESET_VALUE_A("0"),.READ_RESET_VALUE_B("0"),.RST_MODE_A("SYNC"),.RST_MODE_B("SYNC"),
    .SIM_ASSERT_CHK(0),.USE_EMBEDDED_CONSTRAINT(0),.USE_MEM_INIT(0),.WAKEUP_TIME("disable_sleep"),
    .WRITE_DATA_WIDTH_A(64),.WRITE_DATA_WIDTH_B(64),.WRITE_MODE_A("no_change"),.WRITE_MODE_B("no_change")
  ) frame_mem(
    .clka(clk),.clkb(clk),.rsta(!rstn),.rstb(!rstn),.ena(mem_ena),.enb(mem_enb),
    .regcea(1'b1),.regceb(1'b1),.wea(mem_wea),.web(1'b0),.addra(mem_addra),.addrb(mem_addrb),
    .dina(mem_dina),.dinb(64'd0),.douta(),.doutb(mem_doutb),.sleep(1'b0),
    .injectsbiterra(1'b0),.injectdbiterra(1'b0),.injectsbiterrb(1'b0),.injectdbiterrb(1'b0),
    .sbiterra(),.dbiterra(),.sbiterrb(),.dbiterrb()
  );

  always @(posedge clk) begin
    if(!rstn) begin
      write_bank<=0;pixel_count<=0;captured_pixels<=FRAME_PIXELS;word_count<=0;
      pack_index<=0;pack_reg<=0;capture_busy<=0;frame_pending<=0;frozen_bank<=0;frame_id<=0;
      line_sample_index<=0; line_index<=0; line_accum<=0; frame_energy<=0;
      last_completed_bank<=0; supplemental_pending<=0; supplemental_bank<=0;
      mem_ena<=0;mem_wea<=0;mem_enb<=0;replay_state<=RP_IDLE;replay_busy<=0;
      replay_valid<=0;replay_trigger<=0;replay_done<=0;range_error<=0;
    end else begin
      mem_ena<=0;mem_wea<=0;mem_enb<=0;replay_valid<=0;replay_trigger<=0;replay_done<=0;
      if(frame_ack) begin
        if (supplemental_pending) begin
          // The newer bank remains queued after the older bank is acknowledged.
          frame_pending<=1;
          frozen_bank<=supplemental_bank;
          supplemental_pending<=0;
          write_bank<=frozen_bank;
        end else frame_pending<=0;
      end
      if(clear_error) range_error<=0;
      if(capture_request) begin
        if((requested_now==0)||(requested_now>FRAME_PIXELS)) begin range_error<=1;captured_pixels<=FRAME_PIXELS;end
        else captured_pixels<=requested_now[20:0];
        pixel_count<=0;word_count<=0;pack_index<=0;pack_reg<=0;capture_busy<=1;
        line_sample_index<=0; line_index<=0; line_accum<=0; frame_energy<=0;
      end
      if(capture_busy&&feature_valid) begin
        pack_reg<=pack_next;
        if((pack_index==7)||(pixel_count+1>=captured_pixels)) begin
          mem_ena<=1;mem_wea<=1;mem_dina<=pack_next;
          mem_addra<=(write_bank?WORDS_PER_FRAME:0)+word_count;
          word_count<=word_count+1;pack_index<=0;pack_reg<=0;
        end else pack_index<=pack_index+1;
        line_accum <= line_end ? 0 : line_sum_next[23:0];
        line_sample_index <= line_end ? 0 : line_sample_index + 1'b1;
        line_index <= line_end ? line_index + 1'b1 : line_index;
        frame_energy <= frame_energy + feature;
        if(pixel_count+1>=captured_pixels) begin
          capture_busy<=0; last_completed_bank<=write_bank; write_bank<=~write_bank;
          frame_id<=frame_id+1;pixel_count<=0;
          if (!event_enable) begin frozen_bank<=write_bank; frame_pending<=1; end
        end else pixel_count<=pixel_count+1;
      end
      if (event_decision_valid) begin
        if (event_changed) begin
          if (frame_pending) begin
            supplemental_pending<=1;
            supplemental_bank<=last_completed_bank;
            write_bank<=~last_completed_bank;
          end else begin
            frame_pending<=1;
            frozen_bank<=last_completed_bank;
            write_bank<=~last_completed_bank;
          end
        end else if (frame_pending) begin
          // Keep the currently exported bank frozen and reuse the just-tested
          // free bank for the next automatic frame.
          write_bank<=last_completed_bank;
        end
      end
      if(replay_start&&!replay_busy&&frame_pending) begin
        if(segment_base_now>=captured_pixels) begin range_error<=1;replay_done<=1;end
        else begin
          segment_base<=segment_base_now[20:0];replay_count<=0;
          // Every ILA transfer is a fixed 128 KiB. The final segment is padded
          // with zeroes so a qualified ILA capture can always reach its depth.
          segment_count<=SEGMENT_BYTES;
          replay_busy<=1;replay_state<=RP_ISSUE;
        end
      end
      case(replay_state)
        RP_IDLE:;
        RP_ISSUE:begin
          if(segment_base+replay_count>=captured_pixels) begin
            replay_word<=0;replay_byte_index<=0;replay_state<=RP_BYTES;
          end else begin
            mem_enb<=1;
            mem_addrb<=(frozen_bank?WORDS_PER_FRAME:0)+((segment_base+replay_count)>>3);
            replay_state<=RP_WAIT1;
          end
        end
        RP_WAIT1:replay_state<=RP_WAIT2;
        RP_WAIT2:replay_state<=RP_WAIT3;
        RP_WAIT3:begin replay_word<=mem_doutb;replay_byte_index<=(segment_base+replay_count)&7;replay_state<=RP_BYTES;end
        RP_BYTES:begin
          case(replay_byte_index)
            0:replay_data<=replay_word[7:0]; 1:replay_data<=replay_word[15:8];
            2:replay_data<=replay_word[23:16]; 3:replay_data<=replay_word[31:24];
            4:replay_data<=replay_word[39:32]; 5:replay_data<=replay_word[47:40];
            6:replay_data<=replay_word[55:48]; 7:replay_data<=replay_word[63:56];
          endcase
          replay_addr<=segment_base+replay_count;replay_valid<=1;
          if(replay_count==0) replay_trigger<=1;
          if(replay_count+1>=segment_count) begin replay_busy<=0;replay_done<=1;replay_state<=RP_IDLE;end
          else begin
            replay_count<=replay_count+1;
            if(replay_byte_index==7) replay_state<=RP_ISSUE;
            else replay_byte_index<=replay_byte_index+1;
          end
        end
        default:replay_state<=RP_IDLE;
      endcase
    end
  end
endmodule

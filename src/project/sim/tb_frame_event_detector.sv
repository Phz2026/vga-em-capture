`timescale 1ns/1ps
module tb_frame_event_detector;
  reg clk=0, rstn=0;
  always #5 clk=~clk;
  reg event_enable=1, force_export=0, frame_start=0, frame_start_bank=0;
  reg profile_we=0, profile_bank=0, frame_done=0, completed_bank=0;
  reg [9:0] profile_index=0;
  reg [23:0] profile_value=0;
  reg [31:0] completed_sum=0;
  reg frame_ack=0, frozen_bank=0;
  wire busy, decision_valid, changed, reference_valid, ack_copy_busy;
  wire [15:0] metric_q16, best_lag;
  wire [2:0] debounce_history;
  frame_event_detector #(.MAX_LINES(4)) dut (
    .clk(clk),.rstn(rstn),.event_enable(event_enable),
    .force_export(force_export),.threshold_q16(16'd4096),.frame_lines(16'd4),
    .frame_start(frame_start),.frame_start_bank(frame_start_bank),
    .profile_we(profile_we),.profile_bank(profile_bank),
    .profile_index(profile_index),.profile_value(profile_value),
    .frame_done(frame_done),.completed_bank(completed_bank),
    .completed_sum(completed_sum),.frame_ack(frame_ack),
    .frozen_bank(frozen_bank),.busy(busy),.decision_valid(decision_valid),
    .changed(changed),.metric_q16(metric_q16),.best_lag(best_lag),
    .debounce_history(debounce_history),.reference_valid(reference_valid),
    .ack_copy_busy(ack_copy_busy));

  task automatic send_frame(input bit bank, input [23:0] a,b,c,d,
                            input bit expected_changed);
    integer i, ticks;
    reg [23:0] value;
    begin
      @(negedge clk); frame_start=1; frame_start_bank=bank;
      @(negedge clk); frame_start=0;
      for (i=0;i<4;i=i+1) begin
        case(i) 0:value=a; 1:value=b; 2:value=c; default:value=d; endcase
        profile_we=1; profile_bank=bank; profile_index=i; profile_value=value;
        @(negedge clk);
      end
      profile_we=0; completed_bank=bank; completed_sum=a+b+c+d;
      frame_done=1;
      @(negedge clk); frame_done=0;
      ticks=0;
      while (!decision_valid && ticks<200) begin @(negedge clk); ticks=ticks+1; end
      if (!decision_valid) $fatal(1,"decision timeout");
      if (changed !== expected_changed)
        $fatal(1,"changed=%b expected=%b metric=%d history=%b",
               changed,expected_changed,metric_q16,debounce_history);
      $display("frame bank=%b changed=%b metric=%d history=%b",
               bank,changed,metric_q16,debounce_history);
      @(negedge clk);
    end
  endtask

  integer ticks;
  initial begin
    repeat(4) @(negedge clk); rstn=1;
    send_frame(0,1,2,3,4,1);
    @(negedge clk); frozen_bank=0; frame_ack=1;
    @(negedge clk); frame_ack=0;
    ticks=0;
    while (!reference_valid && ticks<30) begin @(negedge clk); ticks=ticks+1; end
    if (!reference_valid) $fatal(1,"reference copy timeout");
    send_frame(1,2,4,6,8,0);       // Gain-only change is invariant.
    send_frame(1,100,0,0,0,0);     // First threshold hit is debounced.
    send_frame(1,100,0,0,0,1);     // Second of three raises the event.
    $display("FRAME_EVENT_DETECTOR_SIM_PASS");
    $finish;
  end
endmodule

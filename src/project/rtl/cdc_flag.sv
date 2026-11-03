// Sticky level synchronizer. It is not valid for pulses or data buses.
module cdc_flag (
  input  wire clk,
  input  wire rstn,
  input  wire async_flag,
  output wire synced_flag
);
  (* ASYNC_REG = "TRUE" *) reg [2:0] ff = 3'b000;
  always @(posedge clk)
    if (!rstn) ff <= 3'b000;
    else       ff <= {ff[1:0], async_flag};
  assign synced_flag = ff[2];
endmodule

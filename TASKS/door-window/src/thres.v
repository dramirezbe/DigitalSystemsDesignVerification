module sensor_df(input [3:0] s0, s1, s2, s3, thresh, input [1:0] sel, output led);
  wire [3:0] mux_out;
  assign mux_out = (sel == 2'b00) ? s0 : 
                   (sel == 2'b01) ? s1 : 
                   (sel == 2'b10) ? s2 : s3;
  assign led = (mux_out >= thresh);
endmodule

module sensor_beh(input [3:0] s0, s1, s2, s3, thresh, input [1:0] sel, output reg led);
  reg [3:0] mux_out;
  always @(*) begin
    case(sel)
      2'b00: mux_out = s0;
      2'b01: mux_out = s1;
      2'b10: mux_out = s2;
      2'b11: mux_out = s3;
    endcase
    led = (mux_out >= thresh);
  end
endmodule
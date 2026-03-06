module alarm_df(input [5:0] w, input [1:0] d, input s, output ind);
  assign ind = ((d[0] | d[1]) & s) | ((w[0]+w[1]+w[2]+w[3]+w[4]+w[5]) > 2);
endmodule

module alarm_beh(input [5:0] w, input [1:0] d, input s, output reg ind);
  integer i, w_count;
  always @(*) begin
    w_count = 0;
    for (i = 0; i < 6; i = i + 1) w_count = w_count + {31'b0, w[i]};
    if (((d[0] | d[1]) & s) | (w_count > 2)) 
      ind = 1;
    else 
      ind = 0;
  end
endmodule
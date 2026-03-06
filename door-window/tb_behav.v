module tb_behav;
  reg [5:0] w; reg [1:0] d; reg s;
  wire ind_df, ind_beh;

  alarm_df u1 (.w(w), .d(d), .s(s), .ind(ind_df));
  alarm_beh u2 (.w(w), .d(d), .s(s), .ind(ind_beh));

  initial begin
    $dumpfile("waveform_behav.vcd");
    $dumpvars(0, tb_behav);
    $monitor("T=%0t | w=%b d=%b s=%b -> ind_df=%b ind_beh=%b", $time, w, d, s, ind_df, ind_beh);

    w = 6'b000000; d = 2'b00; s = 0; #10;
    w = 6'b000111; d = 2'b00; s = 0; #10; 
    w = 6'b000000; d = 2'b01; s = 1; #10; 
    
    $finish;
  end
endmodule
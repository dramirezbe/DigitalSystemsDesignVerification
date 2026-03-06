module tb_thres;
  reg [3:0] s0, s1, s2, s3, thresh; reg [1:0] sel;
  wire led_df, led_beh;

  sensor_df u3 (.s0(s0), .s1(s1), .s2(s2), .s3(s3), .thresh(thresh), .sel(sel), .led(led_df));
  sensor_beh u4 (.s0(s0), .s1(s1), .s2(s2), .s3(s3), .thresh(thresh), .sel(sel), .led(led_beh));

  initial begin
    $dumpfile("waveform_thres.vcd");
    $dumpvars(0, tb_thres);
    $monitor("T=%0t | sel=%b thresh=%d -> led_df=%b led_beh=%b", $time, sel, thresh, led_df, led_beh);

    s0 = 4'd5; s1 = 4'd10; s2 = 4'd2; s3 = 4'd8; thresh = 4'd7;
    sel = 2'b00; #10; 
    sel = 2'b01; #10; 
    sel = 2'b10; #10; 
    
    $finish;
  end
endmodule
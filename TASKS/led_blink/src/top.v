//top.v
module top(
    input clk,
    output reg led2,
    output reg led3
);

reg [23:0] counter;

always @(posedge clk) begin
    counter <= counter + 1;
    
    led2 <= counter[23];      // LED 2 parpadea
    led3 <= ~counter[23];     // LED 3 opuesto
end

endmodule

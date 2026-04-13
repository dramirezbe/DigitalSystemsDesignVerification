module dtypereg #(parameter width = 8)
    (input wire [width-1:0] D,
    output reg [width-1:0] Q,
    input wire n_rst,
    input wire en,
    input wire clk);
    // Behavioral description of the D type register with enable and asynchronous
    // reset.
    always @(posedge clk or negedge n_rst) begin
        if (!n_rst) Q <= 0;
        else if (en) Q <= D;
    end
endmodule
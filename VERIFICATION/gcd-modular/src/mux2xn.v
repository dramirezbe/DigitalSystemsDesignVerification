//mux2xn.v

module mux2xn #(parameter width = 8)
    (input wire [width-1:0] in0,
    input wire [width-1:0] in1,
    input wire sel,
    output wire [width-1:0] out);
    // Functional implementation of the 2-to-1 multiplexer.
    assign out = sel ? in1 : in0;
endmodule
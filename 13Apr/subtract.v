module subtract #(parameter width=8)
    (input wire [width-1:0] a,
    input wire [width-1:0] b,
    output wire [width-1:0] diff
    );
    // Behavioral implementation of the subtraction module. Implementation
    // can be changed if needed.
    assign diff = a - b;
endmodule
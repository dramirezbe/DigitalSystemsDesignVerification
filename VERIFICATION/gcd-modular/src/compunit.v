//compunit.v

module compunit #(parameter width = 8)
    (input wire [width-1:0] a,
    input wire [width-1:0] b,
    output wire great,
    output wire less,
    output wire eq);
    // Behavioral implementation of the comparator module.
    assign eq = (a == b);
    assign less = (a < b);
    assign great = (a > b);
endmodule
module mult4x4_seq (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [3:0]  a,
    input  wire [3:0]  b,
    output reg  [7:0]  product,
    output reg         done
);

    reg [7:0] multiplicand;
    reg [3:0] multiplier;
    reg [2:0] count;

    wire [7:0] adder_out;

    // ---- Single 8-bit adder ----
    assign adder_out = product + multiplicand;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            product      <= 8'd0;
            multiplicand <= 8'd0;
            multiplier   <= 4'd0;
            count        <= 3'd0;
            done         <= 1'b0;
        end else begin
            if (start) begin
                product      <= 8'd0;
                multiplicand <= {4'd0, a}; // zero-extend
                multiplier   <= b;
                count        <= 3'd0;
                done         <= 1'b0;
            end
            else if (count < 4) begin
                if (multiplier[0])
                    product <= adder_out;   // use single adder

                multiplicand <= multiplicand << 1;
                multiplier   <= multiplier >> 1;
                count        <= count + 1;

                if (count == 3)
                    done <= 1'b1;
            end
        end
    end

endmodule

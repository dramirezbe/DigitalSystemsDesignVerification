`timescale 1ns/1ps

module tb_mult4x4_seq;

    reg clk;
    reg rst;
    reg start;
    reg [3:0] a;
    reg [3:0] b;

    wire [7:0] product;
    wire done;

    reg [7:0] expected;   // widened expected result

    mult4x4_seq uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .a(a),
        .b(b),
        .product(product),
        .done(done)
    );

    // Clock generation (10ns period)
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        a = 0;
        b = 0;

        // Waveform dump
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_mult4x4_seq);

        #10 rst = 0;

        test_case(4'd3,  4'd5);
        test_case(4'd7,  4'd9);
        test_case(4'd15, 4'd15);
        test_case(4'd2,  4'd8);

        #50 $finish;
    end

    task test_case(input [3:0] x, input [3:0] y);
    begin
        @(posedge clk);
        a = x;
        b = y;
        start = 1;

        @(posedge clk);
        start = 0;

        wait(done);

        // Compute expected in 8-bit domain
        expected = x * y;

        $display("A=%0d B=%0d Product=%0d Expected=%0d %s",
                 x, y, product, expected,
                 (product == expected) ? "PASS" : "FAIL");

        @(posedge clk);
    end
    endtask

endmodule

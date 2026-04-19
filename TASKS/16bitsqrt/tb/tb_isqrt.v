`timescale 1ns / 1ps

module tb_isqrt;

    // --------------------------------------------------------
    // DUT port connections
    // --------------------------------------------------------
    reg         clk;
    reg         reset;
    reg         start;
    reg  [15:0] data_in;
    wire        done;
    wire [7:0]  data_out;

    // --------------------------------------------------------
    // Instantiate the unit under test
    // --------------------------------------------------------
    isqrt uut (
        .clk      (clk),
        .reset    (reset),
        .start    (start),
        .data_in  (data_in),
        .done     (done),
        .data_out (data_out)
    );

    // --------------------------------------------------------
    // Clock generation — 100 MHz (period = 10 ns)
    // --------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // --------------------------------------------------------
    // Watchdog : abort if any single test takes > 50 cycles.
    // Prevents infinite simulation on a hung DUT.
    // The watchdog is reset at the start of each test_sqrt call
    // and is cancelled when done is seen.
    // --------------------------------------------------------
    integer watchdog_count;

    // --------------------------------------------------------
    // Task : test_sqrt
    //
    //   1. Present the input on the rising edge that also
    //      asserts start.  Deassert start on the NEXT edge so
    //      the DUT sees exactly one start pulse.
    //   2. Wait for done using an event-driven wait (not a
    //      polling delay).
    //   3. Sample data_out one cycle after done goes high —
    //      DONE state latches the result on the rising edge,
    //      so data_out is stable by the end of that cycle.
    //   4. Print PASS / FAIL with the computed and expected
    //      values for easy debugging.
    // --------------------------------------------------------
    task automatic test_sqrt;
        input [15:0] test_val;
        input [7:0]  expected;
        begin
            // --- Apply inputs on a rising clock edge ---
            @(posedge clk);
            data_in = test_val;
            start   = 1'b1;

            @(posedge clk);
            start = 1'b0;       // Hold start high for exactly one cycle

            // --- Wait for DUT to finish (event-driven) ---
            watchdog_count = 0;
            fork
                begin : wait_done
                    wait (done === 1'b1);
                    disable watchdog;
                end
                begin : watchdog
                    repeat (50) @(posedge clk);
                    $display("[TIMEOUT] sqrt(%5d) — DUT never asserted done", test_val);
                    disable wait_done;
                    $finish;
                end
            join

            // Sample one cycle after done (data_out is registered)
            @(posedge clk);

            // --- Self-checking ---
            if (data_out === expected)
                $display("[PASS] isqrt(%5d) = %3d", test_val, data_out);
            else
                $display("[FAIL] isqrt(%5d) = %3d  (expected %3d)",
                         test_val, data_out, expected);
        end
    endtask

    // --------------------------------------------------------
    // Stimulus
    // --------------------------------------------------------
    initial begin

        $dumpfile("build/waveform_isqrt.vcd");
        $dumpvars(0, tb_isqrt);

        // --- Initialise signals ---
        reset   = 1'b1;
        start   = 1'b0;
        data_in = 16'd0;

        // --- Hold reset for two full cycles then release ---
        repeat (2) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);   // One settling cycle after reset

        $display("=== isqrt test suite ===");

        // Exact perfect squares
        test_sqrt(16'd0,      8'd0);
        test_sqrt(16'd1,      8'd1);
        test_sqrt(16'd4,      8'd2);
        test_sqrt(16'd9,      8'd3);
        test_sqrt(16'd16,     8'd4);
        test_sqrt(16'd25,     8'd5);
        test_sqrt(16'd100,    8'd10);
        test_sqrt(16'd1024,   8'd32);
        test_sqrt(16'd4096,   8'd64);
        test_sqrt(16'd65025,  8'd255);   // 255² = 65025

        // Non-perfect squares (floor truncation)
        test_sqrt(16'd2,      8'd1);     // floor(sqrt(2))  = 1
        test_sqrt(16'd3,      8'd1);
        test_sqrt(16'd8,      8'd2);
        test_sqrt(16'd15,     8'd3);
        test_sqrt(16'd26,     8'd5);
        test_sqrt(16'd99,     8'd9);

        // Boundary values
        test_sqrt(16'd65535,  8'd255);   // floor(sqrt(65535)) = 255

        // Back-to-back: verify IDLE→CALC transition is clean
        // with no reset between runs
        test_sqrt(16'd49,     8'd7);
        test_sqrt(16'd50,     8'd7);

        $display("=== All tests complete ===");
        #20 $finish;
    end

endmodule
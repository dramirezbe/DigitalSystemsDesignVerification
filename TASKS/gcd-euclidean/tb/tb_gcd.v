`timescale 1ns / 1ps

module tb_gcd_euclidean();

    // Inputs to the module
    reg clk;
    reg reset;
    reg start;
    reg [7:0] A_in;
    reg [7:0] B_in;

    // Outputs from the module
    wire [7:0] gcd_out;
    wire done;

    // Instantiate the Unit Under Test (UUT)
    gcd_euclidean uut (
        .clk(clk), 
        .reset(reset), 
        .start(start), 
        .A_in(A_in), 
        .B_in(B_in), 
        .gcd_out(gcd_out), 
        .done(done)
    );

    // Clock generation: Toggle every 5ns (10ns period / 100 MHz)
    always #5 clk = ~clk;

    initial begin
        // Setup GTKWave dump files
        $dumpfile("build/waveform_gcd.vcd");
        $dumpvars(0, tb_gcd_euclidean);

        // Initialize all inputs
        clk = 0;
        reset = 0;
        start = 0;
        A_in = 0;
        B_in = 0;

        // Apply Reset
        reset = 1;
        #20; // Hold reset for 2 clock cycles
        reset = 0;
        #10;

        // ----------------------------------------------------
        // Test Case 1: GCD of 48 and 18 (Expected result: 6)
        // ----------------------------------------------------
        $display("Starting Test 1: A=48, B=18");
        A_in = 8'd48;
        B_in = 8'd18;
        
        // Pulse the start signal for one clock cycle
        start = 1;
        #10;
        start = 0; 

        // Wait until the 'done' signal goes high
        wait(done == 1'b1);
        $display("Test 1 Finished. GCD = %d", gcd_out);
        #20; // Wait a bit before the next test

        // ----------------------------------------------------
        // Test Case 2: GCD of 100 and 25 (Expected result: 25)
        // ----------------------------------------------------
        $display("Starting Test 2: A=100, B=25");
        A_in = 8'd100;
        B_in = 8'd25;
        
        start = 1;
        #10;
        start = 0;
        
        wait(done == 1'b1);
        $display("Test 2 Finished. GCD = %d", gcd_out);
        #20;

        // ----------------------------------------------------
        // Test Case 3: GCD of 17 and 31 (Expected result: 1 - Coprimes)
        // ----------------------------------------------------
        $display("Starting Test 3: A=17, B=31");
        A_in = 8'd17;
        B_in = 8'd31;
        
        start = 1;
        #10;
        start = 0;
        
        wait(done == 1'b1);
        $display("Test 3 Finished. GCD = %d", gcd_out);
        #20;

        // End the simulation
        $display("All tests completed.");
        $finish;
    end
    
endmodule
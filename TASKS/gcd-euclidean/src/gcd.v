module gcd_euclidean (
    input wire clk,           // System clock
    input wire reset,         // Asynchronous reset (active high)
    input wire start,         // Signal to start the calculation
    input wire [7:0] A_in,    // 8-bit input A
    input wire [7:0] B_in,    // 8-bit input B
    output reg [7:0] gcd_out, // 8-bit output for the GCD result
    output reg done           // High when the calculation is complete
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam CALC = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [7:0] A_reg;
    reg [7:0] B_reg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all registers to default values
            state <= IDLE;
            A_reg <= 8'b0;
            B_reg <= 8'b0;
            gcd_out <= 8'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load inputs into internal registers and start computing
                        A_reg <= A_in;
                        B_reg <= B_in;
                        state <= CALC;
                    end
                end

                CALC: begin
                    // Edge cases: if one is 0, the other is the GCD
                    if (A_reg == 8'b0) begin
                        gcd_out <= B_reg;
                        state <= DONE;
                    end else if (B_reg == 8'b0) begin
                        gcd_out <= A_reg;
                        state <= DONE;
                    end 
                    // Main Euclidean algorithm logic
                    else if (A_reg == B_reg) begin
                        gcd_out <= A_reg; // Found the GCD
                        state <= DONE;
                    end else if (A_reg > B_reg) begin
                        A_reg <= A_reg - B_reg; // Subtract smaller from larger
                    end else begin
                        B_reg <= B_reg - A_reg; // Subtract smaller from larger
                    end
                end

                DONE: begin
                    // Output the done signal and return to IDLE
                    done <= 1'b1;
                    state <= IDLE; 
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
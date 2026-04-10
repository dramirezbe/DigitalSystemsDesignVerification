
`timescale 1ns / 1ps

module isqrt (
    input  wire        clk,       // System clock (rising edge)
    input  wire        reset,     // Synchronous-high reset
    input  wire        start,     // Pulse high for one cycle to begin
    input  wire [15:0] data_in,   // 16-bit unsigned radicand
    output reg         done,      // High for exactly one cycle when result is valid
    output reg  [7:0]  data_out   // Floor integer square root result
);

    // --------------------------------------------------------
    // State encoding — 3 states need only 2 bits
    // --------------------------------------------------------
    localparam [1:0] IDLE = 2'b00;  // Awaiting start pulse
    localparam [1:0] CALC = 2'b01;  // Iterating digit-by-digit
    localparam [1:0] DONE = 2'b10;  // Latching result, asserting done

    reg [1:0] state;

    // --------------------------------------------------------
    // Iteration counter
    // count starts at 7 and counts DOWN to 0, giving exactly
    // 8 CALC cycles (indices 7,6,5,4,3,2,1,0).
    // 4 bits are sufficient to represent 0–8.
    // --------------------------------------------------------
    reg [3:0] count;

    // --------------------------------------------------------
    // Datapath registers
    //
    //  d_reg   [15:0] : A shift register that holds the
    //                   remaining input bits.  It is shifted
    //                   left by 2 each cycle so that d_reg[15:14]
    //                   always presents the next 2-bit group.
    //
    //  acc_reg  [9:0] : Partial remainder accumulator.
    //                   10 bits = 8-bit quotient prefix shifted
    //                   left by 2, so needs 10 bits to avoid
    //                   overflow in the trial subtraction.
    //
    //  q_reg    [7:0] : The quotient being built, one bit per
    //                   iteration.  MSB is determined first.
    // --------------------------------------------------------
    reg [15:0] d_reg;
    reg  [9:0] acc_reg;
    reg  [7:0] q_reg;

    // --------------------------------------------------------
    // Combinational trial-subtraction network
    //
    // acc_shifted : Bring the next 2 input bits into the LSBs
    //              of the remainder.  The top 8 bits of acc_reg
    //              are retained; the bottom 2 are replaced.
    //              Width must be 10 bits to hold all carries.
    //
    // test_val   : Trial divisor.  Formed as {q[7:0], 2'b01}.
    //              For quotient digit n (n=0..7), the current
    //              partial quotient lives in q_reg[n:0]; the
    //              '01' suffix corresponds to the standard
    //              restoring-sqrt trial step.
    //
    // sub_res    : 11-bit signed result (1 sign + 10 magnitude).
    //              sub_res[10] == 0 → subtraction is non-negative
    //                           → quotient bit = 1, keep result
    //              sub_res[10] == 1 → subtraction is negative
    //                           → quotient bit = 0, restore acc
    //
    //  NOTE: These are wires — they are recomputed purely
    //  combinationally every cycle from the CURRENT register
    //  values.  They are NOT registered here; the always block
    //  below registers the selected result.
    // --------------------------------------------------------
    wire  [9:0] acc_shifted = {acc_reg[7:0], d_reg[15:14]};
    wire  [9:0] test_val    = {q_reg[7:0],   2'b01};
    wire [10:0] sub_res     = {1'b0, acc_shifted} - {1'b0, test_val};

    // --------------------------------------------------------
    // Sequential FSM + datapath
    // All state and register updates occur on the rising edge.
    // Reset is synchronous-high; all registers cleared.
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            state    <= IDLE;
            done     <= 1'b0;
            data_out <= 8'd0;
            d_reg    <= 16'd0;
            acc_reg  <= 10'd0;
            q_reg    <= 8'd0;
            count    <= 4'd0;
        end else begin
            case (state)

                // --------------------------------------------
                // IDLE : Hold done low.  Wait for start pulse.
                //        On start, latch the input and arm the
                //        counter for 8 iterations (count = 7).
                // --------------------------------------------
                IDLE: begin
                    done <= 1'b0;       // Clear done from previous run

                    if (start) begin
                        d_reg   <= data_in;  // Capture radicand
                        acc_reg <= 10'd0;    // Clear remainder
                        q_reg   <= 8'd0;     // Clear quotient
                        count   <= 4'd7;     // 7 down to 0 = 8 iterations
                        state   <= CALC;
                    end
                end

                // --------------------------------------------
                // CALC : One restoring-sqrt iteration.
                //
                //  Step 1 — Shift input register left by 2.
                //            The two MSBs (d_reg[15:14]) were
                //            already captured by acc_shifted
                //            (a wire) this same cycle, so we
                //            can safely shift now without
                //            losing them.
                //
                //  Step 2 — Evaluate the trial subtraction
                //            (combinational, see wires above).
                //
                //  Step 3 — Commit or restore based on sign:
                //    sub_res[10] == 0 → trial succeeded:
                //      acc_reg ← sub_res[9:0]  (keep remainder)
                //      q_reg   ← {q_reg[6:0], 1'b1}  (bit = 1)
                //    sub_res[10] == 1 → trial failed:
                //      acc_reg ← acc_shifted    (restore)
                //      q_reg   ← {q_reg[6:0], 1'b0}  (bit = 0)
                //
                //  Step 4 — Decrement counter; move to DONE
                //            when the last iteration finishes.
                // --------------------------------------------
                CALC: begin
                    // Advance the input shift register
                    d_reg <= {d_reg[13:0], 2'b00};

                    if (sub_res[10] == 1'b0) begin
                        // Non-negative: trial passed, commit
                        acc_reg <= sub_res[9:0];
                        q_reg   <= {q_reg[6:0], 1'b1};
                    end else begin
                        // Negative: trial failed, restore
                        acc_reg <= acc_shifted;
                        q_reg   <= {q_reg[6:0], 1'b0};
                    end

                    // Transition after the 8th iteration
                    if (count == 4'd0) begin
                        state <= DONE;
                    end else begin
                        count <= count - 1'b1;
                    end
                end

                // --------------------------------------------
                // DONE : Assert done for exactly one cycle.
                //        Latch the completed quotient to the
                //        output.  Return to IDLE next cycle.
                // --------------------------------------------
                DONE: begin
                    done     <= 1'b1;
                    data_out <= q_reg;
                    state    <= IDLE;
                end

                // Catch illegal state encoding — return to IDLE
                default: state <= IDLE;

            endcase
        end
    end

endmodule
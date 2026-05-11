`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ  = 27_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_en,
    input  wire [7:0] tx_data,
    output reg        tx,
    output reg        tx_busy
);

    // Compute the minimum register width needed to count up to the bit period.
    function integer calc_width;
        input integer value;
        integer v;
        begin
            v = value - 1;
            calc_width = 0;
            while (v > 0) begin
                calc_width = calc_width + 1;
                v = v >> 1;
            end
            if (calc_width == 0) begin
                calc_width = 1;
            end
        end
    endfunction

    localparam integer CLOCKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer COUNT_WIDTH    = calc_width(CLOCKS_PER_BIT);
    // Reusing the last count value keeps the state logic readable.
    localparam [COUNT_WIDTH-1:0] LAST_CLK_COUNT = CLOCKS_PER_BIT - 1;

    localparam s_IDLE  = 2'b00;
    localparam s_START = 2'b01;
    localparam s_DATA  = 2'b10;
    localparam s_STOP  = 2'b11;

    reg [1:0]  state;
    reg [COUNT_WIDTH-1:0] clk_count;
    reg [2:0]  bit_index;
    // Latch the byte at acceptance time so later input changes do not corrupt
    // the frame currently being transmitted.
    reg [7:0]  tx_data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= s_IDLE;
            clk_count   <= 0;
            bit_index   <= 0;
            tx_data_reg <= 8'h00;
            tx          <= 1'b1; // Line is high when idle
            tx_busy     <= 1'b0;
        end else begin
            case (state)
                s_IDLE: begin
                    tx        <= 1'b1;
                    clk_count <= 0;
                    bit_index <= 0;
                    
                    if (tx_en) begin
                        // Accept a new byte only while idle; the start bit will
                        // appear on the next clock when the FSM enters s_START.
                        tx_data_reg <= tx_data;
                        tx_busy     <= 1'b1;
                        state       <= s_START;
                    end else begin
                        tx_busy     <= 1'b0;
                        state       <= s_IDLE;
                    end
                end
                
                s_START: begin
                    tx <= 1'b0; // Start bit is 0
                    // Hold the start bit for exactly one UART bit period.
                    if (clk_count < LAST_CLK_COUNT) begin
                        clk_count <= clk_count + 1;
                        state     <= s_START;
                    end else begin
                        clk_count <= 0;
                        state     <= s_DATA;
                    end
                end
                
                s_DATA: begin
                    // UART sends the least-significant bit first.
                    tx <= tx_data_reg[bit_index];
                    if (clk_count < LAST_CLK_COUNT) begin
                        clk_count <= clk_count + 1;
                        state     <= s_DATA;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            // Advance to the next payload bit after a full bit time.
                            bit_index <= bit_index + 1;
                            state     <= s_DATA;
                        end else begin
                            bit_index <= 0;
                            state     <= s_STOP;
                        end
                    end
                end
                
                s_STOP: begin
                    tx <= 1'b1; // Stop bit is 1
                    // After the stop bit, control returns to idle and the module
                    // can accept another byte.
                    if (clk_count < LAST_CLK_COUNT) begin
                        clk_count <= clk_count + 1;
                        state     <= s_STOP;
                    end else begin
                        clk_count <= 0;
                        state     <= s_IDLE;
                    end
                end
                
                default: begin
                    state <= s_IDLE;
                end
            endcase
        end
    end

endmodule

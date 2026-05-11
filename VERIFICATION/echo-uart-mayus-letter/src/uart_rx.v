`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FREQ  = 27_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg [7:0]  rx_data,
    output reg        rx_done,
    output reg        rx_busy,
    output reg        rx_frame_error
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
    // Sample the candidate start bit near its center before trusting it.
    localparam integer START_TICKS    = (CLOCKS_PER_BIT > 1) ? (CLOCKS_PER_BIT / 2) : 1;
    localparam integer COUNT_WIDTH    = calc_width(CLOCKS_PER_BIT);

    localparam [COUNT_WIDTH-1:0] LAST_CLK_COUNT     = CLOCKS_PER_BIT - 1;
    localparam [COUNT_WIDTH-1:0] START_SAMPLE_COUNT = START_TICKS - 1;

    localparam s_IDLE  = 2'b00;
    localparam s_START = 2'b01;
    localparam s_DATA  = 2'b10;
    localparam s_STOP  = 2'b11;

    reg [1:0]              state;
    reg [COUNT_WIDTH-1:0]  clk_count;
    reg [2:0]              bit_index;
    // Shift register that collects the incoming byte one synchronized bit at a time.
    reg [7:0]              rx_shift;
    // Two-stage synchronizer for the asynchronous RX line plus a delayed copy to
    // detect the synchronized falling edge of the start bit.
    reg                    rx_meta;
    reg                    rx_sync;
    reg                    rx_sync_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= s_IDLE;
            clk_count      <= 0;
            bit_index      <= 0;
            rx_shift       <= 8'h00;
            rx_data        <= 8'h00;
            rx_done        <= 1'b0;
            rx_busy        <= 1'b0;
            rx_frame_error <= 1'b0;
            rx_meta        <= 1'b1;
            rx_sync        <= 1'b1;
            rx_sync_prev   <= 1'b1;
        end else begin
            // Bring the serial input into the local clock domain before any FSM
            // decision is made.
            rx_meta        <= rx;
            rx_sync        <= rx_meta;
            rx_sync_prev   <= rx_sync;
            // These outputs are single-cycle pulses, so clear them by default
            // and assert them only in the completion/error cycle below.
            rx_done        <= 1'b0;
            rx_frame_error <= 1'b0;

            case (state)
                s_IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    rx_busy   <= 1'b0;

                    if (rx_sync_prev && !rx_sync) begin
                        // A synchronized high-to-low transition is the candidate
                        // start edge of a new frame.
                        state   <= s_START;
                        rx_busy <= 1'b1;
                    end else begin
                        state <= s_IDLE;
                    end
                end

                s_START: begin
                    rx_busy <= 1'b1;

                    if (clk_count < START_SAMPLE_COUNT) begin
                        clk_count <= clk_count + 1;
                        state     <= s_START;
                    end else begin
                        clk_count <= 0;
                        if (!rx_sync) begin
                            // The line is still low at mid-start-bit, so the
                            // frame looks valid and data sampling can begin.
                            state <= s_DATA;
                        end else begin
                            // A short low pulse that disappears before the
                            // center of the start bit is treated as a false start.
                            state   <= s_IDLE;
                            rx_busy <= 1'b0;
                        end
                    end
                end

                s_DATA: begin
                    rx_busy <= 1'b1;

                    if (clk_count < LAST_CLK_COUNT) begin
                        clk_count <= clk_count + 1;
                        state     <= s_DATA;
                    end else begin
                        clk_count            <= 0;
                        // Sample one data bit per UART bit period after synchronization.
                        rx_shift[bit_index]  <= rx_sync;

                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 1;
                            state     <= s_DATA;
                        end else begin
                            bit_index <= 0;
                            state     <= s_STOP;
                        end
                    end
                end

                s_STOP: begin
                    rx_busy <= 1'b1;

                    if (clk_count < LAST_CLK_COUNT) begin
                        clk_count <= clk_count + 1;
                        state     <= s_STOP;
                    end else begin
                        clk_count <= 0;
                        state     <= s_IDLE;
                        rx_busy   <= 1'b0;

                        if (rx_sync) begin
                            // A high stop bit completes the frame and transfers
                            // the assembled byte to the output.
                            rx_data <= rx_shift;
                            rx_done <= 1'b1;
                        end else begin
                            // A low stop bit means the frame is malformed.
                            rx_frame_error <= 1'b1;
                        end
                    end
                end

                default: begin
                    state          <= s_IDLE;
                    clk_count      <= 0;
                    bit_index      <= 0;
                    rx_busy        <= 1'b0;
                    rx_done        <= 1'b0;
                    rx_frame_error <= 1'b0;
                end
            endcase
        end
    end

endmodule

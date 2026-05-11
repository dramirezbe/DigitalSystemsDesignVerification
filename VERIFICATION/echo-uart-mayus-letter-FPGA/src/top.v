`timescale 1ns / 1ps

module top #(
    parameter CLK_FREQ  = 27_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire clk,
    input  wire rst_n,
    input  wire uart_rx,
    output wire uart_tx
);

    localparam [1:0] ECHO_WAIT_RX      = 2'b00;
    localparam [1:0] ECHO_WAIT_TX_IDLE = 2'b01;
    localparam [1:0] ECHO_ASSERT_TX_EN = 2'b10;

    localparam [7:0] ASCII_LOWER_A     = 8'd97;
    localparam [7:0] ASCII_LOWER_Z     = 8'd122;
    localparam [7:0] ASCII_CASE_OFFSET = 8'd32;

    reg [1:0] echo_state;
    reg       tx_en_reg;
    reg [7:0] tx_data_reg;

    // Keep the internal signal names stable so the simulation testbench can
    // still observe the controller behavior hierarchically, while the external
    // ports stay minimal and board-oriented for FPGA implementation.
    wire       tx;
    wire       tx_busy;
    wire [7:0] rx_data;
    wire       rx_done;
    wire       rx_busy;
    wire       rx_frame_error;

    assign uart_tx = tx;

    // Echo controller:
    // - wait for a received byte
    // - convert lowercase ASCII to uppercase
    // - wait for the UART transmitter to go idle
    // - hold tx_en until uart_tx acknowledges with tx_busy
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            echo_state  <= ECHO_WAIT_RX;
            tx_en_reg   <= 1'b0;
            tx_data_reg <= 8'h00;
        end else begin
            case (echo_state)
                ECHO_WAIT_RX: begin
                    tx_en_reg <= 1'b0;

                    if (rx_done) begin
                        if ((rx_data >= ASCII_LOWER_A) && (rx_data <= ASCII_LOWER_Z)) begin
                            tx_data_reg <= rx_data - ASCII_CASE_OFFSET;
                        end else begin
                            tx_data_reg <= rx_data;
                        end
                        echo_state <= ECHO_WAIT_TX_IDLE;
                    end
                end

                ECHO_WAIT_TX_IDLE: begin
                    tx_en_reg <= 1'b0;

                    if (!tx_busy) begin
                        tx_en_reg <= 1'b1;
                        echo_state <= ECHO_ASSERT_TX_EN;
                    end
                end

                ECHO_ASSERT_TX_EN: begin
                    if (tx_busy) begin
                        tx_en_reg <= 1'b0;
                        echo_state <= ECHO_WAIT_RX;
                    end else begin
                        tx_en_reg <= 1'b1;
                    end
                end

                default: begin
                    echo_state <= ECHO_WAIT_RX;
                    tx_en_reg  <= 1'b0;
                end
            endcase
        end
    end

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tx_en(tx_en_reg),
        .tx_data(tx_data_reg),
        .tx(tx),
        .tx_busy(tx_busy)
    );

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .rx_busy(rx_busy),
        .rx_frame_error(rx_frame_error)
    );

endmodule

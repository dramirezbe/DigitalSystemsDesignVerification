`timescale 1ns / 1ps

module top #(
    parameter CLK_FREQ  = 27_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output wire       tx,
    output wire       tx_busy,
    output wire [7:0] rx_data,
    output wire       rx_done,
    output wire       rx_busy,
    output wire       rx_frame_error
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

    // Reuse the existing UART blocks and add a small controller on top that:
    // 1) waits for a received byte,
    // 2) converts lowercase ASCII to uppercase,
    // 3) waits for TX to become idle,
    // 4) holds tx_en until the transmitter acknowledges with tx_busy.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            echo_state <= ECHO_WAIT_RX;
            tx_en_reg  <= 1'b0;
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
                        tx_en_reg  <= 1'b1;
                        echo_state <= ECHO_ASSERT_TX_EN;
                    end
                end

                ECHO_ASSERT_TX_EN: begin
                    if (tx_busy) begin
                        tx_en_reg  <= 1'b0;
                        echo_state <= ECHO_WAIT_RX;
                    end else begin
                        tx_en_reg  <= 1'b1;
                        echo_state <= ECHO_ASSERT_TX_EN;
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
        .rx(rx),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .rx_busy(rx_busy),
        .rx_frame_error(rx_frame_error)
    );

endmodule

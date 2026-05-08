`timescale 1ns / 1ps

module top #(
    parameter CLK_FREQ  = 27_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst_n,   // Shared active-low reset for both UART directions
    input  wire       tx_en,
    input  wire [7:0] tx_data,
    input  wire       rx,      // Independent receive line for full-duplex operation
    output wire       tx,      // Independent transmit line for full-duplex operation
    output wire       tx_busy,
    output wire [7:0] rx_data,
    output wire       rx_done,
    output wire       rx_busy,
    output wire       rx_frame_error
);

    // TX and RX remain fully independent so the system can transmit and receive
    // at the same time while sharing the same active-low reset.
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tx_en(tx_en),
        .tx_data(tx_data),
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

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

    localparam CLOCKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam s_IDLE  = 2'b00;
    localparam s_START = 2'b01;
    localparam s_DATA  = 2'b10;
    localparam s_STOP  = 2'b11;

    reg [1:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
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
                    if (clk_count < CLOCKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                        state     <= s_START;
                    end else begin
                        clk_count <= 0;
                        state     <= s_DATA;
                    end
                end
                
                s_DATA: begin
                    tx <= tx_data_reg[bit_index];
                    if (clk_count < CLOCKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                        state     <= s_DATA;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
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
                    if (clk_count < CLOCKS_PER_BIT - 1) begin
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

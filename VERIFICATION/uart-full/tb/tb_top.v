`timescale 1ns / 1ps

module tb_top;

    localparam integer CLK_FREQ       = 100_000;
    localparam integer BAUD_RATE      = 1_000;
    localparam integer CLOCKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer CLK_PERIOD_NS  = 10;
    localparam integer BIT_PERIOD_NS  = CLOCKS_PER_BIT * CLK_PERIOD_NS;

    reg        clk;
    reg        rst_n;
    reg        tx_en;
    reg [7:0]  tx_data;
    reg        use_loopback;
    reg        ext_rx;
    wire       rx_line;
    wire       tx;
    wire       tx_busy;
    wire [7:0] rx_data;
    wire       rx_done;
    wire       rx_busy;
    wire       rx_frame_error;

    integer cycle_count;
    integer total_checks;
    integer failures;
    integer case_count;
    integer case_fail_checkpoint;

    reg [8*80-1:0] active_case;

    assign rx_line = use_loopback ? tx : ext_rx;

    top #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_en(tx_en),
        .tx_data(tx_data),
        .rx(rx_line),
        .tx(tx),
        .tx_busy(tx_busy),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .rx_busy(rx_busy),
        .rx_frame_error(rx_frame_error)
    );

    initial begin
        clk                  = 1'b0;
        rst_n                = 1'b0;
        tx_en                = 1'b0;
        tx_data              = 8'h00;
        use_loopback         = 1'b0;
        ext_rx               = 1'b1;
        cycle_count          = 0;
        total_checks         = 0;
        failures             = 0;
        case_count           = 0;
        case_fail_checkpoint = 0;
        active_case          = "none";
    end

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
    end

    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
    end

    initial begin
        #(CLK_PERIOD_NS * CLOCKS_PER_BIT * 1200);
        $display("FAIL: simulation timeout");
        finish_and_report();
    end

    task begin_case;
        input [8*80-1:0] case_name;
        begin
            case_count = case_count + 1;
            active_case = case_name;
            case_fail_checkpoint = failures;
            $display("");
            $display("=== Case %0d: %0s ===", case_count, case_name);
        end
    endtask

    task end_case;
        begin
            if (failures == case_fail_checkpoint) begin
                $display("CASE PASS: %0s", active_case);
            end else begin
                $display("CASE FAIL: %0s", active_case);
            end
        end
    endtask

    task check_true;
        input condition;
        input [8*120-1:0] message;
        begin
            total_checks = total_checks + 1;
            if (!condition) begin
                failures = failures + 1;
                $display("FAIL @ cycle %0d: %0s", cycle_count, message);
            end
        end
    endtask

    task check_byte;
        input [7:0] actual;
        input [7:0] expected;
        input [8*120-1:0] message;
        begin
            total_checks = total_checks + 1;
            if (actual !== expected) begin
                failures = failures + 1;
                $display("FAIL @ cycle %0d: %0s expected=%02h got=%02h", cycle_count, message, expected, actual);
            end
        end
    endtask

    task wait_cycles;
        input integer count;
        integer i;
        begin
            for (i = 0; i < count; i = i + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task wait_for_tx_idle;
        begin
            while ((tx_busy !== 1'b0) || (tx !== 1'b1)) begin
                @(posedge clk);
            end
        end
    endtask

    task wait_for_tx_busy_assert;
        integer waited;
        integer found;
        begin
            waited = 0;
            found = 0;
            while ((waited < (CLOCKS_PER_BIT + 20)) && (found == 0)) begin
                @(posedge clk);
                #1;
                if (tx_busy === 1'b1) begin
                    found = 1;
                end
                waited = waited + 1;
            end
            check_true(found == 1, "tx_busy must assert when the transmitter starts a frame");
        end
    endtask

    task wait_for_rx_done_event;
        input [7:0] expected_data;
        integer waited;
        begin
            waited = 0;
            while ((rx_done !== 1'b1) && (waited < (12 * CLOCKS_PER_BIT))) begin
                @(posedge clk);
                #1;
                waited = waited + 1;
            end

            check_true(rx_done === 1'b1, "rx_done must pulse after a complete frame");
            if (rx_done === 1'b1) begin
                check_byte(rx_data, expected_data, "rx_data must match the received byte");
                check_true(rx_frame_error === 1'b0, "rx_frame_error must stay low for valid traffic");
                check_true(rx_busy === 1'b0, "rx_busy must clear when rx_done pulses");
                @(posedge clk);
                #1;
                check_true(rx_done === 1'b0, "rx_done must be one clock wide");
            end
        end
    endtask

    task wait_for_rx_busy_assert;
        integer waited;
        integer found;
        begin
            waited = 0;
            found = 0;
            while ((waited < (CLOCKS_PER_BIT + 20)) && (found == 0)) begin
                @(posedge clk);
                #1;
                if (rx_busy === 1'b1) begin
                    found = 1;
                end
                waited = waited + 1;
            end
            check_true(found == 1, "rx_busy must assert when the receiver sees a frame");
        end
    endtask

    task reset_dut;
        begin
            @(negedge clk);
            rst_n        = 1'b0;
            tx_en        = 1'b0;
            tx_data      = 8'h00;
            use_loopback = 1'b0;
            ext_rx       = 1'b1;

            #1;
            check_true(tx === 1'b1, "tx must go high during reset");
            check_true(tx_busy === 1'b0, "tx_busy must be low during reset");
            check_true(rx_busy === 1'b0, "rx_busy must be low during reset");
            check_true(rx_done === 1'b0, "rx_done must be low during reset");
            check_true(rx_frame_error === 1'b0, "rx_frame_error must be low during reset");
            check_byte(rx_data, 8'h00, "rx_data must clear during reset");

            repeat (2) @(posedge clk);
            #1;
            check_true(tx === 1'b1, "tx must stay high while reset is asserted");
            check_true(tx_busy === 1'b0, "tx_busy must stay low while reset is asserted");

            @(negedge clk);
            rst_n = 1'b1;

            @(posedge clk);
            #1;
            check_true(tx === 1'b1, "tx must remain high after reset release");
            check_true(tx_busy === 1'b0, "tx_busy must remain low after reset release");
            check_true(rx_busy === 1'b0, "rx_busy must remain low after reset release");
        end
    endtask

    task request_tx_byte;
        input [7:0] data_byte;
        begin
            wait_for_tx_idle();
            @(negedge clk);
            tx_data = data_byte;
            tx_en   = 1'b1;
            @(posedge clk);
            #1;
            check_true(tx_busy === 1'b1, "tx_busy must assert when a transmit request is accepted");
            @(negedge clk);
            tx_en = 1'b0;
        end
    endtask

    task send_byte_async;
        input [7:0] data_byte;
        input integer start_offset_ns;
        integer i;
        begin
            ext_rx = 1'b1;
            @(posedge clk);
            #(start_offset_ns);
            ext_rx = 1'b0;
            #(BIT_PERIOD_NS);

            for (i = 0; i < 8; i = i + 1) begin
                ext_rx = data_byte[i];
                #(BIT_PERIOD_NS);
            end

            ext_rx = 1'b1;
            #(BIT_PERIOD_NS);
        end
    endtask

    task exercise_external_receive;
        input [7:0] data_byte;
        input integer start_offset_ns;
        begin
            use_loopback = 1'b0;
            ext_rx       = 1'b1;
            fork
                send_byte_async(data_byte, start_offset_ns);
                begin
                    wait_for_rx_busy_assert();
                    wait_for_rx_done_event(data_byte);
                end
            join
        end
    endtask

    task exercise_loopback_transfer;
        input [7:0] data_byte;
        begin
            use_loopback = 1'b1;
            ext_rx       = 1'b1;
            request_tx_byte(data_byte);
            wait_for_rx_busy_assert();
            wait_for_rx_done_event(data_byte);
            wait_for_tx_idle();
            wait_cycles(2);
            #1;
            check_true(tx === 1'b1, "tx must return to idle-high after loopback traffic");
            check_true(tx_busy === 1'b0, "tx_busy must clear after loopback traffic");
        end
    endtask

    task exercise_full_duplex_transfer;
        input [7:0] tx_byte;
        input [7:0] rx_byte;
        input integer start_offset_ns;
        begin
            use_loopback = 1'b0;
            ext_rx       = 1'b1;

            fork
                begin
                    request_tx_byte(tx_byte);
                end
                begin
                    send_byte_async(rx_byte, start_offset_ns);
                end
                begin
                    wait_for_tx_busy_assert();
                    wait_for_rx_busy_assert();
                    check_true(tx_busy === 1'b1, "tx and rx must overlap during full-duplex traffic");
                    wait_for_rx_done_event(rx_byte);
                end
            join

            wait_for_tx_idle();
            wait_cycles(2);
            #1;
            check_true(tx === 1'b1, "tx must return to idle-high after full-duplex traffic");
            check_true(tx_busy === 1'b0, "tx_busy must clear after full-duplex traffic");
            check_true(rx_busy === 1'b0, "rx_busy must clear after full-duplex traffic");
        end
    endtask

    task finish_and_report;
        begin
            $display("");
            $display("=== Testbench Summary ===");
            $display("CLOCKS_PER_BIT used by TB: %0d", CLOCKS_PER_BIT);
            $display("Cases executed          : %0d", case_count);
            $display("Checks executed         : %0d", total_checks);
            $display("Failures                : %0d", failures);

            if (failures == 0) begin
                $display("FINAL RESULT: PASS");
            end else begin
                $display("FINAL RESULT: FAIL");
            end

            $finish;
        end
    endtask

    initial begin
        begin_case("active-low reset behavior");
        reset_dut();
        end_case();

        begin_case("external receive path through top");
        reset_dut();
        exercise_external_receive(8'hA5, 3);
        end_case();

        begin_case("simultaneous independent tx and rx");
        reset_dut();
        exercise_full_duplex_transfer(8'h3C, 8'hA5, 3);
        end_case();

        begin_case("single tx to rx loopback");
        reset_dut();
        exercise_loopback_transfer(8'h3C);
        end_case();

        begin_case("back-to-back loopback transfers");
        reset_dut();
        exercise_loopback_transfer(8'h96);
        exercise_loopback_transfer(8'h69);
        end_case();

        finish_and_report();
    end

endmodule

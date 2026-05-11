`timescale 1ns / 1ps

module tb_top_echo;

    localparam integer CLK_FREQ       = 100_000;
    localparam integer BAUD_RATE      = 1_000;
    localparam integer CLOCKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer CLK_PERIOD_NS  = 10;
    localparam integer BIT_PERIOD_NS  = CLOCKS_PER_BIT * CLK_PERIOD_NS;

    reg        clk;
    reg        rst_n;
    reg        ext_rx;

    wire       tx;
    wire       tx_busy;
    wire [7:0] rx_data;
    wire       rx_done;
    wire       rx_busy;
    wire       rx_frame_error;

    wire [7:0] mon_rx_data;
    wire       mon_rx_done;
    wire       mon_rx_busy;
    wire       mon_rx_frame_error;

    integer cycle_count;
    integer total_checks;
    integer failures;
    integer case_count;
    integer case_fail_checkpoint;

    reg [8*80-1:0] active_case;

    top #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(ext_rx),
        .uart_tx(tx)
    );

    assign tx_busy        = dut.tx_busy;
    assign rx_data        = dut.rx_data;
    assign rx_done        = dut.rx_done;
    assign rx_busy        = dut.rx_busy;
    assign rx_frame_error = dut.rx_frame_error;

    // Decode the DUT TX line with the same receiver block used in the design so
    // the testbench checks the serial echo path end-to-end.
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) tx_monitor (
        .clk(clk),
        .rst_n(rst_n),
        .rx(tx),
        .rx_data(mon_rx_data),
        .rx_done(mon_rx_done),
        .rx_busy(mon_rx_busy),
        .rx_frame_error(mon_rx_frame_error)
    );

    initial begin
        clk                  = 1'b0;
        rst_n                = 1'b0;
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
        $dumpfile("tb_top_echo.vcd");
        $dumpvars(0, tb_top_echo);
    end

    initial begin
        #(CLK_PERIOD_NS * CLOCKS_PER_BIT * 4000);
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

    task wait_for_dut_rx_done;
        input [7:0] expected_data;
        integer waited;
        begin
            waited = 0;
            while ((rx_done !== 1'b1) && (waited < (15 * CLOCKS_PER_BIT))) begin
                @(posedge clk);
                #1;
                waited = waited + 1;
            end

            check_true(rx_done === 1'b1, "dut rx_done must pulse after receiving a byte");
            if (rx_done === 1'b1) begin
                check_byte(rx_data, expected_data, "dut rx_data must match the serial byte driven into rx");
                check_true(rx_frame_error === 1'b0, "dut rx_frame_error must stay low for valid traffic");
                @(posedge clk);
                #1;
                check_true(rx_done === 1'b0, "dut rx_done must be one clock wide");
            end
        end
    endtask

    task wait_for_tx_busy_assert;
        integer waited;
        integer found;
        begin
            waited = 0;
            found = 0;
            while ((waited < (4 * CLOCKS_PER_BIT)) && (found == 0)) begin
                @(posedge clk);
                #1;
                if (tx_busy === 1'b1) begin
                    found = 1;
                end
                waited = waited + 1;
            end
            check_true(found == 1, "tx_busy must assert when the echo byte is launched");
        end
    endtask

    task wait_for_tx_idle;
        integer waited;
        integer done;
        begin
            waited = 0;
            done = 0;
            while ((waited < (15 * CLOCKS_PER_BIT)) && (done == 0)) begin
                @(posedge clk);
                #1;
                if ((tx_busy === 1'b0) && (tx === 1'b1)) begin
                    done = 1;
                end
                waited = waited + 1;
            end
            check_true(done == 1, "tx must eventually return to idle after the echo frame");
        end
    endtask

    task wait_for_monitor_done;
        input [7:0] expected_data;
        integer waited;
        begin
            waited = 0;
            while ((mon_rx_done !== 1'b1) && (waited < (30 * CLOCKS_PER_BIT))) begin
                @(posedge clk);
                #1;
                waited = waited + 1;
            end

            check_true(mon_rx_done === 1'b1, "monitor rx_done must pulse after the echo frame");
            if (mon_rx_done === 1'b1) begin
                check_byte(mon_rx_data, expected_data, "echoed byte on tx must match the expected uppercase/pass-through value");
                check_true(mon_rx_frame_error === 1'b0, "monitor must not detect a frame error on the echoed byte");
                @(posedge clk);
                #1;
                check_true(mon_rx_done === 1'b0, "monitor rx_done must be one clock wide");
            end
        end
    endtask

    task reset_dut;
        begin
            @(negedge clk);
            rst_n  = 1'b0;
            ext_rx = 1'b1;

            #1;
            check_true(tx === 1'b1, "tx must be idle-high during reset");
            check_true(tx_busy === 1'b0, "tx_busy must stay low during reset");
            check_true(rx_busy === 1'b0, "dut rx_busy must stay low during reset");
            check_true(rx_done === 1'b0, "dut rx_done must stay low during reset");
            check_true(mon_rx_busy === 1'b0, "monitor rx_busy must stay low during reset");
            check_true(mon_rx_done === 1'b0, "monitor rx_done must stay low during reset");

            repeat (2) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;

            @(posedge clk);
            #1;
            check_true(tx === 1'b1, "tx must remain idle-high after reset release");
            check_true(tx_busy === 1'b0, "tx_busy must remain low after reset release");
            check_true(rx_busy === 1'b0, "dut rx_busy must remain low after reset release");
            check_true(mon_rx_busy === 1'b0, "monitor rx_busy must remain low after reset release");
        end
    endtask

    task exercise_echo_byte;
        input [7:0] input_data;
        input [7:0] expected_echo;
        begin
            ext_rx = 1'b1;

            fork
                begin
                    send_byte_async(input_data, 3);
                end
                begin
                    wait_for_dut_rx_done(input_data);
                    wait_for_tx_busy_assert();
                    wait_for_monitor_done(expected_echo);
                end
            join

            wait_for_tx_idle();
            wait_cycles(2);
            #1;
            check_true(tx === 1'b1, "tx must return to idle-high after the echo frame");
            check_true(tx_busy === 1'b0, "tx_busy must clear after the echo frame");
            check_true(rx_busy === 1'b0, "dut rx_busy must clear after the echo frame");
            check_true(mon_rx_busy === 1'b0, "monitor rx_busy must clear after the echo frame");
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

        begin_case("lowercase a echoes as uppercase A");
        reset_dut();
        exercise_echo_byte("a", "A");
        end_case();

        begin_case("lowercase z echoes as uppercase Z");
        reset_dut();
        exercise_echo_byte("z", "Z");
        end_case();

        begin_case("uppercase stays unchanged");
        reset_dut();
        exercise_echo_byte("Q", "Q");
        end_case();

        begin_case("digit stays unchanged");
        reset_dut();
        exercise_echo_byte("7", "7");
        end_case();

        begin_case("sequential mixed characters");
        reset_dut();
        exercise_echo_byte("m", "M");
        exercise_echo_byte("B", "B");
        exercise_echo_byte("?", "?");
        end_case();

        finish_and_report();
    end

endmodule

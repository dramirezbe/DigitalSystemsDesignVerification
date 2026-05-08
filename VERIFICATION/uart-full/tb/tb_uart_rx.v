`timescale 1ns / 1ps

module tb_uart_rx;

    localparam integer CLK_FREQ       = 100_000;
    localparam integer BAUD_RATE      = 1_000;
    localparam integer CLOCKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer CLK_PERIOD_NS  = 10;
    localparam integer BIT_PERIOD_NS  = CLOCKS_PER_BIT * CLK_PERIOD_NS;

    reg       clk;
    reg       rst_n;
    reg       rx;
    wire [7:0] rx_data;
    wire      rx_done;
    wire      rx_busy;
    wire      rx_frame_error;

    integer cycle_count;
    integer total_checks;
    integer failures;
    integer case_count;
    integer case_fail_checkpoint;

    reg [8*80-1:0] active_case;

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .rx_busy(rx_busy),
        .rx_frame_error(rx_frame_error)
    );

    initial begin
        clk                  = 1'b0;
        rst_n                = 1'b0;
        rx                   = 1'b1;
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
        $dumpfile("tb_uart_rx.vcd");
        $dumpvars(0, tb_uart_rx);
    end

    initial begin
        #(CLK_PERIOD_NS * CLOCKS_PER_BIT * 900);
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

    task wait_for_idle;
        begin
            while ((rx_busy !== 1'b0) || (rx_done !== 1'b0) || (rx_frame_error !== 1'b0)) begin
                @(posedge clk);
            end
        end
    endtask

    task wait_for_idle_within;
        input integer limit;
        input [8*120-1:0] message;
        integer i;
        integer found;
        begin
            found = 0;
            for (i = 0; i < limit; i = i + 1) begin
                @(posedge clk);
                #1;
                if ((found == 0) && (rx_busy === 1'b0)) begin
                    found = 1;
                end
            end
            check_true(found == 1, message);
        end
    endtask

    task wait_for_busy_assert;
        output integer busy_cycle;
        integer i;
        integer found;
        begin
            busy_cycle = -1;
            found = 0;
            for (i = 0; i < CLOCKS_PER_BIT + 20; i = i + 1) begin
                @(posedge clk);
                #1;
                if ((found == 0) && (rx_busy === 1'b1)) begin
                    found = 1;
                    busy_cycle = cycle_count;
                end
            end
            check_true(found == 1, "rx_busy must assert after a valid start edge reaches the synchronizer");
        end
    endtask

    task wait_for_done_event;
        input [7:0] expected_data;
        integer waited;
        begin
            waited = 0;
            while ((rx_done !== 1'b1) && (waited < (12 * CLOCKS_PER_BIT))) begin
                @(posedge clk);
                #1;
                waited = waited + 1;
            end

            check_true(rx_done === 1'b1, "rx_done must pulse after a valid frame");
            if (rx_done === 1'b1) begin
                check_byte(rx_data, expected_data, "rx_data must match the received byte");
                check_true(rx_frame_error === 1'b0, "rx_frame_error must stay low for a valid frame");
                check_true(rx_busy === 1'b0, "rx_busy must clear in the completion cycle");
                @(posedge clk);
                #1;
                check_true(rx_done === 1'b0, "rx_done must be one clock wide");
            end
        end
    endtask

    task wait_for_error_event;
        integer waited;
        begin
            waited = 0;
            while ((rx_frame_error !== 1'b1) && (waited < (12 * CLOCKS_PER_BIT))) begin
                @(posedge clk);
                #1;
                waited = waited + 1;
            end

            check_true(rx_frame_error === 1'b1, "rx_frame_error must pulse after a bad stop bit");
            if (rx_frame_error === 1'b1) begin
                check_true(rx_done === 1'b0, "rx_done must stay low on a framing error");
                check_true(rx_busy === 1'b0, "rx_busy must clear in the framing-error cycle");
                @(posedge clk);
                #1;
                check_true(rx_frame_error === 1'b0, "rx_frame_error must be one clock wide");
            end
        end
    endtask

    task observe_no_completion_or_error;
        input integer window_cycles;
        output integer saw_pulse;
        integer i;
        begin
            saw_pulse = 0;
            for (i = 0; i < window_cycles; i = i + 1) begin
                @(posedge clk);
                #1;
                if ((rx_done === 1'b1) || (rx_frame_error === 1'b1)) begin
                    saw_pulse = 1;
                end
            end
        end
    endtask

    task reset_dut;
        begin
            @(negedge clk);
            rst_n = 1'b0;
            rx    = 1'b1;

            #1;
            check_true(rx_busy === 1'b0, "rx_busy must be low during reset");
            check_true(rx_done === 1'b0, "rx_done must be low during reset");
            check_true(rx_frame_error === 1'b0, "rx_frame_error must be low during reset");
            check_byte(rx_data, 8'h00, "rx_data must clear during reset");

            repeat (2) @(posedge clk);
            #1;
            check_true(rx_busy === 1'b0, "rx_busy must stay low while reset is asserted");
            check_true(rx_done === 1'b0, "rx_done must stay low while reset is asserted");

            @(negedge clk);
            rst_n = 1'b1;

            @(posedge clk);
            #1;
            check_true(rx_busy === 1'b0, "rx_busy must remain low after reset release");
            check_true(rx_done === 1'b0, "rx_done must remain low after reset release");
            check_true(rx_frame_error === 1'b0, "rx_frame_error must remain low after reset release");
        end
    endtask

    task send_byte_async;
        input [7:0] data_byte;
        input integer start_offset_ns;
        integer i;
        begin
            rx = 1'b1;
            @(posedge clk);
            #(start_offset_ns);
            rx = 1'b0;
            #(BIT_PERIOD_NS);

            for (i = 0; i < 8; i = i + 1) begin
                rx = data_byte[i];
                #(BIT_PERIOD_NS);
            end

            rx = 1'b1;
            #(BIT_PERIOD_NS);
        end
    endtask

    task send_two_bytes_async;
        input [7:0] first_byte;
        input [7:0] second_byte;
        input integer start_offset_ns;
        integer i;
        begin
            rx = 1'b1;
            @(posedge clk);
            #(start_offset_ns);

            rx = 1'b0;
            #(BIT_PERIOD_NS);
            for (i = 0; i < 8; i = i + 1) begin
                rx = first_byte[i];
                #(BIT_PERIOD_NS);
            end
            rx = 1'b1;
            #(BIT_PERIOD_NS);

            rx = 1'b0;
            #(BIT_PERIOD_NS);
            for (i = 0; i < 8; i = i + 1) begin
                rx = second_byte[i];
                #(BIT_PERIOD_NS);
            end
            rx = 1'b1;
            #(BIT_PERIOD_NS);
        end
    endtask

    task send_byte_with_bad_stop_async;
        input [7:0] data_byte;
        input integer start_offset_ns;
        integer i;
        begin
            rx = 1'b1;
            @(posedge clk);
            #(start_offset_ns);
            rx = 1'b0;
            #(BIT_PERIOD_NS);

            for (i = 0; i < 8; i = i + 1) begin
                rx = data_byte[i];
                #(BIT_PERIOD_NS);
            end

            rx = 1'b0;
            #(BIT_PERIOD_NS);
            rx = 1'b1;
            #(BIT_PERIOD_NS);
        end
    endtask

    task send_false_start_async;
        input integer start_offset_ns;
        begin
            rx = 1'b1;
            @(posedge clk);
            #(start_offset_ns);
            rx = 1'b0;
            #(BIT_PERIOD_NS / 3);
            rx = 1'b1;
            #(BIT_PERIOD_NS);
        end
    endtask

    task exercise_good_frame;
        input [7:0] data_byte;
        input integer start_offset_ns;
        integer busy_cycle;
        begin
            fork
                send_byte_async(data_byte, start_offset_ns);
                begin
                    wait_for_busy_assert(busy_cycle);
                    wait_for_done_event(data_byte);
                end
            join

            wait_cycles(2);
            #1;
            check_true(rx_busy === 1'b0, "rx_busy must remain low after a valid frame completes");
            check_true(rx_frame_error === 1'b0, "rx_frame_error must remain low after a valid frame completes");
        end
    endtask

    task exercise_false_start;
        input integer start_offset_ns;
        integer busy_cycle;
        integer saw_pulse;
        begin
            fork
                send_false_start_async(start_offset_ns);
                begin
                    wait_for_busy_assert(busy_cycle);
                    observe_no_completion_or_error((2 * CLOCKS_PER_BIT) + 10, saw_pulse);
                end
            join

            check_true(saw_pulse == 0, "a false start must not generate rx_done or rx_frame_error");
            wait_for_idle_within(CLOCKS_PER_BIT + 10, "rx_busy must clear after the false start is rejected");
        end
    endtask

    task exercise_bad_stop_frame;
        input [7:0] data_byte;
        input integer start_offset_ns;
        integer busy_cycle;
        begin
            fork
                send_byte_with_bad_stop_async(data_byte, start_offset_ns);
                begin
                    wait_for_busy_assert(busy_cycle);
                    wait_for_error_event();
                end
            join

            wait_cycles(2);
            #1;
            check_true(rx_done === 1'b0, "rx_done must stay low after a framing error");
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
        begin_case("reset behavior");
        reset_dut();
        end_case();

        begin_case("single asynchronous nominal reception");
        reset_dut();
        exercise_good_frame(8'hA5, 3);
        end_case();

        begin_case("pattern sensitivity and LSB-first decoding");
        reset_dut();
        exercise_good_frame(8'h00, 7);
        exercise_good_frame(8'hFF, 1);
        exercise_good_frame(8'h55, 6);
        exercise_good_frame(8'hAA, 2);
        exercise_good_frame(8'h3C, 5);
        end_case();

        begin_case("false start is rejected");
        reset_dut();
        exercise_false_start(4);
        end_case();

        begin_case("bad stop bit raises framing error");
        reset_dut();
        exercise_bad_stop_frame(8'hC3, 3);
        end_case();

        begin_case("back-to-back legal receptions");
        reset_dut();
        fork
            send_two_bytes_async(8'h96, 8'h69, 2);
            begin
                wait_for_done_event(8'h96);
                wait_for_done_event(8'h69);
            end
        join
        wait_for_idle();
        end_case();

        finish_and_report();
    end

endmodule

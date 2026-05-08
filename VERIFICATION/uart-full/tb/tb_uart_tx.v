`timescale 1ns / 1ps

module tb_uart_tx;

    // Tested cases highlighted by the testbench:
    // 1. Reset behavior
    // 2. Single nominal transmission
    // 3. Pattern sensitivity / LSB-first confidence
    // 4. Data capture vs later tx_data changes
    // 5. Short overlapping request while busy (must be ignored)
    // 6. Held-high tx_en semantics (legal immediate reacceptance)
    // 7. Back-to-back legal transmissions
    //
    // The DUT is instantiated with a smaller CLOCKS_PER_BIT value than the
    // default RTL configuration so simulation remains fast while still keeping
    // the clock two orders of magnitude faster than the baud rate.

    localparam integer CLK_FREQ       = 100_000;
    localparam integer BAUD_RATE      = 1_000;
    localparam integer CLOCKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer CLK_PERIOD_NS  = 10;

    reg        clk;
    reg        rst_n;
    reg        tx_en;
    reg [7:0]  tx_data;
    wire       tx;
    wire       tx_busy;

    integer cycle_count;
    integer total_checks;
    integer failures;
    integer case_count;
    integer case_fail_checkpoint;
    integer accept_cycle;
    integer accept_cycle_2;

    reg [8*80-1:0] active_case;

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_en(tx_en),
        .tx_data(tx_data),
        .tx(tx),
        .tx_busy(tx_busy)
    );

    initial begin
        clk         = 1'b0;
        rst_n       = 1'b0;
        tx_en       = 1'b0;
        tx_data     = 8'h00;
        cycle_count = 0;
        total_checks = 0;
        failures    = 0;
        case_count  = 0;
        case_fail_checkpoint = 0;
        active_case = "none";
    end

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
    end

    initial begin
        $dumpfile("tb_uart_tx.vcd");
        $dumpvars(0, tb_uart_tx);
    end

    initial begin
        #(CLK_PERIOD_NS * CLOCKS_PER_BIT * 600);
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
            while ((tx_busy !== 1'b0) || (tx !== 1'b1)) begin
                @(posedge clk);
            end
        end
    endtask

    task reset_dut;
        begin
            @(negedge clk);
            rst_n   = 1'b0;
            tx_en   = 1'b0;
            tx_data = 8'h00;

            #1;
            check_true(tx === 1'b1, "tx must go high immediately on reset");
            check_true(tx_busy === 1'b0, "tx_busy must go low immediately on reset");

            repeat (2) @(posedge clk);
            check_true(tx === 1'b1, "tx must remain high while reset is asserted");
            check_true(tx_busy === 1'b0, "tx_busy must remain low while reset is asserted");

            @(negedge clk);
            rst_n = 1'b1;

            @(posedge clk);
            check_true(tx === 1'b1, "tx must remain high after reset release");
            check_true(tx_busy === 1'b0, "tx_busy must remain low after reset release");
        end
    endtask

    task request_byte;
        input [7:0] data_byte;
        output integer accepted_cycle;
        begin
            wait_for_idle();

            @(negedge clk);
            tx_data = data_byte;
            tx_en   = 1'b1;

            @(posedge clk);
            #1;
            accepted_cycle = cycle_count;
            check_true(tx_busy === 1'b1, "tx_busy must assert when a request is accepted");
            check_true(tx === 1'b1, "tx must remain idle-high in the request acceptance cycle");

            @(negedge clk);
            tx_en = 1'b0;
        end
    endtask

    task short_busy_pulse;
        input [7:0] data_byte;
        begin
            @(negedge clk);
            tx_data = data_byte;
            tx_en   = 1'b1;

            @(posedge clk);
            #1;
            check_true(tx_busy === 1'b1, "tx_busy must stay high during an overlapping request");

            @(negedge clk);
            tx_en = 1'b0;
        end
    endtask

    task check_bit_window;
        input expected_value;
        input integer bit_kind;
        input integer data_index;
        integer k;
        begin
            for (k = 0; k < CLOCKS_PER_BIT; k = k + 1) begin
                total_checks = total_checks + 1;
                if (tx !== expected_value) begin
                    failures = failures + 1;
                    if (bit_kind == 0) begin
                        $display("FAIL @ cycle %0d: start bit expected %0b, got %0b", cycle_count, expected_value, tx);
                    end else if (bit_kind == 1) begin
                        $display("FAIL @ cycle %0d: data bit %0d expected %0b, got %0b", cycle_count, data_index, expected_value, tx);
                    end else begin
                        $display("FAIL @ cycle %0d: stop bit expected %0b, got %0b", cycle_count, expected_value, tx);
                    end
                end

                total_checks = total_checks + 1;
                if (tx_busy !== 1'b1) begin
                    failures = failures + 1;
                    $display("FAIL @ cycle %0d: tx_busy deasserted during active frame", cycle_count);
                end

                if (k != CLOCKS_PER_BIT - 1) begin
                    @(posedge clk);
                    #1;
                end
            end
        end
    endtask

    task verify_frame_bits;
        input [7:0] expected_data;
        input integer accepted_cycle;
        integer i;
        begin
            @(posedge clk);
            #1;
            check_true(
                cycle_count == accepted_cycle + 1,
                "start bit must begin exactly one clock after request acceptance"
            );

            check_bit_window(1'b0, 0, 0);

            for (i = 0; i < 8; i = i + 1) begin
                @(posedge clk);
                #1;
                check_bit_window(expected_data[i], 1, i);
            end

            @(posedge clk);
            #1;
            check_bit_window(1'b1, 2, 0);
        end
    endtask

    task verify_idle_after_frame;
        begin
            @(posedge clk);
            #1;
            check_true(tx_busy === 1'b0, "tx_busy must clear on the first idle cycle after the stop bit");
            check_true(tx === 1'b1, "tx must be high on the first idle cycle after the stop bit");
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

        begin_case("single nominal transmission");
        reset_dut();
        request_byte(8'hA5, accept_cycle);
        verify_frame_bits(8'hA5, accept_cycle);
        verify_idle_after_frame();
        wait_cycles(CLOCKS_PER_BIT / 2);
        check_true(tx === 1'b1, "tx must remain idle after a single nominal transmission");
        check_true(tx_busy === 1'b0, "tx_busy must remain low after a single nominal transmission");
        end_case();

        begin_case("pattern sensitivity and LSB-first ordering");
        reset_dut();

        request_byte(8'h00, accept_cycle);
        verify_frame_bits(8'h00, accept_cycle);
        verify_idle_after_frame();

        request_byte(8'hFF, accept_cycle);
        verify_frame_bits(8'hFF, accept_cycle);
        verify_idle_after_frame();

        request_byte(8'h55, accept_cycle);
        verify_frame_bits(8'h55, accept_cycle);
        verify_idle_after_frame();

        request_byte(8'hAA, accept_cycle);
        verify_frame_bits(8'hAA, accept_cycle);
        verify_idle_after_frame();

        request_byte(8'h3C, accept_cycle);
        verify_frame_bits(8'h3C, accept_cycle);
        verify_idle_after_frame();
        end_case();

        begin_case("data capture vs later tx_data changes");
        reset_dut();
        request_byte(8'h3C, accept_cycle);

        fork
            begin
                wait_cycles(CLOCKS_PER_BIT + 9);
                @(negedge clk);
                tx_data = 8'hC3;
            end
            begin
                verify_frame_bits(8'h3C, accept_cycle);
            end
        join

        verify_idle_after_frame();
        end_case();

        begin_case("short overlapping request while busy is ignored");
        reset_dut();
        request_byte(8'h5A, accept_cycle);

        fork
            begin
                wait_cycles(CLOCKS_PER_BIT + 7);
                short_busy_pulse(8'hC3);
            end
            begin
                verify_frame_bits(8'h5A, accept_cycle);
            end
        join

        verify_idle_after_frame();
        wait_cycles(CLOCKS_PER_BIT + 2);
        check_true(tx === 1'b1, "tx must remain idle after an ignored overlapping request");
        check_true(tx_busy === 1'b0, "tx_busy must return low after the original frame completes");
        end_case();

        begin_case("held-high tx_en causes legal immediate reacceptance");
        reset_dut();
        wait_for_idle();

        @(negedge clk);
        tx_data = 8'h3C;
        tx_en   = 1'b1;

        @(posedge clk);
        #1;
        accept_cycle = cycle_count;
        check_true(tx_busy === 1'b1, "tx_busy must assert when the held-high request is first accepted");
        check_true(tx === 1'b1, "tx must stay high in the first acceptance cycle");

        fork
            begin
                wait_cycles(CLOCKS_PER_BIT + 9);
                @(negedge clk);
                tx_data = 8'hC3;
            end
            begin
                verify_frame_bits(8'h3C, accept_cycle);
            end
        join

        @(posedge clk);
        #1;
        accept_cycle_2 = cycle_count;
        check_true(
            accept_cycle_2 == accept_cycle + (10 * CLOCKS_PER_BIT) + 1,
            "held-high tx_en must be reaccepted on the first idle cycle after the previous frame"
        );
        check_true(tx_busy === 1'b1, "tx_busy must remain high during immediate reacceptance");
        check_true(tx === 1'b1, "tx must stay high in the second acceptance cycle");

        @(negedge clk);
        tx_en = 1'b0;

        verify_frame_bits(8'hC3, accept_cycle_2);
        verify_idle_after_frame();
        end_case();

        begin_case("back-to-back legal transmissions");
        reset_dut();

        request_byte(8'h96, accept_cycle);
        verify_frame_bits(8'h96, accept_cycle);
        verify_idle_after_frame();

        request_byte(8'h69, accept_cycle_2);
        verify_frame_bits(8'h69, accept_cycle_2);
        verify_idle_after_frame();
        end_case();

        finish_and_report();
    end

endmodule

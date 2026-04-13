module gcd #(parameter width=8) 
    (input wire [width-1:0] in_A, 
    input wire [width-1:0] in_B,
    input wire start,
    input wire clk,
    output wire [width-1:0] gcd_res,
    output wire busy,
    output wire done);

    // DATAPATH DESIGN.
    wire [width-1:0] in_mux1_0, in_mux1_1, in_mux2_0, in_mux2_1; 
    wire [width-1:0] in_mux3_1, in_mux4_1; // Kept from original
    wire mux1_sel, mux2_sel, mux3_sel, mux4_sel;

    wire [width-1:0] in_sub_0, in_sub_1;
    wire [width-1:0] sub_res;
    
    wire [width-1:0] A_Q, B_Q;
    wire [width-1:0] A_D, B_D;
    wire A_en, B_en, A_nrst, B_nrst;

    // Hardwired connections for the multiplexers based on original logic
    assign in_mux1_0 = A_Q; 
    assign in_mux1_1 = B_Q;
    assign in_mux2_0 = B_Q;
    assign in_mux2_1 = A_Q;

    dtypereg #( .width(width) ) reg_A ( .D(A_D), .Q(A_Q), .clk(clk), .en(A_en), .n_rst(A_nrst) );
    dtypereg #( .width(width) ) reg_B ( .D(B_D), .Q(B_Q), .clk(clk), .en(B_en), .n_rst(B_nrst) );

    mux2xn #( .width(width) ) mux1 ( .in0(in_mux1_0), .in1(in_mux1_1), .sel(mux1_sel), .out(in_sub_0) );
    mux2xn #( .width(width) ) mux2 ( .in0(in_mux2_0), .in1(in_mux2_1), .sel(mux2_sel), .out(in_sub_1) );
    mux2xn #( .width(width) ) mux3 ( .in0(in_A), .in1(sub_res), .sel(mux3_sel), .out(A_D) );
    mux2xn #( .width(width) ) mux4 ( .in0(in_B), .in1(sub_res), .sel(mux4_sel), .out(B_D) );    

    subtract #( .width(width) ) sub ( .a(in_sub_0), .b(in_sub_1), .diff(sub_res) );

    // CONTROL UNIT IMPLEMENTATION.
    wire ALB, BLA, AEB;
    compunit #( .width(width) ) comp ( .a(A_Q), .b(B_Q), .great(BLA), .less(ALB), .eq(AEB) );

    reg [4:0] state;
    //reg [4:0] next;
    
    reg busyState;
    always @(posedge clk) 
        busyState <= busy;
    assign busy = state[1] | state[2] | state[3];
    assign done = state[4];

    wire decrA, decrB;
    assign decrA = (!start) & busyState & BLA;
    assign decrB = (!start) & busyState & ALB;
    
    parameter [4:0] IDLE = 5'b00001;
    parameter [4:0] S0   = 5'b00010; // Load Inputs
    parameter [4:0] S1   = 5'b00100; // A = A - B
    parameter [4:0] S2   = 5'b01000; // B = B - A
    parameter [4:0] DONE = 5'b10000;
    
    always @(posedge clk) begin
        if (start) state <= S0;
        else begin 
            if (state[1] | state[2] | state[3]) begin
                if (BLA)  state <= S1;
                else if (ALB)  state <= S2;
                else if (AEB)  state <= DONE;
            end
            else state <= IDLE;
        end
    end

    // Datapath control signals
    assign A_nrst = 1'b1;
    assign B_nrst = 1'b1;
    // Enable reg A when loading (S0) or when A < B (S1)
    assign A_en = start | decrA;
    // Enable reg B when loading (S0) or when B < A (S2)
    assign B_en = start | decrB;

    assign mux3_sel = decrA;
    assign mux4_sel = decrB;

    assign mux1_sel = decrB;
    assign mux2_sel = decrB;

    assign gcd_res = A_Q;

endmodule
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/01/2026 11:02:29 AM
// Design Name: 
// Module Name: potentiometer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
//Source: Claude

//module pot_reader (
//    input  logic        clk,
//    input  logic        rst_n,
//    input  logic        vp_in,
//    input  logic        vn_in,
//    output logic [11:0] raw_adc,   // 0-4095, scale this yourself
//    output logic        valid       // pulses when a new reading is ready
//);
//    logic        eoc, drdy;
//    logic [15:0] do_out;

//    assign daddr = 7'h03;
    

//    xadc_wiz_0 u_xadc (
//        .dclk_in   (clk),
//        .reset_in  (~rst_n),
//        .vp_in     (vp_in),
//        .vn_in     (vn_in),
//        .eoc_out   (eoc),
//        .drdy_out  (drdy),
//        .do_out    (do_out),
//        .daddr_in  (daddr),
//        .den_in    (eoc),
//        .dwe_in    ('0),
//        .busy_out  (), .channel_out(), .eos_out(), .alarm_out()
//    );

//    always_ff @(posedge clk) begin
//        if (!rst_n) begin
//            raw_adc <= '0;
//            valid   <= 1'b0;
            
//        end else begin
//            valid <= 1'b0;
            
//            if (drdy) begin
//                raw_adc <= do_out[15:4];  // top 12 bits are the result
//                valid   <= 1'b1;           // one-cycle pulse when new data ready
//            end
//        end
//    end
//endmodule

module pot_reader (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        vp_in,
    input  logic        vn_in,
    output logic [11:0] raw_adc,   // 0-4095, scale this yourself
    output logic        valid       // pulses when a new reading is ready
);
    logic        eoc, drdy;
    logic [15:0] do_out;
    assign den   = eoc;

    xadc_wiz_0 u_xadc (
        .dclk_in   (clk),
        .reset_in  (~rst_n),
        .vp_in     (vp_in),
        .vn_in     (vn_in),
        .eoc_out   (eoc),
        .drdy_out  (drdy),
        .do_out    (do_out),
        .daddr_in  (7'h03),
        .den_in    (den),
        .dwe_in    (1'b0),
        .busy_out  (), .channel_out(), .eos_out(), .alarm_out()
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            raw_adc <= '0;
            valid   <= 1'b0;
        end else begin
            valid <= 1'b0;
            if (drdy) begin
                raw_adc <= do_out[15:4];  // top 12 bits are the result
                valid   <= 1'b1;           // one-cycle pulse when new data ready
            end
        end
    end
endmodule
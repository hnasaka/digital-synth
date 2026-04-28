`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/20/2026 09:46:34 PM
// Design Name: 
// Module Name: audio_tick
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

//Created by Claude "How do I implement a 48kHz audio sample rate tick generator in SystemVerilog on the Urbana board from a 100MHz clock?"


module audio_tick #(
    parameter int CLK_HZ    = 100_000_000,
    parameter int SAMPLE_HZ =      48_000
) (
    input  logic clk,
    input  logic rst_n,
    output logic tick
    
);
    // We want to fire every CLK_HZ/SAMPLE_HZ = 2083.333... cycles.
    // Use a 32-bit phase accumulator: add SAMPLE_HZ each cycle,
    // fire when it crosses CLK_HZ, then subtract CLK_HZ.
    //
    // Equivalent to: tick fires whenever acc overflows CLK_HZ.
    // Average interval = CLK_HZ / SAMPLE_HZ cycles. Exactly.

    logic [31:0] acc;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            acc  <= '0;
            tick <= 1'b0;
        end else begin
            tick <= 1'b0;
            if (acc + SAMPLE_HZ >= CLK_HZ) begin
                acc  <= acc + SAMPLE_HZ - CLK_HZ;
                tick <= 1'b1;
            end else begin
                acc  <= acc + SAMPLE_HZ;
            end
        end
    end

endmodule

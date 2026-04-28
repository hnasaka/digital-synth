`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/23/2026 11:37:23 PM
// Design Name: 
// Module Name: kb2PitchMicrotone
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


module kb2Pitch2 (
    input  logic [7:0] keycode,   // USB HID usage ID
    output logic [23:0] tuning_word
);

    always_comb begin
        tuning_word = 24'd0;

       
            case (keycode)

                // =========================
                // Row 3 (Z X C V B N M)
                // C4 region microtones
                // =========================
                8'h1D: tuning_word = 24'd91478;   // Z
                8'h1B: tuning_word = 24'd93960;   // X (+1 microtone)
                8'h06: tuning_word = 24'd96510;   // C
                8'h19: tuning_word = 24'd99089;   // V
                8'h05: tuning_word = 24'd101707;  // B
                8'h11: tuning_word = 24'd104365;  // N
                8'h10: tuning_word = 24'd107063;  // M

                // =========================
                // Row 2 (A S D F G H J K L)
                // Mid range microtones
                // =========================
                8'h04: tuning_word = 24'd109803;  // A
                8'h16: tuning_word = 24'd112585;  // S
                8'h07: tuning_word = 24'd115410;  // D (? E4 region start)
                8'h09: tuning_word = 24'd118279;  // F
                8'h0A: tuning_word = 24'd121193;  // G
                8'h0B: tuning_word = 24'd124153;  // H
                8'h0D: tuning_word = 24'd127160;  // J
                8'h0E: tuning_word = 24'd130214;  // K
                8'h0F: tuning_word = 24'd133318;  // L

                // =========================
                // Row 1 (Q W E R T Y U I O P)
                // Higher microtonal range
                // =========================
                8'h14: tuning_word = 24'd136471;  // Q
                8'h1A: tuning_word = 24'd139676;  // W
                8'h08: tuning_word = 24'd142934;  // E
                8'h15: tuning_word = 24'd146245;  // R
                8'h17: tuning_word = 24'd149611;  // T
                8'h1C: tuning_word = 24'd153033;  // Y
                8'h18: tuning_word = 24'd156512;  // U
                8'h0C: tuning_word = 24'd160049;  // I
                8'h12: tuning_word = 24'd163646;  // O
                8'h13: tuning_word = 24'd167303;  // P

                // =========================
                // Number row (extend upward octave + microtones)
                // =========================
                8'h1E: tuning_word = 24'd170000;  // 1
                8'h1F: tuning_word = 24'd173800;  // 2
                8'h20: tuning_word = 24'd177700;  // 3
                8'h21: tuning_word = 24'd181700;  // 4
                8'h22: tuning_word = 24'd185800;  // 5
                8'h23: tuning_word = 24'd190000;  // 6
                8'h24: tuning_word = 24'd194300;  // 7
                8'h25: tuning_word = 24'd198700;  // 8
                8'h26: tuning_word = 24'd203200;  // 9
                8'h27: tuning_word = 24'd207800;  // 0

                default: tuning_word = 24'd0;

            endcase
        
    end

endmodule

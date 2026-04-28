`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2026 09:58:04 PM
// Design Name: 
// Module Name: kb2Pitch
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


module kb2Pitch (
    input  logic [7:0] keycode,   // USB HID usage ID
    output logic [23:0] tuning_word
);

    always_comb begin
        tuning_word = 24'd0;

        
            case (keycode)

                // -------- Lower octave (C4-B4) --------
                8'h1D: tuning_word = 24'd91478;   // Z  -> C4
                8'h16: tuning_word = 24'd96935;   // S  -> C#4
                8'h1B: tuning_word = 24'd102705;  // X  -> D4
                8'h07: tuning_word = 24'd108818;  // D  -> D#4
                8'h06: tuning_word = 24'd115308;  // C  -> E4
                8'h19: tuning_word = 24'd122209;  // V  -> F4
                8'h0A: tuning_word = 24'd129561;  // G  -> F#4
                8'h05: tuning_word = 24'd137402;  // B  -> G4
                8'h0B: tuning_word = 24'd145774;  // H  -> G#4
                8'h11: tuning_word = 24'd154721;  // N  -> A4
                8'h0D: tuning_word = 24'd164291;  // J  -> A#4
                8'h10: tuning_word = 24'd174535;  // M  -> B4

                // -------- Upper octave (C5-B5) --------
                8'h14: tuning_word = 24'd182956;  // Q  -> C5
                8'h1F: tuning_word = 24'd193871;  // 2  -> C#5
                8'h1A: tuning_word = 24'd205410;  // W  -> D5
                8'h20: tuning_word = 24'd217637;  // 3  -> D#5
                8'h08: tuning_word = 24'd230616;  // E  -> E5
                8'h15: tuning_word = 24'd244418;  // R  -> F5
                8'h22: tuning_word = 24'd259122;  // 5  -> F#5
                8'h17: tuning_word = 24'd274804;  // T  -> G5
                8'h23: tuning_word = 24'd291548;  // 6  -> G#5
                8'h1C: tuning_word = 24'd309443;  // Y  -> A5
                8'h24: tuning_word = 24'd328582;  // 7  -> A#5
                8'h18: tuning_word = 24'd349071;  // U  -> B5

                default: tuning_word = 24'd0;
            endcase
        
    end

endmodule

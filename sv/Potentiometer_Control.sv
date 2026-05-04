`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/03/2026 02:48:40 PM
// Design Name: 
// Module Name: Potentiometer_Control
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


module Potentiometer_Control(
        input logic clk,
        input logic resetn,
        input logic [11:0] pot_raw,
        input logic systemOn,
        input logic [15:0] SW,
        input logic [3:0] BTN,
        
        output logic [14:0] amplitude,
        output logic [1:0] waveformSelect,
        output logic keyboardSelect,
        output logic [31:0] attack_step,
        output logic [31:0] decay_step,
        output logic [31:0] sustain_level,
        output logic [31:0] sustain_time,
        output logic [31:0] release_step
        
    );
    
    localparam int MIN_SUSTAIN = 1_000_000;      // 10 ms
    localparam int MAX_SUSTAIN = 500_000_000;    // 5 s 
    
    logic [2:0] coarse = pot_raw[11:9];   // big jumps
    logic [8:0] fine   = pot_raw[8:0];    // smooth within range
    
    logic [31:0] base;
    assign base = MIN_SUSTAIN << coarse;

    
    
    always_ff @(posedge clk)begin
        if(~resetn)begin
            amplitude <= 'h4FF;
            waveformSelect <= '0;
            keyboardSelect <= '1;
            attack_step <= 32'h00000015;
            decay_step <= 32'h0000002B;
            sustain_level <= 32'h59999999;
            sustain_time <= 32'h01C9C380;
            release_step <= 32'h0000012D;
            
        end
        else if(~systemOn)begin
            if(BTN[1])begin
                case (SW)
                    'b1: amplitude <= pot_raw*8;
                    'b10: attack_step <= {20'b0, pot_raw};
                    'b100: decay_step <= {20'b0,pot_raw};
                    'b1000: sustain_level <= {pot_raw,20'b0};
                    'b10000: sustain_time <= base + ((base >> 3) * fine >> 9);
                    'b100000: release_step <= {20'b0, pot_raw};
                    default: begin
                        amplitude <= 'h4FF;
                        waveformSelect <= '0;
                        keyboardSelect <= '1;
                        attack_step <= 32'h00000015;
                        decay_step <= 32'h0000002B;
                        sustain_level <= 32'h59999999;
                        sustain_time <= 32'h01C9C380;
                        release_step <= 32'h0000012D;
                    end
                endcase
            end else if (BTN[2]) begin
                keyboardSelect <= SW[0]; 
            end else if (BTN[3]) begin
                waveformSelect <= SW[1:0];
            end
            
        end
    end
    
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/27/2026 08:10:25 PM
// Design Name: 
// Module Name: fftBox
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


module fftBox(
    input clk,
    input resetn,
    
    input logic [9:0] phase,
    output logic [15:0] pcmData,
    
    output logic [32:0] vramAddress,
    input logic [16:0] vramData,
    
    input logic sd_we,
    input logic sd_address,
    input logic sd_data,
    output logic sd_word_done
    
    
    
    );
    
    logic [8:0] address;
    assign address = phase[9:1];
    
    logic [15:0] memDataOut;
    logic [15:0] memDataIn;
    logic ena;
    logic wea;
    
    blk_mem_gen_0 fftOutput(
                .addra(address),
                .clka(clk),
                .dina(memDataIn),
                .douta(memDataOut),
                .ena(ena),
                .wea(wea)
                
        );
    
    
    
    
    
    
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/20/2026 10:25:44 PM
// Design Name: 
// Module Name: claudeTop
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
//Claude: How do I use the vivado IP catalog DDS compiler instead for the DDS Engine

module claudeTop (
    input  logic clk_100mhz,
    input  logic btn_reset_n,
    input  logic [23:0] tuning_word,   // from your UI
    input  logic [14:0] amplitude,
    input  logic [1:0]  waveform_sel,
    output logic pmod_pdm
);
    logic tick;
    logic signed [15:0] pcm_sample;
    logic pcm_valid;

    audio_tick u_tick (
        .clk   (clk_100mhz),
        .rst_n (btn_reset_n),
        .tick  (tick)
    );

    dds_engine_ip u_dds (
        .clk          (clk_100mhz),
        .rst_n        (btn_reset_n),
        .tick         (tick),
        .tuning_word  (tuning_word),
        .amplitude    (amplitude),
        .waveform_sel (waveform_sel),
        .pcm_data     (pcm_sample),
        .pcm_valid    (pcm_valid)
    );

    pcm_to_pdm #(.CLK_DIV(33)) u_pdm (
        .sys_clk   (clk_100mhz),
        .rst_n     (btn_reset_n),
        .pcm_data  (pcm_sample),
        .pcm_valid (pcm_valid),
        .pdm_out   (pmod_pdm),
        .pdm_clk   ()
    );

endmodule

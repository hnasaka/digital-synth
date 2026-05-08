`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/05/2026 10:39:31 PM
// Design Name: 
// Module Name: sdBox
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


module sdBox(
       input logic clk,
       input logic reset,
       input logic audioTick,
       
       output  logic [15:0] sdPCM,
       output logic sdPCM_valid,
       output ramError,
       
       
       output logic cs_bo, //SD card pins (also make sure to disable USB CS if using DE10-Lite)
	   output logic sclk_o,
	   output logic mosi_o,
	   input  logic miso_i 
    );
    
sdcard_init sdcard(
	.clk50(clk),
	.reset(reset),          //starts as soon reset is deasserted
	.ram_we(sdPCM_valid),         //RAM interface pins
	.ram_address(),
	.ram_data(sdPCM),
	.ram_op_begun(audioTick),   //acknowledge from RAM to move to next word
	.ram_init_error(ramError), //error initializing
	.ram_init_done(),  //done with reading all MAX_RAM_ADDRESS words
	.cs_bo(cs_bo), //SD card pins (also make sure to disable USB CS if using DE10-Lite)
	.sclk_o(sclk_o),
	.mosi_o(mosi_o),
	.miso_i(miso_i)  
);

endmodule

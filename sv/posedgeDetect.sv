`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/29/2026 01:25:13 PM
// Design Name: 
// Module Name: posedgeDetect
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


module posedgeDetect #(
    parameter voiceNum = 8
)
(
        input logic clk,
        input logic signal[voiceNum],
        output logic signalPosedge[voiceNum]
        
    );
    
    logic signalBefore[voiceNum];
    always_ff @(posedge clk)begin
        for(int i = 0; i < voiceNum; i = i + 1) begin
            if (signalBefore[i] == 0 && signal[i] == 1) begin
                signalPosedge[i] = '1;
            end else begin
                signalPosedge[i] = '0;
            end
            signalBefore[i] <= signal[i];
        end  
    end 
    
endmodule

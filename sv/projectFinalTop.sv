`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 07:37:08 PM
// Design Name: 
// Module Name: projectFinalTop
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


module projectFinalTop(
        input logic CLK_100MHZ,
        input logic [15:0] SW,
        input logic [3:0] BTN,
        
        output logic [15:0] LED,
        output logic [7:0]  hex_seg_left,
	    output logic [3:0]  hex_grid_left,
	    output logic [7:0]  hex_seg_right,
	    output logic [3:0]  hex_grid_right,
	    output logic SPKL,
	    output logic SPKR,
	    
	    //USB signals
        input logic [0:0] gpio_usb_int_tri_i,
        output logic gpio_usb_rst_tri_o,
        input logic usb_spi_miso,
        output logic usb_spi_mosi,
        output logic usb_spi_sclk,
        output logic usb_spi_ss,
        
        //UART
        input logic uart_rtl_0_rxd,
        output logic uart_rtl_0_txd
        
    );
    
    logic resetn;
    assign resetn = ~BTN[0];
    
// Microblaze ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~``
    
    logic [31:0] keycode0_gpio, keycode1_gpio;
    
    microblaze mb_block_i (
        .clk_100MHz(CLK_100MHZ),
        .gpio_usb_int_tri_i(gpio_usb_int_tri_i),
        .gpio_usb_keycode_0_tri_o(keycode0_gpio),
        .gpio_usb_keycode_1_tri_o(keycode1_gpio),
        .gpio_usb_rst_tri_o(gpio_usb_rst_tri_o),
        .reset_rtl_0(resetn), //Block designs expect active low reset, all other modules are active high
        .uart_rtl_0_rxd(uart_rtl_0_rxd),
        .uart_rtl_0_txd(uart_rtl_0_txd),
        .usb_spi_miso(usb_spi_miso),
        .usb_spi_mosi(usb_spi_mosi),
        .usb_spi_sclk(usb_spi_sclk),
        .usb_spi_ss(usb_spi_ss)
    );
    
//Keycode HEX drivers ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    hex_driver HexA (
        .clk(CLK_100MHZ),
        .reset(~resetn),
        .in({keycode0_gpio[31:28], keycode0_gpio[27:24], keycode0_gpio[23:20], keycode0_gpio[19:16]}),
        .hex_seg(hex_seg_left),
        .hex_grid(hex_grid_left)
    );
    
    hex_driver HexB (
        .clk(CLK_100MHZ),
        .reset(~resetn),
        .in({keycode0_gpio[15:12], keycode0_gpio[11:8], keycode0_gpio[7:4], keycode0_gpio[3:0]}),
        .hex_seg(hex_seg_right),
        .hex_grid(hex_grid_right)
    );
    
// Keyboard to Pitch    

//logic [23:0] tuningWord;

//kb2Pitch pitcher(
//    .keycode(keycode0_gpio[7:0]),
//    .tuning_word(tuningWord)
//);
  
// Tick:~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    logic tick;
    
    audio_tick u_tick (
        .clk   (CLK_100MHZ),
        .rst_n (resetn),
        .tick  (tick)
    ); 
  
  
    
// DDS ENGINE ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    logic dds_pcm_valid;
    logic signed [15:0] dds_pcm_out;
    
    logic [14:0] amplitude;
    
    assign amplitude = 15'(SW[13:10]) * 15'd2048;

    
    dds_engine_ip2 u_dds (
        .clk          (CLK_100MHZ),
        .rst_n        (resetn),
        .tick         (tick),
//        .tuning_word  (tuningWord),
        .keyCodes     (keycode0_gpio),
        .amplitude    (amplitude),
        .waveform_sel (SW[1:0]),
        .pcm_data     (dds_pcm_out),
        .pcm_valid    (dds_pcm_valid),
        .keyboardSelect (SW[14])
    );
    
    
// PCM to PDM ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`    
    
    logic PDM_OUT;
    logic signed [15:0] pcm_data;
    logic signed [15:0] metaStable;
    
    always_ff @(CLK_100MHZ) begin
        for(integer count = 0; count < 16; count = count + 1)
            metaStable[count] = CLK_100MHZ;
    end
    always_comb begin
        pcm_data = dds_pcm_out;
        if (~SW[15] || (keycode0_gpio[7:0] == 0)) begin
            pcm_data = 'h0;
        end 
        else if (SW[9]) begin
            pcm_data = dds_pcm_out + metaStable;
        end
    end
    
    pcm_to_pdm2 #(.PCM_WIDTH(16), .CLK_DIV(8)) u_pdm (
        .sys_clk   (CLK_100MHZ),     
        .rst_n     (resetn),    
        .pcm_data  (pcm_data),    // from DDS engine
        .pcm_valid (dds_pcm_valid),  // from DDS engine sample tick
        .pdm_out   (PDM_OUT),       // to XDC-constrained output pin
        .pdm_clk   ()                // unconnected
    );
    
    assign SPKL = PDM_OUT;
    assign SPKR = PDM_OUT;
    
    
    
    
endmodule

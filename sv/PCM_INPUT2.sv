`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/20/2026 09:45:50 PM
// Design Name: 
// Module Name: PCM_INPUT
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


module dds_engine_ip2 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        tick,              // from audio_tick module, 48 kHz

//    input  logic [23:0] tuning_word,       // f_out * 2^24 / 48000
    input logic [31:0] keyCodes,
    input  logic [14:0] amplitude,         // 0=silent, 0x7FFF=full scale
    input  logic [1:0]  waveform_sel,      // 0=DDS sine, 1=square, 2=saw, 3=noise
    input logic keyboardSelect,

    output logic signed [15:0] pcm_data,
    output logic               pcm_valid,
    
    
    //adsr
    input logic [31:0] attack_step,
    input logic [31:0] decay_step,
    input logic [31:0] sustain_level,
    input logic [31:0] sustain_time,
    input logic [31:0] release_step,
    
    //draw
    output logic [8:0] drawAddress,
    input logic [8:0] drawPCM
    
);

    // ?? DDS Compiler IP instance ?????????????????????????????????????????
    // Generated name will be dds_compiler_0 - match whatever Vivado created.

    logic [23:0] phase_tdata;
    logic        phase_tvalid;
    logic [31:0] dds_tdata;
    logic        dds_tvalid;
    
    
    logic lutValid;
    logic wr_addrValid;
    logic [9:0] wt_addr;
    logic clearAccum;
    logic accum_done;
    logic [15:0] adsrEnvelope;

    controlDDS u_control (
                    .Clk(clk),
                    .Reset(~rst_n),
                    .keycodes(keyCodes),
                    .tick(tick),
                    .lutValid(lutValid),
                    .pcm_valid(accum_done),
                    .wr_addrValid(wr_addrValid),
                    .wt_addr(wt_addr),
                    .clearAccum(clearAccum),
                    .keyboardSelect(keyboardSelect),
                    .envelope(adsrEnvelope),
                    .*
                    
    );
   
    dds_compiler_1 u_dds (
        .aclk                 (clk),
        .aresetn              (rst_n),
        .s_axis_phase_tvalid  (wr_addrValid),
        .s_axis_phase_tdata   (wt_addr),
        .m_axis_data_tvalid   (dds_tvalid),
        .m_axis_data_tdata    (dds_tdata)
    );


    // Extract 16-bit signed sample from bits [15:0] of the 32-bit AXI word
    logic signed [15:0] sine_raw;
    assign sine_raw = dds_tdata[15:0]; //signed'(dds_tdata[15:0]);

    // ?? Preset waveform generators ???????????????????????????????????????
    // These run off the phase accumulator inside the DDS IP.
    // We reconstruct the address from the tuning word and a local counter
    // so presets stay in phase with the DDS sine output.
    
    logic [9:0] wt_addr_r;   // registered address, valid during accum
    logic [15:0] adsrEnvelope_r;

    always_ff @(posedge clk) begin
        if (!rst_n)
            wt_addr_r <= '0;
        else if (wr_addrValid) begin     // capture at end of note_i
            wt_addr_r <= wt_addr;
            adsrEnvelope_r <= adsrEnvelope;
            end
    end

    logic signed [15:0] square_raw, saw_raw, noise_raw, draw_raw;
    assign square_raw = wt_addr_r[9] ? -16'sd32767 : 16'sd32767;
    assign saw_raw    = signed'(16'({wt_addr_r, 6'b0})) - 16'sd32768;

    logic [15:0] lfsr;
    always_ff @(posedge clk) begin
        if (!rst_n) lfsr <= 16'hACE1;
        else if (tick)
            lfsr <= {lfsr[14:0], lfsr[15]^lfsr[14]^lfsr[12]^lfsr[3]};
    end
    assign noise_raw = signed'(lfsr);
    
    assign drawAddress = wt_addr_r[9:1];
    assign draw_raw = ($signed({1'b0, drawPCM}) - 10'sd256) <<< 7;

    // ?? Waveform mux ?????????????????????????????????????????????????????
    logic signed [15:0] selected_raw;
    always_comb begin
        unique case (waveform_sel)
            2'd0:    selected_raw = sine_raw;     // use DDS IP output
            2'd1:    selected_raw = square_raw;
            2'd2:    selected_raw = saw_raw;
            2'd3:    selected_raw = draw_raw;
            default: selected_raw = '0;
        endcase
    end

    // ?? Amplitude scaling ?????????????????????????????????????????????????
    // In always_comb - compute ADSR-scaled sample before accumulation
    logic signed [31:0] adsr_product;
    logic signed [15:0] adsr_scaled;
    
    always_comb begin
        // 16-bit sample × 16-bit ADSR envelope = 32-bit product
        // Take top 16 bits ? back to 16-bit range
        adsr_product = signed'(selected_raw) * signed'({1'b0, adsrEnvelope_r});
        adsr_scaled  = adsr_product[30:15];   // [30:15] not [31:16] - avoids sign bit issue
    end
    
    logic signed [17:0] acc_sum;
    
    always_ff @(posedge clk) begin
        if (clearAccum) begin
            acc_sum <= '0;
        end else if (lutValid) begin
        //acc_sum <= acc_sum + 18'(signed'(selected_raw));
//            adsrProduct = signed'(selected_raw) * signed'({1'b0,adsrEnvelope_r});
            acc_sum <= acc_sum + adsr_scaled;
        end     
    end
    
    
    logic signed [30:0] product;
    assign product = signed'(acc_sum[17:2]) * signed'({1'b0, amplitude});

    // ?? Output register ???????????????????????????????????????????????????
    // For sine (waveform_sel=0): use dds_tvalid as the valid signal -
    // the IP handles its own pipeline latency internally.
    // For presets: valid is delayed by 1 cycle for the mux + multiply.
    // We use dds_tvalid for all modes since the IP latency is fixed and
    // the preset generators are registered to match it.

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            pcm_data  <= '0;
            pcm_valid <= 1'b0;
        end else begin
            pcm_valid <= 1'b0;
            if(accum_done) begin
                pcm_data  <= signed'(16'(product[30:15]));
                pcm_valid <= 'd1;  // IP asserts this when sample is ready
            end
        end
    end

endmodule

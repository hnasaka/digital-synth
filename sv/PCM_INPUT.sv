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


module dds_engine_ip (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        tick,              // from audio_tick module, 48 kHz

    input  logic [23:0] tuning_word,       // f_out * 2^24 / 48000
    input  logic [14:0] amplitude,         // 0=silent, 0x7FFF=full scale
    input  logic [1:0]  waveform_sel,      // 0=DDS sine, 1=square, 2=saw, 3=noise

    output logic signed [15:0] pcm_data,
    output logic               pcm_valid
);

    // ?? DDS Compiler IP instance ?????????????????????????????????????????
    // Generated name will be dds_compiler_0 - match whatever Vivado created.

    logic [23:0] phase_tdata;
    logic        phase_tvalid;
    logic [31:0] dds_tdata;
    logic        dds_tvalid;

    // Pad 24-bit tuning word into 32-bit AXI word (upper 8 bits unused)
    assign phase_tdata  = {8'b0, tuning_word};

    // Assert phase_tvalid for one cycle when tick fires -
    // this tells the DDS "advance by tuning_word and give me one sample"
    assign phase_tvalid = tick;

//    dds_compiler_0 u_dds (
//        .aclk                 (clk),
//        .aresetn              (rst_n),
//        .s_axis_phase_tvalid  (phase_tvalid),
//        .s_axis_phase_tdata   (phase_tdata),
//        .m_axis_data_tvalid   (dds_tvalid),
//        .m_axis_data_tdata    (dds_tdata)
//    );
    logic [9:0] wt_addr;
    
    dds_compiler_1 u_dds (
        .aclk                 (clk),
        .aresetn              (rst_n),
        .s_axis_phase_tvalid  (phase_tvalid),
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

    logic [23:0] phase_acc;
    always_ff @(posedge clk) begin
        if (!rst_n)   phase_acc <= '0;
        else if (tick) phase_acc <= phase_acc + tuning_word;
    end

    
    assign wt_addr = phase_acc[23:14];  // top 10 bits

    logic signed [15:0] square_raw, saw_raw, noise_raw;
    assign square_raw = wt_addr[9] ? -16'sd32767 : 16'sd32767;
    assign saw_raw    = signed'(16'({wt_addr, 6'b0})) - 16'sd32768;

    logic [15:0] lfsr;
    always_ff @(posedge clk) begin
        if (!rst_n) lfsr <= 16'hACE1;
        else if (tick)
            lfsr <= {lfsr[14:0], lfsr[15]^lfsr[14]^lfsr[12]^lfsr[3]};
    end
    assign noise_raw = signed'(lfsr);

    // ?? Waveform mux ?????????????????????????????????????????????????????
    logic signed [15:0] selected_raw;
    always_comb begin
        unique case (waveform_sel)
            2'd0:    selected_raw = sine_raw;     // use DDS IP output
            2'd1:    selected_raw = square_raw;
            2'd2:    selected_raw = saw_raw;
            2'd3:    selected_raw = noise_raw;
            default: selected_raw = '0;
        endcase
    end

    // ?? Amplitude scaling ?????????????????????????????????????????????????
    logic signed [30:0] product;
    assign product = selected_raw * $signed({1'b0, amplitude});

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
            pcm_data  <= signed'(16'(product[30:15]));
            pcm_valid <= dds_tvalid;  // IP asserts this when sample is ready
        end
    end

endmodule

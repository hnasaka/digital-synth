`timescale 1ns / 1ps
// fftBox.sv
//
// Reads 512 frequency-domain bins from freq_draw's col_ram and performs a
// 1024-point IFFT to produce a real time-domain waveform.
//
// To obtain a real output from the IFFT the input spectrum must be
// Hermitian-symmetric:  X[N-k] = conj(X[k]).
//
// Because every drawn bin has zero imaginary part, conj(X[k]) = X[k], so the
// mirror is simply the same magnitude value read in reverse order:
//
//   index   0          : DC bin            -> col_ram[0]
//   index   1 .. 511   : positive freqs    -> col_ram[1..511]
//   index   512        : Nyquist bin       -> col_ram[511]  (real, no mirror)
//   index 513 .. 1023  : negative freqs    -> col_ram[1023-i] = col_ram[510..0]
//
// The FFT IP (xfft_0) must be configured for N=1024 inverse transform.
// All other interfaces are unchanged.

module fftBox (
    input  logic        clk,
    input  logic        resetn,       // active-low

    // Read port into freq_draw's col_ram
    output logic [8:0]  drawAddress,  // index into col_ram  (0-511)
    input  logic [8:0]  drawPCM,      // sample value from col_ram (0=top, 447=baseline)

    // Write port into blk_mem_gen_0 (IFFT output storage)
    input  logic [9:0]  vramAddress,  // read address from display
    output logic signed [15:0]  vramData,     // magnitude out to display

    // Button to trigger IFFT (already debounced + synced to clk)
    input  logic        fft_trigger,
    
    input logic [9:0] fftOutAddr,
    output logic signed [15:0] fftOutData
);

    // -------------------------------------------------------------------------
    // FSM states
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE      = 3'd0,
        CFG       = 3'd1,
        LOAD      = 3'd2,
        WAIT_OUT  = 3'd3,
        CAPTURE   = 3'd4
    } state_t;

    state_t state;

    // -------------------------------------------------------------------------
    // Counters
    // in_cnt  : 0-1023  (1024 samples fed to the FFT IP)
    // out_cnt : 0-1023  (1024 output samples captured)
    // col_idx : 0-511   (index into the 512-entry col_ram)
    // -------------------------------------------------------------------------
    logic [9:0] in_cnt;   // 10 bits to reach 1023
    logic [9:0] out_cnt;  // 10 bits to reach 1023

    // Mirror mapping:
    //   in_cnt  0       -> col_ram[0]          (DC)
    //   in_cnt  1..511  -> col_ram[in_cnt]      (positive freqs)
    //   in_cnt  512     -> col_ram[511]         (Nyquist)
    //   in_cnt  513..1023 -> col_ram[1023-in_cnt] = col_ram[510..0]  (mirror)
    //
    // col_idx is the address driven onto drawAddress one cycle early so that
    // drawPCM is stable when we actually latch the sample.

    logic [8:0] col_idx;

    always_comb begin
        if (in_cnt <= 10'd511)
            col_idx = in_cnt[8:0];          // bins 0-511 direct
        else if (in_cnt == 10'd512)
            col_idx = 9'd511;               // Nyquist = last bin
        else
            col_idx = 10'd1023 - in_cnt + 'd1;    // mirror: 510 down to 0
    end

    assign drawAddress = col_idx;

    // -------------------------------------------------------------------------
    // FFT wires
    // -------------------------------------------------------------------------
    logic [31:0] s_axis_data_tdata;
    logic        s_axis_data_tvalid;
    logic        s_axis_data_tready;
    logic        s_axis_data_tlast;

    logic [15:0] s_axis_config_tdata;
    logic        s_axis_config_tvalid;
    logic        s_axis_config_tready;

    logic [31:0] m_axis_data_tdata;
    logic        m_axis_data_tvalid;
    logic        m_axis_data_tready;
    logic        m_axis_data_tlast;

    // -------------------------------------------------------------------------
    // BRAM wires (port A = IFFT write, port B = display read)
    // -------------------------------------------------------------------------
    logic [9:0]  bram_addr_a;   // 10-bit to address 1024 locations
    logic [15:0]  bram_din_a;
    logic signed [15:0] bram_dout_a;
    logic        bram_we_a;
    logic [15:0]  bram_dout_b;

    // -------------------------------------------------------------------------
    // FFT/IFFT IP instantiation  (xfft_0 must be configured: N=1024, IFFT=1)
    // -------------------------------------------------------------------------
    xfft_0 fftModule (
        .aclk                        (clk),
        .aresetn                     (resetn),

        .s_axis_config_tdata         (s_axis_config_tdata),
        .s_axis_config_tvalid        (s_axis_config_tvalid),
        .s_axis_config_tready        (s_axis_config_tready),

        .s_axis_data_tdata           (s_axis_data_tdata),
        .s_axis_data_tvalid          (s_axis_data_tvalid),
        .s_axis_data_tready          (s_axis_data_tready),
        .s_axis_data_tlast           (s_axis_data_tlast),

        .m_axis_data_tdata           (m_axis_data_tdata),
        .m_axis_data_tvalid          (m_axis_data_tvalid),
        .m_axis_data_tready          (m_axis_data_tready),
        .m_axis_data_tlast           (m_axis_data_tlast),

        .event_frame_started         (),
        .event_tlast_unexpected      (),
        .event_tlast_missing         (),
        .event_status_channel_halt   (),
        .event_data_in_channel_halt  (),
        .event_data_out_channel_halt ()
    );

    // -------------------------------------------------------------------------
    // BRAM instantiation (true dual port, 1024 x 9-bit)
    // -------------------------------------------------------------------------
    blk_mem_gen_0 fftOutput (
        .clka  (clk),
        .ena   (1'b1),
        .wea   (bram_we_a),
        .addra (bram_addr_a),
        .dina  (bram_din_a),
        .douta (bram_dout_a),

        .clkb  (clk),
        .enb   (1'b1),
        .web   (1'b0),
        .addrb (fftOutAddr),
        .dinb  (9'b0),
        .doutb (fftOutData)
    );

    // -------------------------------------------------------------------------
    // Input sample conversion
    //
    // col_ram Y coordinate: 447 = baseline (0 amplitude), 0 = maximum upward.
    // Convert to signed amplitude centred at 0:
    //   sample_centered = -(drawPCM - 447) = 447 - drawPCM
    //   range: 0 (baseline) .. +447 (top of screen)
    //
    // For the Hermitian mirror bins (in_cnt >= 513) the imaginary part of
    // X[N-k] = conj(X[k]) = -Im(X[k]) = 0 (since Im was already 0).
    // So the same data word is used for both halves.
    // -------------------------------------------------------------------------
    wire signed [9:0] sample_raw      = $signed({1'b0, drawPCM}) - 10'sd447;
    wire signed [9:0] sample_centered = -sample_raw;

    // Pack: imag=0 (bits 31:16), real=sample_centered (bits 15:0)
    assign s_axis_data_tdata  = {16'd0, sample_centered, 6'b0};

    // tlast fires on the final (1024th) sample
    assign s_axis_data_tlast  = (in_cnt == 10'd1023);

    // Config word: FWD/INV bit = 0 ? inverse transform
    // Scaling schedule 0x15 (scale at 4 of the 10 stages for N=1024)
    assign s_axis_config_tdata = 16'h0015;

    assign m_axis_data_tready = 1'b1;

    // -------------------------------------------------------------------------
    // Magnitude of IFFT output
    //
    // For a real IFFT the imaginary output should be ~0; we use the real part
    // only and convert to a display amplitude (0-447).
    // -------------------------------------------------------------------------
    wire signed [15:0] re_raw = $signed(m_axis_data_tdata[15:0]);
    wire signed [15:0] im_raw = $signed(m_axis_data_tdata[31:16]);

//    wire [15:0] re_abs = re_raw[15] ? (~re_raw + 16'd1) : re_raw;
//    wire [15:0] im_abs = im_raw[15] ? (~im_raw + 16'd1) : im_raw;

//    // Sum of absolute values as a simple magnitude approximation
//    wire [16:0] mag_sum = {1'b0, re_abs} + {1'b0, im_abs};

//    // Clamp to 447 to fit the 448-pixel display range
//    wire [8:0] magnitude = (mag_sum > 17'd447) ? 9'd447 : mag_sum[8:0];

    logic signed [15:0] magnitude;
    assign magnitude = re_raw; 

    // -------------------------------------------------------------------------
    // BRAM write pipeline (one-cycle delay to align address with data)
    // -------------------------------------------------------------------------
    logic signed [15:0]  mag_reg;
    logic        we_reg;
    logic [9:0]  addr_reg;

    always_ff @(posedge clk) begin
        if (!resetn) begin
            mag_reg  <= 16'd0;
            we_reg   <= 1'b0;
            addr_reg <= 10'd0;
        end else begin
            if ((state == CAPTURE) && m_axis_data_tvalid) begin
                mag_reg  <= magnitude;
                addr_reg <= out_cnt;
                we_reg   <= 1'b1;
            end else if (state == IDLE)begin
                we_reg   <= 1'b0;
                addr_reg <= vramAddress;
                vramData <= bram_dout_a;
            end
        end
    end

    assign bram_addr_a = addr_reg;
    assign bram_din_a  = mag_reg;
    assign bram_we_a   = we_reg;

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!resetn) begin
            state                <= IDLE;
            in_cnt               <= 10'd0;
            out_cnt              <= 10'd0;
            s_axis_data_tvalid   <= 1'b0;
            s_axis_config_tvalid <= 1'b0;

        end else begin
            case (state)

                IDLE: begin
                    s_axis_data_tvalid   <= 1'b0;
                    s_axis_config_tvalid <= 1'b0;
                    in_cnt               <= 10'd0;
                    out_cnt              <= 10'd0;
                    if (fft_trigger)
                        state <= CFG;
                end

                CFG: begin
                    s_axis_config_tvalid <= 1'b1;
                    if (s_axis_config_tready) begin
                        s_axis_config_tvalid <= 1'b0;
                        s_axis_data_tvalid   <= 1'b1;
                        state                <= LOAD;
                    end
                end

                // Feed 1024 samples: direct bins 0-511, then mirror 512-1023.
                LOAD: begin
                    if (s_axis_data_tready) begin
                        if (in_cnt == 10'd1023) begin
                            s_axis_data_tvalid <= 1'b0;
                            state              <= WAIT_OUT;
                        end else begin
                            in_cnt <= in_cnt + 10'd1;
                        end
                    end
                end

                WAIT_OUT: begin
                    if (m_axis_data_tvalid) begin
                        out_cnt <= 10'd0;
                        state   <= CAPTURE;
                    end
                end

                // Capture all 1024 IFFT output samples.
                CAPTURE: begin
                    if (m_axis_data_tvalid) begin
                        if (m_axis_data_tlast) begin
                            state <= IDLE;
                        end else begin
                            out_cnt <= out_cnt + 10'd1;
                        end
                    end
                end

            endcase
        end
    end

endmodule
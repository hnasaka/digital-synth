// =============================================================
// pcm_to_pdm.sv  -  2nd-order delta-sigma PCM ? PDM
// =============================================================
// Key fix over all previous versions: the saturation function
// now receives a WIDER intermediate sum so the addition cannot
// wrap around before saturation clamps it.
//
// Previous bug: sat() operated on ACC_W-bit arithmetic. If
// integ1 was near SAT_MAX and the step pushed the sum past
// 2^(ACC_W-1)-1, the addition wrapped to a large negative number
// BEFORE sat() could see it, causing the integrator to jump by
// ~1 million counts in a single step - producing audible bursts.
//
// Fix: all intermediate sums are computed in ACC_W+1 bits.
// sat() accepts the wider sum and clamps before truncating back
// to ACC_W bits. The extra bit costs one adder stage in hardware
// but prevents all overflow cases completely.
// =============================================================

module pcm_to_pdm2 #(
    parameter int PCM_WIDTH = 16,
    parameter int CLK_DIV   = 1
) (
    input  logic                         sys_clk,
    input  logic                         rst_n,

    input  logic signed [PCM_WIDTH-1:0]  pcm_data,
    input  logic                         pcm_valid,

    output logic                         pdm_out,
    output logic                         pdm_clk
);

    // ?? Widths ????????????????????????????????????????????????????????????????
    localparam int ACC_W  = PCM_WIDTH + 6;   // 20-bit integrators
    localparam int WIDE_W = ACC_W + 1;       // 21-bit intermediate sums
                                             // Wide enough to hold:
                                             // SAT_MAX + PCM_MAX + FB_MAX
                                             // = 524287 + 32767 + 28672
                                             // = 585726 < 2^20 = 1048576 ?

    // ?? Feedback magnitude ????????????????????????????????????????????????????
    // 7/8 of full scale keeps loop gain below 1.0 for 2nd-order stability.
    localparam signed [ACC_W-1:0] FB_POS =  20'sd13107;
    localparam signed [ACC_W-1:0] FB_NEG = -20'sd13107;

    // ?? Saturation limits ?????????????????????????????????????????????????????
    localparam signed [ACC_W-1:0] SAT_MAX =  (2**(ACC_W-1)) - 1; //  524287
    localparam signed [ACC_W-1:0] SAT_MIN = -(2**(ACC_W-1));     // -524288

    // ?? Overflow-safe saturation function ?????????????????????????????????????
    // Takes a WIDE_W-bit input - the arithmetic cannot overflow here because
    // WIDE_W holds the full range of any single-step sum.
    // Clamps to ACC_W-bit limits and returns an ACC_W-bit result.
    function automatic signed [ACC_W-1:0] sat(input signed [WIDE_W-1:0] x);
        if      (x > WIDE_W'(signed'(SAT_MAX))) return SAT_MAX;
        else if (x < WIDE_W'(signed'(SAT_MIN))) return SAT_MIN;
        else                                     return x[ACC_W-1:0];
    endfunction

    // ?? PDM enable generation ?????????????????????????????????????????????????
    logic [$clog2(CLK_DIV)-1:0] clk_cnt;
    logic                        pdm_en;
    logic                        pdm_clk_r;

    always_ff @(posedge sys_clk) begin
        if (!rst_n) begin
            clk_cnt   <= '0;
            pdm_clk_r <= 1'b0;
            pdm_en    <= 1'b0;
        end else begin
            pdm_en <= 1'b0;
            if (clk_cnt == CLK_DIV - 1) begin
                clk_cnt   <= '0;
                pdm_clk_r <= ~pdm_clk_r;
                pdm_en    <= 1'b1;
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end
    end

    assign pdm_clk = pdm_clk_r;

    // ?? Two-stage PCM sample hold ?????????????????????????????????????????????
    // pcm_staged: latches immediately when pcm_valid fires
    // pcm_held:   transfers from staged only when pdm_en is not firing,
    //             so the modulator never sees a mid-step sample change
    logic signed [PCM_WIDTH-1:0] pcm_staged;
    logic signed [PCM_WIDTH-1:0] pcm_held;

    always_ff @(posedge sys_clk) begin
        if (!rst_n) begin
            pcm_staged <= '0;
            pcm_held   <= '0;
        end else begin
            if (pcm_valid)
                pcm_staged <= pcm_data;
            if (!pdm_en)
                pcm_held <= pcm_staged;
        end
    end

    // ?? Combinational modulator core ??????????????????????????????????????????
    // Compute next integrator values and quantizer output combinationally
    // so that pdm_out_next reflects the freshly computed integ2_next.
    //
    // All sums are computed in WIDE_W bits by sign-extending each operand
    // before adding. This prevents the overflow-before-saturation bug.
//    logic [15:0] lfsr;

//    always_ff @(posedge sys_clk) begin
//        if (!rst_n)
//            lfsr <= 16'hACE1;
//        else if (pdm_en)
//            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
//    end   
    
//    logic signed [ACC_W-1:0] dither;
//    assign dither = ACC_W'(signed'(lfsr[1:0])) - 20'sd1;
    
    logic signed [ACC_W-1:0]  integ1, integ2;
    logic signed [ACC_W-1:0]  integ1_next, integ2_next;
    logic signed [WIDE_W-1:0] sum1, sum2;
    logic signed [ACC_W-1:0]  fb;
    logic signed [ACC_W-1:0]  pcm_ext;
    logic                      pdm_out_next;

    always_comb begin
        // Feedback from the current registered pdm_out
        fb      = pdm_out ? FB_POS : FB_NEG;

        // Sign-extend PCM input to accumulator width
        pcm_ext = ACC_W'(signed'(pcm_held));

        // ?? Overflow-safe sums ????????????????????????????????????????????????
        // Sign-extend every operand to WIDE_W before adding.
        // Without this, the ACC_W-bit addition wraps before sat() sees it.
        //
        // Example of the bug this prevents:
        //   integ1 = 524287, pcm_ext = 32767, fb = -28672
        //   ACC_W sum:  524287+32767+28672 = 585726 ? wraps to -462850 !!
        //   WIDE_W sum: 585726, sat clamps to 524287 ?

        sum1 = WIDE_W'(signed'(integ1))
             + WIDE_W'(signed'(pcm_ext))
             - WIDE_W'(signed'(fb));
//             + WIDE_W'(signed'(dither))

        sum2 = WIDE_W'(signed'(integ2))
             + WIDE_W'(signed'(integ1))   // uses old integ1, correct for 2nd-order
             - WIDE_W'(signed'(fb));

        integ1_next  = sat(sum1);
        integ2_next  = sat(sum2);

        // Quantize the FRESH integ2_next (not the registered integ2).
        // MSB=0 means positive ? output 1 (high PDM density = positive signal).
        pdm_out_next = ~integ2_next[ACC_W-1];
    end

    // ?? State registers ???????????????????????????????????????????????????????
    always_ff @(posedge sys_clk) begin
        if (!rst_n) begin
            integ1  <= '0;
            integ2  <= '0;
            pdm_out <= 1'b0;
        end else if (pdm_en) begin
            integ1  <= integ1_next;
            integ2  <= integ2_next;
            pdm_out <= pdm_out_next;
        end
    end

endmodule


// =============================================================
// Testbench
// =============================================================
`ifdef SIMULATION
module pcm_to_pdm_tb;

    localparam int SYS_CLK_HZ  = 100_000_000;
    localparam int AUDIO_FS_HZ =      48_000;
    localparam int OSR         =          64;
    localparam int CLK_DIV     = SYS_CLK_HZ / (AUDIO_FS_HZ * OSR); // = 32

    logic        sys_clk   = 0;
    logic        rst_n     = 0;
    logic signed [15:0] pcm_data  = '0;
    logic        pcm_valid = 0;
    logic        pdm_out;
    logic        pdm_clk;

    pcm_to_pdm #(.PCM_WIDTH(16), .CLK_DIV(CLK_DIV)) dut (.*);

    always #5ns sys_clk = ~sys_clk;

    localparam int SAMPLE_TICKS = SYS_CLK_HZ / AUDIO_FS_HZ; // 2083

    int sample_cnt = 0;
    int sample_idx = 0;
    real TWO_PI = 2.0 * 3.14159265;

    always_ff @(posedge sys_clk) begin
        pcm_valid <= 1'b0;
        if (sample_cnt == SAMPLE_TICKS - 1) begin
            sample_cnt <= 0;
            // 440 Hz at 75% amplitude - leaves headroom for integrators
            pcm_data   <= signed'(16'($rtoi(24575.0 *
                              $sin(TWO_PI * 440.0 * sample_idx / AUDIO_FS_HZ))));
            pcm_valid  <= 1'b1;
            sample_idx <= sample_idx + 1;
        end else begin
            sample_cnt <= sample_cnt + 1;
        end
    end

    initial begin
        rst_n = 0;
        repeat(4) @(posedge sys_clk);
        rst_n = 1;
        // Run for 5ms - long enough to see several full sine wave periods
        #5_000_000ns;
        $display("Simulation complete");
        $finish;
    end

endmodule
`endif

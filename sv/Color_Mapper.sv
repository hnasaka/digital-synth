module color_mapper (
    input  logic [9:0]  BallX,
    input  logic [9:0]  BallY,
    input  logic [9:0]  DrawX,
    input  logic [9:0]  DrawY,

    // Time-domain: from freq_draw
    input  logic [8:0]  regVal,
    output logic [8:0]  addr,

    // Freq-domain: from fftBox BRAM
    input  logic signed [15:0]  fftVal,
    output logic  [9:0]  fftAddr,

    output logic [3:0]  Red,
    output logic [3:0]  Green,
    output logic [3:0]  Blue
);

    // -------------------------------------------------------------------------
    // Layout constants
    // -------------------------------------------------------------------------
    localparam [9:0] GRAPH_X_MIN = 10'd32;
    localparam [9:0] GRAPH_X_MAX = 10'd543;
    localparam [9:0] GRAPH_Y_MIN = 10'd0;
    localparam [9:0] GRAPH_Y_MAX = 10'd447;
    localparam [8:0] EMPTY_Y     = 9'd447;

    localparam [9:0] GRID_X_STEP = 10'd64;
    localparam [9:0] GRID_Y_STEP = 10'd56;

    // -------------------------------------------------------------------------
    // RAM index for time-domain waveform (unchanged)
    // -------------------------------------------------------------------------
    wire [8:0] ram_idx = DrawX[8:0] - GRAPH_X_MIN[8:0];
    assign addr = ram_idx;

    // -------------------------------------------------------------------------
    // FFT bin mapping - FIX for U-shape artifact
    //
    // A 512-point FFT of real data produces:
    //   bin 0        : DC component (huge spike, not musically useful)
    //   bins 1-255   : positive frequencies  ? the useful half
    //   bin 256      : Nyquist
    //   bins 257-511 : mirror image of bins 255-1 (causes the right peak)
    //
    // We display only bins 1-255 across the 512 display columns (0-511).
    // Mapping: bin = 1 + (col * 255) / 512
    // Using a multiply-shift approximation: col * 255 / 512 = (col * 255) >> 9
    // Adding 1 to skip the DC bin.
    // -------------------------------------------------------------------------
    wire [8:0] col      = ram_idx;                          // 0..511
    wire [17:0] scaled  = col * 9'd255;                     // 0..130560, fits 18 bits
    wire [8:0]  bin_idx = 9'd1 + scaled[17:9];             // bins 1..255

    assign fftAddr = 10'(ram_idx)*2;

    // -------------------------------------------------------------------------
    // Region
    // -------------------------------------------------------------------------
    wire in_graph = (DrawX >= GRAPH_X_MIN) && (DrawX <= GRAPH_X_MAX) &&
                    (DrawY >= GRAPH_Y_MIN) && (DrawY <= GRAPH_Y_MAX);

    // -------------------------------------------------------------------------
    // Time-domain: thin line at exact Y stored in col_ram
    // -------------------------------------------------------------------------
    wire on_time_drawn = in_graph &&
                         (regVal != EMPTY_Y) &&
                         (DrawY == {1'b0, regVal});

    // -------------------------------------------------------------------------
    // Freq-domain: filled bar from bottom up
    // fftVal is 0..447 after clamping fix in fftBox
    // bar top = GRAPH_Y_MAX - fftVal, lit if DrawY >= bar_top
    // -------------------------------------------------------------------------
    
//    wire [9:0] fftValCentered = {fftVal[15],fftVal[15:7]} +  10'd256;
//    wire [8:0] fftValClamped = (fftValCentered> 10'd447) ? 9'd447 : fftValCentered;
//    wire [9:0] freq_bar_top = GRAPH_Y_MAX - ({1'b0, fftValClamped});
    // Arithmetic shift preserves sign
//    wire signed [9:0] fftScaled = fftVal >>> 7;
    
//    // Offset into unsigned range
//    wire signed [10:0] fftShifted = fftScaled + 11'sd256;
    
//    // Clamp
//    wire [8:0] fftValClamped =
//        (fftShifted < 0)        ? 9'd0   :
//        (fftShifted > 11'd447) ? 9'd447 :
//                                  fftShifted[8:0];
                                  
//    wire [9:0] freq_bar_top = GRAPH_Y_MAX - {1'b0, fftValClamped};
//    wire on_freq_drawn = in_graph && (DrawY == freq_bar_top);
    // Clamp FFT value to [-224, 223]
    wire signed [15:0] fftClamped =
        (fftVal < -16'sd224) ? -16'sd224 :
        (fftVal >  16'sd223) ?  16'sd223 :
                               fftVal;
    
    // Shift into unsigned display range [0,447]
    wire [8:0] fftDisplay = fftClamped + 16'sd224;
    
    // Convert to screen coordinate
    wire [9:0] freq_bar_top = GRAPH_Y_MAX - {1'b0, fftDisplay};
    
    wire on_freq_drawn = in_graph && (DrawY == freq_bar_top);

    // -------------------------------------------------------------------------
    // Grid
    // -------------------------------------------------------------------------
    wire on_grid_x = in_graph &&
                     (((DrawX - GRAPH_X_MIN) % GRID_X_STEP) == 10'd0);
    wire on_grid_y = in_graph &&
                     (((GRAPH_Y_MAX - DrawY) % GRID_Y_STEP) == 10'd0);

    // -------------------------------------------------------------------------
    // Axes
    // -------------------------------------------------------------------------
    wire on_baseline = in_graph && (DrawY == GRAPH_Y_MAX);
    wire on_yaxis    = in_graph && (DrawX == GRAPH_X_MIN);

    // -------------------------------------------------------------------------
    // Cursor crosshair
    // -------------------------------------------------------------------------
    wire cursor_in_graph = (BallX >= GRAPH_X_MIN) && (BallX <= GRAPH_X_MAX) &&
                           (BallY >= GRAPH_Y_MIN) && (BallY <= GRAPH_Y_MAX);
    wire on_cursor_h = cursor_in_graph && in_graph && (DrawY == BallY);
    wire on_cursor_v = cursor_in_graph && in_graph && (DrawX == BallX);

    // -------------------------------------------------------------------------
    // Color priority
    // -------------------------------------------------------------------------
    always_comb begin : rgb
        if (on_time_drawn) begin
            // YELLOW - time domain
            Red = 4'hF; Green = 4'hF; Blue = 4'h0;

        end else if (on_freq_drawn) begin
            // WHITE - frequency bars
            Red = 4'hF; Green = 4'hF; Blue = 4'hF;

        end else if (on_cursor_h || on_cursor_v) begin
            // CYAN - cursor
            Red = 4'h0; Green = 4'hF; Blue = 4'hF;

        end else if (on_baseline || on_yaxis) begin
            // BRIGHT GREEN - axes
            Red = 4'h0; Green = 4'hF; Blue = 4'h0;

        end else if (on_grid_x || on_grid_y) begin
            // DARK GREEN - grid
            Red = 4'h0; Green = 4'h4; Blue = 4'h0;

        end else if (in_graph) begin
            // BLACK - background
            Red = 4'h0; Green = 4'h0; Blue = 4'h0;

        end else begin
            // DARK GREY - margins
            Red = 4'h2; Green = 4'h2; Blue = 4'h2;
        end
    end

endmodule
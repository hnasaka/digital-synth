// Color_Mapper.sv  (frequency-domain drawing, 512-bin version)
// ----------------------------------------------------------------------------
// Screen layout (640 x 480):
//
//   X  0 - 31  : left margin   (dark grey, Y-axis area)
//   X 32 - 543 : graph area    (512 frequency bins)
//   X 544 - 639: right margin  (dark grey)
//   Y  0 - 447 : graph area
//   Y 448 - 479: bottom margin (dark grey, X-axis label area)
//
// Inside the graph area:
//   • Black background
//   • Dark green grid lines every 64 px in X (from X_MIN), every 56 px in Y
//   • Bright green baseline at Y = 447
//   • Bright green Y-axis line at X = 32
//   • White thin line: pixel at (DrawX, DrawY) where DrawY == col_ram[DrawX-32]
//     and col_ram entry != EMPTY_Y
//   • Cyan cursor crosshair (1 px H + 1 px V) when cursor is in graph region
// ----------------------------------------------------------------------------

module color_mapper (
    input  logic [9:0]  BallX,          // cursor X from ball.sv
    input  logic [9:0]  BallY,          // cursor Y from ball.sv
    input  logic [9:0]  DrawX,          // current pixel X
    input  logic [9:0]  DrawY,          // current pixel Y
    input  logic [8:0]  regVal,// column RAM from freq_draw

    output logic [3:0]  Red,
    output logic [3:0]  Green,
    output logic [3:0]  Blue,
    
    output logic [8:0] addr
);

    // -------------------------------------------------------------------------
    // Layout constants (must match freq_draw.sv)
    // -------------------------------------------------------------------------
    localparam [9:0] GRAPH_X_MIN  = 10'd32;
    localparam [9:0] GRAPH_X_MAX  = 10'd543;
    localparam [9:0] GRAPH_Y_MIN  = 10'd0;
    localparam [9:0] GRAPH_Y_MAX  = 10'd479;
    localparam [8:0] EMPTY_Y      = 9'd447;

    localparam [9:0] GRID_X_STEP  = 10'd64;
    localparam [9:0] GRID_Y_STEP  = 10'd60;

    // -------------------------------------------------------------------------
    // Pixel classification (all combinational)
    // -------------------------------------------------------------------------
    logic in_graph;
    logic on_baseline;
    logic on_yaxis;
    logic on_grid_x;
    logic on_grid_y;
    logic on_drawn;
    logic cursor_in_graph;
    logic on_cursor_h;
    logic on_cursor_v;

    // RAM index for this pixel column
    wire [8:0] ram_idx = DrawX[8:0] - GRAPH_X_MIN[8:0];
    
    assign addr = ram_idx;

    assign in_graph = (DrawX >= GRAPH_X_MIN) && (DrawX <= GRAPH_X_MAX) &&
                      (DrawY >= GRAPH_Y_MIN) && (DrawY <= GRAPH_Y_MAX);

    assign on_baseline  = in_graph && (DrawY == 10'd240);
    assign on_yaxis     = in_graph && (DrawX == GRAPH_X_MIN);

    // Grid: count from X_MIN / from Y_MAX (so grid is anchored to axes)
    assign on_grid_x = in_graph &&
                       (((DrawX - GRAPH_X_MIN) % GRID_X_STEP) == 10'd0);
    assign on_grid_y = in_graph &&
                       (((GRAPH_Y_MAX - DrawY) % GRID_Y_STEP) == 10'd0);

    // Thin drawn line - only when entry is not the empty baseline sentinel
    assign on_drawn = in_graph &&
                      (regVal != EMPTY_Y) &&
                      (DrawY == {1'b0, regVal});

    // Crosshair
    assign cursor_in_graph = (BallX >= GRAPH_X_MIN) && (BallX <= GRAPH_X_MAX) &&
                             (BallY >= GRAPH_Y_MIN) && (BallY <= GRAPH_Y_MAX);

    assign on_cursor_h = cursor_in_graph && in_graph && (DrawY == BallY);
    assign on_cursor_v = cursor_in_graph && in_graph && (DrawX == BallX);

    // -------------------------------------------------------------------------
    // Color priority (highest = first match)
    // -------------------------------------------------------------------------
    always_comb begin : rgb
        if (on_drawn) begin
            // WHITE - drawn waveform
            Red = 4'hF; Green = 4'hF; Blue = 4'hF;

        end else if (on_cursor_h || on_cursor_v) begin
            // CYAN - cursor crosshair
            Red = 4'h0; Green = 4'hF; Blue = 4'hF;

        end else if (on_baseline || on_yaxis) begin
            // BRIGHT GREEN - axes
            Red = 4'h0; Green = 4'hF; Blue = 4'h0;

        end else if (on_grid_x || on_grid_y) begin
            // DARK GREEN - grid
            Red = 4'h0; Green = 4'h4; Blue = 4'h0;

        end else if (in_graph) begin
            // BLACK - graph background
            Red = 4'h0; Green = 4'h0; Blue = 4'h0;

        end else begin
            // DARK GREY - margins
            Red = 4'h2; Green = 4'h2; Blue = 4'h2;
        end
    end

endmodule
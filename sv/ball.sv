// ball.sv - repurposed as mouse cursor tracker.
// Accumulates signed 8-bit X/Y displacement bytes into a clamped absolute
// screen position, updated once per vsync frame.
// Interface is identical to the original so the top-level needs no changes.

module ball (
    input  logic        Reset,
    input  logic        frame_clk,   // vsync
    input  logic [7:0]  mouse_x,     // signed X displacement
    input  logic [7:0]  mouse_y,     // signed Y displacement

    output logic [9:0]  BallX,
    output logic [9:0]  BallY,
    output logic [9:0]  BallS        // unused downstream - kept for compatibility
);

    localparam [9:0] INIT_X  = 10'd287;   // center of 512-bin graph (32+255)
    localparam [9:0] INIT_Y  = 10'd223;   // center of graph height  (447/2)
    localparam [9:0] X_MIN   = 10'd0;
    localparam [9:0] X_MAX   = 10'd639;
    localparam [9:0] Y_MIN   = 10'd0;
    localparam [9:0] Y_MAX   = 10'd479;
    localparam [9:0] BSIZE   = 10'd1;     // crosshair replaces circle visually

    // Sign-extend 8-bit delta to 11 bits
    logic signed [10:0] dx, dy;
    assign dx = {{3{mouse_x[7]}}, mouse_x};
    assign dy = {{3{mouse_y[7]}}, mouse_y};

    logic signed [10:0] nx, ny;

    always_comb begin
        nx = $signed({1'b0, BallX}) + dx;
        ny = $signed({1'b0, BallY}) + dy;

        // Clamp X
        if (nx < $signed({1'b0, X_MIN})) nx = $signed({1'b0, X_MIN});
        else if (nx > $signed({1'b0, X_MAX})) nx = $signed({1'b0, X_MAX});

        // Clamp Y
        if (ny < $signed({1'b0, Y_MIN})) ny = $signed({1'b0, Y_MIN});
        else if (ny > $signed({1'b0, Y_MAX})) ny = $signed({1'b0, Y_MAX});
    end

    always_ff @(posedge frame_clk) begin
        if (Reset) begin
            BallX <= INIT_X;
            BallY <= INIT_Y;
        end else begin
            BallX <= nx[9:0];
            BallY <= ny[9:0];
        end
    end

    assign BallS = BSIZE;

endmodule
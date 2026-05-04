// freq_draw.sv
// Frequency-domain column RAM with Bresenham line-fill FSM.
//
// - 512 entries (screen columns 32-543), each a 9-bit Y value.
// - Runs entirely on clk_25MHz so the Bresenham loop completes in
//   nanoseconds - no gap regardless of mouse speed.
// - CursorX/Y, left_click, right_click, and vsync arrive from the vsync
//   clock domain and are double-flopped before use.
// - Each vsync rising edge triggers a new Bresenham segment from the
//   previous cursor position to the current one.
// - Right-click or Reset clears all 512 entries sequentially (1 per cycle).
// - Overwrites existing entries.
//
// col_ram index 0 = screen column 32 (GRAPH_X_MIN).
// Color_Mapper reads col_ram combinationally.

module freq_draw (
    input  logic        clk,         // 25 MHz pixel clock
    input  logic        Reset,       // active high synchronous

    // vsync-domain inputs
    input  logic        vsync,
    input  logic [9:0]  CursorX,
    input  logic [9:0]  CursorY,
    input  logic        left_click,
    input  logic        right_click,
    input  logic [8:0]  addr,
    
    output logic [8:0]   regVal,

    // Column RAM - read by Color_Mapper
    //output logic [8:0]  col_ram [0:511]
    
    input logic [8:0] drawAddress,
    output logic [8:0] drawPCM
);

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    localparam [9:0] X_MIN    = 10'd32;
    localparam [9:0] X_MAX    = 10'd543;
    localparam [9:0] Y_MIN    = 10'd0;
    localparam [9:0] Y_MAX    = 10'd447;
    localparam [8:0] EMPTY_Y  = 9'd447;

    // -------------------------------------------------------------------------
    // CDC: double-flop vsync-domain signals into clk_25MHz
    // -------------------------------------------------------------------------
    logic [9:0] cx_s1, cx_s2;
    logic [9:0] cy_s1, cy_s2;
    logic       lc_s1, lc_s2;
    logic       rc_s1, rc_s2;
    logic       vs_s1, vs_s2, vs_prev;
    
    logic [8:0] col_ram[0:511];
    
    assign regVal = col_ram[addr];
    assign drawPCM = col_ram[drawAddress];

    always_ff @(posedge clk) begin
        cx_s1 <= CursorX;    cx_s2 <= cx_s1;
        cy_s1 <= CursorY;    cy_s2 <= cy_s1;
        lc_s1 <= left_click; lc_s2 <= lc_s1;
        rc_s1 <= right_click;rc_s2 <= rc_s1;
        vs_s1 <= vsync;      vs_s2 <= vs_s1;
        vs_prev <= vs_s2;
    end

    wire vsync_re = vs_s2 & ~vs_prev;

    // Stable aliases
    wire [9:0]  cur_x = cx_s2;
    wire [9:0]  cur_y = cy_s2;
    wire        l_clk = lc_s2;
    wire        r_clk = rc_s2;

    // -------------------------------------------------------------------------
    // In-range helpers
    // -------------------------------------------------------------------------
    function automatic logic in_graph;
        input [9:0] x;
        input [9:0] y;
        in_graph = (x >= X_MIN) && (x <= X_MAX) &&
                   (y >= Y_MIN) && (y <= Y_MAX);
    endfunction

    function automatic [8:0] to_idx;
        input [9:0] x;
        to_idx = x[8:0] - X_MIN[8:0];   // x - 32, always fits in 9 bits
    endfunction

    function automatic [8:0] clamp_y;
        input signed [10:0] y;
        if      (y < $signed(11'(Y_MIN))) clamp_y = Y_MIN[8:0];
        else if (y > $signed(11'(Y_MAX))) clamp_y = Y_MAX[8:0];
        else                              clamp_y = y[8:0];
    endfunction

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        WAIT  = 2'b01,
        DRAW  = 2'b10,
        CLEAR = 2'b11
    } state_t;

    state_t state;

    // Bresenham registers
    logic [9:0]         bx;          // current X step
    logic signed [10:0] by;          // current Y step (extra bit for safety)
    logic [9:0]         ex;          // end X of segment
    logic signed [10:0] ey;          // end Y of segment
    logic signed [11:0] err;         // Bresenham error term
    logic signed [11:0] two_dy;      // 2 * |dy| (precomputed)
    logic signed [11:0] two_dy_dx;   // 2 * |dy| - 2 * |dx| (precomputed)
    logic               x_fwd;       // stepping X forward (1) or backward (0)
    logic               y_fwd;       // stepping Y downward/increasing (1) or up (0)

    // Previous segment endpoint
    logic [9:0]         prev_x;
    logic signed [10:0] prev_y;

    // Clear counter
    logic [8:0]         clr_cnt;

    // -------------------------------------------------------------------------
    // Main FSM
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin : main_fsm

        if (Reset) begin
            state   <= CLEAR;
            clr_cnt <= 9'd0;

        end else begin

            case (state)

                // --------------------------------------------------------------
                IDLE: begin
                    if (r_clk) begin
                        state   <= CLEAR;
                        clr_cnt <= 9'd0;

                    end else if (l_clk && in_graph(cur_x, cur_y)) begin
                        // Record first click position; write single pixel
                        prev_x <= cur_x;
                        prev_y <= $signed({1'b0, cur_y});
                        col_ram[to_idx(cur_x)] <= cur_y[8:0];
                        state  <= WAIT;
                    end
                end

                // --------------------------------------------------------------
                // Wait for next vsync, then set up Bresenham from prev to cur.
                WAIT: begin
                    if (r_clk) begin
                        state   <= CLEAR;
                        clr_cnt <= 9'd0;

                    end else if (!l_clk) begin
                        state <= IDLE;

                    end else if (vsync_re && in_graph(cur_x, cur_y)) begin
                        // ---- set up segment prev -> cur ----
                        logic [9:0]         abs_dx;
                        logic signed [10:0] raw_dy;
                        logic signed [10:0] abs_dy;

                        abs_dx = (cur_x >= prev_x)
                                   ? cur_x - prev_x
                                   : prev_x - cur_x;
                        raw_dy = $signed({1'b0, cur_y}) - prev_y;
                        abs_dy = (raw_dy >= 0) ? raw_dy : -raw_dy;

                        x_fwd  <= (cur_x >= prev_x);
                        y_fwd  <= (raw_dy >= 0);

                        bx     <= prev_x;
                        by     <= prev_y;
                        ex     <= cur_x;
                        ey     <= $signed({1'b0, cur_y});

                        // Bresenham error initialisation: 2*dy - dx
                        // (using signed 12-bit to hold products safely)
                        err        <= $signed({1'b0, abs_dy} << 1)
                                    - $signed({2'b0, abs_dx});
                        two_dy     <= $signed({1'b0, abs_dy} << 1);
                        two_dy_dx  <= $signed({1'b0, abs_dy} << 1)
                                    - $signed({2'b0, abs_dx} << 1);

                        state  <= DRAW;
                    end
                end

                // --------------------------------------------------------------
                // Step Bresenham one column per clock cycle.
                DRAW: begin
                    if (r_clk) begin
                        state   <= CLEAR;
                        clr_cnt <= 9'd0;

                    end else begin
                        // Write current pixel
                        if (in_graph(bx, 10'(by > 0 ? by : 11'sd0)))
                            col_ram[to_idx(bx)] <= clamp_y(by);

                        if (bx == ex) begin
                            // Segment complete
                            prev_x <= ex;
                            prev_y <= ey;
                            state  <= WAIT;

                        end else begin
                            // Step X
                            bx <= x_fwd ? bx + 10'd1 : bx - 10'd1;

                            // Step Y if error says so
                            if (err >= 12'sd0) begin
                                by  <= y_fwd ? by + 11'sd1 : by - 11'sd1;
                                err <= err + two_dy_dx;
                            end else begin
                                err <= err + two_dy;
                            end
                        end
                    end
                end

                // --------------------------------------------------------------
                // Clear: one entry per clock cycle
                CLEAR: begin
                    col_ram[clr_cnt] <= EMPTY_Y;
                    if (clr_cnt == 9'd511) begin
                        prev_x <= X_MIN;
                        prev_y <= $signed({1'b0, 10'(EMPTY_Y)});
                        state  <= IDLE;
                    end else begin
                        clr_cnt <= clr_cnt + 9'd1;
                    end
                end

            endcase
        end
    end

endmodule
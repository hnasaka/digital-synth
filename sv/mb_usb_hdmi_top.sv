// mb_usb_hdmi_top.sv
// Modified for frequency-domain drawing with Bresenham column RAM.
//
// GPIO packing (set by lw_usb_main.c - see C snippet below):
//   keycode0_gpio[7:0]   = buf.Xdispl  (signed X displacement)
//   keycode0_gpio[15:8]  = buf.Ydispl  (signed Y displacement)
//   keycode0_gpio[16]    = left button  (bit 0 of buf.button)
//   keycode0_gpio[17]    = right button (bit 1 of buf.button)
//
// Required C change in lw_usb_main.c mousePoll branch:
//   printHex((u32)( (BYTE)buf.Xdispl        |
//                   ((BYTE)buf.Ydispl << 8)  |
//                   ((BYTE)buf.button << 16) ), 1);

module mb_usb_hdmi_top (
    input  logic        Clk,
    input  logic        reset_rtl_0,

    // USB
//    input  logic [0:0]  gpio_usb_int_tri_i,
//    output logic        gpio_usb_rst_tri_o,
//    input  logic        usb_spi_miso,
//    output logic        usb_spi_mosi,
//    output logic        usb_spi_sclk,
//    output logic        usb_spi_ss,

    // UART
//    input  logic        uart_rtl_0_rxd,
//    output logic        uart_rtl_0_txd,

    // HDMI
    output logic        hdmi_tmds_clk_n,
    output logic        hdmi_tmds_clk_p,
    output logic [2:0]  hdmi_tmds_data_n,
    output logic [2:0]  hdmi_tmds_data_p,

//    // HEX displays
//    output logic [7:0]  hex_segA,
//    output logic [3:0]  hex_gridA,
//    output logic [7:0]  hex_segB,
//    output logic [3:0]  hex_gridB
    input logic [31:0] keycode0_gpio,
    
    input logic [8:0] drawAddress,
    output logic [8:0] drawPCM
);

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
//    logic [31:0] keycode0_gpio, keycode1_gpio;
    logic        clk_25MHz, clk_125MHz;
    logic        locked;
    logic [9:0]  drawX, drawY;
    logic [9:0]  ballxsig, ballysig, ballsizesig;
    logic        hsync, vsync, vde;
    logic [3:0]  red, green, blue;
    logic        reset_ah;

    // Column RAM shared between freq_draw (write) and color_mapper (read)
    logic [8:0] addr;
    logic [8:0] regVal;

    // Button extractions from GPIO
    logic        mouse_left, mouse_right;
    assign mouse_left  = keycode0_gpio[16];
    assign mouse_right = keycode0_gpio[17];

    assign reset_ah = reset_rtl_0;

    // -------------------------------------------------------------------------
    // HEX drivers (unchanged)
    // -------------------------------------------------------------------------
//    hex_driver HexA (
//        .clk     (Clk),
//        .reset   (reset_ah),
//        .in      ({keycode0_gpio[31:28], keycode0_gpio[27:24],
//                   keycode0_gpio[23:20], keycode0_gpio[19:16]}),
//        .hex_seg (hex_segA),
//        .hex_grid(hex_gridA)
//    );

//    hex_driver HexB (
//        .clk     (Clk),
//        .reset   (reset_ah),
//        .in      ({keycode0_gpio[15:12], keycode0_gpio[11:8],
//                   keycode0_gpio[7:4],   keycode0_gpio[3:0]}),
//        .hex_seg (hex_segB),
//        .hex_grid(hex_gridB)
//    );

    // -------------------------------------------------------------------------
    // MicroBlaze
    // -------------------------------------------------------------------------
//    mb_block mb_block_i (
//        .clk_100MHz              (Clk),
//        .gpio_usb_int_tri_i      (gpio_usb_int_tri_i),
//        .gpio_usb_keycode_0_tri_o(keycode0_gpio),
//        .gpio_usb_keycode_1_tri_o(keycode1_gpio),
//        .gpio_usb_rst_tri_o      (gpio_usb_rst_tri_o),
//        .reset_rtl_0             (~reset_ah),
//        .uart_rtl_0_rxd          (uart_rtl_0_rxd),
//        .uart_rtl_0_txd          (uart_rtl_0_txd),
//        .usb_spi_miso            (usb_spi_miso),
//        .usb_spi_mosi            (usb_spi_mosi),
//        .usb_spi_sclk            (usb_spi_sclk),
//        .usb_spi_ss              (usb_spi_ss)
//    );

    // -------------------------------------------------------------------------
    // Clock wizard
    // -------------------------------------------------------------------------
    clk_wiz_0 clk_wiz (
        .clk_out1(clk_25MHz),
        .clk_out2(clk_125MHz),
        .reset   (reset_ah),
        .locked  (locked),
        .clk_in1 (Clk)
    );

    // -------------------------------------------------------------------------
    // VGA sync
    // -------------------------------------------------------------------------
    vga_controller vga (
        .pixel_clk    (clk_25MHz),
        .reset        (reset_ah),
        .hs           (hsync),
        .vs           (vsync),
        .active_nblank(vde),
        .drawX        (drawX),
        .drawY        (drawY)
    );

    // -------------------------------------------------------------------------
    // HDMI output
    // -------------------------------------------------------------------------
    hdmi_tx_0 vga_to_hdmi (
        .pix_clk       (clk_25MHz),
        .pix_clkx5     (clk_125MHz),
        .pix_clk_locked(locked),
        .rst           (reset_ah),
        .red           (red),
        .green         (green),
        .blue          (blue),
        .hsync         (hsync),
        .vsync         (vsync),
        .vde           (vde),
        .aux0_din      (4'b0),
        .aux1_din      (4'b0),
        .aux2_din      (4'b0),
        .ade           (1'b0),
        .TMDS_CLK_P    (hdmi_tmds_clk_p),
        .TMDS_CLK_N    (hdmi_tmds_clk_n),
        .TMDS_DATA_P   (hdmi_tmds_data_p),
        .TMDS_DATA_N   (hdmi_tmds_data_n)
    );

    // -------------------------------------------------------------------------
    // Cursor tracker (ball.sv - interface unchanged)
    // -------------------------------------------------------------------------
    ball ball_instance (
        .Reset    (reset_ah),
        .frame_clk(vsync),
        .mouse_x  (keycode0_gpio[7:0]),
        .mouse_y  (keycode0_gpio[15:8]),
        .BallX    (ballxsig),
        .BallY    (ballysig),
        .BallS    (ballsizesig)
    );

    // -------------------------------------------------------------------------
    // Frequency-domain drawing - runs on clk_25MHz
    // -------------------------------------------------------------------------
    freq_draw freq_draw_inst (
        .clk        (clk_25MHz),
        .Reset      (reset_ah),
        .vsync      (vsync),
        .CursorX    (ballxsig),
        .CursorY    (ballysig),
        .left_click (mouse_left),
        .right_click(mouse_right),
        .addr(addr),
        .regVal(regVal),
        .drawAddress(drawAddress),
        .drawPCM(drawPCM)
    );

    // -------------------------------------------------------------------------
    // Color mapper - combinational read of col_ram
    // -------------------------------------------------------------------------
    color_mapper color_instance (
        .BallX  (ballxsig),
        .BallY  (ballysig),
        .DrawX  (drawX),
        .DrawY  (drawY),
        .Red    (red),
        .Green  (green),
        .Blue   (blue),
        .addr(addr),
        .regVal(regVal)
    );

endmodule
`timescale 1 ps / 1 ps
//
`default_nettype none

module baseline_a55 (
    // Board PLL reference clock
    input  wire         pll_refclk_100,
    //
    // User switches and LEDs
    output wire [8-1:0] fpga_user_leds,
    input  wire [4-1:0] fpga_user_switches,
    input  wire [2-1:0] fpga_user_push_buttons,
    //
    //HPS
    //
    // HPS EMIF
    input  wire         emif_hps_emif_ref_clk_0_clk,
    output wire         emif_hps_emif_mem_0_mem_cs,
    output wire [  5:0] emif_hps_emif_mem_0_mem_ca,
    output wire         emif_hps_emif_mem_0_mem_ck_t,
    output wire         emif_hps_emif_mem_0_mem_cke,
    output wire         emif_hps_emif_mem_0_mem_ck_c,
    inout  wire [  3:0] emif_hps_emif_mem_0_mem_dmi,
    inout  wire [ 31:0] emif_hps_emif_mem_0_mem_dq,
    inout  wire [  3:0] emif_hps_emif_mem_0_mem_dqs_t,
    inout  wire [  3:0] emif_hps_emif_mem_0_mem_dqs_c,
    output wire         emif_hps_emif_mem_0_mem_reset_n,
    input  wire         emif_hps_emif_oct_0_oct_rzqin,
    //
    // HPS IO48 Peripherals
    output wire         hps_sdmmc_CCLK,
    inout  wire         hps_sdmmc_CMD,
    inout  wire         hps_sdmmc_D0,
    inout  wire         hps_sdmmc_D1,
    inout  wire         hps_sdmmc_D2,
    inout  wire         hps_sdmmc_D3,
    output wire         hps_emac0_TX_CLK,
    input  wire         hps_emac0_RX_CLK,
    output wire         hps_emac0_TX_CTL,
    input  wire         hps_emac0_RX_CTL,
    output wire         hps_emac0_TXD0,
    output wire         hps_emac0_TXD1,
    input  wire         hps_emac0_RXD0,
    input  wire         hps_emac0_RXD1,
    output wire         hps_emac0_TXD2,
    output wire         hps_emac0_TXD3,
    input  wire         hps_emac0_RXD2,
    input  wire         hps_emac0_RXD3,
    inout  wire         hps_emac0_MDIO,
    output wire         hps_emac0_MDC,
    input  wire         hps_uart1_RX,
    output wire         hps_uart1_TX,
    inout  wire         hps_i2c1_SDA,
    inout  wire         hps_i2c1_SCL,
    inout  wire         hps_gpio1_io4,
    inout  wire         hps_gpio1_io5,
    inout  wire         hps_gpio1_io16,
    inout  wire         hps_gpio1_io19,
    input  wire         hps_usb0_CLK,
    inout  wire         hps_usb0_DATA0,
    inout  wire         hps_usb0_DATA1,
    inout  wire         hps_usb0_DATA2,
    inout  wire         hps_usb0_DATA3,
    inout  wire         hps_usb0_DATA4,
    inout  wire         hps_usb0_DATA5,
    inout  wire         hps_usb0_DATA6,
    inout  wire         hps_usb0_DATA7,
    input  wire         hps_usb0_DIR,
    input  wire         hps_usb0_NXT,
    output wire         hps_usb0_STP,
    //
    // HPS External Oscillator
    input  wire         hps_osc_clk,
    //
    // GPIO 0 header (JP1): UART, I2C and SPI on the pins a Raspberry Pi has them on; 5 V on pin 11, GND on pin 12
    input  wire         jp1_9_ptp_trig,    // EMAC0 aux snapshot trigger 1 (extts)
    output wire         jp1_7_ptp_pps,     // EMAC0 PPS output 1 (perout)
    input  wire         jp1_10_uart0_rx,    // HPS UART0 RX (GNSS TX)
    output wire         jp1_8_uart0_tx,    // HPS UART0 TX (GNSS RX)
    inout  wire         jp1_5_i2c_scl,     // HPS I2C_EMAC0, spare
    inout  wire         jp1_3_i2c_sda,
    output wire         jp1_23_spi_sclk,    // HPS SPI master 0, spare
    output wire         jp1_19_spi_mosi,
    input  wire         jp1_21_spi_miso,
    output wire         jp1_24_spi_ss0_n,
    //
    // I2C bus of the HDMI transmitter (ADV7513) and the fan controller (AMC6821), on HPS I2C0
    inout  wire         hdmi_i2c_scl,
    inout  wire         hdmi_i2c_sda,
    //
    // HDMI transmitter (ADV7513) video inputs, and the 50 MHz clock for the pixel clock PLL
    input  wire         hdmi_clk50,
    output wire         hdmi_tx_clk,
    output wire [23:0]  hdmi_tx_d,
    output wire         hdmi_tx_de,
    output wire         hdmi_tx_hs,
    output wire         hdmi_tx_vs
    //
    // External FPGA Reset (unused)
    // input  wire              fpga_reset_n
);

    // Constants
    localparam LED_PIO_WIDTH = 32;
    localparam DIPSW_PIO_WIDTH = 32;
    localparam BUTTONS_PIO_WIDTH = 32;

    // Clock and Reset
    wire sys_clk_100;
    wire sys_clk_100_reset_n;
    wire [31:0] niosv_pio_in;
    // Set this bit to enable the NiosV firmware. Disabled by default.
    wire nios_enable = 1'b0;
    assign niosv_pio_in = {31'b0, nios_enable};

    wire [31:0] niosv_pio_out;
    wire nios_start;
    wire nios_done;
    wire nios_f2sdram_pass;
    wire nios_f2h_pass;
    assign nios_start = niosv_pio_out[0];
    assign nios_f2sdram_pass = niosv_pio_out[1];
    assign nios_f2h_pass = niosv_pio_out[2];
    assign nios_done = niosv_pio_out[3];

    // Debounce logic to clean out push button glitches within 1ms
    wire [BUTTONS_PIO_WIDTH-1:0] fpga_debounced_buttons;
    wire [BUTTONS_PIO_WIDTH-1:0] fpga_push_buttons;
    assign fpga_push_buttons = {
        {BUTTONS_PIO_WIDTH - $size(fpga_user_push_buttons) {1'b0}}, fpga_user_push_buttons
    };

    debounce #(
        .WIDTH        (32),
        .POLARITY     ("LOW"),
        .TIMEOUT      (10000),  // at 100MHz this is a debounce time of 1ms
        .TIMEOUT_WIDTH(32)      // ceil(log2(TIMEOUT))
    ) debounce_inst (
        .clk     (sys_clk_100),
        .reset_n (sys_clk_100_reset_n),
        .data_in (fpga_push_buttons),
        .data_out(fpga_debounced_buttons)
    );

    // Assign DIPSW I/O
    wire [DIPSW_PIO_WIDTH-1:0] fpga_switches;
    assign fpga_switches = {
        {DIPSW_PIO_WIDTH - $size(fpga_user_switches) {1'b0}}, fpga_user_switches
    };

    // Create a heartbeat counter
    reg [22:0] heartbeat_count;
    always @(posedge sys_clk_100) begin
        if (!sys_clk_100_reset_n) begin
            heartbeat_count <= '0;
        end else begin
            heartbeat_count <= heartbeat_count + 23'd1;
        end
    end

    // Create a heartbeat LED
    wire heartbeat_led;
    assign heartbeat_led = heartbeat_count[22];

    // LED PIO
    wire [LED_PIO_WIDTH-1:0] fpga_leds;

    // Drive the USER PIN LEDs to be the HPS LED outputs
    // in addition to the heartbeat LED
    // LEDs 0 to 2 are HDMI diagnostics (below); 3 to 6 stay with the HPS; 7 is the heartbeat.
    wire [2:0] hdmi_diag;
    assign fpga_user_leds = {heartbeat_led, fpga_leds[6:3], hdmi_diag};


    // Tie off all fabric to HPS interrupts
    wire [31:0] fpga2hps_interrupts;
    assign fpga2hps_interrupts = '0;

    // Directly loop reset request signal to the reset acknowledge signals.
    logic h2f_warm_reset_handshake_reset_ack;
    logic h2f_warm_reset_handshake_reset_req;

    assign h2f_warm_reset_handshake_reset_ack = h2f_warm_reset_handshake_reset_req;

    // Baseline-A55 system top module
    wire i2c0_scl_oe, i2c0_sda_oe, i2c2_scl_oe, i2c2_sda_oe;
    wire         hdmi_pix_clk, hdmi_pll_locked;
    wire         hdmi_dbg_bad;
    wire [26:0]  hdmi_mem_address;
    wire [4:0]   hdmi_mem_burstcount;
    wire         hdmi_mem_read, hdmi_mem_readdatavalid, hdmi_mem_waitrequest;
    wire [255:0] hdmi_mem_readdata;

    baseline_top u_baseline_top (
        // Board PLL reference clock
        .pll_refclk_100_clk                   (pll_refclk_100),
        // External FPGA reset (unused)
        .fpga_reset_n_reset_n                 (1'b1),
        // System clock and reset to FPGA
        .system_clk_clk                       (sys_clk_100),
        .system_reset_n_reset_n               (sys_clk_100_reset_n),
        //
        //HPS
        // HPS Clock
        .hps_io_hps_osc_clk                   (hps_osc_clk),
        // HPS reset to the fabric
        .h2f_warm_reset_handshake_reset_req   (h2f_warm_reset_handshake_reset_req),
        .h2f_warm_reset_handshake_reset_ack   (h2f_warm_reset_handshake_reset_ack),
        // HPS EMIF interface
        .emif_hps_emif_mem_0_mem_cs           (emif_hps_emif_mem_0_mem_cs),
        .emif_hps_emif_mem_0_mem_ca           (emif_hps_emif_mem_0_mem_ca),
        .emif_hps_emif_mem_0_mem_cke          (emif_hps_emif_mem_0_mem_cke),
        .emif_hps_emif_mem_0_mem_dq           (emif_hps_emif_mem_0_mem_dq),
        .emif_hps_emif_mem_0_mem_dqs_t        (emif_hps_emif_mem_0_mem_dqs_t),
        .emif_hps_emif_mem_0_mem_dqs_c        (emif_hps_emif_mem_0_mem_dqs_c),
        .emif_hps_emif_mem_0_mem_dmi          (emif_hps_emif_mem_0_mem_dmi),
        .emif_hps_emif_mem_ck_0_mem_ck_t      (emif_hps_emif_mem_0_mem_ck_t),
        .emif_hps_emif_mem_ck_0_mem_ck_c      (emif_hps_emif_mem_0_mem_ck_c),
        .emif_hps_emif_mem_reset_n_mem_reset_n(emif_hps_emif_mem_0_mem_reset_n),
        .emif_hps_emif_oct_0_oct_rzqin        (emif_hps_emif_oct_0_oct_rzqin),
        .emif_hps_emif_ref_clk_0_clk          (emif_hps_emif_ref_clk_0_clk),
        // HPS Peripherals
        .hps_io_emac0_tx_clk                  (hps_emac0_TX_CLK),
        .hps_io_emac0_rx_clk                  (hps_emac0_RX_CLK),
        .hps_io_emac0_tx_ctl                  (hps_emac0_TX_CTL),
        .hps_io_emac0_rx_ctl                  (hps_emac0_RX_CTL),
        .hps_io_emac0_txd0                    (hps_emac0_TXD0),
        .hps_io_emac0_txd1                    (hps_emac0_TXD1),
        .hps_io_emac0_rxd0                    (hps_emac0_RXD0),
        .hps_io_emac0_rxd1                    (hps_emac0_RXD1),
        .hps_io_emac0_txd2                    (hps_emac0_TXD2),
        .hps_io_emac0_txd3                    (hps_emac0_TXD3),
        .hps_io_emac0_rxd2                    (hps_emac0_RXD2),
        .hps_io_emac0_rxd3                    (hps_emac0_RXD3),
        .hps_io_mdio0_mdio                    (hps_emac0_MDIO),
        .hps_io_mdio0_mdc                     (hps_emac0_MDC),
        .hps_io_sdmmc_cclk                    (hps_sdmmc_CCLK),
        .hps_io_sdmmc_cmd                     (hps_sdmmc_CMD),
        .hps_io_sdmmc_data0                   (hps_sdmmc_D0),
        .hps_io_sdmmc_data1                   (hps_sdmmc_D1),
        .hps_io_sdmmc_data2                   (hps_sdmmc_D2),
        .hps_io_sdmmc_data3                   (hps_sdmmc_D3),
        .hps_io_uart1_tx                      (hps_uart1_TX),
        .hps_io_uart1_rx                      (hps_uart1_RX),
        .hps_io_usb0_clk                      (hps_usb0_CLK),
        .hps_io_usb0_stp                      (hps_usb0_STP),
        .hps_io_usb0_dir                      (hps_usb0_DIR),
        .hps_io_usb0_nxt                      (hps_usb0_NXT),
        .hps_io_usb0_data0                    (hps_usb0_DATA0),
        .hps_io_usb0_data1                    (hps_usb0_DATA1),
        .hps_io_usb0_data2                    (hps_usb0_DATA2),
        .hps_io_usb0_data3                    (hps_usb0_DATA3),
        .hps_io_usb0_data4                    (hps_usb0_DATA4),
        .hps_io_usb0_data5                    (hps_usb0_DATA5),
        .hps_io_usb0_data6                    (hps_usb0_DATA6),
        .hps_io_usb0_data7                    (hps_usb0_DATA7),
        .hps_io_i2c1_sda                      (hps_i2c1_SDA),
        .hps_io_i2c1_scl                      (hps_i2c1_SCL),
        .hps_io_gpio28                        (hps_gpio1_io4),
        .hps_io_gpio34                        (hps_gpio1_io5),
        .hps_io_gpio40                        (hps_gpio1_io16),
        .hps_io_gpio41                        (hps_gpio1_io19),
        //
        // Interrupts
        .f2h_interrupts_irq                   (fpga2hps_interrupts),
        //
        // LEDs, Push Buttons and DIP Switches IOs
        .user_leds_export                     (fpga_leds),
        .user_switches_export                 (fpga_switches),
        .user_push_buttons_export             (fpga_debounced_buttons),
        //
        // NiosV subsys PIO
        .niosv_pio_in_export                  (niosv_pio_in),
        .niosv_pio_out_export                 (niosv_pio_out),
        //
        // EMAC0 PTP
        .emac0_ptp_mac_ptp_trig               (jp1_9_ptp_trig),
        .emac0_ptp_mac_ptp_pps                (jp1_7_ptp_pps),
        .emac0_ptp_mac_ptp_tstmp_data         (),
        .emac0_ptp_mac_ptp_tstmp_en           (),
        // UART0, no flow control
        .uart0_rx                             (jp1_10_uart0_rx),
        .uart0_tx                             (jp1_8_uart0_tx),
        .uart0_cts_n                          (1'b0),
        .uart0_dsr_n                          (1'b0),
        .uart0_dcd_n                          (1'b0),
        .uart0_ri_n                           (1'b1),
        .uart0_rts_n                          (),
        .uart0_dtr_n                          (),
        .uart0_out1_n                         (),
        .uart0_out2_n                         (),
        // I2C0: HDMI transmitter and fan controller
        .I2C0_scl_i_clk                       (hdmi_i2c_scl),
        .I2C0_scl_oe_clk                      (i2c0_scl_oe),
        .I2C0_sda_i                           (hdmi_i2c_sda),
        .I2C0_sda_oe                          (i2c0_sda_oe),
        // I2C_EMAC0: spare, on the header
        .emac0_i2c_mac_scl_i                  (jp1_5_i2c_scl),
        .emac0_i2c_mac_scl_oe                 (i2c2_scl_oe),
        .emac0_i2c_mac_sda_i                  (jp1_3_i2c_sda),
        .emac0_i2c_mac_sda_oe                 (i2c2_sda_oe),
        // SPI master 0: spare, on the header
        .spim0_sclk_out_clk                   (jp1_23_spi_sclk),
        .spim0_mosi_o                         (jp1_19_spi_mosi),
        .spim0_mosi_oe                        (),
        .spim0_miso_i                         (jp1_21_spi_miso),
        .spim0_ss_in_n                        (1'b1),
        .spim0_ss0_n_o                        (jp1_24_spi_ss0_n),
        .spim0_ss1_n_o                        (),
        .spim0_ss2_n_o                        (),
        .spim0_ss3_n_o                        (),
        // HDMI: pixel clock, and the frame buffer read port into HPS memory
        .hdmi_clk50_clk                       (hdmi_clk50),
        .hdmi_pix_clk_clk                     (hdmi_pix_clk),
        .hdmi_pll_locked_export               (hdmi_pll_locked),
        .hdmi_mem_address                     (hdmi_mem_address),
        .hdmi_mem_burstcount                  (hdmi_mem_burstcount),
        .hdmi_mem_read                        (hdmi_mem_read),
        .hdmi_mem_readdata                    (hdmi_mem_readdata),
        .hdmi_mem_readdatavalid               (hdmi_mem_readdatavalid),
        .hdmi_mem_waitrequest                 (hdmi_mem_waitrequest),
        .hdmi_mem_write                       (1'b0),
        .hdmi_mem_writedata                   (256'b0),
        .hdmi_mem_byteenable                  ({32{1'b1}})
    );

    hdmi_scanout u_hdmi_scanout (
        .mem_clk           (sys_clk_100),
        .mem_reset_n       (sys_clk_100_reset_n),
        .mem_address       (hdmi_mem_address),
        .mem_burstcount    (hdmi_mem_burstcount),
        .mem_read          (hdmi_mem_read),
        .mem_readdata      (hdmi_mem_readdata),
        .mem_readdatavalid (hdmi_mem_readdatavalid),
        .mem_waitrequest   (hdmi_mem_waitrequest),
        .pix_clk           (hdmi_pix_clk),
        .pix_pll_locked    (hdmi_pll_locked),
        .vid_d             (hdmi_tx_d),
        .vid_de            (hdmi_tx_de),
        .vid_hs            (hdmi_tx_hs),
        .vid_vs            (hdmi_tx_vs),
        .dbg_bad           (hdmi_dbg_bad)
    );
    // The pixel clock goes to the transmitter not inverted, as in Terasic's and Macnica's
    // designs. Timing report of 2026-11-13: the clock pin is 2.1 to 3.1 ns faster than the data
    // pins, so the transmitter's rising edge falls 3.6 ns or more after the data of the previous
    // cycle settled and 2.1 ns or more before it changes (it needs 1.8 ns and 1.3 ns). Inverted,
    // as it was at first, the edge came 0.3 to 0.8 ns after the data changed.
    assign hdmi_tx_clk = hdmi_pix_clk;

    // HDMI diagnostics on LEDs 0 to 2:
    //   0: pixel PLL locked now
    //   1: the PLL lost lock at some time since it first locked (stays until the fabric is reloaded)
    //   2: the scan-out ran out of frame buffer data in the last half second
    reg  [1:0]  hdmi_lock_sync;
    reg         hdmi_seen_lock, hdmi_lost_lock;
    always_ff @(posedge sys_clk_100) begin
        hdmi_lock_sync <= {hdmi_lock_sync[0], hdmi_pll_locked};
        if (!sys_clk_100_reset_n) begin
            hdmi_seen_lock <= 1'b0; hdmi_lost_lock <= 1'b0;
        end else begin
            if (hdmi_lock_sync[1])                     hdmi_seen_lock <= 1'b1;
            if (hdmi_seen_lock && !hdmi_lock_sync[1])  hdmi_lost_lock <= 1'b1;
        end
    end
    reg [26:0] hdmi_bad_stretch;
    always_ff @(posedge hdmi_pix_clk) begin
        if (hdmi_tx_de && hdmi_dbg_bad)        hdmi_bad_stretch <= 27'd74_250_000;
        else if (hdmi_bad_stretch != 27'd0)    hdmi_bad_stretch <= hdmi_bad_stretch - 27'd1;
    end
    assign hdmi_diag = {hdmi_bad_stretch != 27'd0, hdmi_lost_lock, hdmi_lock_sync[1]};

    // I2C lines are open drain: drive low or release.
    assign hdmi_i2c_scl   = i2c0_scl_oe ? 1'b0 : 1'bz;
    assign hdmi_i2c_sda   = i2c0_sda_oe ? 1'b0 : 1'bz;
    assign jp1_5_i2c_scl = i2c2_scl_oe ? 1'b0 : 1'bz;
    assign jp1_3_i2c_sda = i2c2_sda_oe ? 1'b0 : 1'bz;

endmodule

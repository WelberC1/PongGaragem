/**
 * Pong-Garagem: GAR-8 + ROM 2 KB + RAM 16 KB + E/S 0 (botões, serial, LEDs, tempo).
 * Mapa de memória e portas: docs/isa.md.
 * Padrões para a Tang Nano 20K (clk = 27 MHz); o testbench diminui os divisores.
 */
module gar8_soc
  #(parameter ROM_FILE = "rom.hex",
    parameter CE_DIV   = 9,        // 27 MHz / 9 = 3 MHz na CPU
    parameter UART_DIV = 2813,     // 27 MHz / 9600 bps
    parameter TICK_DIV = 270000)   // 27 MHz / 100 Hz
   (
    input        clk,
    input        rst,
    input        btn,      // S2
    input        uart_rx,
    output       uart_tx,
    output [5:0] led_n     // LEDs da placa acendem em nível baixo
    );

   // ---------- clock enable da CPU ----------
   reg [7:0] cediv = 0;
   wire      ce = (cediv == CE_DIV - 1);
   always @(posedge clk) cediv <= ce ? 0 : cediv + 1;

   // ---------- CPU ----------
   wire [15:0] addr;
   wire [7:0]  wdata, rdata, io_port, io_wdata;
   reg [7:0]   io_rdata;
   wire        we, io_rd, io_wr, halted;

   gar8_cpu cpu(.clk(clk), .rst(rst), .ce(ce),
                .addr(addr), .wdata(wdata), .we(we), .rdata(rdata),
                .io_port(io_port), .io_wdata(io_wdata), .io_rd(io_rd), .io_wr(io_wr),
                .io_rdata(io_rdata), .halted(halted));

   // ---------- memória: A15 = 0 ROM, A15 = 1 RAM ----------
   reg [7:0] rom [0:2047];
   reg [7:0] ram [0:16383];
   reg [7:0] rom_q, ram_q;
   initial $readmemh(ROM_FILE, rom);
   always @(posedge clk) rom_q <= rom[addr[10:0]];
   always @(posedge clk) begin
      if (we && addr[15]) ram[addr[13:0]] <= wdata;
      ram_q <= ram[addr[13:0]];
   end
   assign rdata = addr[15] ? ram_q : rom_q;

   // ---------- serial 8N1 ----------
   reg [1:0]  rx_sync = 2'b11;
   always @(posedge clk) rx_sync <= {rx_sync[0], uart_rx};
   wire       rx = rx_sync[1];

   reg [15:0] rc = 0;
   reg [3:0]  rb = 0;
   reg        rbusy = 0, rx_ready = 0;
   reg [7:0]  rsh = 0, rx_data = 0;
   always @(posedge clk) begin
      if (io_rd && io_port == 8'h02) rx_ready <= 0;
      if (!rbusy) begin
         if (!rx) begin rbusy <= 1; rc <= UART_DIV / 2; rb <= 0; end
      end else if (rc != 0) rc <= rc - 1;
      else begin
         rc <= UART_DIV - 1;
         rb <= rb + 1;
         if (rb == 0) begin if (rx) rbusy <= 0; end      // start falso
         else if (rb <= 8) rsh <= {rx, rsh[7:1]};
         else begin rbusy <= 0; rx_data <= rsh; rx_ready <= 1; end
      end
   end

   reg [9:0]  tsh = 10'h3FF;
   reg [3:0]  tbits = 0;
   reg [15:0] tc = 0;
   wire       tx_busy = (tbits != 0);
   assign uart_tx = tsh[0];
   always @(posedge clk)
     if (io_wr && io_port == 8'h02 && !tx_busy) begin
        tsh <= {1'b1, io_wdata, 1'b0}; tbits <= 10; tc <= UART_DIV - 1;
     end else if (tx_busy) begin
        if (tc == 0) begin tsh <= {1'b1, tsh[9:1]}; tbits <= tbits - 1; tc <= UART_DIV - 1; end
        else tc <= tc - 1;
     end

   // ---------- contador de tempo (100 Hz) ----------
   reg [19:0] tdiv = 0;
   reg [7:0]  tick = 0;
   always @(posedge clk)
     if (tdiv == TICK_DIV - 1) begin tdiv <= 0; tick <= tick + 1; end
     else tdiv <= tdiv + 1;

   // ---------- LEDs ----------
   reg [5:0] leds = 0;
   assign led_n = ~leds;
   always @(posedge clk)
     if (rst) leds <= 0;
     else if (io_wr && io_port == 8'h03) leds <= io_wdata[5:0];

   // ---------- leitura de E/S 0 ----------
   always @* case (io_port)
     8'h00:   io_rdata = {7'b0, btn};
     8'h01:   io_rdata = {6'b0, tx_busy, rx_ready};
     8'h02:   io_rdata = rx_data;
     8'h03:   io_rdata = tick;
     default: io_rdata = 8'h00;
   endcase
endmodule

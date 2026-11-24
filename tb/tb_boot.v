// Testa o bootloader pela serial: boot pela ROM, carga certa, soma errada e tamanho grande.
`timescale 1ns/1ns
`include "carga.vh"   // gerado pelo build.py: CARGA_LEN e CARGA_SUM
module tb_boot;
   localparam DIV = 64;                // clks por bit da serial
   reg clk = 0, rst = 1, rx = 1;
   wire tx; wire [5:0] led_n;
   gar8_soc #(.ROM_FILE("rom.hex"), .CE_DIV(2), .UART_DIV(DIV), .TICK_DIV(400)) dut
     (.clk(clk), .rst(rst), .btn(5'b0), .uart_rx(rx), .uart_tx(tx), .led_n(led_n));
   always #1 clk = ~clk;

   reg [7:0] carga [0:4095];
   initial $readmemh("carga.hex", carga);

   // ---- recebe e mostra o que a placa envia ----
   reg [8*16-1:0] ultimos = 0;          // últimos 16 caracteres
   integer i;
   reg [7:0] ch;
   always begin
      @(negedge tx);
      repeat (DIV + DIV/2) @(posedge clk);
      for (i = 0; i < 8; i = i + 1) begin ch[i] = tx; repeat (DIV) @(posedge clk); end
      ultimos = {ultimos[8*15-1:0], ch};
      if (ch == 10) $write("\n"); else if (ch >= 32) $write("%c", ch); else $write("<%h>", ch);
   end

   task envia(input [7:0] b);
      integer k;
      begin
         rx = 0; repeat (DIV) @(posedge clk);
         for (k = 0; k < 8; k = k + 1) begin rx = b[k]; repeat (DIV) @(posedge clk); end
         rx = 1; repeat (DIV) @(posedge clk);
      end
   endtask

   // espera os últimos n caracteres serem s
   task espera(input [8*16-1:0] s, input integer n);
      integer t;
      reg [8*16-1:0] mask;
      begin
         mask = ~(~128'b0 << (8*n));
         t = 0;
         while ((ultimos & mask) != (s & mask) && t < 2000000) begin @(posedge clk); t = t + 1; end
         if (t >= 2000000) begin $display("\nFALHA: esperava \"%0s\"", s); $finish; end
      end
   endtask

   task reinicia;
      begin rst = 1; repeat (10) @(posedge clk); ultimos = 0; rst = 0; end
   endtask

   integer j;
   initial begin
      // 1) sem 'S': depois de 2 s roda o SO da ROM
      $display("--- 1) boot pela ROM");
      reinicia;
      espera("boot\015\012", 6);
      espera("(eco)\015\012", 7);
      envia("a"); espera("a", 1);       // o SO faz eco

      // 2) carga certa: roda o programa novo
      $display("\n--- 2) carga pela serial");
      reinicia;
      espera("boot\015\012", 6);
      envia("S"); espera(">", 1);
      envia(`CARGA_LEN & 8'hFF); envia(`CARGA_LEN >> 8);
      for (j = 0; j < `CARGA_LEN; j = j + 1) envia(carga[j]);
      envia(`CARGA_SUM);
      espera("KNOVO\015\012", 7);

      // 3) soma errada: 'E' e reinicia
      $display("\n--- 3) soma errada");
      reinicia;
      espera("boot\015\012", 6);
      envia("S"); espera(">", 1);
      envia(1); envia(0); envia(8'h42); envia(8'h43);
      espera("E", 1);
      espera("boot\015\012", 6);
      espera("(eco)\015\012", 7);

      // 4) tamanho acima de 0800h: 'E'
      $display("\n--- 4) tamanho grande");
      reinicia;
      espera("boot\015\012", 6);
      envia("S"); espera(">", 1);
      envia(8'h01); envia(8'h08);
      espera("E", 1);

      $display("\nOK: bootloader passou nos 4 testes");
      $finish;
   end
endmodule

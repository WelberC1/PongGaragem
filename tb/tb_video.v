// Roda sw/teste_video.asm com os relógios reais (27 MHz e 25,2 MHz) por 5 quadros:
// confere a varredura, alguns pixels, o placar, o som (I2S) e os botões,
// e grava o 4º quadro em quadro.ppm (o build.py converte para build/quadro.png).
`timescale 1ns/1ps
module tb_video;
   reg clk = 0, clk_pix = 0, rst = 1;
   reg [4:0] btn = 5'b00100;                  // jogador 1 segurando "desce"
   wire tx, hs, vs, de, bck, ws, din;
   wire [5:0] led_n;
   wire [7:0] r, g, b;

   gar8_soc #(.ROM_FILE("salto.hex"), .TICK_DIV(27000)) dut   // "10 ms" = 1 ms aqui
     (.clk(clk), .rst(rst), .btn(btn), .uart_rx(1'b1), .uart_tx(tx), .led_n(led_n),
      .clk_pix(clk_pix), .vid_r(r), .vid_g(g), .vid_b(b), .vid_hs(hs), .vid_vs(vs), .vid_de(de),
      .i2s_bck(bck), .i2s_ws(ws), .i2s_din(din));
   always #18.519 clk = ~clk;       // 27 MHz
   always #19.841 clk_pix = ~clk_pix; // 25,2 MHz

   initial $readmemh("teste_video.hex", dut.ram);   // programa já em 8000h; a ROM só pula para lá

   integer erros = 0;
   task confere(input ok, input [8*48-1:0] msg);
      if (!ok) begin $display("FALHA: %0s", msg); erros = erros + 1; end
   endtask

   // ---------- quadros, varredura e captura ----------
   integer quadros = 0, px = 0, linhas = 0, arq = 0;
   reg hs_ant = 1;
   reg [7:0] bx, by, r1;

   always @(posedge clk_pix) begin
      hs_ant <= hs;
      if (dut.video.quadro) begin
         if (quadros == 4) begin
            confere(px == 640 * 480, "pixels visíveis no quadro");
            confere(linhas == 525, "linhas por quadro");
            $fclose(arq);
         end
         quadros = quadros + 1;
         px = 0; linhas = 0;
         if (quadros == 4) begin
            arq = $fopen("quadro.ppm", "w");
            $fwrite(arq, "P3\n640 480\n255\n");
            bx = dut.bola_x; by = dut.bola_y; r1 = dut.raq1;
         end
      end
      if (quadros == 4) begin
         if (hs_ant && !hs) linhas = linhas + 1;
         if (de) begin
            $fwrite(arq, "%0d %0d %0d\n", r, g, b);
            // pixels de referência
            if (px == (by * 4 + 4) * 640 + bx * 4 + 4) confere(r == 255, "centro da bola aceso");
            if (px == (r1 * 4 + 32) * 640 + 18)          confere(g == 255, "raquete 1 acesa");
            if (px == 302 * 640 + 202)                   confere(b == 0,   "fundo apagado");
            if (px == 1 * 640 + 317)                     confere(r == 255, "rede acesa");
            if (px == 9 * 640 + 317)                     confere(r == 0,   "falha da rede apagada");
            if (px == 17 * 640 + 273)                    confere(r == 255, "placar 1 = '1' aceso");
            if (px == 17 * 640 + 265)                    confere(r == 0,   "placar 1 sem dezena");
            px = px + 1;
         end
      end
   end

   // ---------- som: decodifica o I2S (canal esquerdo) ----------
   reg [15:0] sh = 0, amostra = 0, ant = 0;
   reg        ws_ant = 0;
   integer    seguidas = 0, viu53 = 0, viu106 = 0, tocou = 0;
   always @(posedge bck) begin
      sh = {sh[14:0], din};
      if (ws && !ws_ant) begin
         amostra = sh;
         if (amostra != 0) tocou = 1;
         if (amostra == ant) seguidas = seguidas + 1;
         else begin
            if (ant != 0 && amostra != 0 && seguidas == 53)  viu53 = 1;
            if (ant != 0 && amostra != 0 && seguidas == 106) viu106 = 1;
            seguidas = 1;
         end
         ant = amostra;
      end
      ws_ant = ws;
   end

   initial begin
      #200 rst = 0;
      wait (quadros == 5);
      confere(dut.placar1 == 1 && dut.placar2 == 1, "placar depois de 2 quiques");
      confere(r1 > 52, "raquete 1 desceu com o botão");
      confere(~led_n == 6'b000100, "LEDs mostram os botões");
      confere(tocou, "som tocou");
      confere(viu106 && viu53, "notas de 106 e 53 amostras");
      confere(amostra == 0, "som parou sozinho");
      if (erros == 0) $display("OK: vídeo, som e botões");
      $finish;
   end
   initial begin #120_000_000 $display("FALHA: tempo esgotado, quadros=%0d pc=%h", quadros, dut.cpu.pc); $finish; end
endmodule

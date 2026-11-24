/**
 * Desenhista do Pong: varredura 640x480 a 60 Hz e cor de cada pixel.
 * A tela é uma grade de 160x120 casas de 4x4 pixels; as posições vêm das portas 80h-86h.
 * Bola 2x2 casas, raquetes 2x16 casas (colunas 4 e 154), rede na coluna 79,
 * placar com dígitos de 3x5 "pixels de fonte" de 2x2 casas.
 */
module gar8_video
  (
   input            clk_pix,   // 25,2 MHz
   input [7:0]      bola_x, bola_y, raq1, raq2, placar1, placar2,
   input [7:0]      cor,       // RRRGGGBB da frente; o fundo é preto
   output reg [7:0] r, g, b,
   output reg       hs, vs, de,
   output           quadro     // pulso de 1 clk_pix no início do retraço vertical
   );

   // ---------- varredura ----------
   reg [9:0] hc = 0, vc = 0;
   always @(posedge clk_pix) begin
      hc <= (hc == 799) ? 0 : hc + 1;
      if (hc == 799) vc <= (vc == 524) ? 0 : vc + 1;
   end
   assign quadro = (hc == 0 && vc == 480);

   wire [7:0] cx = hc[9:2], cy = vc[9:2];   // casa atual (válida na área visível)

   // está dentro do intervalo [ini, ini+tam) ? (9 bits para não estourar perto de 255)
   function dentro(input [7:0] c, input [7:0] ini, input [7:0] tam);
      dentro = ({1'b0, c} >= {1'b0, ini}) && ({1'b0, c} < {1'b0, ini} + tam);
   endfunction

   // ---------- fonte 3x5 dos dígitos (linha 0 em cima, bit 2 = coluna da esquerda) ----------
   function [2:0] fonte(input [3:0] d, input [2:0] lin);
      reg [14:0] f;
      begin
         case (d)
           0: f = 15'b111_101_101_101_111;
           1: f = 15'b010_110_010_010_111;
           2: f = 15'b111_001_111_100_111;
           3: f = 15'b111_001_111_001_111;
           4: f = 15'b101_101_111_001_001;
           5: f = 15'b111_100_111_001_111;
           6: f = 15'b111_100_111_101_111;
           7: f = 15'b111_001_001_001_001;
           8: f = 15'b111_101_111_101_111;
           default: f = 15'b111_101_111_001_111;
         endcase
         fonte = f >> (3 * (4 - lin));
      end
   endfunction

   // dezenas de 0..99 (acima de 99 mostra 99)
   function [3:0] dezena(input [7:0] v);
      dezena = (v >= 90) ? 9 : (v >= 80) ? 8 : (v >= 70) ? 7 : (v >= 60) ? 6 : (v >= 50) ? 5 :
               (v >= 40) ? 4 : (v >= 30) ? 3 : (v >= 20) ? 2 : (v >= 10) ? 1 : 0;
   endfunction

   // dígito d na casa (x0, 4): 6x10 casas; apaga se "apagar"
   function digito(input [7:0] x0, input [3:0] d, input apagar, input [7:0] x, input [7:0] y);
      reg [2:0] linha;
      reg [7:0] dx, dy;
      begin
         dx = x - x0; dy = y - 8'd4;
         linha = fonte(d, dy[3:1]);
         digito = !apagar && dentro(x, x0, 6) && dentro(y, 4, 10) && linha[2 - dx[2:1]];
      end
   endfunction

   function placar(input [7:0] x0, input [7:0] v, input [7:0] x, input [7:0] y);
      reg [3:0] dz;
      reg [7:0] vv;
      begin
         vv = (v > 99) ? 8'd99 : v;
         dz = dezena(vv);
         placar = digito(x0, dz, dz == 0, x, y) || digito(x0 + 8, vv - dz * 10, 1'b0, x, y);
      end
   endfunction

   wire visivel = (hc < 640) && (vc < 480);
   wire acende = (dentro(cx, bola_x, 2) && dentro(cy, bola_y, 2))
              || (dentro(cx, 4, 2)   && dentro(cy, raq1, 16))
              || (dentro(cx, 154, 2) && dentro(cy, raq2, 16))
              || (cx == 79 && !cy[1])
              || placar(58, placar1, cx, cy)
              || placar(88, placar2, cx, cy);

   always @(posedge clk_pix) begin
      de <= visivel;
      hs <= !(hc >= 656 && hc < 752);    // sincronismo negativo
      vs <= !(vc >= 490 && vc < 492);
      {r, g, b} <= (visivel && acende) ? {cor[7:5], cor[7:5], cor[7:6],
                                          cor[4:2], cor[4:2], cor[4:3],
                                          {4{cor[1:0]}}} : 24'h0;
   end
endmodule

// Codifica 100 mil valores aleatórios com tmds_enc, decodifica de volta e confere,
// e verifica que o balanço DC (uns - zeros acumulados) fica limitado.
`timescale 1ns/100ps
module tb_tmds;
   reg clk = 0, de = 0;
   reg [7:0] d = 0;
   reg [1:0] c = 0;
   wire [9:0] q;
   tmds_enc dut(.clk(clk), .d(d), .c(c), .de(de), .q(q));
   always #1 clk = ~clk;

   function [9:0] decod(input [9:0] w);   // volta ao byte original
      reg [7:0] x, y;
      integer i;
      begin
         x = w[9] ? ~w[7:0] : w[7:0];
         y[0] = x[0];
         for (i = 1; i < 8; i = i + 1) y[i] = w[8] ? (x[i] ^ x[i-1]) : ~(x[i] ^ x[i-1]);
         decod = {2'b00, y};
      end
   endfunction

   function integer uns(input [9:0] w);
      integer i;
      begin uns = 0; for (i = 0; i < 10; i = i + 1) uns = uns + w[i]; end
   endfunction


   integer n, erros = 0, disp = 0, pior = 0;
   initial begin
      for (n = 0; n < 100000; n = n + 1) begin
         @(negedge clk);
         de = ($random % 8) != 0;          // de vez em quando um período de controle
         d = $random; c = $random;
         @(posedge clk); #0.1;
         begin
            if (de) begin
               if (decod(q) != {2'b00, d}) erros = erros + 1;
               disp = disp + 2 * uns(q) - 10;
               if (disp > pior) pior = disp;
               if (-disp > pior) pior = -disp;
            end else begin
               disp = 0;
               if (q != (c == 0 ? 10'b1101010100 : c == 1 ? 10'b0010101011 :
                         c == 2 ? 10'b0101010100 : 10'b1010101011)) erros = erros + 1;
            end
         end
      end
      if (erros == 0 && pior <= 20) $display("OK: TMDS ida e volta, balanço DC máximo %0d", pior);
      else $display("FALHA: %0d erros, balanço DC máximo %0d", erros, pior);
      $finish;
   end
endmodule

// Decodifica a saida WS2812 e conta quantas vezes acende em branco.
module tb;
   reg clk = 0; wire ws;
   led_branco #(.N(20), .MEIO(20000)) dut(clk, ws);
   always #1 clk = ~clk;
   integer alto = 0, bits = 0, acesas = 0, baixo = 0;
   reg [23:0] q = 0, ant = 0;
   always @(posedge clk) begin
      if (ws) begin alto = alto + 1; baixo = 0; end
      else begin
         if (alto) begin q = {q[22:0], alto > 15}; bits = bits + 1; alto = 0; end
         baixo = baixo + 1;
         if (baixo == 1000 && bits) begin
            if (bits != 24 || (q != 24'h7F7F7F && q != 0)) begin $display("FALHA quadro %0d bits %h", bits, q); $finish; end
            if (q == 24'h7F7F7F && ant == 0) acesas = acesas + 1;
            ant = q; bits = 0;
         end
      end
   end
   initial begin
      #(2*20000*45*2);
      if (acesas == 20 && ant == 0) $display("OK: acendeu %0d vezes e terminou apagado", acesas);
      else $display("FALHA: acendeu %0d vezes", acesas);
      $finish;
   end
endmodule

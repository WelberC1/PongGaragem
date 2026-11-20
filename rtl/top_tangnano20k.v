/**
 * Topo para a Tang Nano 20K. S1 = reset, S2 = botão lido na porta 00h.
 */
module top_tangnano20k
  (
   input        clk,      // 27 MHz
   input        s1,
   input        s2,
   input        uart_rx,
   output       uart_tx,
   output [5:0] led_n
   );

   // reset ao ligar (~2,4 ms) ou enquanto S1 estiver apertado (S1 = 1 apertado)
   reg [15:0] por = 0;
   always @(posedge clk) if (s1) por <= 0; else if (!por[15]) por <= por + 1;

   gar8_soc soc(.clk(clk), .rst(!por[15]), .btn(s2),
                .uart_rx(uart_rx), .uart_tx(uart_tx), .led_n(led_n));
endmodule

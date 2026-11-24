/**
 * Topo para a Tang Nano 20K. S1 = reset, S2 = botão 0 da porta 00h.
 * Botões de fliperama na protoboard: um lado no pino, o outro no GND (pull-up interno).
 */
module top_tangnano20k
  (
   input        clk,      // 27 MHz
   input        s1,
   input        s2,
   input        j1_sobe, j1_desce, j2_sobe, j2_desce,   // 0 = apertado
   input        uart_rx,
   output       uart_tx,
   output [5:0] led_n,
   output       tmds_clk_p, tmds_clk_n,
   output [2:0] tmds_d_p, tmds_d_n,
   output       hp_bck, hp_ws, hp_din,
   output       pa_en
   );

   // reset ao ligar (~2,4 ms) ou enquanto S1 estiver apertado (S1 = 1 apertado)
   reg [15:0] por = 0;
   always @(posedge clk) if (s1) por <= 0; else if (!por[15]) por <= por + 1;

   wire       clk_pix, pronto;
   wire [7:0] r, g, b;
   wire       hs, vs, de;

   gar8_soc soc(.clk(clk), .rst(!por[15]),
                .btn({!j2_desce, !j2_sobe, !j1_desce, !j1_sobe, s2}),
                .uart_rx(uart_rx), .uart_tx(uart_tx), .led_n(led_n),
                .clk_pix(clk_pix), .vid_r(r), .vid_g(g), .vid_b(b),
                .vid_hs(hs), .vid_vs(vs), .vid_de(de),
                .i2s_bck(hp_bck), .i2s_ws(hp_ws), .i2s_din(hp_din));

   hdmi_gowin hdmi(.clk27(clk), .clk_pix(clk_pix), .pronto(pronto),
                   .r(r), .g(g), .b(b), .hs(hs), .vs(vs), .de(de),
                   .tmds_clk_p(tmds_clk_p), .tmds_clk_n(tmds_clk_n),
                   .tmds_d_p(tmds_d_p), .tmds_d_n(tmds_d_n));

   assign pa_en = 1'b1;   // liga o amplificador
endmodule

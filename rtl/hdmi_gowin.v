/**
 * Saída HDMI (sinal DVI) 640x480 na Tang Nano 20K: PLL 126 MHz, pixel 25,2 MHz,
 * 3 codificadores TMDS, serializadores OSER10 e saídas diferenciais.
 * Usa primitivas da Gowin: só entra na síntese, não na simulação.
 */
module hdmi_gowin
  (
   input        clk27,
   output       clk_pix,
   output       pronto,     // PLL travado
   input [7:0]  r, g, b,
   input        hs, vs, de,
   output       tmds_clk_p, tmds_clk_n,
   output [2:0] tmds_d_p, tmds_d_n
   );

   wire clk_ser;   // 126 MHz = 5 x pixel; OSER10 usa as duas bordas: 10 bits por pixel

   // 27 x 14 / 3 = 126 MHz; VCO = 126 x 4 = 504 MHz
   rPLL #(.FCLKIN("27"), .IDIV_SEL(2), .FBDIV_SEL(13), .ODIV_SEL(4), .DEVICE("GW2AR-18C"))
   pll(.CLKIN(clk27), .CLKFB(1'b0), .RESET(1'b0), .RESET_P(1'b0),
       .FBDSEL(6'b0), .IDSEL(6'b0), .ODSEL(6'b0), .PSDA(4'b0), .DUTYDA(4'b0), .FDLY(4'b0),
       .CLKOUT(clk_ser), .CLKOUTP(), .CLKOUTD(), .CLKOUTD3(), .LOCK(pronto));

   CLKDIV #(.DIV_MODE("5")) div(.HCLKIN(clk_ser), .RESETN(pronto), .CALIB(1'b0), .CLKOUT(clk_pix));

   // canal 0 = azul (leva os sincronismos), 1 = verde, 2 = vermelho
   wire [9:0] q0, q1, q2;
   tmds_enc e0(.clk(clk_pix), .d(b), .c({vs, hs}), .de(de), .q(q0));
   tmds_enc e1(.clk(clk_pix), .d(g), .c(2'b00),    .de(de), .q(q1));
   tmds_enc e2(.clk(clk_pix), .d(r), .c(2'b00),    .de(de), .q(q2));

   wire [9:0] palavra [0:3];
   assign palavra[0] = q0;
   assign palavra[1] = q1;
   assign palavra[2] = q2;
   assign palavra[3] = 10'b0000011111;   // relógio TMDS

   wire [3:0] serial;
   genvar i;
   generate for (i = 0; i < 4; i = i + 1) begin : ser
      OSER10 s(.Q(serial[i]), .PCLK(clk_pix), .FCLK(clk_ser), .RESET(!pronto),
               .D0(palavra[i][0]), .D1(palavra[i][1]), .D2(palavra[i][2]), .D3(palavra[i][3]),
               .D4(palavra[i][4]), .D5(palavra[i][5]), .D6(palavra[i][6]), .D7(palavra[i][7]),
               .D8(palavra[i][8]), .D9(palavra[i][9]));
   end endgenerate

   TLVDS_OBUF buf_clk(.I(serial[3]), .O(tmds_clk_p), .OB(tmds_clk_n));
   TLVDS_OBUF buf_d0 (.I(serial[0]), .O(tmds_d_p[0]), .OB(tmds_d_n[0]));
   TLVDS_OBUF buf_d1 (.I(serial[1]), .O(tmds_d_p[1]), .OB(tmds_d_n[1]));
   TLVDS_OBUF buf_d2 (.I(serial[2]), .O(tmds_d_p[2]), .OB(tmds_d_n[2]));
endmodule

/**
 * Pisca o LED RGB WS2812 da Tang Nano 20K em branco, N vezes, e apaga.
 * clk = 27 MHz. Protocolo WS2812: 24 bits GRB, MSB primeiro,
 * bit = 34 ciclos (1,25 us); '1' fica alto 19 ciclos, '0' fica alto 10.
 */
module led_branco #(parameter N = 20, MEIO = 6_750_000) // MEIO = 0,25 s
  (input clk, output reg ws = 0);

   // fase: conta meio-periodos; aceso nos pares, ate 2*N
   reg [22:0] t = 0;
   reg [6:0]  fase = 0;
   always @(posedge clk)
     if (fase < 2*N) begin
        if (t == MEIO-1) begin t <= 0; fase <= fase + 1; end
        else t <= t + 1;
     end
   wire [23:0] cor = (fase < 2*N && !fase[0]) ? 24'h7F7F7F : 24'h000000;

   // envia a cor sem parar: 24 bits + 300 us de reset
   reg [4:0]  bitn = 23;
   reg [5:0]  cyc = 0;
   reg [13:0] rst = 8100;
   reg [23:0] grb = 0; // cor travada durante o quadro
   always @(posedge clk)
     if (rst != 0) begin
        rst <= rst - 1; ws <= 0; bitn <= 23; cyc <= 0; grb <= cor;
     end else begin
        ws <= cyc < (grb[bitn] ? 19 : 10);
        if (cyc == 33) begin
           cyc <= 0;
           if (bitn == 0) rst <= 8100; else bitn <= bitn - 1;
        end else cyc <= cyc + 1;
     end
endmodule

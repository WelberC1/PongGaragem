/**
 * Som: onda quadrada enviada por I2S ao amplificador MAX98357A da placa.
 * OUT 8Ah = n toca a nota (meio período = n amostras; n = 0 cala) por "duração" x 10 ms.
 * I2S: BCLK = clk / (2*BCK_DIV), 32 BCLK por amostra (16 bits por canal), mesmo som nos dois.
 * Com clk = 27 MHz: BCLK = 1,5 MHz, 46 875 amostras/s, frequência = 23 437 / n Hz.
 */
module gar8_som
  #(parameter BCK_DIV = 9,
    parameter [15:0] VOLUME = 16'h1000)
   (
    input       clk,
    input       rst,
    input       tick,       // pulso a cada 10 ms
    input       toca,       // pulso: escreveram na porta 8Ah
    input [7:0] nota,
    input [7:0] duracao,    // em unidades de 10 ms
    output reg  bck = 0,
    output      ws,
    output      din
    );

   // ---------- relógios do I2S ----------
   reg [7:0] div = 0;
   reg [4:0] bit_n = 0;                 // muda na descida do BCLK
   always @(posedge clk)
     if (div == BCK_DIV - 1) begin
        div <= 0;
        bck <= ~bck;
        if (bck) bit_n <= bit_n + 1;    // bck vai de 1 para 0
     end else div <= div + 1;
   wire amostra_nova = (div == BCK_DIV - 1) && bck && (bit_n == 31);

   // ---------- gerador de tom ----------
   reg [7:0]  n = 0, fase = 0, resta = 0;
   reg        nivel = 0;
   wire       tocando = (n != 0) && (resta != 0);
   wire [15:0] amostra = !tocando ? 16'h0000 : nivel ? VOLUME : -VOLUME;

   always @(posedge clk)
     if (rst) begin n <= 0; resta <= 0; end
     else if (toca) begin n <= nota; resta <= duracao; fase <= 0; nivel <= 1; end
     else begin
        if (tick && resta != 0) resta <= resta - 1;
        if (amostra_nova && tocando) begin
           if (fase >= n - 1) begin fase <= 0; nivel <= ~nivel; end
           else fase <= fase + 1;
        end
     end

   // I2S padrão Philips: o MSB sai 1 BCLK depois da troca de WS (bit_n 1 -> bit 15 ... bit_n 0 -> bit 0)
   wire [3:0] idx = 4'd0 - bit_n[3:0];
   assign ws  = bit_n[4];
   assign din = amostra[idx];
endmodule

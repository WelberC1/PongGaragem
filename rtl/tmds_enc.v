/**
 * Codificador TMDS (DVI 1.0, seção 3.3): 8 bits de cor -> 10 bits, com balanço DC.
 * Fora da área visível (de = 0) envia um dos 4 códigos de controle (c = {c1, c0}).
 * q[0] é o primeiro bit a sair no fio.
 */
module tmds_enc
  (
   input            clk,
   input [7:0]      d,
   input [1:0]      c,
   input            de,
   output reg [9:0] q = 0
   );

   wire [3:0] n1d = d[0] + d[1] + d[2] + d[3] + d[4] + d[5] + d[6] + d[7];
   wire       usa_xnor = (n1d > 4) || (n1d == 4 && !d[0]);

   wire [8:0] qm;
   assign qm[0] = d[0];
   genvar i;
   generate for (i = 1; i < 8; i = i + 1) begin : g
      assign qm[i] = usa_xnor ? ~(qm[i-1] ^ d[i]) : (qm[i-1] ^ d[i]);
   end endgenerate
   assign qm[8] = ~usa_xnor;

   wire signed [5:0] n1 = qm[0] + qm[1] + qm[2] + qm[3] + qm[4] + qm[5] + qm[6] + qm[7];
   wire signed [5:0] dif = n1 + n1 - 6'sd8;           // uns - zeros
   reg  signed [5:0] cnt = 0;                         // disparidade acumulada

   always @(posedge clk)
     if (!de) begin
        cnt <= 0;
        case (c)
          2'b00: q <= 10'b1101010100;
          2'b01: q <= 10'b0010101011;
          2'b10: q <= 10'b0101010100;
          2'b11: q <= 10'b1010101011;
        endcase
     end else if (cnt == 0 || dif == 0) begin
        q   <= {~qm[8], qm[8], qm[8] ? qm[7:0] : ~qm[7:0]};
        cnt <= qm[8] ? cnt + dif : cnt - dif;
     end else if ((cnt > 0 && dif > 0) || (cnt < 0 && dif < 0)) begin
        q   <= {1'b1, qm[8], ~qm[7:0]};
        cnt <= cnt + (qm[8] ? 6'sd2 : 6'sd0) - dif;
     end else begin
        q   <= {1'b0, qm[8], qm[7:0]};
        cnt <= cnt - (qm[8] ? 6'sd0 : 6'sd2) + dif;
     end
endmodule

/**
 * GAR-8: CPU de 8 bits, acumulador, endereços de 16 bits.
 * ISA em docs/isa.md.
 *
 * Um único clock (clk); a CPU só avança quando ce = 1.
 * A memória é síncrona (dado 1 clk depois do endereço), por isso o
 * ce precisa vir no máximo a cada 2 clks (CE_DIV >= 2 no SoC).
 */
module gar8_cpu
  (
   input             clk,
   input             rst,
   input             ce,
   // memória
   output reg [15:0] addr = 0,
   output reg [7:0]  wdata = 0,
   output reg        we = 0,        // pulso de 1 clk
   input [7:0]       rdata,
   // E/S
   output [7:0]      io_port,
   output [7:0]      io_wdata,
   output reg        io_rd = 0,     // pulso de 1 clk
   output reg        io_wr = 0,     // pulso de 1 clk
   input [7:0]       io_rdata,
   output            halted
   );

   localparam F0 = 0, F1 = 1, F2 = 2, F3 = 3, EX = 4, RD = 5,
              C2 = 6, R1 = 7, R2 = 8, HALT = 9;

   reg [3:0]  st = F0;
   reg [15:0] pc = 0, sp = 16'hC000, x = 0;
   reg [7:0]  a = 0, op = 0, lo = 0, hi = 0;
   reg        z = 0, c = 0;
   wire [15:0] imm16 = {hi, lo};

   assign io_port  = lo;
   assign io_wdata = a;
   assign halted   = (st == HALT);

   function [1:0] oplen(input [7:0] o);
      case (o)
        8'h10, 8'h20, 8'h22, 8'h24, 8'h26, 8'h28, 8'h2A, 8'h50, 8'h51:
          oplen = 2;
        8'h11, 8'h12, 8'h13, 8'h14, 8'h21, 8'h23, 8'h25, 8'h27, 8'h29, 8'h2B,
        8'h30, 8'h33, 8'h40, 8'h41, 8'h42, 8'h43, 8'h44, 8'h46, 8'h4C:
          oplen = 3;
        default:
          oplen = 1;
      endcase
   endfunction

   // ULA: operando é o imediato (EX) ou o dado lido da memória (RD)
   wire [7:0] m   = (st == RD) ? rdata : lo;
   wire [8:0] sum = {1'b0, a} + m;
   wire [8:0] dif = {1'b0, a} - m;  // dif[8] = empresta (A < m)
   reg [7:0]  na;
   reg        nz, nc;
   always @* begin
      na = a; nc = c;
      case (op)
        8'h10, 8'h11, 8'h12, 8'h49: na = m;
        8'h20, 8'h21: {nc, na} = sum;
        8'h22, 8'h23: {nc, na} = dif;
        8'h24, 8'h25: na = a & m;
        8'h26, 8'h27: na = a | m;
        8'h28, 8'h29: na = a ^ m;
        8'h2A, 8'h2B: nc = dif[8];
        default: ;
      endcase
      nz = (op == 8'h2A || op == 8'h2B) ? (dif[7:0] == 0) : (na == 0);
   end

   always @(posedge clk) begin
      we <= 0; io_rd <= 0; io_wr <= 0;
      if (rst) begin
         st <= F0; pc <= 0; sp <= 16'hC000; x <= 0;
         a <= 0; z <= 0; c <= 0; addr <= 0;
      end
      else if (ce) case (st)
        F0: begin addr <= pc; pc <= pc + 1; st <= F1; end
        F1: begin
           op <= rdata;
           if (oplen(rdata) != 1) begin addr <= pc; pc <= pc + 1; st <= F2; end
           else st <= EX;
        end
        F2: begin
           lo <= rdata;
           if (oplen(op) == 3) begin addr <= pc; pc <= pc + 1; st <= F3; end
           else st <= EX;
        end
        F3: begin hi <= rdata; st <= EX; end
        EX: begin
           st <= F0;
           case (op)
             8'h00: ;
             8'h10, 8'h20, 8'h22, 8'h24, 8'h26, 8'h28, 8'h2A:
               {a, z, c} <= {na, nz, nc};
             8'h11, 8'h21, 8'h23, 8'h25, 8'h27, 8'h29, 8'h2B:
               begin addr <= imm16; st <= RD; end
             8'h12: begin addr <= imm16 + x; st <= RD; end
             8'h13: begin addr <= imm16;     wdata <= a; we <= 1; end
             8'h14: begin addr <= imm16 + x; wdata <= a; we <= 1; end
             8'h2C: begin c <= a[7]; a <= {a[6:0], 1'b0}; z <= (a[6:0] == 0); end
             8'h2D: begin c <= a[0]; a <= {1'b0, a[7:1]}; z <= (a[7:1] == 0); end
             8'h30: x <= imm16;
             8'h31: begin x <= x + 1; z <= (x == 16'hFFFF); end
             8'h32: begin x <= x - 1; z <= (x == 16'h0001); end
             8'h33: begin z <= (x == imm16); c <= (x < imm16); end
             8'h34: x[7:0]  <= a;
             8'h35: x[15:8] <= a;
             8'h36: begin a <= x[7:0];  z <= (x[7:0] == 0);  end
             8'h37: begin a <= x[15:8]; z <= (x[15:8] == 0); end
             8'h40: pc <= imm16;
             8'h41: if (z)  pc <= imm16;
             8'h42: if (!z) pc <= imm16;
             8'h43: if (c)  pc <= imm16;
             8'h44: if (!c) pc <= imm16;
             8'h45: pc <= x;
             // CALL e PHX: byte alto agora, byte baixo em C2
             8'h46: begin sp <= sp - 1; addr <= sp - 1; wdata <= pc[15:8]; we <= 1; st <= C2; end
             8'h4A: begin sp <= sp - 1; addr <= sp - 1; wdata <= x[15:8];  we <= 1; st <= C2; end
             // RET e PLX: byte baixo em R1, alto em R2
             8'h47, 8'h4B: begin addr <= sp; sp <= sp + 1; st <= R1; end
             8'h48: begin sp <= sp - 1; addr <= sp - 1; wdata <= a; we <= 1; end
             8'h49: begin addr <= sp; sp <= sp + 1; st <= RD; end
             8'h4C: sp <= imm16;
             8'h50: begin a <= io_rdata; z <= (io_rdata == 0); io_rd <= 1; end
             8'h51: io_wr <= 1;
             default: st <= HALT; // inclui 01 (HLT) e opcodes inválidos
           endcase
        end
        RD: begin {a, z, c} <= {na, nz, nc}; st <= F0; end
        C2: begin
           sp <= sp - 1; addr <= sp - 1; we <= 1;
           wdata <= (op == 8'h46) ? pc[7:0] : x[7:0];
           if (op == 8'h46) pc <= imm16;
           st <= F0;
        end
        R1: begin lo <= rdata; addr <= sp; sp <= sp + 1; st <= R2; end
        R2: begin
           if (op == 8'h47) pc <= {rdata, lo}; else x <= {rdata, lo};
           st <= F0;
        end
        default: ; // HALT
      endcase
   end
endmodule

// Roda sw/teste_cpu.asm e espera 55h na porta F0h.
`timescale 1ns/1ns
module tb_cpu;
   reg clk = 0, rst = 1;
   wire tx; wire [5:0] led_n;
   gar8_soc #(.ROM_FILE("teste_cpu.hex"), .CE_DIV(2)) dut
     (.clk(clk), .rst(rst), .btn(1'b0), .uart_rx(1'b1), .uart_tx(tx), .led_n(led_n));
   always #1 clk = ~clk;

   initial begin
      #10 rst = 0;
      #200000 $display("FALHA: tempo esgotado, pc=%h", dut.cpu.pc); $finish;
   end
   always @(posedge clk)
     if (dut.cpu.io_wr && dut.cpu.io_port == 8'hF0) begin
        if (dut.cpu.io_wdata == 8'h55) $display("OK: teste da CPU passou");
        else $display("FALHA: teste da CPU parou em pc=%h", dut.cpu.pc);
        $finish;
     end
   always @(posedge clk)
     if (dut.cpu.halted) begin $display("FALHA: HLT inesperado, pc=%h op=%h", dut.cpu.pc, dut.cpu.op); $finish; end
endmodule

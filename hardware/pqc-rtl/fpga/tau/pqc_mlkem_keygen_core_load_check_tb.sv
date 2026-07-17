`timescale 1ns/1ps
module check_load_tb;
  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;
  localparam int K = 2;
  logic clk, reset, start, done;
  logic [255:0] d_seed, z_seed;
  logic [8*800-1:0] ek_out;
  logic [8*1632-1:0] dk_out;
  logic [255:0] debug_rho, debug_sigma;
  logic [256*COEFF_W-1:0] debug_A00;
  logic [4:0] debug_state;
  always #5 clk = ~clk;
  pqc_mlkem_keygen_core #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW), .K(K)) dut (
    .clk(clk), .reset(reset), .start(start), .d_seed(d_seed), .z_seed(z_seed),
    .done(done), .ek_out(ek_out), .dk_out(dk_out),
    .debug_rho(debug_rho), .debug_sigma(debug_sigma), .debug_A00(debug_A00), .debug_state(debug_state)
  );
  int fh, scan_ok;
  logic [8*800-1:0] ek_expect;
  logic [8*1632-1:0] dk_expect;
  logic [COEFF_W-1:0] init_mem [0:255];
  logic [1:0] bank_rom_tb  [0:255];
  logic [5:0] local_rom_tb [0:255];
  function automatic [COEFF_W-1:0] read_bank(input int addr);
    case (bank_rom_tb[addr])
      2'd0: read_bank = dut.ntt_dut.bank0[local_rom_tb[addr]];
      2'd1: read_bank = dut.ntt_dut.bank1[local_rom_tb[addr]];
      2'd2: read_bank = dut.ntt_dut.bank2[local_rom_tb[addr]];
      default: read_bank = dut.ntt_dut.bank3[local_rom_tb[addr]];
    endcase
  endfunction
  initial begin
    clk = 0; reset = 1; start = 0;
    fh = $fopen("vectors/mlkem_keygen_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", d_seed);
    scan_ok = $fscanf(fh, "%h\n", z_seed);
    scan_ok = $fscanf(fh, "%h\n", ek_expect);
    scan_ok = $fscanf(fh, "%h\n", dk_expect);
    $fclose(fh);
    $readmemh("fpga/tau/s_vec0_direct_input.memh", init_mem);
    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    repeat(3) @(posedge clk);
    reset = 0;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    // Odota etta S_NTT_FWD_SCHED_START (tila 13) alkaa - lataus valmis
    begin
      int wait_cycles;
      wait_cycles = 0;
      while (debug_state !== 5'd13 && wait_cycles < 5000) begin
        @(posedge clk);
        wait_cycles++;
      end
      $display("Saavutti S_NTT_FWD_SCHED_START (13) %0d syklin jalkeen", wait_cycles);
    end
    // Odota pari sykliä lisaa varmistaaksemme etta viimeinenkin kirjoitus ehti
    repeat(3) @(posedge clk);

    begin
      int diffs;
      diffs = 0;
      for (int i = 0; i < 256; i++) begin
        if (read_bank(i) !== init_mem[i]) begin
          if (diffs < 10) $display("  [%0d] pankki=%0d, odotettu=%0d", i, read_bank(i), init_mem[i]);
          diffs++;
        end
      end
      if (diffs == 0) $display("PASS: kaikki 256 arvoa kirjoitettu oikein bring-up-latauksen kautta");
      else $display("FAIL: %0d/256 arvoa vaarin ladattu", diffs);
    end
    $finish;
  end
endmodule

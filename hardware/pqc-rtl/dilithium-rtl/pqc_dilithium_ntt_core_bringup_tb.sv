// M5-DILITHIUM-001 DK1-testi: bring-up-rajapintaisen NTT-ytimen
// todennus - sama golden-vertailu, mutta sana-kerrallaan-lataus/luku.

`timescale 1ns/1ps

module pqc_dilithium_ntt_core_bringup_tb;

  localparam int CW = 23;

  logic clk, reset, start, done;
  logic load_valid, read_en, read_valid;
  logic [7:0] load_addr, read_addr;
  logic [CW-1:0] load_data, read_data;

  always #5 clk = ~clk;

  pqc_dilithium_ntt_core_bringup dut (
    .clk(clk), .reset(reset), .start(start),
    .load_valid(load_valid), .load_addr(load_addr), .load_data(load_data),
    .read_en(read_en), .read_addr(read_addr), .read_valid(read_valid), .read_data(read_data),
    .done(done)
  );

  int fh, scan_ok, error_count;
  logic [256*CW-1:0] coeffs_in, expect_out;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0; load_valid = 0; read_en = 0;

    fh = $fopen("dilithium-rtl/ntt_full_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", coeffs_in);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    // Lataa 256 sanaa
    for (int i = 0; i < 256; i++) begin
      load_valid <= 1'b1;
      load_addr <= i[7:0];
      load_data <= coeffs_in[i*CW +: CW];
      @(posedge clk);
    end
    load_valid <= 1'b0;
    @(posedge clk);

    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    begin
      int wait_cycles;
      wait_cycles = 0;
      while (!done && wait_cycles < 20000) begin @(posedge clk); wait_cycles++; end
      if (!done) $display("FAIL: aikakatkaisu");
      else $display("Valmis %0d syklin jalkeen", wait_cycles);
    end

    // Lue 256 sanaa takaisin ja vertaa
    for (int i = 0; i < 256; i++) begin
      logic [CW-1:0] word;
      read_en <= 1'b1;
      read_addr <= i[7:0];
      @(posedge clk);
      word = read_data;
      if (word !== expect_out[i*CW +: CW]) begin
        $display("FAIL kerroin %0d: RTL=%0d golden=%0d", i, word, expect_out[i*CW +: CW]);
        error_count++;
      end
    end
    read_en <= 1'b0;

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: bring-up-NTT tasmaa taydellisesti kaikille 256 kertoimelle");
    else begin $display("FAIL: %0d/256 virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule

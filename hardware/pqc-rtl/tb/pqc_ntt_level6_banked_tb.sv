// pqc_ntt_level6_banked_tb.sv
//
// M2 Vaihe 3b -testipenkki. Kayttaa SAMOJA golden-vektoreita kuin 2b
// (vectors/level6_init.memh, level6_expect.memh, level6_twiddles.memh)
// - laskenta on jo todistettu tason 6 osalta 2b:ssa, tama testaa VAIN
// etta oikea 4-pankkinen muistireititys ei riko sita.
//
// Alustus ja lopputuloksen luku tehdaan ROM:in (bank_rom/local_rom)
// kautta koska data on nyt oikeasti neljassa erillisessa pankissa,
// ei yhdessa isossa taulukossa.

`timescale 1ns/1ps

module pqc_ntt_level6_banked_tb;

  localparam int COEFF_W = 16;

  logic clk, reset, start, cluster_done, bank_conflict_detected;
  logic [7:0] count;
  logic tw_in_valid;
  logic [5:0] tw_in_idx;
  logic [COEFF_W-1:0] tw_in_data;

  int error_count;
  int conflict_cycles;

  always #5 clk = ~clk;

  pqc_ntt_level6_banked #(.COEFF_W(COEFF_W)) dut (
    .clk(clk), .reset(reset), .start(start), .count(count),
    .tw_in_valid(tw_in_valid), .tw_in_idx(tw_in_idx), .tw_in_data(tw_in_data),
    .cluster_done(cluster_done), .bank_conflict_detected(bank_conflict_detected)
  );

  logic [COEFF_W-1:0] init_mem   [0:255];
  logic [COEFF_W-1:0] expect_mem [0:255];
  logic [COEFF_W-1:0] tw_vec     [0:63];
  logic [1:0] bank_rom_tb  [0:255];
  logic [5:0] local_rom_tb [0:255];

  task automatic run_wait(int max_cycles);
    int c;
    begin
      c = 0;
      while (!cluster_done && c < max_cycles) begin
        if (bank_conflict_detected) begin
          $display("HAVAITTU PANKKIKONFLIKTI syklilla %0d!", c);
          conflict_cycles++;
        end
        @(posedge clk);
        c++;
      end
    end
  endtask

  function automatic void write_bank(input [1:0] b, input [5:0] l, input [COEFF_W-1:0] val);
    case (b)
      2'd0: dut.bank0[l] = val;
      2'd1: dut.bank1[l] = val;
      2'd2: dut.bank2[l] = val;
      default: dut.bank3[l] = val;
    endcase
  endfunction

  function automatic [COEFF_W-1:0] read_bank_tb(input [1:0] b, input [5:0] l);
    case (b)
      2'd0: read_bank_tb = dut.bank0[l];
      2'd1: read_bank_tb = dut.bank1[l];
      2'd2: read_bank_tb = dut.bank2[l];
      default: read_bank_tb = dut.bank3[l];
    endcase
  endfunction

  initial begin
    error_count = 0;
    conflict_cycles = 0;
    clk = 0; reset = 1; start = 0; count = 0;
    tw_in_valid = 0; tw_in_idx = 0; tw_in_data = 0;

    $readmemh("vectors/level6_init.memh", init_mem);
    $readmemh("vectors/level6_expect.memh", expect_mem);
    $readmemh("vectors/level6_twiddles.memh", tw_vec);
    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    repeat (3) @(posedge clk);
    reset = 0;
    repeat (2) @(posedge clk);

    // Alustus ROM:in kautta oikeisiin pankkeihin
    for (int i = 0; i < 256; i++) begin
      write_bank(bank_rom_tb[i], local_rom_tb[i], init_mem[i]);
    end

    for (int t = 0; t < 64; t++) begin
      @(posedge clk);
      tw_in_valid <= 1'b1;
      tw_in_idx   <= 6'(t);
      tw_in_data  <= tw_vec[t];
    end
    @(posedge clk);
    tw_in_valid <= 1'b0;

    count <= 8'd64;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    run_wait(3000);

    if (!cluster_done) begin
      $display("FAIL: cluster_done ei noussut aikarajassa");
      error_count++;
    end

    if (conflict_cycles > 0) begin
      $display("FAIL: %0d pankkikonfliktia havaittu ajon aikana - 3a:n todistus ei pidakaan paikkaansa taalla!", conflict_cycles);
      error_count++;
    end else begin
      $display("OK: EI pankkikonflikteja koko ajon aikana - 3a:n muodollinen todistus vahvistuu ajossa");
    end

    // Lue lopputulos ROM:in kautta ja vertaa golden-malliin
    for (int i = 0; i < 256; i++) begin
      logic [COEFF_W-1:0] actual;
      actual = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);
      if (actual !== expect_mem[i]) begin
        $display("FAIL: osoite %0d (pankki %0d, local %0d) = %0d, odotettu %0d",
                  i, bank_rom_tb[i], local_rom_tb[i], actual, expect_mem[i]);
        error_count++;
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) begin
      $display("PASS: 4-pankkinen muistireititys ei riko laskentaa, ei konflikteja, kaikki 256 sanaa tasmaavat");
    end else begin
      $display("FAIL: %0d virhetta", error_count);
      $fatal(1);
    end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule

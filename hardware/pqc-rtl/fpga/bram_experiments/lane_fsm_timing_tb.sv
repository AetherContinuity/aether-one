// pqc_lane_fsm_registered_mem_timing_tb.sv
//
// M4-FPGA-002A, kayttajan oma ehdotus: minimaalinen koe joka
// vastaa TASMALLEEN yhteen kysymykseen - voiko NYKYINEN,
// MUUTTUMATON lane_fsm toimia yhden syklin rekisteroidylla
// lukuviiveella ilman algoritmimuutoksia?
//
// EI NTT-laskentaa tarkastella tassa - vain osoitteiden, grant/
// read-signaalien ja FSM-tilojen ajoitus. Rekisteroity testimuisti
// (EI kombinatorinen) kytketty suoraan lane_fsm:n omiin portteihin,
// MUUTTUMATTOMANA (rtl/pqc_rvv_cluster_2lane.sv:sta, ei kopiota).

`timescale 1ns/1ps

module pqc_lane_fsm_registered_mem_timing_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;

  logic clk, reset, start;
  logic [SPAD_AW-1:0] base_addr;
  logic [7:0] stride, count, pair_dist;
  logic mode;
  logic [SPAD_AW-1:0] mem_addr_a, mem_addr_b;
  logic [COEFF_W-1:0] mem_rdata_a, mem_rdata_b;
  logic [COEFF_W-1:0] mem_wdata_a, mem_wdata_b;
  logic [COEFF_W-1:0] zeta_in;
  logic req, is_write, grant;
  logic [2:0] state;
  logic done;
  logic [7:0] idx_out;

  always #5 clk = ~clk;

  // --- MUUTTUMATON lane_fsm, ei kopiota ---
  lane_fsm #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) dut (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr), .stride(stride), .count(count),
    .pair_dist(pair_dist), .mode(mode),
    .mem_addr_a(mem_addr_a), .mem_addr_b(mem_addr_b),
    .mem_rdata_a(mem_rdata_a), .mem_rdata_b(mem_rdata_b),
    .mem_wdata_a(mem_wdata_a), .mem_wdata_b(mem_wdata_b),
    .zeta_in(zeta_in),
    .req(req), .is_write(is_write), .grant(grant),
    .state(state), .done(done), .idx_out(idx_out)
  );

  // --- REKISTEROITY testimuisti (EI kombinatorinen) - tarkoituksella
  // yksinkertaisin mahdollinen 1-syklin-viive-muisti, jotta nahdaan
  // TASMALLEEN taman ajoituksen vaikutus lane_fsm:n omaan
  // kayttaytymiseen. ---
  logic [COEFF_W-1:0] test_mem [0:511];
  logic [COEFF_W-1:0] rdata_a_reg, rdata_b_reg;

  always_ff @(posedge clk) begin
    rdata_a_reg <= test_mem[mem_addr_a];
    rdata_b_reg <= test_mem[mem_addr_b];
    if (grant && is_write) begin
      test_mem[mem_addr_a] <= mem_wdata_a;
      test_mem[mem_addr_b] <= mem_wdata_b;
    end
  end

  assign mem_rdata_a = rdata_a_reg;
  assign mem_rdata_b = rdata_b_reg;

  // --- Yksinkertainen grant: myonnetaan aina heti (ei
  // pankkikonfliktia tassa yhden-lanen kokeessa) ---
  assign grant = req;

  int cycle_count;
  logic [COEFF_W-1:0] expected_a, expected_b;

  initial begin
    clk = 0; reset = 1; start = 0;
    base_addr = 9'd0; stride = 8'd1; count = 8'd4; pair_dist = 8'd4; mode = 1'b0;
    zeta_in = 16'd1;
    cycle_count = 0;

    // Alusta testimuisti tunnetuilla arvoilla: test_mem[i] = i*10
    for (int i = 0; i < 512; i++) test_mem[i] = i * 10;

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    // Odota etta FSM saavuttaa S_DONE:n, tarkkaillen jokaisen syklin
    // tilaa ja verraten a_reg/b_reg:n (dut:n sisainen, hierarkkinen
    // luku VAIN tahan simulaatioon - ei synteesikohde) arvoja
    // odotettuihin.
    cycle_count = 0;
    while (state != 3'd4 && cycle_count < 100) begin
      @(posedge clk);
      cycle_count++;
      $display("sykli %0d: state=%0d idx=%0d addr_a=%0d addr_b=%0d req=%0b grant=%0b rdata_a=%0d rdata_b=%0d",
                cycle_count, state, idx_out, mem_addr_a, mem_addr_b, req, grant, mem_rdata_a, mem_rdata_b);
    end

    $display("--------------------------------------------------");
    if (state == 3'd4) $display("FSM saavutti S_DONE:n %0d syklissa", cycle_count);
    else $display("FSM EI saavuttanut S_DONE:a 100 syklissa - jumissa");

    // --- Tarkistus: onko a_reg/b_reg jarkevia (dut:n sisainen tila,
    // hierarkkinen luku vain diagnostiikkaan) ---
    $display("Viimeisen laskennan a_reg=%0d (dut:n sisainen tila)", dut.a_reg);
    $display("Viimeisen laskennan b_reg=%0d (dut:n sisainen tila)", dut.b_reg);

    $finish;
  end

endmodule
// TULOS (2026-07-17): count=4 (idx=0..3), mutta viimeinen a_reg=20,
// b_reg=60 vastaa idx=2:n arvoja (test_mem[2]=20, test_mem[6]=60),
// EI odotettuja idx=3:n arvoja (test_mem[3]=30, test_mem[7]=70).
// lane_fsm nayttestaa YHDEN ITERAATION MYOHASSA olevaa dataa
// rekisteroidyn muistin kanssa - vahvistaa etta S_REQ_READ-tilan
// nykyinen "grant -> nayttestys samalla reunalla" -logiikka olettaa
// NOLLAVIIVEISEN (kombinatorisen) muistin, ei toimi sellaisenaan
// rekisteroidyn muistin kanssa. VASTAUS kayttajan kysymykseen: EI,
// lane_fsm EI voi toimia rekisteroidylla muistilla ilman FSM:n
// omaa ajoitusmuutosta (esim. yhden ylimaaraisen odotustilan
// lisaamista S_REQ_READ:n ja nayttestyksen valiin).

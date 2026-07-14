// Kokeilu 4: 2 kirjoitus- + 2 lukuporttia YHDELLA yhtenaisella
// muistilla - vastaa TASMALLEEN pqc_ntt_stage_bankedin oikeaa
// kayttotarvetta (lane0 ja lane1 lukevat JA kirjoittavat joka sykli).
module test4_2w2r (
    input  logic clk,
    input  logic we0, input logic [7:0] waddr0, input logic [15:0] wdata0,
    input  logic we1, input logic [7:0] waddr1, input logic [15:0] wdata1,
    input  logic re0, input logic [7:0] raddr0, output logic [15:0] rdata0,
    input  logic re1, input logic [7:0] raddr1, output logic [15:0] rdata1
);
  logic [15:0] mem [0:255];

  always_ff @(posedge clk) begin
    if (we0) mem[waddr0] <= wdata0;
    if (we1) mem[waddr1] <= wdata1;
  end

  always_ff @(posedge clk) begin
    if (re0) rdata0 <= mem[raddr0];
    if (re1) rdata1 <= mem[raddr1];
  end
endmodule

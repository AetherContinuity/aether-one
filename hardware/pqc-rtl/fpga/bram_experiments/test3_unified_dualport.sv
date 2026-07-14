// Kokeilu 3: YKSI yhtenainen 256-alkion muisti, MUTTA kaksi
// lukuporttia (vastaa oikean NTT-ytimen 2-kaistaista rinnakkais-
// lukua per sykli) - ECP5:n DP16KD tukee aitoa kaksiporttista kayttoa.
module test3_unified_dualport (
    input  logic clk,
    input  logic we,
    input  logic [7:0] waddr,
    input  logic [15:0] wdata,
    input  logic re0,
    input  logic [7:0] raddr0,
    output logic [15:0] rdata0,
    input  logic re1,
    input  logic [7:0] raddr1,
    output logic [15:0] rdata1
);
  logic [15:0] mem [0:255];

  always_ff @(posedge clk) begin
    if (we) mem[waddr] <= wdata;
  end

  always_ff @(posedge clk) begin
    if (re0) rdata0 <= mem[raddr0];
  end

  always_ff @(posedge clk) begin
    if (re1) rdata1 <= mem[raddr1];
  end
endmodule

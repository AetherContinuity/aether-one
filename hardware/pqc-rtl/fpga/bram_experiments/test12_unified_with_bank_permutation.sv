// Kokeilu 12 (kayttajan oma ehdotus): YKSI yhtenainen 256-alkion
// muisti, jossa pankitus lasketaan XOR-kaavalla MUTTA kaytetaan
// VAIN osoitteen sisaisena permutaationa - EI fyysista jakoa
// neljaan erilliseen taulukkoon.
//
// physical_addr = {bank(addr), index(addr)}
//   bank(addr)  = addr[1:0] ^ addr[3:2] ^ addr[5:4] ^ addr[7:6] (2 bittia)
//   index(addr) = addr[7:2] (6 bittia)
//
// Jos tama inferoituu DP16KD:ksi, todiste on: ongelma EI ole
// pankitusalgoritmi (XOR-kaava), vaan FYYSINEN jako neljaan
// pieneen taulukkoon.
module test12_unified_with_bank_permutation (
    input  logic clk,
    input  logic we,
    input  logic [7:0] waddr,   // looginen osoite 0..255
    input  logic [15:0] wdata,
    input  logic re,
    input  logic [7:0] raddr,   // looginen osoite 0..255
    output logic [15:0] rdata
);
  logic [15:0] mem [0:255];

  function automatic logic [7:0] physical_addr(input logic [7:0] a);
    logic [1:0] bank;
    logic [5:0] idx;
    bank = a[1:0] ^ a[3:2] ^ a[5:4] ^ a[7:6];
    idx  = a[7:2];
    physical_addr = {bank, idx};
  endfunction

  always_ff @(posedge clk) begin
    if (we) mem[physical_addr(waddr)] <= wdata;
  end

  always_ff @(posedge clk) begin
    if (re) rdata <= mem[physical_addr(raddr)];
  end
endmodule

// Kokeilu 1: yksinkertaisin mahdollinen synkroninen 1R1W-muisti,
// yksi yhtenainen taulukko, suora osoitedekoodaus - "oppikirjan"
// BRAM-kuvio jota Yosysin memory_bram pitaisi tunnistaa.
module test1_simple_ram (
    input  logic clk,
    input  logic we,
    input  logic [7:0] waddr,
    input  logic [15:0] wdata,
    input  logic re,
    input  logic [7:0] raddr,
    output logic [15:0] rdata
);
  logic [15:0] mem [0:255];

  always_ff @(posedge clk) begin
    if (we) mem[waddr] <= wdata;
  end

  always_ff @(posedge clk) begin
    if (re) rdata <= mem[raddr];
  end
endmodule

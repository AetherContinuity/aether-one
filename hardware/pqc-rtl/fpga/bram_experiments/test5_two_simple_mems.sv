// Kokeilu 5: KAKSI ERILLISTA yksinkertaista 1w1r-muistia (ei case-
// pohjaista pankinvalintaa, suora osoitteistus per muisti) - vastaisi
// lane0/lane1-jakoa jos datat jaettaisiin suoralla paikallisella
// osoitteella ilman ulkoista ROM-valintaa.
module test5_two_simple_mems (
    input  logic clk,
    input  logic we0, input logic [6:0] waddr0, input logic [15:0] wdata0,
    input  logic re0, input logic [6:0] raddr0, output logic [15:0] rdata0,
    input  logic we1, input logic [6:0] waddr1, input logic [15:0] wdata1,
    input  logic re1, input logic [6:0] raddr1, output logic [15:0] rdata1
);
  logic [15:0] mem_a [0:127];
  logic [15:0] mem_b [0:127];

  always_ff @(posedge clk) begin
    if (we0) mem_a[waddr0] <= wdata0;
    if (re0) rdata0 <= mem_a[raddr0];
  end

  always_ff @(posedge clk) begin
    if (we1) mem_b[waddr1] <= wdata1;
    if (re1) rdata1 <= mem_b[raddr1];
  end
endmodule

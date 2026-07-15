module test_two_64 (
    input  logic clk,
    input  logic we0, input logic [7:0] waddr0, input logic [15:0] wdata0,
    input  logic re0, input logic [7:0] raddr0, output logic [15:0] rdata0,
    input  logic we1, input logic [7:0] waddr1, input logic [15:0] wdata1,
    input  logic re1, input logic [7:0] raddr1, output logic [15:0] rdata1
);
  logic [15:0] bank0 [0:63];
  logic [15:0] bank1 [0:63];

  always_ff @(posedge clk) begin
    if (we0) bank0[waddr0] <= wdata0;
    if (re0) rdata0 <= bank0[raddr0];
  end
  always_ff @(posedge clk) begin
    if (we1) bank1[waddr1] <= wdata1;
    if (re1) rdata1 <= bank1[raddr1];
  end
endmodule

module test_four_128 (
    input  logic clk,
    input  logic we0, input logic [6:0] waddr0, input logic [15:0] wdata0,
    input  logic re0, input logic [6:0] raddr0, output logic [15:0] rdata0,
    input  logic we1, input logic [6:0] waddr1, input logic [15:0] wdata1,
    input  logic re1, input logic [6:0] raddr1, output logic [15:0] rdata1,
    input  logic we2, input logic [6:0] waddr2, input logic [15:0] wdata2,
    input  logic re2, input logic [6:0] raddr2, output logic [15:0] rdata2,
    input  logic we3, input logic [6:0] waddr3, input logic [15:0] wdata3,
    input  logic re3, input logic [6:0] raddr3, output logic [15:0] rdata3
);
  logic [15:0] bank0 [0:127];
  logic [15:0] bank1 [0:127];
  logic [15:0] bank2 [0:127];
  logic [15:0] bank3 [0:127];

  always_ff @(posedge clk) begin
    if (we0) bank0[waddr0] <= wdata0;
    if (re0) rdata0 <= bank0[raddr0];
  end
  always_ff @(posedge clk) begin
    if (we1) bank1[waddr1] <= wdata1;
    if (re1) rdata1 <= bank1[raddr1];
  end
  always_ff @(posedge clk) begin
    if (we2) bank2[waddr2] <= wdata2;
    if (re2) rdata2 <= bank2[raddr2];
  end
  always_ff @(posedge clk) begin
    if (we3) bank3[waddr3] <= wdata3;
    if (re3) rdata3 <= bank3[raddr3];
  end
endmodule

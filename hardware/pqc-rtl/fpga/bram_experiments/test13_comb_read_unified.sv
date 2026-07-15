module test_comb_read (
    input  logic clk,
    input  logic we,
    input  logic [7:0] waddr,
    input  logic [15:0] wdata,
    input  logic [7:0] raddr,
    output logic [15:0] rdata
);
  logic [15:0] mem [0:255];
  always_ff @(posedge clk) begin
    if (we) mem[waddr] <= wdata;
  end
  always_comb begin
    rdata = mem[raddr];
  end
endmodule

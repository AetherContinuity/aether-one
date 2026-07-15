// Kokeilu 6: SAMA nelja-pankkinen konfliktiton kuvaus kuin
// pqc_ntt_stage_bankedissa, MUTTA suljetulla XOR-kaavalla ROM-haun
// sijaan: bank = addr[1:0]^addr[3:2]^addr[5:4]^addr[7:6],
// local = addr[7:2]. Bijektiivisyys ja 64/64/64/64-jakauma
// vahvistettu Pythonissa ennen tata koetta.
module test6_xor_banks (
    input  logic clk,
    input  logic we,
    input  logic [7:0] waddr,
    input  logic [15:0] wdata,
    input  logic re,
    input  logic [7:0] raddr,
    output logic [15:0] rdata
);
  logic [15:0] bank0 [0:63];
  logic [15:0] bank1 [0:63];
  logic [15:0] bank2 [0:63];
  logic [15:0] bank3 [0:63];

  function automatic logic [1:0] bank_of(input logic [7:0] a);
    bank_of = a[1:0] ^ a[3:2] ^ a[5:4] ^ a[7:6];
  endfunction

  function automatic logic [5:0] local_of(input logic [7:0] a);
    local_of = a[7:2];
  endfunction

  always_ff @(posedge clk) begin
    if (we) begin
      case (bank_of(waddr))
        2'd0: bank0[local_of(waddr)] <= wdata;
        2'd1: bank1[local_of(waddr)] <= wdata;
        2'd2: bank2[local_of(waddr)] <= wdata;
        default: bank3[local_of(waddr)] <= wdata;
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (re) begin
      case (bank_of(raddr))
        2'd0: rdata <= bank0[local_of(raddr)];
        2'd1: rdata <= bank1[local_of(raddr)];
        2'd2: rdata <= bank2[local_of(raddr)];
        default: rdata <= bank3[local_of(raddr)];
      endcase
    end
  end
endmodule

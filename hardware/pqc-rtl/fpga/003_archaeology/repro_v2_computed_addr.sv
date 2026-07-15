// v2: wsel/rsel korvattu LASKETULLA osoitteen XOR-kaavalla (ei
// vapaita valintasignaaleja) - jokainen kirjoitus-/lukulahde saa
// oman 8-bittisen loogisen osoitteensa, josta pankki+paikallinen
// johdetaan.
module repro (
    input  logic clk,
    input  logic we0, we1, we2, we3,
    input  logic [7:0] waddr0, waddr1, waddr2, waddr3,
    input  logic [15:0] wdata0, wdata1, wdata2, wdata3,
    input  logic [7:0] raddr0, raddr1, raddr2, raddr3,
    input  logic [1:0] rsel,
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
    if (we0) case (bank_of(waddr0))
      2'd0: bank0[local_of(waddr0)] <= wdata0; 2'd1: bank1[local_of(waddr0)] <= wdata0;
      2'd2: bank2[local_of(waddr0)] <= wdata0; default: bank3[local_of(waddr0)] <= wdata0;
    endcase
    if (we1) case (bank_of(waddr1))
      2'd0: bank0[local_of(waddr1)] <= wdata1; 2'd1: bank1[local_of(waddr1)] <= wdata1;
      2'd2: bank2[local_of(waddr1)] <= wdata1; default: bank3[local_of(waddr1)] <= wdata1;
    endcase
    if (we2) case (bank_of(waddr2))
      2'd0: bank0[local_of(waddr2)] <= wdata2; 2'd1: bank1[local_of(waddr2)] <= wdata2;
      2'd2: bank2[local_of(waddr2)] <= wdata2; default: bank3[local_of(waddr2)] <= wdata2;
    endcase
    if (we3) case (bank_of(waddr3))
      2'd0: bank0[local_of(waddr3)] <= wdata3; 2'd1: bank1[local_of(waddr3)] <= wdata3;
      2'd2: bank2[local_of(waddr3)] <= wdata3; default: bank3[local_of(waddr3)] <= wdata3;
    endcase
  end

  logic [15:0] b0_r0, b0_r1, b0_r2, b0_r3;
  logic [15:0] b1_r0, b1_r1, b1_r2, b1_r3;
  logic [15:0] b2_r0, b2_r1, b2_r2, b2_r3;
  logic [15:0] b3_r0, b3_r1, b3_r2, b3_r3;
  always_ff @(posedge clk) begin
    b0_r0 <= bank0[local_of(raddr0)]; b0_r1 <= bank0[local_of(raddr1)];
    b0_r2 <= bank0[local_of(raddr2)]; b0_r3 <= bank0[local_of(raddr3)];
    b1_r0 <= bank1[local_of(raddr0)]; b1_r1 <= bank1[local_of(raddr1)];
    b1_r2 <= bank1[local_of(raddr2)]; b1_r3 <= bank1[local_of(raddr3)];
    b2_r0 <= bank2[local_of(raddr0)]; b2_r1 <= bank2[local_of(raddr1)];
    b2_r2 <= bank2[local_of(raddr2)]; b2_r3 <= bank2[local_of(raddr3)];
    b3_r0 <= bank3[local_of(raddr0)]; b3_r1 <= bank3[local_of(raddr1)];
    b3_r2 <= bank3[local_of(raddr2)]; b3_r3 <= bank3[local_of(raddr3)];
  end
  logic [15:0] b0_out, b1_out, b2_out, b3_out;
  always_comb begin
    case (rsel)
      2'd0: b0_out = b0_r0; 2'd1: b0_out = b0_r1; 2'd2: b0_out = b0_r2; default: b0_out = b0_r3;
    endcase
    case (rsel)
      2'd0: b1_out = b1_r0; 2'd1: b1_out = b1_r1; 2'd2: b1_out = b1_r2; default: b1_out = b1_r3;
    endcase
    case (rsel)
      2'd0: b2_out = b2_r0; 2'd1: b2_out = b2_r1; 2'd2: b2_out = b2_r2; default: b2_out = b2_r3;
    endcase
    case (rsel)
      2'd0: b3_out = b3_r0; 2'd1: b3_out = b3_r1; 2'd2: b3_out = b3_r2; default: b3_out = b3_r3;
    endcase
  end
  always_comb begin
    case (rsel)
      2'd0: rdata = b0_out; 2'd1: rdata = b1_out; 2'd2: rdata = b2_out; default: rdata = b3_out;
    endcase
  end
endmodule

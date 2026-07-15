// M4-FPGA-003A: minimaalinen transparenssitoistin. Neljä pankkia,
// kirjoitus JOKAISEEN neljasta eri lähteestä (case-valinnalla, kolme
// eksplisiittistä + yksi default), luku vastaavasti neljästä
// dedikoidusta rekisteristä mux'attuna. Tavoite: toistaa TÄSMÄLLEEN
// "no output FF found" (bank0-2) vs "merging output FF" (bank3)
// -diagnostiikka mahdollisimman pienessä esimerkissä.
module repro (
    input  logic clk,
    input  logic [1:0] wsel0, wsel1, wsel2, wsel3,  // mihin pankkiin kukin lähde kirjoittaa
    input  logic we0, we1, we2, we3,
    input  logic [5:0] waddr0, waddr1, waddr2, waddr3,
    input  logic [15:0] wdata0, wdata1, wdata2, wdata3,
    input  logic [1:0] rsel,
    input  logic [5:0] raddr0, raddr1, raddr2, raddr3,
    output logic [15:0] rdata
);
  logic [15:0] bank0 [0:63];
  logic [15:0] bank1 [0:63];
  logic [15:0] bank2 [0:63];
  logic [15:0] bank3 [0:63];

  always_ff @(posedge clk) begin
    if (we0) case (wsel0)
      2'd0: bank0[waddr0] <= wdata0; 2'd1: bank1[waddr0] <= wdata0;
      2'd2: bank2[waddr0] <= wdata0; default: bank3[waddr0] <= wdata0;
    endcase
    if (we1) case (wsel1)
      2'd0: bank0[waddr1] <= wdata1; 2'd1: bank1[waddr1] <= wdata1;
      2'd2: bank2[waddr1] <= wdata1; default: bank3[waddr1] <= wdata1;
    endcase
    if (we2) case (wsel2)
      2'd0: bank0[waddr2] <= wdata2; 2'd1: bank1[waddr2] <= wdata2;
      2'd2: bank2[waddr2] <= wdata2; default: bank3[waddr2] <= wdata2;
    endcase
    if (we3) case (wsel3)
      2'd0: bank0[waddr3] <= wdata3; 2'd1: bank1[waddr3] <= wdata3;
      2'd2: bank2[waddr3] <= wdata3; default: bank3[waddr3] <= wdata3;
    endcase
  end

  // NELJA lukuosoitetta PER PANKKI (vastaa oikeaa rakennetta: mika
  // tahansa a0/b0/a1/b1 voi osua tahan pankkiin)
  logic [15:0] b0_r0, b0_r1, b0_r2, b0_r3;
  logic [15:0] b1_r0, b1_r1, b1_r2, b1_r3;
  logic [15:0] b2_r0, b2_r1, b2_r2, b2_r3;
  logic [15:0] b3_r0, b3_r1, b3_r2, b3_r3;
  always_ff @(posedge clk) begin
    b0_r0 <= bank0[raddr0]; b0_r1 <= bank0[raddr1];
    b0_r2 <= bank0[raddr2]; b0_r3 <= bank0[raddr3];
    b1_r0 <= bank1[raddr0]; b1_r1 <= bank1[raddr1];
    b1_r2 <= bank1[raddr2]; b1_r3 <= bank1[raddr3];
    b2_r0 <= bank2[raddr0]; b2_r1 <= bank2[raddr1];
    b2_r2 <= bank2[raddr2]; b2_r3 <= bank2[raddr3];
    b3_r0 <= bank3[raddr0]; b3_r1 <= bank3[raddr1];
    b3_r2 <= bank3[raddr2]; b3_r3 <= bank3[raddr3];
  end
  logic [15:0] b0_out, b1_out, b2_out, b3_out;
  always_comb begin
    case (rsel)
      2'd0: b0_out = b0_r0; 2'd1: b0_out = b0_r1;
      2'd2: b0_out = b0_r2; default: b0_out = b0_r3;
    endcase
    case (rsel)
      2'd0: b1_out = b1_r0; 2'd1: b1_out = b1_r1;
      2'd2: b1_out = b1_r2; default: b1_out = b1_r3;
    endcase
    case (rsel)
      2'd0: b2_out = b2_r0; 2'd1: b2_out = b2_r1;
      2'd2: b2_out = b2_r2; default: b2_out = b2_r3;
    endcase
    case (rsel)
      2'd0: b3_out = b3_r0; 2'd1: b3_out = b3_r1;
      2'd2: b3_out = b3_r2; default: b3_out = b3_r3;
    endcase
  end
  always_comb begin
    case (rsel)
      2'd0: rdata = b0_out; 2'd1: rdata = b1_out;
      2'd2: rdata = b2_out; default: rdata = b3_out;
    endcase
  end
endmodule

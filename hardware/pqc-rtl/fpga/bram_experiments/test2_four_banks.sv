// Kokeilu 2: TASMALLEEN sama kuvio kuin pqc_ntt_stage_banked.sv:ssa -
// nelja erillista pankkia + ulkoinen ROM-pohjainen pankinvalinta.
module test2_four_banks (
    input  logic clk,
    input  logic we,
    input  logic [7:0] waddr,  // looginen 0..255
    input  logic [15:0] wdata,
    input  logic re,
    input  logic [7:0] raddr,  // looginen 0..255
    output logic [15:0] rdata
);
  logic [15:0] bank0 [0:63];
  logic [15:0] bank1 [0:63];
  logic [15:0] bank2 [0:63];
  logic [15:0] bank3 [0:63];

  logic [1:0] bank_rom [0:255];
  logic [5:0] local_rom [0:255];
  initial begin
    for (int i = 0; i < 256; i++) begin
      bank_rom[i] = i[1:0];
      local_rom[i] = i[7:2];
    end
  end

  always_ff @(posedge clk) begin
    if (we) begin
      case (bank_rom[waddr])
        2'd0: bank0[local_rom[waddr]] <= wdata;
        2'd1: bank1[local_rom[waddr]] <= wdata;
        2'd2: bank2[local_rom[waddr]] <= wdata;
        default: bank3[local_rom[waddr]] <= wdata;
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (re) begin
      case (bank_rom[raddr])
        2'd0: rdata <= bank0[local_rom[raddr]];
        2'd1: rdata <= bank1[local_rom[raddr]];
        2'd2: rdata <= bank2[local_rom[raddr]];
        default: rdata <= bank3[local_rom[raddr]];
      endcase
    end
  end
endmodule

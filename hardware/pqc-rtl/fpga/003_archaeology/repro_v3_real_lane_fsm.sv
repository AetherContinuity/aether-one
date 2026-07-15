// v3: YKSI AITO lane_fsm-instanssi (ei kopiota) korvaa vapaat
// we/waddr/wdata-syotteet - grant, is_write, osoitteet TULEVAT nyt
// oikeasta tilakoneesta.
module repro (
    input  logic clk, reset, start,
    input  logic [8:0] base_addr,
    input  logic [7:0] stride, count, pair_dist,
    input  logic mode,
    input  logic [15:0] zeta_in,
    output logic done
);
  logic [15:0] bank0 [0:63];
  logic [15:0] bank1 [0:63];
  logic [15:0] bank2 [0:63];
  logic [15:0] bank3 [0:63];

  function automatic logic [1:0] bank_of(input logic [8:0] a);
    bank_of = a[1:0] ^ a[3:2] ^ a[5:4] ^ a[7:6] ^ a[8];
  endfunction
  function automatic logic [5:0] local_of(input logic [8:0] a);
    local_of = a[7:2];
  endfunction

  logic [8:0] mem_addr_a, mem_addr_b;
  logic [15:0] mem_rdata_a, mem_rdata_b;
  logic [15:0] mem_wdata_a, mem_wdata_b;
  logic req, is_write, grant;
  logic [2:0] state;
  logic [7:0] idx_out;

  assign grant = req;

  lane_fsm #(.COEFF_W(16), .SPAD_AW(9), .READ_LATENCY(1)) dut (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr), .stride(stride), .count(count), .pair_dist(pair_dist), .mode(mode),
    .mem_addr_a(mem_addr_a), .mem_addr_b(mem_addr_b),
    .mem_rdata_a(mem_rdata_a), .mem_rdata_b(mem_rdata_b),
    .mem_wdata_a(mem_wdata_a), .mem_wdata_b(mem_wdata_b),
    .zeta_in(zeta_in), .req(req), .is_write(is_write), .grant(grant),
    .state(state), .done(done), .idx_out(idx_out)
  );

  wire [1:0] pb_a = bank_of(mem_addr_a); wire [5:0] pl_a = local_of(mem_addr_a);
  wire [1:0] pb_b = bank_of(mem_addr_b); wire [5:0] pl_b = local_of(mem_addr_b);

  always_ff @(posedge clk) begin
    if (grant && is_write) begin
      case (pb_a)
        2'd0: bank0[pl_a] <= mem_wdata_a; 2'd1: bank1[pl_a] <= mem_wdata_a;
        2'd2: bank2[pl_a] <= mem_wdata_a; default: bank3[pl_a] <= mem_wdata_a;
      endcase
      case (pb_b)
        2'd0: bank0[pl_b] <= mem_wdata_b; 2'd1: bank1[pl_b] <= mem_wdata_b;
        2'd2: bank2[pl_b] <= mem_wdata_b; default: bank3[pl_b] <= mem_wdata_b;
      endcase
    end
  end

  logic [15:0] b0_ra, b1_ra, b2_ra, b3_ra;
  logic [15:0] b0_rb, b1_rb, b2_rb, b3_rb;
  always_ff @(posedge clk) begin
    b0_ra <= bank0[pl_a]; b1_ra <= bank1[pl_a]; b2_ra <= bank2[pl_a]; b3_ra <= bank3[pl_a];
    b0_rb <= bank0[pl_b]; b1_rb <= bank1[pl_b]; b2_rb <= bank2[pl_b]; b3_rb <= bank3[pl_b];
  end
  always_comb begin
    case (pb_a)
      2'd0: mem_rdata_a = b0_ra; 2'd1: mem_rdata_a = b1_ra; 2'd2: mem_rdata_a = b2_ra; default: mem_rdata_a = b3_ra;
    endcase
    case (pb_b)
      2'd0: mem_rdata_b = b0_rb; 2'd1: mem_rdata_b = b1_rb; 2'd2: mem_rdata_b = b2_rb; default: mem_rdata_b = b3_rb;
    endcase
  end
endmodule

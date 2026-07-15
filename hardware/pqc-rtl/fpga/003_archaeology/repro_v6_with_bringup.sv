// v4: KAKSI aitoa lane_fsm-instanssia (lane0, lane1) - vastaa
// oikean ytimen dual-lane-rakennetta.
module repro (
    input  logic clk, reset, start,
    input  logic [8:0] base_addr0, base_addr1,
    input  logic [7:0] stride, count, pair_dist,
    input  logic mode,
    input  logic [15:0] zeta0, zeta1,
    output logic done0, done1,
  output logic bank_conflict_detected,
  input  logic load_valid,
  input  logic [7:0] load_addr,
  input  logic [15:0] load_data,
  input  logic read_en,
  input  logic [7:0] read_addr,
  output logic read_valid,
  output logic [15:0] read_data
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

  logic [8:0] addr_a0, addr_b0, addr_a1, addr_b1;
  logic [15:0] rdata_a0, rdata_b0, rdata_a1, rdata_b1;
  logic [15:0] wdata_a0, wdata_b0, wdata_a1, wdata_b1;
  logic req0, is_write0, grant0, req1, is_write1, grant1;
  logic [2:0] state0, state1;
  logic [7:0] idx0, idx1;

  assign grant0 = req0;
  assign grant1 = req1;

  lane_fsm #(.COEFF_W(16), .SPAD_AW(9), .READ_LATENCY(1)) lane0 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr0), .stride(stride), .count(count), .pair_dist(pair_dist), .mode(mode),
    .mem_addr_a(addr_a0), .mem_addr_b(addr_b0),
    .mem_rdata_a(rdata_a0), .mem_rdata_b(rdata_b0),
    .mem_wdata_a(wdata_a0), .mem_wdata_b(wdata_b0),
    .zeta_in(zeta0), .req(req0), .is_write(is_write0), .grant(grant0),
    .state(state0), .done(done0), .idx_out(idx0)
  );
  lane_fsm #(.COEFF_W(16), .SPAD_AW(9), .READ_LATENCY(1)) lane1 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr1), .stride(stride), .count(count), .pair_dist(pair_dist), .mode(mode),
    .mem_addr_a(addr_a1), .mem_addr_b(addr_b1),
    .mem_rdata_a(rdata_a1), .mem_rdata_b(rdata_b1),
    .mem_wdata_a(wdata_a1), .mem_wdata_b(wdata_b1),
    .zeta_in(zeta1), .req(req1), .is_write(is_write1), .grant(grant1),
    .state(state1), .done(done1), .idx_out(idx1)
  );

  wire [1:0] pb_a0 = bank_of(addr_a0); wire [5:0] pl_a0 = local_of(addr_a0);
  wire [1:0] pb_b0 = bank_of(addr_b0); wire [5:0] pl_b0 = local_of(addr_b0);
  wire [1:0] pb_a1 = bank_of(addr_a1); wire [5:0] pl_a1 = local_of(addr_a1);
  wire [1:0] pb_b1 = bank_of(addr_b1); wire [5:0] pl_b1 = local_of(addr_b1);

  logic conflict_flag;
  always_comb begin
    conflict_flag = 1'b0;
    if (grant0 && grant1) begin
      if (pb_a0 == pb_a1 || pb_a0 == pb_b1 || pb_b0 == pb_a1 || pb_b0 == pb_b1) begin
        conflict_flag = 1'b1;
      end
    end
  end
  assign bank_conflict_detected = conflict_flag;

  logic [1:0] read_bank_reg;
  logic [5:0] read_local_reg;
  always_ff @(posedge clk) begin
    if (load_valid) begin
      case (bank_of({1'b0,load_addr}))
        2'd0: bank0[local_of({1'b0,load_addr})] <= load_data;
        2'd1: bank1[local_of({1'b0,load_addr})] <= load_data;
        2'd2: bank2[local_of({1'b0,load_addr})] <= load_data;
        default: bank3[local_of({1'b0,load_addr})] <= load_data;
      endcase
    end
    if (reset) read_valid <= 1'b0;
    else begin
      read_valid <= read_en;
      if (read_en) begin
        read_bank_reg  <= bank_of({1'b0,read_addr});
        read_local_reg <= local_of({1'b0,read_addr});
      end
    end
  end
  always_ff @(posedge clk) begin
    case (read_bank_reg)
      2'd0: read_data <= bank0[read_local_reg];
      2'd1: read_data <= bank1[read_local_reg];
      2'd2: read_data <= bank2[read_local_reg];
      default: read_data <= bank3[read_local_reg];
    endcase
  end

  always_ff @(posedge clk) begin
    if (grant0 && is_write0) begin
      case (pb_a0)
        2'd0: bank0[pl_a0] <= wdata_a0; 2'd1: bank1[pl_a0] <= wdata_a0;
        2'd2: bank2[pl_a0] <= wdata_a0; default: bank3[pl_a0] <= wdata_a0;
      endcase
      case (pb_b0)
        2'd0: bank0[pl_b0] <= wdata_b0; 2'd1: bank1[pl_b0] <= wdata_b0;
        2'd2: bank2[pl_b0] <= wdata_b0; default: bank3[pl_b0] <= wdata_b0;
      endcase
    end
    if (grant1 && is_write1) begin
      case (pb_a1)
        2'd0: bank0[pl_a1] <= wdata_a1; 2'd1: bank1[pl_a1] <= wdata_a1;
        2'd2: bank2[pl_a1] <= wdata_a1; default: bank3[pl_a1] <= wdata_a1;
      endcase
      case (pb_b1)
        2'd0: bank0[pl_b1] <= wdata_b1; 2'd1: bank1[pl_b1] <= wdata_b1;
        2'd2: bank2[pl_b1] <= wdata_b1; default: bank3[pl_b1] <= wdata_b1;
      endcase
    end
  end

  logic [15:0] b0_a0,b1_a0,b2_a0,b3_a0, b0_b0,b1_b0,b2_b0,b3_b0;
  logic [15:0] b0_a1,b1_a1,b2_a1,b3_a1, b0_b1,b1_b1,b2_b1,b3_b1;
  always_ff @(posedge clk) begin
    b0_a0<=bank0[pl_a0]; b1_a0<=bank1[pl_a0]; b2_a0<=bank2[pl_a0]; b3_a0<=bank3[pl_a0];
    b0_b0<=bank0[pl_b0]; b1_b0<=bank1[pl_b0]; b2_b0<=bank2[pl_b0]; b3_b0<=bank3[pl_b0];
    b0_a1<=bank0[pl_a1]; b1_a1<=bank1[pl_a1]; b2_a1<=bank2[pl_a1]; b3_a1<=bank3[pl_a1];
    b0_b1<=bank0[pl_b1]; b1_b1<=bank1[pl_b1]; b2_b1<=bank2[pl_b1]; b3_b1<=bank3[pl_b1];
  end
  always_comb begin
    case (pb_a0) 2'd0: rdata_a0=b0_a0; 2'd1: rdata_a0=b1_a0; 2'd2: rdata_a0=b2_a0; default: rdata_a0=b3_a0; endcase
    case (pb_b0) 2'd0: rdata_b0=b0_b0; 2'd1: rdata_b0=b1_b0; 2'd2: rdata_b0=b2_b0; default: rdata_b0=b3_b0; endcase
    case (pb_a1) 2'd0: rdata_a1=b0_a1; 2'd1: rdata_a1=b1_a1; 2'd2: rdata_a1=b2_a1; default: rdata_a1=b3_a1; endcase
    case (pb_b1) 2'd0: rdata_b1=b0_b1; 2'd1: rdata_b1=b1_b1; 2'd2: rdata_b1=b2_b1; default: rdata_b1=b3_b1; endcase
  end
endmodule

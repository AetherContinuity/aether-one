# SYNTH-001: Barrett multiplier pipeline exploration

**Status:** Open
**Created:** 2026-07-21
**Priority:** Performance optimization candidate (post-functional-
verification phase)
**Related:** `SYNTHESIS_REPORT.md`, `pqc_dilithium_barrett_mulmod.sv`

## Background

Yosys `ltp` (longest topological path) analysis identified **107
logic levels** through `pqc_dilithium_barrett_mulmod.sv`, the
Barrett modular-reduction multiplier used pervasively throughout the
NTT forward/inverse cores (hundreds of invocations per full 256-
coefficient transform). This is the deepest recurring combinational
block found anywhere in the M5-DILITHIUM-001 codebase.

A full place-and-route-based Fmax measurement (`nextpnr-ecp5`) did
not converge within available time/resources in the development
sandbox (see `SYNTHESIS_REPORT.md`), so absolute Fmax remains
unmeasured. However, `ltp`'s logic-level count is a strong,
tool-independent signal that this specific block is a primary
critical-path contributor, and that pipelining it is a well-
targeted optimization candidate - independent of what the eventual
measured Fmax turns out to be.

## Objective

Explore splitting `pqc_dilithium_barrett_mulmod.sv`'s current
single-cycle combinational implementation into a registered,
multi-stage pipeline, and measure the resulting trade-offs.

## Proposed experiment matrix

| Variant | Description | Metrics to collect |
|---|---|---|
| **Baseline** | Current implementation (0-stage, fully combinational) | `ltp` logic levels (already: 107), cell count (already: 6517), FF count (already: 0) |
| **2-stage pipeline** | Split multiply and Barrett-reduction steps across one register boundary | `ltp` logic levels per stage, cell count, FF count, cycles added per NTT butterfly call |
| **3-stage pipeline** | Further split (e.g. multiply / partial-reduce / final-correct) | Same as above |

For each variant, collect:
1. **`ltp` logic levels** (fast, already-proven method from this
   session) for the longest path *within any single pipeline stage*
   - the goal is to see this drop substantially below 107 per stage.
2. **Cell/FF count** (generic `synth`/`stat`, already-proven method)
   - expect FF count to increase (new pipeline registers), cell
   count to stay roughly flat (same logic, just partitioned).
3. **Cycle-count impact on the full NTT core.** `pqc_dilithium_ntt_core.sv`
   invokes Barrett multiplication as part of each butterfly step;
   adding pipeline stages to Barrett changes the core's own FSM
   (either by adding wait states, or by restructuring to keep the
   pipeline full across consecutive butterflies). Measure the new
   total cycle count for one full 256-coefficient NTT transform
   against the known baseline (previously measured elsewhere in
   this project - see DK1 status for the original ~3584-4095
   cycle/NTT figures) and confirm functional correctness is
   unaffected (re-run the existing NTT unit/component tests from
   `TESTING.md`'s taxonomy - this is a Unit/Component-level RTL
   change, so it should be verifiable with the same fast tests,
   NOT a new long integration run).
4. **Fmax impact estimate.** Even without full P&R, a reduced
   `ltp` logic-level count per stage is itself informative;
   if/when a dedicated (non-resource-constrained) environment
   becomes available, re-attempt `nextpnr-ecp5` on the pipelined
   variant for a real, measured Fmax comparison against the
   (still-unmeasured) baseline.

## Why this is a good next target (rationale carried over from
   discussion)

- It is a **narrow, single-module** change - much more tractable
  than attempting to optimize the entire ML-DSA pipeline at once.
- Because Barrett multiplication is reused **hundreds of times**
  per NTT transform, any latency reduction here compounds across
  the entire Sign/Verify/KeyGen pipeline (all three use NTT
  extensively).
- The existing test infrastructure (Unit-level `barrett_mulmod`
  synthesis/simulation, Component-level NTT tests) already provides
  a fast regression harness for this change - no new heavy
  integration testing should be required to validate functional
  correctness of a pipelined variant, only re-running what already
  exists.

## Out of scope for this ticket

- Full end-to-end Fmax measurement (blocked on P&R convergence in
  this environment - tracked separately, not a blocker for starting
  this exploration).
- ECP5 BRAM-mapping investigation (pre-existing open item from
  ML-KEM work, `SYNTHESIS_NOTE.md` - unrelated to Barrett pipelining).
- Architecture-level parallelism changes to `sign_hint_core`/
  `verify_core` (the 1536-instance Decompose/MakeHint structures) -
  that is a separate, larger architectural question already noted
  in `SYNTHESIS_REPORT.md`'s own recommendations, not part of this
  ticket's narrow scope.

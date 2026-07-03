#include <stdint.h>
#include <riscv_vector.h>

#define Q 8380417
#define GAMMA2 ((Q - 1) / 32)
#define N 256

/* decompose (GAMMA2=(Q-1)/32-haara, ML-DSA-65): a1=HighBits, a0=LowBits.
 * Sama kaava kuin ref/rounding.c: a1=(a+127)>>7; a1=(a1*1025+2^21)>>22;
 * a1&=15; a0=a-a1*2*GAMMA2; korjaus jos a0>(Q-1)/2. */
void poly_decompose_rvv(int32_t *a1_out, int32_t *a0_out, const int32_t *a) {
    unsigned int i = 0;
    while (i < N) {
        size_t vl = __riscv_vsetvl_e32m1(N - i);
        vint32m1_t va = __riscv_vle32_v_i32m1(&a[i], vl);

        vint32m1_t a1 = __riscv_vsra_vx_i32m1(__riscv_vadd_vx_i32m1(va, 127, vl), 7, vl);
        vint32m1_t prod = __riscv_vadd_vx_i32m1(
            __riscv_vmul_vx_i32m1(a1, 1025, vl), (1 << 21), vl);
        a1 = __riscv_vsra_vx_i32m1(prod, 22, vl);
        a1 = __riscv_vand_vx_i32m1(a1, 15, vl);

        vint32m1_t a0 = __riscv_vsub_vv_i32m1(va, __riscv_vmul_vx_i32m1(a1, 2 * GAMMA2, vl), vl);
        /* korjaus: jos (Q-1)/2 - a0 < 0 (eli a0 > (Q-1)/2), vahenna Q */
        vint32m1_t diff = __riscv_vrsub_vx_i32m1(a0, (Q - 1) / 2, vl);
        vint32m1_t mask = __riscv_vsra_vx_i32m1(diff, 31, vl);  /* -1 jos diff<0, muuten 0 */
        vint32m1_t corr = __riscv_vand_vx_i32m1(mask, Q, vl);
        a0 = __riscv_vsub_vv_i32m1(a0, corr, vl);

        __riscv_vse32_v_i32m1(&a1_out[i], a1, vl);
        __riscv_vse32_v_i32m1(&a0_out[i], a0, vl);
        i += vl;
    }
}

/* make_hint per kerroin: 1 jos |a0|>GAMMA2 tai (a0==-GAMMA2 && a1!=0) */
void poly_make_hint_rvv(uint32_t *hint_out, const int32_t *a0, const int32_t *a1) {
    unsigned int i = 0;
    while (i < N) {
        size_t vl = __riscv_vsetvl_e32m1(N - i);
        vint32m1_t v0 = __riscv_vle32_v_i32m1(&a0[i], vl);
        vint32m1_t v1 = __riscv_vle32_v_i32m1(&a1[i], vl);

        vbool32_t gt = __riscv_vmsgt_vx_i32m1_b32(v0, GAMMA2, vl);
        vbool32_t lt = __riscv_vmslt_vx_i32m1_b32(v0, -GAMMA2, vl);
        vbool32_t eq_neg = __riscv_vmseq_vx_i32m1_b32(v0, -GAMMA2, vl);
        vbool32_t a1_ne0 = __riscv_vmsne_vx_i32m1_b32(v1, 0, vl);
        vbool32_t edge = __riscv_vmand_mm_b32(eq_neg, a1_ne0, vl);

        vbool32_t res = __riscv_vmor_mm_b32(__riscv_vmor_mm_b32(gt, lt, vl), edge, vl);

        vuint32m1_t zeros = __riscv_vmv_v_x_u32m1(0, vl);
        vuint32m1_t out = __riscv_vmerge_vxm_u32m1(zeros, 1, res, vl);
        __riscv_vse32_v_u32m1(&hint_out[i], out, vl);
        i += vl;
    }
}

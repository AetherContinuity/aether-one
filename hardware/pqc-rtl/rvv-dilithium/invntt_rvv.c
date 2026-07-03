#include <stdint.h>
#include <riscv_vector.h>
#include "zetas.h"

#define Q 8380417
#define QINV 58728449
#define N 256

static inline vint32m1_t montgomery_reduce_vec(vint64m2_t a, size_t vl) {
    vint32m1_t a32 = __riscv_vnsra_wx_i32m1(__riscv_vsll_vx_i64m2(a, 32, vl), 32, vl);
    vint32m1_t t32 = __riscv_vmul_vx_i32m1(a32, (int32_t)QINV, vl);
    vint64m2_t t32_ext = __riscv_vsext_vf2_i64m2(t32, vl);
    vint64m2_t tQ = __riscv_vmul_vx_i64m2(t32_ext, Q, vl);
    vint64m2_t diff = __riscv_vsub_vv_i64m2(a, tQ, vl);
    vint64m2_t shifted = __riscv_vsra_vx_i64m2(diff, 32, vl);
    return __riscv_vnsra_wx_i32m1(shifted, 0, vl);
}

/* Kaanteis-NTT (Gentleman-Sande), sama rakenne kuin ref/ntt.c:n
 * invntt_tomont: len=1..128, zeta=-zetas[--k], (add/sub ENNEN kertolaskua,
 * eri jarjestys kuin eteenpain-NTT:n Cooley-Tukey-perhosessa). Lopuksi
 * skaalaus Montgomery-kertoimella f=41978 (mont^2/256). */
void invntt_rvv(int32_t *a) {
    unsigned int len, start;
    int k = 256;
    const int32_t f = 41978;

    for (len = 1; len < N; len <<= 1) {
        for (start = 0; start < N; start += 2 * len) {
            int32_t zeta = -ZETAS[--k];

            unsigned int j = start;
            while (j < start + len) {
                size_t remaining = start + len - j;
                size_t vl = __riscv_vsetvl_e32m1(remaining);

                vint32m1_t a_j = __riscv_vle32_v_i32m1(&a[j], vl);
                vint32m1_t a_jl = __riscv_vle32_v_i32m1(&a[j + len], vl);

                vint32m1_t new_j = __riscv_vadd_vv_i32m1(a_j, a_jl, vl);
                vint32m1_t diff = __riscv_vsub_vv_i32m1(a_j, a_jl, vl);

                vint64m2_t prod = __riscv_vwmul_vx_i64m2(diff, zeta, vl);
                vint32m1_t new_jl = montgomery_reduce_vec(prod, vl);

                __riscv_vse32_v_i32m1(&a[j], new_j, vl);
                __riscv_vse32_v_i32m1(&a[j + len], new_jl, vl);

                j += vl;
            }
        }
    }

    /* Loppuskaalaus: a[j] = montgomery_reduce(f * a[j]) kaikille j */
    unsigned int j = 0;
    while (j < N) {
        size_t vl = __riscv_vsetvl_e32m1(N - j);
        vint32m1_t aj = __riscv_vle32_v_i32m1(&a[j], vl);
        vint64m2_t prod = __riscv_vwmul_vx_i64m2(aj, f, vl);
        vint32m1_t res = montgomery_reduce_vec(prod, vl);
        __riscv_vse32_v_i32m1(&a[j], res, vl);
        j += vl;
    }
}

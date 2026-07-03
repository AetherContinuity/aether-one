#include <stdio.h>
#include <stdint.h>
#include <riscv_vector.h>
#include "zetas.h"

#define Q 8380417
#define QINV 58728449
#define N 256

/* Yhden vektorin Montgomery-reduktio, sama algoritmi kuin
 * mont_dilithium_rvv.c:ssa (todennettu erikseen 7/7 oikeaa referenssia
 * vastaan). Tassa inline-versio joka toimii suoraan int64-vektorista
 * int32-vektoriin ilman valimuistia. */
static inline vint32m1_t montgomery_reduce_vec(vint64m2_t a, size_t vl) {
    vint32m1_t a32 = __riscv_vnsra_wx_i32m1(__riscv_vsll_vx_i64m2(a, 32, vl), 32, vl);
    vint32m1_t t32 = __riscv_vmul_vx_i32m1(a32, (int32_t)QINV, vl);
    vint64m2_t t32_ext = __riscv_vsext_vf2_i64m2(t32, vl);
    vint64m2_t tQ = __riscv_vmul_vx_i64m2(t32_ext, Q, vl);
    vint64m2_t diff = __riscv_vsub_vv_i64m2(a, tQ, vl);
    vint64m2_t shifted = __riscv_vsra_vx_i64m2(diff, 32, vl);
    return __riscv_vnsra_wx_i32m1(shifted, 0, vl);
}

/* Taysi NTT, sama rakenne kuin pq-crystals/dilithium ref/ntt.c:
 * len=128..1, jokaiselle lohkolle oma zeta, lohkon sisalla vektoroitu
 * perhonen (RVV vektoroi 'len' rinnakkaista butterfly-operaatiota). */
void ntt_rvv(int32_t *a) {
    unsigned int len, start, k = 0;

    for (len = 128; len > 0; len >>= 1) {
        for (start = 0; start < N; start += 2 * len) {
            int32_t zeta = ZETAS[++k];

            unsigned int j = start;
            while (j < start + len) {
                size_t remaining = start + len - j;
                size_t vl = __riscv_vsetvl_e32m1(remaining);

                vint32m1_t a_hi = __riscv_vle32_v_i32m1(&a[j + len], vl);
                vint32m1_t a_lo = __riscv_vle32_v_i32m1(&a[j], vl);

                /* t = montgomery_reduce(zeta * a[j+len]) */
                vint64m2_t prod = __riscv_vwmul_vx_i64m2(a_hi, zeta, vl);
                vint32m1_t t = montgomery_reduce_vec(prod, vl);

                vint32m1_t new_hi = __riscv_vsub_vv_i32m1(a_lo, t, vl);
                vint32m1_t new_lo = __riscv_vadd_vv_i32m1(a_lo, t, vl);

                __riscv_vse32_v_i32m1(&a[j + len], new_hi, vl);
                __riscv_vse32_v_i32m1(&a[j], new_lo, vl);

                j += vl;
            }
        }
    }
}

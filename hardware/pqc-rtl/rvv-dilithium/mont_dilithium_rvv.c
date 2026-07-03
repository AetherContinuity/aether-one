#include <stdio.h>
#include <stdint.h>
#include <riscv_vector.h>

#define Q 8380417
#define QINV 58728449

/* Rinnakkainen 32-bittinen Montgomery-reduktio Dilithiumin/ML-DSA:n
 * omalla algoritmilla (pq-crystals/dilithium ref/reduce.c):
 *   t32 = (int32_t)a * QINV                 (mod 2^32)
 *   t   = (a - (int64_t)t32 * Q) >> 32
 * HUOM: EI SAMA kuin Kyberin 16-bittinen versio (mont_rvv.c) - eri Q,
 * eri R (2^32 vs 2^16), eri QINV-etumerkkikonventio. */
void dilithium_mont_reduce_rvv(const int64_t *in, int32_t *out, size_t n) {
    size_t i = 0;
    while (i < n) {
        size_t vl = __riscv_vsetvl_e64m2(n - i);
        vint64m2_t a = __riscv_vle64_v_i64m2(&in[i], vl);

        /* a32 = (int32_t)a : ota alimmat 32 bittia, tulkitse etumerkillisena */
        vint32m1_t a32 = __riscv_vnsra_wx_i32m1(
            __riscv_vsll_vx_i64m2(a, 32, vl), 32, vl);  /* sign-extend low32 shift-trikilla */

        /* t32 = a32 * QINV, pidetaan vain alimmat 32 bittia (luonnollinen ylivuoto) */
        vint32m1_t t32 = __riscv_vmul_vx_i32m1(a32, (int32_t)QINV, vl);

        /* t32_widened_signed * Q, 64-bittisena */
        vint64m2_t t32_ext = __riscv_vsext_vf2_i64m2(t32, vl);
        vint64m2_t tQ = __riscv_vmul_vx_i64m2(t32_ext, Q, vl);

        vint64m2_t diff = __riscv_vsub_vv_i64m2(a, tQ, vl);
        vint64m2_t shifted = __riscv_vsra_vx_i64m2(diff, 32, vl);

        vint32m1_t result = __riscv_vnsra_wx_i32m1(shifted, 0, vl);
        __riscv_vse32_v_i32m1(&out[i], result, vl);

        i += vl;
    }
}

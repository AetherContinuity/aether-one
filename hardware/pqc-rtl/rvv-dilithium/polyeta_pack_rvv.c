#include <stdint.h>
#include <riscv_vector.h>

#define ETA 4
#define N 256

/* polyeta_pack ETA=4-haaralle: t=ETA-a per kerroin, 2 kerrointa/tavu. */
void polyeta_pack_rvv(uint8_t *r, const int32_t *a) {
    unsigned int i = 0;
    const unsigned int NHALF = N / 2;
    int32_t tmp[128];
    while (i < NHALF) {
        size_t vl = __riscv_vsetvl_e32m1(NHALF - i);
        vint32m1_t a_even = __riscv_vlse32_v_i32m1(&a[2*i], 8, vl);
        vint32m1_t a_odd  = __riscv_vlse32_v_i32m1(&a[2*i+1], 8, vl);
        vint32m1_t t0 = __riscv_vrsub_vx_i32m1(a_even, ETA, vl);
        vint32m1_t t1 = __riscv_vrsub_vx_i32m1(a_odd, ETA, vl);
        vint32m1_t packed = __riscv_vor_vv_i32m1(t0, __riscv_vsll_vx_i32m1(t1, 4, vl), vl);
        __riscv_vse32_v_i32m1(&tmp[i], packed, vl);
        i += vl;
    }
    for (unsigned int j = 0; j < NHALF; j++) r[j] = (uint8_t)tmp[j];
}

/* polyeta_unpack ETA=4-haaralle: kaanteinen. vzext_vf4 8->32 bit vaatii
 * LMUL*4 kohteen (m1->m4) - sama saanto kuin rej_uniform_rvv.c:ssa. */
void polyeta_unpack_rvv(int32_t *r, const uint8_t *a) {
    unsigned int i = 0;
    const unsigned int NHALF = N / 2;
    while (i < NHALF) {
        size_t vl = __riscv_vsetvl_e8m1(NHALF - i);
        vuint8m1_t b = __riscv_vle8_v_u8m1(&a[i], vl);
        vuint8m1_t lo8 = __riscv_vand_vx_u8m1(b, 0x0F, vl);
        vuint8m1_t hi8 = __riscv_vsrl_vx_u8m1(b, 4, vl);

        vuint32m4_t lo_u = __riscv_vzext_vf4_u32m4(lo8, vl);
        vuint32m4_t hi_u = __riscv_vzext_vf4_u32m4(hi8, vl);
        vint32m4_t lo = __riscv_vreinterpret_v_u32m4_i32m4(lo_u);
        vint32m4_t hi = __riscv_vreinterpret_v_u32m4_i32m4(hi_u);

        vint32m4_t r_even = __riscv_vrsub_vx_i32m4(lo, ETA, vl);
        vint32m4_t r_odd  = __riscv_vrsub_vx_i32m4(hi, ETA, vl);

        __riscv_vsse32_v_i32m4(r + 2*i + 0, 8, r_even, vl);
        __riscv_vsse32_v_i32m4(r + 2*i + 1, 8, r_odd, vl);
        i += vl;
    }
}

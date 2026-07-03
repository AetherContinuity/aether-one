#include <stdint.h>
#include <riscv_vector.h>

#define N 256

/* polyw1_pack GAMMA2=(Q-1)/32-haaralle (ML-DSA-65): r[i] = a[2i] | (a[2i+1]<<4).
 * Jokainen kerroin on jo 4 bitissa (decompose maskaa a1:n &15). Vektori
 * laskee yhdistetyn arvon 32-bittisena, skalaarisilmukka typistaa
 * tavuiksi - valtetaan vncvt-narrowingin LMUL-ristiriidat (sama ongelma
 * kuin RTL M1:ssa aiemmin havaittiin). */
void polyw1_pack_rvv(uint8_t *r, const int32_t *a) {
    unsigned int i = 0;
    const unsigned int NHALF = N / 2;
    int32_t tmp[128];

    while (i < NHALF) {
        size_t vl = __riscv_vsetvl_e32m1(NHALF - i);
        vint32m1_t a_even = __riscv_vlse32_v_i32m1(&a[2*i], 8, vl);
        vint32m1_t a_odd  = __riscv_vlse32_v_i32m1(&a[2*i+1], 8, vl);
        vint32m1_t packed = __riscv_vor_vv_i32m1(a_even, __riscv_vsll_vx_i32m1(a_odd, 4, vl), vl);
        __riscv_vse32_v_i32m1(&tmp[i], packed, vl);
        i += vl;
    }
    for (unsigned int j = 0; j < NHALF; j++) r[j] = (uint8_t)tmp[j];
}

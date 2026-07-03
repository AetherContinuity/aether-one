#include <stdint.h>
#include <riscv_vector.h>

#define GAMMA1 (1 << 19)
#define N 256

/* polyz_pack GAMMA1=2^19-haaralle: 2 kerrointa -> 5 tavua. Sama malli
 * kuin polyt1_pack_rvv (vektori laskee 32-bittisena, skalaarisilmukka
 * typistaa - valtetaan vncvt-narrowing). */
void polyz_pack_rvv(uint8_t *r, const int32_t *a) {
    unsigned int i = 0;
    const unsigned int NHALF = N / 2;
    int32_t b0[128], b1[128], b2[128], b3[128], b4[128];

    while (i < NHALF) {
        size_t vl = __riscv_vsetvl_e32m1(NHALF - i);
        vint32m1_t a0 = __riscv_vlse32_v_i32m1(&a[2*i+0], 8, vl);
        vint32m1_t a1 = __riscv_vlse32_v_i32m1(&a[2*i+1], 8, vl);
        vint32m1_t t0 = __riscv_vrsub_vx_i32m1(a0, GAMMA1, vl);
        vint32m1_t t1 = __riscv_vrsub_vx_i32m1(a1, GAMMA1, vl);

        vint32m1_t r0 = t0;
        vint32m1_t r1 = __riscv_vsra_vx_i32m1(t0, 8, vl);
        vint32m1_t r2 = __riscv_vor_vv_i32m1(
            __riscv_vsra_vx_i32m1(t0, 16, vl), __riscv_vsll_vx_i32m1(t1, 4, vl), vl);
        vint32m1_t r3 = __riscv_vsra_vx_i32m1(t1, 4, vl);
        vint32m1_t r4 = __riscv_vsra_vx_i32m1(t1, 12, vl);

        __riscv_vse32_v_i32m1(&b0[i], r0, vl);
        __riscv_vse32_v_i32m1(&b1[i], r1, vl);
        __riscv_vse32_v_i32m1(&b2[i], r2, vl);
        __riscv_vse32_v_i32m1(&b3[i], r3, vl);
        __riscv_vse32_v_i32m1(&b4[i], r4, vl);
        i += vl;
    }
    for (unsigned int j = 0; j < NHALF; j++) {
        r[5*j+0] = (uint8_t)b0[j];
        r[5*j+1] = (uint8_t)b1[j];
        r[5*j+2] = (uint8_t)b2[j];
        r[5*j+3] = (uint8_t)b3[j];
        r[5*j+4] = (uint8_t)b4[j];
    }
}

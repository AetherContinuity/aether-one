#include <stdint.h>
#include <riscv_vector.h>

#define N 256

/* polyt1_pack: 4 kerrointa (10 bittia kukin) -> 5 tavua. Vektori laskee
 * 32-bittisena, skalaarisilmukka typistaa (sama malli kuin polyw1_pack_rvv,
 * valttaa vncvt-narrowingin LMUL-ristiriidat). */
void polyt1_pack_rvv(uint8_t *r, const int32_t *a) {
    unsigned int i = 0;
    const unsigned int NQ = N / 4;  /* 64 nelikkoa */
    int32_t b0[64], b1[64], b2[64], b3[64], b4[64];

    while (i < NQ) {
        size_t vl = __riscv_vsetvl_e32m1(NQ - i);
        vint32m1_t a0 = __riscv_vlse32_v_i32m1(&a[4*i+0], 16, vl);
        vint32m1_t a1 = __riscv_vlse32_v_i32m1(&a[4*i+1], 16, vl);
        vint32m1_t a2 = __riscv_vlse32_v_i32m1(&a[4*i+2], 16, vl);
        vint32m1_t a3 = __riscv_vlse32_v_i32m1(&a[4*i+3], 16, vl);

        vint32m1_t r0 = a0;
        vint32m1_t r1 = __riscv_vor_vv_i32m1(__riscv_vsra_vx_i32m1(a0, 8, vl), __riscv_vsll_vx_i32m1(a1, 2, vl), vl);
        vint32m1_t r2 = __riscv_vor_vv_i32m1(__riscv_vsra_vx_i32m1(a1, 6, vl), __riscv_vsll_vx_i32m1(a2, 4, vl), vl);
        vint32m1_t r3 = __riscv_vor_vv_i32m1(__riscv_vsra_vx_i32m1(a2, 4, vl), __riscv_vsll_vx_i32m1(a3, 6, vl), vl);
        vint32m1_t r4 = __riscv_vsra_vx_i32m1(a3, 2, vl);

        __riscv_vse32_v_i32m1(&b0[i], r0, vl);
        __riscv_vse32_v_i32m1(&b1[i], r1, vl);
        __riscv_vse32_v_i32m1(&b2[i], r2, vl);
        __riscv_vse32_v_i32m1(&b3[i], r3, vl);
        __riscv_vse32_v_i32m1(&b4[i], r4, vl);
        i += vl;
    }
    for (unsigned int j = 0; j < NQ; j++) {
        r[5*j+0] = (uint8_t)b0[j];
        r[5*j+1] = (uint8_t)b1[j];
        r[5*j+2] = (uint8_t)b2[j];
        r[5*j+3] = (uint8_t)b3[j];
        r[5*j+4] = (uint8_t)b4[j];
    }
}

/* polyt1_unpack: kaanteinen, strided-lataus + bittiyhdistely, ei hylkaysta. */
void polyt1_unpack_rvv(int32_t *r, const uint8_t *a) {
    unsigned int i = 0;
    const unsigned int NQ = N / 4;

    while (i < NQ) {
        size_t vl = __riscv_vsetvl_e8m1(NQ - i);
        const uint8_t *base = a + i * 5;
        vuint8m1_t b0 = __riscv_vlse8_v_u8m1(base + 0, 5, vl);
        vuint8m1_t b1 = __riscv_vlse8_v_u8m1(base + 1, 5, vl);
        vuint8m1_t b2 = __riscv_vlse8_v_u8m1(base + 2, 5, vl);
        vuint8m1_t b3 = __riscv_vlse8_v_u8m1(base + 3, 5, vl);
        vuint8m1_t b4 = __riscv_vlse8_v_u8m1(base + 4, 5, vl);

        vuint32m4_t w0 = __riscv_vzext_vf4_u32m4(b0, vl);
        vuint32m4_t w1 = __riscv_vzext_vf4_u32m4(b1, vl);
        vuint32m4_t w2 = __riscv_vzext_vf4_u32m4(b2, vl);
        vuint32m4_t w3 = __riscv_vzext_vf4_u32m4(b3, vl);
        vuint32m4_t w4 = __riscv_vzext_vf4_u32m4(b4, vl);

        vuint32m4_t r0 = __riscv_vand_vx_u32m4(
            __riscv_vor_vv_u32m4(w0, __riscv_vsll_vx_u32m4(w1, 8, vl), vl), 0x3FF, vl);
        vuint32m4_t r1 = __riscv_vand_vx_u32m4(
            __riscv_vor_vv_u32m4(__riscv_vsrl_vx_u32m4(w1, 2, vl), __riscv_vsll_vx_u32m4(w2, 6, vl), vl), 0x3FF, vl);
        vuint32m4_t r2 = __riscv_vand_vx_u32m4(
            __riscv_vor_vv_u32m4(__riscv_vsrl_vx_u32m4(w2, 4, vl), __riscv_vsll_vx_u32m4(w3, 4, vl), vl), 0x3FF, vl);
        vuint32m4_t r3 = __riscv_vand_vx_u32m4(
            __riscv_vor_vv_u32m4(__riscv_vsrl_vx_u32m4(w3, 6, vl), __riscv_vsll_vx_u32m4(w4, 2, vl), vl), 0x3FF, vl);

        __riscv_vsse32_v_i32m4(r + 4*i + 0, 16, __riscv_vreinterpret_v_u32m4_i32m4(r0), vl);
        __riscv_vsse32_v_i32m4(r + 4*i + 1, 16, __riscv_vreinterpret_v_u32m4_i32m4(r1), vl);
        __riscv_vsse32_v_i32m4(r + 4*i + 2, 16, __riscv_vreinterpret_v_u32m4_i32m4(r2), vl);
        __riscv_vsse32_v_i32m4(r + 4*i + 3, 16, __riscv_vreinterpret_v_u32m4_i32m4(r3), vl);
        i += vl;
    }
}

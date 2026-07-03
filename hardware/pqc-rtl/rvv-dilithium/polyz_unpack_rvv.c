#include <stdint.h>
#include <riscv_vector.h>

#define GAMMA1 (1 << 19)
#define N 256

/* polyz_unpack GAMMA1=2^19-haaralle (ML-DSA-65): 5 tavua -> 2 kerrointa,
 * 20-bittinen kentta per kerroin. EI hylkaysta - jokainen syote kaytetaan,
 * joten ei compressia tarvita, vain strided-lataus + bittiyhdistely.
 *
 * a[5i+0..4] -> r[2i+0] = a[5i+0] | a[5i+1]<<8 | a[5i+2]<<16, mask 0xFFFFF
 *              r[2i+1] = a[5i+2]>>4 | a[5i+3]<<4 | a[5i+4]<<12
 *              molemmat: r = GAMMA1 - r
 */
void polyz_unpack_rvv(int32_t *r, const uint8_t *a) {
    unsigned int i = 0;
    const unsigned int NHALF = N / 2;  /* 128 paria */

    while (i < NHALF) {
        size_t vl = __riscv_vsetvl_e8m1(NHALF - i);
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

        /* r_even = (w0 | w1<<8 | w2<<16) & 0xFFFFF */
        vuint32m4_t r_even = __riscv_vor_vv_u32m4(
            w0, __riscv_vor_vv_u32m4(__riscv_vsll_vx_u32m4(w1, 8, vl),
                                      __riscv_vsll_vx_u32m4(w2, 16, vl), vl), vl);
        r_even = __riscv_vand_vx_u32m4(r_even, 0xFFFFF, vl);

        /* r_odd = (w2>>4 | w3<<4 | w4<<12) - jo 20 bitissa, ei maskia tarvita */
        vuint32m4_t r_odd = __riscv_vor_vv_u32m4(
            __riscv_vsrl_vx_u32m4(w2, 4, vl),
            __riscv_vor_vv_u32m4(__riscv_vsll_vx_u32m4(w3, 4, vl),
                                  __riscv_vsll_vx_u32m4(w4, 12, vl), vl), vl);

        vint32m4_t r_even_s = __riscv_vrsub_vx_i32m4(
            __riscv_vreinterpret_v_u32m4_i32m4(r_even), GAMMA1, vl);
        vint32m4_t r_odd_s = __riscv_vrsub_vx_i32m4(
            __riscv_vreinterpret_v_u32m4_i32m4(r_odd), GAMMA1, vl);

        /* Striidattu talletus lomitukseen: r[2i]=even, r[2i+1]=odd */
        __riscv_vsse32_v_i32m4(r + 2*i + 0, 8, r_even_s, vl);
        __riscv_vsse32_v_i32m4(r + 2*i + 1, 8, r_odd_s, vl);

        i += vl;
    }
}

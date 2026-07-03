#include <stdint.h>
#include <stddef.h>
#include <riscv_vector.h>

#define Q 8380417

/* Vektoroitu rej_uniform. Sama semantiikka kuin pq-crystals/dilithium
 * ref/poly.c:n rej_uniform: lue 3 tavua per ehdokas, ota alimmat 23 bittia,
 * hyvaksy jos < Q, kirjoita hyvaksytyt perakkain ulostuloon.
 *
 * RVV-strategia: kasittele vl ehdokasta kerralla.
 *   b0,b1,b2 = strided-lataukset offseteilla 0,1,2 (stride=3 tavua)
 *   t = b0 | (b1<<8) | (b2<<16), maskattu 0x7FFFFF
 *   mask = (t < Q)
 *   vcompress pakkaa hyvaksytyt t-arvot alkuun
 *   popcount kertoo montako hyvaksyttiin -> kirjoitetaan ulos, edetaan
 *
 * HUOM: tama on YKSI LAPI puskurin lapi (ei referenssin while-uudelleen-
 * taytto-silmukkaa jos ctr<len puskurin lopussa). Jos puskuri ei riita
 * N:n tayttamiseen, palauttaa vajaan maaran - sama kuin referenssin
 * rej_uniform() (ei poly_uniform():n ulompi kierratys).
 */
unsigned int rej_uniform_rvv(int32_t *a, unsigned int len,
                              const uint8_t *buf, unsigned int buflen) {
    unsigned int ctr = 0;
    unsigned int ncand = buflen / 3;  /* taysia 3-tavun ryhmia */
    unsigned int i = 0;

    while (i < ncand && ctr < len) {
        size_t remaining_cand = ncand - i;
        size_t remaining_out = len - ctr;
        size_t vl = __riscv_vsetvl_e8m1(remaining_cand);

        const uint8_t *base = buf + i * 3;
        vuint8m1_t b0 = __riscv_vlse8_v_u8m1(base + 0, 3, vl);
        vuint8m1_t b1 = __riscv_vlse8_v_u8m1(base + 1, 3, vl);
        vuint8m1_t b2 = __riscv_vlse8_v_u8m1(base + 2, 3, vl);

        vuint32m4_t w0 = __riscv_vzext_vf4_u32m4(b0, vl);
        vuint32m4_t w1 = __riscv_vzext_vf4_u32m4(b1, vl);
        vuint32m4_t w2 = __riscv_vzext_vf4_u32m4(b2, vl);

        vuint32m4_t t = __riscv_vor_vv_u32m4(
            w0,
            __riscv_vor_vv_u32m4(
                __riscv_vsll_vx_u32m4(w1, 8, vl),
                __riscv_vsll_vx_u32m4(w2, 16, vl), vl),
            vl);
        t = __riscv_vand_vx_u32m4(t, 0x7FFFFF, vl);

        vbool8_t mask = __riscv_vmsltu_vx_u32m4_b8(t, Q, vl);

        vuint32m4_t compacted = __riscv_vcompress_vm_u32m4(t, mask, vl);
        unsigned long accepted = __riscv_vcpop_m_b8(mask, vl);

        /* Alle jaljella olevan ulostulotilan - jos vektorierassa hyvaksyttiin
         * enemman kuin mahtuu, katkaistaan (harvinaista, len on N=256 ja
         * vl tyypillisesti pieni). Yksinkertaisuuden vuoksi tama versio
         * kasittelee vain tapauksen jossa accepted <= remaining_out; jos ei,
         * ylimenevat jaisivat kirjoittamatta seuraavalla kierroksella koska
         * i kasvaa joka tapauksessa taysilla vl:lla (ehdokkaat eivat toistu). */
        unsigned long to_write = (accepted < remaining_out) ? accepted : remaining_out;

        /* Kirjoita to_write ensimmaista hyvaksyttya arvoa (int32-muunnos) */
        vint32m4_t compacted_signed = __riscv_vreinterpret_v_u32m4_i32m4(compacted);
        size_t wvl = __riscv_vsetvl_e32m4(to_write);
        if (wvl > 0) {
            __riscv_vse32_v_i32m4(&a[ctr], compacted_signed, wvl);
        }
        ctr += (unsigned int)to_write;

        i += vl;
    }

    return ctr;
}

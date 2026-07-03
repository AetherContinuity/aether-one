#include <stdint.h>

#define D 13
#define N 256

/* polyt0_pack/unpack. TAHALLAAN SKALAARINEN, ei RVV.
 *
 * 8 kerrointa pakataan 13 tavuun epasaannollisella bittikuviolla - jokainen
 * kerroin alkaa eri bittikohdasta suhteessa tavurajaan (0, 5, 3, 11, 6, 1,
 * 9, 4, 12, 7, 2, 10, 5 bittia offsetteina), ei kiinteaa "N kerrointa per
 * M tavua tasavalein" -kuviota jota voisi lukea strided-load-tyylilla
 * (toisin kuin polyt1_pack: 4 kerrointa/5 tavua on SAANNOLLINEN 4-vali).
 * Vektorointi tahan vaatisi joko 13 eri strided-kuviota tai bittitason
 * shufflen jota RVV ei tarjoa suoraan - sama harkinta kuin SampleInBall:ssa,
 * pakotettu vektorointi olisi naennaista tyota jolla ei ole selkeaa hyotya. */

void polyt0_pack_rvv(uint8_t *r, const int32_t *a) {
    for (unsigned int i = 0; i < N/8; i++) {
        uint32_t t[8];
        for (int k = 0; k < 8; k++) t[k] = (1 << (D-1)) - a[8*i+k];

        r[13*i+0]  =  t[0];
        r[13*i+1]  =  t[0] >>  8; r[13*i+1] |= t[1] <<  5;
        r[13*i+2]  =  t[1] >>  3;
        r[13*i+3]  =  t[1] >> 11; r[13*i+3] |= t[2] <<  2;
        r[13*i+4]  =  t[2] >>  6; r[13*i+4] |= t[3] <<  7;
        r[13*i+5]  =  t[3] >>  1;
        r[13*i+6]  =  t[3] >>  9; r[13*i+6] |= t[4] <<  4;
        r[13*i+7]  =  t[4] >>  4;
        r[13*i+8]  =  t[4] >> 12; r[13*i+8] |= t[5] <<  1;
        r[13*i+9]  =  t[5] >>  7; r[13*i+9] |= t[6] <<  6;
        r[13*i+10] =  t[6] >>  2;
        r[13*i+11] =  t[6] >> 10; r[13*i+11] |= t[7] << 3;
        r[13*i+12] =  t[7] >>  5;
    }
}

void polyt0_unpack_rvv(int32_t *r, const uint8_t *a) {
    for (unsigned int i = 0; i < N/8; i++) {
        int32_t c[8];
        c[0] = (a[13*i+0]  | ((uint32_t)a[13*i+1]  << 8)) & 0x1FFF;
        c[1] = (a[13*i+1]>>5 | ((uint32_t)a[13*i+2]  << 3) | ((uint32_t)a[13*i+3]<<11)) & 0x1FFF;
        c[2] = (a[13*i+3]>>2 | ((uint32_t)a[13*i+4]  << 6)) & 0x1FFF;
        c[3] = (a[13*i+4]>>7 | ((uint32_t)a[13*i+5]  << 1) | ((uint32_t)a[13*i+6]<<9)) & 0x1FFF;
        c[4] = (a[13*i+6]>>4 | ((uint32_t)a[13*i+7]  << 4) | ((uint32_t)a[13*i+8]<<12)) & 0x1FFF;
        c[5] = (a[13*i+8]>>1 | ((uint32_t)a[13*i+9]  << 7)) & 0x1FFF;
        c[6] = (a[13*i+9]>>6 | ((uint32_t)a[13*i+10] << 2) | ((uint32_t)a[13*i+11]<<10)) & 0x1FFF;
        c[7] = (a[13*i+11]>>3 | ((uint32_t)a[13*i+12] << 5)) & 0x1FFF;
        for (int k = 0; k < 8; k++) r[8*i+k] = (1 << (D-1)) - c[k];
    }
}

#include <stdint.h>
#include "fips202.h"

#define N 256
#define TAU 49
#define CTILDEBYTES 48
#define SHAKE256_RATE 136

/* SampleInBall (poly_challenge). TAHALLAAN SKALAARINEN, ei RVV.
 *
 * Tama on Fisher-Yates-tyyppinen osittainen sekoitus rejektionaytteistyksella:
 * jokainen askel i lukee c[b]:n ja kirjoittaa seka c[b]:hen etta c[i]:hen,
 * jossa b riippuu edellisen askeleen SHAKE-tavuvirran tilasta JA b:n oma
 * hyvaksymisehto (b<=i) riippuu i:sta joka kasvaa joka askel. Kahta
 * peräkkaista askelta ei voi laskea rinnakkain koska askel i+1:n b-arvon
 * hyvaksymisraja (i+1) ja luettava muisti (c[b]) riippuvat askeleen i
 * lopputuloksesta. Tama on sama rakenteellinen este joka tekee Fisher-
 * Yates-sekoituksesta yleisesti ei-vektoroituvan ilman algoritmin
 * vaihtamista johonkin muuhun (esim. Sattolon muunnelmaan liittyvat
 * temput eivat poista rejektion aiheuttamaa muuttuvaa askelmaaraa).
 *
 * Vektorointiyritys tahan olisi teeskentelya - sama virhe jota tama
 * projekti on koko ajan valttanyt (nakoisesti RVV mutta ei oikeasti). */
void sample_in_ball_rvv(int32_t *c, const uint8_t *seed) {
    unsigned int i, b, pos;
    uint64_t signs;
    uint8_t buf[SHAKE256_RATE];
    keccak_state state;

    shake256_init(&state);
    shake256_absorb(&state, seed, CTILDEBYTES);
    shake256_finalize(&state);
    shake256_squeezeblocks(buf, 1, &state);

    signs = 0;
    for (i = 0; i < 8; i++) signs |= (uint64_t)buf[i] << (8 * i);
    pos = 8;

    for (i = 0; i < N; i++) c[i] = 0;
    for (i = N - TAU; i < N; i++) {
        do {
            if (pos >= SHAKE256_RATE) {
                shake256_squeezeblocks(buf, 1, &state);
                pos = 0;
            }
            b = buf[pos++];
        } while (b > i);
        c[i] = c[b];
        c[b] = 1 - 2 * (int32_t)(signs & 1);
        signs >>= 1;
    }
}

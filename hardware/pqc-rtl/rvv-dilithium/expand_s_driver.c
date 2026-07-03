#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "fips202.h"

#define N 256
#define K 6
#define L 5
#define CRHBYTES 64
#define SHAKE256_RATE 136
#define POLY_UNIFORM_ETA_NBLOCKS ((227 + SHAKE256_RATE - 1) / SHAKE256_RATE)

static unsigned int rej_eta_ref(int32_t *a, unsigned int len, const uint8_t *buf, unsigned int buflen) {
    unsigned int ctr=0,pos=0; uint32_t t0,t1;
    while(ctr<len && pos<buflen){t0=buf[pos]&0xF;t1=buf[pos++]>>4;
        if(t0<9)a[ctr++]=4-(int32_t)t0; if(t1<9&&ctr<len)a[ctr++]=4-(int32_t)t1;}
    return ctr;
}

static void poly_uniform_eta_ref(int32_t *a, const uint8_t *seed, uint16_t nonce) {
    uint8_t input[CRHBYTES + 2];
    memcpy(input, seed, CRHBYTES);
    input[CRHBYTES] = nonce & 0xFF;
    input[CRHBYTES+1] = (nonce >> 8) & 0xFF;

    keccak_state state;
    shake256_absorb_once(&state, input, sizeof(input));

    unsigned int buflen = POLY_UNIFORM_ETA_NBLOCKS * SHAKE256_RATE;
    uint8_t buf[POLY_UNIFORM_ETA_NBLOCKS * SHAKE256_RATE];
    shake256_squeezeblocks(buf, POLY_UNIFORM_ETA_NBLOCKS, &state);

    unsigned int ctr = rej_eta_ref(a, N, buf, buflen);
    while (ctr < N) {
        shake256_squeezeblocks(buf, 1, &state);
        ctr += rej_eta_ref(a + ctr, N - ctr, buf, SHAKE256_RATE);
    }
}

int main(void) {
    uint8_t rhoprime[CRHBYTES];
    for (int i = 0; i < CRHBYTES; i++) rhoprime[i] = (uint8_t)(i * 23 + 7);

    int32_t s1[L][N], s2[K][N];
    for (int i = 0; i < L; i++) poly_uniform_eta_ref(s1[i], rhoprime, (uint16_t)i);
    for (int i = 0; i < K; i++) poly_uniform_eta_ref(s2[i], rhoprime, (uint16_t)(L + i));

    FILE *f = fopen("expand_s_golden.txt", "w");
    for (int i = 0; i < L; i++) for (int n = 0; n < N; n++) fprintf(f, "%d\n", s1[i][n]);
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++) fprintf(f, "%d\n", s2[i][n]);
    fclose(f);

    FILE *fr = fopen("expand_s_seed.txt", "w");
    for (int i = 0; i < CRHBYTES; i++) fprintf(fr, "%d\n", rhoprime[i]);
    fclose(fr);

    printf("s1[0][0..4]: %d %d %d %d %d\n", s1[0][0], s1[0][1], s1[0][2], s1[0][3], s1[0][4]);
    printf("s2[5][0..4] (viimeinen): %d %d %d %d %d\n", s2[5][0], s2[5][1], s2[5][2], s2[5][3], s2[5][4]);
    return 0;
}

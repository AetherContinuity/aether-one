#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "fips202.h"

#define N 256
#define CRHBYTES 64
#define SHAKE256_RATE 136
#define POLY_UNIFORM_ETA_NBLOCKS ((227 + SHAKE256_RATE - 1) / SHAKE256_RATE)

static unsigned int rej_eta_ref(int32_t *a, unsigned int len, const uint8_t *buf, unsigned int buflen) {
    unsigned int ctr=0,pos=0; uint32_t t0,t1;
    while(ctr<len && pos<buflen){t0=buf[pos]&0xF;t1=buf[pos++]>>4;
        if(t0<9)a[ctr++]=4-(int32_t)t0; if(t1<9&&ctr<len)a[ctr++]=4-(int32_t)t1;}
    return ctr;
}

int main(void) {
    uint32_t seedval = 56410;  /* tunnettu: pakottaa uudelleentaytto oikealla datalla */
    uint8_t seed[CRHBYTES];
    memset(seed, 0, CRHBYTES);
    memcpy(seed, &seedval, 4);
    uint16_t nonce = 0;

    uint8_t input[CRHBYTES + 2];
    memcpy(input, seed, CRHBYTES);
    input[CRHBYTES] = nonce & 0xFF;
    input[CRHBYTES+1] = (nonce >> 8) & 0xFF;

    keccak_state state;
    shake256_absorb_once(&state, input, sizeof(input));

    unsigned int buflen = POLY_UNIFORM_ETA_NBLOCKS * SHAKE256_RATE;
    uint8_t buf[POLY_UNIFORM_ETA_NBLOCKS * SHAKE256_RATE];
    shake256_squeezeblocks(buf, POLY_UNIFORM_ETA_NBLOCKS, &state);

    int32_t out[N];
    unsigned int ctr = rej_eta_ref(out, N, buf, buflen);
    printf("Ensimmaisen eran jalkeen: ctr=%u\n", ctr);

    while (ctr < N) {
        shake256_squeezeblocks(buf, 1, &state);
        ctr += rej_eta_ref(out + ctr, N - ctr, buf, SHAKE256_RATE);
        printf("Uudelleentaytto: ctr=%u\n", ctr);
    }

    FILE *f = fopen("poly_eta_golden.txt", "w");
    for (int i = 0; i < N; i++) fprintf(f, "%d\n", out[i]);
    fclose(f);
    FILE *fs = fopen("poly_eta_seed.txt", "w");
    for (int i = 0; i < CRHBYTES; i++) fprintf(fs, "%d\n", seed[i]);
    fclose(fs);

    printf("Lopullinen ctr=%u\n", ctr);
    return 0;
}

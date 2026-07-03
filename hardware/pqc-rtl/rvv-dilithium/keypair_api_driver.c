#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define DILITHIUM_MODE 3
#include "params.h"
#include "poly.h"
#include "polyvec.h"
#include "packing.h"
#include "fips202.h"

int main(void) {
    uint8_t seedbuf[2*SEEDBYTES + CRHBYTES];
    uint8_t tr[TRBYTES];
    const uint8_t *rho, *rhoprime, *key;
    polyvecl mat[K];
    polyvecl s1, s1hat;
    polyveck s2, t1, t0;

    uint8_t random_seed[SEEDBYTES];
    for (int i = 0; i < SEEDBYTES; i++) random_seed[i] = (uint8_t)(i*17+9);

    memcpy(seedbuf, random_seed, SEEDBYTES);
    seedbuf[SEEDBYTES+0] = K;
    seedbuf[SEEDBYTES+1] = L;
    shake256(seedbuf, 2*SEEDBYTES + CRHBYTES, seedbuf, SEEDBYTES+2);
    rho = seedbuf;
    rhoprime = rho + SEEDBYTES;
    key = rhoprime + CRHBYTES;

    polyvec_matrix_expand(mat, rho);
    polyvecl_uniform_eta(&s1, rhoprime, 0);
    polyveck_uniform_eta(&s2, rhoprime, L);

    s1hat = s1;
    polyvecl_ntt(&s1hat);
    polyvec_matrix_pointwise_montgomery(&t1, mat, &s1hat);
    polyveck_reduce(&t1);
    polyveck_invntt_tomont(&t1);
    polyveck_add(&t1, &t1, &s2);
    polyveck_caddq(&t1);
    polyveck_power2round(&t1, &t0, &t1);

    uint8_t pk[CRYPTO_PUBLICKEYBYTES];
    pack_pk(pk, rho, &t1);

    shake256(tr, TRBYTES, pk, CRYPTO_PUBLICKEYBYTES);

    uint8_t sk[CRYPTO_SECRETKEYBYTES];
    pack_sk(sk, rho, tr, key, &t0, &s1, &s2);

    FILE *f = fopen("keypair_seed.txt", "w");
    for (int i = 0; i < SEEDBYTES; i++) fprintf(f, "%d\n", random_seed[i]);
    fclose(f);
    f = fopen("keypair_pk_golden.txt", "w");
    for (int i = 0; i < CRYPTO_PUBLICKEYBYTES; i++) fprintf(f, "%u\n", pk[i]);
    fclose(f);
    f = fopen("keypair_sk_golden.txt", "w");
    for (int i = 0; i < CRYPTO_SECRETKEYBYTES; i++) fprintf(f, "%u\n", sk[i]);
    fclose(f);

    printf("CRYPTO_PUBLICKEYBYTES=%d CRYPTO_SECRETKEYBYTES=%d\n", CRYPTO_PUBLICKEYBYTES, CRYPTO_SECRETKEYBYTES);
    printf("pk[0..4]: %u %u %u %u %u\n", pk[0],pk[1],pk[2],pk[3],pk[4]);
    return 0;
}

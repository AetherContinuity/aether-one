#include <stdint.h>
#include <string.h>

#define K 6
#define N 256
#define SEEDBYTES 32
#define POLYT1_PACKEDBYTES 320
#define CRYPTO_PUBLICKEYBYTES (SEEDBYTES + K*POLYT1_PACKEDBYTES)

extern void polyt1_pack_rvv(uint8_t *r, const int32_t *a);
extern void polyt1_unpack_rvv(int32_t *r, const uint8_t *a);

/* pack_pk: pk = rho || t1[0] || t1[1] || ... || t1[K-1] */
void pack_pk_rvv(uint8_t pk[CRYPTO_PUBLICKEYBYTES], uint8_t rho[SEEDBYTES], int32_t t1[K][N]) {
    memcpy(pk, rho, SEEDBYTES);
    for (unsigned int i = 0; i < K; i++)
        polyt1_pack_rvv(pk + SEEDBYTES + i * POLYT1_PACKEDBYTES, t1[i]);
}

void unpack_pk_rvv(uint8_t rho[SEEDBYTES], int32_t t1[K][N], const uint8_t pk[CRYPTO_PUBLICKEYBYTES]) {
    memcpy(rho, pk, SEEDBYTES);
    for (unsigned int i = 0; i < K; i++)
        polyt1_unpack_rvv(t1[i], pk + SEEDBYTES + i * POLYT1_PACKEDBYTES);
}

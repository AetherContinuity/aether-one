#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define K 6
#define N 256
#define SEEDBYTES 32
#define POLYT1_PACKEDBYTES 320
#define CRYPTO_PUBLICKEYBYTES (SEEDBYTES + K*POLYT1_PACKEDBYTES)

extern void pack_pk_rvv(uint8_t*, uint8_t*, int32_t[K][N]);
extern void unpack_pk_rvv(uint8_t*, int32_t[K][N], const uint8_t*);

int main(void) {
    uint8_t rho[SEEDBYTES];
    for (int i = 0; i < SEEDBYTES; i++) rho[i] = (uint8_t)(i*7+3);
    int32_t t1[K][N];
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++) t1[i][n] = (n*i+n) % 1024;

    uint8_t pk[CRYPTO_PUBLICKEYBYTES];
    pack_pk_rvv(pk, rho, t1);

    uint8_t rho2[SEEDBYTES];
    int32_t t1_2[K][N];
    unpack_pk_rvv(rho2, t1_2, pk);

    int errors = 0;
    if (memcmp(rho, rho2, SEEDBYTES) != 0) { errors++; printf("[FAIL] rho ei tasmaa\n"); }
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++)
        if (t1[i][n] != t1_2[i][n]) { errors++; if(errors<=3) printf("[FAIL] t1[%d][%d]\n",i,n); }
    printf("%s (%d virhetta)\n", errors==0?"PASS":"FAIL", errors);
    return errors==0?0:1;
}

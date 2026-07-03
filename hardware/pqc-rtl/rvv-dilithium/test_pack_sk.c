#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define K 6
#define L 5
#define N 256
#define SEEDBYTES 32
#define TRBYTES 64
#define POLYETA_PACKEDBYTES 128
#define POLYT0_PACKEDBYTES 416
#define CRYPTO_SECRETKEYBYTES (2*SEEDBYTES + TRBYTES + L*POLYETA_PACKEDBYTES + K*POLYETA_PACKEDBYTES + K*POLYT0_PACKEDBYTES)

extern void pack_sk_rvv(uint8_t*, uint8_t*, uint8_t*, uint8_t*, int32_t[K][N], int32_t[L][N], int32_t[K][N]);
extern void unpack_sk_rvv(uint8_t*, uint8_t*, uint8_t*, int32_t[K][N], int32_t[L][N], int32_t[K][N], const uint8_t*);

int main(void) {
    uint8_t rho[SEEDBYTES], tr[TRBYTES], key[SEEDBYTES];
    for (int i=0;i<SEEDBYTES;i++) rho[i]=(uint8_t)(i*3+1);
    for (int i=0;i<TRBYTES;i++) tr[i]=(uint8_t)(i*5+2);
    for (int i=0;i<SEEDBYTES;i++) key[i]=(uint8_t)(i*7+3);

    int32_t t0[K][N], s1[L][N], s2[K][N];
    for (int i=0;i<K;i++) for (int n=0;n<N;n++) t0[i][n] = ((n*13+i)%8191)-4095;
    for (int i=0;i<L;i++) for (int n=0;n<N;n++) s1[i][n] = (n%9)-4;
    for (int i=0;i<K;i++) for (int n=0;n<N;n++) s2[i][n] = ((n*3)%9)-4;

    uint8_t sk[CRYPTO_SECRETKEYBYTES];
    pack_sk_rvv(sk, rho, tr, key, t0, s1, s2);

    uint8_t rho2[SEEDBYTES], tr2[TRBYTES], key2[SEEDBYTES];
    int32_t t0_2[K][N], s1_2[L][N], s2_2[K][N];
    unpack_sk_rvv(rho2, tr2, key2, t0_2, s1_2, s2_2, sk);

    int errors = 0;
    if (memcmp(rho,rho2,SEEDBYTES)) { errors++; printf("[FAIL] rho\n"); }
    if (memcmp(tr,tr2,TRBYTES)) { errors++; printf("[FAIL] tr\n"); }
    if (memcmp(key,key2,SEEDBYTES)) { errors++; printf("[FAIL] key\n"); }
    for (int i=0;i<K;i++) for(int n=0;n<N;n++) if(t0[i][n]!=t0_2[i][n]) { errors++; if(errors<=3) printf("[FAIL] t0[%d][%d]\n",i,n); }
    for (int i=0;i<L;i++) for(int n=0;n<N;n++) if(s1[i][n]!=s1_2[i][n]) { errors++; if(errors<=3) printf("[FAIL] s1[%d][%d]\n",i,n); }
    for (int i=0;i<K;i++) for(int n=0;n<N;n++) if(s2[i][n]!=s2_2[i][n]) { errors++; if(errors<=3) printf("[FAIL] s2[%d][%d]\n",i,n); }

    printf("%s (%d virhetta)\n", errors==0?"PASS":"FAIL", errors);
    FILE *fo = fopen("sk_rvv_out.txt", "w"); for (int i=0;i<CRYPTO_SECRETKEYBYTES;i++) fprintf(fo,"%u\n",sk[i]); fclose(fo);
    return errors==0?0:1;
}

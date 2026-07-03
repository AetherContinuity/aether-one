#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define K 6
#define L 5
#define N 256
#define CTILDEBYTES 48
#define POLYZ_PACKEDBYTES 640
#define OMEGA 55
#define CRYPTO_BYTES (CTILDEBYTES + L*POLYZ_PACKEDBYTES + OMEGA + K)

extern void pack_sig_rvv(uint8_t*, uint8_t*, int32_t[L][N], int32_t[K][N]);
extern int unpack_sig_rvv(uint8_t*, int32_t[L][N], int32_t[K][N], const uint8_t*);

int main(void) {
    uint8_t ctilde[CTILDEBYTES];
    FILE *fc = fopen("ver_ctilde.txt","r"); for(int i=0;i<CTILDEBYTES;i++) { int v; fscanf(fc,"%d",&v); ctilde[i]=(uint8_t)v; } fclose(fc);
    static int32_t z[L][N], h[K][N];
    FILE *fz = fopen("sig_z.txt","r"); for(int i=0;i<L;i++)for(int n=0;n<N;n++) fscanf(fz,"%d",&z[i][n]); fclose(fz);
    FILE *fh = fopen("ver_h.txt","r"); for(int i=0;i<K;i++)for(int n=0;n<N;n++) { unsigned v; fscanf(fh,"%u",&v); h[i][n]=v; } fclose(fh);

    static uint8_t expected[CRYPTO_BYTES];
    FILE *fg = fopen("sig_ref_golden.txt","r"); for(int i=0;i<CRYPTO_BYTES;i++) { int v; fscanf(fg,"%d",&v); expected[i]=(uint8_t)v; } fclose(fg);

    static uint8_t sig[CRYPTO_BYTES];
    pack_sig_rvv(sig, ctilde, z, h);

    int e1=0; for(int i=0;i<CRYPTO_BYTES;i++) if(sig[i]!=expected[i]) { e1++; if(e1<=5) printf("[FAIL] sig[%d] got=%u exp=%u\n",i,sig[i],expected[i]); }
    printf("pack_sig vs REFERENSSI: %s (%d/%d)\n", e1==0?"PASS":"FAIL", CRYPTO_BYTES-e1, CRYPTO_BYTES);

    static int32_t z2[L][N], h2[K][N];
    uint8_t ctilde2[CTILDEBYTES];
    int rc = unpack_sig_rvv(ctilde2, z2, h2, expected);
    int e2 = (rc != 0);
    if (memcmp(ctilde,ctilde2,CTILDEBYTES)) e2++;
    for (int i=0;i<L;i++) for(int n=0;n<N;n++) if(z[i][n]!=z2[i][n]) e2++;
    for (int i=0;i<K;i++) for(int n=0;n<N;n++) if(h[i][n]!=h2[i][n]) e2++;
    printf("unpack_sig pyorytys: %s (rc=%d, virheet=%d)\n", e2==0?"PASS":"FAIL", rc, e2);

    printf("%s\n", (e1==0 && e2==0) ? "PASS" : "FAIL");
    return (e1==0 && e2==0) ? 0 : 1;
}

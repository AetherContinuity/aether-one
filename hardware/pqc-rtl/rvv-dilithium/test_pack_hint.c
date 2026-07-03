#include <stdio.h>
#include <stdint.h>
#define K 6
#define N 256
#define OMEGA 55
extern void pack_hint_rvv(uint8_t*, int32_t[K][N]);
extern int unpack_hint_rvv(int32_t[K][N], const uint8_t*);
int main(void) {
    int32_t h[K][N]; uint8_t expected[OMEGA+K];
    FILE *fh = fopen("hint_h.txt","r"); for(int i=0;i<K;i++)for(int j=0;j<N;j++) { int v; fscanf(fh,"%d",&v); h[i][j]=v; } fclose(fh);
    FILE *fg = fopen("hint_packed_golden.txt","r"); for(int i=0;i<OMEGA+K;i++) { int v; fscanf(fg,"%d",&v); expected[i]=(uint8_t)v; } fclose(fg);

    uint8_t packed[OMEGA+K];
    pack_hint_rvv(packed, h);
    int e1=0; for(int i=0;i<OMEGA+K;i++) if(packed[i]!=expected[i]) { e1++; if(e1<=3) printf("[FAIL] pack[%d] got=%u exp=%u\n",i,packed[i],expected[i]); }
    printf("pack: %s (%d/%d)\n", e1==0?"PASS":"FAIL", OMEGA+K-e1, OMEGA+K);

    int32_t h2[K][N];
    int rc = unpack_hint_rvv(h2, expected);
    int e2 = (rc != 0);
    if (e2) printf("[FAIL] unpack rc=%d, odotettu 0\n", rc);
    for (int i=0;i<K;i++) for(int j=0;j<N;j++) if(h[i][j]!=h2[i][j]) { e2++; if(e2<=3) printf("[FAIL] h[%d][%d]\n",i,j); }
    printf("unpack: %s\n", e2==0?"PASS":"FAIL");

    /* Negatiivikontrolli: turmeltu jarjestys (ei nouseva) */
    uint8_t bad[OMEGA+K];
    for (int i=0;i<OMEGA+K;i++) bad[i]=expected[i];
    if (bad[0] < bad[1]) { uint8_t t=bad[0]; bad[0]=bad[1]; bad[1]=t; }  /* riko nouseva jarjestys */
    int32_t h3[K][N];
    int rc_bad = unpack_hint_rvv(h3, bad);
    printf("negatiivikontrolli (turmeltu jarjestys): rc=%d (odotettu 1)\n", rc_bad);

    int ok = (e1==0 && e2==0 && rc_bad==1);
    printf("%s\n", ok?"PASS":"FAIL");
    return ok?0:1;
}

#include <stdio.h>
#include <stdint.h>
extern void polyt0_pack_rvv(uint8_t*, const int32_t*);
extern void polyt0_unpack_rvv(int32_t*, const uint8_t*);
int main(void) {
    int32_t a[256]; uint8_t expected[416];
    FILE *fa = fopen("t0_a.txt","r"); for(int i=0;i<256;i++) fscanf(fa,"%d",&a[i]); fclose(fa);
    FILE *fg = fopen("t0_golden.txt","r"); for(int i=0;i<416;i++) { int v; fscanf(fg,"%d",&v); expected[i]=(uint8_t)v; } fclose(fg);

    uint8_t packed[416];
    polyt0_pack_rvv(packed, a);
    int e1=0; for(int i=0;i<416;i++) if(packed[i]!=expected[i]) { e1++; if(e1<=3) printf("[FAIL] pack[%d] got=%u exp=%u\n",i,packed[i],expected[i]); }
    printf("pack: %s (%d/416)\n", e1==0?"PASS":"FAIL", 416-e1);

    int32_t back[256];
    polyt0_unpack_rvv(back, expected);
    int e2=0; for(int i=0;i<256;i++) if(back[i]!=a[i]) { e2++; if(e2<=3) printf("[FAIL] unpack[%d] got=%d exp=%d\n",i,back[i],a[i]); }
    printf("unpack: %s (%d/256)\n", e2==0?"PASS":"FAIL", 256-e2);
    return (e1==0&&e2==0)?0:1;
}

#include <stdio.h>
#include <stdint.h>
extern void polyt1_pack_rvv(uint8_t*, const int32_t*);
extern void polyt1_unpack_rvv(int32_t*, const uint8_t*);
int main(void) {
    int32_t a[256]; uint8_t expected[320];
    FILE *fa = fopen("t1_a.txt","r"); for(int i=0;i<256;i++) fscanf(fa,"%d",&a[i]); fclose(fa);
    FILE *fg = fopen("t1_packed_golden.txt","r"); for(int i=0;i<320;i++) { int v; fscanf(fg,"%d",&v); expected[i]=(uint8_t)v; } fclose(fg);

    uint8_t packed[320];
    polyt1_pack_rvv(packed, a);
    int e1=0; for(int i=0;i<320;i++) if(packed[i]!=expected[i]) { e1++; if(e1<=3) printf("[FAIL] pack[%d] got=%u exp=%u\n",i,packed[i],expected[i]); }
    printf("pack: %s (%d/320)\n", e1==0?"PASS":"FAIL", 320-e1);

    int32_t back[256];
    polyt1_unpack_rvv(back, expected);
    int e2=0; for(int i=0;i<256;i++) if(back[i]!=a[i]) { e2++; if(e2<=3) printf("[FAIL] unpack[%d] got=%d exp=%d\n",i,back[i],a[i]); }
    printf("unpack: %s (%d/256)\n", e2==0?"PASS":"FAIL", 256-e2);
    return (e1==0&&e2==0)?0:1;
}

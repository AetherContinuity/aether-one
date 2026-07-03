#include <stdio.h>
#include <stdint.h>
extern void polyw1_pack_rvv(uint8_t *r, const int32_t *a);
int main(void) {
    int32_t a[256]; uint8_t expected[128];
    FILE *fa = fopen("w1_a.txt","r"); for(int i=0;i<256;i++) fscanf(fa,"%d",&a[i]); fclose(fa);
    FILE *fg = fopen("w1_golden.txt","r"); for(int i=0;i<128;i++) { int v; fscanf(fg,"%d",&v); expected[i]=(uint8_t)v; } fclose(fg);
    uint8_t r[128];
    polyw1_pack_rvv(r, a);
    int errors=0;
    for (int i=0;i<128;i++) if (r[i]!=expected[i]) { errors++; if(errors<=3) printf("[FAIL] r[%d] got=%u exp=%u\n",i,r[i],expected[i]); }
    printf("%s (%d/128)\n", errors==0?"PASS":"FAIL", 128-errors);
    return errors==0?0:1;
}

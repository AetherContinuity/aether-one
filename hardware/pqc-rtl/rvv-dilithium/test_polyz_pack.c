#include <stdio.h>
#include <stdint.h>
extern void polyz_pack_rvv(uint8_t*, const int32_t*);
extern void polyz_unpack_rvv(int32_t*, const uint8_t*);
int main(void) {
    int32_t a[256]; uint8_t expected[640];
    FILE *fa = fopen("z_pack_a.txt","r"); for(int i=0;i<256;i++) fscanf(fa,"%d",&a[i]); fclose(fa);
    FILE *fg = fopen("z_pack_golden.txt","r"); for(int i=0;i<640;i++) { int v; fscanf(fg,"%d",&v); expected[i]=(uint8_t)v; } fclose(fg);

    uint8_t packed[640];
    polyz_pack_rvv(packed, a);
    int e1=0; for(int i=0;i<640;i++) if(packed[i]!=expected[i]) { e1++; if(e1<=3) printf("[FAIL] pack[%d] got=%u exp=%u\n",i,packed[i],expected[i]); }
    printf("pack: %s (%d/640)\n", e1==0?"PASS":"FAIL", 640-e1);

    /* Ristiinvarmistus: pura JO OLEMASSA OLEVALLA polyz_unpack_rvv:lla */
    int32_t back[256];
    polyz_unpack_rvv(back, packed);
    int e2=0; for(int i=0;i<256;i++) if(back[i]!=a[i]) { e2++; if(e2<=3) printf("[FAIL] roundtrip[%d] got=%d exp=%d\n",i,back[i],a[i]); }
    printf("pack->unpack pyorytys (eri funktio): %s (%d/256)\n", e2==0?"PASS":"FAIL", 256-e2);
    return (e1==0&&e2==0)?0:1;
}

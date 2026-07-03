#include <stdio.h>
#include <stdint.h>
extern void poly_use_hint_rvv(int32_t*, const int32_t*, const uint32_t*);
extern void poly_shiftl_rvv(int32_t*);
int main(void) {
    int32_t a[256], exp_use[256], exp_shl[256]; uint32_t hint[256];
    FILE *f;
    f=fopen("uh_a.txt","r"); for(int i=0;i<256;i++) fscanf(f,"%d",&a[i]); fclose(f);
    f=fopen("uh_hint.txt","r"); for(int i=0;i<256;i++) { unsigned v; fscanf(f,"%u",&v); hint[i]=v; } fclose(f);
    f=fopen("uh_exp.txt","r"); for(int i=0;i<256;i++) fscanf(f,"%d",&exp_use[i]); fclose(f);
    f=fopen("shl_exp.txt","r"); for(int i=0;i<256;i++) fscanf(f,"%d",&exp_shl[i]); fclose(f);

    int32_t out[256]; poly_use_hint_rvv(out, a, hint);
    int e1=0; for(int i=0;i<256;i++) if(out[i]!=exp_use[i]) { e1++; if(e1<=3) printf("[FAIL] use_hint[%d] got=%d exp=%d\n",i,out[i],exp_use[i]); }
    printf("use_hint: %s (%d/256)\n", e1==0?"PASS":"FAIL", 256-e1);

    int32_t a2[256]; for(int i=0;i<256;i++) a2[i]=a[i];
    poly_shiftl_rvv(a2);
    int e2=0; for(int i=0;i<256;i++) if(a2[i]!=exp_shl[i]) { e2++; if(e2<=3) printf("[FAIL] shiftl[%d] got=%d exp=%d\n",i,a2[i],exp_shl[i]); }
    printf("shiftl: %s (%d/256)\n", e2==0?"PASS":"FAIL", 256-e2);
    return (e1==0&&e2==0)?0:1;
}

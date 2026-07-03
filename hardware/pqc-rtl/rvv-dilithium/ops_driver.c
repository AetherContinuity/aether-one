#include <stdio.h>
#include <stdint.h>
#define DILITHIUM_MODE 2
#include "reduce.c"
#include "params.h"

int main(void) {
    int32_t a[256], b[256];
    for (int i = 0; i < 256; i++) {
        a[i] = (i * 777 - 5000) % 8380417;
        b[i] = (i * 333 + 12345) % 8380417;
    }
    int32_t pw[256], add[256], red[256], cad[256], a1[256], a0[256];
    for (int i = 0; i < 256; i++) pw[i] = montgomery_reduce((int64_t)a[i] * b[i]);
    for (int i = 0; i < 256; i++) add[i] = a[i] + b[i];
    for (int i = 0; i < 256; i++) { int32_t t=(a[i]+(1<<22))>>23; red[i]=a[i]-t*Q; }
    for (int i = 0; i < 256; i++) { cad[i]=red[i]; cad[i]+=(cad[i]>>31)&Q; }
    for (int i = 0; i < 256; i++) { int32_t t1=(cad[i]+(1<<(13-1))-1)>>13; a1[i]=t1; a0[i]=cad[i]-(t1<<13); }

    FILE *f;
    f=fopen("ops_a.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",a[i]); fclose(f);
    f=fopen("ops_b.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",b[i]); fclose(f);
    f=fopen("ops_pw.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",pw[i]); fclose(f);
    f=fopen("ops_add.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",add[i]); fclose(f);
    f=fopen("ops_red.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",red[i]); fclose(f);
    f=fopen("ops_cad.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",cad[i]); fclose(f);
    f=fopen("ops_a1.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",a1[i]); fclose(f);
    f=fopen("ops_a0.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",a0[i]); fclose(f);
    printf("golden kirjoitettu\n");
    return 0;
}

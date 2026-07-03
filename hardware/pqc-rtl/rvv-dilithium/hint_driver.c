#include <stdio.h>
#include <stdint.h>
#define Q 8380417
#define GAMMA2 ((Q-1)/32)
#define D 13

static int32_t decompose_ref(int32_t *a0, int32_t a) {
    int32_t a1 = (a + 127) >> 7;
    a1 = (a1*1025 + (1 << 21)) >> 22;
    a1 &= 15;
    *a0 = a - a1*2*GAMMA2;
    *a0 -= (((Q-1)/2 - *a0) >> 31) & Q;
    return a1;
}
static int32_t use_hint_ref(int32_t a, unsigned int hint) {
    int32_t a0, a1 = decompose_ref(&a0, a);
    if (!hint) return a1;
    if (a0 > 0) return (a1+1) & 15;
    return (a1-1) & 15;
}

int main(void) {
    int32_t a[256]; uint32_t hint[256]; int32_t exp_use[256]; int32_t exp_shiftl[256];
    for (int i = 0; i < 256; i++) { a[i] = (int32_t)(((int64_t)i*6959237+555) % Q); hint[i] = (i%3==0)?1:0; }
    for (int i = 0; i < 256; i++) exp_use[i] = use_hint_ref(a[i], hint[i]);
    for (int i = 0; i < 256; i++) exp_shiftl[i] = a[i] << D;

    FILE *f;
    f=fopen("uh_a.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",a[i]); fclose(f);
    f=fopen("uh_hint.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%u\n",hint[i]); fclose(f);
    f=fopen("uh_exp.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",exp_use[i]); fclose(f);
    f=fopen("shl_exp.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",exp_shiftl[i]); fclose(f);
    printf("use_hint[0..4]: %d %d %d %d %d\n", exp_use[0],exp_use[1],exp_use[2],exp_use[3],exp_use[4]);
    return 0;
}

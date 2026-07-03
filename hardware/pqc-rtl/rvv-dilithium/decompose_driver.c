#include <stdio.h>
#include <stdint.h>
#define Q 8380417
#define GAMMA2 ((Q-1)/32)

static int32_t decompose_ref(int32_t *a0, int32_t a) {
    int32_t a1 = (a + 127) >> 7;
    a1 = (a1*1025 + (1 << 21)) >> 22;
    a1 &= 15;
    *a0 = a - a1*2*GAMMA2;
    *a0 -= (((Q-1)/2 - *a0) >> 31) & Q;
    return a1;
}
static unsigned int make_hint_ref(int32_t a0, int32_t a1) {
    if (a0 > GAMMA2 || a0 < -GAMMA2 || (a0 == -GAMMA2 && a1 != 0)) return 1;
    return 0;
}

int main(void) {
    int32_t a[256], a1[256], a0[256];
    unsigned int hint[256];
    for (int i = 0; i < 256; i++) a[i] = (int32_t)(((int64_t)i * 6959237 + 555) % Q);

    for (int i = 0; i < 256; i++) a1[i] = decompose_ref(&a0[i], a[i]);
    for (int i = 0; i < 256; i++) hint[i] = make_hint_ref(a0[i], a1[i]);

    FILE *f;
    f=fopen("dec_a.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",a[i]); fclose(f);
    f=fopen("dec_a1.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",a1[i]); fclose(f);
    f=fopen("dec_a0.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",a0[i]); fclose(f);
    f=fopen("dec_hint.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%u\n",hint[i]); fclose(f);

    int hint_count=0; for(int i=0;i<256;i++) hint_count+=hint[i];
    printf("a1[0..4]: %d %d %d %d %d\n", a1[0],a1[1],a1[2],a1[3],a1[4]);
    printf("hint_count=%d\n", hint_count);
    return 0;
}

#include <stdio.h>
#include <stdint.h>
#define Q 8380417

static int chknorm_ref(const int32_t *a, int32_t B) {
    if (B > (Q-1)/8) return 1;
    for (int i = 0; i < 256; i++) {
        int32_t t = a[i] >> 31;
        t = a[i] - (t & 2*a[i]);
        if (t >= B) return 1;
    }
    return 0;
}

int main(void) {
    /* Testi 1: kaikki alle rajan */
    int32_t a1[256];
    for (int i = 0; i < 256; i++) a1[i] = (i % 200) - 100;  /* [-100,99] */
    printf("testi1 (raja 150): %d (odotettu 0)\n", chknorm_ref(a1, 150));
    printf("testi1 (raja 50): %d (odotettu 1)\n", chknorm_ref(a1, 50));

    /* Testi 2: yksi arvo ylittaa juuri ja juuri */
    int32_t a2[256];
    for (int i = 0; i < 256; i++) a2[i] = 10;
    a2[137] = -200;
    printf("testi2 (raja 199): %d (odotettu 1, negatiivinen ylitys)\n", chknorm_ref(a2, 199));
    printf("testi2 (raja 201): %d (odotettu 0)\n", chknorm_ref(a2, 201));

    FILE *f = fopen("chk_a1.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",a1[i]); fclose(f);
    f = fopen("chk_a2.txt","w"); for(int i=0;i<256;i++) fprintf(f,"%d\n",a2[i]); fclose(f);
    return 0;
}

#include <stdio.h>
#include <stdint.h>

#define N 256
#define CTILDEBYTES 48

extern void sample_in_ball_rvv(int32_t *c, const uint8_t *seed);

int main(void) {
    uint8_t seed[CTILDEBYTES];
    int32_t expected[N];

    FILE *fs = fopen("sib_seed.txt", "r");
    FILE *fg = fopen("sib_golden.txt", "r");
    if (!fs || !fg) { printf("FAIL: tiedostoja ei loydy\n"); return 1; }
    for (int i = 0; i < CTILDEBYTES; i++) { int v; if(fscanf(fs,"%d",&v)!=1) return 1; seed[i]=(uint8_t)v; }
    for (int i = 0; i < N; i++) if(fscanf(fg, "%d", &expected[i]) != 1) return 1;
    fclose(fs); fclose(fg);

    int32_t c[N];
    sample_in_ball_rvv(c, seed);

    int errors = 0;
    for (int i = 0; i < N; i++) if (c[i] != expected[i]) {
        errors++;
        if (errors <= 5) printf("[FAIL] c[%d] got=%d expected=%d\n", i, c[i], expected[i]);
    }
    printf("%s (%d virhetta/256)\n", errors == 0 ? "PASS" : "FAIL", errors);
    return errors == 0 ? 0 : 1;
}

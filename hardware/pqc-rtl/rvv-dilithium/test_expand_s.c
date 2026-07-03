#include <stdio.h>
#include <stdint.h>

#define K 6
#define L 5
#define N 256
#define CRHBYTES 64

extern void expand_s_rvv(int32_t s1[L][N], int32_t s2[K][N], uint8_t seed[CRHBYTES]);

int main(void) {
    FILE *fs = fopen("expand_s_seed.txt", "r");
    FILE *fg = fopen("expand_s_golden.txt", "r");
    if (!fs || !fg) { printf("FAIL: tiedostoja ei loydy\n"); return 1; }

    uint8_t seed[CRHBYTES];
    for (int i = 0; i < CRHBYTES; i++) { int v; if(fscanf(fs, "%d", &v)!=1) return 1; seed[i] = (uint8_t)v; }
    fclose(fs);

    int32_t exp_s1[L][N], exp_s2[K][N];
    for (int i = 0; i < L; i++) for (int n = 0; n < N; n++) if(fscanf(fg, "%d", &exp_s1[i][n])!=1) return 1;
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++) if(fscanf(fg, "%d", &exp_s2[i][n])!=1) return 1;
    fclose(fg);

    static int32_t s1[L][N], s2[K][N];
    expand_s_rvv(s1, s2, seed);

    int errors = 0;
    for (int i = 0; i < L; i++)
        for (int n = 0; n < N; n++)
            if (s1[i][n] != exp_s1[i][n]) {
                errors++;
                if (errors <= 5) printf("[FAIL] s1[%d][%d] got=%d expected=%d\n", i, n, s1[i][n], exp_s1[i][n]);
            }
    for (int i = 0; i < K; i++)
        for (int n = 0; n < N; n++)
            if (s2[i][n] != exp_s2[i][n]) {
                errors++;
                if (errors <= 5) printf("[FAIL] s2[%d][%d] got=%d expected=%d\n", i, n, s2[i][n], exp_s2[i][n]);
            }

    printf("%s (%d virhetta / %d)\n", errors == 0 ? "PASS" : "FAIL", errors, (L+K)*N);
    return errors == 0 ? 0 : 1;
}

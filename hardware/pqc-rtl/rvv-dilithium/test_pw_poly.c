#include <stdio.h>
#include <stdint.h>

#define K 6
#define L 5
#define N 256

extern void polyvecl_pointwise_poly_montgomery_rvv(int32_t r[L][N], const int32_t *a, int32_t v[L][N]);
extern void polyveck_pointwise_poly_montgomery_rvv(int32_t r[K][N], const int32_t *a, int32_t v[K][N]);

static int load(const char *fn, int32_t *arr, int n) {
    FILE *f = fopen(fn, "r");
    if (!f) return 0;
    for (int i = 0; i < n; i++) if (fscanf(f, "%d", &arr[i]) != 1) { fclose(f); return 0; }
    fclose(f);
    return 1;
}

int main(void) {
    static int32_t cp[N], vl[L][N], vk[K][N], exp_rl[L][N], exp_rk[K][N];
    load("pw_cp.txt", cp, N);
    load("pw_vl.txt", (int32_t*)vl, L*N);
    load("pw_vk.txt", (int32_t*)vk, K*N);
    load("pw_rl.txt", (int32_t*)exp_rl, L*N);
    load("pw_rk.txt", (int32_t*)exp_rk, K*N);

    static int32_t rl[L][N], rk[K][N];
    polyvecl_pointwise_poly_montgomery_rvv(rl, cp, vl);
    polyveck_pointwise_poly_montgomery_rvv(rk, cp, vk);

    int errors = 0;
    for (int i = 0; i < L; i++) for (int n = 0; n < N; n++)
        if (rl[i][n] != exp_rl[i][n]) { errors++; if(errors<=3) printf("[FAIL] rl[%d][%d] got=%d exp=%d\n",i,n,rl[i][n],exp_rl[i][n]); }
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++)
        if (rk[i][n] != exp_rk[i][n]) { errors++; if(errors<=3) printf("[FAIL] rk[%d][%d] got=%d exp=%d\n",i,n,rk[i][n],exp_rk[i][n]); }

    printf("%s (%d virhetta / %d)\n", errors==0?"PASS":"FAIL", errors, (L+K)*N);
    return errors==0?0:1;
}

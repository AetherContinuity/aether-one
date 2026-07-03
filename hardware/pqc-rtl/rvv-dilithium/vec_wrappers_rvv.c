#include <stdint.h>

#define K 6
#define L 5
#define N 256

extern int poly_chknorm_rvv(const int32_t *a, int32_t B);
extern void poly_make_hint_rvv(uint32_t *hint, const int32_t *a0, const int32_t *a1);
extern void poly_decompose_rvv(int32_t *a1, int32_t *a0, const int32_t *a);

int polyvecl_chknorm_rvv(int32_t v[L][N], int32_t bound) {
    for (unsigned int i = 0; i < L; i++)
        if (poly_chknorm_rvv(v[i], bound)) return 1;
    return 0;
}

int polyveck_chknorm_rvv(int32_t v[K][N], int32_t bound) {
    for (unsigned int i = 0; i < K; i++)
        if (poly_chknorm_rvv(v[i], bound)) return 1;
    return 0;
}

void polyveck_decompose_rvv(int32_t v1[K][N], int32_t v0[K][N], int32_t v[K][N]) {
    for (unsigned int i = 0; i < K; i++)
        poly_decompose_rvv(v1[i], v0[i], v[i]);
}

/* polyveck_make_hint: palauttaa hintien kokonaismaaran (kuten referenssi) */
unsigned int polyveck_make_hint_rvv(uint32_t h[K][N], int32_t v0[K][N], int32_t v1[K][N]) {
    unsigned int total = 0;
    for (unsigned int i = 0; i < K; i++) {
        poly_make_hint_rvv(h[i], v0[i], v1[i]);
        for (unsigned int n = 0; n < N; n++) total += h[i][n];
    }
    return total;
}

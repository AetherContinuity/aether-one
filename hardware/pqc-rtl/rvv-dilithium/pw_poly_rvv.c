#include <stdint.h>

#define K 6
#define L 5
#define N 256

extern void poly_pointwise_montgomery_rvv(int32_t*, const int32_t*, const int32_t*);

void polyvecl_pointwise_poly_montgomery_rvv(int32_t r[L][N], const int32_t *a, int32_t v[L][N]) {
    for (unsigned int i = 0; i < L; i++)
        poly_pointwise_montgomery_rvv(r[i], a, v[i]);
}

void polyveck_pointwise_poly_montgomery_rvv(int32_t r[K][N], const int32_t *a, int32_t v[K][N]) {
    for (unsigned int i = 0; i < K; i++)
        poly_pointwise_montgomery_rvv(r[i], a, v[i]);
}

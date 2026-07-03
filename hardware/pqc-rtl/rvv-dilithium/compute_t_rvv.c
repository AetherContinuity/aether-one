#include <stdint.h>
#include <string.h>

#define K 6
#define L 5
#define N 256

extern void ntt_rvv(int32_t *a);
extern void invntt_rvv(int32_t *a);
extern void poly_pointwise_montgomery_rvv(int32_t*, const int32_t*, const int32_t*);
extern void poly_add_rvv(int32_t*, const int32_t*, const int32_t*);
extern void poly_reduce32_rvv(int32_t*);
extern void poly_caddq_rvv(int32_t*);
extern void poly_power2round_rvv(int32_t*, int32_t*, const int32_t*);

/* t = As + e, koko ML-DSA-65:n avaingeneroinnin keskeinen laskuaskel.
 * Sama jarjestys kuin ref/sign.c:n crypto_sign_keypair:
 *   s1hat = NTT(s1)                                    [L polynomia]
 *   t1[i] = reduce32(sum_j pointwise_montgomery(mat[i][j], s1hat[j]))  [K polynomia]
 *   t1 = invntt_tomont(t1)
 *   t1 = t1 + s2
 *   t1 = caddq(t1)
 *   (t1_out, t0_out) = power2round(t1)
 */
void compute_t_rvv(int32_t t1_out[K][N], int32_t t0_out[K][N],
                    int32_t mat[K][L][N], int32_t s1[L][N], int32_t s2[K][N]) {
    int32_t s1hat[L][N];
    for (unsigned int i = 0; i < L; i++) {
        memcpy(s1hat[i], s1[i], N * sizeof(int32_t));
        ntt_rvv(s1hat[i]);
    }

    for (unsigned int i = 0; i < K; i++) {
        int32_t acc[N], tmp[N];
        poly_pointwise_montgomery_rvv(acc, mat[i][0], s1hat[0]);
        for (unsigned int j = 1; j < L; j++) {
            poly_pointwise_montgomery_rvv(tmp, mat[i][j], s1hat[j]);
            poly_add_rvv(acc, acc, tmp);
        }
        poly_reduce32_rvv(acc);
        invntt_rvv(acc);
        poly_add_rvv(acc, acc, s2[i]);
        poly_caddq_rvv(acc);
        poly_power2round_rvv(t1_out[i], t0_out[i], acc);
    }
}

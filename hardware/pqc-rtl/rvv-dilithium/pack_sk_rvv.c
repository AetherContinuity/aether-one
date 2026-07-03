#include <stdint.h>
#include <string.h>

#define K 6
#define L 5
#define N 256
#define SEEDBYTES 32
#define TRBYTES 64
#define POLYETA_PACKEDBYTES 128
#define POLYT0_PACKEDBYTES 416
#define CRYPTO_SECRETKEYBYTES (2*SEEDBYTES + TRBYTES + L*POLYETA_PACKEDBYTES + K*POLYETA_PACKEDBYTES + K*POLYT0_PACKEDBYTES)

extern void polyeta_pack_rvv(uint8_t *r, const int32_t *a);
extern void polyeta_unpack_rvv(int32_t *r, const uint8_t *a);
extern void polyt0_pack_rvv(uint8_t *r, const int32_t *a);
extern void polyt0_unpack_rvv(int32_t *r, const uint8_t *a);

/* pack_sk: sk = rho || key || tr || s1 || s2 || t0.
 * HUOM jarjestys: rho,KEY,TR - ei rho,tr,key, vaikka ref/packing.c:n
 * funktioargumenttien nimeamisjarjestys (rho,tr,key) antaisi olettaa
 * toisin. Tarkistettu suoraan funktion RUNGOSTA, ei parametrilistasta. */
void pack_sk_rvv(uint8_t sk[CRYPTO_SECRETKEYBYTES],
                  uint8_t rho[SEEDBYTES], uint8_t tr[TRBYTES], uint8_t key[SEEDBYTES],
                  int32_t t0[K][N], int32_t s1[L][N], int32_t s2[K][N]) {
    uint8_t *p = sk;
    memcpy(p, rho, SEEDBYTES); p += SEEDBYTES;
    memcpy(p, key, SEEDBYTES); p += SEEDBYTES;
    memcpy(p, tr, TRBYTES); p += TRBYTES;
    for (unsigned int i = 0; i < L; i++) { polyeta_pack_rvv(p, s1[i]); p += POLYETA_PACKEDBYTES; }
    for (unsigned int i = 0; i < K; i++) { polyeta_pack_rvv(p, s2[i]); p += POLYETA_PACKEDBYTES; }
    for (unsigned int i = 0; i < K; i++) { polyt0_pack_rvv(p, t0[i]); p += POLYT0_PACKEDBYTES; }
}

void unpack_sk_rvv(uint8_t rho[SEEDBYTES], uint8_t tr[TRBYTES], uint8_t key[SEEDBYTES],
                    int32_t t0[K][N], int32_t s1[L][N], int32_t s2[K][N],
                    const uint8_t sk[CRYPTO_SECRETKEYBYTES]) {
    const uint8_t *p = sk;
    memcpy(rho, p, SEEDBYTES); p += SEEDBYTES;
    memcpy(key, p, SEEDBYTES); p += SEEDBYTES;
    memcpy(tr, p, TRBYTES); p += TRBYTES;
    for (unsigned int i = 0; i < L; i++) { polyeta_unpack_rvv(s1[i], p); p += POLYETA_PACKEDBYTES; }
    for (unsigned int i = 0; i < K; i++) { polyeta_unpack_rvv(s2[i], p); p += POLYETA_PACKEDBYTES; }
    for (unsigned int i = 0; i < K; i++) { polyt0_unpack_rvv(t0[i], p); p += POLYT0_PACKEDBYTES; }
}

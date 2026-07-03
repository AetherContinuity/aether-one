#include <stdint.h>
#include <string.h>

#define K 6
#define L 5
#define N 256
#define CTILDEBYTES 48
#define POLYZ_PACKEDBYTES 640
#define OMEGA 55
#define CRYPTO_BYTES (CTILDEBYTES + L*POLYZ_PACKEDBYTES + OMEGA + K)

extern void polyz_pack_rvv(uint8_t *r, const int32_t *a);
extern void polyz_unpack_rvv(int32_t *r, const uint8_t *a);
extern void pack_hint_rvv(uint8_t sig[OMEGA + K], int32_t h[K][N]);
extern int unpack_hint_rvv(int32_t h[K][N], const uint8_t sig[OMEGA + K]);

/* pack_sig: sig = ctilde || z[0..L-1] || hint(h) */
void pack_sig_rvv(uint8_t sig[CRYPTO_BYTES], uint8_t ctilde[CTILDEBYTES],
                   int32_t z[L][N], int32_t h[K][N]) {
    uint8_t *p = sig;
    memcpy(p, ctilde, CTILDEBYTES); p += CTILDEBYTES;
    for (unsigned int i = 0; i < L; i++) { polyz_pack_rvv(p, z[i]); p += POLYZ_PACKEDBYTES; }
    pack_hint_rvv(p, h);
}

/* Palauttaa 1 jos virheellinen (hint-purun validointi epaonnistui). */
int unpack_sig_rvv(uint8_t ctilde[CTILDEBYTES], int32_t z[L][N], int32_t h[K][N],
                    const uint8_t sig[CRYPTO_BYTES]) {
    const uint8_t *p = sig;
    memcpy(ctilde, p, CTILDEBYTES); p += CTILDEBYTES;
    for (unsigned int i = 0; i < L; i++) { polyz_unpack_rvv(z[i], p); p += POLYZ_PACKEDBYTES; }
    return unpack_hint_rvv(h, p);
}

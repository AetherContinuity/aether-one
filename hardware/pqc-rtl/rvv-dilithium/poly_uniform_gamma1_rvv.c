#include <stdint.h>

#define N 256
#define POLYZ_PACKEDBYTES 640
#define SHAKE256_RATE 136
#define POLY_UNIFORM_GAMMA1_NBLOCKS ((POLYZ_PACKEDBYTES + SHAKE256_RATE - 1) / SHAKE256_RATE)

extern void polyz_unpack_rvv(int32_t *r, const uint8_t *a);

typedef void (*squeeze_fn_t)(uint8_t *out, unsigned int nblocks, void *ctx);

/* poly_uniform_gamma1: EI hylkaysta, EI uudelleentayttoa - yksi squeeze,
 * yksi unpack. Yksinkertaisempi kuin poly_uniform/poly_uniform_eta juuri
 * tasta syysta (deterministinen bittipurku, ei rejektiota). */
void poly_uniform_gamma1_rvv(int32_t *a, squeeze_fn_t squeeze, void *ctx) {
    uint8_t buf[POLY_UNIFORM_GAMMA1_NBLOCKS * SHAKE256_RATE];
    squeeze(buf, POLY_UNIFORM_GAMMA1_NBLOCKS, ctx);
    polyz_unpack_rvv(a, buf);
}

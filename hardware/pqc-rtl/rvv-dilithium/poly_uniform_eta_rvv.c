#include <stdint.h>

#define N 256
#define SHAKE256_RATE 136
#define POLY_UNIFORM_ETA_NBLOCKS ((227 + SHAKE256_RATE - 1) / SHAKE256_RATE)

extern unsigned int rej_eta_rvv(int32_t *a, unsigned int len,
                                 const uint8_t *buf, unsigned int buflen);

typedef void (*squeeze_fn_t)(uint8_t *out, unsigned int nblocks, void *ctx);

/* poly_uniform_eta RVV-rej_eta:lla. Sama rakenne kuin ref/poly.c:n
 * poly_uniform_eta: ensimmainen era POLY_UNIFORM_ETA_NBLOCKS lohkoa,
 * uudelleentaytto YHDELLA lohkolla kerrallaan jos ei riita (HUOM: ei
 * carry-over-tavuja kuten poly_uniform:ssa, koska rej_eta kuluttaa
 * tasan yhden tavun per askel, ei 3:a - ei jakojaannosongelmaa). */
unsigned int poly_uniform_eta_rvv(int32_t *a, squeeze_fn_t squeeze, void *ctx) {
    unsigned int ctr;
    unsigned int buflen = POLY_UNIFORM_ETA_NBLOCKS * SHAKE256_RATE;
    uint8_t buf[POLY_UNIFORM_ETA_NBLOCKS * SHAKE256_RATE];

    squeeze(buf, POLY_UNIFORM_ETA_NBLOCKS, ctx);
    ctr = rej_eta_rvv(a, N, buf, buflen);

    while (ctr < N) {
        squeeze(buf, 1, ctx);
        ctr += rej_eta_rvv(a + ctr, N - ctr, buf, SHAKE256_RATE);
    }
    return ctr;
}

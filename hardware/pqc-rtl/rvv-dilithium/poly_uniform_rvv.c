#include <stdint.h>
#include <string.h>

#define Q 8380417
#define N 256
#define SHAKE128_RATE 168
#define POLY_UNIFORM_NBLOCKS ((768 + SHAKE128_RATE - 1) / SHAKE128_RATE)

extern unsigned int rej_uniform_rvv(int32_t *a, unsigned int len,
                                     const uint8_t *buf, unsigned int buflen);

/* squeeze_fn: sama rajapinta kuin referenssin stream128_squeezeblocks -
 * kutsuja antaa toteutuksen (oikea SHAKE128 tai testigeneraattori). */
typedef void (*squeeze_fn_t)(uint8_t *out, unsigned int nblocks, void *ctx);

/* poly_uniform RVV-rej_uniformilla. Sama rakenne kuin ref/poly.c:n
 * poly_uniform - mukaan lukien uudelleentaytto jos ensimmainen era
 * ei tuota N hyvaksyttya kerrointa. */
unsigned int poly_uniform_rvv(int32_t *a, squeeze_fn_t squeeze, void *ctx) {
    unsigned int i, ctr, off;
    unsigned int buflen = POLY_UNIFORM_NBLOCKS * SHAKE128_RATE;
    uint8_t buf[POLY_UNIFORM_NBLOCKS * SHAKE128_RATE + 2];

    squeeze(buf, POLY_UNIFORM_NBLOCKS, ctx);
    ctr = rej_uniform_rvv(a, N, buf, buflen);

    while (ctr < N) {
        off = buflen % 3;
        for (i = 0; i < off; i++) buf[i] = buf[buflen - off + i];
        squeeze(buf + off, 1, ctx);
        buflen = SHAKE128_RATE + off;
        ctr += rej_uniform_rvv(a + ctr, N - ctr, buf, buflen);
    }
    return ctr;
}

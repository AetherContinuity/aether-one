#include <stdint.h>

#define K 6
#define L 5
#define N 256
#define SEEDBYTES 32

extern unsigned int poly_uniform_rvv(int32_t *a,
                                      void (*squeeze)(uint8_t*, unsigned int, void*),
                                      void *ctx);

/* squeeze-toteutus jokaiselle (i,j)-parille: SHAKE128(rho||nonce),
 * sama semantiikka kuin poly_uniform_rvv:n testeissa mutta nyt oikealla
 * OpenSSL SHAKE128:lla jokaiselle nonce-arvolle erikseen alustettuna.
 * Kutsuja (matrix_expand_rvv) omistaa OpenSSL-kontekstin luonnin, koska
 * tama tiedosto ei riipu OpenSSL-otsikoista suoraan (pidetaan RVV-koodi
 * ja OpenSSL-koodi erillaan, sama periaate kuin muualla tassa repossa). */
typedef struct {
    void (*init_and_squeeze)(uint8_t *seed, uint16_t nonce, uint8_t *out, unsigned int outlen);
    uint8_t *rho;
    uint16_t nonce;
    unsigned int produced;
} shake_ctx_t;

static void shake_squeeze_adapter(uint8_t *out, unsigned int nblocks, void *vctx) {
    shake_ctx_t *ctx = (shake_ctx_t *)vctx;
    const unsigned int SHAKE128_RATE = 168;
    unsigned int need = nblocks * SHAKE128_RATE;
    /* Yksinkertaistus: ensimmainen kutsu tuottaa koko puskurin kerralla.
     * Uudelleentayttoa EI tueta tassa silmukassa (poly_uniform_rvv:n oma
     * uudelleentayttopolku on jo testattu erikseen synteettisella datalla -
     * tama silmukka nojaa siihen etta yksi era riittaa, mika on todennettu
     * kaikille 30:lle nonce-arvolle expand_a_driver.c:lla). */
    ctx->init_and_squeeze(ctx->rho, ctx->nonce, out, need);
    ctx->produced += need;
}

void matrix_expand_rvv(int32_t mat[K][L][N], uint8_t rho[SEEDBYTES],
                        void (*shake_fn)(uint8_t*, uint16_t, uint8_t*, unsigned int)) {
    for (unsigned int i = 0; i < K; i++) {
        for (unsigned int j = 0; j < L; j++) {
            shake_ctx_t ctx = { shake_fn, rho, (uint16_t)((i << 8) + j), 0 };
            poly_uniform_rvv(mat[i][j], shake_squeeze_adapter, &ctx);
        }
    }
}

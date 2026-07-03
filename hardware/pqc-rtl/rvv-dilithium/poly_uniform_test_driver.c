#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define Q 8380417
#define N 256
#define SHAKE128_RATE 168
#define POLY_UNIFORM_NBLOCKS ((768 + SHAKE128_RATE - 1) / SHAKE128_RATE)

static unsigned int rej_uniform_ref(int32_t *a, unsigned int len, const uint8_t *buf, unsigned int buflen) {
    unsigned int ctr = 0, pos = 0; uint32_t t;
    while (ctr < len && pos + 3 <= buflen) {
        t = buf[pos++]; t |= (uint32_t)buf[pos++] << 8; t |= (uint32_t)buf[pos++] << 16;
        t &= 0x7FFFFF;
        if (t < Q) a[ctr++] = t;
    }
    return ctr;
}

/* Keinotekoinen "squeeze": ensimmainen erä = kaikki hylataan (0x7FFFFF > Q
 * joka tripletille), toinen erä = kelvolliset arvot (nollat, aina < Q).
 * Tama PAKOTTAA referenssin while(ctr<N)-uudelleentaytto-haaran, mika ei
 * lauennut yhdellakaan 200000 oikealla SHAKE128-siemenella. */
static int block_num = 0;
static void fake_squeezeblocks(uint8_t *out, unsigned int nblocks) {
    for (unsigned int b = 0; b < nblocks; b++) {
        if (block_num == 0) {
            for (int i = 0; i < SHAKE128_RATE; i++) out[b*SHAKE128_RATE+i] = 0xFF; /* -> aina hylatty */
        } else {
            for (int i = 0; i < SHAKE128_RATE; i++) out[b*SHAKE128_RATE+i] = 0x00; /* -> aina hyvaksytty (t=0) */
        }
        block_num++;
    }
}

/* Poly_uniform, referenssin rakenteen mukainen, mutta keinotekoisella squeezella */
static unsigned int poly_uniform_ref(int32_t *a) {
    unsigned int i, ctr, off;
    unsigned int buflen = POLY_UNIFORM_NBLOCKS * SHAKE128_RATE;
    uint8_t buf[POLY_UNIFORM_NBLOCKS*SHAKE128_RATE + 2];

    fake_squeezeblocks(buf, POLY_UNIFORM_NBLOCKS);
    ctr = rej_uniform_ref(a, N, buf, buflen);
    printf("Ensimmaisen eran jalkeen: ctr=%u (odotettu 0, koska kaikki 0xFF hylataan)\n", ctr);

    while (ctr < N) {
        off = buflen % 3;
        for (i = 0; i < off; i++) buf[i] = buf[buflen - off + i];
        fake_squeezeblocks(buf + off, 1);
        buflen = SHAKE128_RATE + off;
        ctr += rej_uniform_ref(a + ctr, N - ctr, buf, buflen);
        printf("Uudelleentaytto-kierros: ctr=%u\n", ctr);
    }
    return ctr;
}

int main(void) {
    int32_t out[N];
    unsigned int ctr = poly_uniform_ref(out);
    printf("Lopullinen ctr=%u (pitaa olla %d)\n", ctr, N);
    printf("%s\n", ctr == N ? "PASS: uudelleentaytto-polku toimii" : "FAIL");

    FILE *f = fopen("poly_uniform_golden.txt", "w");
    for (int i = 0; i < N; i++) fprintf(f, "%d\n", out[i]);
    fclose(f);
    return ctr == N ? 0 : 1;
}

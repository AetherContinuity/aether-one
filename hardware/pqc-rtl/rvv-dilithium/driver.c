#include <stdio.h>
#include <stdint.h>
#define DILITHIUM_MODE 2
#include "reduce.c"
#include "ntt.c"

int main(void) {
    /* Testi 1: montgomery_reduce yksittaisille arvoille */
    int64_t test_inputs[] = {
        0LL, 1LL, -1LL,
        (int64_t)8380416 * 8380416,
        (int64_t)(-8380416) * 8380416,
        (int64_t)1234567 * 7654321,
        (int64_t)(-1234567) * 7654321
    };
    printf("=== montgomery_reduce ===\n");
    for (size_t i = 0; i < sizeof(test_inputs)/sizeof(test_inputs[0]); i++) {
        int32_t r = montgomery_reduce(test_inputs[i]);
        printf("%lld -> %d\n", (long long)test_inputs[i], r);
    }

    /* Testi 2: taysi NTT kiinnitetylle syotteelle */
    printf("=== ntt (256 kerrointa) ===\n");
    int32_t poly[256];
    for (int i = 0; i < 256; i++) {
        poly[i] = (i * 777 + 42) % 8380417;
        if (i % 7 == 0) poly[i] = -poly[i];
    }
    printf("syote[0..7]: ");
    for (int i = 0; i < 8; i++) printf("%d ", poly[i]);
    printf("\n");

    ntt(poly);

    printf("NTT-tulos[0..7]: ");
    for (int i = 0; i < 8; i++) printf("%d ", poly[i]);
    printf("\n");
    printf("NTT-tulos[248..255]: ");
    for (int i = 248; i < 256; i++) printf("%d ", poly[i]);
    printf("\n");

    /* Tulosta koko 256-vektori tiedostoon myohempaa golden-vertailua varten */
    FILE *f = fopen("ntt_golden.txt", "w");
    for (int i = 0; i < 256; i++) fprintf(f, "%d\n", poly[i]);
    fclose(f);

    FILE *fin = fopen("ntt_input.txt", "w");
    for (int i = 0; i < 256; i++) fprintf(fin, "%d\n", ( (i * 777 + 42) % 8380417 ) * (i % 7 == 0 ? -1 : 1));
    fclose(fin);

    return 0;
}

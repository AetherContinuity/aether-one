#include <stdio.h>
#include <stdint.h>
#define DILITHIUM_MODE 2
#include "reduce.c"
#include "ntt.c"

int main(void) {
    int32_t poly[256];
    for (int i = 0; i < 256; i++) {
        poly[i] = (i * 54321 + 999) % 8380417;
        if (i % 5 == 0) poly[i] = -poly[i];
    }
    FILE *fin = fopen("invntt_input.txt", "w");
    for (int i = 0; i < 256; i++) fprintf(fin, "%d\n", poly[i]);
    fclose(fin);

    invntt_tomont(poly);

    FILE *f = fopen("invntt_golden.txt", "w");
    for (int i = 0; i < 256; i++) fprintf(f, "%d\n", poly[i]);
    fclose(f);
    printf("invntt[0..4]: %d %d %d %d %d\n", poly[0],poly[1],poly[2],poly[3],poly[4]);
    return 0;
}

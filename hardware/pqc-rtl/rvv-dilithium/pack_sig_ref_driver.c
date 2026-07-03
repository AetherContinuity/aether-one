#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define DILITHIUM_MODE 3
#include "params.h"
#include "poly.h"
#include "polyvec.h"
#include "packing.h"

static int load_i32(const char *fn, int32_t *arr, int n) {
    FILE *f = fopen(fn, "r");
    for (int i = 0; i < n; i++) fscanf(f, "%d", &arr[i]);
    fclose(f); return 1;
}
static int load_u32(const char *fn, uint32_t *arr, int n) {
    FILE *f = fopen(fn, "r");
    for (int i = 0; i < n; i++) { unsigned v; fscanf(f, "%u", &v); arr[i]=v; }
    fclose(f); return 1;
}
static int load_u8(const char *fn, uint8_t *arr, int n) {
    FILE *f = fopen(fn, "r");
    for (int i = 0; i < n; i++) { int v; fscanf(f, "%d", &v); arr[i]=(uint8_t)v; }
    fclose(f); return 1;
}

int main(void) {
    uint8_t ctilde[CTILDEBYTES];
    load_u8("ver_ctilde.txt", ctilde, CTILDEBYTES);
    polyvecl z; load_i32("sig_z.txt", (int32_t*)&z, L*N);
    polyveck h; load_u32("ver_h.txt", (uint32_t*)&h, K*N);

    uint8_t sig[CRYPTO_BYTES];
    pack_sig(sig, ctilde, &z, &h);

    FILE *f = fopen("sig_ref_golden.txt", "w");
    for (int i = 0; i < CRYPTO_BYTES; i++) fprintf(f, "%u\n", sig[i]);
    fclose(f);
    printf("CRYPTO_BYTES=%d\n", CRYPTO_BYTES);
    printf("sig[0..4]: %u %u %u %u %u\n", sig[0],sig[1],sig[2],sig[3],sig[4]);
    return 0;
}

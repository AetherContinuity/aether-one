#include <stdio.h>
#include <stdint.h>

extern void dilithium_mont_reduce_rvv(const int64_t *in, int32_t *out, size_t n);

int main(void) {
    int64_t inputs[8] = {
        0LL, 1LL, -1LL,
        70231372333056LL, -70231372333056LL,
        9449772114007LL, -9449772114007LL,
        0LL  /* taytto 8:aan asti (VLEN-testia varten) */
    };
    int32_t expected[8] = {0, -114592, 114592, -114592, 114592, -2579117, 2579117, 0};
    int32_t out[8] = {0};

    dilithium_mont_reduce_rvv(inputs, out, 8);

    int errors = 0;
    for (int i = 0; i < 7; i++) {  /* viimeinen on vain tayte, ei tarkisteta */
        int ok = (out[i] == expected[i]);
        if (!ok) errors++;
        printf("[%s] in=%lld out=%d expected=%d\n", ok ? "OK" : "FAIL",
               (long long)inputs[i], out[i], expected[i]);
    }
    printf("%s: %d/7 oikein\n", errors == 0 ? "PASS" : "FAIL", 7 - errors);
    return errors == 0 ? 0 : 1;
}

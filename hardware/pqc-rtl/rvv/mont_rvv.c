#include <stdio.h>
#include <stdint.h>
#include <riscv_vector.h>
#include "vectors.h"

#define Q 3329
#define QINV 62209u

/* Rinnakkainen Montgomery-reduktio: t = (a + ((a*QINV mod 2^16) * Q)) >> 16, korjaus jos t>=Q */
void mont_reduce_rvv(const uint32_t *in, uint32_t *out, size_t n) {
    size_t i = 0;
    while (i < n) {
        size_t vl = __riscv_vsetvl_e32m1(n - i);
        vuint32m1_t a = __riscv_vle32_v_u32m1(&in[i], vl);
        vuint32m1_t u = __riscv_vand_vx_u32m1(a, 0xFFFF, vl);
        u = __riscv_vmul_vx_u32m1(u, QINV, vl);
        u = __riscv_vand_vx_u32m1(u, 0xFFFF, vl);
        vuint32m1_t uq = __riscv_vmul_vx_u32m1(u, Q, vl);
        vuint32m1_t sum = __riscv_vadd_vv_u32m1(a, uq, vl);
        vuint32m1_t t = __riscv_vsrl_vx_u32m1(sum, 16, vl);
        vbool32_t ge = __riscv_vmsgeu_vx_u32m1_b32(t, Q, vl);
        vuint32m1_t t_corr = __riscv_vsub_vx_u32m1_mu(ge, t, t, Q, vl);
        __riscv_vse32_v_u32m1(&out[i], t_corr, vl);
        i += vl;
    }
}

int main() {
    uint32_t out[8] = {0};
    mont_reduce_rvv(IN_VALS, out, 8);

    int errors = 0;
    for (size_t i = 0; i < 8; i++) {
        int ok = (out[i] == EXPECTED[i]);
        if (!ok) errors++;
        printf("[%s] in=%u out=%u expected=%u\n", ok ? "OK" : "FAIL", IN_VALS[i], out[i], EXPECTED[i]);
    }
    printf("%s: %d/%d oikein\n", errors == 0 ? "PASS" : "FAIL", 8 - errors, 8);
    return errors == 0 ? 0 : 1;
}

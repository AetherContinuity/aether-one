#include <stdint.h>
#include <riscv_vector.h>

#define Q 8380417
#define N 256

/* poly_chknorm RVV:lla. Referenssi tekee varhaisen paluun ensimmaisesta
 * ylityksesta - funktionaalisesti sama tulos saadaan etsimalla suurin
 * itseisarvo koko vektorista (vredmaxu) ja vertaamalla kerran lopussa,
 * koska palautusarvo riippuu vain SITA ONKO ylitysta, ei mista kohtaa. */
int poly_chknorm_rvv(const int32_t *a, int32_t B) {
    if (B > (Q - 1) / 8) return 1;

    uint32_t max_abs = 0;
    unsigned int i = 0;
    while (i < N) {
        size_t vl = __riscv_vsetvl_e32m1(N - i);
        vint32m1_t va = __riscv_vle32_v_i32m1(&a[i], vl);

        /* itseisarvo: t = a - (sign_mask & 2a), sama temppu kuin referenssi */
        vint32m1_t sign = __riscv_vsra_vx_i32m1(va, 31, vl);
        vint32m1_t twice = __riscv_vsll_vx_i32m1(va, 1, vl);
        vint32m1_t masked = __riscv_vand_vv_i32m1(sign, twice, vl);
        vint32m1_t abs_v = __riscv_vsub_vv_i32m1(va, masked, vl);

        vuint32m1_t abs_u = __riscv_vreinterpret_v_i32m1_u32m1(abs_v);
        vuint32m1_t redsum = __riscv_vmv_v_x_u32m1(max_abs, 1);
        vuint32m1_t vmax = __riscv_vredmaxu_vs_u32m1_u32m1(abs_u, redsum, vl);
        max_abs = __riscv_vmv_x_s_u32m1_u32(vmax);

        i += vl;
    }

    return (max_abs >= (uint32_t)B) ? 1 : 0;
}

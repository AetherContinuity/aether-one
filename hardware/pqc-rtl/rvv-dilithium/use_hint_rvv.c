#include <stdint.h>
#include <riscv_vector.h>

#define D 13
#define N 256

/* poly_shiftl: a[i] <<= D, ei redusointia */
void poly_shiftl_rvv(int32_t *a) {
    unsigned int i = 0;
    while (i < N) {
        size_t vl = __riscv_vsetvl_e32m1(N - i);
        vint32m1_t va = __riscv_vle32_v_i32m1(&a[i], vl);
        __riscv_vse32_v_i32m1(&a[i], __riscv_vsll_vx_i32m1(va, D, vl), vl);
        i += vl;
    }
}

extern void poly_decompose_rvv(int32_t *a1, int32_t *a0, const int32_t *a);

/* use_hint: decompose ensin, jos hint=1 korjaa a1:ta +-1 mod 16 a0:n
 * etumerkin mukaan (GAMMA2=(Q-1)/32-haara). */
void poly_use_hint_rvv(int32_t *out_a1, const int32_t *a, const uint32_t *hint) {
    int32_t a1[N], a0[N];
    poly_decompose_rvv(a1, a0, a);

    unsigned int i = 0;
    while (i < N) {
        size_t vl = __riscv_vsetvl_e32m1(N - i);
        vint32m1_t va1 = __riscv_vle32_v_i32m1(&a1[i], vl);
        vint32m1_t va0 = __riscv_vle32_v_i32m1(&a0[i], vl);
        vint32m1_t vhint = __riscv_vreinterpret_v_u32m1_i32m1(
            __riscv_vle32_v_u32m1((const uint32_t*)&hint[i], vl));

        vbool32_t hint_set = __riscv_vmsne_vx_i32m1_b32(vhint, 0, vl);
        vbool32_t a0_pos = __riscv_vmsgt_vx_i32m1_b32(va0, 0, vl);

        vint32m1_t plus1 = __riscv_vand_vx_i32m1(__riscv_vadd_vx_i32m1(va1, 1, vl), 15, vl);
        vint32m1_t minus1 = __riscv_vand_vx_i32m1(__riscv_vsub_vx_i32m1(va1, 1, vl), 15, vl);
        vint32m1_t corrected = __riscv_vmerge_vvm_i32m1(minus1, plus1, a0_pos, vl);

        vint32m1_t result = __riscv_vmerge_vvm_i32m1(va1, corrected, hint_set, vl);
        __riscv_vse32_v_i32m1(&out_a1[i], result, vl);
        i += vl;
    }
}

#include <stdint.h>
#include <riscv_vector.h>

#define Q 8380417
#define QINV 58728449
#define D 13
#define N 256

static inline vint32m1_t montgomery_reduce_vec(vint64m2_t a, size_t vl) {
    vint32m1_t a32 = __riscv_vnsra_wx_i32m1(__riscv_vsll_vx_i64m2(a, 32, vl), 32, vl);
    vint32m1_t t32 = __riscv_vmul_vx_i32m1(a32, (int32_t)QINV, vl);
    vint64m2_t t32_ext = __riscv_vsext_vf2_i64m2(t32, vl);
    vint64m2_t tQ = __riscv_vmul_vx_i64m2(t32_ext, Q, vl);
    vint64m2_t diff = __riscv_vsub_vv_i64m2(a, tQ, vl);
    vint64m2_t shifted = __riscv_vsra_vx_i64m2(diff, 32, vl);
    return __riscv_vnsra_wx_i32m1(shifted, 0, vl);
}

/* c[i] = montgomery_reduce(a[i]*b[i]), pistetulo NTT-domainissa */
void poly_pointwise_montgomery_rvv(int32_t *c, const int32_t *a, const int32_t *b) {
    unsigned int i = 0;
    while (i < N) {
        size_t vl = __riscv_vsetvl_e32m1(N - i);
        vint32m1_t va = __riscv_vle32_v_i32m1(&a[i], vl);
        vint32m1_t vb = __riscv_vle32_v_i32m1(&b[i], vl);
        vint64m2_t prod = __riscv_vwmul_vv_i64m2(va, vb, vl);
        vint32m1_t res = montgomery_reduce_vec(prod, vl);
        __riscv_vse32_v_i32m1(&c[i], res, vl);
        i += vl;
    }
}

/* c[i] = a[i] + b[i], ei redusointia (sama kuin ref/poly.c:n poly_add) */
void poly_add_rvv(int32_t *c, const int32_t *a, const int32_t *b) {
    unsigned int i = 0;
    while (i < N) {
        size_t vl = __riscv_vsetvl_e32m1(N - i);
        vint32m1_t va = __riscv_vle32_v_i32m1(&a[i], vl);
        vint32m1_t vb = __riscv_vle32_v_i32m1(&b[i], vl);
        __riscv_vse32_v_i32m1(&c[i], __riscv_vadd_vv_i32m1(va, vb, vl), vl);
        i += vl;
    }
}

/* reduce32: t=(a+2^22)>>23; return a-t*Q. Tulos valilla (-Q,Q) suunnilleen. */
void poly_reduce32_rvv(int32_t *a) {
    unsigned int i = 0;
    while (i < N) {
        size_t vl = __riscv_vsetvl_e32m1(N - i);
        vint32m1_t va = __riscv_vle32_v_i32m1(&a[i], vl);
        vint32m1_t t = __riscv_vsra_vx_i32m1(__riscv_vadd_vx_i32m1(va, 1 << 22, vl), 23, vl);
        vint32m1_t res = __riscv_vsub_vv_i32m1(va, __riscv_vmul_vx_i32m1(t, Q, vl), vl);
        __riscv_vse32_v_i32m1(&a[i], res, vl);
        i += vl;
    }
}

/* caddq: a += (a>>31)&Q (lisaa Q jos negatiivinen) */
void poly_caddq_rvv(int32_t *a) {
    unsigned int i = 0;
    while (i < N) {
        size_t vl = __riscv_vsetvl_e32m1(N - i);
        vint32m1_t va = __riscv_vle32_v_i32m1(&a[i], vl);
        vint32m1_t mask = __riscv_vsra_vx_i32m1(va, 31, vl);  /* -1 jos neg, 0 jos ei */
        vint32m1_t addend = __riscv_vand_vx_i32m1(mask, Q, vl);
        __riscv_vse32_v_i32m1(&a[i], __riscv_vadd_vv_i32m1(va, addend, vl), vl);
        i += vl;
    }
}

/* power2round: a1=(a+2^(D-1)-1)>>D; a0=a-(a1<<D). Palauttaa a1 t0:aan
 * kirjoitetun a0:n lisaksi (t1 ja t0 molemmat ulos, kuten referenssi). */
void poly_power2round_rvv(int32_t *a1, int32_t *a0, const int32_t *a) {
    unsigned int i = 0;
    const int32_t half = (1 << (D - 1)) - 1;
    while (i < N) {
        size_t vl = __riscv_vsetvl_e32m1(N - i);
        vint32m1_t va = __riscv_vle32_v_i32m1(&a[i], vl);
        vint32m1_t t1 = __riscv_vsra_vx_i32m1(__riscv_vadd_vx_i32m1(va, half, vl), D, vl);
        vint32m1_t t0 = __riscv_vsub_vv_i32m1(va, __riscv_vsll_vx_i32m1(t1, D, vl), vl);
        __riscv_vse32_v_i32m1(&a1[i], t1, vl);
        __riscv_vse32_v_i32m1(&a0[i], t0, vl);
        i += vl;
    }
}

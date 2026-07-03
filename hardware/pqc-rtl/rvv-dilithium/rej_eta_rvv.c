#include <stdint.h>
#include <stddef.h>
#include <riscv_vector.h>

/* rej_eta RVV:lla, ETA=4 (ML-DSA-65). Sama semantiikka kuin
 * pq-crystals/dilithium ref/poly.c:n rej_eta(#elif ETA==4 -haara):
 *   t0 = buf[pos] & 0x0F,  t1 = buf[pos] >> 4
 *   hyvaksy jos t < 9, arvo = 4 - t
 *   JARJESTYS: saman tavun t0 ENNEN t1:aa ulostulossa.
 *
 * STRATEGIA: kasitellaan tavut ja nibblet erikseen (lo=t0, hi=t1),
 * lasketaan arvot ja hyvaksymisliput kummallekin, striidataan ne
 * lomitettuun valipuskuriin (lo[k] paikkaan 2k, hi[k] paikkaan 2k+1)
 * jotta alkuperainen jarjestys sailyy, ja tehdaan YKSI vcompress koko
 * lomitetulle 2*vl-pituiselle valipuskurille. */
unsigned int rej_eta_rvv(int32_t *a, unsigned int len,
                          const uint8_t *buf, unsigned int buflen) {
    unsigned int ctr = 0;
    unsigned int i = 0;

    /* Riittavan suuri stack-puskuri lomitusta varten (vl korkeintaan ~vlmax) */
    int32_t interleaved_val[512];
    int32_t interleaved_flag[512];

    while (i < buflen && ctr < len) {
        size_t remaining = buflen - i;
        size_t vl = __riscv_vsetvl_e8m1(remaining);
        if (vl * 2 > 512) vl = 256;  /* turvaraja valipuskurille */

        vuint8m1_t b = __riscv_vle8_v_u8m1(&buf[i], vl);
        vuint8m1_t lo8 = __riscv_vand_vx_u8m1(b, 0x0F, vl);
        vuint8m1_t hi8 = __riscv_vsrl_vx_u8m1(b, 4, vl);

        vint32m4_t lo = __riscv_vreinterpret_v_u32m4_i32m4(__riscv_vzext_vf4_u32m4(lo8, vl));
        vint32m4_t hi = __riscv_vreinterpret_v_u32m4_i32m4(__riscv_vzext_vf4_u32m4(hi8, vl));

        vint32m4_t lo_val = __riscv_vrsub_vx_i32m4(lo, 4, vl);   /* 4 - lo */
        vint32m4_t hi_val = __riscv_vrsub_vx_i32m4(hi, 4, vl);   /* 4 - hi */

        vbool8_t lo_ok = __riscv_vmsltu_vx_u32m4_b8(__riscv_vreinterpret_v_i32m4_u32m4(lo), 9, vl);
        vbool8_t hi_ok = __riscv_vmsltu_vx_u32m4_b8(__riscv_vreinterpret_v_i32m4_u32m4(hi), 9, vl);

        vint32m4_t lo_flag = __riscv_vmerge_vxm_i32m4(__riscv_vmv_v_x_i32m4(0, vl), 1, lo_ok, vl);
        vint32m4_t hi_flag = __riscv_vmerge_vxm_i32m4(__riscv_vmv_v_x_i32m4(0, vl), 1, hi_ok, vl);

        /* Striidattu tallennus lomitukseen: askel 8 tavua (2 int32:a) */
        __riscv_vsse32_v_i32m4(interleaved_val + 0, 8, lo_val, vl);
        __riscv_vsse32_v_i32m4(interleaved_val + 1, 8, hi_val, vl);
        __riscv_vsse32_v_i32m4(interleaved_flag + 0, 8, lo_flag, vl);
        __riscv_vsse32_v_i32m4(interleaved_flag + 1, 8, hi_flag, vl);

        size_t total = vl * 2;
        size_t j = 0;
        while (j < total && ctr < len) {
            size_t cvl = __riscv_vsetvl_e32m4(total - j);
            vint32m4_t vals = __riscv_vle32_v_i32m4(interleaved_val + j, cvl);
            vint32m4_t flags = __riscv_vle32_v_i32m4(interleaved_flag + j, cvl);
            vbool8_t mask = __riscv_vmsne_vx_i32m4_b8(flags, 0, cvl);

            vint32m4_t compacted = __riscv_vcompress_vm_i32m4(vals, mask, cvl);
            unsigned long accepted = __riscv_vcpop_m_b8(mask, cvl);

            unsigned long remaining_out = len - ctr;
            unsigned long to_write = (accepted < remaining_out) ? accepted : remaining_out;
            if (to_write > 0) {
                size_t wvl = __riscv_vsetvl_e32m4(to_write);
                __riscv_vse32_v_i32m4(&a[ctr], compacted, wvl);
            }
            ctr += (unsigned int)to_write;
            j += cvl;
        }

        i += vl;
    }

    return ctr;
}

#include <stdio.h>
#include <stdint.h>

extern void poly_decompose_rvv(int32_t *a1, int32_t *a0, const int32_t *a);
extern void poly_make_hint_rvv(uint32_t *hint, const int32_t *a0, const int32_t *a1);

static int load_i32(const char *fn, int32_t *arr, int n) {
    FILE *f = fopen(fn, "r");
    if (!f) return 0;
    for (int i = 0; i < n; i++) if (fscanf(f, "%d", &arr[i]) != 1) { fclose(f); return 0; }
    fclose(f);
    return 1;
}

int main(void) {
    int32_t a[256], exp_a1[256], exp_a0[256], exp_hint[256];
    load_i32("dec_a.txt", a, 256);
    load_i32("dec_a1.txt", exp_a1, 256);
    load_i32("dec_a0.txt", exp_a0, 256);
    load_i32("dec_hint.txt", exp_hint, 256);

    int32_t a1[256], a0[256];
    poly_decompose_rvv(a1, a0, a);

    int errors = 0;
    for (int i = 0; i < 256; i++) {
        if (a1[i] != exp_a1[i]) { errors++; if(errors<=3) printf("[FAIL] a1[%d] got=%d exp=%d\n",i,a1[i],exp_a1[i]); }
        if (a0[i] != exp_a0[i]) { errors++; if(errors<=3) printf("[FAIL] a0[%d] got=%d exp=%d\n",i,a0[i],exp_a0[i]); }
    }
    printf("decompose: %s (%d virhetta/512)\n", errors==0?"PASS":"FAIL", errors);

    uint32_t hint[256];
    poly_make_hint_rvv(hint, exp_a0, exp_a1);
    int herr = 0;
    for (int i = 0; i < 256; i++) if ((int32_t)hint[i] != exp_hint[i]) { herr++; if(herr<=3) printf("[FAIL] hint[%d] got=%u exp=%d\n",i,hint[i],exp_hint[i]); }
    printf("make_hint (decompose-data): %s (%d virhetta/256)\n", herr==0?"PASS":"FAIL", herr);

    /* Rajatapaustestit make_hintille erikseen */
    FILE *fe = fopen("hint_edge.txt", "r");
    int32_t e_a0, e_a1; unsigned int e_exp;
    int edge_errors = 0, edge_total = 0;
    while (fscanf(fe, "%d %d %u", &e_a0, &e_a1, &e_exp) == 3) {
        uint32_t got[1]; int32_t a0arr[256]={0}, a1arr[256]={0}; a0arr[0]=e_a0; a1arr[0]=e_a1;
        uint32_t hintarr[256];
        poly_make_hint_rvv(hintarr, a0arr, a1arr);
        edge_total++;
        if (hintarr[0] != e_exp) { edge_errors++; printf("[FAIL] edge a0=%d a1=%d got=%u exp=%u\n", e_a0,e_a1,hintarr[0],e_exp); }
    }
    fclose(fe);
    printf("make_hint (rajatapaukset): %s (%d/%d)\n", edge_errors==0?"PASS":"FAIL", edge_total-edge_errors, edge_total);

    int total_errors = errors + herr + edge_errors;
    printf("%s\n", total_errors==0?"KAIKKI PASS":"FAIL");
    return total_errors==0?0:1;
}

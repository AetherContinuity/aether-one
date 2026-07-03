#include <stdio.h>
#include <stdint.h>

#define K 6
#define L 5
#define N 256

extern void compute_t_rvv(int32_t t1_out[K][N], int32_t t0_out[K][N],
                           int32_t mat[K][L][N], int32_t s1[L][N], int32_t s2[K][N]);

int main(void) {
    static int32_t mat[K][L][N], s1[L][N], s2[K][N];
    static int32_t exp_t1[K][N], exp_t0[K][N];

    FILE *f;
    f = fopen("t_mat.txt", "r");
    for (int i=0;i<K;i++)for(int j=0;j<L;j++)for(int n=0;n<N;n++) if(fscanf(f,"%d",&mat[i][j][n])!=1) return 1;
    fclose(f);
    f = fopen("t_s1.txt", "r");
    for (int j=0;j<L;j++)for(int n=0;n<N;n++) if(fscanf(f,"%d",&s1[j][n])!=1) return 1;
    fclose(f);
    f = fopen("t_s2.txt", "r");
    for (int i=0;i<K;i++)for(int n=0;n<N;n++) if(fscanf(f,"%d",&s2[i][n])!=1) return 1;
    fclose(f);
    f = fopen("t_golden_t1.txt", "r");
    for (int i=0;i<K;i++)for(int n=0;n<N;n++) if(fscanf(f,"%d",&exp_t1[i][n])!=1) return 1;
    fclose(f);
    f = fopen("t_golden_t0.txt", "r");
    for (int i=0;i<K;i++)for(int n=0;n<N;n++) if(fscanf(f,"%d",&exp_t0[i][n])!=1) return 1;
    fclose(f);

    static int32_t t1[K][N], t0[K][N];
    compute_t_rvv(t1, t0, mat, s1, s2);

    int errors = 0;
    for (int i=0;i<K;i++) for (int n=0;n<N;n++) {
        if (t1[i][n] != exp_t1[i][n]) { errors++; if(errors<=5) printf("[FAIL] t1[%d][%d] got=%d exp=%d\n",i,n,t1[i][n],exp_t1[i][n]); }
        if (t0[i][n] != exp_t0[i][n]) { errors++; if(errors<=5) printf("[FAIL] t0[%d][%d] got=%d exp=%d\n",i,n,t0[i][n],exp_t0[i][n]); }
    }
    printf("%s (%d virhetta / %d)\n", errors==0?"PASS":"FAIL", errors, 2*K*N);
    return errors==0?0:1;
}

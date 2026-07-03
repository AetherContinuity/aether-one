#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define DILITHIUM_MODE 3
#include "reduce.c"
#include "ntt.c"

#define K 6
#define L 5
#define D 13

int main(void) {
    static int32_t mat[K][L][N], s1[L][N], s2[K][N];
    for (int i = 0; i < K; i++)
        for (int j = 0; j < L; j++)
            for (int n = 0; n < N; n++)
                mat[i][j][n] = ((i*97 + j*13 + n*7 + 11) % (2*Q)) - Q;
    for (int j = 0; j < L; j++)
        for (int n = 0; n < N; n++)
            s1[j][n] = (n % 9) - 4;  /* eta=4-tyylinen pieni kerroin */
    for (int i = 0; i < K; i++)
        for (int n = 0; n < N; n++)
            s2[i][n] = ((n*3) % 9) - 4;

    FILE *f;
    f=fopen("t_mat.txt","w");
    for(int i=0;i<K;i++)for(int j=0;j<L;j++)for(int n=0;n<N;n++)fprintf(f,"%d\n",mat[i][j][n]);
    fclose(f);
    f=fopen("t_s1.txt","w");
    for(int j=0;j<L;j++)for(int n=0;n<N;n++)fprintf(f,"%d\n",s1[j][n]);
    fclose(f);
    f=fopen("t_s2.txt","w");
    for(int i=0;i<K;i++)for(int n=0;n<N;n++)fprintf(f,"%d\n",s2[i][n]);
    fclose(f);

    static int32_t s1hat[L][N];
    for (int j = 0; j < L; j++) { memcpy(s1hat[j], s1[j], sizeof(s1[j])); ntt(s1hat[j]); }

    static int32_t t1[K][N], t0[K][N];
    for (int i = 0; i < K; i++) {
        int32_t acc[N], tmp[N];
        for (int n = 0; n < N; n++) acc[n] = montgomery_reduce((int64_t)mat[i][0][n]*s1hat[0][n]);
        for (int j = 1; j < L; j++) {
            for (int n = 0; n < N; n++) tmp[n] = montgomery_reduce((int64_t)mat[i][j][n]*s1hat[j][n]);
            for (int n = 0; n < N; n++) acc[n] += tmp[n];
        }
        for (int n = 0; n < N; n++) acc[n] = reduce32(acc[n]);
        invntt_tomont(acc);
        for (int n = 0; n < N; n++) acc[n] += s2[i][n];
        for (int n = 0; n < N; n++) acc[n] = caddq(acc[n]);
        for (int n = 0; n < N; n++) {
            int32_t a1v = (acc[n] + (1<<(D-1)) - 1) >> D;
            t1[i][n] = a1v;
            t0[i][n] = acc[n] - (a1v << D);
        }
    }

    f=fopen("t_golden_t1.txt","w");
    for(int i=0;i<K;i++)for(int n=0;n<N;n++)fprintf(f,"%d\n",t1[i][n]);
    fclose(f);
    f=fopen("t_golden_t0.txt","w");
    for(int i=0;i<K;i++)for(int n=0;n<N;n++)fprintf(f,"%d\n",t0[i][n]);
    fclose(f);

    printf("t1[0][0..4]: %d %d %d %d %d\n", t1[0][0],t1[0][1],t1[0][2],t1[0][3],t1[0][4]);
    printf("t0[5][0..4]: %d %d %d %d %d\n", t0[5][0],t0[5][1],t0[5][2],t0[5][3],t0[5][4]);
    return 0;
}

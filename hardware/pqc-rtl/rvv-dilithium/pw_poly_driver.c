#include <stdio.h>
#include <stdint.h>
#define Q 8380417
#define QINV 58728449
#define K 6
#define L 5
#define N 256

static int32_t montgomery_reduce(int64_t a) {
    int32_t t = (int64_t)(int32_t)a * QINV;
    t = (a - (int64_t)t * Q) >> 32;
    return t;
}

int main(void) {
    int32_t cp[N], v_l[L][N], v_k[K][N];
    for (int n = 0; n < N; n++) cp[n] = ((n * 977 + 3) % (2*Q)) - Q;
    for (int i = 0; i < L; i++) for (int n = 0; n < N; n++) v_l[i][n] = ((n*i*13+7) % (2*Q)) - Q;
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++) v_k[i][n] = ((n*i*17+11) % (2*Q)) - Q;

    int32_t r_l[L][N], r_k[K][N];
    for (int i = 0; i < L; i++) for (int n = 0; n < N; n++) r_l[i][n] = montgomery_reduce((int64_t)cp[n]*v_l[i][n]);
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++) r_k[i][n] = montgomery_reduce((int64_t)cp[n]*v_k[i][n]);

    FILE *f;
    f=fopen("pw_cp.txt","w"); for(int n=0;n<N;n++) fprintf(f,"%d\n",cp[n]); fclose(f);
    f=fopen("pw_vl.txt","w"); for(int i=0;i<L;i++)for(int n=0;n<N;n++) fprintf(f,"%d\n",v_l[i][n]); fclose(f);
    f=fopen("pw_vk.txt","w"); for(int i=0;i<K;i++)for(int n=0;n<N;n++) fprintf(f,"%d\n",v_k[i][n]); fclose(f);
    f=fopen("pw_rl.txt","w"); for(int i=0;i<L;i++)for(int n=0;n<N;n++) fprintf(f,"%d\n",r_l[i][n]); fclose(f);
    f=fopen("pw_rk.txt","w"); for(int i=0;i<K;i++)for(int n=0;n<N;n++) fprintf(f,"%d\n",r_k[i][n]); fclose(f);
    printf("golden kirjoitettu\n");
    return 0;
}

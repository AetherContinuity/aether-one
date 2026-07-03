#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define DILITHIUM_MODE 3
#include "reduce.c"
#include "ntt.c"
#include "fips202.c"

#define K 6
#define L 5
#define D 13
#define SEEDBYTES 32
#define CRHBYTES 64
#define SHAKE128_RATE 168
#define SHAKE256_RATE 136
#define POLY_UNIFORM_NBLOCKS ((768 + SHAKE128_RATE - 1) / SHAKE128_RATE)
#define POLY_UNIFORM_ETA_NBLOCKS ((227 + SHAKE256_RATE - 1) / SHAKE256_RATE)

static unsigned int rej_uniform_ref(int32_t *a, unsigned int len, const uint8_t *buf, unsigned int buflen) {
    unsigned int ctr=0,pos=0; uint32_t t;
    while(ctr<len && pos+3<=buflen){t=buf[pos++];t|=(uint32_t)buf[pos++]<<8;t|=(uint32_t)buf[pos++]<<16;t&=0x7FFFFF;
        if(t<Q)a[ctr++]=t;}
    return ctr;
}
static unsigned int rej_eta_ref(int32_t *a, unsigned int len, const uint8_t *buf, unsigned int buflen) {
    unsigned int ctr=0,pos=0; uint32_t t0,t1;
    while(ctr<len && pos<buflen){t0=buf[pos]&0xF;t1=buf[pos++]>>4;
        if(t0<9)a[ctr++]=4-(int32_t)t0; if(t1<9&&ctr<len)a[ctr++]=4-(int32_t)t1;}
    return ctr;
}
static void poly_uniform_ref(int32_t *a, const uint8_t *seed, uint16_t nonce) {
    unsigned int buflen = POLY_UNIFORM_NBLOCKS*SHAKE128_RATE;
    uint8_t input[SEEDBYTES+2]; memcpy(input,seed,SEEDBYTES);
    input[SEEDBYTES]=nonce&0xFF; input[SEEDBYTES+1]=(nonce>>8)&0xFF;
    keccak_state st; shake128_absorb_once(&st, input, sizeof(input));
    uint8_t buf[POLY_UNIFORM_NBLOCKS*SHAKE128_RATE+2];
    shake128_squeezeblocks(buf, POLY_UNIFORM_NBLOCKS, &st);
    unsigned int ctr = rej_uniform_ref(a, N, buf, buflen);
    while (ctr<N) {
        unsigned int off=buflen%3;
        for(unsigned int i=0;i<off;i++) buf[i]=buf[buflen-off+i];
        shake128_squeezeblocks(buf+off,1,&st);
        buflen=SHAKE128_RATE+off;
        ctr += rej_uniform_ref(a+ctr, N-ctr, buf, buflen);
    }
}
static void poly_uniform_eta_ref(int32_t *a, const uint8_t *seed, uint16_t nonce) {
    uint8_t input[CRHBYTES+2]; memcpy(input,seed,CRHBYTES);
    input[CRHBYTES]=nonce&0xFF; input[CRHBYTES+1]=(nonce>>8)&0xFF;
    keccak_state st; shake256_absorb_once(&st, input, sizeof(input));
    unsigned int buflen=POLY_UNIFORM_ETA_NBLOCKS*SHAKE256_RATE;
    uint8_t buf[POLY_UNIFORM_ETA_NBLOCKS*SHAKE256_RATE];
    shake256_squeezeblocks(buf, POLY_UNIFORM_ETA_NBLOCKS, &st);
    unsigned int ctr = rej_eta_ref(a, N, buf, buflen);
    while (ctr<N) { shake256_squeezeblocks(buf,1,&st); ctr += rej_eta_ref(a+ctr, N-ctr, buf, SHAKE256_RATE); }
}

int main(void) {
    uint8_t rho[SEEDBYTES], rhoprime[CRHBYTES];
    for (int i=0;i<SEEDBYTES;i++) rho[i]=(uint8_t)(i*41+3);
    for (int i=0;i<CRHBYTES;i++) rhoprime[i]=(uint8_t)(i*29+11);

    static int32_t mat[K][L][N], s1[L][N], s2[K][N];
    for (int i=0;i<K;i++) for (int j=0;j<L;j++) poly_uniform_ref(mat[i][j], rho, (uint16_t)((i<<8)+j));
    for (int j=0;j<L;j++) poly_uniform_eta_ref(s1[j], rhoprime, (uint16_t)j);
    for (int i=0;i<K;i++) poly_uniform_eta_ref(s2[i], rhoprime, (uint16_t)(L+i));

    FILE *f;
    f=fopen("real_rho.txt","w"); for(int i=0;i<SEEDBYTES;i++) fprintf(f,"%d\n",rho[i]); fclose(f);
    f=fopen("real_rhoprime.txt","w"); for(int i=0;i<CRHBYTES;i++) fprintf(f,"%d\n",rhoprime[i]); fclose(f);
    f=fopen("real_mat.txt","w");
    for(int i=0;i<K;i++)for(int j=0;j<L;j++)for(int n=0;n<N;n++)fprintf(f,"%d\n",mat[i][j][n]);
    fclose(f);
    f=fopen("real_s1.txt","w"); for(int j=0;j<L;j++)for(int n=0;n<N;n++)fprintf(f,"%d\n",s1[j][n]); fclose(f);
    f=fopen("real_s2.txt","w"); for(int i=0;i<K;i++)for(int n=0;n<N;n++)fprintf(f,"%d\n",s2[i][n]); fclose(f);

    static int32_t s1hat[L][N];
    for (int j=0;j<L;j++) { memcpy(s1hat[j], s1[j], sizeof(s1[j])); ntt(s1hat[j]); }
    static int32_t t1[K][N], t0[K][N];
    for (int i=0;i<K;i++) {
        int32_t acc[N], tmp[N];
        for (int n=0;n<N;n++) acc[n]=montgomery_reduce((int64_t)mat[i][0][n]*s1hat[0][n]);
        for (int j=1;j<L;j++) { for(int n=0;n<N;n++) tmp[n]=montgomery_reduce((int64_t)mat[i][j][n]*s1hat[j][n]);
            for(int n=0;n<N;n++) acc[n]+=tmp[n]; }
        for (int n=0;n<N;n++) acc[n]=reduce32(acc[n]);
        invntt_tomont(acc);
        for (int n=0;n<N;n++) acc[n]+=s2[i][n];
        for (int n=0;n<N;n++) acc[n]=caddq(acc[n]);
        for (int n=0;n<N;n++) { int32_t a1v=(acc[n]+(1<<(D-1))-1)>>D; t1[i][n]=a1v; t0[i][n]=acc[n]-(a1v<<D); }
    }
    f=fopen("real_golden_t1.txt","w"); for(int i=0;i<K;i++)for(int n=0;n<N;n++)fprintf(f,"%d\n",t1[i][n]); fclose(f);
    f=fopen("real_golden_t0.txt","w"); for(int i=0;i<K;i++)for(int n=0;n<N;n++)fprintf(f,"%d\n",t0[i][n]); fclose(f);
    printf("t1[0][0..4]: %d %d %d %d %d\n", t1[0][0],t1[0][1],t1[0][2],t1[0][3],t1[0][4]);
    return 0;
}

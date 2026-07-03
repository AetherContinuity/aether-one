#include <stdio.h>
#include <stdint.h>
#define N 256
#define GAMMA1 (1 << 19)
int main(void) {
    int32_t a[N];
    for (int i = 0; i < N; i++) a[i] = ((i*54321) % (2*GAMMA1)) - GAMMA1 + 1;  /* [-GAMMA1+1, GAMMA1] */
    uint8_t r[N/2*5];
    for (int i = 0; i < N/2; i++) {
        uint32_t t0 = GAMMA1 - a[2*i+0];
        uint32_t t1 = GAMMA1 - a[2*i+1];
        r[5*i+0] = t0; r[5*i+1] = t0>>8; r[5*i+2] = t0>>16; r[5*i+2] |= t1<<4;
        r[5*i+3] = t1>>4; r[5*i+4] = t1>>12;
    }
    int32_t back[N];
    for (int i = 0; i < N/2; i++) {
        uint32_t v0 = r[5*i+0] | ((uint32_t)r[5*i+1]<<8) | ((uint32_t)(r[5*i+2]&0xF)<<16);
        uint32_t v1 = (r[5*i+2]>>4) | ((uint32_t)r[5*i+3]<<4) | ((uint32_t)r[5*i+4]<<12);
        back[2*i+0] = GAMMA1 - v0;
        back[2*i+1] = GAMMA1 - v1;
    }
    for (int i = 0; i < N; i++) if (back[i] != a[i]) { printf("EI KONSISTENTTI i=%d got=%d exp=%d\n",i,back[i],a[i]); return 1; }
    FILE *f = fopen("z_pack_a.txt","w"); for(int i=0;i<N;i++) fprintf(f,"%d\n",a[i]); fclose(f);
    f = fopen("z_pack_golden.txt","w"); for(int i=0;i<N/2*5;i++) fprintf(f,"%u\n",r[i]); fclose(f);
    printf("golden[0..4]: %u %u %u %u %u\n", r[0],r[1],r[2],r[3],r[4]);
    return 0;
}

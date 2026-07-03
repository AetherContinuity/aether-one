#include <stdio.h>
#include <stdint.h>
#define N 256
int main(void) {
    int32_t a[N];
    for (int i = 0; i < N; i++) a[i] = (i * 37) % 1024;  /* 10-bittiset arvot */
    uint8_t r[N/4*5];
    for (int i = 0; i < N/4; i++) {
        r[5*i+0] = (a[4*i+0] >> 0);
        r[5*i+1] = (a[4*i+0] >> 8) | (a[4*i+1] << 2);
        r[5*i+2] = (a[4*i+1] >> 6) | (a[4*i+2] << 4);
        r[5*i+3] = (a[4*i+2] >> 4) | (a[4*i+3] << 6);
        r[5*i+4] = (a[4*i+3] >> 2);
    }
    int32_t back[N];
    for (int i = 0; i < N/4; i++) {
        back[4*i+0] = ((r[5*i+0] >> 0) | ((uint32_t)r[5*i+1] << 8)) & 0x3FF;
        back[4*i+1] = ((r[5*i+1] >> 2) | ((uint32_t)r[5*i+2] << 6)) & 0x3FF;
        back[4*i+2] = ((r[5*i+2] >> 4) | ((uint32_t)r[5*i+3] << 4)) & 0x3FF;
        back[4*i+3] = ((r[5*i+3] >> 6) | ((uint32_t)r[5*i+4] << 2)) & 0x3FF;
    }
    for (int i = 0; i < N; i++) if (back[i] != a[i]) { printf("REFERENSSI EI EDES ITSE KONSISTENTTI i=%d\n", i); return 1; }

    FILE *f = fopen("t1_a.txt","w"); for(int i=0;i<N;i++) fprintf(f,"%d\n",a[i]); fclose(f);
    f = fopen("t1_packed_golden.txt","w"); for(int i=0;i<N/4*5;i++) fprintf(f,"%u\n",r[i]); fclose(f);
    printf("packed[0..4]: %u %u %u %u %u\n", r[0],r[1],r[2],r[3],r[4]);
    return 0;
}

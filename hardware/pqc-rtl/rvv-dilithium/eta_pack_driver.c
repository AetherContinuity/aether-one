#include <stdio.h>
#include <stdint.h>
#define N 256
#define ETA 4
int main(void) {
    int32_t a[N];
    for (int i = 0; i < N; i++) a[i] = (i % 9) - 4;  /* [-4,4] */
    uint8_t r[N/2];
    for (int i = 0; i < N/2; i++) {
        uint8_t t0 = ETA - a[2*i+0];
        uint8_t t1 = ETA - a[2*i+1];
        r[i] = t0 | (t1 << 4);
    }
    int32_t back[N];
    for (int i = 0; i < N/2; i++) {
        back[2*i+0] = r[i] & 0xF;
        back[2*i+1] = r[i] >> 4;
        back[2*i+0] = ETA - back[2*i+0];
        back[2*i+1] = ETA - back[2*i+1];
    }
    for (int i = 0; i < N; i++) if (back[i] != a[i]) { printf("EI KONSISTENTTI i=%d\n", i); return 1; }
    FILE *f = fopen("eta_pack_a.txt","w"); for(int i=0;i<N;i++) fprintf(f,"%d\n",a[i]); fclose(f);
    f = fopen("eta_pack_golden.txt","w"); for(int i=0;i<N/2;i++) fprintf(f,"%u\n",r[i]); fclose(f);
    printf("golden[0..3]: %u %u %u %u\n", r[0],r[1],r[2],r[3]);
    return 0;
}

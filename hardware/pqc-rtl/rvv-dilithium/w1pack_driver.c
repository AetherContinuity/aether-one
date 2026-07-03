#include <stdio.h>
#include <stdint.h>
#define N 256
int main(void) {
    int32_t a[N];
    for (int i = 0; i < N; i++) a[i] = i % 16;  /* kelvolliset 4-bittiset arvot */
    uint8_t r[N/2];
    for (int i = 0; i < N/2; i++) r[i] = a[2*i+0] | (a[2*i+1] << 4);
    FILE *f = fopen("w1_a.txt","w"); for(int i=0;i<N;i++) fprintf(f,"%d\n",a[i]); fclose(f);
    f = fopen("w1_golden.txt","w"); for(int i=0;i<N/2;i++) fprintf(f,"%u\n",r[i]); fclose(f);
    printf("r[0..3]: %u %u %u %u\n", r[0],r[1],r[2],r[3]);
    return 0;
}

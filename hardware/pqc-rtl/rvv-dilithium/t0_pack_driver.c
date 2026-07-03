#include <stdio.h>
#include <stdint.h>
#define N 256
#define D 13
int main(void) {
    int32_t a[N];
    for (int i = 0; i < N; i++) {
        a[i] = ((i * 37) % 8191) - 4095;  /* [-4095, 4095], turvallisesti sisalla ]-4096,4096] */
    }
    uint8_t r[N/8*13];
    for (int i = 0; i < N/8; i++) {
        uint32_t t[8];
        for (int k = 0; k < 8; k++) t[k] = (1 << (D-1)) - a[8*i+k];
        r[13*i+0]  =  t[0];
        r[13*i+1]  =  t[0] >>  8; r[13*i+1] |= t[1] <<  5;
        r[13*i+2]  =  t[1] >>  3;
        r[13*i+3]  =  t[1] >> 11; r[13*i+3] |= t[2] <<  2;
        r[13*i+4]  =  t[2] >>  6; r[13*i+4] |= t[3] <<  7;
        r[13*i+5]  =  t[3] >>  1;
        r[13*i+6]  =  t[3] >>  9; r[13*i+6] |= t[4] <<  4;
        r[13*i+7]  =  t[4] >>  4;
        r[13*i+8]  =  t[4] >> 12; r[13*i+8] |= t[5] <<  1;
        r[13*i+9]  =  t[5] >>  7; r[13*i+9] |= t[6] <<  6;
        r[13*i+10] =  t[6] >>  2;
        r[13*i+11] =  t[6] >> 10; r[13*i+11] |= t[7] << 3;
        r[13*i+12] =  t[7] >>  5;
    }
    int32_t back[N];
    for (int i = 0; i < N/8; i++) {
        back[8*i+0]  = a[13*0]; /* placeholder overwritten below */
    }
    /* Puretaan referenssin mukaisesti tarkistusta varten */
    for (int i = 0; i < N/8; i++) {
        int32_t c[8];
        c[0] = (r[13*i+0] | ((uint32_t)r[13*i+1]<<8)) & 0x1FFF;
        c[1] = (r[13*i+1]>>5 | ((uint32_t)r[13*i+2]<<3) | ((uint32_t)r[13*i+3]<<11)) & 0x1FFF;
        c[2] = (r[13*i+3]>>2 | ((uint32_t)r[13*i+4]<<6)) & 0x1FFF;
        c[3] = (r[13*i+4]>>7 | ((uint32_t)r[13*i+5]<<1) | ((uint32_t)r[13*i+6]<<9)) & 0x1FFF;
        c[4] = (r[13*i+6]>>4 | ((uint32_t)r[13*i+7]<<4) | ((uint32_t)r[13*i+8]<<12)) & 0x1FFF;
        c[5] = (r[13*i+8]>>1 | ((uint32_t)r[13*i+9]<<7)) & 0x1FFF;
        c[6] = (r[13*i+9]>>6 | ((uint32_t)r[13*i+10]<<2) | ((uint32_t)r[13*i+11]<<10)) & 0x1FFF;
        c[7] = (r[13*i+11]>>3 | ((uint32_t)r[13*i+12]<<5)) & 0x1FFF;
        for (int k = 0; k < 8; k++) back[8*i+k] = (1<<(D-1)) - c[k];
    }
    for (int i = 0; i < N; i++) if (back[i] != a[i]) { printf("EI KONSISTENTTI i=%d got=%d exp=%d\n", i, back[i], a[i]); return 1; }

    FILE *f = fopen("t0_a.txt","w"); for(int i=0;i<N;i++) fprintf(f,"%d\n",a[i]); fclose(f);
    f = fopen("t0_golden.txt","w"); for(int i=0;i<N/8*13;i++) fprintf(f,"%u\n",r[i]); fclose(f);
    printf("golden[0..4]: %u %u %u %u %u\n", r[0],r[1],r[2],r[3],r[4]);
    return 0;
}

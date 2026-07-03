#include <stdio.h>
#include <stdint.h>
#define K 6
#define N 256
#define OMEGA 55

static void pack_hint_ref(uint8_t *sig, uint32_t h[K][N]) {
    unsigned int k = 0;
    for (unsigned int i = 0; i < OMEGA+K; i++) sig[i] = 0;
    for (unsigned int i = 0; i < K; i++) {
        for (unsigned int j = 0; j < N; j++)
            if (h[i][j] != 0) sig[k++] = j;
        sig[OMEGA+i] = k;
    }
}
static int unpack_hint_ref(uint32_t h[K][N], const uint8_t *sig) {
    unsigned int k = 0;
    for (unsigned int i = 0; i < K; i++) {
        for (unsigned int j = 0; j < N; j++) h[i][j] = 0;
        if (sig[OMEGA+i] < k || sig[OMEGA+i] > OMEGA) return 1;
        for (unsigned int j = k; j < sig[OMEGA+i]; j++) {
            if (j > k && sig[j] <= sig[j-1]) return 1;
            h[i][sig[j]] = 1;
        }
        k = sig[OMEGA+i];
    }
    for (unsigned int j = k; j < OMEGA; j++) if (sig[j]) return 1;
    return 0;
}

int main(void) {
    uint32_t h[K][N] = {0};
    /* Realistinen jakauma: n. 27 vihjetta yhteensa (kuten aiemmassa sign-testissa) */
    for (int i = 0; i < K; i++)
        for (int j = 0; j < N; j++)
            if ((j*7+i*13) % 57 == 0) h[i][j] = 1;

    int total = 0;
    for (int i=0;i<K;i++) for(int j=0;j<N;j++) total += h[i][j];
    printf("hintien maara: %d (OMEGA=%d)\n", total, OMEGA);
    if (total > OMEGA) { printf("LIIKAA - saadetaan tiheytta\n"); return 1; }

    uint8_t sig[OMEGA+K];
    pack_hint_ref(sig, h);

    uint32_t h2[K][N];
    int rc = unpack_hint_ref(h2, sig);
    printf("unpack rc=%d (odotettu 0)\n", rc);
    for (int i=0;i<K;i++) for(int j=0;j<N;j++) if (h[i][j]!=h2[i][j]) { printf("EI KONSISTENTTI i=%d j=%d\n",i,j); return 1; }

    FILE *f = fopen("hint_h.txt","w"); for(int i=0;i<K;i++)for(int j=0;j<N;j++) fprintf(f,"%u\n",h[i][j]); fclose(f);
    f = fopen("hint_packed_golden.txt","w"); for(int i=0;i<OMEGA+K;i++) fprintf(f,"%u\n",sig[i]); fclose(f);
    printf("packed[0..4]: %u %u %u %u %u, packed[OMEGA..OMEGA+2]: %u %u %u\n",
           sig[0],sig[1],sig[2],sig[3],sig[4], sig[OMEGA],sig[OMEGA+1],sig[OMEGA+2]);
    return 0;
}

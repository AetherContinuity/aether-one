#include <stdint.h>

#define K 6
#define N 256
#define OMEGA 55

/* Hint-vektorin (h) koodaus/purku. TAHALLAAN SKALAARINEN, ei RVV.
 *
 * Koodaus tallentaa vain 1-bittien POSITIOT jokaiselle K:sta polynomista,
 * ei koko 256-bittista karttaa - ulostulon pituus riippuu datasta (0..OMEGA
 * yhteensa). Tama on rakenteellisesti sama este kuin SampleInBall:ssa:
 * peräkkäinen kirjoituskohta (k) riippuu edellisten iteraatioiden
 * lopputuloksesta, ei kiinteaa "N sisaanmenoa -> N/vakio ulostuloa"
 * -kuviota jota voisi vektoroida suoraviivaisesti. Puretaan sama pattern
 * jota RVV:lla ei ole (kompaktointi ilman kiinteaa maaraa on jo katetu
 * rej_uniform/rej_eta:ssa vcompress:lla, mutta tassa MYOS PURKU on
 * sekventiaalinen koska se validoi jarjestyksen - eri tehtava). */

void pack_hint_rvv(uint8_t sig[OMEGA + K], int32_t h[K][N]) {
    unsigned int k = 0;
    for (unsigned int i = 0; i < OMEGA + K; i++) sig[i] = 0;
    for (unsigned int i = 0; i < K; i++) {
        for (unsigned int j = 0; j < N; j++)
            if (h[i][j] != 0) sig[k++] = (uint8_t)j;
        sig[OMEGA + i] = (uint8_t)k;
    }
}

/* Palauttaa 1 jos virheellinen (per referenssi: "strong unforgeability" -
 * tarkistus, jarjestys ja ylimaaraiset indeksit). */
int unpack_hint_rvv(int32_t h[K][N], const uint8_t sig[OMEGA + K]) {
    unsigned int k = 0;
    for (unsigned int i = 0; i < K; i++) {
        for (unsigned int j = 0; j < N; j++) h[i][j] = 0;
        if (sig[OMEGA + i] < k || sig[OMEGA + i] > OMEGA) return 1;
        for (unsigned int j = k; j < sig[OMEGA + i]; j++) {
            if (j > k && sig[j] <= sig[j-1]) return 1;
            h[i][sig[j]] = 1;
        }
        k = sig[OMEGA + i];
    }
    for (unsigned int j = k; j < OMEGA; j++)
        if (sig[j]) return 1;
    return 0;
}

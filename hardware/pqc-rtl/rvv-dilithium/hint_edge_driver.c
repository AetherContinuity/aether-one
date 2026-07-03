#include <stdio.h>
#include <stdint.h>
#define Q 8380417
#define GAMMA2 ((Q-1)/32)

static unsigned int make_hint_ref(int32_t a0, int32_t a1) {
    if (a0 > GAMMA2 || a0 < -GAMMA2 || (a0 == -GAMMA2 && a1 != 0)) return 1;
    return 0;
}

int main(void) {
    struct { int32_t a0, a1; unsigned int expect; } cases[] = {
        { GAMMA2+1, 0, 1 },
        { -GAMMA2-1, 0, 1 },
        { -GAMMA2, 0, 0 },
        { -GAMMA2, 5, 1 },
        { 0, 3, 0 },
        { GAMMA2, 0, 0 },
        { -GAMMA2+1, 0, 0 },
    };
    FILE *f = fopen("hint_edge.txt", "w");
    for (unsigned i = 0; i < sizeof(cases)/sizeof(cases[0]); i++) {
        unsigned int got = make_hint_ref(cases[i].a0, cases[i].a1);
        fprintf(f, "%d %d %u\n", cases[i].a0, cases[i].a1, got);
        printf("a0=%d a1=%d -> %u (odotettu %u) %s\n", cases[i].a0, cases[i].a1, got, cases[i].expect,
               got==cases[i].expect?"OK":"VIRHE REFERENSSISSA ITSESSAAN");
    }
    fclose(f);
    return 0;
}

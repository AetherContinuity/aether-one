#include <stdio.h>
#include <string.h>
#include <openssl/evp.h>

static int check(const char *label, const unsigned char *msg, size_t msglen,
                  size_t outlen, const char *expected_hex) {
    unsigned char out[64];
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_shake128(), NULL);
    EVP_DigestUpdate(ctx, msg, msglen);
    EVP_DigestFinalXOF(ctx, out, outlen);
    EVP_MD_CTX_free(ctx);

    char got_hex[129] = {0};
    for (size_t i = 0; i < outlen; i++) sprintf(got_hex + i*2, "%02x", out[i]);

    int ok = (strcmp(got_hex, expected_hex) == 0);
    printf("[%s] %s: %s\n", ok ? "OK" : "FAIL", label, got_hex);
    return ok;
}

int main(void) {
    int ok = 1;
    ok &= check("empty", (const unsigned char*)"", 0, 32,
        "7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26");
    unsigned char one_byte = 0xCC;
    ok &= check("0xCC", &one_byte, 1, 32,
        "4dd4b0004a7d9e613a0f488b4846f804015f0f8ccdba5f7c16810bbc5a1c6fb2");
    unsigned char seed_nonce[34] = {0};
    seed_nonce[32] = 5; seed_nonce[33] = 0;
    ok &= check("seed+nonce(dilithium-tyyli)", seed_nonce, 34, 16,
        "db14f51dadcb46e204dc4c814ab0e007");

    printf("%s\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}

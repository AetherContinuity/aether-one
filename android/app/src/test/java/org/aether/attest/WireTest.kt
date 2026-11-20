package org.aether.attest

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import java.io.File

/**
 * S1 (docs/VAIHE3-ENNAKKO.md): sovelluksen tavut = todentajan tavut.
 * Kultaiset vektorit: pi2_trust_server/tests/android/app_vectors.py gen.
 * S2: kirjoittaa allekirjoitetut CBOR-paketit build/aether-vectors/, jotka
 * Python (liboqs) verifioi CI:ssä (app_vectors.py check).
 */
class WireTest {
    private val golden: Map<String, String> by lazy {
        javaClass.classLoader!!.getResource("golden.txt")!!.readText().lines().filter { "=" in it }
            .associate { it.substringBefore("=") to it.substringAfter("=") }
    }
    private val deviceId = "0123456789abcdef"
    private val nonce = ByteArray(32) { it.toByte() }
    private val chain = listOf(Wire.unhex("3003020101"), "abc".toByteArray(), ByteArray(200) { it.toByte() })
    private val kSig = Wire.unhex("0102")

    private fun tc02(mode: String, ks: ByteArray?) = Wire.attestationMessage(
        deviceId, Wire.POLICY_ID, nonce, Wire.androidEvidenceHash(mode, chain, ks), ByteArray(0), ByteArray(32))

    @Test fun evidenceHashes() {
        assertEquals(golden["attest_key.evidence_hash"], Wire.hex(Wire.androidEvidenceHash("attest_key", chain, null)))
        assertEquals(golden["signed.evidence_hash"], Wire.hex(Wire.androidEvidenceHash("signed", chain, kSig)))
    }

    @Test fun tc02Messages() {
        assertEquals(golden["attest_key.tc02"], Wire.hex(tc02("attest_key", null)))
        assertEquals(golden["signed.tc02"], Wire.hex(tc02("signed", kSig)))
    }

    @Test fun chainAndKMessage() {
        assertEquals(golden["chain_digest"], Wire.hex(Wire.chainDigest(chain)))
        assertEquals(golden["k_signed_message"], Wire.hex(Wire.kSignedMessage(nonce, chain)))
        assertEquals(golden["device_id_from_spki"], Wire.deviceId("spki-esimerkki".toByteArray()))
    }

    /** Negatiivikontrolli: yksi muutettu syötetavu muuttaa tuloksen. */
    @Test fun oneByteChangesEverything() {
        val n2 = nonce.copyOf().also { it[0] = 1 }
        val m = Wire.attestationMessage(deviceId, Wire.POLICY_ID, n2,
            Wire.androidEvidenceHash("attest_key", chain, null), ByteArray(0), ByteArray(32))
        assertFalse(golden["attest_key.tc02"] == Wire.hex(m))
        val c2 = chain.toMutableList().also { it[2] = it[2].copyOf().apply { this[199] = 0 } }
        assertFalse(golden["chain_digest"] == Wire.hex(Wire.chainDigest(c2)))
    }

    @Test fun cborBasics() {
        assertArrayEquals(Wire.unhex("a2616101616282f643010203"),
            Cbor.encode(linkedMapOf("a" to 1, "b" to listOf(null, byteArrayOf(1, 2, 3)))))
        assertArrayEquals(Wire.unhex("1903e8"), Cbor.encode(1000))
        assertArrayEquals(Wire.unhex("1a000f4240"), Cbor.encode(1000000))
    }

    @Test fun writeSignedBundlesForPython() {
        val dir = File("build/aether-vectors").apply { mkdirs() }
        val mldsa = MlDsa(ByteArray(32) { (it * 7).toByte() })
        File(dir, "mldsa_public.bin").writeBytes(mldsa.publicKey)
        for ((mode, ks) in listOf("attest_key" to null, "signed" to kSig)) {
            val b = BundleBuilder.build(deviceId, nonce, mode, chain, ks, mldsa, 1795200000L)
            File(dir, "bundle_$mode.cbor").writeBytes(b)
        }
        assertEquals(1952, mldsa.publicKey.size)
    }
}

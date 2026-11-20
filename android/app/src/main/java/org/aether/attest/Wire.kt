package org.aether.attest

import java.io.ByteArrayOutputStream
import java.security.MessageDigest

/**
 * Todentajan tavumuodot (pi2_trust_server/core/trustcore/crypto.py, android_verify.py).
 * Lähde on Python; tämä seuraa sitä. Kultaiset vektorit: app/src/test/resources/golden.txt
 * (pi2_trust_server/tests/android/app_vectors.py gen).
 */
object Wire {
    const val POLICY_ID = "trustcore-v0.2"

    fun sha256(vararg parts: ByteArray): ByteArray {
        val md = MessageDigest.getInstance("SHA-256")
        parts.forEach { md.update(it) }
        return md.digest()
    }

    private fun be32(n: Int) = byteArrayOf((n ushr 24).toByte(), (n ushr 16).toByte(), (n ushr 8).toByte(), n.toByte())

    private fun lenPrefixed(md: MessageDigest, v: ByteArray) {
        md.update(be32(v.size)); md.update(v)
    }

    /** crypto.make_attestation_message (TC02). */
    fun attestationMessage(
        deviceId: String, policyId: String, nonce: ByteArray, evidenceHash: ByteArray,
        sensorStateHash: ByteArray, decisionHash: ByteArray,
    ): ByteArray {
        val out = ByteArrayOutputStream()
        out.write("TC02".toByteArray()); out.write(0)
        for (f in listOf(deviceId.toByteArray(Charsets.UTF_8), policyId.toByteArray(Charsets.UTF_8),
                nonce, evidenceHash, sensorStateHash, decisionHash)) {
            out.write(be32(f.size)); out.write(f)
        }
        return out.toByteArray()
    }

    /** crypto.android_evidence_hash */
    fun androidEvidenceHash(mode: String, chain: List<ByteArray>, kSig: ByteArray?): ByteArray {
        val md = MessageDigest.getInstance("SHA-256")
        md.update("TCE1".toByteArray()); md.update(mode.toByteArray(Charsets.UTF_8))
        chain.forEach { lenPrefixed(md, it) }
        lenPrefixed(md, kSig ?: ByteArray(0))
        return md.digest()
    }

    /** android_verify.chain_digest */
    fun chainDigest(chain: List<ByteArray>): ByteArray {
        val md = MessageDigest.getInstance("SHA-256")
        md.update("TCC1".toByteArray())
        chain.forEach { lenPrefixed(md, it) }
        return md.digest()
    }

    /** android_verify.k_signed_message */
    fun kSignedMessage(nonce: ByteArray, chain: List<ByteArray>): ByteArray =
        "TCA1".toByteArray() + nonce + chainDigest(chain)

    /** device_id = SHA-256(K:n SubjectPublicKeyInfo)[:8] heksana (android_verify.build_android_record). */
    fun deviceId(kSpki: ByteArray): String = hex(sha256(kSpki)).substring(0, 16)

    fun hex(b: ByteArray): String = b.joinToString("") { "%02x".format(it) }

    fun unhex(s: String): ByteArray {
        require(s.length % 2 == 0) { "pariton heksapituus" }
        return ByteArray(s.length / 2) { s.substring(2 * it, 2 * it + 2).toInt(16).toByte() }
    }
}

/** Minimaalinen CBOR-kooderi (RFC 8949): map, array, bytes, text, uint, bool, null. */
object Cbor {
    private fun head(out: ByteArrayOutputStream, major: Int, n: Long) {
        val mt = major shl 5
        when {
            n < 24 -> out.write(mt or n.toInt())
            n < 0x100 -> { out.write(mt or 24); out.write(n.toInt()) }
            n < 0x10000 -> { out.write(mt or 25); out.write((n shr 8).toInt()); out.write(n.toInt() and 0xff) }
            n < 0x100000000L -> { out.write(mt or 26); for (s in 24 downTo 0 step 8) out.write(((n shr s) and 0xff).toInt()) }
            else -> { out.write(mt or 27); for (s in 56 downTo 0 step 8) out.write(((n shr s) and 0xff).toInt()) }
        }
    }

    fun encode(v: Any?): ByteArray = ByteArrayOutputStream().also { enc(it, v) }.toByteArray()

    private fun enc(out: ByteArrayOutputStream, v: Any?) {
        when (v) {
            null -> out.write(0xf6)
            is Boolean -> out.write(if (v) 0xf5 else 0xf4)
            is Int -> { require(v >= 0) { "vain ei-negatiiviset" }; head(out, 0, v.toLong()) }
            is Long -> { require(v >= 0) { "vain ei-negatiiviset" }; head(out, 0, v) }
            is ByteArray -> { head(out, 2, v.size.toLong()); out.write(v) }
            is String -> { val b = v.toByteArray(Charsets.UTF_8); head(out, 3, b.size.toLong()); out.write(b) }
            is List<*> -> { head(out, 4, v.size.toLong()); v.forEach { enc(out, it) } }
            is Map<*, *> -> { head(out, 5, v.size.toLong()); v.forEach { (k, x) -> enc(out, k as String); enc(out, x) } }
            else -> throw IllegalArgumentException("CBOR: tukematon tyyppi ${v::class}")
        }
    }
}

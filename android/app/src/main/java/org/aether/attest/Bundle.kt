package org.aether.attest

import org.bouncycastle.pqc.crypto.mldsa.MLDSAParameters
import org.bouncycastle.pqc.crypto.mldsa.MLDSAPrivateKeyParameters
import org.bouncycastle.pqc.crypto.mldsa.MLDSASigner

/**
 * ML-DSA-65 ohjelmistona (BouncyCastle, puhdas FIPS 204, tyhjä konteksti).
 * Avain muodostetaan 32 tavun siemenestä; siemen säilytetään Keystore-AES-kääreessä
 * (Attestor). Allekirjoitetaan SHA-256(viesti), kuten todentajan PQCManager.
 */
class MlDsa(seed: ByteArray) {
    init { require(seed.size == 32) { "siemen 32 tavua" } }
    private val priv = MLDSAPrivateKeyParameters(MLDSAParameters.ml_dsa_65, seed)
    val publicKey: ByteArray get() = priv.publicKey

    fun signDigestOf(msg: ByteArray): ByteArray {
        val s = MLDSASigner()
        s.init(true, priv)
        val d = Wire.sha256(msg)
        s.update(d, 0, d.size)
        return s.generateSignature()
    }

    companion object { const val ALGORITHM = "ML-DSA-65" }
}

/** Todistepaketti v2, Android (verifier.evaluate + android_verify.evaluate_android). */
object BundleBuilder {
    val DECISION_ZERO = ByteArray(32)

    fun build(
        deviceId: String, nonce: ByteArray, mode: String, chain: List<ByteArray>, kSig: ByteArray?,
        mldsa: MlDsa, timestamp: Long,
    ): ByteArray {
        val evHash = Wire.androidEvidenceHash(mode, chain, kSig)
        val msg = Wire.attestationMessage(deviceId, Wire.POLICY_ID, nonce, evHash, ByteArray(0), DECISION_ZERO)
        val android = linkedMapOf<String, Any?>("mode" to mode, "chain" to chain)
        if (kSig != null) android["k_sig"] = kSig
        val bundle = linkedMapOf<String, Any?>(
            "tc_version" to 2,
            "timestamp" to timestamp,
            "device_id" to deviceId,
            "policy_id" to Wire.POLICY_ID,
            "nonce" to nonce,
            "android" to android,
            "pqc" to linkedMapOf("algorithm" to MlDsa.ALGORITHM, "signature" to mldsa.signDigestOf(msg)),
            "sensor_state_hash" to ByteArray(0),
            "decision_hash" to DECISION_ZERO,
        )
        return Cbor.encode(bundle)
    }
}

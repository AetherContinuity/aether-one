package org.aether.attest

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.SecureRandom
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Keystore-puoli (docs/VAIHE3-ENNAKKO.md). Ei laitetunnisteita, ei ID-attestaatiota.
 * Jokainen valinta (tila, StrongBox/TEE, ketjun kokoaminen) kirjataan diag-tietoihin,
 * koska ne ovat vaiheen 3b mittaustuloksia.
 */
class Attestor(private val ctx: Context) {
    private val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private val prefs = ctx.getSharedPreferences("attest", Context.MODE_PRIVATE)
    private val seedFile = File(ctx.filesDir, "mldsa.bin")

    val attestKeySupported: Boolean
        get() = ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_KEYSTORE_APP_ATTEST_KEY)
    private val strongBoxSupported: Boolean
        get() = ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)

    val enrolled: Boolean get() = ks.containsAlias(K) && seedFile.exists() && prefs.getString("mode", null) != null
    val mode: String get() = prefs.getString("mode", "?")!!

    fun diagnostics(): JSONObject = JSONObject().apply {
        put("android_release", Build.VERSION.RELEASE)
        put("sdk_int", Build.VERSION.SDK_INT)
        put("security_patch", Build.VERSION.SECURITY_PATCH)
        put("model", Build.MODEL)
        put("feature_app_attest_key", attestKeySupported)
        put("feature_strongbox", strongBoxSupported)
        put("enrolled_mode", prefs.getString("mode", null))
        put("k_backing", prefs.getString("k_backing", null))
        put("last_chain_len_returned", prefs.getInt("last_chain_len", -1))
        put("last_chain_appended_k", prefs.getBoolean("last_appended", false))
    }

    // --- ML-DSA-siemen Keystore-AES-kääreessä ---------------------------------

    private fun wrapKey(): SecretKey {
        (ks.getKey(WRAP, null) as? SecretKey)?.let { return it }
        val kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        kg.init(KeyGenParameterSpec.Builder(WRAP, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256).build())
        return kg.generateKey()
    }

    private fun storeSeed(seed: ByteArray) {
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, wrapKey())
        seedFile.writeBytes(c.iv + c.doFinal(seed))
    }

    private fun loadMlDsa(): MlDsa {
        val raw = seedFile.readBytes()
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.DECRYPT_MODE, wrapKey(), GCMParameterSpec(128, raw.copyOfRange(0, 12)))
        return MlDsa(c.doFinal(raw.copyOfRange(12, raw.size)))
    }

    // --- rekisteröinti -----------------------------------------------------------

    private fun genEc(alias: String, purposes: Int, challenge: ByteArray, strongBox: Boolean, attestKey: String?) {
        val b = KeyGenParameterSpec.Builder(alias, purposes)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setAttestationChallenge(challenge)
            .setIsStrongBoxBacked(strongBox)
        if (attestKey != null) b.setAttestKeyAlias(attestKey)
        KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore").apply {
            initialize(b.build()); generateKeyPair()
        }
    }

    /** Luo K:n (challenge = rekisteröintinonce) ja ML-DSA-avaimen. Palauttaa vientitiedot. */
    fun enroll(enrollNonce: ByteArray): JSONObject {
        require(enrollNonce.size == 32) { "rekisteröintinonce: 32 tavua (64 heksamerkkiä)" }
        ks.deleteEntry(K)
        val mode = if (attestKeySupported) "attest_key" else "signed"
        val purposes = if (mode == "attest_key") KeyProperties.PURPOSE_ATTEST_KEY else KeyProperties.PURPOSE_SIGN
        var backing = "TEE"
        val notes = JSONArray()
        if (strongBoxSupported) {
            try {
                genEc(K, purposes, enrollNonce, true, null); backing = "STRONGBOX"
            } catch (e: Exception) {
                notes.put("StrongBox epäonnistui: ${e.javaClass.simpleName}: ${e.message}")
                ks.deleteEntry(K)
            }
        }
        if (backing == "TEE") genEc(K, purposes, enrollNonce, false, null)
        val seed = ByteArray(32).also { SecureRandom().nextBytes(it) }
        storeSeed(seed)
        prefs.edit().putString("mode", mode).putString("k_backing", backing).apply()
        val chain = ks.getCertificateChain(K).map { it.encoded }
        return JSONObject().apply {
            put("device_id", Wire.deviceId(ks.getCertificate(K).publicKey.encoded))
            put("mode", mode)
            put("k_chain_hex", JSONArray(chain.map { Wire.hex(it) }))
            put("algorithm", MlDsa.ALGORITHM)
            put("mldsa_public_hex", Wire.hex(MlDsa(seed).publicKey))
            put("mldsa_storage", "ohjelmisto (BouncyCastle; siemen Keystore-AES-GCM-kääreessä)")
            put("diag", diagnostics().put("enroll_notes", notes))
        }
    }

    // --- attestaatio ---------------------------------------------------------------

    class Evidence(val bundle: ByteArray, val deviceId: String)

    /** Tuore avain challengella; tilassa attest_key K allekirjoittaa sen TEE:ssä. */
    fun makeBundle(nonce: ByteArray, deviceIdOverride: String?, corruptChain: Boolean): Evidence {
        check(enrolled) { "laitetta ei ole rekisteröity tässä sovelluksessa" }
        val m = mode
        ks.deleteEntry(FRESH)
        val chain: MutableList<ByteArray>
        try {
            // attest_key: tuoreen avaimen on oltava samassa KeyMint-instanssissa kuin K.
            genEc(FRESH, KeyProperties.PURPOSE_SIGN, nonce, prefs.getString("k_backing", "TEE") == "STRONGBOX",
                if (m == "attest_key") K else null)
            val got = ks.getCertificateChain(FRESH).map { it.encoded }
            chain = got.toMutableList()
            var appended = false
            if (m == "attest_key" && got.size == 1) {
                chain += ks.getCertificateChain(K).map { it.encoded }
                appended = true
            }
            prefs.edit().putInt("last_chain_len", got.size).putBoolean("last_appended", appended).apply()
        } finally {
            ks.deleteEntry(FRESH)
        }
        if (corruptChain && chain.size > 1) {
            val c = chain[1].copyOf(); c[c.size - 5] = (c[c.size - 5].toInt() xor 1).toByte(); chain[1] = c
        }
        var kSig: ByteArray? = null
        if (m == "signed") {
            val s = Signature.getInstance("SHA256withECDSA")
            s.initSign((ks.getEntry(K, null) as KeyStore.PrivateKeyEntry).privateKey)
            s.update(Wire.kSignedMessage(nonce, chain)); kSig = s.sign()
        }
        val did = deviceIdOverride?.takeIf { it.isNotBlank() } ?: Wire.deviceId(ks.getCertificate(K).publicKey.encoded)
        return Evidence(BundleBuilder.build(did, nonce, m, chain, kSig, loadMlDsa(), System.currentTimeMillis() / 1000), did)
    }

    companion object {
        const val K = "tc_k"
        const val FRESH = "tc_fresh"
        const val WRAP = "tc_mldsa_wrap"

        fun getNonce(server: String): ByteArray {
            val c = URL(server.trimEnd('/') + "/nonce").openConnection() as HttpURLConnection
            c.connectTimeout = 8000; c.readTimeout = 8000
            try {
                val body = c.inputStream.bufferedReader().readText()
                return Wire.unhex(JSONObject(body).getString("nonce"))
            } finally { c.disconnect() }
        }

        fun postVerify(server: String, bundle: ByteArray): JSONObject {
            val c = URL(server.trimEnd('/') + "/verify").openConnection() as HttpURLConnection
            c.connectTimeout = 8000; c.readTimeout = 30000
            c.requestMethod = "POST"; c.doOutput = true
            c.setRequestProperty("Content-Type", "application/cbor")
            try {
                c.outputStream.use { it.write(bundle) }
                return JSONObject(c.inputStream.bufferedReader().readText())
            } finally { c.disconnect() }
        }
    }
}

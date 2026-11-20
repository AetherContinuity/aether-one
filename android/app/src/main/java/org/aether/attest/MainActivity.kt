package org.aether.attest

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.json.JSONObject

/**
 * Yksi näkymä. Tulos näytetään väite kerrallaan; yhteistä OK-tilaa ei ole
 * (docs/ATTESTATION-LEVELS.md). Negatiivikontrollit (docs/VAIHE3-ENNAKKO.md 3b)
 * ovat omina painikkeinaan.
 */
class MainActivity : Activity() {
    private lateinit var att: Attestor
    private lateinit var server: EditText
    private lateinit var enrollNonce: EditText
    private lateinit var idOverride: EditText
    private lateinit var out: TextView
    private var lastEnrollment: String? = null
    private var lastBundle: ByteArray? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        att = Attestor(this)
        val prefs = getSharedPreferences("ui", Context.MODE_PRIVATE)
        val col = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(32, 32, 32, 32) }
        fun field(hint: String, value: String?) = EditText(this).apply {
            this.hint = hint; setText(value ?: ""); inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            col.addView(this, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
        }
        fun button(text: String, f: () -> Unit) = col.addView(Button(this).apply { this.text = text; setOnClickListener { f() } })

        server = field("Todentajan osoite, esim. http://192.168.1.50:5000", prefs.getString("server", null))
        enrollNonce = field("Rekisteröintinonce (admin.py android-nonce, 64 heksamerkkiä)", null)
        button("Rekisteröi (luo avain K)") { enroll() }
        button("Jaa rekisteröintitiedot") { share() }
        button("Attestoi") { attest(corrupt = false) }
        button("Kontrolli: lähetä edellinen paketti uudelleen") { replay() }
        button("Kontrolli: attestoi turmellulla ketjulla") { attest(corrupt = true) }
        idOverride = field("Kontrolli: device_id-ohitus (tyhjä = oma)", null)
        button("Diagnostiikka") { show(att.diagnostics().toString(2)) }
        out = TextView(this).apply { setTextIsSelectable(true); textSize = 13f }
        col.addView(out)
        setContentView(ScrollView(this).apply { addView(col) })
        show(if (att.enrolled) "Rekisteröity, tila ${att.mode}." else "Ei rekisteröity.")
        server.setOnFocusChangeListener { _, has -> if (!has) prefs.edit().putString("server", server.text.toString().trim()).apply() }
    }

    private fun show(s: String) = runOnUiThread { out.text = s }

    private fun bg(f: () -> String) {
        show("…")
        Thread { show(try { f() } catch (e: Exception) { "VIRHE: ${e.javaClass.simpleName}: ${e.message}" }) }.start()
    }

    private fun enroll() = bg {
        val j = att.enroll(Wire.unhex(enrollNonce.text.toString().trim()))
        lastEnrollment = j.toString()
        "Rekisteröity: tila ${j.getString("mode")}, device_id ${j.getString("device_id")}.\n" +
            "Jaa tiedot ja aja Pi 2:lla: admin.py enroll-android laite.json\n\n" + j.getJSONObject("diag").toString(2)
    }

    private fun share() {
        val j = lastEnrollment ?: return show("Rekisteröi ensin.")
        (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("laite.json", j))
        startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"; putExtra(Intent.EXTRA_TEXT, j)
        }, "laite.json"))
    }

    private fun render(r: JSONObject): String {
        val c = r.optJSONObject("claims") ?: return r.toString(2)
        val sb = StringBuilder("device_id ${r.optString("device_id")}, käytäntö ${r.optString("policy_id")}\n\n")
        for (k in listOf("A", "B", "P", "Q")) {
            val x = c.optJSONObject(k)
            sb.append("$k: ${x?.optString("result") ?: "puuttuu"}\n   ${x?.optString("reason") ?: ""}\n\n")
        }
        return sb.toString()
    }

    private fun attest(corrupt: Boolean) = bg {
        val url = server.text.toString().trim()
        val nonce = Attestor.getNonce(url)
        val ev = att.makeBundle(nonce, idOverride.text.toString().trim(), corrupt)
        lastBundle = ev.bundle
        (if (corrupt) "KONTROLLI: turmeltu ketju\n" else "") + render(Attestor.postVerify(url, ev.bundle))
    }

    private fun replay() = bg {
        val b = lastBundle ?: return@bg "Ei edellistä pakettia."
        "KONTROLLI: sama paketti uudelleen\n" + render(Attestor.postVerify(server.text.toString().trim(), b))
    }
}

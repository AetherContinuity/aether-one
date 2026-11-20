package ref;

import com.google.android.attestation.AuthorizationList;
import com.google.android.attestation.ParsedAttestationRecord;
import com.google.android.attestation.RootOfTrust;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.google.gson.JsonNull;
import com.google.gson.JsonObject;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.nio.file.Files;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.time.format.DateTimeFormatter;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.TreeSet;
import org.bouncycastle.asn1.ASN1InputStream;
import org.bouncycastle.asn1.ASN1OctetString;
import org.bouncycastle.asn1.ASN1Sequence;

/**
 * Tulostaa jokaisen KeyDescription-laajennuksen Googlen jäsentimellä JSON-riveinä.
 * Sama muoto kuin reference_compare.py ours. Vain kääre: jäsennys on Googlen koodia
 * (ParsedAttestationRecord.create). Laajennuksen OCTET STRING -kuoren purku on sama
 * kuin Googlen yksityisessä extractAttestationSequence-metodissa.
 */
public class Main {
  static final String OID = "1.3.6.1.4.1.11129.2.1.17";
  static final HexFormat HEX = HexFormat.of();

  static JsonObject al(AuthorizationList a) {
    JsonObject o = new JsonObject();
    JsonArray p = new JsonArray();
    new TreeSet<String>(a.purpose().stream().map(Enum::name).toList()).forEach(p::add);
    o.add("purpose", p);
    o.add("algorithm", a.algorithm().map(x -> (com.google.gson.JsonElement) new com.google.gson.JsonPrimitive(x.name())).orElse(JsonNull.INSTANCE));
    if (a.rootOfTrust().isPresent()) {
      RootOfTrust r = a.rootOfTrust().get();
      JsonObject ro = new JsonObject();
      ro.addProperty("verifiedBootKey", HEX.formatHex(r.verifiedBootKey().toByteArray()));
      ro.addProperty("deviceLocked", r.deviceLocked());
      ro.addProperty("verifiedBootState", r.verifiedBootState().name());
      if (r.verifiedBootHash().isPresent()) {
        ro.addProperty("verifiedBootHash", HEX.formatHex(r.verifiedBootHash().get().toByteArray()));
      } else {
        ro.add("verifiedBootHash", JsonNull.INSTANCE);
      }
      o.add("rootOfTrust", ro);
    } else {
      o.add("rootOfTrust", JsonNull.INSTANCE);
    }
    if (a.osVersion().isPresent()) o.addProperty("osVersion", a.osVersion().get()); else o.add("osVersion", JsonNull.INSTANCE);
    if (a.osPatchLevel().isPresent()) o.addProperty("osPatchLevel", Integer.parseInt(a.osPatchLevel().get().format(DateTimeFormatter.ofPattern("yyyyMM")))); else o.add("osPatchLevel", JsonNull.INSTANCE);
    DateTimeFormatter d = DateTimeFormatter.ofPattern("yyyyMMdd");
    if (a.vendorPatchLevel().isPresent()) o.addProperty("vendorPatchLevel", Integer.parseInt(a.vendorPatchLevel().get().format(d))); else o.add("vendorPatchLevel", JsonNull.INSTANCE);
    if (a.bootPatchLevel().isPresent()) o.addProperty("bootPatchLevel", Integer.parseInt(a.bootPatchLevel().get().format(d))); else o.add("bootPatchLevel", JsonNull.INSTANCE);
    return o;
  }

  public static void main(String[] args) throws Exception {
    Gson gson = new GsonBuilder().serializeNulls().create();
    CertificateFactory cf = CertificateFactory.getInstance("X.509");
    File[] dirs = new File(args[0]).listFiles(File::isDirectory);
    Arrays.sort(dirs);
    for (File dir : dirs) {
      for (int i = 0; ; i++) {
        File f = new File(dir, "c" + i + ".der");
        if (!f.exists()) break;
        JsonObject o = new JsonObject();
        o.addProperty("chain", dir.getName());
        o.addProperty("index", i);
        try {
          X509Certificate c = (X509Certificate) cf.generateCertificate(new ByteArrayInputStream(Files.readAllBytes(f.toPath())));
          byte[] ext = c.getExtensionValue(OID);
          if (ext == null || ext.length == 0) continue;
          ASN1Sequence seq;
          try (ASN1InputStream in = new ASN1InputStream(ext)) {
            byte[] inner = ((ASN1OctetString) in.readObject()).getOctets();
            try (ASN1InputStream in2 = new ASN1InputStream(inner)) { seq = (ASN1Sequence) in2.readObject(); }
          }
          ParsedAttestationRecord r = ParsedAttestationRecord.create(seq, c.getPublicKey());
          o.addProperty("attestationVersion", r.attestationVersion());
          o.addProperty("attestationSecurityLevel", r.attestationSecurityLevel().name());
          o.addProperty("keymasterVersion", r.keymasterVersion());
          o.addProperty("keymasterSecurityLevel", r.keymasterSecurityLevel().name());
          o.addProperty("attestationChallenge", HEX.formatHex(r.attestationChallenge().toByteArray()));
          o.add("softwareEnforced", al(r.softwareEnforced()));
          o.add("teeEnforced", al(r.teeEnforced()));
        } catch (Exception e) {
          o.addProperty("error", e.getClass().getSimpleName() + ": " + e.getMessage());
        }
        System.out.println(gson.toJson(o));
      }
    }
  }
}

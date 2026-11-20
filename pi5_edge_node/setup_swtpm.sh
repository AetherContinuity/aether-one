#!/bin/bash
# setup_swtpm.sh - provisioi swtpm + rajoitettu AK-kahva 0x81000000 (dev/CI).
#
# Vaihe 1 (docs/VAIHE1-ENNAKKO.md K2): AK on restricted|sign|fixedtpm.
# Jos kahvassa on v0.1:n rajoittamaton avain (decrypt|sign), se poistetaan
# ja tilalle luodaan rajoitettu. Idempotentti muuten.
#
# Valinnainen: AK_HANDLE=0x81000001 bash setup_swtpm.sh luo toisen AK:n
# (negatiivikontrolli "toinen AK").
set -e
export TPM2TOOLS_TCTI="swtpm:host=localhost,port=2321"
AK_HANDLE="${AK_HANDLE:-0x81000000}"
AK_ATTRS="fixedtpm|fixedparent|sensitivedataorigin|userwithauth|restricted|sign"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if ! pgrep -f "swtpm socket" > /dev/null; then
  mkdir -p /tmp/swtpm_state
  # Irrotettu: tausta-swtpm ei saa periä kutsujan stdoutia (putki jäisi auki).
  nohup swtpm socket --tpmstate dir=/tmp/swtpm_state \
    --ctrl type=tcp,port=2322 --server type=tcp,port=2321 \
    --flags not-need-init --tpm2 > /tmp/swtpm.log 2>&1 < /dev/null &
  sleep 2
  tpm2_startup -c || true
fi

tpm2_flushcontext -t || true

if tpm2_readpublic -c "$AK_HANDLE" > "$WORK/pub.txt" 2>/dev/null; then
  if grep -q "restricted" "$WORK/pub.txt" && grep -q "sign" "$WORK/pub.txt" \
     && grep -q "fixedtpm" "$WORK/pub.txt"; then
    echo "Rajoitettu AK loytyi ($AK_HANDLE), ohitetaan provisiointi."
    exit 0
  fi
  echo "AK $AK_HANDLE ei ole rajoitettu, poistetaan."
  tpm2_evictcontrol -C o -c "$AK_HANDLE" -Q
fi

echo "Provisioidaan rajoitettu AK $AK_HANDLE..."
tpm2_createprimary -C o -c "$WORK/primary.ctx" -Q
tpm2_flushcontext -t
tpm2_create -C "$WORK/primary.ctx" -G rsa2048:rsassa-sha256:null \
  -a "$AK_ATTRS" -u "$WORK/ak.pub" -r "$WORK/ak.priv" -Q
tpm2_flushcontext -t
tpm2_load -C "$WORK/primary.ctx" -u "$WORK/ak.pub" -r "$WORK/ak.priv" -c "$WORK/ak.ctx" -Q
tpm2_flushcontext -t
tpm2_evictcontrol -C o -c "$WORK/ak.ctx" "$AK_HANDLE" -Q
tpm2_flushcontext -t || true
echo "AK provisioitu."

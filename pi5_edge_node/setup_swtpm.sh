#!/bin/bash
# setup_swtpm.sh - provisioi swtpm + AK-kahva 0x81000000 CI-ympäristössä.
# Idempotentti: ohittaa provisioinnin jos AK on jo olemassa.
set -e
export TPM2TOOLS_TCTI="swtpm:host=localhost,port=2321"

if ! pgrep -f "swtpm socket" > /dev/null; then
  mkdir -p /tmp/swtpm_state
  swtpm socket --tpmstate dir=/tmp/swtpm_state --ctrl type=tcp,port=2322 --server type=tcp,port=2321 --flags not-need-init --tpm2 &
  sleep 2
  tpm2_startup -c || true
fi

tpm2_flushcontext -t || true

if ! tpm2_readpublic -c 0x81000000 > /dev/null 2>&1; then
  echo "AK puuttuu, provisioidaan..."
  tpm2_createprimary -C o -c /tmp/primary.ctx -Q
  tpm2_flushcontext -t
  tpm2_create -G rsa -u /tmp/ak.pub -r /tmp/ak.priv -C /tmp/primary.ctx -Q
  tpm2_flushcontext -t
  tpm2_load -C /tmp/primary.ctx -u /tmp/ak.pub -r /tmp/ak.priv -c /tmp/ak.ctx -Q
  tpm2_flushcontext -t
  tpm2_evictcontrol -C o -c /tmp/ak.ctx 0x81000000 -Q
  echo "AK provisioitu."
else
  echo "AK loytyi jo, ohitetaan provisiointi."
fi

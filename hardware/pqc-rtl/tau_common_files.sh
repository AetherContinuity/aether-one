# tau_common_files.sh
#
# KESKITETTY tiedostolista kaikille pqc_tau_integrated_wrapper.sv:aa
# kayttaville run_m4_tau_*.sh-testiskripteille.
#
# TAUSTA (2026-07-19): CI-regressio (workflow run #197) paljasti etta
# kaareen lisatyt uudet moduulit (Decaps, Encaps) eivat automaattisesti
# nakyneet olemassa olevissa run_*.sh-skripteissa - jokainen skripti
# yllapiti OMAA, kasin kirjoitettua kopiotaan tiedostolistasta, ja nama
# kopiot erkanivat toisistaan ajan myota. Kayttajan oma ehdotus:
# keskitetty tiedostolista pienentaa taman toistumisen riskia -
# UUDEN moduulin lisays kaareen vaatii paivityksen VAIN TAHAN YHTEEN
# tiedostoon, ei jokaiseen run_*.sh-skriptiin erikseen.
#
# Kaytto run_*.sh-skriptissa:
#   source "$(dirname "$0")/tau_common_files.sh"
#   compile_tau sim/xxx_sim fpga/tau/xxx_tb.sv [lisaa_tarvittaessa_muita.sv]

TAU_RTL_FILES="rtl/pqc_rvv_cluster_2lane.sv rtl/pqc_ntt_stage_banked.sv \
  rtl/pqc_samplentt_reject.sv rtl/pqc_samplentt.sv \
  rtl/pqc_keccak_pad.sv rtl/pqc_keccak_absorb.sv rtl/pqc_keccak_squeeze.sv rtl/pqc_keccak_f1600.sv \
  rtl/pqc_sha3_512.sv rtl/pqc_sha3_256.sv rtl/pqc_shake128.sv rtl/pqc_shake256.sv \
  rtl/pqc_samplepolycbd.sv rtl/pqc_prf_samplepolycbd.sv \
  rtl/pqc_byteencode_dparam.sv rtl/pqc_byteencode_d1.sv \
  rtl/pqc_multiplyntts.sv rtl/pqc_basecasemul.sv rtl/pqc_polyadd.sv rtl/pqc_polysub.sv \
  rtl/pqc_ntt_final_scale.sv rtl/pqc_compress.sv rtl/pqc_batch_compress.sv rtl/pqc_batch_decompress.sv \
  fpga/tau/pqc_mlkem_keygen_core.sv fpga/tau/pqc_mlkem_decaps_a_core.sv \
  fpga/tau/pqc_mlkem_decaps_b1_core.sv fpga/tau/pqc_mlkem_decaps_top.sv \
  fpga/tau/pqc_mlkem_encaps_top.sv \
  fpga/tau/pqc_tau_audit_log.sv fpga/tau/pqc_tau_watchdog.sv \
  fpga/tau/pqc_tau_integrated_wrapper.sv"

# KESKITETTY kaannoskomento (kayttajan oma jatkoehdotus 2026-07-19):
# nyt myos iverilog-liput/optiot ja tiedostolista pysyvat YHDESSA
# paikassa - run_*.sh-skriptit sisaltavat VAIN sen mika on kullekin
# testille ominaista (mita testataan), ei sita MITEN kaannetaan.
#
# $1 = ulostulon polku (esim. sim/xxx_sim)
# $2..$N = testipenkin oma(t) tiedosto(t) (yleensa yksi fpga/tau/xxx_tb.sv)
compile_tau() {
  local out="$1"
  shift
  iverilog -g2012 -o "$out" $TAU_RTL_FILES "$@"
}

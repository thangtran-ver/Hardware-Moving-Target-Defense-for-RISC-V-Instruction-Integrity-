#!/usr/bin/env bash
# Chay KAT Ascon-128a bang Verilator (WSL Ubuntu).  Dung:  ./run_verilator.sh [wave]
#   wave : bat ghi waveform (wave.vcd, xem bang GTKWave)
set -uo pipefail
cd "$(dirname "$0")"                       # thu muc ascon_kat (can de doc kat_vectors.txt)
R="${RTL_DIR:-../../../hw/rtl/ascon}"      # co the doi: RTL_DIR=/duong/dan/rtl/ascon ./run_verilator.sh
OBJ="${TMPDIR:-/tmp}/vl_ascon_kat"         # build ngoai repo (nhanh, khong lam ban repo)
SRC="ascon_add_constant ascon_sbox ascon_xor_diffusion ascon_round ascon_p8 ascon_p12 \
ascon_key_nonce_reg ascon_initial_state ascon_post_init ascon_ad_buffer_padding ascon_ad_absorb \
ascon_final_pre ascon_state_mux ascon_state_reg ascon_tag_output ascon_controller ascon_top"
FILES=""; for f in $SRC; do FILES="$FILES $R/$f.v"; done
EXTRA=""; [ "${1:-}" = wave ] && EXTRA="--trace"

python3 gen_vectors.py || { echo "gen_vectors.py loi"; exit 1; }
rm -rf "$OBJ"
verilator --binary --timing $EXTRA -Wno-fatal -Wno-lint -Wno-style -Wno-TIMESCALEMOD \
  --top-module tb_ascon_kat --Mdir "$OBJ" -o Vtb $FILES tb_ascon_kat.v > build.log 2>&1 \
  || { echo "Verilator bien dich loi, xem build.log"; tail -20 build.log; exit 1; }
mkdir -p results
TS=$(date +%Y%m%d_%H%M%S); LOG="results/kat_$TS.log"
{
  echo "Ngay chay : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Verilator : $(verilator --version)"
  "$OBJ/Vtb" ${EXTRA:++wave} | grep -v 'Verilog \$finish'
} | tee "$LOG"
cp "$LOG" results/latest.log; cp "$LOG" run.log       # latest.log luon la ket qua moi nhat
if grep -q "KET QUA CHUNG  : PASS" "$LOG"; then echo "==== KET QUA: PASS ====  (log: $LOG)"; exit 0; fi
echo "==== KET QUA: FAIL ====  (log: $LOG)"; exit 1

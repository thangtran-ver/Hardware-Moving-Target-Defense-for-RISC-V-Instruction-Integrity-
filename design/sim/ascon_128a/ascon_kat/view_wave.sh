#!/usr/bin/env bash
# Tu dong mo waveform Ascon KAT trong GTKWave.
#   ./view_wave.sh                 # tao wave.vcd neu chua co, mo GTKWave, tu them tin hieu + hex + zoom full
#   ./view_wave.sh 400 700         # zoom vao doan 400 ns .. 700 ns
#   ./view_wave.sh --rebuild       # chay lai mo phong (run_verilator.sh wave) roi moi mo
cd "$(dirname "$0")"
if [ "${1:-}" = "--rebuild" ] || [ ! -f wave.vcd ]; then
  ./run_verilator.sh wave || { echo "Mo phong loi"; exit 1; }
  [ "${1:-}" = "--rebuild" ] && shift
fi
command -v gtkwave >/dev/null || { echo "Chua co gtkwave: sudo apt install gtkwave"; exit 1; }
[ $# -ge 2 ] && export ZOOM_FROM_NS="$1" ZOOM_TO_NS="$2"
exec gtkwave -S view_wave.tcl wave.vcd

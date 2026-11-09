#!/usr/bin/env bash
# Xem lai ket qua KAT cua lan chay gan nhat, KHONG can chay lai mo phong.
#   ./show_result.sh          # in log moi nhat
#   ./show_result.sh list     # liet ke cac log da luu
#   ./show_result.sh fail     # chi in cac dong FAIL va bang thong ke
cd "$(dirname "$0")"
[ -f results/latest.log ] || { echo "Chua co log. Chay ./run_verilator.sh truoc."; exit 1; }
case "${1:-}" in
  list) ls -1t results/kat_*.log ;;
  fail) grep -E "FAIL|THONG KE|Tong so|PASS  |Ty le|Bypass|KET QUA CHUNG" results/latest.log ;;
  *)    cat results/latest.log ;;
esac

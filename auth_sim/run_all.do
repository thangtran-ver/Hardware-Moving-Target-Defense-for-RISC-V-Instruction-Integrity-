# run_all.do -- ModelSim: vsim -c -do run_all.do  (run from the project auth_sim/ directory)
# Unit test in [PASS]/[FAIL] cho tung khoi + 'UNIT errors = 0'.
# Moi kich ban he thong in 1 dong 'CHECK PASS/FAIL'. Mac dinh G=4, T=128.
vlib work
vlog -f files.f
vlog tb_auth_units.v

echo "=== Unit test tung khoi con"
vsim -c -onfinish stop work.tb_auth_units
run -all
quit -sim

echo "=== 1 firmware + tag dung"
vsim -c -onfinish stop work.tb_auth_soc +code=main_c.hex +tag=main_t.hex +expect=clean
run -all
quit -sim
echo "=== 2 lat 1 bit code"
vsim -c -onfinish stop work.tb_auth_soc +code=main_c.hex +tag=main_t.hex +attack=1 +expect=fault
run -all
quit -sim
echo "=== 3 lat 1 bit tag"
vsim -c -onfinish stop work.tb_auth_soc +code=main_c.hex +tag=main_t.hex +attack=2 +expect=fault
run -all
quit -sim
echo "=== 4 doi cho block 1 va 2"
vsim -c -onfinish stop work.tb_auth_soc +code=main_c.hex +tag=main_t.hex +attack=3 +expect=fault
run -all
quit -sim
echo "=== 5 PROGRAM_ID khac"
vsim -c -onfinish stop work.tb_auth_soc +code=p2_c.hex +tag=p2_t.hex +expect=fault
run -all
quit -sim
echo "=== 6 IMAGE_ID cu"
vsim -c -onfinish stop work.tb_auth_soc +code=i0_c.hex +tag=i0_t.hex +expect=fault
run -all
quit -sim
echo "=== 7 key khac"
vsim -c -onfinish stop work.tb_auth_soc +code=k_c.hex +tag=k_t.hex +expect=fault
run -all
quit -sim
echo "=== 8 nhay vao ma chen trong data RAM"
vsim -c -onfinish stop work.tb_auth_soc +code=inject_c.hex +tag=inject_t.hex +data=inject_data.hex +expect=fault
run -all
quit -sim
echo "=== 9 TOCTOU sua code sau khi verify"
vsim -c -onfinish stop work.tb_auth_soc +code=main_c.hex +tag=main_t.hex +attack=4 +expect=toctou
run -all
quit -sim
echo "=== 10 firmware khong ky"
vsim -c -onfinish stop work.tb_auth_soc +code=main.hex +expect=fault
run -all
quit -sim
echo "=== 11 store vao vung CODE"
vsim -c -onfinish stop work.tb_auth_soc +code=wcode_c.hex +tag=wcode_t.hex +expect=wcode
run -all
quit -sim

echo "=== 12 firmware C (gcc/clang) + tag dung"
vsim -c -onfinish stop work.tb_auth_soc +code=fw_c/code.hex +tag=fw_c/tag.hex +data=fw_c/data.hex +maxcyc=50000 +expect=clean
run -all
quit -sim
echo "=== 13 firmware C, lat 1 bit code"
vsim -c -onfinish stop work.tb_auth_soc +code=fw_c/code.hex +tag=fw_c/tag.hex +data=fw_c/data.hex +attack=1 +expect=fault
run -all
quit -sim

quit -f

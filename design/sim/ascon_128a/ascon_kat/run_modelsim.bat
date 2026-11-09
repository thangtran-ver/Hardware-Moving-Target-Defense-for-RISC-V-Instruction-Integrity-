@echo off
rem Tu dong chay KAT Ascon-128a tren ModelSim.  Dung:  run_modelsim.bat [gui]
rem Can: python (hoac py) va vsim trong PATH.
cd /d "%~dp0"

where python >nul 2>nul && (set PY=python) || (set PY=py)
%PY% gen_vectors.py || goto :err

if /i "%1"=="gui" (
  vsim -do "if {[file exists work]} {vdel -lib work -all}; vlib work; vmap work work; set R ../../../hw/rtl/ascon; vlog -work work $R/ascon_add_constant.v $R/ascon_sbox.v $R/ascon_xor_diffusion.v $R/ascon_round.v $R/ascon_p8.v $R/ascon_p12.v $R/ascon_key_nonce_reg.v $R/ascon_initial_state.v $R/ascon_post_init.v $R/ascon_ad_buffer_padding.v $R/ascon_ad_absorb.v $R/ascon_final_pre.v $R/ascon_state_mux.v $R/ascon_state_reg.v $R/ascon_tag_output.v $R/ascon_controller.v $R/ascon_top.v tb_ascon_kat.v; vsim -voptargs=+acc work.tb_ascon_kat; add wave -r /tb_ascon_kat/dut/*; run -all"
  goto :eof
)

vsim -c -do run_modelsim.do > run.log 2>&1
type run.log
findstr /c:"KET QUA CHUNG  : PASS" run.log >nul && (echo.& echo ==== KET QUA: PASS ====& exit /b 0)
echo.& echo ==== KET QUA: FAIL (xem run.log) ====
exit /b 1

:err
echo Khong chay duoc gen_vectors.py (can Python trong PATH)
exit /b 1

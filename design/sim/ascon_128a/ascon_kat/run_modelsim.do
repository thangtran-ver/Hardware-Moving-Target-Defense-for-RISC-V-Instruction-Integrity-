# Chay: vsim -c -do run_modelsim.do   (trong thu muc ascon_kat)
quit -sim
if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work
set R ../../../hw/rtl/ascon
if {[info exists ::env(RTL_DIR)]} { set R $::env(RTL_DIR) }
vlog -work work -timescale 1ns/1ps \
  $R/ascon_add_constant.v $R/ascon_sbox.v $R/ascon_xor_diffusion.v $R/ascon_round.v \
  $R/ascon_p8.v $R/ascon_p12.v $R/ascon_key_nonce_reg.v $R/ascon_initial_state.v \
  $R/ascon_post_init.v $R/ascon_ad_buffer_padding.v $R/ascon_ad_absorb.v $R/ascon_final_pre.v \
  $R/ascon_state_mux.v $R/ascon_state_reg.v $R/ascon_tag_output.v $R/ascon_controller.v \
  $R/ascon_top.v tb_ascon_kat.v
vsim -c -voptargs=+acc work.tb_ascon_kat -do "run -all; quit -f"

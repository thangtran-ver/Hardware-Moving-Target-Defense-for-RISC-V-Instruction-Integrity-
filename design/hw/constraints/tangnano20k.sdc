//  tangnano20k.sdc -- 27 MHz
create_clock -name sys_clk -period 37.037 -waveform {0 18.518} [get_ports {sys_clk}]
set_false_path -from [get_ports {btn_rst}]
set_false_path -from [get_ports {uart_rx}]

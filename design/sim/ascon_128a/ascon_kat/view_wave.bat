@echo off
rem Mo wave.vcd bang GTKWave cho Windows (can gtkwave trong PATH). Dung: view_wave.bat [tu_ns den_ns]
cd /d "%~dp0"
if not exist wave.vcd (echo Chua co wave.vcd - hay chay ./run_verilator.sh wave trong WSL truoc & exit /b 1)
if not "%2"=="" (set ZOOM_FROM_NS=%1& set ZOOM_TO_NS=%2)
gtkwave -S view_wave.tcl wave.vcd

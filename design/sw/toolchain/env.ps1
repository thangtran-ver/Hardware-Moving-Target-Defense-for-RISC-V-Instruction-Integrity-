# Them toolchain vao PATH cua phien PowerShell hien tai.
# Dung:  . .\env.ps1
$verLine = (Get-Content (Join-Path $PSScriptRoot "VERSION") -TotalCount 1).Trim()
$ver     = ($verLine -split "\s+")[-1]
$bin     = Join-Path $PSScriptRoot "xpack-riscv-none-elf-gcc-$ver\bin"
if (-not (Test-Path $bin)) { Write-Error "Chua cai toolchain. Chay setup.ps1 truoc."; return }
$env:PATH = "$bin;$env:PATH"
riscv-none-elf-gcc --version | Select-Object -First 1

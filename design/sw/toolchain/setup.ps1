<#
.SYNOPSIS
  Tai va giai nen xPack RISC-V GCC dung version trong file VERSION.
.USAGE
  powershell -ExecutionPolicy Bypass -File setup.ps1
  powershell -ExecutionPolicy Bypass -File setup.ps1 -Force   # cai lai
#>
param([switch]$Force)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root    = $PSScriptRoot
$verLine = (Get-Content (Join-Path $root "VERSION") -TotalCount 1).Trim()
$ver     = ($verLine -split "\s+")[-1]                      # vd: 15.2.0-1
$name    = "xpack-riscv-none-elf-gcc-$ver"
$zipName = "$name-win32-x64.zip"
$base    = "https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v$ver"
$dest    = Join-Path $root $name
$gcc     = Join-Path $dest "bin\riscv-none-elf-gcc.exe"
$zipPath = Join-Path $root $zipName

if ((Test-Path $gcc) -and -not $Force) {
    Write-Host "Da co toolchain: $dest"
    & $gcc --version | Select-Object -First 1
    exit 0
}

if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }

Write-Host "Tai $zipName ..."
$ProgressPreference = "SilentlyContinue"
Invoke-WebRequest "$base/$zipName" -OutFile $zipPath

# Kiem tra SHA-256 neu xPack cung cap file .sha
try {
    Invoke-WebRequest "$base/$zipName.sha" -OutFile "$zipPath.sha"
    $expected = ((Get-Content "$zipPath.sha" -TotalCount 1) -split "\s+")[0].ToLower()
    $actual   = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
    if ($expected -ne $actual) { throw "SHA-256 khong khop. expected=$expected actual=$actual" }
    Write-Host "SHA-256 OK"
} catch [System.Net.WebException] {
    Write-Warning "Khong tai duoc file .sha, bo qua buoc kiem tra checksum."
}

Write-Host "Giai nen ..."
Expand-Archive $zipPath -DestinationPath $root -Force
Remove-Item $zipPath, "$zipPath.sha" -ErrorAction SilentlyContinue

if (-not (Test-Path $gcc)) { throw "Khong tim thay $gcc sau khi giai nen." }
Write-Host "Cai xong: $dest"
& $gcc --version | Select-Object -First 1
Write-Host "Chay '. .\env.ps1' de them toolchain vao PATH cua phien hien tai."

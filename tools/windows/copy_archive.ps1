<#
.SYNOPSIS
Copies the A. tortilis dataset and the trained work directories from the project
share to a local disk, then checks the tile counts and prints the two lines needed
in docker\.env.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\windows\copy_archive.ps1 -Destination D:\A.tortilis_Data_Model

.EXAMPLE
# check a copy that already exists (no copying, no Z: drive needed)
powershell -ExecutionPolicy Bypass -File tools\windows\copy_archive.ps1 -Destination "D:\...\A.tortilis_Data_Model" -CheckOnly

.NOTES
Safe to run again: robocopy skips files that are already present.
#>
param(
    [Parameter(Mandatory = $true)][string]$Destination,
    [string]$Source = "Z:\Final Geodatabase\Vegetation_Geodatabase\3_Mapping Acacia tortilis Trees\A.tortilis_Data & Model",
    [switch]$CheckOnly,
    [switch]$NoEnv
)

$ErrorActionPreference = 'Stop'
$data = "Data used to build the model"
$wts = "A.tortilis Models\Pretrained weights"

if ($Destination -match '&') { throw "The destination path must not contain '&' (Docker cannot mount it)." }

if ($CheckOnly) {
    Write-Host "Checking the copy in $Destination (nothing is copied) ..."
    if (-not (Test-Path -LiteralPath "$Destination\$data")) {
        throw "Not found: $Destination\$data`n  Give the folder that contains '$data' and 'A.tortilis Models'."
    }
}
else {
    if (-not (Test-Path -LiteralPath "$Source\$data")) {
        throw "Source not found: $Source\$data`n  Is the Z: drive visible in File Explorer? Is this PowerShell window running as administrator? (an administrator window cannot see network drives: close it and open a normal one)"
    }

    Write-Host "1/2  Copying the dataset (about 32 GB; 10 to 60 minutes depending on the network) ..."
    robocopy "$Source\$data" "$Destination\$data" /E /MT:16 /R:2 /W:5 /XF *.aux.xml *.ovr /NP /NFL /NDL
    if ($LASTEXITCODE -ge 8) { throw "robocopy reported failures (exit code $LASTEXITCODE); run the script again." }

    Write-Host "2/2  Copying the trained models (about 2.5 GB) ..."
    robocopy "$Source\$wts" "$Destination\$wts" /E /MT:16 /R:2 /W:5 /NP /NFL /NDL
    if ($LASTEXITCODE -ge 8) { throw "robocopy reported failures (exit code $LASTEXITCODE); run the script again." }
}

Write-Host ""
Write-Host "Tile counts   (expected: train 4893, val 2407, test2 3123, Generalizability 2162)"
$ok = $true
$expected = @{ train = 4893; val = 2407; test2 = 3123; Generalizability = 2162 }
foreach ($s in 'train', 'val', 'test2', 'Generalizability') {
    $img = @(Get-ChildItem -LiteralPath "$Destination\$data\img_dir\$s" -Filter *.tif -File -ErrorAction SilentlyContinue).Count
    $ann = @(Get-ChildItem -LiteralPath "$Destination\$data\ann_dir\$s" -Filter *.tif -File -ErrorAction SilentlyContinue).Count
    $flag = if ($img -eq $expected[$s] -and $ann -eq $expected[$s]) { 'ok' } else { $ok = $false; 'CHECK' }
    "{0,-18} images={1,5}  masks={2,5}   {3}" -f $s, $img, $ann, $flag
}

Write-Host ""
Write-Host "Best checkpoints found:"
$found = @(Get-ChildItem -LiteralPath "$Destination\$wts" -Recurse -Filter best_mIoU_iter_*.pth -ErrorAction SilentlyContinue)
if ($found.Count -eq 0) {
    $ok = $false
    Write-Host "  none: '$Destination\$wts' is missing or empty   CHECK"
}
else {
    $found | ForEach-Object { "  " + $_.FullName }
    if ($found.Count -lt 3) { Write-Host "  (three are expected: tiny, small, base)" }
}

$d = $Destination.TrimEnd('\') -replace '\\', '/'
$dataLine = 'DATA_DIR="' + $d + '/' + ($data -replace '\\', '/') + '"'
$wtsLine = 'WEIGHTS_DIR="' + $d + '/' + ($wts -replace '\\', '/') + '"'

Write-Host ""
Write-Host "Lines for docker\.env:"
Write-Host "  $dataLine"
Write-Host "  $wtsLine"

if (-not $NoEnv) {
    $dockerDir = Join-Path $PSScriptRoot '..\..\docker'
    if (Test-Path -LiteralPath $dockerDir) {
        $envPath = Join-Path (Resolve-Path -LiteralPath $dockerDir).Path '.env'
        Set-Content -LiteralPath $envPath -Encoding ASCII -Value $dataLine, $wtsLine, 'HF_HUB_OFFLINE=0'
        Write-Host ""
        Write-Host "Written: $envPath   (step 6 only checks this file)"
    }
    else {
        Write-Host ""
        Write-Host "docker\.env was not written (this script is not inside the code folder); enter the two lines by hand in step 6."
    }
}

Write-Host ""
if ($ok) { Write-Host "RESULT: OK" } else { Write-Host "RESULT: something is marked CHECK above; run the command again, and report it if it stays." }

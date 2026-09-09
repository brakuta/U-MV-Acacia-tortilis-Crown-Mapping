<#
.SYNOPSIS
Copies the A. tortilis dataset and the trained work directories from the project
share to a local disk, then checks the tile counts and prints the two lines needed
in docker\.env.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\windows\copy_archive.ps1 -Destination D:\A.tortilis_Data_Model

.NOTES
Safe to run again: robocopy skips files that are already present.
#>
param(
    [Parameter(Mandatory = $true)][string]$Destination,
    [string]$Source = "Z:\Final Geodatabase\Vegetation_Geodatabase\3_Mapping Acacia tortilis Trees\A.tortilis_Data & Model"
)

$ErrorActionPreference = 'Stop'
$data = "Data used to build the model"
$wts = "A.tortilis Models\Pretrained weights"

if ($Destination -match '&') { throw "The destination path must not contain '&' (Docker cannot mount it)." }
if (-not (Test-Path -LiteralPath "$Source\$data")) { throw "Source not found: $Source\$data  (is the Z: drive connected?)" }

Write-Host "1/2  Copying the dataset (about 32 GB; 10 to 60 minutes depending on the network) ..."
robocopy "$Source\$data" "$Destination\$data" /E /MT:16 /R:2 /W:5 /XF *.aux.xml *.ovr *.xml /NP /NFL /NDL
if ($LASTEXITCODE -ge 8) { throw "robocopy reported failures (exit code $LASTEXITCODE); run the script again." }

Write-Host "2/2  Copying the trained models (about 2.5 GB) ..."
robocopy "$Source\$wts" "$Destination\$wts" /E /MT:16 /R:2 /W:5 /NP /NFL /NDL
if ($LASTEXITCODE -ge 8) { throw "robocopy reported failures (exit code $LASTEXITCODE); run the script again." }

Write-Host ""
Write-Host "Tile counts   (expected: train 4893, val 2407, test2 3123, Generalizability 2162)"
$ok = $true
$expected = @{ train = 4893; val = 2407; test2 = 3123; Generalizability = 2162 }
foreach ($s in 'train', 'val', 'test2', 'Generalizability') {
    $img = (Get-ChildItem -LiteralPath "$Destination\$data\img_dir\$s" -Filter *.tif -File).Count
    $ann = (Get-ChildItem -LiteralPath "$Destination\$data\ann_dir\$s" -Filter *.tif -File).Count
    $flag = if ($img -eq $expected[$s] -and $ann -eq $expected[$s]) { 'ok' } else { $ok = $false; 'CHECK' }
    "{0,-18} images={1,5}  masks={2,5}   {3}" -f $s, $img, $ann, $flag
}

Write-Host ""
Write-Host "Best checkpoints found:"
Get-ChildItem -LiteralPath "$Destination\$wts" -Recurse -Filter best_mIoU_iter_*.pth | ForEach-Object { "  " + $_.FullName }

$d = $Destination.TrimEnd('\') -replace '\\', '/'
Write-Host ""
Write-Host "Lines for docker\.env (already correct in docker\.env.windows.example if Destination is D:\A.tortilis_Data_Model):"
Write-Host ("DATA_DIR=""{0}/{1}""" -f $d, $data)
Write-Host ("WEIGHTS_DIR=""{0}/{1}""" -f $d, ($wts -replace '\\', '/'))
Write-Host ""
if ($ok) { Write-Host "RESULT: OK" } else { Write-Host "RESULT: tile counts differ from the archive; run the script again or report it." }

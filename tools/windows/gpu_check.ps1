<#
.SYNOPSIS
Collects the facts that decide whether Docker Desktop can use the NVIDIA GPU,
and prints them as one short report to send to the project lead.

.EXAMPLE
docker\umv.cmd doctor

.NOTES
Read-only: it starts nothing and changes nothing.
#>

function Show-Section($title) {
    Write-Host ""
    Write-Host "== $title"
}

function Try-Run($label, $script) {
    try {
        $out = & $script 2>&1
        if ($null -eq $out -or "$out".Trim() -eq '') { $out = '(no output)' }
        foreach ($line in @($out)) { Write-Host ("  {0}" -f $line) }
    }
    catch {
        Write-Host ("  {0}: not available ({1})" -f $label, $_.Exception.Message)
    }
}

Write-Host "U-MV GPU report   $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

Show-Section "1. Windows"
Try-Run 'Windows' {
    $os = Get-CimInstance Win32_OperatingSystem
    "{0} (version {1}, build {2})" -f $os.Caption, $os.Version, $os.BuildNumber
}
Write-Host "  needed: Windows 11, or Windows 10 build 19044 (21H2) or higher"

Show-Section "2. Graphics cards and NVIDIA driver"
Try-Run 'video controllers' { Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name } }
Try-Run 'nvidia-smi' { nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap --format=csv }
Write-Host "  needed: an NVIDIA card above, and a driver version of 520 or higher"

Show-Section "3. Linux layer (WSL)"
Try-Run 'wsl --version' { wsl.exe --version }
Try-Run 'wsl -l -v' { wsl.exe -l -v }
Write-Host "  needed: a WSL version line, and every distribution at VERSION 2"

Show-Section "4. Docker engine"
Try-Run 'docker version' { docker version --format "client {{.Client.Version}}, server {{.Server.Version}}" }
Try-Run 'docker kernel' { docker info --format "kernel {{.KernelVersion}} | os {{.OperatingSystem}} | memory {{.MemTotal}}" }
Write-Host "  needed: the kernel must contain 'WSL2'. 'linuxkit' means Docker Desktop runs on"
Write-Host "  Hyper-V, where no GPU is visible: Settings -> General -> tick 'Use the WSL 2"
Write-Host "  based engine' -> Apply & restart."

Show-Section "5. Driver inside the Linux layer"
Try-Run 'wsl lib' {
    $r = wsl.exe -e ls /usr/lib/wsl/lib 2>&1
    if ("$r" -match 'libnvidia-ml') { "libnvidia-ml.so.1 is present in /usr/lib/wsl/lib" }
    else { "libnvidia-ml.so.1 NOT found in /usr/lib/wsl/lib -> run 'wsl --update', then 'wsl --shutdown'" }
}

Show-Section "6. GPU inside a container"
Try-Run 'docker gpu' { docker run --rm --gpus all ubuntu:22.04 nvidia-smi -L }

Write-Host ""
Write-Host "Send everything printed above (right-click the title bar -> Edit -> Select All -> Enter, then paste)."

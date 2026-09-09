@echo off
rem Copies the A. tortilis archive from the project share to a local disk (see copy_archive.ps1).
rem Usage:  tools\windows\copy_archive.cmd D:\A.tortilis_Data_Model
if "%~1"=="" (
  echo Usage: tools\windows\copy_archive.cmd ^<destination folder, e.g. D:\A.tortilis_Data_Model^>
  exit /b 2
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0copy_archive.ps1" -Destination "%~1"
exit /b %ERRORLEVEL%

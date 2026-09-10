@echo off
rem Copies the A. tortilis archive from the project share to a local disk (runs copy_archive.ps1).
rem Usage:  tools\windows\copy_archive.cmd D:\A.tortilis_Data_Model
rem         tools\windows\copy_archive.cmd D:\A.tortilis_Data_Model -Source "Y:\...\A.tortilis_Data & Model"
setlocal
if "%~1"=="" (
  echo Usage: tools\windows\copy_archive.cmd ^<destination folder, e.g. D:\A.tortilis_Data_Model^>
  exit /b 2
)
set "DEST=%~1"
if "%DEST:~-1%"=="\" set "DEST=%DEST:~0,-1%"
set "REST="
:more
shift
if "%~1"=="" goto run
set "REST=%REST% "%~1""
goto more
:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0copy_archive.ps1" -Destination "%DEST%" %REST%
exit /b %ERRORLEVEL%

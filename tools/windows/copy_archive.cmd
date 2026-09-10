@echo off
rem Copies the A. tortilis archive from the project share to a local disk, then checks it
rem (runs copy_archive.ps1).  Usage:
rem   tools\windows\copy_archive.cmd D:\A.tortilis_Data_Model
rem   tools\windows\copy_archive.cmd "D:\Vegetation\3_Mapping Acacia tortilis Trees\A.tortilis_Data_Model" check
rem   tools\windows\copy_archive.cmd D:\A.tortilis_Data_Model -Source "Y:\...\A.tortilis_Data ^& Model"
rem "check" verifies a copy that already exists and prints the docker\.env lines; it copies nothing.
setlocal
set "HERE=%~dp0"
set "DEST=%~1"
if not defined DEST goto usage
if "%DEST:~-1%"=="\" set "DEST=%DEST:~0,-1%"

set "OPT="
set "SRC=%~2"
if /i "%SRC%"=="check" set "OPT=-CheckOnly"
if /i "%SRC%"=="-check" set "OPT=-CheckOnly"
if /i "%SRC%"=="-CheckOnly" set "OPT=-CheckOnly"
if defined OPT set "SRC="
if /i "%SRC%"=="-Source" set "SRC=%~3"

if defined SRC (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%copy_archive.ps1" -Destination "%DEST%" -Source "%SRC%" %OPT%
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%copy_archive.ps1" -Destination "%DEST%" %OPT%
)
exit /b %ERRORLEVEL%

:usage
echo Usage:
echo   tools\windows\copy_archive.cmd ^<destination folder^>
echo   tools\windows\copy_archive.cmd ^<destination folder^> check
echo   tools\windows\copy_archive.cmd ^<destination folder^> -Source "^<share folder^>"
exit /b 2

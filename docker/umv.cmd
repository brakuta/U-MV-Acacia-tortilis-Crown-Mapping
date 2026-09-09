@echo off
rem U-MV helper for Windows (run from PowerShell or cmd, from the repository root).
rem
rem   docker\umv.cmd gpu                  check that Docker Desktop can use the GPU
rem   docker\umv.cmd build 7.5            build the image for one GPU architecture (MAX_JOBS=2)
rem   docker\umv.cmd build "7.5;8.6" 4    several architectures and 4 compiler jobs (64 GB RAM)
rem   docker\umv.cmd shell                start an interactive container (type exit to leave)
rem
rem The full docker compose commands behind these are listed in docs/01_installation.md.
setlocal
set "DIR=%~dp0"
if /i "%~1"=="gpu" goto gpu
if /i "%~1"=="build" goto build
if /i "%~1"=="shell" goto shell
goto usage

:gpu
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
exit /b %ERRORLEVEL%

:build
call :needenv || exit /b 1
set "ARCH=%~2"
if "%ARCH%"=="" set "ARCH=7.5;8.6"
set "JOBS=%~3"
if "%JOBS%"=="" set "JOBS=2"
echo Building umv:latest with CUDA_ARCH=%ARCH% and MAX_JOBS=%JOBS% (30 to 60 minutes) ...
docker compose --env-file "%DIR%.env" -f "%DIR%docker-compose.yml" build --build-arg "MAX_JOBS=%JOBS%" --build-arg "CUDA_ARCH=%ARCH%"
if errorlevel 1 (
  echo.
  echo BUILD FAILED. If the last lines mention "cannot allocate memory", raise memory= in
  echo %%USERPROFILE%%\.wslconfig, run "wsl --shutdown" and run this command again.
  exit /b 1
)
echo.
echo Build finished. Next: docker\umv.cmd shell
exit /b 0

:shell
call :needenv || exit /b 1
docker compose --env-file "%DIR%.env" -f "%DIR%docker-compose.yml" run --rm umv
exit /b %ERRORLEVEL%

:needenv
if exist "%DIR%.env" exit /b 0
echo docker\.env is missing. Create it with:  copy docker\.env.windows.example docker\.env
exit /b 1

:usage
echo Usage: docker\umv.cmd gpu ^| build [CUDA_ARCH] [MAX_JOBS] ^| shell
exit /b 2

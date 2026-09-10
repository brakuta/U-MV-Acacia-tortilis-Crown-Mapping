@echo off
rem U-MV helper for Windows (run from PowerShell or cmd, from the repository root, e.g. D:\U-MV).
rem
rem   docker\umv.cmd gpu                check that Docker Desktop can use the GPU (prints name and memory)
rem   docker\umv.cmd build              build the image (works for every supported NVIDIA GPU)
rem   docker\umv.cmd build 8.6 4        optional: compile mmcv GPU kernels for one architecture, 4 jobs
rem   docker\umv.cmd shell              start an interactive container (type exit to leave)
rem
rem The docker compose commands behind these are listed in docs/01_installation.md.
setlocal
set "DIR=%~dp0"
if /i "%~1"=="gpu" goto gpu
if /i "%~1"=="build" goto build
if /i "%~1"=="shell" goto shell
goto usage

:gpu
call :needdocker || exit /b 1
docker run --rm --gpus all ubuntu:22.04 nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap --format=csv
if errorlevel 1 (
  echo.
  echo Docker could not use the GPU.
  echo   libnvidia-ml.so.1 or "legacy" in the message above: run  wsl --update , then quit
  echo   Docker Desktop, run  wsl --shutdown , start Docker Desktop and try again.
  echo   Other messages: see the "If you see this message" table in the guide.
  echo   The image can be built ^(docker\umv.cmd build^) while this is being solved.
  exit /b 1
)
echo.
echo OK: Docker can use the GPU shown above.
exit /b 0

:build
call :needdocker || exit /b 1
call :needenv || exit /b 1
set "ARCH=%~2"
set "JOBS=%~3"
if "%JOBS%"=="" set "JOBS=4"
if "%ARCH%"=="" (
  echo Building umv:latest ^(30 to 60 minutes; nothing may appear for many minutes^) ...
  docker compose --env-file "%DIR%.env" -f "%DIR%docker-compose.yml" build --build-arg "MAX_JOBS=%JOBS%"
) else (
  set "ARCH=%ARCH:+=;%"
  echo Building umv:latest with mmcv GPU kernels for CUDA_ARCH=%ARCH:+=;% and MAX_JOBS=%JOBS% ...
  docker compose --env-file "%DIR%.env" -f "%DIR%docker-compose.yml" build --build-arg "MAX_JOBS=%JOBS%" --build-arg "MMCV_CUDA=1" --build-arg "CUDA_ARCH=%ARCH:+=;%"
)
if errorlevel 1 (
  echo.
  echo BUILD FAILED. Run the same command once more ^(finished stages are reused^).
  echo If it fails again, see the "If you see this message" table in the guide.
  exit /b 1
)
echo.
echo Build finished. Next: docker\umv.cmd shell
exit /b 0

:shell
call :needdocker || exit /b 1
call :needenv || exit /b 1
docker compose --env-file "%DIR%.env" -f "%DIR%docker-compose.yml" run --rm umv
exit /b %ERRORLEVEL%

:needdocker
docker info >nul 2>&1 && exit /b 0
echo Docker Desktop is not running. Start it from the Start menu, wait until the whale icon
echo in the taskbar corner is still, then run this command again.
exit /b 1

:needenv
if exist "%DIR%.env" exit /b 0
echo docker\.env is missing. Create it with:  copy docker\.env.windows.example docker\.env
exit /b 1

:usage
echo Usage: docker\umv.cmd gpu ^| build [CUDA_ARCH [MAX_JOBS]] ^| shell
exit /b 2

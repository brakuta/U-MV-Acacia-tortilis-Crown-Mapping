# 1. Installation

Two routes are supported. The Docker route reproduces the environment in which
the published experiments were executed and is the recommended option for
hand-over to new team members. The manual route documents every dependency for
users who cannot run containers.

## 1.1 Software stack and version rationale

| Component | Version | Reason |
|---|---|---|
| Python | 3.11 | Version of the original container (`docs/reference/environment.frozen.yml`). |
| PyTorch / torchvision | 2.6.0 + cu118 / 0.21.0 | Original experiments; CUDA 11.8 wheels run on driver ≥ 520 (TITAN RTX, RTX A5000). |
| MMEngine | 0.10.7 | Version of the original container. Its checkpoint loader predates the `weights_only=True` default of PyTorch 2.6; `umv` registers a loader that reads the project checkpoints in full (and the image sets `TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1`). |
| MMCV | 2.1.0 (compiled) | Latest release accepted by MMSegmentation 1.2.2 (`mmcv>=2.0.0rc4,<2.2.0`). No prebuilt wheel exists for PyTorch 2.6, so it is compiled from source. The image compiles the operators for CPU by default (`MMCV_CUDA=0`): U-MV executes no MMCV CUDA operator, and the CPU build is GPU-independent and fast. |
| MMSegmentation | 1.2.2 | Last stable 1.x release; equivalent to the `main` branch used originally. |
| transformers / timm | 4.50.0 / 1.0.15 | Versions with which the MambaVision remote code (`trust_remote_code=True`) is known to import (`timm.models.registry`, `timm.models.layers` shims). |
| mamba-ssm | 2.2.4 | Provides `selective_scan_fn`, the CUDA kernel used by the MambaVision mixer. Installed from the prebuilt wheel for torch 2.6 / CUDA 11 (kernels for compute capability 7.0 to 9.0); compiled from source only if the download fails. |
| GDAL / rasterio / geopandas | 3.10 / 1.4 / 1.0 (conda-forge) | GDAL `Polygonize` is used for streaming vectorisation of gigapixel probability rasters. |

MambaVision does **not** call `causal_conv1d`; that package is optional.

## 1.2 Docker route (recommended)

### Prerequisites on Windows 11 / WSL2

1. Install an NVIDIA driver ≥ 520 on Windows (the driver is shared with WSL2; do not install a driver inside WSL2).
2. Install Docker Desktop with the WSL2 backend and enable the Ubuntu distribution under *Settings → Resources → WSL integration*.
3. Verify GPU visibility from WSL2:
   ```bash
   docker run --rm --gpus all ubuntu:22.04 nvidia-smi --query-gpu=name,memory.total,compute_cap --format=csv
   ```
4. Grant WSL2 enough memory for the 1024 × 1024 training tiles (in `%USERPROFILE%\.wslconfig`):
   ```ini
   [wsl2]
   memory=48GB
   swap=16GB
   ```
   then `wsl --shutdown` from PowerShell.

### Build

```bash
git clone https://github.com/brakuta/U-MV-Acacia-tortilis-Crown-Mapping.git
cd U-MV-Acacia-tortilis-Crown-Mapping
git lfs install && git lfs pull      # released checkpoints; not needed with the project archive
cp docker/.env.example docker/.env && nano docker/.env   # DATA_DIR, WEIGHTS_DIR
docker compose --env-file docker/.env -f docker/docker-compose.yml build
```

The build compiles MMCV (CPU operators, a few minutes) and installs the
prebuilt mamba-ssm wheel; it typically takes 15–40 min and works unchanged on
every supported NVIDIA GPU. Three build arguments exist: `MAX_JOBS` (parallel
compiler jobs, default 4; each needs 2–4 GB of RAM, so use 2 where Docker/WSL2
has 16 GB or less), `MMCV_CUDA` (default 0; set 1 to compile MMCV's CUDA
operators, which U-MV itself does not use) and, with `MMCV_CUDA=1`,
`CUDA_ARCH` (default `"7.0;8.0+PTX"`, which runs on every GPU generation from
Volta to Ada; a single value such as `8.6` builds faster for that generation
only):

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml build \
    --build-arg MAX_JOBS=2                          # low-RAM host
docker compose --env-file docker/.env -f docker/docker-compose.yml build \
    --build-arg MMCV_CUDA=1 --build-arg CUDA_ARCH="8.6"   # MMCV CUDA operators
```

`nvidia-smi --query-gpu=name,compute_cap --format=csv` prints the GPU name
and its architecture number (7.5 = TITAN RTX / RTX 20xx, 8.6 = RTX A5000 /
RTX 30xx, 8.0 = A100, 8.9 = RTX 40xx).

### Windows (PowerShell + Docker Desktop)

`docker\umv.cmd` wraps the same compose commands for a PowerShell or cmd
window, so that no long command has to be typed; `docker\.env.windows.example`
is a ready-made `.env` with Windows paths (forward slashes, quoted):

```powershell
copy docker\.env.windows.example docker\.env   # then edit the two paths if needed
docker\umv.cmd gpu                             # Docker can see the GPU? (prints name, memory, arch)
docker\umv.cmd build                           # = compose build (MAX_JOBS=4)
docker\umv.cmd build 8.6 4                     # optional: MMCV CUDA operators for one architecture
docker\umv.cmd shell                           # = compose run --rm umv
```

The wrapper refuses to run when Docker Desktop is stopped or `docker\.env` is
missing, and prints what to do.

The complete Windows procedure, including copying the archive from the share
with `tools\windows\copy_archive.cmd`, is `docs/08_handover_checklist.md`.

### Run

```bash
cp docker/.env.example docker/.env        # set DATA_DIR and WEIGHTS_DIR (quoted if they contain spaces)
docker compose --env-file docker/.env -f docker/docker-compose.yml run --rm umv
# inside the container
python tools/verify_install.py --variant small
```

The compose file bind-mounts the repository at `/workspace/U-MV`, the dataset at
`/data`, the checkpoint folder read-only at `/weights`, a named volume for the
Hugging Face cache and `work_dirs/` for training outputs. `docker/run.sh` offers
the same without compose and reads the same `docker/.env`.

### Offline use

The MambaVision code and ImageNet weights are downloaded once from the
Hugging Face Hub into the `hf_cache` volume:

```bash
python tools/download_backbones.py --variants tiny small base
export HF_HUB_OFFLINE=1      # subsequent runs need no network
```

## 1.3 Manual route (conda)

Install in this order; later steps compile against earlier ones.

```bash
conda create -n umv python=3.11 -y && conda activate umv
# 1. PyTorch (CUDA 11.8 wheels)
pip install torch==2.6.0 torchvision==0.21.0 --index-url https://download.pytorch.org/whl/cu118
# 2. MMEngine and MMCV (compiled; requires nvcc from CUDA 11.8 toolkit on PATH)
pip install mmengine==0.10.7
MMCV_WITH_OPS=1 FORCE_CUDA=1 TORCH_CUDA_ARCH_LIST="7.5;8.6" pip install --no-build-isolation mmcv==2.1.0
# 3. Mamba kernels
pip install packaging ninja && pip install --no-build-isolation -r requirements/mamba.txt
# 4. Geospatial stack (GDAL bindings from conda-forge)
conda install -c conda-forge gdal=3.10 rasterio=1.4 geopandas=1.0 shapely=2.1 pyproj=3.7 pyogrio -y
# 5. Project
pip install -r requirements/core.txt
pip install --no-deps -e .
python tools/verify_install.py
```

`pip install -e .` makes `umv` importable from any working directory; the
scripts in `tools/` also work without installation because they add the
repository root to `sys.path`.

## 1.4 Verification

```bash
python tools/verify_install.py                    # imports, CUDA, mamba_ssm, mmcv.ops
python tools/verify_install.py --variant small    # builds U-MV-small, forward pass, peak VRAM
python -m pytest tests -q                         # tiling / vectorisation unit tests (CPU)
```

Expected: `RESULT: OK`, and for the second command a forward pass of a
512 × 512 tensor producing logits of shape `(1, 2, 512, 512)`.

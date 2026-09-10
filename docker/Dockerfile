# ---------------------------------------------------------------------------
# U-MV (U-shaped MambaVision) - reproducible GPU environment
#
# Base image: the official PyTorch 2.6.0 / CUDA 11.8 / cuDNN 9 *devel* image
# (Ubuntu 22.04, Miniforge Python 3.11).  This mirrors the environment in which
# the published experiments were run (docs/reference/environment.frozen.yml).
#
# Build (from the repository root; 15-40 min, most of it the mmcv compilation):
#   docker compose --env-file docker/.env -f docker/docker-compose.yml build
# Run:
#   docker compose --env-file docker/.env -f docker/docker-compose.yml run --rm umv
# ---------------------------------------------------------------------------
FROM pytorch/pytorch:2.6.0-cuda11.8-cudnn9-devel

# Build-time knobs (docker compose build --build-arg NAME=value):
#   MAX_JOBS  : parallel compiler jobs for mmcv (each needs 2-4 GB RAM; 4 is safe with
#               >= 24 GB available to Docker/WSL2, 8 with >= 40 GB).
#   MMCV_CUDA : 0 (default) compiles mmcv's operators for CPU only.  U-MV executes no mmcv
#               CUDA operator (plain convolutions, BatchNorm, CE + Dice losses), so the
#               CPU build is sufficient, runs on every GPU and takes a few minutes.
#               1 compiles the CUDA operators as well (needed only for other mmseg heads
#               such as PointRend/Mask2Former); then CUDA_ARCH selects the GPU generations.
#   CUDA_ARCH : GPU architectures for MMCV_CUDA=1.  "7.0;8.0+PTX" runs on every NVIDIA GPU
#               from Volta/Turing (7.x) to Ada (8.9) and later; a single value such as
#               "8.6" (RTX 30xx / A-series) builds faster but runs on that generation only.
#   mamba-ssm is installed from its prebuilt wheel (kernels for 7.0-9.0 included), so
#   these arguments do not affect it.
ARG MAX_JOBS=4
ARG MMCV_CUDA=0
ARG CUDA_ARCH="7.0;8.0+PTX"

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Dubai \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    TORCH_CUDA_ARCH_LIST=${CUDA_ARCH} \
    FORCE_CUDA=${MMCV_CUDA} \
    MMCV_WITH_OPS=1 \
    MAX_JOBS=${MAX_JOBS} \
    TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1 \
    HF_HOME=/workspace/hf_cache

# --- system packages -------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        git build-essential ninja-build ca-certificates curl \
        libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# --- geospatial stack via conda-forge -------------------------------------
# GDAL Python bindings are not reliably pip-installable; conda-forge provides a
# consistent GDAL/PROJ/GEOS/rasterio/geopandas set (versions as in the frozen env).
RUN conda install -y --override-channels -c conda-forge \
        "python=3.11" "gdal=3.10" "rasterio=1.4" "geopandas=1.0" "shapely=2.1" \
        "pyproj=3.7" "pyogrio" "numpy=2.2" \
    && conda clean -afy

# --- OpenMMLab: mmengine (pure python) + mmcv (compiled from source) --------
# setuptools < 82 keeps pkg_resources, which mmcv 2.1.0's setup.py imports.
RUN pip install "setuptools<82" wheel "numpy>=2.2,<2.3" opencv-python==4.11.0.86 mmengine==0.10.7 && \
    pip install --no-build-isolation -v mmcv==2.1.0 && \
    python -c "import mmcv, mmcv.ops; print('mmcv', mmcv.__version__, 'ops OK')"

# --- project dependencies (mmseg, transformers, timm, ...) ------------------
WORKDIR /workspace/U-MV
COPY requirements ./requirements
RUN pip install -r requirements/core.txt

# --- Mamba selective-scan kernels ------------------------------------------
# Prebuilt wheel for torch 2.6 / CUDA 11 / Python 3.11 (no compilation); --no-deps keeps
# the transformers pin of core.txt.  Fallback: compile from source with few jobs.
RUN curl -fL --retry 3 -o /tmp/mamba.whl \
      https://github.com/state-spaces/mamba/releases/download/v2.2.4/mamba_ssm-2.2.4+cu11torch2.6cxx11abiFALSE-cp311-cp311-linux_x86_64.whl \
    && pip install --no-deps /tmp/mamba.whl && rm -f /tmp/mamba.whl \
    || (echo "wheel download failed; compiling mamba-ssm from source" && \
        MAX_JOBS=2 MAMBA_FORCE_BUILD=TRUE pip install --no-build-isolation --no-deps mamba-ssm==2.2.4) \
    && python -c "from mamba_ssm.ops.selective_scan_interface import selective_scan_fn; print('mamba_ssm OK')"

# --- project code (editable) -----------------------------------------------
COPY . .
RUN pip install --no-build-isolation --no-deps -e . && python -c "import umv; print('umv', umv.__version__)"

RUN mkdir -p /data /workspace/hf_cache /workspace/U-MV/work_dirs
VOLUME ["/data", "/workspace/hf_cache", "/workspace/U-MV/work_dirs"]
CMD ["/bin/bash"]

# MMSegmentation 1.2.2 on PyTorch 2.6.0 / CUDA 11.8 with a geospatial stack.
#   docker compose --env-file docker/.env -f docker/docker-compose.yml build   (30-50 min: mmcv is compiled)
FROM pytorch/pytorch:2.6.0-cuda11.8-cudnn9-devel

# Build-time knobs (override: docker compose build --build-arg MAX_JOBS=2 --build-arg CUDA_ARCH="7.5")
#   MAX_JOBS  : parallel nvcc jobs when compiling mmcv; each needs ~2 GB RAM. Use 2 on machines
#               where Docker/WSL2 has <= 16 GB, 4 for 32 GB, 8 for 64 GB.
#   CUDA_ARCH : GPU architectures to compile for. Only your GPU is needed:
#               TITAN RTX / RTX 20xx = 7.5, RTX A5000 / RTX 30xx = 8.6, A100 = 8.0, RTX 40xx = 8.9.
#               Compiling several architectures multiplies memory and time.
ARG MAX_JOBS=4
ARG CUDA_ARCH="7.5;8.6"

ARG DEBIAN_FRONTEND=noninteractive
ENV PIP_NO_CACHE_DIR=1 PYTHONUNBUFFERED=1 \
    TORCH_CUDA_ARCH_LIST=${CUDA_ARCH} FORCE_CUDA=1 MMCV_WITH_OPS=1 MAX_JOBS=${MAX_JOBS}

RUN apt-get update && apt-get install -y --no-install-recommends \
        git build-essential ninja-build ca-certificates curl tmux \
        libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# geospatial stack (GDAL Python bindings are not reliably pip-installable)
RUN conda install -y --override-channels -c conda-forge \
        "python=3.11" "gdal=3.10" "rasterio=1.4" "geopandas=1.0" "shapely=2.1" "pyproj=3.7" "pyogrio" "numpy=2.2" \
    && conda clean -afy

# OpenMMLab: mmengine (pure python) + mmcv 2.1.0 compiled for this PyTorch + mmsegmentation
RUN pip install mmengine==0.10.7 && \
    pip install --no-build-isolation -v mmcv==2.1.0 && \
    python -c "import mmcv, mmcv.ops; print('mmcv', mmcv.__version__, 'ops OK')"

WORKDIR /workspace/tutorial
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
RUN pip install --no-deps -e . && python -c "import geoseg, mmseg; print('geoseg', geoseg.__version__, 'mmseg', mmseg.__version__)"

RUN mkdir -p /data /workspace/tutorial/work_dirs
VOLUME ["/data", "/workspace/tutorial/work_dirs"]
CMD ["/bin/bash"]

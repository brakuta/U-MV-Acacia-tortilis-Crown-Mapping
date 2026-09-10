# 6. Troubleshooting

| Symptom | Cause | Remedy |
|---|---|---|
| `ModuleNotFoundError: No module named 'mmcv._ext'` | `mmcv-lite` or a wheel built for another PyTorch/CUDA is installed. | Reinstall MMCV from source against the active PyTorch (`docs/01_installation.md`, step 2) or use the Docker image. |
| `No module named 'mamba_ssm'` / `selective_scan_cuda` import error | Kernels not built or built for a different PyTorch. | `pip install --no-build-isolation mamba-ssm==2.2.4` with `nvcc` available; confirm with `tools/verify_install.py`. |
| `KeyError: 'MambaVisionBackbone is not in the mmseg::model registry'` | `umv` not imported. | Configs must contain `custom_imports = dict(imports=['umv'])` (all shipped configs do); run scripts from the repository root or `pip install -e .`. |
| `OSError: We couldn't connect to 'https://huggingface.co'` | Backbone download blocked (proxy, offline). | Pre-download on a connected machine (`tools/download_backbones.py`), copy `hf_cache/` and set `HF_HUB_OFFLINE=1`. |
| `UnpicklingError: invalid load key, 'v'` when loading a `.pth` | The file is a Git LFS pointer. | `git lfs install && git lfs pull` (see `Pretrained_Weights/README.md`). |
| `_pickle.UnpicklingError: Weights only load failed` | PyTorch ≥ 2.6 with an old MMEngine. | Use MMEngine 0.10.7 (pinned). |
| `size mismatch for decode_head.decoder_stages.0.0.weight` | Checkpoint and config variant differ. | `python tools/inspect_checkpoint.py <ckpt>` prints the matching config. |
| Validation mIoU ≈ 50 % or all-background predictions | Masks are 0/255 or RGB, or wrong suffix. | Re-encode masks as 0/1 uint8 single band (`docs/02_data_preparation.md`, §2.3). |
| Test mIoU several points below the paper | Band order or resolution mismatch. | Ensure RGB orthomosaics, 2.5–3 cm GSD, no `--band-order bgr`. |
| CUDA out of memory during training | 1024² tiles with batch 2 need ~20 GB on U-MV-b. | Use `--amp`, or `train_dataloader.batch_size=1` with doubled iterations. |
| WSL2 freezes; GPU memory shows 24 GB + system RAM use | CUDA sysmem fallback exhausting host RAM. | Set *Prefer No Sysmem Fallback* in the NVIDIA Control Panel; reduce batch size; drop page cache between runs. |
| Docker build fails at the MMCV step with `cannot allocate memory` / `Failed to build mmcv` | too many parallel compiler jobs for the RAM given to Docker/WSL2 | rebuild with `--build-arg MAX_JOBS=2`; raise `memory=` in `.wslconfig`; cached layers are reused |
| `_pickle.UnpicklingError: Weights only load failed ... HistoryBuffer` when a checkpoint is loaded | PyTorch ≥ 2.6 defaults `torch.load` to `weights_only=True`; mmengine 0.10.x does not pass the argument | import `umv` before loading (all tools do; it registers a full loader) or set `TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1` (set in the image) |
| `ERROR: the checkpoint is U-MV-small but the config is U-MV-base` | config and checkpoint belong to different variants | use the config named in the message; `tools/inspect_checkpoint.py` prints the variant |
| `ERROR: N model parameters are not in the checkpoint` | key layout mismatch (a foreign checkpoint, or a truncated download) | `tools/inspect_checkpoint.py <file> --keys`; the released checkpoints have `backbone.backbone.model.*` keys |
| `RuntimeError: CUDA error: no kernel image is available for execution on the device` | MMCV CUDA operators (`MMCV_CUDA=1`) were compiled for another GPU generation | rebuild with the default `MMCV_CUDA=0`, or `CUDA_ARCH="7.0;8.0+PTX"` |
| `AssertionError: The image size in a batch should be the same` during `tools/test.py` | test tiles of different sizes with `batch_size > 1` | keep `test_dataloader.batch_size=1` (the default) |
| `CUDA out of memory` during `tools/test.py` or `geospatial_inference.py` on a 12 GB GPU | another process holds GPU memory, or a large batch | close GIS/browser applications; `--batch-size 2` for the geospatial tool; `--cfg-options test_cfg.fp16=True` for `test.py` |
| `docker\umv.cmd`: `Docker Desktop is not running` | the Docker engine is stopped | start Docker Desktop and wait for the whale icon to be still |
| `Clone succeeded, but checkout failed` / `over its data quota` during `git clone` | Git LFS tried to download the released checkpoints | `$env:GIT_LFS_SKIP_SMUDGE = "1"` before `git clone`; use the archive's work directories |
| `RuntimeError: DataLoader worker ... Bus error` / shared-memory errors in Docker | `/dev/shm` too small. | Run with `--ipc=host` (compose file does) or `--shm-size=16g`. |
| `osgeo` missing in inference | GDAL Python bindings absent. | Install via conda-forge; the rasterio fallback only handles rasters ≤ 1.5 gigapixels. |
| Straight cut lines in the crown map | `--overlap` below ~128 or `--blend` misconfigured. | Keep the defaults (overlap 256, centre-crop). |
| Very slow inference from `/mnt/<drive>` | Windows filesystem access from WSL2. | Use `--scratch-dir /tmp/geospatial_work` and COG inputs. |
| `img_ratios` `NameError` when loading a config | Legacy dataset config. | Fixed in this revision; `img_ratios` is defined in `configs/_base_/datasets/uav_acacia_dataset.py`. |

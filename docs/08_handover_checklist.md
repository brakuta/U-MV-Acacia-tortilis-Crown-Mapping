# 8. Hand-over procedure: from scratch to a verified model

This chapter is the complete procedure for the receiving team member. It
assumes nothing has been done yet, a Windows 11 workstation with an NVIDIA
GPU, read access to the project share (`Z:`), and Windows PowerShell as the
shell. Do the steps in order; every command is one line even where it wraps
on the page, and each step ends with what you should see. The other chapters
are reference material; this one is sufficient on its own.

## What you receive

| Item | Where | What it is |
|---|---|---|
| Code | https://github.com/brakuta/U-MV-Acacia-tortilis-Crown-Mapping | model, configs, Docker build, tools, tests, this guide |
| Dataset | `Z:\...\A.tortilis_Data & Model\Data used to build the model` | `img_dir/` and `ann_dir/` with `train`, `val`, `test2`, `Generalizability` (1024 × 1024 tiles, ~32 GB) |
| Trained models | `Z:\...\A.tortilis_Data & Model\A.tortilis Models\Pretrained weights` | three MMSegmentation work directories with checkpoints, training configs and logs (~2.5 GB) |

The archive also contains `A.tortilis Models\MMsegmentation Folder`; it is the
superseded container workspace and is **not** needed.

Facts to know before starting:

* **Which weights.** `best_mIoU_iter_*.pth` in each work directory (checkpoint
  selected on validation mIoU, used for the paper's test results): tiny
  `best_mIoU_iter_100000.pth`, small `best_mIoU_iter_95000.pth`, base
  `best_mIoU_iter_60000.pth`. Every tool accepts the folder in place of the
  file and selects it automatically. The files on GitHub are byte-identical
  copies; Git LFS is not needed.
* **Which model.** Start with U-MV-small; it produced the regional maps and
  has the best generalisability figures.
* **Dataset.** The archive holds 4 893 (train), 2 407 (val), 3 123 (test2)
  and 2 162 (Generalizability) tiles. The published models were trained on
  26 615 tiles; the training folder was pruned afterwards. Evaluation and
  inference are exact; retraining reproduces the recipe, not the model.
* **Confidentiality.** The dataset is not publicly shareable.

## Step 0 — Prerequisites (once per machine)

| Need | How to get or check it |
|---|---|
| NVIDIA driver ≥ 520 | `nvidia-smi` in PowerShell prints a table with the GPU name and driver version; otherwise install the driver from nvidia.com |
| Docker Desktop | install from docker.com; in Settings → General keep "Use the WSL 2 based engine"; a steady whale icon in the tray means the engine runs |
| Git | `git --version`; otherwise install Git for Windows (git-scm.com) with default options |
| Disk | ~40 GB free on the local data disk for the archive copy; ~40 GB on `C:` for the Docker image |
| RAM | Task Manager → Performance → Memory: note the total (needed in step 2) |
| Internet | required for the image build and the first model download |

Open PowerShell (Start → type `PowerShell` → Enter) for all commands that are
not marked "inside the container".

## Step 1 — Copy the archive to a local disk (PowerShell)

Reading tiles from the share is too slow for training and evaluation. Copy
to a short local path **without** the `&` character (Docker and PowerShell
both dislike it); `D:\A.tortilis_Data_Model` is used below. Run the three
lines one at a time:

```powershell
$Z = "Z:\Final Geodatabase\Vegetation_Geodatabase\3_Mapping Acacia tortilis Trees\A.tortilis_Data & Model"
robocopy "$Z\Data used to build the model" "D:\A.tortilis_Data_Model\Data used to build the model" /E /XF *.aux.xml *.ovr *.xml /MT:16 /R:2 /W:5
robocopy "$Z\A.tortilis Models\Pretrained weights" "D:\A.tortilis_Data_Model\A.tortilis Models\Pretrained weights" /E /MT:16 /R:2 /W:5
```

**You should see:** in each summary, *Failed* = 0 and *Copied* + *Skipped* =
*Total*. Then check the tiles:

```powershell
$root = "D:\A.tortilis_Data_Model\Data used to build the model"; foreach ($s in 'train','val','test2','Generalizability') { "{0,-18} img={1,6} ann={2,6}" -f $s, (Get-ChildItem "$root\img_dir\$s" -Filter *.tif -File).Count, (Get-ChildItem "$root\ann_dir\$s" -Filter *.tif -File).Count }
```

**You should see:** `train 4893/4893`, `val 2407/2407`, `test2 3123/3123`,
`Generalizability 2162/2162`. If the archive was copied earlier to another
place (for example under `D:\Vegetiation\...`), keep it and use that path in
step 4; only make sure its name contains no `&`.

## Step 2 — Give Docker enough memory (once)

Docker Desktop runs inside WSL2; the image build compiles software and needs
several GB. Set the WSL2 limit below the machine's total RAM (24GB on a
32 GB machine, 40GB on 64 GB):

```powershell
notepad $env:USERPROFILE\.wslconfig
```

Make the file's content exactly the following, save with Ctrl+S, close:

```
[wsl2]
memory=24GB
swap=8GB
```

Apply it and wait about a minute until Docker Desktop shows "Engine running"
again:

```powershell
wsl --shutdown
```

## Step 3 — Confirm Docker can use the GPU

```powershell
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

**You should see:** the GPU table printed from inside a container. Note the
GPU name. *If not:* Docker Desktop → Settings → Resources → WSL integration →
enable the default distribution → Apply & restart.

## Step 4 — Get the code and point it at the data

```powershell
cd D:\
git clone https://github.com/brakuta/U-MV-Acacia-tortilis-Crown-Mapping.git U-MV
cd D:\U-MV
copy docker\.env.example docker\.env
notepad docker\.env
```

(If the repository was cloned before, `cd` into it and run `git pull`
instead of cloning.) Replace everything in Notepad with the three lines
below, adjusted to where the archive was copied in step 1, keep the quotes,
save, close:

```
DATA_DIR="D:\A.tortilis_Data_Model\Data used to build the model"
WEIGHTS_DIR="D:\A.tortilis_Data_Model\A.tortilis Models\Pretrained weights"
HF_HUB_OFFLINE=0
```

```powershell
type docker\.env
```

**You should see:** the three lines exactly as written.

## Step 5 — Find the GPU architecture number

From the GPU name of step 3:

| GPU | `CUDA_ARCH` |
|---|---|
| TITAN RTX, RTX 2060 / 2070 / 2080, Quadro RTX 4000–8000 | `7.5` |
| RTX A4000 / A5000 / A6000, RTX 3060 / 3070 / 3080 / 3090 | `8.6` |
| A100 | `8.0` |
| RTX 4070 / 4080 / 4090, RTX 6000 Ada | `8.9` |

## Step 6 — Build the image (30 to 60 minutes)

Use the `CUDA_ARCH` of step 5. Keep `MAX_JOBS=2` unless the machine has 64 GB
of RAM (then `4`):

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml build --build-arg MAX_JOBS=2 --build-arg CUDA_ARCH="7.5"
```

Leave the window open and the computer awake. Stages in order: base image
download (`sha256:` lines), `apt` packages, `conda` packages, the MMCV
compilation (long, few visible lines), `mamba-ssm`, the project install.

**You should see:** the build ends without `ERROR`, and

```powershell
docker images umv
```

prints one line with `umv` and `latest`.

*`ERROR ... cannot allocate memory`:* raise `memory=` in step 2, run
`wsl --shutdown`, repeat step 6 (finished stages are reused). *Any other
`ERROR`:* copy the last 60 lines and send them.

## Step 7 — Start the container

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml run --rm umv
```

**You should see:** the prompt becomes `root@...:/workspace/U-MV#`. You are
now inside Linux; steps 8 to 12 run here. Check the mounts:

```bash
ls /data
ls /weights
nvidia-smi
```

**You should see:** `ann_dir  img_dir`; the three `mambavision-*` folders; the
GPU table. *If `/data` is empty:* type `exit`, correct `docker\.env` (step 4),
repeat step 7.

## Step 8 — Verify the software (inside the container)

```bash
python tools/verify_install.py --variant small
```

The first run downloads the MambaVision-S encoder (~200 MB) from the Hugging
Face Hub.

**You should see:** every library with a version, `CUDA available: True` with
the GPU name, `mamba_ssm selective_scan_fn: ok`, `mmcv.ops ... ok`,
`forward (1, 3, 512, 512) -> (1, 2, 512, 512)`, and `RESULT: OK`.

## Step 9 — Verify the dataset (inside the container)

```bash
python tools/check_dataset.py /data --splits train val test2 Generalizability
```

**You should see:** the four pair counts of step 1, mask values `[0, 1]`, and
`RESULT: OK`.

## Step 10 — Identify the checkpoint (inside the container)

```bash
python tools/inspect_checkpoint.py "/weights/mambavision-s_generic-unet_acacia-88"
```

**You should see:** `"path": ".../best_mIoU_iter_95000.pth"`,
`"variant": "small"`, `"iteration": 95000`.

## Step 11 — Reproduce the published accuracy (inside the container)

```bash
CKPT="/weights/mambavision-s_generic-unet_acacia-88"
python tools/test.py configs/mambavision/U-MV-small.py "$CKPT" --test-split test2
python tools/test.py configs/mambavision/U-MV-small.py "$CKPT" --test-split Generalizability
```

Each run takes 10 to 20 minutes and ends with a metric table.

**You should see:** on `test2`, `mIoU` ≈ 85.4 and `mFscore` ≈ 91.6 (paper:
85.38 / 91.58); on `Generalizability`, ≈ 89.5 and ≈ 94.2 (paper: 89.48 /
94.17). Send both tables to the project lead. Optional: repeat with
`U-MV-tiny.py` + `mambavision-t_generic-unet_acacia` (tiny: 85.44 / 91.61 on
`test2`) and `U-MV-base.py` + `mambavision-b_generic-unet_acacia` (base:
85.30 / 91.52).

## Step 12 — Map one orthomosaic (inside the container, optional)

From Windows, put a GeoTIFF orthomosaic into a new folder `orthos` inside
`Data used to build the model`. Then:

```bash
python tools/geospatial_inference.py --config configs/mambavision/U-MV-small.py --checkpoint "$CKPT" --input "/data/orthos/<name>.tif" --output "/data/predictions/<name>_crowns.gpkg" --scratch-dir /tmp/geospatial_work --min-area 1.0 --save-prob
```

**You should see:** progress bars, then a JSON summary with `polygons`. The
GeoPackage appears in Windows under `...\Data used to build the model\predictions`
and opens in ArcGIS Pro or QGIS on top of the orthomosaic, with `area` and
`mean_prob` attributes. Many orthomosaics: `tools/batch_geospatial_inference.py`
with `--input-dir` / `--output-dir` (chapter on inference).

## Step 13 — Leave and come back

`exit` leaves the container. Next time only step 7 onward is needed (and
`git pull` in `D:\U-MV` to receive updates); the image stays built. Training
outputs go to `D:\U-MV\work_dirs`, predictions to wherever `--output` points.

## Alternative: the WSL2 Ubuntu terminal

The same steps work from an Ubuntu (WSL2) terminal with Linux paths: the
archive is visible as `/mnt/d/A.tortilis_Data_Model/...`, `nano` replaces
`notepad`, and `docker compose ... run --rm umv` is identical. Nothing inside
the container changes.

## If something goes wrong

Consult the troubleshooting chapter first. When reporting a problem, give the
step number, the exact command, the last 60 lines of output and, for steps 8
onward, the output of `python tools/verify_install.py`.

Contact: Mohamed Barakat A. Gibril (mbgibril@sharjah.ac.ae).

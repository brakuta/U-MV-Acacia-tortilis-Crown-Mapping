# 8. Setup procedure (Windows, from scratch)

This chapter is the complete procedure for the receiving team member. It
starts from an empty Windows 11 workstation with an NVIDIA GPU, read access
to the project share (`Z:`), and Windows PowerShell. Fourteen steps, in
order. Each step says where the commands run (PowerShell or inside the
container), gives the commands, and states what a successful result looks
like. Commands are copied line by line; a line ending in a backslash
continues on the next line and is pasted together with it. The other chapters are reference material and are not needed to
complete this one.

Overview (steps 1 to 8 are done once; steps 9 to 12 verify the installation):

| Step | What | Where | Time |
|---|---|---|---|
| 1 | Prerequisites: driver, Docker Desktop, Git | Windows | 10 min |
| 2 | Download the code (`git clone`) | PowerShell | 1 min |
| 3 | Copy the archive from `Z:` to a local disk | PowerShell | 10–60 min |
| 4 | Give Docker enough memory | PowerShell | 2 min |
| 5 | Confirm Docker can use the GPU | PowerShell | 1 min |
| 6 | Tell Docker where the data is (`docker\.env`) | PowerShell | 1 min |
| 7 | Build the image | PowerShell | 30–60 min |
| 8 | Start the container | PowerShell | 1 min |
| 9 | Verify the software | container | 2 min |
| 10 | Verify the dataset | container | 1 min |
| 11 | Identify the checkpoint | container | 1 min |
| 12 | Reproduce the published accuracy | container | 30 min |
| 13 | Map an orthomosaic (optional) | container | varies |
| 14 | Leave and come back | both | – |

Facts to know before starting:

* **Which weights.** `best_mIoU_iter_*.pth` in each work directory (the
  checkpoint with the best validation mIoU, used for the paper's test
  results): tiny `best_mIoU_iter_100000.pth`, small `best_mIoU_iter_95000.pth`,
  base `best_mIoU_iter_60000.pth`. Every tool accepts the folder instead of the
  file and selects it automatically. The files on GitHub are byte-identical
  copies; Git LFS is not needed.
* **Which model.** Start with U-MV-small; it produced the regional maps and
  has the best generalisability figures.
* **Dataset.** The archive holds 4 893 (train), 2 407 (val), 3 123 (test2)
  and 2 162 (Generalizability) tiles of 1024 × 1024 pixels. The published
  models were trained on 26 615 tiles; the training folder was pruned
  afterwards. Evaluation and inference are exact; retraining reproduces the
  recipe, not the model.
* **Confidentiality.** The dataset is not publicly shareable.

## Step 1 — Prerequisites

> Windows · once per machine

| Need | How to get or check it |
|---|---|
| NVIDIA driver ≥ 520 | open PowerShell (Start → type `PowerShell` → Enter) and run `nvidia-smi`; a table with the GPU name and driver version must appear. Otherwise install the driver from nvidia.com |
| Docker Desktop | install from docker.com and start it; in Settings → General keep "Use the WSL 2 based engine". A steady whale icon in the tray means the engine runs |
| Git | `git --version` in PowerShell; otherwise install Git for Windows (git-scm.com) with the default options |
| Disk | about 40 GB free on the local data disk (`D:` below) and 40 GB on `C:` for the Docker image |
| RAM | Task Manager → Performance → Memory: note the total (needed in step 4) |
| Internet | needed for steps 2, 5, 7 and 9 |

Use one PowerShell window for the whole procedure. Commands marked "inside
the container" (steps 9 to 13) are typed in the same window after step 8.

## Step 2 — Download the code

> PowerShell · once · the repository is public

```powershell
cd D:\
git clone https://github.com/brakuta/U-MV-Acacia-tortilis-Crown-Mapping.git U-MV
cd D:\U-MV
git log -1 --format=%cd
```

**You should see:** a `Cloning into 'U-MV'...` message and then the date of
the latest commit. The code is now in `D:\U-MV`. *If a copy from an earlier
attempt exists* (any folder that already contains `docker\Dockerfile`),
rename or delete it first, or open it and run `git pull` instead of cloning.
Any other location works; use it wherever `D:\U-MV` appears below.

## Step 3 — Copy the archive to a local disk

> PowerShell, in `D:\U-MV` · once · 10 to 60 minutes

Tiles must not be read from the share (too slow). The copy goes to a short
path **without** the `&` character; `D:\A.tortilis_Data_Model` is used
everywhere below. One command does the copy, checks the tile counts and
prints the two lines needed in step 6:

```powershell
tools\windows\copy_archive.cmd D:\A.tortilis_Data_Model
```

**You should see:** two robocopy summaries with `Failed 0`, then the tile
counts marked `ok` (`train 4893`, `val 2407`, `test2 3123`,
`Generalizability 2162`), three `best_mIoU_iter_*.pth` paths, and
`RESULT: OK`. *If the archive was copied earlier* to another folder whose
name contains no `&`, keep it and skip this step; note its path for step 6.
*If the source is not found*, connect the `Z:` drive (File Explorer → This
PC) and run the command again. The script can be run again at any time; it
only copies what is missing. (It runs `tools\windows\copy_archive.ps1`, which
can also be given `-Source` if the share is mounted under another letter.)

## Step 4 — Give Docker enough memory

> PowerShell · once

Docker Desktop runs inside WSL2, and the image build compiles software that
needs several GB. Set the WSL2 limit below the machine's total RAM: 24GB on
a 32 GB machine, 40GB on 64 GB.

```powershell
notepad $env:USERPROFILE\.wslconfig
```

Notepad asks whether to create the file: answer Yes. Make its content
exactly the following, save with Ctrl+S, close Notepad:

```
[wsl2]
memory=24GB
swap=8GB
```

Apply the setting (Docker Desktop restarts its engine; wait until the tray
icon is steady again, about one minute):

```powershell
wsl --shutdown
```

## Step 5 — Confirm Docker can use the GPU

> PowerShell, in `D:\U-MV` · once

```powershell
docker\umv.cmd gpu
```

**You should see:** the same GPU table as `nvidia-smi`, printed from inside
a container (the first run downloads a small test image). Note the GPU name
for step 7. *If it fails:* Docker Desktop → Settings → Resources → WSL
integration → enable the default distribution → Apply & restart, then repeat.

## Step 6 — Tell Docker where the data is

> PowerShell, in `D:\U-MV` · once

```powershell
copy docker\.env.windows.example docker\.env
type docker\.env
```

**You should see:** the file content, whose two path lines are

```
DATA_DIR="D:/A.tortilis_Data_Model/Data used to build the model"
WEIGHTS_DIR="D:/A.tortilis_Data_Model/A.tortilis Models/Pretrained weights"
```

These are correct if step 3 used `D:\A.tortilis_Data_Model`. Otherwise run
`notepad docker\.env` and replace the two paths with the ones printed at the
end of step 3 (forward slashes, quotes kept), save, close.

## Step 7 — Build the image

> PowerShell, in `D:\U-MV` · once · 30 to 60 minutes

Find the architecture number of the GPU named in step 5:

| GPU | Number |
|---|---|
| TITAN RTX, RTX 2060 / 2070 / 2080, Quadro RTX 4000–8000 | `7.5` |
| RTX A4000 / A5000 / A6000, RTX 3060 / 3070 / 3080 / 3090 | `8.6` |
| A100 | `8.0` |
| RTX 4070 / 4080 / 4090, RTX 6000 Ada | `8.9` |

Then build with that number (`7.5` is shown; replace it if different):

```powershell
docker\umv.cmd build 7.5
```

Leave the window open and the computer awake. The stages appear in this
order: base image download (`sha256:` lines), `apt` packages, `conda`
packages, the MMCV compilation (long, few visible lines), `mamba-ssm`, the
project install.

**You should see:** `Build finished. Next: docker\umv.cmd shell`. To
double-check, `docker images umv` prints one line with `umv` and `latest`.

*`cannot allocate memory`:* raise `memory=` in step 4, run `wsl --shutdown`,
run the build command again (finished stages are reused). *Any other
`ERROR`:* copy the last 60 lines of the window and send them to the project
lead. On a machine with 64 GB of RAM the build can use four compiler jobs:
`docker\umv.cmd build 7.5 4`.

## Step 8 — Start the container

> PowerShell, in `D:\U-MV` · every session

```powershell
docker\umv.cmd shell
```

**You should see:** the prompt changes to `root@...:/workspace/U-MV#`. You
are now inside Linux; steps 9 to 13 are typed here. Check the mounts:

```bash
ls /data
ls /weights
nvidia-smi
```

**You should see:** `ann_dir  img_dir`; three `mambavision-*` folders; the
GPU table. *If `/data` or `/weights` is empty:* type `exit`, correct
`docker\.env` (step 6), run step 8 again.

## Step 9 — Verify the software

> inside the container · once

```bash
python tools/verify_install.py --variant small
```

The first run downloads the MambaVision-S encoder (about 200 MB) from the
Hugging Face Hub.

**You should see:** every library with a version, `CUDA available: True`
with the GPU name, `mamba_ssm selective_scan_fn: ok`, `mmcv.ops ... ok`,
`forward (1, 3, 512, 512) -> (1, 2, 512, 512)`, and `RESULT: OK`.

## Step 10 — Verify the dataset

> inside the container · once

```bash
python tools/check_dataset.py /data --splits train val test2 Generalizability
```

**You should see:** the four tile counts of step 3, mask values `[0, 1]`,
and `RESULT: OK`.

## Step 11 — Identify the checkpoint

> inside the container · once

```bash
python tools/inspect_checkpoint.py "/weights/mambavision-s_generic-unet_acacia-88"
```

**You should see:** `"path": ".../best_mIoU_iter_95000.pth"`,
`"variant": "small"`, `"iteration": 95000`.

## Step 12 — Reproduce the published accuracy

> inside the container · once · 10 to 20 minutes per run

```bash
CKPT="/weights/mambavision-s_generic-unet_acacia-88"
python tools/test.py configs/mambavision/U-MV-small.py "$CKPT" --test-split test2
python tools/test.py configs/mambavision/U-MV-small.py "$CKPT" --test-split Generalizability
```

Each run ends with a metric table.

**You should see:** on `test2`, `mIoU` ≈ 85.4 and `mFscore` ≈ 91.6 (paper:
85.38 / 91.58); on `Generalizability`, ≈ 89.5 and ≈ 94.2 (paper: 89.48 /
94.17). Send both tables to the project lead. The installation is now
verified.

Optional, for the other two models:

```bash
CKPT_T="/weights/mambavision-t_generic-unet_acacia"
python tools/test.py configs/mambavision/U-MV-tiny.py "$CKPT_T" --test-split test2
CKPT_B="/weights/mambavision-b_generic-unet_acacia"
python tools/test.py configs/mambavision/U-MV-base.py "$CKPT_B" --test-split test2
```

(paper: tiny 85.44 / 91.61, base 85.30 / 91.52).

## Step 13 — Map an orthomosaic (optional)

> inside the container · per orthomosaic

In Windows, create the folder `orthos` inside
`D:\A.tortilis_Data_Model\Data used to build the model` and put a GeoTIFF
orthomosaic in it (any name; `site.tif` is used below). Then:

```bash
CKPT="/weights/mambavision-s_generic-unet_acacia-88"
python tools/geospatial_inference.py \
    --config configs/mambavision/U-MV-small.py --checkpoint "$CKPT" \
    --input /data/orthos/site.tif --output /data/predictions/site_crowns.gpkg \
    --scratch-dir /tmp/geospatial_work --min-area 1.0 --save-prob
```

(The command is one bash command written over four lines; the trailing
backslashes join them. Paste all four lines together.)

**You should see:** progress bars and a JSON summary with the number of
`polygons`. In Windows the result is
`...\Data used to build the model\predictions\site_crowns.gpkg`; it opens in
ArcGIS Pro or QGIS on top of the orthomosaic, with `area` and `mean_prob`
attributes. For a folder of orthomosaics use
`tools/batch_geospatial_inference.py` with `--input-dir` and `--output-dir`
(see the inference chapter).

## Step 14 — Leave and come back

> both

`exit` leaves the container. The image stays built; next time only step 8
is needed (`cd D:\U-MV` then `docker\umv.cmd shell`). To receive code
updates, run `git pull` in `D:\U-MV` before step 8; the container sees the
new files immediately. Training outputs go to `D:\U-MV\work_dirs`,
predictions to wherever `--output` points.

## Alternative: the WSL2 Ubuntu terminal

The same steps work from an Ubuntu (WSL2) terminal with Linux commands: the
archive is visible as `/mnt/d/A.tortilis_Data_Model/...`, `nano` replaces
`notepad`, `docker/.env.example` replaces `docker/.env.windows.example`, and
the `docker compose ... build` and `run --rm umv` commands of the
installation chapter replace `docker\umv.cmd`. Nothing inside the container
changes.

## If something goes wrong

Consult the troubleshooting chapter first. When reporting a problem, give
the step number, the exact command, the last 60 lines of output and, for
steps 9 onward, the output of `python tools/verify_install.py`.

Contact: Mohamed Barakat A. Gibril (mbgibril@sharjah.ac.ae).

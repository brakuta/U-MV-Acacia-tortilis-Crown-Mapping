# 8. Setup procedure (Windows, from scratch)

This chapter is the complete procedure for the receiving team member. It
assumes no previous experience with command windows, Git or Docker, and it
starts from an empty Windows 11 workstation with an NVIDIA GPU (12 GB of GPU
memory is enough), 64 GB of RAM, and read access to the project share (`Z:`).
Every command is copied exactly as printed and pasted into the window with
Ctrl+V, followed by Enter. Each step says which window it runs in, shows the
commands, states what a successful result looks like, and what to do
otherwise. The table "If you see this message" at the end of the chapter
covers every error observed so far. The other chapters are reference material
and are not needed to complete this one.

| Step | What | Where | Time |
|---|---|---|---|
| 0 | Words you will see | – | 3 min |
| 1 | Install the driver, Docker Desktop and Git | Windows | 20 min |
| 2 | Download the code | PowerShell | 1 min |
| 3 | Copy the archive from `Z:` to the local disk | PowerShell | 10–60 min |
| 4 | Give Docker enough memory | PowerShell | 3 min |
| 5 | Confirm Docker can use the GPU | PowerShell | 1 min |
| 6 | Tell Docker where the data is | PowerShell | 1 min |
| 7 | Build the image | PowerShell | 15–40 min |
| 8 | Start the container | PowerShell | 1 min |
| 9 | Verify the software | container | 3 min |
| 10 | Verify the dataset | container | 3 min |
| 11 | Identify the checkpoint | container | 1 min |
| 12 | Reproduce the published accuracy | container | 40–60 min |
| 13 | Map an orthomosaic (optional) | container | varies |
| 14 | Leave and come back | both | – |

Steps 1 to 7 are done once. Steps 9 to 12 verify the installation. Facts to
know before starting:

* **Which weights.** `best_mIoU_iter_*.pth` in each work directory (the
  checkpoint with the best validation mIoU, used for the paper's test
  results): tiny `best_mIoU_iter_100000.pth`, small `best_mIoU_iter_95000.pth`,
  base `best_mIoU_iter_60000.pth`. Every tool accepts the folder instead of the
  file and selects it automatically.
* **Which model.** Start with U-MV-small; it produced the regional maps and
  has the best generalisability figures.
* **Dataset.** The archive holds 4 893 (train), 2 407 (val), 3 123 (test2)
  and 2 162 (Generalizability) tiles of 1024 × 1024 pixels. The published
  models were trained on 26 615 tiles; the training folder was pruned
  afterwards. Evaluation and inference are exact; retraining reproduces the
  recipe, not the model.
* **Confidentiality.** The dataset is not publicly shareable.

## Step 0 — Words you will see

* **PowerShell** is the window in which commands are typed. Open it with the
  Windows key, type `PowerShell`, click **Windows PowerShell** (blue icon).
  Never choose "Run as administrator": an administrator window cannot see
  the `Z:` drive.
* **Prompt** is the line where you type. `PS C:\Users\name>` or `PS D:\U-MV>`
  means Windows PowerShell. `root@1a2b3c4d:/workspace/U-MV#` (the letters and
  digits differ every time) means the Linux container of step 8. Each step
  says which prompt it needs; a command typed at the wrong prompt fails with
  "is not recognized" or "command not found".
* **Run a command:** click after the prompt, paste with Ctrl+V (or
  right-click), press Enter. Nothing happens until Enter is pressed. If
  Windows asks "You are about to paste text that contains multiple lines",
  click **Paste anyway**.
* **Finished** means a new prompt line with a blinking cursor has appeared.
  Until then, wait, even if nothing is printed for thirty minutes, and do not
  close the window. Ctrl+C stops a command that seems stuck.
* **Copy exactly.** Every quote `"`, backslash `\`, slash `/`, dash `-` and
  dollar sign `$` matters; do not add or remove any. Folder names used here
  must not contain the character `&`.
* **Repository** is the folder with the program's code, `D:\U-MV`, created in
  step 2. `cd D:\U-MV` moves the prompt into it; it is the first line of every
  PowerShell step.
* **Docker Desktop** is a program that runs a ready-made Linux system. The
  **image** is that system, built once in step 7. The **container** is the
  image running in your window (step 8); typing `exit` leaves it.
* **Mounted folder:** a folder of your disk is visible inside the container
  under a Linux name. `D:\A.tortilis_Data_Model\Data used to build the model`
  is `/data` there, and the trained models are `/weights`.
* **Windows questions.** "Do you want to allow this app to make changes?"
  appears only for the installers of step 1: answer **Yes**.
* **Red text** is an error. Read only its first line, find it in the table
  "If you see this message" at the end of the chapter, do what the table
  says, and do not continue to the next step until the current one succeeds.

## Step 1 — Install the driver, Docker Desktop and Git

> Windows · once per machine · needs Internet

**1a. NVIDIA driver.** Open PowerShell (see step 0) and paste:

```powershell
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
```

**You should see** two lines, for example `name, memory.total [MiB],
driver_version` and `NVIDIA GeForce RTX 3060, 12288 MiB, 560.94`. The driver
number must be 520 or higher; if it is lower, or the command is "not
recognized", install the driver for your GPU from nvidia.com, restart the
computer and repeat.

**1b. Docker Desktop.** Download "Docker Desktop for Windows" from docker.com
and run the installer (answer **Yes**; keep "Use WSL 2 instead of Hyper-V"
ticked; restart the computer when asked). Start Docker Desktop from the Start
menu. On first start click **Accept** on the agreement and **Skip** or
**Continue without signing in** on the sign-in page; no account is needed. If
it says that WSL must be installed or updated, paste `wsl --update` into
PowerShell, restart the computer and start Docker Desktop again. Docker is
ready when the whale icon in the taskbar corner (click the small `^` arrow to
see hidden icons) has stopped moving. Then check in PowerShell:

```powershell
docker version
```

**You should see** a `Client:` block and a `Server: Docker Desktop` block. If
the command is "not recognized", close PowerShell and open a new window
(programs installed while a window is open are not visible in it).

**1c. Git.** In PowerShell paste `git --version`. If it prints `git version
2.x`, Git is installed. Otherwise install "Git for Windows" from git-scm.com
with all default options, close PowerShell and open a new window.

**1d. Disk space.** Paste:

```powershell
Get-PSDrive C,D | ForEach-Object { "{0}: {1} GB free" -f $_.Name, [math]::Round($_.Free/1GB) }
```

**You should see** two lines such as `C: 120 GB free` and `D: 800 GB free`;
40 GB on `C:` (the image) and 40 GB on `D:` (the archive) are needed. If the answer contains
`Cannot find drive` for `D`, the computer has no `D:` drive: use `C:` instead
and replace `D:\` by `C:\` in every command of steps 2, 3 and 6.

## Step 2 — Download the code

> PowerShell · once · needs Internet · no GitHub account is needed

The first line stops Git from downloading the large weight files stored on
GitHub (they are not needed; the archive has them and the download can fail
with a quota error).

```powershell
$env:GIT_LFS_SKIP_SMUDGE = "1"
cd D:\
git clone https://github.com/brakuta/U-MV-Acacia-tortilis-Crown-Mapping.git U-MV
cd D:\U-MV
git log -1 --format=%cd
```

**You should see** `Cloning into 'U-MV'...`, `Receiving objects: 100%`,
`Resolving deltas: 100% ..., done.` and finally a date such as `Wed Sep 9
14:02:11 2026 +0400`. The prompt is now `PS D:\U-MV>`.

*If a copy from an earlier attempt exists*, paste
`Test-Path D:\U-MV\docker\Dockerfile`. `False`: continue with the block
above. `True`: instead of the block, paste these three lines:

```powershell
cd D:\U-MV
$env:GIT_LFS_SKIP_SMUDGE = "1"
git pull
```

**You should see** `Already up to date.` or a list of updated files.

## Step 3 — Copy the archive to the local disk

> PowerShell · once · 10 to 60 minutes

Tiles must not be read from the share (too slow), so the dataset and the
trained models are copied to a local folder. One command does the copy,
checks the tile counts and prints the two lines used in step 6. Nothing new
appears for many minutes while it copies; that is normal.

```powershell
cd D:\U-MV
tools\windows\copy_archive.cmd D:\A.tortilis_Data_Model
```

**You should see** two robocopy tables; in each, the `Files :` row must show
`0` under `FAILED`. Then four lines such as
`train              images= 4893  masks= 4893   ok` (also `val 2407`,
`test2 3123`, `Generalizability 2162`, all marked `ok`), three
`best_mIoU_iter_*.pth` paths under `Best checkpoints found:`, two lines
starting with `DATA_DIR=` and `WEIGHTS_DIR=`, and `RESULT: OK`. Write down
those two lines; step 6 uses them.

**If the archive is already on the computer** (an earlier attempt, or someone
copied it for you), do not copy it again. Check it instead, giving the folder
that contains `Data used to build the model` (quotes are needed when the path
contains spaces; add the word `check` at the end):

```powershell
cd D:\U-MV
tools\windows\copy_archive.cmd "D:\Vegetation\3_Mapping Acacia tortilis Trees\A.tortilis_Data_Model" check
```

This copies nothing, prints the same tile counts and the same two
`DATA_DIR=` / `WEIGHTS_DIR=` lines for step 6. The folder name must not
contain the character `&`; rename it in File Explorer if it does.

*If red text says* `Source not found`, open File Explorer → This PC and make
sure `Z:` opens; make sure PowerShell was not started as administrator; then
repeat the command. The command can be repeated at any time; it copies only
what is missing. *If the share has another drive letter* (for example `Y:`),
use:

```powershell
$src = "Y:\Final Geodatabase\Vegetation_Geodatabase\3_Mapping Acacia tortilis Trees"
tools\windows\copy_archive.cmd D:\A.tortilis_Data_Model -Source "$src\A.tortilis_Data & Model"
```

## Step 4 — Give Docker enough memory

> PowerShell · once

Docker runs inside a Linux layer of Windows (WSL2) whose memory limit is set
in a small file. The first line writes that file (40 GB of the 64 GB), the
second shows it:

```powershell
$cfg = "$env:USERPROFILE\.wslconfig"
Set-Content $cfg -Encoding ASCII -Value '[wsl2]','memory=40GB','swap=8GB'
Get-Content $cfg
```

**You should see** the three lines `[wsl2]`, `memory=40GB`, `swap=8GB`. To
apply them: right-click the whale icon in the taskbar corner → **Quit Docker
Desktop**; wait until the icon disappears; paste `wsl --shutdown` (it prints
nothing); start Docker Desktop again from the Start menu and wait until the
whale is still. Then check:

```powershell
[math]::Round([long](docker info --format "{{.MemTotal}}") / 1GB)
```

**You should see** `39` or `40`. Any smaller number means the file was not
applied: repeat the quit, `wsl --shutdown`, start sequence.

## Step 5 — Confirm Docker can use the GPU

> PowerShell · once · Docker Desktop must be running

```powershell
cd D:\U-MV
docker\umv.cmd gpu
```

**You should see**, after a short download (`Unable to find image ... locally`
and `Pull complete` lines are normal), a line with the GPU name, its memory,
the driver version and a number such as `8.6`, followed by `OK: Docker can
use the GPU shown above.` *If not:* see the table at the end of the chapter
(rows `error during connect`, `could not select device driver`).

## Step 6 — Tell Docker where the data is

> PowerShell · once

```powershell
cd D:\U-MV
copy docker\.env.windows.example docker\.env
type docker\.env
```

**You should see** the file: a few comment lines starting with `#`, then

```
DATA_DIR="D:/A.tortilis_Data_Model/Data used to build the model"
WEIGHTS_DIR="D:/A.tortilis_Data_Model/A.tortilis Models/Pretrained weights"
HF_HUB_OFFLINE=0
```

These paths are correct if step 3 copied to `D:\A.tortilis_Data_Model`.
*If the archive is elsewhere*, write the file with the two lines that step 3
printed. Set `$d` to the folder used in step 3 (forward slashes, no trailing
slash) and paste:

```powershell
$d = "D:/Vegetation/3_Mapping Acacia tortilis Trees/A.tortilis_Data_Model"
$l1 = 'DATA_DIR="' + $d + '/Data used to build the model"'
$l2 = 'WEIGHTS_DIR="' + $d + '/A.tortilis Models/Pretrained weights"'
Set-Content docker\.env -Encoding ASCII -Value $l1, $l2, 'HF_HUB_OFFLINE=0'
type docker\.env
```

Paths use forward slashes `/` and stay inside the double quotes.

## Step 7 — Build the image

> PowerShell · once · 15 to 40 minutes · needs Internet

```powershell
cd D:\U-MV
docker\umv.cmd build
```

Leave the window open and the computer awake (Settings → System → Power:
never sleep when plugged in). Lines starting with `#` followed by a number
show the stages: base image download, `apt` packages, `conda` packages, the
mmcv compilation (several minutes with little output), the project packages,
`mamba_ssm OK`, `umv 1.1.0`.

**You should see** the last line `Build finished. Next: docker\umv.cmd shell`.

*If it ends with `BUILD FAILED`*, paste the same two lines again once;
downloads are often interrupted and finished stages are reused. If it fails a
second time, click the window's title bar with the right mouse button → Edit
→ Select All, then Enter (this copies the whole window), paste into an e-mail
to the project lead.

## Step 8 — Start the container

> PowerShell · every session · Docker Desktop must be running

```powershell
cd D:\U-MV
docker\umv.cmd shell
```

**You should see** the prompt change to `root@...:/workspace/U-MV#`. You are
now inside Linux; the commands of steps 9 to 13 are typed at this prompt and
only here. (`[+] Creating ... Network umv_default` and `Volume "umv_hf_cache"`
lines on the first start are normal.) Check the mounted folders:

```bash
ls /data
ls /weights
nvidia-smi
```

**You should see** `ann_dir  img_dir`, then
`mambavision-b_generic-unet_acacia  mambavision-s_generic-unet_acacia-88  mambavision-t_generic-unet_acacia`,
then the GPU table. *If `/data` or `/weights` prints nothing:* type `exit`
and Enter (the prompt returns to `PS D:\U-MV>`), correct `docker\.env`
(step 6), and repeat step 8.

## Step 9 — Verify the software

> inside the container (prompt ends with `#`) · once · needs Internet

```bash
python tools/verify_install.py --variant small
```

The first run downloads the MambaVision-S encoder (about 200 MB) from the
Hugging Face Hub; progress bars and a warning that remote code was
downloaded ("Make sure to double-check ...") are expected.

**You should see** every library with a version, a line
`CUDA available: True | <your GPU name> | torch cuda 11.8`,
`mamba_ssm selective_scan_fn: ok`, `mmcv.ops (compiled extension): ok`,
`U-MV-small: ... M parameters`, `forward (1, 3, 512, 512) -> (1, 2, 512,
512) in ... s, peak VRAM ... GiB`, and the last line `RESULT: OK`. The last
line `RESULT: PROBLEMS FOUND (see above)` means one of the lines above
reports a problem: copy the whole output (right-click the title bar → Edit →
Select All → Enter) into an e-mail to the project lead.

## Step 10 — Verify the dataset

> inside the container · once

```bash
python tools/check_dataset.py /data --splits train val test2 Generalizability
```

**You should see** for each split a line such as
`[train] images=4893 masks=4893 pairs=4893 sidecars=0`, then `sampled ...
sizes={(1024, 1024): ...}` and `mask values=[0, 1]`, and finally
`RESULT: OK`. A `note: ... side-car files ... are ignored` line is harmless.

## Step 11 — Identify the checkpoint

> inside the container · once

```bash
python tools/inspect_checkpoint.py "/weights/mambavision-s_generic-unet_acacia-88"
```

**You should see** `"path": ".../best_mIoU_iter_95000.pth"`,
`"variant": "small"`, `"iteration": 95000` and
`=> use configs/mambavision/U-MV-small.py with this checkpoint`.
*If red text says `No best_mIoU_iter_*.pth ... found`*, `/weights` is wrong:
`exit`, redo step 6, then step 8.

## Step 12 — Reproduce the published accuracy

> inside the container · once · 20 to 30 minutes per run

```bash
CKPT="/weights/mambavision-s_generic-unet_acacia-88"
python tools/test.py configs/mambavision/U-MV-small.py "$CKPT" --test-split test2
python tools/test.py configs/mambavision/U-MV-small.py "$CKPT" --test-split Generalizability
```

The first line prints nothing (it stores the path in a name; it must be pasted
again after every `exit`). Each run prints `-> checkpoint loaded: ... no
missing parameters`, a progress line `Iter(test) [ 100/3123]` that advances,
a small table with rows `background` and `acacia`, and one long last line
starting with `Iter(test) [3123/3123]`.

**You should see** in that last line, for `test2`, `mIoU: 85.4` and `mFscore:
91.6` (paper: 85.38 / 91.58), and for `Generalizability`, `mIoU: 89.5` and
`mFscore: 94.2` (paper: 89.48 / 94.17), with the last digit possibly
different. Send the two log files to the project lead; in Windows they are
`D:\U-MV\work_dirs\U-MV-small\test2\<date>\<date>.log` and
`...\Generalizability\<date>\<date>.log`. The installation is now verified.

Optional, the other two models (paper: tiny 85.44 / 91.61, base 85.30 / 91.52
on `test2`):

```bash
CKPT_T="/weights/mambavision-t_generic-unet_acacia"
python tools/test.py configs/mambavision/U-MV-tiny.py "$CKPT_T" --test-split test2
CKPT_B="/weights/mambavision-b_generic-unet_acacia"
python tools/test.py configs/mambavision/U-MV-base.py "$CKPT_B" --test-split test2
```

## Step 13 — Map an orthomosaic (optional)

> inside the container · per orthomosaic

In Windows, open File Explorer → `D:` → `A.tortilis_Data_Model` → `Data used
to build the model`, right-click an empty space → New → Folder, name it
`orthos`, and copy the orthomosaic GeoTIFF into it. The file name must contain
no spaces; `site.tif` is used below (replace it by the real name, twice). The
container sees the file at once. Then, at the `#` prompt (the second command
is written over four lines that end with a backslash; paste the four lines
together and click **Paste anyway** if asked):

```bash
CKPT="/weights/mambavision-s_generic-unet_acacia-88"
python tools/geospatial_inference.py \
    --config configs/mambavision/U-MV-small.py --checkpoint "$CKPT" \
    --input /data/orthos/site.tif --output /data/predictions/site_crowns.gpkg \
    --scratch-dir /tmp/geospatial_work --min-area 1.0 --save-prob
```

**You should see** progress bars (`tiles`, `writing prob`, `mean_prob`) and a
summary in curly braces with `"polygons": <number>`. In Windows the result is
`D:\A.tortilis_Data_Model\Data used to build the model\predictions\site_crowns.gpkg`
(and `site_crowns_prob.tif`); it opens in ArcGIS Pro or QGIS on top of the
orthomosaic, with `area` (m²) and `mean_prob` attributes. For a folder of
orthomosaics, use `tools/batch_geospatial_inference.py` with `--input-dir
/data/orthos --output-dir /data/predictions` (see the inference chapter).

## Step 14 — Leave and come back

> both

At the `#` prompt, type `exit` and Enter: the container closes and the prompt
returns to `PS D:\U-MV>`. Closing the PowerShell window does the same. Nothing
is lost: the image stays built, the outputs are on `D:`.

Next time: start Docker Desktop and wait for the whale to be still; open
Windows PowerShell (not as administrator); paste `cd D:\U-MV` and then
`docker\umv.cmd shell`; you are back at the `#` prompt (step 8). To receive
code updates first, paste at the `PS` prompt `cd D:\U-MV`, then
`$env:GIT_LFS_SKIP_SMUDGE = "1"`, then `git pull`; the container sees the new
files immediately.

Training on this workstation is possible for U-MV-tiny and U-MV-small with
`python tools/train.py configs/mambavision/U-MV-small.py --amp --cfg-options
train_dataloader.batch_size=1` (12 GB GPU; the published runs used batch 2 on
24 GB); see the training chapter before starting a run.

## If you see this message

| First line of the message | Meaning | What to do |
|---|---|---|
| `git : The term 'git' is not recognized` or `docker : The term 'docker' is not recognized` | The program is not installed, or PowerShell was opened before it was installed | Install it (step 1); close PowerShell; open a new window; repeat the command |
| `nvidia-smi : The term 'nvidia-smi' is not recognized` | No NVIDIA driver | Install the driver from nvidia.com, restart Windows, repeat step 1a |
| `The term 'tools\windows\copy_archive.cmd' is not recognized` or `'docker\umv.cmd' is not recognized` | The prompt is not in the code folder | Paste `cd D:\U-MV`, then repeat the command |
| `python : The term 'python' is not recognized` | A container command was typed at the `PS` prompt | Do step 8 first, then repeat the command at the `#` prompt |
| `Docker Desktop is not running` or `error during connect: ... dockerDesktopLinuxEngine` | Docker Desktop is stopped | Start Docker Desktop, wait until the whale is still, repeat the command |
| `no matching manifest for windows/amd64` | Docker is in Windows-container mode | Right-click the whale icon → **Switch to Linux containers**, repeat the command |
| `could not select device driver "" with capabilities: [[gpu]]` or `Failed to initialize NVML` | Docker cannot reach the GPU | Paste `wsl --update`, then `wsl --shutdown`; start Docker Desktop again; repeat `docker\umv.cmd gpu`. Still failing: Docker Desktop → Settings → Resources → WSL integration → tick the default distribution → Apply & restart |
| `Source not found: Z:\...` | The share is not connected, or PowerShell runs as administrator | Open File Explorer → This PC and open `Z:`; open a normal PowerShell; repeat step 3 |
| `Clone succeeded, but checkout failed` or `This repository is over its data quota` | Git downloaded the weight files | Paste `Remove-Item -Recurse -Force D:\U-MV`, then repeat step 2 from its first line |
| `BUILD FAILED` with `cannot allocate memory` above it | Docker has too little memory | Repeat step 4 with `memory=48GB` instead of `40GB`, then repeat step 7 |
| `BUILD FAILED` (anything else) | A download was interrupted or a package failed | Repeat step 7 once; if it fails again, send the whole window content to the project lead |
| `The argument 'D:\copy_archive.ps1' to the -File parameter does not exist` | The copy helper of an older version had a fault | Paste `cd D:\U-MV`, then `git pull`, then repeat step 3 |
| `docker\.env is missing` | Step 6 was skipped | Do step 6, then repeat the command |
| `ERROR: the checkpoint is U-MV-... but the config is U-MV-...` | Config and checkpoint of different models | Use the config file named in the message |
| `torch.OutOfMemoryError: CUDA out of memory` or `RuntimeError: CUDA out of memory` | The GPU memory is used by something else | Close ArcGIS, QGIS and browsers; at the `#` prompt run `nvidia-smi` (Memory-Usage should be near 0 MiB); repeat the command. For step 13 add `--batch-size 2` |

## Reporting a problem

Give the step number, the exact command, and the whole window content
(right-click the title bar → Edit → Select All → Enter, then paste into the
e-mail). For steps 9 onward, also run at the `#` prompt

```bash
python tools/verify_install.py --variant small > work_dirs/verify.txt 2>&1
```

and attach the file `D:\U-MV\work_dirs\verify.txt`.

Contact: Mohamed Barakat A. Gibril (mbgibril@sharjah.ac.ae).

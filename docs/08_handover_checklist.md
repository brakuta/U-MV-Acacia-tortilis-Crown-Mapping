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
| 6 | Check that Docker knows where the data is | PowerShell | 1 min |
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

**1c. Update the Linux layer.** Docker runs the software inside a small Linux
system built into Windows (WSL 2). It must be up to date, otherwise the
graphics card stays invisible to it in step 5. Paste:

```powershell
wsl --update
```

**You should see** either `Installing: Windows Subsystem for Linux` followed
by `The requested operation is successful`, or a message saying it is already
up to date. Both are fine. *If it answers* `Invalid command line option` or
that WSL is unknown, the Windows version is too old: press the Windows key,
type `winver`, press Enter, and report the version shown (Windows 11, or
Windows 10 version 21H2 or newer, is required).

**1d. Git.** In PowerShell paste `git --version`. If it prints `git version
2.x`, Git is installed. Otherwise install "Git for Windows" from git-scm.com
with all default options, close PowerShell and open a new window.

**1e. Disk space.** Paste:

```powershell
Get-PSDrive C,D | ForEach-Object { "{0}: {1} GB free" -f $_.Name, [math]::Round($_.Free/1GB) }
```

**You should see** two lines such as `C: 120 GB free` and `D: 800 GB free`;
40 GB on `C:` (the image) and 40 GB on `D:` (the archive) are needed. If the answer contains
`Cannot find drive` for `D`, the computer has no `D:` drive: use `C:` instead
and replace `D:\` by `C:\` in every command of steps 2, 3 and 6.

## Step 2 — Download the code

> PowerShell · once · needs Internet · no GitHub account is needed

The second line removes a folder left by an earlier attempt (it stays silent
if there is none). The third stops Git from
downloading the large weight files stored on GitHub: they are not needed,
the archive already has them, and the download can fail with a quota error.

```powershell
cd D:\
Remove-Item -Recurse -Force D:\U-MV -ErrorAction SilentlyContinue
$env:GIT_LFS_SKIP_SMUDGE = "1"
git clone https://github.com/brakuta/U-MV-Acacia-tortilis-Crown-Mapping.git U-MV
cd D:\U-MV
git log -1 --format=%cd
```

**You should see** `Cloning into 'U-MV'...`, `Receiving objects: 100%`,
`Resolving deltas: 100% ..., done.` and finally a date. The prompt is now
`PS D:\U-MV>`. The date must be recent; if it is older than the date printed
on the front page of this guide, tell the project lead before continuing.

## Step 3 — Put the dataset on the local disk

> PowerShell, in `D:\U-MV` · once · 10 to 60 minutes if it must be copied

Tiles must not be read from the shared drive (too slow), so the dataset and
the trained models have to be on a disk of this computer. The command of this
step also checks them and writes the settings file that step 6 needs.

**3a. Is the archive already on this computer?** Paste:

```powershell
cd D:\U-MV
$f = "Data used to build the model"
Get-ChildItem D:\ -Directory -Recurse -Depth 4 -Filter $f -EA 0 | ForEach-Object { $_.Parent.FullName }
```

This takes up to a minute. It prints either nothing, or one line per copy
found: the folder that holds the archive, for example
`D:\Vegetation\3_Mapping Acacia tortilis Trees\A.tortilis_Data_Model`. If
several lines appear, use the first one in 3b; if its check reports `CHECK`,
try the next.

**3b. A line was printed: check that copy, copy nothing.** Paste the folder
between the quotes, exactly as printed, and keep the word `check` at the end:

```powershell
tools\windows\copy_archive.cmd "D:\Vegetation\3_Mapping Acacia tortilis Trees\A.tortilis_Data_Model" check
```

**3c. Nothing was printed: copy the archive from the share.** This takes 10 to
60 minutes, and nothing new appears on the screen while it copies:

```powershell
tools\windows\copy_archive.cmd D:\A.tortilis_Data_Model
```

**You should see**, after either command, four lines such as
`train              images= 4893  masks= 4893   ok` (also `val 2407`,
`test2 3123`, `Generalizability 2162`, each marked `ok`), three
`best_mIoU_iter_*.pth` paths under `Best checkpoints found:`, a line
`Written: D:\U-MV\docker\.env`, and the last line
`RESULT: OK`. After 3c there are also two robocopy tables, in which the
`Files :` row must show `0` under `FAILED`.

*If red text says* `Source not found`, the shared drive is not connected: open
File Explorer → This PC and check that `Z:` opens, make sure PowerShell was
not started as administrator, then repeat. *If the folder name contains the
character* `&`, rename it in File Explorer first (Docker cannot use it). *If
the share has another drive letter* (for example `Y:`), use:

```powershell
$src = "Y:\Final Geodatabase\Vegetation_Geodatabase\3_Mapping Acacia tortilis Trees"
tools\windows\copy_archive.cmd D:\A.tortilis_Data_Model -Source "$src\A.tortilis_Data & Model"
```

The command may be repeated at any time: it copies only what is missing.

## Step 4 — Give Docker enough memory and restart it

> PowerShell · once

Docker runs inside the Linux layer of Windows, whose memory limit is set in a
small file. Three actions, in this order.

**4a. Write the file** (40 GB of the 64 GB; the second line shows the result):

```powershell
$cfg = "$env:USERPROFILE\.wslconfig"
Set-Content $cfg -Encoding ASCII -Value '[wsl2]','memory=40GB','swap=8GB'
Get-Content $cfg
```

**You should see** the three lines `[wsl2]`, `memory=40GB`, `swap=8GB`.

**4b. Restart the Linux layer** so that the file and the update of step 1c
take effect. Right-click the whale icon in the taskbar corner (click the
small `^` arrow if it is hidden) → **Quit Docker Desktop**, and wait until the
icon has disappeared. Then paste:

```powershell
wsl --shutdown
```

It prints nothing. Now start Docker Desktop again from the Start menu and
wait until the whale icon is still. This takes up to two minutes.

**4c. Check the result.** Paste:

```powershell
[math]::Round([long](docker info --format "{{.MemTotal}}") / 1GB)
```

**You should see** `39` or `40`. A smaller number means Docker was not
restarted after the file was written: repeat 4b. An error message means
Docker Desktop is not running yet: wait for the whale icon and repeat 4c.

## Step 5 — Confirm Docker can use the GPU

> PowerShell · once · Docker Desktop must be running

```powershell
cd D:\U-MV
docker\umv.cmd gpu
```

**You should see**, after a short download (`Unable to find image ... locally`
and `Pull complete` lines are normal), a line with the GPU name, its memory,
the driver version and a number such as `8.6`, followed by `OK: Docker can
use the GPU shown above.`

*If it fails*, the usual repair is, in this order: paste `wsl --update`, quit
Docker Desktop from the whale icon, paste `wsl --shutdown`, start Docker
Desktop again from the Start menu, and repeat step 5.

*If it still fails*, this command prints a report that names the cause. It
only reads, it starts and changes nothing:

```powershell
docker\umv.cmd doctor
```

It prints six sections: the Windows version, the NVIDIA driver, the Linux
layer, the Docker engine, the driver inside the Linux layer, and a last
attempt in a container. Each section states what it needs. The two decisive
lines are section 2, which must show the graphics card and a driver version
of 520 or higher, and section 4, whose kernel must contain `WSL2`; a kernel
containing `linuxkit` means Docker Desktop runs on Hyper-V, where no graphics
card is visible, and the remedy is Docker Desktop → Settings → General →
tick **Use the WSL 2 based engine** → Apply & restart. Send the whole report
to the project lead.

Do not stop the work meanwhile: **the graphics card is not needed for step 7**,
so go on and build the image, which takes the longest of all steps. It is
needed from step 8 onward.

## Step 6 — Check that Docker knows where the data is

> PowerShell, in `D:\U-MV` · once

Step 3 wrote this file; here it is only read back.

```powershell
cd D:\U-MV
type docker\.env
```

**You should see** exactly three lines, the first two naming the folder found
in step 3, for example

```
DATA_DIR=".../A.tortilis_Data_Model/Data used to build the model"
WEIGHTS_DIR=".../A.tortilis_Data_Model/A.tortilis Models/Pretrained weights"
HF_HUB_OFFLINE=0
```

where `...` stands for the beginning of the folder found in step 3, written
with forward slashes.

The slashes lean forward and each line ends with a double quote; that is
correct. *If the file is not found* or the folder is wrong, repeat step 3 with
the right folder, or write the file by hand: set `$d` to that folder with
forward slashes and no slash at the end, then paste all five lines together:

```powershell
$d = "D:/Vegetation/3_Mapping Acacia tortilis Trees/A.tortilis_Data_Model"
$l1 = 'DATA_DIR="' + $d + '/Data used to build the model"'
$l2 = 'WEIGHTS_DIR="' + $d + '/A.tortilis Models/Pretrained weights"'
Set-Content docker\.env -Encoding ASCII -Value $l1, $l2, 'HF_HUB_OFFLINE=0'
type docker\.env
```

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
| `nvidia-container-cli: initialization error: load library failed: libnvidia-ml.so.1` (usually with `Auto-detected mode as 'legacy'`) | The Linux layer of Windows does not see the NVIDIA driver: its GPU support is outdated, or Docker Desktop is not using WSL 2. `docker\umv.cmd doctor` names the cause | 1. `wsl --update` 2. quit Docker Desktop from the whale icon 3. `wsl --shutdown` 4. start Docker Desktop 5. repeat step 5. If it persists: Docker Desktop → Settings → General → tick **Use the WSL 2 based engine** → Apply & restart. If it still persists, install the current NVIDIA driver for the GPU from nvidia.com (choose the Studio or Game Ready driver, not a WSL driver, and install it on Windows, never inside WSL), restart Windows, repeat step 5 |
| `wsl --update`: `Invalid command line option` or WSL not installed | The Windows version predates the WSL GPU support | The workstation needs Windows 11, or Windows 10 version 21H2 or newer (Windows key → type `winver`); report the version shown |
| `Source not found: Z:\...` | The share is not connected, or PowerShell runs as administrator | Open File Explorer → This PC and open `Z:`; open a normal PowerShell; repeat step 3 |
| `Clone succeeded, but checkout failed` or `This repository is over its data quota` | Git downloaded the weight files | Paste `Remove-Item -Recurse -Force D:\U-MV`, then repeat step 2 from its first line |
| `BUILD FAILED` with `cannot allocate memory` above it | Docker has too little memory | Repeat step 4 with `memory=48GB` instead of `40GB`, then repeat step 7 |
| `BUILD FAILED` (anything else) | A download was interrupted or a package failed | Repeat step 7 once; if it fails again, send the whole window content to the project lead |
| `The argument 'D:\copy_archive.ps1' to the -File parameter does not exist` | The copy helper of an older version had a fault | Paste `cd D:\U-MV`, then `git pull`, then repeat step 3 |
| `destination path 'U-MV' already exists and is not an empty directory` | The old folder could not be deleted because a program still uses it | Close File Explorer, editors and any container window, then repeat step 2 |
| `docker\.env is missing` | Step 3 did not write the file | Repeat step 3, or write the file by hand as shown at the end of step 6 |
| `Get-ChildItem : Access to the path ... is denied` in step 3a | A protected folder was met while searching | Ignore it; if a folder line was printed, continue with 3b |
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

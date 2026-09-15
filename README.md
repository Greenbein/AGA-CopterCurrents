# AGA-CopterCurrents

**UAV-based surface current estimation with Adaptive Gradient Ascent**

| | |
|---|---|
| Course | Engineering Project II (67547), HUJI |
| Group | 120 |
| Student | Lior Grinbein |
| Advisor | Aviv Solodoch |

## What this project does

This repo extends [CopterCurrents](https://github.com/rubencarrasco/CopterCurrents) (Streßer et al., 2017) with a faster **Adaptive Gradient Ascent (AGA)** optimizer for fitting the wave dispersion relation. AGA is compared against **GPU Grid Search** on drone videos from a **March 4, 2022** field campaign, validated against ADCP measurements.

**Pipeline (5 steps):**
1. Read drone video + camera metadata
2. Georeference / rectify frames
3. Build a grid of analysis windows (STCFIT)
4. Fit current velocity **U = (Ux, Uy)** per window (AGA or Grid Search)
5. Filter by SNR and export velocity maps / CSV tables

---

## Requirements

| Component | Required? | Notes |
|---|---|---|
| **MATLAB** R2020b+ | Yes | Base environment |
| **Parallel Computing Toolbox** | Recommended | GPU acceleration for fit step |
| **NVIDIA GPU + CUDA** | Recommended | AGA and Grid Search run on GPU |
| **MediaInfo CLI** | Yes | Reads drone GPS/altitude from video metadata. [Download](https://mediaarea.net/en/MediaInfo/Download/Windows). Add to system PATH. |
| **Video codecs** | Yes | MATLAB `VideoReader` must read your `.MP4` (DJI H.264/MPEG-4) |
| **deg2utm** | Optional | UTM map plotting — included as `deg2utm.m` in repo root |
| **Camera Calibration Toolbox** | Optional | Only needed to create new calibrations, not to run the pipeline |

Bundled inside `CopterCurrents-master/CopterCurrents/external_libraries/`: `deg2utm`, Caltech camera calibration helpers, and CopterCurrents extras (`nanmean`, `nansum`).

---

## Setup

Clone the repo, then in MATLAB:

```matlab
% 1. Go to your working folder (repo root)
cd('C:\Users\User\Documents\MATLAB');   % adjust path if cloned elsewhere

% 2. Add CopterCurrents paths (external libs, ui_private, etc.)
cd CopterCurrents-master/CopterCurrents
add_CopterCurrents_matlab_path
cd ../..   % back to repo root

% 3. Add AGA / GPU Grid Search code (NOT added automatically)
addpath(genpath('Code_Lior'));
addpath('Code_Lior/private');

% 4. Optional: verify dependencies
check_external_functions
```

> **Note:** `Code_Lior/` must be added manually — `add_CopterCurrents_matlab_path.m` does not include it.

---

## How to run

### Interactive UI (recommended)

```matlab
cd CopterCurrents-master/CopterCurrents/test_scripts
UI_CopterCurrents
```

The UI will prompt you for:
- **Video file** (`.MP4` — keep locally, not in git)
- **Algorithm:** Adaptive Gradient Ascent / Grid Search / Simple Gradient Ascent
- **GPU mode:** Yes (GPU) or No (CPU)
- **Output folder** (created next to the video as `<video_name>_results/`)
- **Georeference cache:** reuse or rebuild

Results are saved under `<video_name>_results/<Algorithm>_results/`.

### Script entry point

```matlab
cd CopterCurrents-master/CopterCurrents/test_scripts
Run_CopterCurrents_script   % calls UI_CopterCurrents
```

---

## Configuration

All pipeline constants live in one file:

```
CopterCurrents-master/CopterCurrents/test_scripts/ui_private/get_ui_pipeline_config.m
```

Edit this file before running — no recompile needed.

### Changing the calibration file

The calibration `.mat` must match your **video horizontal resolution**. Wrong resolution → georeference error.

1. Place the `.mat` file in the repo root (`Documents/MATLAB/` on Windows).
2. Open `get_ui_pipeline_config.m` and set:

```matlab
cfg.calibration_mat_fname = 'Phantom4pro20022022_Caltech_4096x2160.mat';
cfg.calibration_file      = fullfile(matlab_root, cfg.calibration_mat_fname);
```

**Available calibrations in this repo:**

| File | Resolution | Notes |
|---|---|---|
| `Phantom4pro20022022_Caltech_4096x2160.mat` | 4096×2160 | Default for 4096×2160 campaign videos |
| `Phantom4_20220227_FOV_manual_4096x2160.mat` | 4096×2160 | FOV manual calibration |

> Always include the `.mat` extension. The file is resolved relative to `Documents/MATLAB/` (see `get_matlab_root.m`).

### Other common parameters

| Parameter | Meaning | Example |
|---|---|---|
| `cfg.time_limits` | Video segment [start, end] in seconds | `[5 35]` |
| `cfg.sq_size_m` | Analysis window side length [m] | `10` or `40` |
| `cfg.sq_dist_m` | Window spacing [m] | `sq_size_m / 2` |
| `cfg.waveLength_limits_m` | Wavelength filter [m] | `[0.125 10]` |
| `cfg.wavePeriod_limits_sec` | Period filter [s] | `[0.125 2.25]` |
| `cfg.Ux_limits_FG` / `cfg.Uy_limits_FG` | Velocity search range [m/s] | `[-2.0 2.0]` |
| `cfg.SNR_density_thr` | SNR density threshold for maps | `0` or `1.5` |

AGA-specific settings (learning rate, sigma, max iterations) are in `Code_Lior/private/GetOptimizationConfig.m`.

---

## Repository layout

```
MATLAB/                          ← repo root (working directory)
├── Code_Lior/                   ← AGA, Simple GA, GPU Grid Search
├── CopterCurrents-master/       ← modified CopterCurrents pipeline
│   └── CopterCurrents/
│       ├── test_scripts/        ← UI_CopterCurrents, evaluation scripts
│       └── external_libraries/  ← deg2utm, calibration toolbox, extras
├── testaaa/                     ← ADCP import / comparison utilities
├── results_tables/              ← summary CSVs and plots (Mar 4, 2022)
├── Phantom4pro20022022_*.mat    ← camera calibration files
├── deg2utm.m                    ← UTM coordinate helper
└── license.txt                  ← GPL v3 (CopterCurrents)
```

**Not in git** (see `.gitignore`): drone videos (`.MP4`), per-video output folders (`*_results/`), georeference caches, third-party folders (`Plotting/`, `TOOLBOX_calib/`).

---

## Evaluation scripts

Run from `CopterCurrents-master/CopterCurrents/test_scripts/` after processing videos:

| Script | Purpose |
|---|---|
| `compare_aga_vs_adcp_full.m` | Compare AGA vs Grid Search against ADCP |
| `calculate_csv_velocities_statistics.m` | Mean velocities from window CSVs |
| `plot_fit_time_histogram.m` | Fit runtime: AGA vs Grid Search |
| `plot_angle_differences.m` | Angular error analysis |

Pre-computed results for **March 4, 2022** are in `results_tables/`.

---

## Key results (Mar 4, 2022 — 29 videos)

| Metric | AGA | Grid Search |
|---|---|---|
| MAE \|U\| (with wind) | 0.058 m/s | 1.421 m/s |
| MAE angle (with wind) | 28.1° | 38.7° |
| MAE \|U\| (no wind) | 0.130 m/s | 1.494 m/s |
| MAE angle (no wind) | 40.5° | 64.7° |
| Mean GPU fit time | ~4.3 min (259 s) | ~22 min (1328 s) |

---

## References

- Streßer, M., Carrasco, R., & Horstmann, J. (2017). Video-based estimation of surface currents using shore-based and UAV-based cameras. *Ocean Dynamics*, 67, 1087–1102.
- Carrasco, R. (2019). CopterCurrents — MATLAB toolbox for UAV-based surface current estimation.

## License

CopterCurrents components: **GPL v3** (`license.txt`, `CopterCurrents-master/LICENSE`). Project code in `Code_Lior/` follows the same license.

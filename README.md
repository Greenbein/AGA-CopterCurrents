# AGA-CopterCurrents

**UAV-Based Surface Current Estimation with Adaptive Gradient Ascent**

| | |
|---|---|
| **Course** | Engineering Project II (67547), HUJI |
| **Group** | 120 |
| **Student** | Lior Grinbein |
| **Advisor** | Aviv Solodoch |

## Overview

This project extends [CopterCurrents](https://github.com/rubencarrasco/CopterCurrents) (Streßer et al., 2017) with an **Adaptive Gradient Ascent (AGA)** optimizer for fitting the wave dispersion relation, compared against **GPU Grid Search**. Results are validated against ADCP measurements from a February 20, 2022 field campaign.

## Requirements

- MATLAB R2020b or newer (Parallel Computing Toolbox recommended)
- NVIDIA GPU with CUDA support (for GPU Grid Search and AGA)
- CopterCurrents dependencies (included under `CopterCurrents-master/`)

## Quick start

```matlab
cd('C:\path\to\this\repo');
addpath(genpath('CopterCurrents-master/CopterCurrents'));
addpath(genpath('Code_Lior'));
addpath('Code_Lior/private');

% Interactive UI pipeline
UI_CopterCurrents

% Or run the default script
Run_CopterCurrents_script
```

Place drone `.MP4` videos locally (not tracked in git). Select a calibration `.mat` in `get_ui_pipeline_config.m` matching your camera resolution.

## Repository layout

| Path | Description |
|---|---|
| `Code_Lior/` | AGA implementation and GPU Grid Search |
| `CopterCurrents-master/` | Modified CopterCurrents pipeline |
| `testaaa/` | ADCP comparison utilities |
| `results_tables/` | Summary CSVs and error reports (Feb 20, 2022) |
| `Phantom4pro20022022_Caltech_4096x2160.mat` | Example camera calibration |

## Evaluation scripts

Run from `CopterCurrents-master/CopterCurrents/test_scripts/`:

- `compare_aga_vs_adcp_full.m` — compare AGA vs Grid Search against ADCP
- `calculate_csv_velocities_statistics.m` — mean velocities from window CSVs
- `plot_fit_time_histogram.m` — fit runtime comparison
- `plot_angle_differences.m` — angular error plots

## Key results (Feb 20, 2022, 13 videos)

| Metric | AGA | Grid Search |
|---|---|---|
| MAE \|U\| (with wind) | 0.083 m/s | 0.211 m/s |
| MAE angle (with wind) | 18.1° | 78.4° |
| Typical GPU fit time | ~2 min | ~7–12 min |

## References

- Streßer, M., Carrasco, R., & Horstmann, J. (2017). Video-based estimation of surface currents using shore-based and UAV-based cameras. *Ocean Dynamics*, 67, 1087–1102.
- Carrasco, R. (2019). CopterCurrents — MATLAB toolbox for UAV-based surface current estimation.

## License

CopterCurrents components are licensed under GPL v3 (see `license.txt` and `CopterCurrents-master/LICENSE`). Project-specific code in `Code_Lior/` follows the same license unless noted otherwise.

# Tensile Test Evaluation

MATLAB evaluation of tensile tests on AlMg3 and CFRP laminates (UD 0°, UD 90°, 0°/90°) from the TUM lab course "Scientific Experiment with Research Data Management – Tensile Test" (Chair of Product Development and Lightweight Design, winter semester 2026/27, Group 1).

The tests ran on an Instron 4505 (100 kN). Strain was measured with an extensometer, strain gauges and the crosshead displacement. One goal of the course was to quantify how far off the crosshead displacement is.

## Contents

| File | Description |
|---|---|
| `evaluation.m` | Reads the raw data, computes all characteristic values and creates the figures |
| `results.csv`, `results.tex` | Characteristic values (table and LaTeX macros used by the report) |
| `figures/` | Force–strain and force–displacement diagrams (a)–(i) |
| `photos/` | Fracture patterns of the specimens |
| `Tensile_Test_Group1_EN.tex` / `.pdf` | Report incl. data management plan (English translation of the German original) |

## Key results

| Specimen | E [GPa] | Strength [N/mm²] | E error factor (crosshead) |
|---|---|---|---|
| AlMg3 | 66.5 | R_m = 227 | 3.74 |
| CFRP UD 0° | 153.5 | 2292 | 2.81 |
| CFRP UD 90°* | 7.7 | 17 | 1.19 |
| CFRP 0°/90°** | 79.8 | 1033 | 2.51 |

\* broke in the grip, limited validity  ** measurement data of Group 3

The modulus from the crosshead displacement is too low by a factor of 1.2 to 3.7, because it includes the compliance of the machine, grips and end tabs. The stiffer the specimen, the larger the error.

## Usage

Put the .mat files in `daten/Messdaten_Gruppe_1/` and `daten/Messdaten_Gruppe_3/`, then run in MATLAB (R2020a or newer):

```matlab
evaluation
```

This writes `figures/*.pdf`, `results.tex` and `results.csv`. Compile the report with `pdflatex Tensile_Test_Group1_EN.tex` (twice, for the table of contents).

The raw data (provided by the chair) are not part of this repository, in line with the data management plan.

## Authors

Georg Müller, Junjie Qiu, Mark Radlach, Martin Streicher (TUM). Contributions are listed in the report.

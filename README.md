# Tensile Test Evaluation: AlMg3 and CFRP

MATLAB script for evaluating tensile tests on an aluminium alloy (AlMg3) and three carbon fibre laminates (UD 0°, UD 90° and 0°/90°). I wrote it for the lab course "Wissenschaftlicher Versuch mit Forschungsdatenmanagement" at TUM (Chair of Product Development and Lightweight Design, winter term 2026/27). The tests ran on a ZwickRoell universal testing machine.

The script reads the raw machine data, computes the material properties and writes everything the group report needs: vector PDF plots and a file of LaTeX macros, so every number in the report comes straight from the data.

## What it computes

AlMg3
- Young's modulus between 0.01 % and 0.1 % strain, once from the extensometer and once from the crosshead displacement
- Tensile strength R<sub>m</sub>, fracture force and strain at fracture
- Fracture point detected as the start of the steepest force drop after F<sub>max</sub>

CFRP
- Fracture force and strain at F<sub>max</sub> (the laminates fail brittle)
- Secant modulus between 10 % and 50 % of F<sub>max</sub>, from strain gauge or extensometer and from crosshead displacement

The ratio between the two modulus values shows how much machine compliance and grip slip distort a modulus taken from crosshead travel.

Test speed is checked as well (median crosshead speed up to F<sub>max</sub>).

## Files

```
auswertung.m        evaluation script
daten/              raw data (.mat), not included, see below
figures/            plots, created by the script
ergebnisse.tex      LaTeX macros with all results, created by the script
ergebnisse.csv      the same results as a table, created by the script
```

## Running it

Requires MATLAB R2020a or newer (uses `exportgraphics`, `xline`, `yline`). No toolboxes.

1. Put the measurement files into `daten/Messdaten_Gruppe_1/` and `daten/Messdaten_Gruppe_3/`.
2. Run `auswertung` in the MATLAB command window from the repository folder.

Specimen width, thickness (three measuring points) and gauge length are entered at the top of the script.

In the report the results are loaded with `\input{ergebnisse.tex}` and used as macros, e.g. `\RAluRm` for the tensile strength of AlMg3.

## Notes

- For the 0°/90° laminate the data of group 3 is evaluated. On our specimen the tab slipped during the test, so that curve is only plotted for comparison.
- Code comments and plot labels are in German because the report was written in German.
- The raw data belongs to the chair and is not part of this repository.

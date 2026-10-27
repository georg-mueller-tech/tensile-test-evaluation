function auswertung()
%AUSWERTUNG  Auswertung der Zugversuche an AlMg3 und CFK.
%   Liest die Messdaten aus daten/, berechnet E-Modul, Festigkeit und
%   Bruchdehnung und schreibt:
%     figures/*.pdf    Kraft-Dehnungs- und Kraft-Weg-Diagramme
%     ergebnisse.tex   Kennwerte als LaTeX-Makros für den Bericht
%     ergebnisse.csv   dieselben Kennwerte als Tabelle
%
%   Einheiten der Rohdaten: Kraft in kN, Maschinenweg in mm,
%   Dehnung (DMS bzw. Extensometer) in %.
%   Benötigt MATLAB R2020a oder neuer (exportgraphics, xline, yline).

here   = fileparts(mfilename('fullpath'));
daten  = fullfile(here, 'daten');
figDir = fullfile(here, 'figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end

%% Probengeometrie aus dem Versuchsprotokoll
% Breite b [mm], Dicke t oben/mittig/unten [mm], Bezugslänge L0 [mm]
P.Alu    = probe(16.06, [4.04 4.04 4.05],  65.00);   % AlMg3
P.CFK0   = probe(16.20, [0.88 0.87 0.88], 150.55);   % CFK-UD 0°
P.CFK90  = probe(16.25, [1.95 1.90 1.90], 151.60);   % CFK-UD 90°
P.CFK090 = probe(15.85, [2.00 2.00 2.02], 154.61);   % CFK 0°/90°

%% Messdaten
% Für 0°/90° wird die Messung von Gruppe 3 ausgewertet, weil bei Gruppe 1
% der Aufleimer abgerutscht ist. Die Kurve von Gruppe 1 und die 90°-Probe
% von Gruppe 3 werden nur zum Vergleich mitgeplottet.
g1 = fullfile(daten, 'Messdaten_Gruppe_1');
g3 = fullfile(daten, 'Messdaten_Gruppe_3');
aluE     = ladeMessung(fullfile(g1, 'Alu_E.mat'));
aluBruch = ladeMessung(fullfile(g1, 'Alu_Bruch.mat'));
cfk0     = ladeMessung(fullfile(g1, 'CFK_0.mat'));
cfk90    = ladeMessung(fullfile(g1, 'CFK_90.mat'));
cfk090   = ladeMessung(fullfile(g3, 'CFK_090.mat'));
cfk090G1 = ladeMessung(fullfile(g1, 'CFK_090.mat'));
cfk90G3  = ladeMessung(fullfile(g3, 'CFK_90.mat'));

C = struct('main', hex2rgb('#1f4e8c'), ...   % Messkurve
           'ref',  hex2rgb('#8a8a8a'), ...   % Vergleichskurve
           'mark', hex2rgb('#c0392b'), ...   % Auswertepunkte
           'lim',  hex2rgb('#2e8b57'));      % Grenzen E-Modul

res = cell(0, 3);   % Zeilen: {Name, Wert, Nachkommastellen}

%% AlMg3, elastischer Bereich: E-Modul zwischen 0,01 % und 0,1 % Dehnung
[~, iA] = max(aluE.F);
e  = [0.01 0.1];                                       % Dehnung [%]
Fe = ersteUeberschreitung(aluE.eps, aluE.F, e, iA);    % Kraft bei e [kN]
De = ersteUeberschreitung(aluE.F, aluE.D, Fe, iA);     % Weg bei Fe [mm]
EaluExt = diff(Fe) * 1e3 / (P.Alu.A * diff(e) / 100);  % N/mm²
EaluMw  = diff(Fe) * 1e3 / (P.Alu.A * diff(De) / P.Alu.L0);
res = [res; {
    'AluFepsA', Fe(1),           3
    'AluFepsB', Fe(2),           3
    'AluEext',  EaluExt / 1e3,   1
    'AluEmw',   EaluMw / 1e3,    1
    'AluEfak',  EaluExt / EaluMw, 2}];

%% AlMg3 bis zum Bruch
[FmaxAlu, iB] = max(aluBruch.F);
iBr = bruchIndex(aluBruch.F, iB);
Db  = aluBruch.D - aluBruch.D(1);
FBr = aluBruch.F(iBr);
res = [res; {
    'AluFmax',   FmaxAlu,                    2
    'AluFbruch', FBr,                        2
    'AluDbruch', Db(iBr),                    2
    'AluRm',     FmaxAlu * 1e3 / P.Alu.A,    0
    'AluSigB',   FBr * 1e3 / P.Alu.A,        0
    'AluAmw',    Db(iBr) / P.Alu.L0 * 100,   1}];

%% CFK: Bruch bei Fmax, Sekantenmodul zwischen 10 % und 50 % Fmax
[r0, lim0] = cfkKennwerte(cfk0,   P.CFK0,   'CFKnull');
[r9, lim9] = cfkKennwerte(cfk90,  P.CFK90,  'CFKneunzig');
[rx, limx] = cfkKennwerte(cfk090, P.CFK090, 'CFKnullneunzig');
[Fg3, ig3] = max(cfk90G3.F);
res = [res; r0; r9; rx; {
    'GeinsFmaxNullNeunzig', max(cfk090G1.F),  2
    'GdreiFmaxNeunzig',     Fg3,              2
    'GdreiEpsBNeunzig',     cfk90G3.eps(ig3), 3}];

%% Prüfgeschwindigkeit in mm/min (Plausibilitätskontrolle)
proben = {aluE, aluBruch, cfk0, cfk90, cfk090};
namen  = {'vAluE', 'vAluB', 'vCFKnull', 'vCFKneunzig', 'vCFKnullneunzig'};
for k = 1:numel(proben)
    res(end+1, :) = {namen{k}, pruefgeschwindigkeit(proben{k}), 2}; %#ok<AGROW>
end

%% Diagramme
% (a) AlMg3 elastisch, Kraft über Extensometerdehnung
ax = neueAchse();
plot(ax, aluE.eps(1:iA), aluE.F(1:iA), 'Color', C.main, 'LineWidth', 1.4, ...
    'DisplayName', 'AlMg3, Extensometer (Gr. 1)');
xline(ax, e(1), '--', 'Color', C.lim, 'LineWidth', 0.9, ...
    'DisplayName', 'E-Modul-Grenzen ε = 0,01 % / 0,1 %');
xline(ax, e(2), '--', 'Color', C.lim, 'LineWidth', 0.9, 'HandleVisibility', 'off');
plot(ax, e, Fe, 'o-', 'Color', C.lim, 'LineWidth', 1.0, 'MarkerSize', 6, ...
    'MarkerFaceColor', C.lim, 'MarkerEdgeColor', 'w', 'HandleVisibility', 'off');
speichern(ax, fullfile(figDir, 'a_alu_elast_ext.pdf'), 'Extensometerdehnung {\itε} [%]');

% (b) AlMg3 elastisch, Kraft über Maschinenweg
ax = neueAchse();
plot(ax, aluE.D(1:iA), aluE.F(1:iA), 'Color', C.main, 'LineWidth', 1.4, ...
    'DisplayName', 'AlMg3, Maschinenweg (Gr. 1)');
horizGrenzen(ax, Fe, 'Kräfte bei ε = 0,01 % / 0,1 %', C.lim);
plot(ax, De, Fe, 'o', 'MarkerSize', 6, 'MarkerFaceColor', C.lim, ...
    'MarkerEdgeColor', 'w', 'HandleVisibility', 'off');
speichern(ax, fullfile(figDir, 'b_alu_elast_mw.pdf'), 'Maschinenweg Δ{\itl} [mm]');

% (c) AlMg3 bis Bruch, Kraft über Maschinenweg
ax = neueAchse();
n = min(iBr + 29, numel(Db));   % ein Stück nach dem Bruch mitzeichnen
plot(ax, Db(1:n), aluBruch.F(1:n), 'Color', C.main, 'LineWidth', 1.4, ...
    'DisplayName', 'AlMg3 bis Bruch (Gr. 1)');
markiere(ax, Db(iB), FmaxAlu, 'o', C.mark, ['{\itF}_{max} = ' komma(FmaxAlu) ' kN']);
markiere(ax, Db(iBr), FBr, 's', C.mark, ['Bruch: {\itF}_B = ' komma(FBr) ' kN']);
speichern(ax, fullfile(figDir, 'c_alu_bruch_mw.pdf'), 'Maschinenweg Δ{\itl} [mm]');

% (d)-(i) CFK, jeweils über Dehnung und über Maschinenweg
cfkDiagramme(cfk0, lim0, C, figDir, 'de_cfk0', 'CFK-UD 0° (Gr. 1)', ...
    'DMS-Dehnung {\itε} [%]', [], '');
cfkDiagramme(cfk90, lim9, C, figDir, 'fg_cfk90', 'CFK-UD 90° (Gr. 1)', ...
    'Extensometerdehnung {\itε} [%]', cfk90G3, 'CFK-UD 90° (Gr. 3, Vergleich)');
cfkDiagramme(cfk090, limx, C, figDir, 'hi_cfk090', 'CFK 0°/90° (Gr. 3, ausgewertet)', ...
    'DMS-Dehnung {\itε} [%]', cfk090G1, 'CFK 0°/90° (Gr. 1, Aufleimer abgerutscht)');

%% Export
fid = fopen(fullfile(here, 'ergebnisse.tex'), 'w', 'n', 'UTF-8');
fprintf(fid, '%% automatisch erzeugt von auswertung.m, nicht von Hand bearbeiten\n');
for k = 1:size(res, 1)
    fprintf(fid, '\\newcommand{\\R%s}{%s}\n', res{k, 1}, fmt(res{k, 2}, res{k, 3}));
end
tags = struct('Alu', 'Alu', 'CFK0', 'CFKnull', 'CFK90', 'CFKneunzig', 'CFK090', 'CFKnullneunzig');
for name = fieldnames(P)'
    p  = P.(name{1});
    tg = tags.(name{1});
    t3 = strjoin(arrayfun(@(x) fmt(x, 2), p.t3, 'UniformOutput', false), ' / ');
    fprintf(fid, '\\newcommand{\\P%sb}{%s}\n',     tg, fmt(p.b, 2));
    fprintf(fid, '\\newcommand{\\P%st}{%s}\n',     tg, fmt(p.t, 3));
    fprintf(fid, '\\newcommand{\\P%stdrei}{%s}\n', tg, t3);
    fprintf(fid, '\\newcommand{\\P%sL}{%s}\n',     tg, fmt(p.L0, 1));
    fprintf(fid, '\\newcommand{\\P%sA}{%s}\n',     tg, fmt(p.A, 2));
end
fclose(fid);

T = table(res(:, 1), round(cell2mat(res(:, 2)), 4), 'VariableNames', {'Kennwert', 'Wert'});
writetable(T, fullfile(here, 'ergebnisse.csv'));

fprintf('Fertig. Diagramme in figures/, Kennwerte in ergebnisse.tex und ergebnisse.csv\n');
for k = 1:size(res, 1)
    fprintf('  %-24s %s\n', res{k, 1}, komma(res{k, 2}, res{k, 3}));
end
end


%% ========================================================================
%  Auswertung
%  ========================================================================

function p = probe(b, t3, L0)
% Probengeometrie; Dicke als Mittelwert der drei Messstellen.
t = mean(t3);
p = struct('b', b, 't3', t3, 't', t, 'L0', L0, 'A', b * t);
end

function m = ladeMessung(datei)
% Lädt eine .mat-Datei der Prüfmaschine (Kraft, Weg, Dehnung, Zeit).
s = load(datei);
m.F = s.Load(:);
% wie im Lehrstuhlskript: Wegvektor auf die Länge des Kraftvektors kürzen
D = s.Displacement(:);
m.D = D(max(1, end - numel(m.F) + 1):end);
m.eps = [];
for feld = {'Strain', 'Extensometer'}
    if isfield(s, feld{1})
        e = s.(feld{1})(:);
        m.eps = e(1:min(end, numel(m.F)));
    end
end
m.t = s.Load_time(:);
end

function [rows, lim] = cfkKennwerte(c, p, tag)
% Kennwerte einer CFK-Probe. Bruch = Fmax, Sekantenmodul 10-50 % Fmax,
% einmal aus der DMS-/Extensometerdehnung und einmal aus dem Maschinenweg.
[Fmax, i] = max(c.F);
lim.i   = i;
lim.F   = [0.1 0.5] * Fmax;
lim.eps = ersteUeberschreitung(c.F, c.eps, lim.F, i);
lim.D   = ersteUeberschreitung(c.F, c.D,   lim.F, i);

epsB   = c.eps(i);
DB     = c.D(i) - c.D(1);
epsBmw = DB / p.L0 * 100;
Es     = diff(lim.F) * 1e3 / (p.A * diff(lim.eps) / 100);   % N/mm²
Emw    = diff(lim.F) * 1e3 / (p.A * diff(lim.D) / p.L0);
sigB   = Fmax * 1e3 / p.A;

rows = {
    [tag 'Fmax'],      Fmax,          2
    [tag 'Fzehn'],     lim.F(1),      2
    [tag 'Ffuenfzig'], lim.F(2),      2
    [tag 'epsB'],      epsB,          3
    [tag 'DB'],        DB,            2
    [tag 'sigB'],      sigB,          0
    [tag 'Es'],        Es / 1e3,      1
    [tag 'epsBmw'],    epsBmw,        3
    [tag 'epsfak'],    epsB / epsBmw, 2
    [tag 'Emw'],       Emw / 1e3,     1
    [tag 'Efak'],      Es / Emw,      2};
end

function out = ersteUeberschreitung(ref, val, q, iEnd)
% Wert von val an der Stelle, an der ref zum ersten Mal q erreicht.
% Gesucht wird in der monoton steigenden Hüllkurve von ref bis iEnd,
% dazwischen wird linear interpoliert. q darf ein Vektor sein.
huelle = cummax(ref(1:iEnd));
out = zeros(size(q));
for k = 1:numel(q)
    j = find(huelle >= q(k), 1);
    if isempty(j), j = iEnd; end
    j = max(j, 2);
    r0 = ref(j - 1);
    r1 = ref(j);
    w = 0;
    if r1 ~= r0, w = (q(k) - r0) / (r1 - r0); end
    out(k) = val(j - 1) + w * (val(j) - val(j - 1));
end
end

function i = bruchIndex(F, iMax)
% Bruchpunkt Alu: Beginn des steilsten Kraftabfalls nach Fmax.
w = 5;
dF = F(iMax + w:end) - F(iMax:end - w);
[~, k] = min(dF);
i = iMax + k - 1;
end

function v = pruefgeschwindigkeit(m)
% Median der Traversengeschwindigkeit bis Fmax in mm/min (NaN bei Stillstand).
[~, i] = max(m.F);
v = diff(m.D(1:i)) ./ diff(m.t(1:i)) * 60;
v = median(v(v > 0.01));
end


%% ========================================================================
%  Diagramme
%  ========================================================================

function cfkDiagramme(c, lim, C, figDir, basis, titel, xlabEps, ref, refLabel)
% Zwei Diagramme pro CFK-Probe: Kraft über Dehnung und über Maschinenweg.
i = lim.i;
grenzLabel = 'Grenzen Sekantenmodul 10 % / 50 % {\itF}_{max}';

ax = neueAchse();
if ~isempty(ref)
    [~, ir] = max(ref.F);
    plot(ax, ref.eps(1:ir), ref.F(1:ir), '--', 'Color', C.ref, 'LineWidth', 1.1, ...
        'DisplayName', refLabel);
end
plot(ax, c.eps(1:i), c.F(1:i), 'Color', C.main, 'LineWidth', 1.4, 'DisplayName', titel);
horizGrenzen(ax, lim.F, grenzLabel, C.lim);
plot(ax, lim.eps, lim.F, 'Color', C.lim, 'LineWidth', 1.0, 'HandleVisibility', 'off');
markiere(ax, c.eps(i), c.F(i), 'o', C.mark, ['Bruch: {\itF}_{max} = ' komma(c.F(i)) ...
    ' kN, {\itε}_B = ' komma(c.eps(i)) ' %']);
speichern(ax, fullfile(figDir, [basis '_eps.pdf']), xlabEps);

ax = neueAchse();
if ~isempty(ref)
    [~, ir] = max(ref.F);
    Dr = ref.D - ref.D(1);
    nr = min(ir + 39, numel(Dr));
    plot(ax, Dr(1:nr), ref.F(1:nr), '--', 'Color', C.ref, 'LineWidth', 1.1, ...
        'DisplayName', refLabel);
end
D = c.D - c.D(1);
plot(ax, D(1:i), c.F(1:i), 'Color', C.main, 'LineWidth', 1.4, 'DisplayName', titel);
horizGrenzen(ax, lim.F, grenzLabel, C.lim);
plot(ax, lim.D - c.D(1), lim.F, 'Color', C.lim, 'LineWidth', 1.0, 'HandleVisibility', 'off');
markiere(ax, D(i), c.F(i), 'o', C.mark, ['Bruch: {\itF}_{max} = ' komma(c.F(i)) ...
    ' kN, Δ{\itl}_B = ' komma(D(i)) ' mm']);
speichern(ax, fullfile(figDir, [basis '_mw.pdf']), 'Maschinenweg Δ{\itl} [mm]');
end

function ax = neueAchse()
f = figure('Visible', 'off', 'Units', 'inches', 'Position', [1 1 6.0 3.6], 'Color', 'w');
ax = axes(f);
hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
set(ax, 'FontName', 'Times New Roman', 'FontSize', 10, 'LineWidth', 0.6, ...
    'GridColor', hex2rgb('#dddddd'), 'GridAlpha', 1);
ax.XAxis.Exponent = 0;
end

function speichern(ax, datei, xlab)
xlabel(ax, xlab);
ylabel(ax, 'Kraft {\itF} [kN]');
xl = xlim(ax); xlim(ax, [min(0, xl(1)), xl(2)]);
yl = ylim(ax); ylim(ax, [0, yl(2)]);
legend(ax, 'Location', 'best', 'Box', 'off', 'FontSize', 8.5);
exportgraphics(ax.Parent, datei, 'ContentType', 'vector');
close(ax.Parent);
end

function horizGrenzen(ax, F, label, farbe)
yline(ax, F(1), '--', 'Color', farbe, 'LineWidth', 0.9, 'DisplayName', label);
yline(ax, F(2), '--', 'Color', farbe, 'LineWidth', 0.9, 'HandleVisibility', 'off');
end

function markiere(ax, x, y, symbol, farbe, label)
plot(ax, x, y, symbol, 'MarkerSize', 6, 'MarkerFaceColor', farbe, ...
    'MarkerEdgeColor', 'w', 'LineWidth', 1.0, 'DisplayName', label);
end


%% ========================================================================
%  Formatierung
%  ========================================================================

function s = fmt(v, nd)
% Zahl für LaTeX mit Dezimalkomma; NaN erscheint im Bericht als ??.
if isempty(v) || isnan(v)
    s = '\textbf{??}';
else
    s = strrep(sprintf('%.*f', nd, v), '.', '{,}');
end
end

function s = komma(v, nd)
% Zahl mit Dezimalkomma für Legenden und Konsolenausgabe.
if nargin < 2, nd = 2; end
s = strrep(sprintf('%.*f', nd, v), '.', ',');
end

function c = hex2rgb(h)
c = sscanf(h(2:end), '%2x%2x%2x', [1 3]) / 255;
end

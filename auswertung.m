function evaluate_tensile_tests()
%EVALUATE_TENSILE_TESTS  Tensile test evaluation for AlMg3 and CFRP laminates.
%   Reads the raw machine data from data/, computes modulus, strength and
%   strain at fracture, and writes
%     figures/*.pdf   force-strain and force-displacement plots
%     results.tex     all results as LaTeX macros for the report
%     results.csv     the same results as a table
%   Raw data units: force in kN, crosshead displacement in mm, strain in %.
%   Needs MATLAB R2020a or newer.

root   = fileparts(mfilename('fullpath'));
figDir = fullfile(root, 'figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end

% Specimens: width b [mm], thickness at three points [mm], gauge length L0 [mm]
S.Alu    = specimen(16.06, [4.04 4.04 4.05],  65.00);   % AlMg3
S.CFK0   = specimen(16.20, [0.88 0.87 0.88], 150.55);   % CFRP UD 0°
S.CFK90  = specimen(16.25, [1.95 1.90 1.90], 151.60);   % CFRP UD 90°
S.CFK090 = specimen(15.85, [2.00 2.00 2.02], 154.61);   % CFRP 0°/90°

% The tab on our (group 1) 0°/90° specimen slipped, so group 3's test is
% evaluated and ours is only plotted for comparison. Group 3's 90° test is
% a second reference curve.
g1 = @(f) loadTest(fullfile(root, 'data', 'Messdaten_Gruppe_1', f));
g3 = @(f) loadTest(fullfile(root, 'data', 'Messdaten_Gruppe_3', f));
aluE   = g1('Alu_E.mat');    aluB  = g1('Alu_Bruch.mat');
cfk0   = g1('CFK_0.mat');    cfk90 = g1('CFK_90.mat');
cfk090 = g3('CFK_090.mat');  cfk090G1 = g1('CFK_090.mat');  cfk90G3 = g3('CFK_90.mat');

C = struct('main', [0.12 0.31 0.55], 'ref', [0.54 0.54 0.54], ...
           'mark', [0.75 0.22 0.17], 'lim', [0.18 0.55 0.34]);

%% AlMg3, elastic range: modulus between 0.01 % and 0.1 % strain
[~, iA] = max(aluE.F);
e  = [0.01 0.1];
Fe = firstCrossing(aluE.eps, aluE.F, e, iA);   % force at those strains [kN]
De = firstCrossing(aluE.F, aluE.D, Fe, iA);    % crosshead position at Fe [mm]
Eext = diff(Fe) * 1e3 / (S.Alu.A * diff(e) / 100);        % MPa
Ecr  = diff(Fe) * 1e3 / (S.Alu.A * diff(De) / S.Alu.L0);  % MPa, from crosshead

%% AlMg3 to fracture
[Fmax, iB] = max(aluB.F);
iBr = fractureIndex(aluB.F, iB);
Db  = aluB.D - aluB.D(1);

% Macro names are German because the report is (\RAluRm etc.)
res = {
    'AluFepsA',  Fe(1),                     3
    'AluFepsB',  Fe(2),                     3
    'AluEext',   Eext / 1e3,                1
    'AluEmw',    Ecr / 1e3,                 1
    'AluEfak',   Eext / Ecr,                2
    'AluFmax',   Fmax,                      2
    'AluFbruch', aluB.F(iBr),               2
    'AluDbruch', Db(iBr),                   2
    'AluRm',     Fmax * 1e3 / S.Alu.A,      0
    'AluSigB',   aluB.F(iBr) * 1e3 / S.Alu.A, 0
    'AluAmw',    Db(iBr) / S.Alu.L0 * 100,  1};

%% CFRP
[r0, lim0] = cfrp(cfk0,   S.CFK0,   'CFKnull');
[r9, lim9] = cfrp(cfk90,  S.CFK90,  'CFKneunzig');
[rx, limx] = cfrp(cfk090, S.CFK090, 'CFKnullneunzig');
[Fg3, ig3] = max(cfk90G3.F);
res = [res; r0; r9; rx; {
    'GeinsFmaxNullNeunzig', max(cfk090G1.F),  2
    'GdreiFmaxNeunzig',     Fg3,              2
    'GdreiEpsBNeunzig',     cfk90G3.eps(ig3), 3}];

%% Test speed in mm/min (plausibility check)
tests = {aluE, aluB, cfk0, cfk90, cfk090};
names = {'vAluE', 'vAluB', 'vCFKnull', 'vCFKneunzig', 'vCFKnullneunzig'};
for k = 1:numel(tests)
    res(end+1, :) = {names{k}, testSpeed(tests{k}), 2}; %#ok<AGROW>
end

%% Plots
xStrainExt = 'Extensometer strain {\itε} [%]';
xStrainSG  = 'Strain gauge strain {\itε} [%]';
xCross     = 'Crosshead displacement Δ{\itl} [mm]';

% (a) AlMg3 elastic, force over extensometer strain
ax = newPlot();
plot(ax, aluE.eps(1:iA), aluE.F(1:iA), 'Color', C.main, 'LineWidth', 1.4, ...
    'DisplayName', 'AlMg3, extensometer');
xline(ax, e(1), '--', 'Color', C.lim, 'DisplayName', 'Modulus limits 0.01 % / 0.1 %');
xline(ax, e(2), '--', 'Color', C.lim, 'HandleVisibility', 'off');
plot(ax, e, Fe, 'o-', 'Color', C.lim, 'MarkerFaceColor', C.lim, 'HandleVisibility', 'off');
savePlot(ax, fullfile(figDir, 'a_alu_elast_ext.pdf'), xStrainExt);

% (b) AlMg3 elastic, force over crosshead displacement
ax = newPlot();
plot(ax, aluE.D(1:iA), aluE.F(1:iA), 'Color', C.main, 'LineWidth', 1.4, ...
    'DisplayName', 'AlMg3, crosshead');
limitLines(ax, Fe, 'Forces at 0.01 % / 0.1 % strain', C.lim);
plot(ax, De, Fe, 'o', 'Color', C.lim, 'MarkerFaceColor', C.lim, 'HandleVisibility', 'off');
savePlot(ax, fullfile(figDir, 'b_alu_elast_mw.pdf'), xCross);

% (c) AlMg3 to fracture
ax = newPlot();
n = min(iBr + 29, numel(Db));   % draw a bit past the fracture point
plot(ax, Db(1:n), aluB.F(1:n), 'Color', C.main, 'LineWidth', 1.4, ...
    'DisplayName', 'AlMg3 to fracture');
plot(ax, Db(iB), Fmax, 'o', 'Color', C.mark, 'MarkerFaceColor', C.mark, ...
    'DisplayName', ['{\itF}_{max} = ' num(Fmax) ' kN']);
plot(ax, Db(iBr), aluB.F(iBr), 's', 'Color', C.mark, 'MarkerFaceColor', C.mark, ...
    'DisplayName', ['Fracture: {\itF}_B = ' num(aluB.F(iBr)) ' kN']);
savePlot(ax, fullfile(figDir, 'c_alu_bruch_mw.pdf'), xCross);

% (d)-(i) CFRP, each over strain and over crosshead displacement
cfrpPlots(cfk0,   lim0, C, figDir, 'de_cfk0',   'UD 0° (group 1)',  xStrainSG,  [], '');
cfrpPlots(cfk90,  lim9, C, figDir, 'fg_cfk90',  'UD 90° (group 1)', xStrainExt, ...
    cfk90G3, 'UD 90° (group 3, reference)');
cfrpPlots(cfk090, limx, C, figDir, 'hi_cfk090', '0°/90° (group 3)', xStrainSG, ...
    cfk090G1, '0°/90° (group 1, tab slipped)');

%% Export
fid = fopen(fullfile(root, 'results.tex'), 'w', 'n', 'UTF-8');
fprintf(fid, '%% generated by evaluate_tensile_tests.m, do not edit\n');
for k = 1:size(res, 1)
    fprintf(fid, '\\newcommand{\\R%s}{%s}\n', res{k, 1}, tex(res{k, 2}, res{k, 3}));
end
tags = {'Alu', 'CFKnull', 'CFKneunzig', 'CFKnullneunzig'};
fn = fieldnames(S);
for k = 1:numel(fn)
    s = S.(fn{k});
    t = tags{k};
    t3 = strjoin(arrayfun(@(x) tex(x, 2), s.t3, 'UniformOutput', false), ' / ');
    fprintf(fid, '\\newcommand{\\P%sb}{%s}\n',     t, tex(s.b, 2));
    fprintf(fid, '\\newcommand{\\P%st}{%s}\n',     t, tex(s.t, 3));
    fprintf(fid, '\\newcommand{\\P%stdrei}{%s}\n', t, t3);
    fprintf(fid, '\\newcommand{\\P%sL}{%s}\n',     t, tex(s.L0, 1));
    fprintf(fid, '\\newcommand{\\P%sA}{%s}\n',     t, tex(s.A, 2));
end
fclose(fid);

writetable(table(res(:, 1), round(cell2mat(res(:, 2)), 4), ...
    'VariableNames', {'Name', 'Value'}), fullfile(root, 'results.csv'));
fprintf('Done. Plots in figures/, results in results.tex and results.csv\n');
end


%% ------------------------------------------------------------------------
%  Evaluation
%  ------------------------------------------------------------------------

function s = specimen(b, t3, L0)
t = mean(t3);
s = struct('b', b, 't3', t3, 't', t, 'L0', L0, 'A', b * t);
end

function m = loadTest(file)
% Loads one .mat export of the testing machine.
s = load(file);
m.F = s.Load(:);
% Same as the chair's reference script: trim displacement to the force length
D = s.Displacement(:);
m.D = D(max(1, end - numel(m.F) + 1):end);
m.eps = [];
for f = {'Strain', 'Extensometer'}
    if isfield(s, f{1})
        e = s.(f{1})(:);
        m.eps = e(1:min(end, numel(m.F)));
    end
end
m.t = s.Load_time(:);
end

function [rows, lim] = cfrp(c, s, tag)
% CFRP fails brittle, so fracture = Fmax.
% Secant modulus between 10 % and 50 % Fmax, from strain and from crosshead.
[Fmax, i] = max(c.F);
lim.i   = i;
lim.F   = [0.1 0.5] * Fmax;
lim.eps = firstCrossing(c.F, c.eps, lim.F, i);
lim.D   = firstCrossing(c.F, c.D, lim.F, i);
epsB  = c.eps(i);
DB    = c.D(i) - c.D(1);
epsCr = DB / s.L0 * 100;
Es    = diff(lim.F) * 1e3 / (s.A * diff(lim.eps) / 100);
Ecr   = diff(lim.F) * 1e3 / (s.A * diff(lim.D) / s.L0);
rows = {
    [tag 'Fmax'],      Fmax,             2
    [tag 'Fzehn'],     lim.F(1),         2
    [tag 'Ffuenfzig'], lim.F(2),         2
    [tag 'epsB'],      epsB,             3
    [tag 'DB'],        DB,               2
    [tag 'sigB'],      Fmax * 1e3 / s.A, 0
    [tag 'Es'],        Es / 1e3,         1
    [tag 'epsBmw'],    epsCr,            3
    [tag 'epsfak'],    epsB / epsCr,     2
    [tag 'Emw'],       Ecr / 1e3,        1
    [tag 'Efak'],      Es / Ecr,         2};
end

function out = firstCrossing(ref, val, q, iEnd)
% Value of val where ref first reaches q (linear interpolation).
% Searches the rising envelope of ref up to iEnd, so small dips in the
% curve don't cause a second crossing. q can be a vector.
env = cummax(ref(1:iEnd));
out = zeros(size(q));
for k = 1:numel(q)
    j = max(2, find([env; inf] >= q(k), 1));
    j = min(j, iEnd);
    w = 0;
    if ref(j) ~= ref(j-1), w = (q(k) - ref(j-1)) / (ref(j) - ref(j-1)); end
    out(k) = val(j-1) + w * (val(j) - val(j-1));
end
end

function i = fractureIndex(F, iMax)
% AlMg3 fracture point: start of the steepest force drop after Fmax.
w = 5;
[~, k] = min(F(iMax+w:end) - F(iMax:end-w));
i = iMax + k - 1;
end

function v = testSpeed(m)
% Median crosshead speed up to Fmax in mm/min (NaN if it never moves).
[~, i] = max(m.F);
v = diff(m.D(1:i)) ./ diff(m.t(1:i)) * 60;
v = median(v(v > 0.01));
end


%% ------------------------------------------------------------------------
%  Plotting
%  ------------------------------------------------------------------------

function cfrpPlots(c, lim, C, figDir, name, label, xStrain, ref, refLabel)
i = lim.i;
D = c.D - c.D(1);
for view = 1:2
    ax = newPlot();
    if view == 1
        x = c.eps; xl = lim.eps; xlab = xStrain; file = [name '_eps.pdf'];
        mk = ['{\itε}_B = ' num(x(i)) ' %'];
    else
        x = D; xl = lim.D - c.D(1); xlab = 'Crosshead displacement Δ{\itl} [mm]';
        file = [name '_mw.pdf'];
        mk = ['Δ{\itl}_B = ' num(x(i)) ' mm'];
    end
    if ~isempty(ref)
        [~, ir] = max(ref.F);
        if view == 1, xr = ref.eps; n = ir;
        else, xr = ref.D - ref.D(1); n = min(ir + 39, numel(xr)); end
        plot(ax, xr(1:n), ref.F(1:n), '--', 'Color', C.ref, 'LineWidth', 1.1, ...
            'DisplayName', refLabel);
    end
    plot(ax, x(1:i), c.F(1:i), 'Color', C.main, 'LineWidth', 1.4, 'DisplayName', label);
    limitLines(ax, lim.F, 'Secant modulus limits 10 % / 50 % {\itF}_{max}', C.lim);
    plot(ax, xl, lim.F, 'Color', C.lim, 'HandleVisibility', 'off');
    plot(ax, x(i), c.F(i), 'o', 'Color', C.mark, 'MarkerFaceColor', C.mark, ...
        'DisplayName', ['Fracture: {\itF}_{max} = ' num(c.F(i)) ' kN, ' mk]);
    savePlot(ax, fullfile(figDir, file), xlab);
end
end

function ax = newPlot()
f = figure('Visible', 'off', 'Units', 'inches', 'Position', [1 1 6 3.6], 'Color', 'w');
ax = axes(f);
hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
set(ax, 'FontName', 'Times New Roman', 'FontSize', 10, 'LineWidth', 0.6, ...
    'GridColor', [0.87 0.87 0.87], 'GridAlpha', 1);
ax.XAxis.Exponent = 0;
end

function savePlot(ax, file, xlab)
xlabel(ax, xlab);
ylabel(ax, 'Force {\itF} [kN]');
xl = xlim(ax); xlim(ax, [min(0, xl(1)), xl(2)]);
yl = ylim(ax); ylim(ax, [0, yl(2)]);
legend(ax, 'Location', 'best', 'Box', 'off', 'FontSize', 8.5);
exportgraphics(ax.Parent, file, 'ContentType', 'vector');
close(ax.Parent);
end

function limitLines(ax, F, label, color)
yline(ax, F(1), '--', 'Color', color, 'DisplayName', label);
yline(ax, F(2), '--', 'Color', color, 'HandleVisibility', 'off');
end


%% ------------------------------------------------------------------------
%  Number formatting
%  ------------------------------------------------------------------------

function s = num(v)
s = sprintf('%.2f', v);
end

function s = tex(v, nd)
% Decimal comma for the German report; NaN shows up as ?? in the PDF.
if isnan(v)
    s = '\textbf{??}';
else
    s = strrep(sprintf('%.*f', nd, v), '.', '{,}');
end
end

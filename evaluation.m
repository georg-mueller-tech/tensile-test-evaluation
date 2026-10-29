function evaluation()
% Tensile test evaluation - lab course "Scientific Experiment with Research
% Data Management", TUM LPL, winter semester 2026/27, Group 1.
%
% English version of auswertung.m (same calculation, English labels and
% decimal points). Used for the English report.
%
% Creates:
%   figures/*.pdf   diagrams (a)-(i) incl. evaluation points; the CFRP 0 deg
%                   diagrams also show the measurement after Fmax
%   results.tex     LaTeX macros with all characteristic values (loaded by the report)
%   results.csv     all characteristic values as a table
%
% Enter specimen dimensions and reference lengths from the test protocol in
% PROBEN below and run the script again. Missing values ([]) appear in the
% report as "??".
%
% Units of the raw data: force [kN], crosshead displacement [mm],
% strain gauge / extensometer strain [%].
%
% Usage: type "evaluation" in the folder of this file. Needs R2020a or
% newer (exportgraphics, xline/yline).

HERE = fileparts(mfilename('fullpath'));
DATA = fullfile(HERE, 'daten');
FIG = fullfile(HERE, 'figures');
if ~exist(FIG, 'dir'), mkdir(FIG); end

% ---------------------------------------------------------------------------
% Test protocol: width b [mm], thickness t [mm] (top/centre/bottom),
% reference length L0 [mm] for the strain from the crosshead displacement.
% ENTER HERE.  Missing value = []
% ---------------------------------------------------------------------------
PROBEN = struct();
% thickness: [top, centre, bottom]
PROBEN.Alu    = struct('b', 16.06, 't3', [4.04, 4.04, 4.05], 'L0', 65.00);    % AlMg3
PROBEN.CFK0   = struct('b', 16.20, 't3', [0.88, 0.87, 0.88], 'L0', 150.55);   % CFRP UD 0
PROBEN.CFK90  = struct('b', 16.25, 't3', [1.95, 1.90, 1.90], 'L0', 151.60);   % CFRP UD 90
PROBEN.CFK090 = struct('b', 15.85, 't3', [2.00, 2.00, 2.02], 'L0', 154.61);   % CFRP 0/90 (protocol Gr. 1)
pn = fieldnames(PROBEN);
for q = 1:numel(pn)
    PROBEN.(pn{q}).t = sum(PROBEN.(pn{q}).t3) / 3;
end

% Files: for 0/90 the Group 3 measurement is used as instructed
FILES = struct( ...
    'Alu_E',     'Messdaten_Gruppe_1/Alu_E.mat', ...
    'Alu_Bruch', 'Messdaten_Gruppe_1/Alu_Bruch.mat', ...
    'CFK0',      'Messdaten_Gruppe_1/CFK_0.mat', ...
    'CFK90',     'Messdaten_Gruppe_1/CFK_90.mat', ...
    'CFK090',    'Messdaten_Gruppe_3/CFK_090.mat', ...
    'CFK090_G1', 'Messdaten_Gruppe_1/CFK_090.mat', ...   % documentation only
    'CFK90_G3',  'Messdaten_Gruppe_3/CFK_90.mat');       % comparison only

% Colours (print, b/w readable through line styles)
C_MAIN = hex2rgb('#1f4e8c');   % measured curve
C_REF  = hex2rgb('#8a8a8a');   % comparison / invalid curve
C_MARK = hex2rgb('#c0392b');   % evaluation points
C_LIM  = hex2rgb('#2e8b57');   % modulus limits

% Results
R = struct('name', {{}}, 'val', {{}}, 'nd', {{}});


% ---------------------------------------------------------------------------
% AlMg3 elastic (modulus from extensometer, limits 0.01 % / 0.1 %)
% ---------------------------------------------------------------------------
a = load_('Alu_E');
[~, iA] = max(a.F);
e01 = 0.01; e1 = 0.1;  % [%]
F_e01 = at_value(a.eps, a.F, e01, iA);
F_e1  = at_value(a.eps, a.F, e1, iA);
D_e01 = at_force(a.F, a.D, F_e01, iA);
D_e1  = at_force(a.F, a.D, F_e1, iA);
put('AluFepsA', F_e01, 3);
put('AluFepsB', F_e1, 3);
A_alu = area('Alu');
if truthy(A_alu)
    E_alu_ext = (F_e1 - F_e01) * 1e3 / (A_alu * (e1 - e01) / 100);  % N/mm2
else
    E_alu_ext = [];
end
if truthy(E_alu_ext), put('AluEext', E_alu_ext / 1e3, 1); else, put('AluEext', [], 1); end  % kN/mm2 = GPa
if truthy(A_alu) && truthy(L0('Alu'))
    deps_mw = (D_e1 - D_e01) / L0('Alu');
    E_alu_mw = (F_e1 - F_e01) * 1e3 / (A_alu * deps_mw);
    put('AluEmw', E_alu_mw / 1e3, 1);
    put('AluEfak', E_alu_ext / E_alu_mw, 2);
else
    put('AluEmw', []); put('AluEfak', []);
end

% ---------------------------------------------------------------------------
% AlMg3 fracture
% ---------------------------------------------------------------------------
b = load_('Alu_Bruch');
[~, iB] = max(b.F);
iBr = fracture_index_ductile(b.F, iB);
put('AluFmax', b.F(iB), 2);
put('AluFbruch', b.F(iBr), 2);
put('AluDbruch', b.D(iBr) - b.D(1), 2);
if truthy(A_alu)
    put('AluRm', b.F(iB) * 1e3 / A_alu, 0);
    put('AluSigB', b.F(iBr) * 1e3 / A_alu, 0);
else
    put('AluRm', [], 0); put('AluSigB', [], 0);
end
if truthy(L0('Alu'))
    put('AluAmw', (b.D(iBr) - b.D(1)) / L0('Alu') * 100, 1);
else
    put('AluAmw', [], 1);
end


% ---------------------------------------------------------------------------
% CFRP: fracture force = Fmax, strain at Fmax, secant modulus 10-50 % Fmax
% ---------------------------------------------------------------------------
[cf0, i0, lim0] = eval_cfk('CFK0', 'CFK0', 'CFKnull');
[cf9, i9, lim9] = eval_cfk('CFK90', 'CFK90', 'CFKneunzig');
[cfx, ix, limx] = eval_cfk('CFK090', 'CFK090', 'CFKnullneunzig');

g1x = load_('CFK090_G1');
put('GeinsFmaxNullNeunzig', max(g1x.F), 2);
g3n = load_('CFK90_G3');
put('GdreiFmaxNeunzig', max(g3n.F), 2);
[~, ig3] = max(g3n.F);
put('GdreiEpsBNeunzig', g3n.eps(ig3), 3);


% ---------------------------------------------------------------------------
% Plots
% ---------------------------------------------------------------------------

% (a) AlMg3 elastic: F vs. extensometer strain
ax = newax();
plot(ax, a.eps(1:iA), a.F(1:iA), 'Color', C_MAIN, 'LineWidth', 1.4, ...
    'DisplayName', 'AlMg3, extensometer (Gr. 1)');
ev = [e01, e1]; Fv = [F_e01, F_e1];
for k = 1:2
    h = xline(ax, ev(k), '--', 'Color', C_LIM, 'LineWidth', 0.9);
    if k == 1
        h.DisplayName = 'Young''s modulus limits ε = 0.01 % / 0.1 %';
    else
        h.HandleVisibility = 'off';
    end
    plot(ax, ev(k), Fv(k), 'o', 'MarkerSize', 6, 'MarkerFaceColor', C_LIM, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 1.0, 'HandleVisibility', 'off');
end
plot(ax, [e01, e1], [F_e01, F_e1], 'Color', C_LIM, 'LineWidth', 1.0, 'HandleVisibility', 'off');
finish(ax, 'a_alu_elast_ext', 'Extensometer strain {\itε} [%]');

% (b) AlMg3 elastic: F vs. crosshead displacement
ax = newax();
plot(ax, a.D(1:iA), a.F(1:iA), 'Color', C_MAIN, 'LineWidth', 1.4, ...
    'DisplayName', 'AlMg3, crosshead displacement (Gr. 1)');
hline_lim(ax, F_e01, 'Forces at ε = 0.01 % / 0.1 %');
yline(ax, F_e1, '--', 'Color', C_LIM, 'LineWidth', 0.9, 'HandleVisibility', 'off');
plot(ax, [D_e01, D_e1], [F_e01, F_e1], 'o', 'MarkerSize', 6, 'MarkerFaceColor', C_LIM, ...
    'MarkerEdgeColor', 'w', 'LineWidth', 1.0, 'LineStyle', 'none', 'HandleVisibility', 'off');
finish(ax, 'b_alu_elast_mw', 'Crosshead displacement Δ{\itl} [mm]');

% (c) AlMg3 fracture: F vs. crosshead displacement
ax = newax();
Db = b.D - b.D(1);
n = min(iBr + 29, numel(b.F));
plot(ax, Db(1:n), b.F(1:n), 'Color', C_MAIN, 'LineWidth', 1.4, ...
    'DisplayName', 'AlMg3 to fracture (Gr. 1)');
mark(ax, Db(iB), b.F(iB), ['{\itF}_{max} = ' num(b.F(iB), 2) ' kN']);
plot(ax, Db(iBr), b.F(iBr), 's', 'MarkerSize', 6, 'MarkerFaceColor', C_MARK, ...
    'MarkerEdgeColor', 'w', 'LineWidth', 1.0, ...
    'DisplayName', ['Fracture: {\itF}_B = ' num(b.F(iBr), 2) ' kN']);
finish(ax, 'c_alu_bruch_mw', 'Crosshead displacement Δ{\itl} [mm]');

cfk0_full_plots(cf0, i0, lim0);
cfk_plots(cf9, i9, lim9, 'fg_cfk90', 'CFRP UD 90° (Gr. 1)', 'Extensometer strain {\itε} [%]', ...
    g3n, 'CFRP UD 90° (Gr. 3, comparison)');
cfk_plots(cfx, ix, limx, 'hi_cfk090', 'CFRP 0°/90° (Gr. 3, evaluated)', 'Strain gauge strain {\itε} [%]', ...
    g1x, 'CFRP 0°/90° (Gr. 1, tab slipped)');

% Testing speed (plausibility check, for report/DMP)
keys_ = {'Alu_E', 'Alu_Bruch', 'CFK0', 'CFK90', 'CFK090'};
speeds = struct();
for k = 1:numel(keys_)
    c = load_(keys_{k});
    [~, i] = max(c.F);
    dt = diff(c.t(1:i));
    v = diff(c.D(1:i)) ./ dt * 60;
    if any(v > 0.01)
        speeds.(keys_{k}) = median(v(v > 0.01));
    else
        speeds.(keys_{k}) = NaN;
    end
end
put('vAluE', speeds.Alu_E, 2);
put('vAluB', speeds.Alu_Bruch, 2);
put('vCFKnull', speeds.CFK0, 2);
put('vCFKneunzig', speeds.CFK90, 2);
put('vCFKnullneunzig', speeds.CFK090, 2);


% ---------------------------------------------------------------------------
% Export
% ---------------------------------------------------------------------------
fid = fopen(fullfile(HERE, 'results.tex'), 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', '% generated by evaluation.m - do not edit by hand');
for k = 1:numel(R.name)
    fprintf(fid, '%s\n', ['\newcommand{\R' R.name{k} '}{' fmt(R.val{k}, R.nd{k}) '}']);
end
TAG = struct('Alu', 'Alu', 'CFK0', 'CFKnull', 'CFK90', 'CFKneunzig', 'CFK090', 'CFKnullneunzig');
for q = 1:numel(pn)
    p = pn{q}; d = PROBEN.(p); tg = TAG.(p);
    t3s = cell(1, numel(d.t3));
    for k = 1:numel(d.t3), t3s{k} = fmt(d.t3(k), 2); end
    fprintf(fid, '%s\n', ['\newcommand{\P' tg 'b}{' fmt(d.b, 2) '}']);
    fprintf(fid, '%s\n', ['\newcommand{\P' tg 't}{' fmt(d.t, 3) '}']);
    fprintf(fid, '%s\n', ['\newcommand{\P' tg 'tdrei}{' strjoin(t3s, ' / ') '}']);
    fprintf(fid, '%s\n', ['\newcommand{\P' tg 'L}{' fmt(d.L0, 1) '}']);
    fprintf(fid, '%s\n', ['\newcommand{\P' tg 'A}{' fmt(area(p), 2) '}']);
end
fclose(fid);

fid = fopen(fullfile(HERE, 'results.csv'), 'w', 'n', 'UTF-8');
fprintf(fid, 'quantity,value\r\n');
for k = 1:numel(R.name)
    fprintf(fid, '%s,%s\r\n', R.name{k}, csvnum(R.val{k}));
end
fclose(fid);

missing = {};
for q = 1:numel(pn)
    d = PROBEN.(pn{q});
    if isempty(d.b) || isempty(d.t3) || isempty(d.L0) || isempty(d.t)
        missing{end+1} = pn{q}; %#ok<AGROW>
    end
end
fprintf('Done. Figures in figures/, values in results.tex/.csv\n');
if ~isempty(missing)
    fprintf('Missing specimen dimensions for: %s\n', strjoin(missing, ', '));
end
for k = 1:numel(R.name)
    fprintf('  %-24s %s\n', R.name{k}, fmt(R.val{k}, R.nd{k}));
end


% ===========================================================================
% Nested functions (share PROBEN, FILES, R etc.)
% ===========================================================================
    function m = load_(key)
        % named load_ because load is a MATLAB built-in
        s = load(fullfile(DATA, FILES.(key)));
        F = s.Load(:);
        % as in the chair script: trim displacement vector to the length of the force vector
        D = s.Displacement(:);
        D = D(max(1, end - numel(F) + 1):end);
        e = [];
        kk = {'Strain', 'Extensometer'};
        for jj = 1:2
            if isfield(s, kk{jj})
                e = s.(kk{jj})(:);
                e = e(1:min(end, numel(F)));
            end
        end
        m = struct('F', F, 'D', D, 'eps', e, 't', s.Load_time(:));
    end

    function A = area(p)
        d = PROBEN.(p);
        if isempty(d.b) || isempty(d.t)
            A = [];
        else
            A = d.b * d.t;
        end
    end

    function L = L0(p)
        L = PROBEN.(p).L0;
    end

    function put(name, val, nd)
        if nargin < 3, nd = 2; end
        if ~isempty(val), val = double(val); end
        ir_ = find(strcmp(R.name, name), 1);
        if isempty(ir_), ir_ = numel(R.name) + 1; R.name{ir_} = name; end
        R.val{ir_} = val;
        R.nd{ir_} = nd;
    end

    function [c, i, lim] = eval_cfk(key, p, tag)
        c = load_(key);
        [Fmax, i] = max(c.F);
        F10 = 0.1 * Fmax; F50 = 0.5 * Fmax;
        eps10 = at_force(c.F, c.eps, F10, i);
        eps50 = at_force(c.F, c.eps, F50, i);
        D10 = at_force(c.F, c.D, F10, i);
        D50 = at_force(c.F, c.D, F50, i);
        eps_B = c.eps(i);
        D_B = c.D(i) - c.D(1);
        A = area(p);
        put([tag 'Fmax'], Fmax, 2);
        put([tag 'Fzehn'], F10, 2);
        put([tag 'Ffuenfzig'], F50, 2);
        put([tag 'epsB'], eps_B, 3);
        put([tag 'DB'], D_B, 2);
        if truthy(A)
            put([tag 'sigB'], Fmax * 1e3 / A, 0);
            E_s = 0.4 * Fmax * 1e3 / (A * (eps50 - eps10) / 100);
        else
            put([tag 'sigB'], [], 0);
            E_s = [];
        end
        if truthy(E_s), put([tag 'Es'], E_s / 1e3, 1); else, put([tag 'Es'], [], 1); end
        if truthy(L0(p))
            eps_B_mw = D_B / L0(p) * 100;
            put([tag 'epsBmw'], eps_B_mw, 3);
            put([tag 'epsfak'], eps_B / eps_B_mw, 2);
            if truthy(A)
                E_mw = 0.4 * Fmax * 1e3 / (A * (D50 - D10) / L0(p));
                put([tag 'Emw'], E_mw / 1e3, 1);
                put([tag 'Efak'], E_s / E_mw, 2);
            else
                put([tag 'Emw'], []); put([tag 'Efak'], []);
            end
        else
            kk = {'epsBmw', 'epsfak', 'Emw', 'Efak'};
            for jj = 1:numel(kk), put([tag kk{jj}], []); end
        end
        lim = [F10, F50, eps10, eps50, D10, D50];
    end

    function ax = newax()
        % figure with common formatting
        f = figure('Visible', 'off', 'Units', 'inches', 'Position', [1 1 6.0 3.6], 'Color', 'w');
        ax = axes(f);
        hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
        set(ax, 'FontName', 'Times New Roman', 'FontSize', 10, 'LineWidth', 0.6, ...
            'GridColor', hex2rgb('#dddddd'), 'GridAlpha', 1, 'TickLabelInterpreter', 'tex');
        ax.XAxis.Exponent = 0;   % no x10^n axis label
    end

    function finish(ax, name, xlabel_, show_legend)
        if nargin < 4, show_legend = true; end
        xlabel(ax, xlabel_);
        ylabel(ax, 'Force {\itF} [kN]');
        xl = xlim(ax); xlim(ax, [min(0, xl(1)), xl(2)]);
        yl = ylim(ax); ylim(ax, [0, yl(2)]);
        if show_legend
            legend(ax, 'Location', 'best', 'Box', 'off', 'FontSize', 8.5);
        end
        exportgraphics(ax.Parent, fullfile(FIG, [name '.pdf']), 'ContentType', 'vector');
        close(ax.Parent);
    end

    function hline_lim(ax, F, label)
        yline(ax, F, '--', 'Color', C_LIM, 'LineWidth', 0.9, 'DisplayName', label);
    end

    function mark(ax, x, y, label)
        plot(ax, x, y, 'o', 'MarkerSize', 6, 'MarkerFaceColor', C_MARK, ...
            'MarkerEdgeColor', 'w', 'LineWidth', 1.0, 'DisplayName', label);
    end

    function cfk0_full_plots(c, i, lim)
        % CFRP 0 deg: measurement up to Fmax (blue) and after Fmax (grey dashed)
        F10 = lim(1); F50 = lim(2); eps10 = lim(3); eps50 = lim(4); D10 = lim(5); D50 = lim(6);
        D = c.D - c.D(1);
        xs = {c.eps, D};
        seg = {[eps10, eps50], [D10 - c.D(1), D50 - c.D(1)]};
        xlabs = {'Strain gauge strain {\itε} [%]', 'Crosshead displacement Δ{\itl} [mm]'};
        pts = {['Maximum force: {\itF}_{max} = ' num(c.F(i), 2) ' kN, {\itε}({\itF}_{max}) = ' num(c.eps(i), 2) ' %'], ...
               ['Maximum force: {\itF}_{max} = ' num(c.F(i), 2) ' kN, Δ{\itl}({\itF}_{max}) = ' num(D(i), 2) ' mm']};
        names = {'de_cfk0_full_eps', 'de_cfk0_full_mw'};
        for kk = 1:2
            x = xs{kk};
            ax = newax();
            plot(ax, x(1:i), c.F(1:i), 'Color', C_MAIN, 'LineWidth', 1.4, ...
                'DisplayName', 'CFRP UD 0° (Gr. 1), up to {\itF}_{max}');
            plot(ax, x(i:end), c.F(i:end), '--', 'Color', C_REF, 'LineWidth', 1.0, ...
                'DisplayName', 'Data after {\itF}_{max}');
            hline_lim(ax, F10, 'Secant modulus limits 10 % / 50 % {\itF}_{max}');
            yline(ax, F50, '--', 'Color', C_LIM, 'LineWidth', 0.9, 'HandleVisibility', 'off');
            plot(ax, seg{kk}, [F10, F50], 'Color', C_LIM, 'LineWidth', 1.0, 'HandleVisibility', 'off');
            mark(ax, x(i), c.F(i), pts{kk});
            finish(ax, names{kk}, xlabs{kk});
        end
    end

    function cfk_plots(c, i, lim, name, title_, xlab_eps, ref, ref_label)
        F10 = lim(1); F50 = lim(2); eps10 = lim(3); eps50 = lim(4); D10 = lim(5); D50 = lim(6);
        % strain
        ax = newax();
        if ~isempty(ref)
            [~, ir] = max(ref.F);
            plot(ax, ref.eps(1:ir), ref.F(1:ir), '--', 'Color', C_REF, 'LineWidth', 1.1, ...
                'DisplayName', ref_label);
        end
        plot(ax, c.eps(1:i), c.F(1:i), 'Color', C_MAIN, 'LineWidth', 1.4, 'DisplayName', title_);
        hline_lim(ax, F10, 'Secant modulus limits 10 % / 50 % {\itF}_{max}');
        yline(ax, F50, '--', 'Color', C_LIM, 'LineWidth', 0.9, 'HandleVisibility', 'off');
        plot(ax, [eps10, eps50], [F10, F50], 'Color', C_LIM, 'LineWidth', 1.0, 'HandleVisibility', 'off');
        mark(ax, c.eps(i), c.F(i), ['Fracture: {\itF}_{max} = ' num(c.F(i), 2) ' kN, {\itε}_B = ' ...
            num(c.eps(i), 2) ' %']);
        finish(ax, [name '_eps'], xlab_eps);
        % crosshead displacement
        ax = newax();
        if ~isempty(ref)
            [~, ir] = max(ref.F);
            Dr = ref.D - ref.D(1);
            nr = min(ir + 39, numel(ref.F));
            plot(ax, Dr(1:nr), ref.F(1:nr), '--', 'Color', C_REF, 'LineWidth', 1.1, ...
                'DisplayName', ref_label);
        end
        D = c.D - c.D(1);
        plot(ax, D(1:i), c.F(1:i), 'Color', C_MAIN, 'LineWidth', 1.4, 'DisplayName', title_);
        hline_lim(ax, F10, 'Secant modulus limits 10 % / 50 % {\itF}_{max}');
        yline(ax, F50, '--', 'Color', C_LIM, 'LineWidth', 0.9, 'HandleVisibility', 'off');
        plot(ax, [D10 - c.D(1), D50 - c.D(1)], [F10, F50], 'Color', C_LIM, 'LineWidth', 1.0, ...
            'HandleVisibility', 'off');
        mark(ax, D(i), c.F(i), ['Fracture: {\itF}_{max} = ' num(c.F(i), 2) ' kN, Δ{\itl}_B = ' ...
            num(D(i), 2) ' mm']);
        finish(ax, [name '_mw'], 'Crosshead displacement Δ{\itl} [mm]');
    end

end


% ===========================================================================
% Local helper functions. All indices are 1-based; i_end is the index of Fmax.
% ===========================================================================
function Fm = rising(F, i_end)
% Monotonically increasing envelope up to i_end (for unique interpolation).
Fm = cummax(F(1:i_end));
end

function j = searchsorted_(xm, xq, i_end)
% index of the first element >= xq, limited to [2, i_end]
j = find(xm >= xq, 1);
if isempty(j), j = numel(xm) + 1; end
j = max(2, min(j, i_end));
end

function val = at_force(F, x, Fq, i_end)
% Value of x when the force first reaches Fq (linear interpolation).
Fm = rising(F, i_end);
j = searchsorted_(Fm, Fq, i_end);
f0 = F(j - 1); f1 = F(j);
if f1 == f0, w = 0.0; else, w = (Fq - f0) / (f1 - f0); end
val = x(j - 1) + w * (x(j) - x(j - 1));
end

function val = at_value(x, F, xq, i_end)
% Force when x first reaches xq (e.g. strain 0.01 %).
xm = cummax(x(1:i_end));
j = searchsorted_(xm, xq, i_end);
x0 = x(j - 1); x1 = x(j);
if x1 == x0, w = 0.0; else, w = (xq - x0) / (x1 - x0); end
val = F(j - 1) + w * (F(j) - F(j - 1));
end

function i = fracture_index_ductile(F, i_max)
% Fracture point AlMg3: start of the steepest force drop after Fmax.
w = 5;
dF = F(i_max + w:end) - F(i_max:end - w);
[~, k] = min(dF);
i = i_max + k - 1;
end

function tf = truthy(x)
% empty and 0 are false, NaN is true
tf = ~isempty(x) && x ~= 0;
end

function s = fmt(v, nd)
if isempty(v) || isnan(v)
    s = '\textbf{??}';
    return
end
s = sprintf('%.*f', nd, v);
end

function s = num(v, nd)
% number for legends (decimal point)
s = sprintf('%.*f', nd, v);
end

function s = csvnum(v)
% value rounded to 4 decimals
if isempty(v), s = ''; return, end
if isnan(v), s = 'nan'; return, end
if isinf(v)
    if v > 0, s = 'inf'; else, s = '-inf'; end
    return
end
r = round(v * 1e4) / 1e4;
s = sprintf('%.15g', r);
if ~any(s == '.') && ~any(s == 'e'), s = [s '.0']; end
end

function c = hex2rgb(h)
c = sscanf(h(2:end), '%2x%2x%2x', [1 3]) / 255;
end

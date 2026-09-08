%% LLC Resonant Converter Design & Multi-Load Gain + Input Impedance (FHA)
% Specs: Vin = 2200 Vdc, Vout = 24 Vdc, Power = 20..100 W
%
% Notes:
% - n = Np/Ns (PRIMARY / SECONDARY)
% - Required tank gain: Gt_req = (Vout * n) / (kbridge * Vin)
% - Q = (omega_r * Lr) / Rac,  Rac = (8/pi^2) * n^2 * Rdc,  Rdc = V^2/P
% - ZVS region (inductive as seen by bridge): Imag(Zin) > 0
%
% Figures:
%  * Figure 1: Gain curves vs normalized frequency (colorbar = load power)
%  * Figure 2: Input impedance (Imag and Real) vs normalized frequency
%  * Figure 3: Imag(Zin) zero-crossings (inside controller window), traces + markers
%
% Author: (you)

clear; clc; close all;

%% ---------------------- Your Specs ----------------------
spec.Vin_min   = 300;    % [V]
spec.Vin_max   = 2600;   % [V]
spec.Vout_min  = 36;     % [V]
spec.Vout_max  = 36;     % [V]
spec.Pout_max  = 100;    % [W] maximum power

spec.topology  = 'half'; % 'half' or 'full'
kbridge        = strcmpi(spec.topology,'half') * 0.5 + strcmpi(spec.topology,'full') * 1;

%Vin_nom       = 0.5*(spec.Vin_min + spec.Vin_max);
Vin_nom        = 2600;
Vout_nom       = 0.5*(spec.Vout_min + spec.Vout_max);

% Resonant frequency (choose per devices/magnetics)
fr      = 300e3;   % [Hz]
omega_r = 2*pi*fr;

% Normalized frequency axis
fn_vec  = linspace(0.4, 8.0, 16010);

% Design choices (starting point)
Ln        = 6;      % Ln = Lm/Lr
Q_design  = 0.5;   % Q at worst-case design point (heavy load)
% Controller window (normalized)
fn_min = 1.0;
fn_max = 4.80;

% Load sweep in POWER (W)
Pout_vec = [10 20 30 40 50 60 70 80 90 100]; % [W]
Vout_set = spec.Vout_min;                    % 24 V
% ---------------------------------------------------------

%% Transformer turns ratio (n = Np/Ns)
% Target Gt ~ 1 near fn=1 -> choose n accordingly
n = (kbridge * Vin_nom) / Vout_nom;

%% Required tank gain bounds (red lines in Figure 1)
% Gt_req = (Vout * n) / (kbridge * Vin)
Gt_req_max = (spec.Vout_max * n) / (kbridge * spec.Vin_min);
Gt_req_min = (spec.Vout_min * n) / (kbridge * spec.Vin_max);

%% Size Lr, Cr, Lm from Ln, Q_design at worst-case corner (Vin_min, Vout_max, Pout_max)
Vout_wc = spec.Vout_max;
Vin_wc  = spec.Vin_min;
Pout_wc = spec.Pout_max;

Rdc_wc  = (Vout_wc^2) / Pout_wc;   % [ohm]
Rpri_wc = (n^2) * Rdc_wc;          % primary referred
Rac_wc  = (8/pi^2) * Rpri_wc;      % FHA AC equivalent

Lr = Q_design * Rac_wc / omega_r;  % from Q = (w_r*Lr)/Rac
Cr = 1 / (omega_r^2 * Lr);         % from fr = 1/(2*pi*sqrt(Lr*Cr))
Lm = Ln * Lr;

%% Helpers (normalized model uses Lr=1, Cr=1, Lm=Ln, Rac=1/Q)
Gt_norm     = @(fn, Ln, Q) llc_gt_norm_vs_over_vp(fn, Ln, Q);
zin_norm    = @(fn, Ln, Q) llc_input_impedance_norm(fn, Ln, Q);
is_inductive = @(fn, Ln, Q) imag(zin_norm(fn, Ln, Q)) > 0;

% Compute Q at (Vout, Pout) using physical Lr & fr
% Rdc = V^2/P; Rac = (8/pi^2) * n^2 * Rdc
compute_Q_from_power = @(Vout, Pout) ...
    (omega_r * Lr) / ((8/pi^2) * n^2 * (Vout^2 / max(Pout,1e-6)));
%% Peak gain estimate at very light load (small Q)
Q_very_light = 0.05;
Gt_peak_curve = Gt_norm(fn_vec, Ln, Q_very_light);
Gt_peak_curve(~is_inductive(fn_vec, Ln, Q_very_light)) = NaN;
[Gt_peak, idx_peak] = max(Gt_peak_curve);
fn_at_peak = fn_vec(idx_peak);

%% Suggested fn window using heavy-load worst case (Vout_max, Pout_max)
Q_heavy_wc  = compute_Q_from_power(spec.Vout_max, spec.Pout_max);
Gt_heavy_wc = Gt_norm(fn_vec, Ln, Q_heavy_wc);
Gt_heavy_wc(~is_inductive(fn_vec, Ln, Q_heavy_wc)) = NaN;

idx_l = find(Gt_heavy_wc >= (1.02*Gt_req_max) & fn_vec > 1, 1, 'first');
if isempty(idx_l), idx_l = find(fn_vec > 1, 1, 'first'); end
fn_min_suggest = max([fn_vec(idx_l), 1.02]);

idx_u = find(Gt_heavy_wc <= Gt_req_min & fn_vec > fn_min_suggest, 1, 'first');
if isempty(idx_u), fn_max_suggest = min([fn_max, max(fn_vec)]);
else, fn_max_suggest = fn_vec(idx_u);
end

fs_min         = fn_min * fr;
fs_max         = fn_max * fr;
fs_min_suggest = fn_min_suggest * fr;
fs_max_suggest = fn_max_suggest * fr;

%% ----------------------- Figure 1: Gain (context) -----------------------
figure('Color','w','Name','Figure 1 - LLC Gain Response (2600V -> 36V)');
hold on; grid on; box on;

% Family of gain curves by load (parula colormap)
nLoads = numel(Pout_vec);
cmap   = parula(nLoads);

for li = 1:nLoads
    Pout_i = Pout_vec(li);
    Q_i    = compute_Q_from_power(Vout_set, Pout_i);
    Gt_i   = Gt_norm(fn_vec, Ln, Q_i);
    plot(fn_vec, Gt_i, 'Color', cmap(li,:), 'LineWidth', 1.6);
end
% ---- Required tank gain lines (with your requested legend text)
h_mgmax = yline(Gt_req_max, 'r-', 'LineWidth', 2.0, ...
    'DisplayName', sprintf('Vin_{min} = %.0f V', spec.Vin_min));
h_mgmin = yline(Gt_req_min, 'Color', [0.8 0 0], 'LineStyle', '--', 'LineWidth', 1.6, ...
    'DisplayName', sprintf('Vin_{max} = %.0f V', spec.Vin_max));

% Peak and windows
h_peak     = plot(fn_at_peak, Gt_peak, 'ko', 'MarkerFaceColor', 'y', 'DisplayName', 'Max Peak (very light load)');
h_fnmin    = xline(fn_min, 'k--', 'LineWidth', 1.2, 'DisplayName', sprintf('f_n^{min}=%.2f', fn_min));
h_fnmax    = xline(fn_max, 'k-.', 'LineWidth', 1.2, 'DisplayName', sprintf('f_n^{max}=%.2f', fn_max));
h_fnminsug = xline(fn_min_suggest, 'b--', 'LineWidth', 1.2, 'DisplayName', sprintf('f_n^{min} (suggested)=%.2f', fn_min_suggest));
h_fnmaxsug = xline(fn_max_suggest, 'b-.', 'LineWidth', 1.2, 'DisplayName', sprintf('f_n^{max} (suggested)=%.2f', fn_max_suggest));

xlabel('Normalized frequency, f_n = f / f_r');
ylabel('Tank gain, G_t = |V_{s,refPri} / V_p|');
title('Figure 1 - LLC Tank Gain vs Normalized Frequency');

% Colorbar keyed to load power
colormap(parula);
cb1 = colorbar('Location','eastoutside');
cb1.Label.String = 'Load power (W)';
nTicks1 = min(numel(Pout_vec), 8);
idx1 = round(linspace(1, numel(Pout_vec), nTicks1));
cb1.Ticks = linspace(0, 1, nTicks1);
cb1.TickLabels = arrayfun(@(p) sprintf('%d', p), Pout_vec(idx1), 'UniformOutput', false);

% Compact overlays legend (includes your two red lines)
lg1 = legend([h_mgmax, h_mgmin, h_peak, h_fnmin, h_fnmax, h_fnminsug, h_fnmaxsug], ...
    'Location', 'northeastoutside', 'Box', 'on');
lg1.Title.String = 'Overlays';

%% === Inline labels for Figure 1 curves (place labels near the right side) ===
% Choose where (in normalized frequency) to place the labels.
% Option A: near the right edge of the plot (use last 10% of fn_vec to find a stable point)
fn_right = fn_vec(round(numel(fn_vec)*0.95));

% Option B (alternative): lock to the controller window upper bound
% fn_right = min(fn_max, fn_vec(end));

% Safety: if fn_right not exactly on grid, we will interpolate
fn_grid = fn_vec;

% Build a small helper to interpolate y at chosen fn
interp_at_fn = @(fn_target, fn_grid, ygrid) ...
    interp1(fn_grid, ygrid, fn_target, 'linear', 'extrap');

%% === ZVS boundary (Imag(Zin)=0) per load, with dashed connecting curve ===
% This block finds, for each load in Pout_vec, the fn where Imag(Zin)=0 (closest to fn=1),
% computes the corresponding tank gain Gt at that point, and plots:
%   - a colored marker (same color as that load curve),
%   - a black dashed curve through all valid boundary points.

% Make sure we use the same colormap & load list as the gain curves
nLoads = numel(Pout_vec);
cmap   = parula(nLoads);

boundary_pts = nan(nLoads, 2);   % columns: [fn_boundary, Gt_at_boundary]

for li = 1:nLoads
    Pout_i = Pout_vec(li);

    % Q for this load (uses your physical Lr and fr)
    Q_i = compute_Q_from_power(Vout_set, Pout_i);

    % Imag(Zin) over fn
    ImagZ = imag( zin_norm(fn_vec, Ln, Q_i) );

    % All zero-crossings
    zc_idx = find(diff(sign(ImagZ)) ~= 0);

    if isempty(zc_idx)
        % No boundary in this fn range for this load -> skip
        continue;
    end

% Interpolate exact fn at each zero-crossing
fn_cand = zeros(1, numel(zc_idx));
for k = 1:numel(zc_idx)
    f1 = fn_vec(zc_idx(k));    f2 = fn_vec(zc_idx(k)+1);
    y1 = ImagZ(zc_idx(k));     y2 = ImagZ(zc_idx(k)+1);
    if (y2 - y1) == 0
        fn_cand(k) = NaN;      % degenerate (shouldn't happen)
    else
        fn_cand(k) = f1 - y1*(f2 - f1)/(y2 - y1);
    end
end
fn_cand = fn_cand(isfinite(fn_cand));

if isempty(fn_cand)
    continue;
end

% Pick the crossing closest to fn=1 (the practical ZVS/ZCS boundary)
[~, kmin] = min(abs(fn_cand - 1));
fn_b = fn_cand(kmin);

% Gain at the boundary for this load
Gt_b = Gt_norm(fn_b, Ln, Q_i);   % scalar OK

% Store and plot the boundary point
boundary_pts(li, :) = [fn_b, Gt_b];
plot(fn_b, Gt_b, 'o', ...
    'Color', cmap(li,:), 'MarkerFaceColor', cmap(li,:), ...
    'MarkerSize', 6, 'HandleVisibility','off');

end

% Connect valid points with a dashed line (sorted by fn for a clean curve)
valid = ~isnan(boundary_pts(:,1));
if any(valid)
    pts = boundary_pts(valid, :);
    [fn_sorted, ord] = sort(pts(:,1));
    Gt_sorted = pts(ord, 2);
    h_zvs_curve = plot(fn_sorted, Gt_sorted, 'k--', 'LineWidth', 2.0, ...
    'DisplayName', 'ZVS boundary (per load)');
uistack(h_zvs_curve, 'top');  % keep it visible

% Optional label close to the rightmost boundary point
try
    text(fn_sorted(end), Gt_sorted(end), ' ZVS boundary', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold', 'Color', 'k', 'Clipping', 'on');
catch
    % Safe no-op if text placement fails (e.g., empty arrays)
end
else
    % Nothing found in this fn range — leave a console note
    disp('NOTE: No Imag(Zin)=0 boundary found for any load within current fn_vec range.');
end

% Retrieve current axes for Figure 1
ax1 = gca; hold(ax1, 'on');

uistack(ax1, 'top');

%% === Inline labels for the two required-gain red lines ===
% Sample a y slightly to the right, and print Vin_min / Vin_max text near that height.

% Position the labels near the rightmost edge of the current x-limits
xl = xlim(ax1);
xr = xl(2);

% Small vertical offsets so the two red-line labels don't overlap
dy_red = 0.015 * range(ylim(ax1));

% Label for Gt_req_max (Vin_min)
text(ax1, xr - 0.02*(xl(2)-xl(1)), Gt_req_max + dy_red, ...
    sprintf('Vin_{min} = %.0f V', spec.Vin_min), ...
    'Color', 'r', 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'Clipping', 'on');

% Label for Gt_req_min (Vin_max)
text(ax1, xr - 0.02*(xl(2)-xl(1)), Gt_req_min - dy_red, ...
    sprintf('Vin_{max} = %.0f V', spec.Vin_max), ...
    'Color', [0.8 0 0], 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'Clipping', 'on');

%% === Restore & bring-to-front the four frequency guide lines in Figure 1 (HORIZONTAL labels) ===
fig1 = gcf; ax1 = gca; hold(ax1,'on');

% Keep x-limits stable so label positions don't shift axes
xlim(ax1, [min(fn_vec) max(fn_vec)]);

% Remove any previous guide lines we created (safe if none exist)
delete(findall(ax1, 'Tag','fn_guide_line'));

% % Recreate all four frequency guides with consistent styling + DisplayName
% h_fnmin  = xline(ax1, fn_min, ...
%     'k-.', 'LineWidth', 1.4, ...
%     'Tag','fn_guide_line', ...
%     'DisplayName', sprintf('f_n^{min}=%.2f', fn_min));
%
% h_fnmax  = xline(ax1, fn_max, ...
%     'k-.', 'LineWidth', 1.4, ...
%     'Tag','fn_guide_line', ...
%     'DisplayName', sprintf('f_n^{max}=%.2f', fn_max));
%
% h_fnminsug = xline(ax1, fn_min_suggest, ...
%     'b--', 'LineWidth', 1.4, ...
%     'Tag','fn_guide_line', ...
%     'DisplayName', sprintf('f_n^{min} (suggested)=%.2f', fn_min_suggest));
%
% h_fnmaxsug = xline(ax1, fn_max_suggest, ...
%     'b--', 'LineWidth', 1.4, ...
%     'Tag','fn_guide_line', ...
%     'DisplayName', sprintf('f_n^{max} (suggested)=%.2f', fn_max_suggest));

% Bring guides above curves/patches
uistack([h_fnmin h_fnmax h_fnminsug h_fnmaxsug], 'top');

% ---------- Horizontal labels (no rotation) ----------
yl = ylim(ax1);
x_pad = 0.002 * range(xlim(ax1));   % tiny horizontal offset so text doesn't overlap the line

y_up1 = yl(2) - 0.035 * range(yl);  % two y-levels to stagger labels
y_up2 = yl(2) - 0.075 * range(yl);

common_text_opts = {'Rotation', 0, 'FontWeight','bold', ...
    'BackgroundColor','w', 'EdgeColor','none', ...
    'Margin', 2, 'Clipping','on'};

% Place the labels slightly to the right/left of the line x-positions
% (choose alignment to keep the label inside the axes)
text(ax1, fn_min + x_pad, y_up1, sprintf('f_n^{min}=%.2f', fn_min), ...
    'Color','k', 'HorizontalAlignment','left', 'VerticalAlignment','top', common_text_opts{:});

text(ax1, fn_max - x_pad, y_up2, sprintf('f_n^{max}=%.2f', fn_max), ...
    'Color','k', 'HorizontalAlignment','right', 'VerticalAlignment','top', common_text_opts{:});

text(ax1, fn_min_suggest + x_pad, y_up2, ...
    sprintf('f_n^{min} (sugg.)=%.2f', fn_min_suggest), ...
    'Color','b', 'HorizontalAlignment','left', 'VerticalAlignment','top', common_text_opts{:});

text(ax1, fn_max_suggest - x_pad, y_up1, ...
    sprintf('f_n^{max} (sugg.)=%.2f', fn_max_suggest), ...
    'Color','b', 'HorizontalAlignment','right', 'VerticalAlignment','top', common_text_opts{:});

ylim([0.9, 1.5]);

% (Optional) If you prefer to remove or simplify the overlays legend after inline labels:
% delete(lg1);  % <-- uncomment to remove the overlays legend entirely

%% -------------------- Figure 2: Input Impedance (ZVS check) --------------------
% Plot REAL(Zin) and IMAG(Zin) vs fn with colorbar and overlays legend
fig2 = figure('Color','w','Name','Figure 2 - LLC Input Impedance vs f_n (ZVS Check)');
tlo = tiledlayout(fig2, 2, 1, 'Padding','compact','TileSpacing','compact');

% (a) Imag(Zin)
ax_im = nexttile(tlo, 1); hold(ax_im,'on'); grid(ax_im,'on'); box(ax_im,'on');
for li = 1:nLoads
    Pout_i = Pout_vec(li);
    Q_i    = compute_Q_from_power(Vout_set, Pout_i);
    Zin_i  = zin_norm(fn_vec, Ln, Q_i); % normalized impedance
    plot(ax_im, fn_vec, imag(Zin_i), 'Color', cmap(li,:), 'LineWidth', 1.6);
end
yline(ax_im, 0, 'k-', 'HandleVisibility','off');
h_res2  = xline(ax_im, 1, 'k:', 'Visible','off', 'DisplayName','Resonance (f_n=1)');
h_fmin2 = xline(ax_im, fn_min, 'k-.', 'Visible','off', 'DisplayName',sprintf('f_n^{min}=%.2f', fn_min));
h_fmax2 = xline(ax_im, fn_max, 'k-.', 'Visible','off', 'DisplayName',sprintf('f_n^{max}=%.2f', fn_max));
xlabel(ax_im, 'Normalized frequency, f_n = f / f_r');
ylabel(ax_im, 'Imag\{Z_{in}\} (normalized)');
title(ax_im, 'Figure 2a - Imag\{Z_{in}\} (inductive if > 0)');

% (b) Real(Zin)
ax_re = nexttile(tlo, 2); hold(ax_re,'on'); grid(ax_re,'on'); box(ax_re,'on');
for li = 1:nLoads
    Pout_i = Pout_vec(li);
    Q_i    = compute_Q_from_power(Vout_set, Pout_i);
    Zin_i  = zin_norm(fn_vec, Ln, Q_i);
    plot(ax_re, fn_vec, real(Zin_i), 'Color', cmap(li,:), 'LineWidth', 1.6);
end
h_res2b  = xline(ax_re, 1, 'k:', 'HandleVisibility','off');
h_fmin2b = xline(ax_re, fn_min, 'k-.', 'HandleVisibility','off');
h_fmax2b = xline(ax_re, fn_max, 'k-.', 'HandleVisibility','off');
xlabel(ax_re, 'Normalized frequency, f_n = f / f_r');
ylabel(ax_re, 'Real\{Z_{in}\} (normalized)');
title(ax_re, 'Figure 2b - Real\{Z_{in}\}');

% Shared colorbar (like Figure 1)
colormap(fig2, parula);
cb2 = colorbar(ax_re, 'Location','eastoutside'); % attach to bottom axes (either is fine)
cb2.Label.String = 'Load power (W)';
nTicks2 = min(numel(Pout_vec), 8);
idx2 = round(linspace(1, numel(Pout_vec), nTicks2));
cb2.Ticks = linspace(0, 1, nTicks2);
cb2.TickLabels = arrayfun(@(p) sprintf('%d', p), Pout_vec(idx2), 'UniformOutput', false);

% Compact overlays legend in the top subplot
axes(ax_im); % focus top axes
lg2 = legend([h_res2, h_fmin2, h_fmax2], 'Location','eastoutside','Box','on');
lg2.Title.String = 'Overlays';

%% -------------------- Figure 3: Imag(Zin) Zero-Crossings --------------------
% Robust plot: always show Imag{Zin} traces + mark zero-crossings within [fn_min, fn_max]
fig3 = figure('Color','w','Name','Figure 3 - Imag(Zin) Zero-Crossings (Window)');
hold on; grid on; box on;
search_in_window = true;   % toggle: search inside controller window (true) or full range (false)
any_crossings    = false;

% Use same colormap as Fig 1 for consistency
colormap(fig3, parula);
for li = 1:nLoads
    Pout_i = Pout_vec(li);
    Q_i    = compute_Q_from_power(Vout_set, Pout_i);
    Zin_i  = zin_norm(fn_vec, Ln, Q_i);
    imz    = imag(Zin_i);

    % Plot Imag(Zin) trace (thin)
    plot(fn_vec, imz, 'Color', cmap(li,:), 'LineWidth', 1.2, ...
        'DisplayName', sprintf('P_{out}=%dW', Pout_i));

    % Range to search for zero-crossings
    if search_in_window
        mask = (fn_vec >= fn_min) & (fn_vec <= fn_max);
    else
        mask = true(size(fn_vec));
    end
    fn_search = fn_vec(mask);
    im_search = imz(mask);

    % Find sign changes (exclude NaNs)
    valid = ~isnan(im_search) & isfinite(im_search);
    fnv = fn_search(valid);
    imv = im_search(valid);
    if numel(fnv) >= 2
        sgn = sign(imv);
        sc  = find(diff(sgn) ~= 0);   % sign changes
        for k = 1:numel(sc)
            f1 = fnv(sc(k));   f2 = fnv(sc(k)+1);
            y1 = imv(sc(k));   y2 = imv(sc(k)+1);
            if (y2 - y1) ~= 0
                fn_zc = f1 - y1*(f2 - f1)/(y2 - y1);
                plot(fn_zc, 0, 'o', 'MarkerSize', 7, ...
                    'Color', cmap(li,:), 'MarkerFaceColor', cmap(li,:), ...
                    'HandleVisibility','off');   % keep legend clean
                any_crossings = true;
            end
        end
    end
end

% Axes decorations
yline(0, 'k-', 'HandleVisibility','off');
h_res3  = xline(1, 'k:', 'Visible','off', 'DisplayName','Resonance (f_n=1)');
h_fmin3 = xline(fn_min, 'k-.', 'Visible','off', 'DisplayName',sprintf('f_n^{min}=%.2f', fn_min));
h_fmax3 = xline(fn_max, 'k-.', 'Visible','off', 'DisplayName',sprintf('f_n^{max}=%.2f', fn_max));

xlabel('Normalized frequency, f_n = f / f_r');
ylabel('Imag\{Z_{in}\} (normalized)');
title('Figure 3 - Imag\{Z_{in}\} Zero-Crossings (inside controller window)');

% Colorbar keyed to load power (like Figure 1)
cb3 = colorbar('Location','eastoutside');
cb3.Label.String = 'Load power (W)';
nTicks3 = min(numel(Pout_vec), 8);
idx3 = round(linspace(1, numel(Pout_vec), nTicks3));
cb3.Ticks = linspace(0, 1, nTicks3);
cb3.TickLabels = arrayfun(@(p) sprintf('%d', p), Pout_vec(idx3), 'UniformOutput', false);

% Compact overlays legend
lg3 = legend([h_res3, h_fmin3, h_fmax3], 'Location','eastoutside','Box','on');
lg3.Title.String = 'Overlays';

% If no crossings found, annotate clearly
if ~any_crossings
    yl = ylim; xl = xlim;
    txt = sprintf(['No Imag\\{Z_{in}\\} zero-crossings inside [f_n^{min}=%.2f, f_n^{max}=%.2f]\n' ...
        'ZVS maintained in the controller window for plotted loads'], fn_min, fn_max);
    text(xl(1) + 0.02*(xl(2)-xl(1)), yl(1) + 0.85*(yl(2)-yl(1)), txt, ...
        'Color',[0 0.5 0], 'FontWeight','bold');
end

%% -------------------- Figure 4: Tank & Magnetizing Currents (RMS) --------------------
% Compute and plot |I_tank,rms| and |I_m,rms| vs normalized frequency for your load sweep.
% Tank current = resonant branch current (series Lr-Cr), equal to input series current.
% Magnetizing current flows in Lm branch.

% We use physical impedances (Lr, Cr, Lm) and fundamental of applied bridge voltage:
% V1 = (4/pi) * kbridge * Vin
% Currents are plotted in absolute RMS amperes.

figure('Color','w','Name','Figure 4 - Tank & Magnetizing Currents vs f_n');
tlo4 = tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

% --- Choose which input voltage to use for this current plot:
Vin_for_current_plot = spec.Vin_min;   % (worst case gain / higher tank current). Change to spec.Vin_max if desired.

% Colormap consistent with Figure 1
nLoads = numel(Pout_vec);
cmap   = parula(nLoads);

% Helper: compute currents for a given operating condition
compute_currents = @(fnv, Vin, Vout, Pout) llc_currents_rms( ...
    fnv, Lr, Cr, Lm, n, kbridge, Vin, Vout, Pout, fr);

% ---------------- (a) Tank (series) current RMS ----------------
ax4a = nexttile(tlo4, 1); hold(ax4a,'on'); grid(ax4a,'on'); box(ax4a,'on');
for li = 1:nLoads
    Pout_i = Pout_vec(li);
    [I_tank_rms, I_mag_rms, ~, ~] = compute_currents(fn_vec, Vin_for_current_plot, Vout_set, Pout_i);
    plot(ax4a, fn_vec, I_tank_rms, 'Color', cmap(li,:), 'LineWidth', 1.7);
end
% Controller window markers
xline(ax4a, fn_min, 'k-.', 'HandleVisibility','off');
xline(ax4a, fn_max, 'k-.', 'HandleVisibility','off');
xlabel(ax4a, 'Normalized frequency, f_n = f / f_r');
ylabel(ax4a, 'I_{tank} (A_{RMS})');
title(ax4a, sprintf('Figure 4a - Tank (L_r-C_r series) current vs f_n @ V_{in}=%.0f V', Vin_for_current_plot));

% ---------------- (b) Magnetizing current RMS ----------------
ax4b = nexttile(tlo4, 2); hold(ax4b,'on'); grid(ax4b,'on'); box(ax4b,'on');
for li = 1:nLoads
    Pout_i = Pout_vec(li);
    [~, I_mag_rms, ~, ~] = compute_currents(fn_vec, Vin_for_current_plot, Vout_set, Pout_i);
    plot(ax4b, fn_vec, I_mag_rms, 'Color', cmap(li,:), 'LineWidth', 1.7);
end
xline(ax4b, fn_min, 'k-.', 'HandleVisibility','off');
xline(ax4b, fn_max, 'k-.', 'HandleVisibility','off');
xlabel(ax4b, 'Normalized frequency, f_n = f / f_r');
ylabel(ax4b, 'I_m (A_{RMS})');
title(ax4b, sprintf('Figure 4b - Magnetizing current vs f_n @ V_{in}=%.0f V', Vin_for_current_plot));

% Shared colorbar with load powers
colormap(parula);
cb4 = colorbar(ax4b, 'Location','eastoutside');
cb4.Label.String = 'Load power (W)';
nTicks4 = min(numel(Pout_vec), 8);
idx4 = round(linspace(1, numel(Pout_vec), nTicks4));
cb4.Ticks = linspace(0, 1, nTicks4);
cb4.TickLabels = arrayfun(@(p) sprintf('%d', p), Pout_vec(idx4), 'UniformOutput', false);

% (Optional) Fix x-limits to match your extended f_n axis (if you extended to 5.0 earlier)
% xlim([min(fn_vec) max(fn_vec)]);
%% ================= Combined Figure 1 + 3 (Gain + ZVS boundary & Zero-crossings) =================
fig13 = figure('Color','w','Name','Combined - Gain (with ZVS boundary) + Zero-Crossings');
tlo13 = tiledlayout(fig13, 2, 1, 'Padding','compact','TileSpacing','compact');
colormap(fig13, parula);

% Common styling
nLoads = numel(Pout_vec);
cmap   = parula(nLoads);

%% -------------------- TOP subplot: Gain + Required lines + ZVS shading + per-load ZVS boundary --------------------
axTop = nexttile(tlo13, 1); hold(axTop,'on'); grid(axTop,'on'); box(axTop,'on');
title(axTop,'Gain vs Normalized Frequency (with ZVS region & boundary)');
xlabel(axTop,'Normalized frequency, f_n = f / f_r');
ylabel(axTop,'Tank gain, G_t = |V_{s,refPri} / V_p|');

% 1) Plot the gain family by load
for li = 1:nLoads
    Pout_i = Pout_vec(li);
    Q_i    = compute_Q_from_power(Vout_set, Pout_i);
    Gt_i   = Gt_norm(fn_vec, Ln, Q_i);
    plot(axTop, fn_vec, Gt_i, 'Color', cmap(li,:), 'LineWidth', 1.6);
end

% 2) Required tank gain (your requested labels)
h_mgmax = yline(axTop, Gt_req_max, 'r-', 'LineWidth', 2.0, ...
    'DisplayName', sprintf('Vin_{min} = %.0f V', spec.Vin_min));
h_mgmin = yline(axTop, Gt_req_min, 'Color',[0.8 0 0], 'LineStyle','--', 'LineWidth', 1.6, ...
    'DisplayName', sprintf('Vin_{max} = %.0f V', spec.Vin_max));

% 3) Controller window guide lines
h_fnmin    = xline(axTop, fn_min, 'k-.', 'LineWidth', 1.4, 'DisplayName', sprintf('f_n^{min}=%.2f', fn_min));
h_fnmax    = xline(axTop, fn_max, 'k-.', 'LineWidth', 1.4, 'DisplayName', sprintf('f_n^{max}=%.2f', fn_max));
h_fnminsug = xline(axTop, fn_min_suggest, 'b--', 'LineWidth', 1.4, ...
    'DisplayName', sprintf('f_n^{min} (suggested)=%.2f', fn_min_suggest));
h_fnmaxsug = xline(axTop, fn_max_suggest, 'b--', 'LineWidth', 1.4, ...
    'DisplayName', sprintf('f_n^{max} (suggested)=%.2f', fn_max_suggest));

% 4) Shade the ZVS region (Imag{Zin} > 0) for a representative worst-case (Vout_max, Pout_max)
Q_zvs  = compute_Q_from_power(spec.Vout_max, spec.Pout_max);
Zin_wc = zin_norm(fn_vec, Ln, Q_zvs);
zvs_mask = imag(Zin_wc) > 0;

if any(zvs_mask)
    ylTop = ylim(axTop);
    xZ = fn_vec(zvs_mask);
    yZ = [ylTop(1)*ones(size(xZ)), ylTop(2)*ones(size(xZ))];
    h_patch = patch(axTop, [xZ fliplr(xZ)], yZ, [0.85 0.95 1.0], ...
        'EdgeColor','none', 'FaceAlpha',0.30, 'DisplayName','ZVS Region');
    uistack(h_patch,'bottom'); % push behind curves
end

% 5) Per-load ZVS boundary points & dashed connecting curve (Imag{Zin}=0 closest to fn=1)
boundary_pts = nan(nLoads, 2);   % [fn_boundary, Gt_at_boundary]
for li = 1:nLoads
    Pout_i = Pout_vec(li);
    Q_i    = compute_Q_from_power(Vout_set, Pout_i);
    ImagZ  = imag(zin_norm(fn_vec, Ln, Q_i));
    zc_idx = find(diff(sign(ImagZ)) ~= 0);
    if isempty(zc_idx), continue; end

    % Interpolate zero-crossing candidates
    fn_cand = zeros(1, numel(zc_idx));
    for k = 1:numel(zc_idx)
        f1 = fn_vec(zc_idx(k));    f2 = fn_vec(zc_idx(k)+1);
        y1 = ImagZ(zc_idx(k));     y2 = ImagZ(zc_idx(k)+1);
        if (y2 - y1) == 0
            fn_cand(k) = NaN;
        else
            fn_cand(k) = f1 - y1*(f2 - f1)/(y2 - y1);
        end
    end
    fn_cand = fn_cand(isfinite(fn_cand));
    if isempty(fn_cand), continue; end

% Pick crossing closest to fn=1
[~, idxMin] = min(abs(fn_cand - 1));
fn_b = fn_cand(idxMin);
Gt_b = Gt_norm(fn_b, Ln, Q_i);

% Store & mark
boundary_pts(li,:) = [fn_b, Gt_b];
plot(axTop, fn_b, Gt_b, 'o', 'Color', cmap(li,:), 'MarkerFaceColor', cmap(li,:), ...
    'MarkerSize', 6, 'HandleVisibility','off');
end

valid = ~isnan(boundary_pts(:,1));
if any(valid)
    pts = boundary_pts(valid,:);
    [fn_sorted, o] = sort(pts(:,1)); Gt_sorted = pts(o,2);
    h_zvs_curve = plot(axTop, fn_sorted, Gt_sorted, 'k--', 'LineWidth', 2.0, ...
        'DisplayName', 'ZVS boundary (per load)');
    uistack(h_zvs_curve, 'top');
end

% 6) Small overlays legend (keep colorbar for loads)
lgTop = legend(axTop, [h_mgmax, h_mgmin, h_fnmin, h_fnmax, h_fnminsug, h_fnmaxsug], ...
    'Location','northeastoutside', 'Box','on');
lgTop.Title.String = 'Overlays';

% ==== name the lines====
valid = ~isnan(boundary_pts(:,1));
if any(valid)
    pts = boundary_pts(valid, :);
    [fn_sorted, ord] = sort(pts(:,1));
    Gt_sorted = pts(ord, 2);

    h_zvs_curve = plot(fn_sorted, Gt_sorted, 'k--', 'LineWidth', 2.0, ...
        'DisplayName', 'ZVS boundary (per load)');
    uistack(h_zvs_curve, 'top'); % keep it visible

% Optional label close to the rightmost boundary point
try
    text(fn_sorted(end), Gt_sorted(end), ' ZVS boundary', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold', 'Color','k', 'Clipping','on');
catch
    % Safe no-op if text placement fails (e.g., empty arrays)
end
else
    % Nothing found in this fn range — leave a console note
    disp('NOTE: No Imag(Zin)=0 boundary found for any load within current fn_vec range.');
end

% Retrieve current axes for Figure 1
ax1 = gca; hold(ax1, 'on');

uistack(ax1, 'top');

%% === Inline labels for the two required-gain red lines ===
% Sample a y slightly to the right, and print Vin_min / Vin_max text near that height.

% Position the labels near the rightmost edge of the current x-limits
xl = xlim(ax1);
xr = xl(2);

% Small vertical offsets so the two red-line labels don't overlap
dy_red = 0.015 * range(ylim(ax1));

% Label for Gt_req_max (Vin_min)
text(ax1, xr - 0.02*(xl(2)-xl(1)), Gt_req_max + dy_red, ...
    sprintf('Vin_{min} = %.0f V', spec.Vin_min), ...
    'Color', 'r', 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'Clipping', 'on');

% Label for Gt_req_min (Vin_max)
text(ax1, xr - 0.02*(xl(2)-xl(1)), Gt_req_min - dy_red, ...
    sprintf('Vin_{max} = %.0f V', spec.Vin_max), ...
    'Color', [0.8 0 0], 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'Clipping', 'on');

cb13 = colorbar('Location','eastoutside');
cb13.Label.String = 'Load power (W)';
nTicks = min(numel(Pout_vec), 8);
idxT   = round(linspace(1, numel(Pout_vec), nTicks));
cb13.Ticks = linspace(0, 1, nTicks);
cb13.TickLabels = arrayfun(@(p) sprintf('%d', p), Pout_vec(idxT), 'UniformOutput', false);

%% -------------------- BOTTOM subplot: Imag(Zin) traces + in-window zero-crossings --------------------
axBot = nexttile(tlo13, 2); hold(axBot,'on'); grid(axBot,'on'); box(axBot,'on');
title(axBot, 'Imag\{Z_{in}\} Zero-Crossings (searched inside controller window)');
xlabel(axBot,'Normalized frequency, f_n = f / f_r');
ylabel(axBot,'Imag\{Z_{in}\} (normalized)');

search_in_window = true;   % only mark zero-crossings inside [fn_min, fn_max]
any_crossings    = false;

for li = 1:nLoads
    Pout_i = Pout_vec(li);
    Q_i    = compute_Q_from_power(Vout_set, Pout_i);
    Zin_i  = zin_norm(fn_vec, Ln, Q_i);
    imz    = imag(Zin_i);

    % Trace
    plot(axBot, fn_vec, imz, 'Color', cmap(li,:), 'LineWidth', 1.2, ...
        'DisplayName', sprintf('%dW', Pout_i));

    % Range for search
    if search_in_window
        mask = (fn_vec >= fn_min) & (fn_vec <= fn_max);
    else
        mask = true(size(fn_vec));
    end
    fnw = fn_vec(mask); imw = imz(mask);

    % Zero-crossings
    valid = isfinite(imw);
    fnv = fnw(valid); imv = imw(valid);
    valid = isfinite(imw);
fnv = fnw(valid); imv = imw(valid);
if numel(fnv) >= 2
    sgn = sign(imv);
    sc  = find(diff(sgn) ~= 0);
    for k = 1:numel(sc)
        f1 = fnv(sc(k)); f2 = fnv(sc(k)+1);
        y1 = imv(sc(k)); y2 = imv(sc(k)+1);
        if (y2 - y1) ~= 0
            fn_zc = f1 - y1*(f2 - f1)/(y2 - y1);
            plot(axBot, fn_zc, 0, 'o', 'MarkerSize', 7, ...
                'Color', cmap(li,:), 'MarkerFaceColor', cmap(li,:), ...
                'HandleVisibility','off');
            any_crossings = true;
        end
    end
end
end


% Baselines and controller window in bottom plot
yline(axBot, 0, 'k-', 'HandleVisibility','off');
xline(axBot, 1, 'k:', 'HandleVisibility','off'); % resonance
xline(axBot, fn_min, 'k-.', 'HandleVisibility','off');
xline(axBot, fn_max, 'k-.', 'HandleVisibility','off');

% If none found, annotate
if ~any_crossings
    yLB = ylim(axBot); xLB = xlim(axBot);
    txt = sprintf('No Imag\\{Z_{in}\\} zero-crossings inside [f_n^{min}=%.2f, f_n^{max}=%.2f]', fn_min, fn_max);
    text(axBot, xLB(1)+0.02*(xLB(2)-xLB(1)), yLB(1)+0.85*(yLB(2)-yLB(1)), txt, ...
        'Color',[0 0.5 0], 'FontWeight','bold');
end

%% -------------------- Shared colorbar for both subplots --------------------
% Single colorbar for the whole tiledlayout, keyed to load powers
cb13 = colorbar('Location','eastoutside');
cb13.Label.String = 'Load power (W)';
nTicks = min(numel(Pout_vec), 8);
idxT   = round(linspace(1, numel(Pout_vec), nTicks));
cb13.Ticks = linspace(0, 1, nTicks);
cb13.TickLabels = arrayfun(@(p) sprintf('%d', p), Pout_vec(idxT), 'UniformOutput', false);

%% -------------------- Figure 6: Tank & Magnetizing Currents (RMS) --------------------
% Compute and plot |I_tank,rms| and |I_m,rms| vs normalized frequency for your load sweep.
% Tank current = resonant branch current (series Lr-Cr), equal to input series current.
% Magnetizing current flows in Lm branch.
%
% We use physical impedances (Lr, Cr, Lm) and fundamental of applied bridge voltage:
% V1 = (4/pi) * kbridge * Vin
% Currents are plotted in absolute RMS amperes.

figure('Color','w','Name','Figure 6 - Tank & Magnetizing Currents vs f_n');
tlo4 = tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

% --- Choose which input voltage to use for this current plot:
Vin_for_current_plot = 2200;   % (worst case gain / higher tank current). Change to spec.Vin_max if desired.

% Colormap consistent with Figure 1
nLoads = numel(Pout_vec);
cmap   = parula(nLoads);

% Helper: compute currents for a given operating condition
compute_currents = @(fnv, Vin, Vout, Pout) llc_currents_rms( ...
    fnv, Lr, Cr, Lm, n, kbridge, Vin, Vout, Pout, fr);

% ---------------- (a) Tank (series) current RMS ----------------
ax4a = nexttile(tlo4, 1); hold(ax4a,'on'); grid(ax4a,'on'); box(ax4a,'on');
for li = 1:nLoads
    Pout_i = Pout_vec(li);
    [I_tank_rms, I_mag_rms, ~, ~] = compute_currents(fn_vec, Vin_for_current_plot, Vout_set, Pout_i);
    plot(ax4a, fn_vec, I_tank_rms, 'Color', cmap(li,:), 'LineWidth', 1.7);
end

% Controller window markers
xline(ax4a, fn_min, 'k-.', 'HandleVisibility','off');
xline(ax4a, fn_max, 'k-.', 'HandleVisibility','off');
xlabel(ax4a, 'Normalized frequency, f_n = f / f_r');
ylabel(ax4a, 'I_{tank} (A_{RMS})');
title(ax4a, sprintf('Figure 6a - Tank (L_r-C_r series) current vs f_n @ V_{in}=%.0f V', Vin_for_current_plot));

% ---------------- (b) Magnetizing current RMS ----------------
ax4b = nexttile(tlo4, 2); hold(ax4b,'on'); grid(ax4b,'on'); box(ax4b,'on');
for li = 1:nLoads
    Pout_i = Pout_vec(li);
[~, I_mag_rms, ~, ~] = compute_currents(fn_vec, Vin_for_current_plot, Vout_set, Pout_i);
plot(ax4b, fn_vec, I_mag_rms, 'Color', cmap(li,:), 'LineWidth', 1.7);
end

xline(ax4b, fn_min, 'k-.', 'HandleVisibility','off');
xline(ax4b, fn_max, 'k-.', 'HandleVisibility','off');
xlabel(ax4b, 'Normalized frequency, f_n = f / f_r');
ylabel(ax4b, 'I_m (A_{RMS})');
title(ax4b, sprintf('Figure 6b - Magnetizing current vs f_n @ V_{in}=%.0f V', Vin_for_current_plot));

% Shared colorbar with load powers
colormap(parula);
cb4 = colorbar(ax4b, 'Location','eastoutside');
cb4.Label.String = 'Load power (W)';
nTicks4 = min(numel(Pout_vec), 8);
idx4    = round(linspace(1, numel(Pout_vec), nTicks4));
cb4.Ticks = linspace(0, 1, nTicks4);
cb4.TickLabels = arrayfun(@(p) sprintf('%d', p), Pout_vec(idx4), 'UniformOutput', false);

% (Optional) Fix x-limits to match your extended f_n axis (if you extended to 5.0 earlier)
% xlim([min(fn_vec) max(fn_vec)]);

%% ================= Console Report =================
fprintf('\n=== LLC Design Summary (FHA + Zin) ===\n');
fprintf('Topology: %s-bridge (kbridge = %.2f)\n', spec.topology, kbridge);
fprintf('fr = %.1f kHz\n', fr/1e3);
fprintf('Turns ratio n = Np/Ns = %.4f\n', n);
fprintf('Chosen Ln = %.3f, Q_design = %.3f\n', Ln, Q_design);
fprintf('Lr = %.3f uH, Cr = %.3f nF, Lm = %.3f uH\n', Lr*1e6, Cr*1e9, Lm*1e6);
fprintf('Gt_req_max (Vin_min=%.0fV) = %.4f, Gt_req_min (Vin_max=%.0fV) = %.4f\n', ...
    spec.Vin_min, Gt_req_max, spec.Vin_max, Gt_req_min);
fprintf('Gt_peak=%.4f at fn=%.3f (very light load)\n', Gt_peak, fn_at_peak);
fprintf('Chosen window: fn_min=%.3f (fs=%.1f kHz), fn_max=%.3f (fs=%.1f kHz)\n', ...
    fn_min, (fn_min*fr)/1e3, fn_max, (fn_max*fr)/1e3);
fprintf('Suggested window: fn_min=%.3f (fs=%.1f kHz), fn_max=%.3f (fs=%.1f kHz)\n', ...
    fn_min_suggest, (fn_min_suggest*fr)/1e3, fn_max_suggest, (fn_max_suggest*fr)/1e3);
fprintf('Load sweep (W): %s\n', mat2str(Pout_vec));
fprintf('ZVS criterion to check: Imag{Zin} > 0 across your window for all loads.\n');
fprintf('========================================\n');

%% ================= Helper for Figure 4: actual RMS currents from physical impedances =================
function [I_tank_rms, I_mag_rms, I_load_rms, I_in_rms] = llc_currents_rms(fn_vec, Lr, Cr, Lm, n, kbridge, Vin, Vout, Pout, fr)
% FHA AC load (primary-referred)
Rdc = (Vout^2) / max(Pout,1e-6);        % avoid divide-by-zero at very light load
Rpri = (n^2) * Rdc;
Rac  = (8/pi^2) * Rpri;                % FHA AC equivalent

% Fundamental excitation amplitude of the bridge (sine) and RMS
V1_amp = (4/pi) * kbridge * Vin;       % sine amplitude
V1_rms = V1_amp / sqrt(2);             % RMS of the fundamental

% Build frequency-dependent impedances
w  = 2*pi*fr*fn_vec;
j2 = 1j;

Zs  = j2*(w*Lr - 1./(w*Cr));            % series branch: Lr + Cr
Zm  = j2*w*Lm;                          % magnetizing
Zp  = (Zm.*Rac) ./ (Zm + Rac);          % parallel of Lm and Rac
Zin = Zs + Zp;                          % input seen by the bridge

% Phasor currents (use amplitude domain), then convert to RMS
I_in_amp   = V1_amp ./ Zin;             % input series current amplitude
Vs_amp     = V1_amp .* (Zp ./ (Zs + Zp)); % node phasor across parallel branch
I_mag_amp  = Vs_amp ./ Zm;              % magnetizing branch amplitude
I_load_amp = Vs_amp ./ Rac;             % load (FHA) branch amplitude

% Convert to RMS magnitudes
I_in_rms   = abs(I_in_amp) / sqrt(2);
I_tank_rms = I_in_rms;                  % tank (series) current equals input series current
I_mag_rms  = abs(I_mag_amp) / sqrt(2);
I_load_rms = abs(I_load_amp) / sqrt(2);

end
%% -------------------- Helper Functions --------------------

function Gt = llc_gt_norm_vs_over_vp(fn, Ln, Q)
% Normalized LLC tank transfer from primary applied sinusoid to
% secondary-referred node (Vs_ref@primary / Vp).
% Normalization: Lr=1, Cr=1 -> fr = 1/(2*pi), omega_r=1
j2 = 1j;
Zs  = j2*(fn - 1./fn);    % series Lr+Cr branch
Zm  = j2*fn*Ln;           % Lm branch
Rac = 1./Q;               % FHA AC load referred to primary
Zp  = (Zm.*Rac) ./ (Zm + Rac); % parallel of Lm and Rac
H   = Zp ./ (Zs + Zp);
Gt  = abs(H);

end


function Zin = llc_input_impedance_norm(fn, Ln, Q)
% Input impedance seen by the bridge (normalized tank):
% Zin = Zs + (Zm || Rac)
j2 = 1j;
Zs  = j2*(fn - 1./fn);
Zm  = j2*fn*Ln;
Rac = 1./Q;
Zp  = (Zm.*Rac) ./ (Zm + Rac);
Zin = Zs + Zp;

end
%% LLC Resonant Converter Design (FHA)
%  - Gain vs normalized frequency (load sweep)
%  - Input impedance (Real/Imag) and ZVS boundary (Imag{Zin}=0)
%  - Zero-crossings inside controller window
%  - Tank and magnetizing RMS currents (physical values)
%
% Notes:
% - n = Np/Ns (PRIMARY / SECONDARY)
% - Required tank gain: Gt_req = (Vout * n) / (kbridge * Vin)
% - Q = (omega_r * Lr) / Rac,  Rac = (8/pi^2) * n^2 * Rdc,  Rdc = V^2/P
% - ZVS region (inductive as seen by bridge): Imag(Zin) > 0
%
% Author: (you)  -- refined

clear; clc; close all;

%% ---------------------- USER SPECS ----------------------
spec.Vin_min   = 2200;     % [V]
spec.Vin_max   = 2600;    % [V]
spec.Vout      = 36;      % [V] (use ONE value unless you truly need a range)
spec.Pout_max  = 100;     % [W]
spec.Pout_vec  = [10 20 30 40 50 60 70 80 90 100];

spec.topology  = 'half';  % 'half' or 'full'
kbridge        = strcmpi(spec.topology,'half') * 0.5 + strcmpi(spec.topology,'full') * 1;

% Pick nominal Vin for turns ratio selection
Vin_nom = spec.Vin_max;   % common choice for high-ratio designs (keeps n manageable)

% Resonant frequency
fr      = 300e3;          % [Hz]
w_r     = 2*pi*fr;

% Normalized frequency axis
fn_vec  = linspace(0.3, 4.0, 6000); % fewer points usually plenty

% Design knobs
Ln        = 20;      % Ln = Lm/Lr
Q_design  = 0.005;    % “design Q” at worst-case corner (heavy load)
fn_win    = [1.0, 2];   % controller window [fn_min fn_max]

% For current plots: choose Vin for worst current stress
Vin_for_current_plot = 300;
Vin_for_current_plot2 = 2200;
%% ---------------------- DERIVED -------------------------
% Transformer ratio (choose so that required gain ~ 1 at Vin_nom)
n = (kbridge * Vin_nom) / spec.Vout;

% Required gain bounds over Vin range
Gt_req_max = (spec.Vout * n) / (kbridge * spec.Vin_min); % highest required gain at lowest Vin
Gt_req_min = (spec.Vout * n) / (kbridge * spec.Vin_max); % lowest required gain at highest Vin

% Worst-case corner for sizing Lr,Cr,Lm (typically: max power, and whatever you define)
P_wc   = spec.Pout_max;
Rdc_wc = (spec.Vout^2) / max(P_wc,1e-12);
Rpri_wc = n^2 * Rdc_wc;
Rac_wc  = (8/pi^2) * Rpri_wc;

Lr = Q_design * Rac_wc / w_r;
Cr = 1 / (w_r^2 * Lr);
Lm = Ln * Lr;

% Helper: compute Q from power (physical Lr, fr)
compute_Q = @(Vout,Pout) (w_r * Lr) / ((8/pi^2) * n^2 * (Vout^2 / max(Pout,1e-12)));

% Normalized FHA model
Gt_norm  = @(fn,Q) llc_gt_norm(fn, Ln, Q);
Zin_norm = @(fn,Q) llc_zin_norm(fn, Ln, Q);

%% ------------------ LIGHT-LOAD PEAK (sanity) ------------------
Q_very_light = 0.05;
Gt_peak_curve = Gt_norm(fn_vec, Q_very_light);
% Keep only inductive points for “practical peak” if you want:
ind_mask = imag(Zin_norm(fn_vec, Q_very_light)) > 0;
Gt_peak_curve(~ind_mask) = NaN;
[Gt_peak, idx_pk] = max(Gt_peak_curve);
fn_pk = fn_vec(idx_pk);

%% ----------- SUGGESTED WINDOW USING HEAVY LOAD -----------
Q_heavy = compute_Q(spec.Vout, spec.Pout_max);
Gt_heavy = Gt_norm(fn_vec, Q_heavy);
Gt_heavy(imag(Zin_norm(fn_vec,Q_heavy)) <= 0) = NaN; % enforce inductive region

fn_min = fn_win(1);
fn_max = fn_win(2);

% Find a reasonable minimum: first fn>1 where gain >= (margin)*Gt_req_max
margin = 1.02;
idxL = find(fn_vec > 1 & Gt_heavy >= margin*Gt_req_max, 1, 'first');
if isempty(idxL), fn_min_sug = max(fn_min, 1.02);
else,            fn_min_sug = max(fn_vec(idxL), 1.02);
end

% Find an upper point where heavy-load gain falls below required min
idxU = find(fn_vec > fn_min_sug & Gt_heavy <= Gt_req_min, 1, 'first');
if isempty(idxU), fn_max_sug = min(fn_max, fn_vec(end));
else,             fn_max_sug = fn_vec(idxU);
end

%% ---------------------- COLOR MAP ----------------------
Pvec = spec.Pout_vec(:);
nLoads = numel(Pvec);
cmap = parula(nLoads);

%% ===================== FIGURE 1: GAIN =====================

fig1 = figure('Color','w','Name','Figure 1 (Combined) - Gain + ZVS boundary + Zero-crossings');
tlo1 = tiledlayout(fig1, 2, 1, 'Padding','compact','TileSpacing','compact');

% ---------- TOP: Gain + required lines + per-load ZVS boundary ----------
axTop = nexttile(tlo1, 1); hold(axTop,'on'); grid(axTop,'on'); box(axTop,'on');
title(axTop, 'Gain vs f_n (Required lines + per-load ZVS boundary)');
xlabel(axTop,'Normalized frequency f_n = f/f_r');
ylabel(axTop,'Tank gain G_t = |V_s/V_p|');

% Gain family
for i = 1:nLoads
    Q_i = compute_Q(spec.Vout, Pvec(i));
    plot(axTop, fn_vec, Gt_norm(fn_vec, Q_i), 'LineWidth', 1.6, 'Color', cmap(i,:));
end

% Required gain lines (Vin min/max)
hReqMax = yline(axTop, Gt_req_max, 'r-', 'LineWidth', 2.0, ...
    'DisplayName', sprintf('Vin_{min}=%.0f V', spec.Vin_min));
hReqMin = yline(axTop, Gt_req_min, '--', 'LineWidth', 1.6, 'Color', [0.8 0 0], ...
    'DisplayName', sprintf('Vin_{max}=%.0f V', spec.Vin_max));

% Controller window guides
hW1 = xline(axTop, fn_min, 'k-.', 'LineWidth', 1.2, ...
    'DisplayName', sprintf('f_n^{min}=%.2f', fn_min));
hW2 = xline(axTop, fn_max, 'k-.', 'LineWidth', 1.2, ...
    'DisplayName', sprintf('f_n^{max}=%.2f', fn_max));
hS1 = xline(axTop, fn_min_sug, 'b--', 'LineWidth', 1.2, ...
    'DisplayName', sprintf('f_n^{min} sugg=%.2f', fn_min_sug));
hS2 = xline(axTop, fn_max_sug, 'b--', 'LineWidth', 1.2, ...
    'DisplayName', sprintf('f_n^{max} sugg=%.2f', fn_max_sug));

% Peak marker (optional)
plot(axTop, fn_pk, Gt_peak, 'ko', 'MarkerFaceColor','y', 'DisplayName','Peak (very light, inductive only)');

% Per-load ZVS boundary: Imag{Zin}=0 crossing closest to fn=1
boundary = nan(nLoads,2); % [fn_b, Gt_b]
for i = 1:nLoads
    Q_i = compute_Q(spec.Vout, Pvec(i));
    Z   = Zin_norm(fn_vec, Q_i);
    fn_b = find_zvs_boundary_fn(fn_vec, Z, 1.0);  % closest to fn=1
    if ~isnan(fn_b)
        boundary(i,1) = fn_b;
        boundary(i,2) = Gt_norm(fn_b, Q_i);
        plot(axTop, boundary(i,1), boundary(i,2), 'o', 'MarkerSize', 6, ...
            'Color', cmap(i,:), 'MarkerFaceColor', cmap(i,:), 'HandleVisibility','off');
    end
end
ylim([0.5 1.4])
% Connect boundary points
v = ~isnan(boundary(:,1));
if any(v)
    [xs, ord] = sort(boundary(v,1));
    ys = boundary(v,2); ys = ys(ord);
    hZVS = plot(axTop, xs, ys, 'k--', 'LineWidth', 2.0, ...
        'DisplayName','ZVS boundary (Imag(Zin)=0)');
    uistack(hZVS, 'top');
end

% Legend: keep overlays (avoid clutter)
legend(axTop, [hReqMax hReqMin hW1 hW2 hS1 hS2], 'Location','northeastoutside', 'Box','on');

% Label the dashed ZVS boundary curve directly on the plot
if exist('hZVS','var') && isgraphics(hZVS)
    xd = hZVS.XData; yd = hZVS.YData;
    k  = numel(xd);              % last point
    % text(axTop, xd(k), yd(k), '  ZVS boundary', ...
    %     'Color','k', 'FontWeight','bold', ...
    %     'HorizontalAlignment','left', 'VerticalAlignment','middle', ...
    %     'BackgroundColor','w', 'Margin',2, 'Clipping','on');
    text(axTop, xd(k), yd(k), ' ZVS boundary', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold', 'Color', 'k', 'Clipping', 'on');
end
% Label for Gt_req_min (Vin_max)
ax1 = gca; hold(ax1, 'on');
% Position the labels near the rightmost edge of the current x-limits
xl = xlim(ax1);
xr = xl(2);

% Small vertical offsets so the two red-line labels don't overlap
dy_red = 0.015 * range(ylim(ax1));
text(ax1, xr - 0.02*(xl(2)-xl(1)), Gt_req_min - dy_red, ...
    sprintf('Vin_{max} = %.0f V', spec.Vin_max), ...
    'Color', [0.8 0 0], 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'Clipping', 'on');

% Colorbar keyed to power
colormap(axTop, cmap);
cb1 = colorbar(axTop, 'Location','eastoutside');
cb1.Label.String = 'Load power (W)';
cb1.Ticks = linspace(0,1,min(nLoads,8));
tickIdx = round(linspace(1,nLoads,numel(cb1.Ticks)));
cb1.TickLabels = arrayfun(@(x) sprintf('%d', x), Pvec(tickIdx), 'UniformOutput', false);

% ---------- BOTTOM: Imag(Zin) + zero-crossings inside window ----------
axBot = nexttile(tlo1, 2); hold(axBot,'on'); grid(axBot,'on'); box(axBot,'on');
title(axBot, sprintf('Imag\\{Z_{in}\\} (zero-crossings inside window [%.2f, %.2f])', fn_min, fn_max));
xlabel(axBot,'Normalized frequency f_n = f/f_r');
ylabel(axBot,'Imag(Zin) (normalized)');

maskW = (fn_vec >= fn_min) & (fn_vec <= fn_max);
anyCross = false;

for i = 1:nLoads
    Q_i = compute_Q(spec.Vout, Pvec(i));
    imz = imag(Zin_norm(fn_vec, Q_i));
    plot(axBot, fn_vec, imz, 'LineWidth', 1.2, 'Color', cmap(i,:), ...
        'DisplayName', sprintf('%dW', Pvec(i)));

    % Zero-crossings inside the window
    fnw = fn_vec(maskW);
    imw = imz(maskW);
    fn_zc = find_all_zero_crossings(fnw, imw);
    if ~isempty(fn_zc)
        anyCross = true;
        plot(axBot, fn_zc, zeros(size(fn_zc)), 'o', 'MarkerSize', 7, ...
            'Color', cmap(i,:), 'MarkerFaceColor', cmap(i,:), 'HandleVisibility','off');
    end
end

yline(axBot,0,'k-','HandleVisibility','off');
xline(axBot,1,'k:','HandleVisibility','off');     % resonance marker
xline(axBot,fn_min,'k-.','HandleVisibility','off');
xline(axBot,fn_max,'k-.','HandleVisibility','off');

if ~anyCross
    xl = xlim(axBot); yl = ylim(axBot);
    % text(axBot, xl(1)+0.02*range(xl), yl(1)+0.85*range(yl), ...
    %     'No Imag(Zin)=0 crossings in window -> inductive (ZVS) maintained for these loads', ...
    %     'Color',[0 0.5 0], 'FontWeight','bold');
end
% Colorbar keyed to power
colormap(axBot, cmap);
cb1 = colorbar(axBot, 'Location','eastoutside');
cb1.Label.String = 'Load power (W)';
cb1.Ticks = linspace(0,1,min(nLoads,8));
tickIdx = round(linspace(1,nLoads,numel(cb1.Ticks)));
cb1.TickLabels = arrayfun(@(x) sprintf('%d', x), Pvec(tickIdx), 'UniformOutput', false);

%% ===================== FIGURE 2: ZIN (REAL/IMAG) =====================
fig2 = figure('Color','w','Name','Figure 2 - Zin vs f_n');
tlo2 = tiledlayout(fig2,2,1,'Padding','compact','TileSpacing','compact');

ax2a = nexttile(tlo2,1); hold(ax2a,'on'); grid(ax2a,'on'); box(ax2a,'on');
ax2b = nexttile(tlo2,2); hold(ax2b,'on'); grid(ax2b,'on'); box(ax2b,'on');

for i = 1:nLoads
    Q_i = compute_Q(spec.Vout, Pvec(i));
    Z = Zin_norm(fn_vec,Q_i);
    plot(ax2a, fn_vec, imag(Z), 'LineWidth',1.4, 'Color',cmap(i,:));
    plot(ax2b, fn_vec, real(Z), 'LineWidth',1.4, 'Color',cmap(i,:));
end

yline(ax2a,0,'k-','HandleVisibility','off');
xline(ax2a,1,'k:','HandleVisibility','off');
xline(ax2a,fn_min,'k-.','HandleVisibility','off');
xline(ax2a,fn_max,'k-.','HandleVisibility','off');

xline(ax2b,1,'k:','HandleVisibility','off');
xline(ax2b,fn_min,'k-.','HandleVisibility','off');
xline(ax2b,fn_max,'k-.','HandleVisibility','off');

title(ax2a,'Imag\{Z_{in}\} (inductive if > 0)');
ylabel(ax2a,'Imag(Zin) (normalized)');
xlabel(ax2a,'f_n');

title(ax2b,'Real\{Z_{in}\}');
ylabel(ax2b,'Real(Zin) (normalized)');
xlabel(ax2b,'f_n');


colormap(fig2, cmap);
cb2 = colorbar(ax2a,'Location','eastoutside');
cb2.Label.String = 'Load power (W)';
cb2.Ticks = cb1.Ticks;
cb2.TickLabels = cb1.TickLabels;


colormap(fig2, cmap);
cb2 = colorbar(ax2b,'Location','eastoutside');
cb2.Label.String = 'Load power (W)';
cb2.Ticks = cb1.Ticks;
cb2.TickLabels = cb1.TickLabels;

%% ===================== FIGURE 3: ZERO-CROSSINGS IN WINDOW =====================
fig3 = figure('Color','w','Name','Figure 3 - Imag(Zin) zero-crossings (window)');
ax3 = axes(fig3); hold(ax3,'on'); grid(ax3,'on'); box(ax3,'on');

maskW = fn_vec>=fn_min & fn_vec<=fn_max;
anyCross = false;

for i = 1:nLoads
    Q_i = compute_Q(spec.Vout, Pvec(i));
    imz = imag(Zin_norm(fn_vec,Q_i));
    plot(ax3, fn_vec, imz, 'LineWidth',1.1, 'Color',cmap(i,:), 'DisplayName',sprintf('%dW',Pvec(i)));

    fnw = fn_vec(maskW); imw = imz(maskW);
    fn_zc = find_all_zero_crossings(fnw, imw);
    if ~isempty(fn_zc)
        anyCross = true;
        plot(ax3, fn_zc, zeros(size(fn_zc)), 'o', 'MarkerSize',7, ...
            'Color',cmap(i,:), 'MarkerFaceColor',cmap(i,:), 'HandleVisibility','off');
    end
end

yline(ax3,0,'k-','HandleVisibility','off');
xline(ax3,1,'k:','HandleVisibility','off');
xline(ax3,fn_min,'k-.','HandleVisibility','off');
xline(ax3,fn_max,'k-.','HandleVisibility','off');

xlabel(ax3,'f_n'); ylabel(ax3,'Imag(Zin) (normalized)');
title(ax3, sprintf('Imag(Zin) zero-crossings inside window [%.2f, %.2f]', fn_min, fn_max));

if ~anyCross
    xl = xlim(ax3); yl = ylim(ax3);
    % text(ax3, xl(1)+0.02*range(xl), yl(1)+0.85*range(yl), ...
    %     'No zero-crossings in window -> ZVS maintained (Imag(Zin)>0) for these loads', ...
    %     'Color',[0 0.5 0], 'FontWeight','bold');
end

colormap(fig3, cmap);
cb3 = colorbar(ax3,'Location','eastoutside');
cb3.Label.String = 'Load power (W)';
cb3.Ticks = cb1.Ticks;
cb3.TickLabels = cb1.TickLabels;

%% ===================== FIGURE 4: RMS CURRENTS (PHYSICAL) =====================
fig4 = figure('Color','w','Name','Figure 4 - Currents vs f_n');
tlo4 = tiledlayout(fig4,2,1,'Padding','compact','TileSpacing','compact');
ax4a = nexttile(tlo4,1); hold(ax4a,'on'); grid(ax4a,'on'); box(ax4a,'on');
ax4b = nexttile(tlo4,2); hold(ax4b,'on'); grid(ax4b,'on'); box(ax4b,'on');

for i = 1:nLoads
    Pout_i = Pvec(i);
    [It, Im] = llc_currents_rms(fn_vec, Lr, Cr, Lm, n, kbridge, Vin_for_current_plot, spec.Vout, Pout_i, fr);
    plot(ax4a, fn_vec, It, 'LineWidth',1.5, 'Color',cmap(i,:));
    plot(ax4b, fn_vec, Im, 'LineWidth',1.5, 'Color',cmap(i,:));
end
xline(ax4a, fn_min,'k-.','HandleVisibility','off'); xline(ax4a, fn_max,'k-.','HandleVisibility','off');
xline(ax4b, fn_min,'k-.','HandleVisibility','off'); xline(ax4b, fn_max,'k-.','HandleVisibility','off');

xlabel(ax4a,'f_n'); ylabel(ax4a,'I_{tank} (A_{RMS})');
title(ax4a, sprintf('Tank current @ Vin=%.0f V', Vin_for_current_plot));

colormap(fig4, cmap);
cb4 = colorbar(ax4a,'Location','eastoutside');
cb4.Label.String = 'Load power (W)';
cb4.Ticks = cb1.Ticks;
cb4.TickLabels = cb1.TickLabels;
xlabel(ax4a,'f_n'); ylabel(ax4a,'I_m (A_{RMS})');
title(ax4a, sprintf('Magnetizing current @ Vin=%.0f V', Vin_for_current_plot));

colormap(fig4, cmap);
cb4 = colorbar(ax4b,'Location','eastoutside');
cb4.Label.String = 'Load power (W)';
cb4.Ticks = cb1.Ticks;
cb4.TickLabels = cb1.TickLabels;


%% ===================== FIGURE 5: RMS CURRENTS (PHYSICAL) =====================
fig5 = figure('Color','w','Name','Figure 5 - Currents vs f_n');
tlo5 = tiledlayout(fig5,2,1,'Padding','compact','TileSpacing','compact');
ax5a = nexttile(tlo5,1); hold(ax5a,'on'); grid(ax5a,'on'); box(ax5a,'on');
ax5b = nexttile(tlo5,2); hold(ax5b,'on'); grid(ax5b,'on'); box(ax5b,'on');

for i = 1:nLoads
    Pout_i = Pvec(i);
    [It, Im] = llc_currents_rms(fn_vec, Lr, Cr, Lm, n, kbridge, Vin_for_current_plot2, spec.Vout, Pout_i, fr);
    plot(ax5a, fn_vec, It, 'LineWidth',1.5, 'Color',cmap(i,:));
    plot(ax5b, fn_vec, Im, 'LineWidth',1.5, 'Color',cmap(i,:));
end
xline(ax5a, fn_min,'k-.','HandleVisibility','off'); xline(ax5a, fn_max,'k-.','HandleVisibility','off');
xline(ax5b, fn_min,'k-.','HandleVisibility','off'); xline(ax5b, fn_max,'k-.','HandleVisibility','off');

xlabel(ax5a,'f_n'); ylabel(ax5a,'I_{tank} (A_{RMS})');
title(ax5a, sprintf('Tank current @ Vin=%.0f V', Vin_for_current_plot2));

colormap(fig5, cmap);
cb5 = colorbar(ax5a,'Location','eastoutside');
cb5.Label.String = 'Load power (W)';
cb5.Ticks = cb1.Ticks;
cb5.TickLabels = cb1.TickLabels;
xlabel(ax5a,'f_n'); ylabel(ax5a,'I_m (A_{RMS})');
title(ax5a, sprintf('Magnetizing current @ Vin=%.0f V', Vin_for_current_plot2));

colormap(fig5, cmap);
cb5 = colorbar(ax5b,'Location','eastoutside');
cb5.Label.String = 'Load power (W)';
cb5.Ticks = cb1.Ticks;
cb5.TickLabels = cb1.TickLabels;
%% ===================== CONSOLE SUMMARY =====================
fprintf('\n=== LLC FHA Design Summary ===\n');
fprintf('Topology: %s-bridge  (kbridge=%.2f)\n', spec.topology, kbridge);
fprintf('Vout = %.2f V\n', spec.Vout);
fprintf('Vin range: [%.0f .. %.0f] V   (Vin_nom=%.0f V)\n', spec.Vin_min, spec.Vin_max, Vin_nom);
fprintf('Turns ratio n = Np/Ns = %.4f\n', n);
fprintf('fr = %.1f kHz\n', fr/1e3);
fprintf('Ln = %.3f, Q_design = %.3f\n', Ln, Q_design);
fprintf('Lr = %.3f uH, Cr = %.3f nF, Lm = %.3f uH\n', Lr*1e6, Cr*1e9, Lm*1e6);
fprintf('Required gain: Gt_req_max(Vin_min)=%.4f,  Gt_req_min(Vin_max)=%.4f\n', Gt_req_max, Gt_req_min);
fprintf('Peak (very light load, inductive only): Gt_peak=%.4f at fn=%.3f\n', Gt_peak, fn_pk);
fprintf('Controller window: fn=[%.2f .. %.2f] => fs=[%.1f .. %.1f] kHz\n', fn_min, fn_max, fn_min*fr/1e3, fn_max*fr/1e3);
fprintf('Suggested window:  fn=[%.2f .. %.2f] => fs=[%.1f .. %.1f] kHz\n', fn_min_sug, fn_max_sug, fn_min_sug*fr/1e3, fn_max_sug*fr/1e3);
fprintf('Loads (W): %s\n', mat2str(Pvec.'));
fprintf('ZVS check: ensure Imag{Zin} > 0 across your controller window for all loads.\n');
fprintf('==============================\n');

%% ===================== LOCAL FUNCTIONS =====================
function Gt = llc_gt_norm(fn, Ln, Q)
    j = 1j;
    Zs  = j*(fn - 1./fn);       % series branch (normalized Lr=1, Cr=1)
    Zm  = j*fn*Ln;              % magnetizing
    Rac = 1./Q;                 % normalized FHA load
    Zp  = (Zm.*Rac) ./ (Zm + Rac);
    H   = Zp ./ (Zs + Zp);
    Gt  = abs(H);
end

function Zin = llc_zin_norm(fn, Ln, Q)
    j = 1j;
    Zs  = j*(fn - 1./fn);
    Zm  = j*fn*Ln;
    Rac = 1./Q;
    Zp  = (Zm.*Rac) ./ (Zm + Rac);
    Zin = Zs + Zp;
end

function fn_b = find_zvs_boundary_fn(fn_vec, Zin_vec, fn_ref)
% Returns the Imag(Zin)=0 crossing closest to fn_ref (usually 1.0).
    imz = imag(Zin_vec);
    fn_b = NaN;
    if any(~isfinite(imz)), return; end

    s = sign(imz);
    zc = find(diff(s) ~= 0); % sign change indices
    if isempty(zc), return; end

    fn_cand = nan(size(zc));
    for k = 1:numel(zc)
        i = zc(k);
        f1 = fn_vec(i); f2 = fn_vec(i+1);
        y1 = imz(i);    y2 = imz(i+1);
        if (y2-y1) ~= 0
            fn_cand(k) = f1 - y1*(f2-f1)/(y2-y1);
        end
    end
    fn_cand = fn_cand(isfinite(fn_cand));
    if isempty(fn_cand), return; end

    [~, idx] = min(abs(fn_cand - fn_ref));
    fn_b = fn_cand(idx);
end

function fn_zc = find_all_zero_crossings(x, y)
% Linear-interpolated zero-crossings of y(x). Returns vector of x at crossings.
    fn_zc = [];
    if numel(x) < 2, return; end
    if any(~isfinite(y)), return; end

    s = sign(y);
    idx = find(diff(s) ~= 0);
    if isempty(idx), return; end

    fn_zc = nan(size(idx));
    for k = 1:numel(idx)
        i = idx(k);
        x1 = x(i); x2 = x(i+1);
        y1 = y(i); y2 = y(i+1);
        if (y2-y1) ~= 0
            fn_zc(k) = x1 - y1*(x2-x1)/(y2-y1);
        end
    end
    fn_zc = fn_zc(isfinite(fn_zc));
end

function [I_tank_rms, I_mag_rms] = llc_currents_rms(fn_vec, Lr, Cr, Lm, n, kbridge, Vin, Vout, Pout, fr)
% Physical RMS currents using FHA load and fundamental excitation.
    Rdc  = (Vout^2) / max(Pout,1e-12);
    Rpri = n^2 * Rdc;
    Rac  = (8/pi^2) * Rpri;

    V1_amp = (4/pi) * kbridge * Vin;  % fundamental sine amplitude
    w = 2*pi*fr*fn_vec;
    j = 1j;

    Zs  = j*(w*Lr - 1./(w*Cr));       % series branch
    Zm  = j*w*Lm;                     % magnetizing
    Zp  = (Zm.*Rac) ./ (Zm + Rac);    % parallel Lm || Rac
    Zin = Zs + Zp;

    I_in_amp  = V1_amp ./ Zin;
    Vs_amp    = V1_amp .* (Zp ./ (Zs + Zp));
    I_mag_amp = Vs_amp ./ Zm;

    I_tank_rms = abs(I_in_amp) / sqrt(2);
    I_mag_rms  = abs(I_mag_amp) / sqrt(2);
end
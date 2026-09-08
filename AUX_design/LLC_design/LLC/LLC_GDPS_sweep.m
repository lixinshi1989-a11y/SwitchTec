%% 800 kHz / 30 W planar LLC transformer pre-design (UU core, DMR53)
% Targets: Vin=36 V half bridge, Vout=24 V, Np=3, Ns=4,
% Lm~=6.5 uH, Llk,p~=1 uH. Primary and secondary are on opposite U-core legs.
% Replace the EXAMPLE core/PCB geometry with drawing and stack-up data.
% Final leakage must be verified by 3-D FEA or short-circuit measurement.
clear; clc; close all;

%% Electrical specification
S.Vin=36; S.Vout=24; S.Pout=30; S.fr=800e3;
S.Np=3; S.Ns=4; S.secondary_count=4; % four identical 4-turn secondaries
S.secondary_connection='parallel';  % assumed same-phase parallel for 24 V
S.Lm_target=6.5e-6; S.Llk_target=1e-6;
S.topology='half-bridge';           % 'half-bridge' or 'full-bridge'
S.eta_guess=0.90;

%% DMR53 data (Material Characteristic, Rev. B, 2019-07)
M.mui_nom=900; M.mui_tol=0.25;
M.Bs_25=0.560; M.Bs_100=0.460;     % T, low-frequency test values
M.Pv_ref=70e3; M.f_ref=1e6; M.B_ref=50e-3; % 70 mW/cm^3
M.alpha_f=1.5; M.beta_B=2.5;       % assumptions; replace with curve fit

%% Proposed custom UU core - first prototype dimensions (DMR53)
% Two identical U halves form a rectangular magnetic circuit around the PCB.
% These dimensions are an engineering starting point for tooling/FEA.
D.outer_x_mm=36.0;                 % complete core length, top view
D.outer_y_mm=15.0;                 % one U-core height, side view
D.leg_x_mm=10.0;                   % each leg width in top view
D.yoke_y_mm=10.0;                  % yoke width in top view
D.core_depth_mm=10.0;              % dimension normal to top view
D.pcb_hole_x_mm=10.6;              % finished slot around each leg
D.pcb_hole_y_mm=10.6;
D.leg_center_pitch_mm=D.outer_x_mm-D.leg_x_mm;
D.window_x_mm=D.outer_x_mm-2*D.leg_x_mm;
D.window_y_mm=D.outer_y_mm-D.yoke_y_mm; % clear leg length in side view
G.Ae=D.leg_x_mm*D.core_depth_mm*1e-6;                  % 25 mm^2
G.le=2*((D.outer_x_mm-D.leg_x_mm)+(D.outer_y_mm-D.yoke_y_mm))*1e-3;
G.Ve=G.Ae*G.le;
G.Aw=D.window_x_mm*D.window_y_mm*1e-6;

%% Actual 8-layer PCB stack-up from supplied drawing
% Primary is on one U leg and secondary on the other U leg. They can use the
% same PCB layers because they are separated laterally, not vertically.
W.layer_name={'L1','L2','L3','L4','L5','L6','L7','L8'};
W.cu_mm=[0.069 0.064 0.064 0.064 0.064 0.064 0.064 0.069];
W.diel_mm=[0.346 0.406 0.393 0.406 0.406 0.406 0.360]; % L1-L2 ... L7-L8
W.board_thickness_mm=sum(W.cu_mm)+sum(W.diel_mm);
% Representative electrical winding used by this legacy sweep. The realised
% PCB has two identical 3-turn primaries in parallel and four separate 4-turn
% outputs; see LLC_Magnetics_simulation.m for the complete layer schedule.
W.Np_layer=[0 3 0 0 0 0 0 0];
W.Ns_layer=[0 4 0 0 0 0 0 0];
assert(sum(W.Np_layer)==S.Np && sum(W.Ns_layer)==S.Ns,'Layer turns do not match Np/Ns.');
W.MLT=55e-3; W.width=10e-3;
W.primary_parallel=2; W.secondary_parallel=1;
W.trace_width_p=1.2e-3; W.trace_width_s=0.70e-3;
W.trace_spacing=0.20e-3;
W.secondary_radial_build=S.secondary_count*W.trace_width_s+ ...
    (S.secondary_count-1)*W.trace_spacing;

mu0=4*pi*1e-7; n=S.Np/S.Ns;
kbridge=0.5*strcmpi(S.topology,'half-bridge')+strcmpi(S.topology,'full-bridge');
assert(kbridge>0,'S.topology must be half-bridge or full-bridge.');

%% Lm and air gap
AL_target=S.Lm_target/S.Np^2;
Rtarget=S.Np^2/S.Lm_target;
Rcore=G.le/(mu0*M.mui_nom*G.Ae);
g_total=mu0*G.Ae*(Rtarget-Rcore);   % total gap in magnetic path
mui=M.mui_nom*[1-M.mui_tol 1 1+M.mui_tol];
Lm_corner=S.Np^2./(G.le./(mu0*mui*G.Ae)+max(g_total,0)/(mu0*G.Ae));

%% Flux and approximate core loss
% Symmetric square wave: Bpk=Vpri/(4*f*N*Ae).
Vpri_square=kbridge*S.Vin;
Bpk=Vpri_square/(4*S.fr*S.Np*G.Ae);
Pv_est=M.Pv_ref*(S.fr/M.f_ref)^M.alpha_f*(Bpk/M.B_ref)^M.beta_B;
Pcore_est=Pv_est*G.Ve;

%% Tank and LLC FHA operating point
Cr=1/((2*pi*S.fr)^2*S.Llk_target); Ln=S.Lm_target/S.Llk_target;
Rdc=S.Vout^2/S.Pout; Rac=(8/pi^2)*n^2*Rdc;
Q=2*pi*S.fr*S.Llk_target/Rac;
Mreq=S.Vout*n/(kbridge*S.Vin);
fn=linspace(0.35,2.5,5000); H=llc_gain(fn,Ln,Q); Zin=llc_zin(fn,Ln,Q);
valid=find(imag(Zin)>0); [~,j]=min(abs(H(valid)-Mreq));
fn_op=fn(valid(j)); gain_error=H(valid(j))-Mreq;
H_valid_min=min(H(valid)); H_valid_max=max(H(valid));
gain_reachable=(Mreq>=H_valid_min && Mreq<=H_valid_max && abs(gain_error)<2e-3);

%% Leakage target for opposite-leg windings
% A vertical stack-up-only leakage equation is invalid here: leakage is set
% mainly by U-leg spacing, window dimensions, winding footprint and fringing.
% Lopen is approximated as Lm+Llk. For Lsc=Lopen*(1-k^2), calculate the
% coupling coefficient that the final geometry must achieve.
Lopen_target=S.Lm_target+S.Llk_target;
k_target=sqrt(max(0,1-S.Llk_target/Lopen_target));
M_target=k_target*sqrt(Lopen_target*(S.Ns/S.Np)^2*Lopen_target);

%% Copper checks (DC lower bound; AC proximity loss not included)
rhoCu=1.724e-8; delta=sqrt(2*rhoCu/(2*pi*S.fr*mu0));
tCu=W.cu_mm*1e-3;
Rpri_dc=sum(rhoCu*W.MLT*W.Np_layer./(W.trace_width_p*tCu))/W.primary_parallel;
Rsec_each_dc=sum(rhoCu*W.MLT*W.Ns_layer./(W.trace_width_s*tCu))/W.secondary_parallel;
Rsec_dc=Rsec_each_dc/S.secondary_count; % four identical windings in parallel
Iout=S.Pout/S.Vout; Iin=S.Pout/(S.Vin*S.eta_guess);
Pcu_dc_lb=Iin^2*Rpri_dc+Iout^2*Rsec_dc;
Ku_proxy=(W.primary_parallel*sum(W.Np_layer.*tCu)*W.trace_width_p+ ...
    S.secondary_count*sum(W.Ns_layer.*tCu)*W.trace_width_s)/G.Aw;

%% Report
fprintf('\n=== %.3f MHz planar LLC transformer pre-design ===\n',S.fr/1e6);
fprintf('Np/Ns=%d/%d=%.3f; required tank gain=%.3f (%s)\n',S.Np,S.Ns,n,Mreq,S.topology);
fprintf('Secondary: %d x %d turns, assumed %s\n',S.secondary_count,S.Ns,S.secondary_connection);
fprintf('30 W FHA point: fs=%.3f MHz, Q=%.3f, gain error=%+.4f\n',fn_op*S.fr/1e6,Q,gain_error);
fprintf('Inductive-region gain range in sweep: %.3f to %.3f; reachable=%d\n',H_valid_min,H_valid_max,gain_reachable);
fprintf('Lr=%.3f uH, Cr=%.3f nF, Lm=%.3f uH, Ln=%.2f\n',S.Llk_target*1e6,Cr*1e9,S.Lm_target*1e6,Ln);
fprintf('Required AL=%.1f nH/turn^2\n',AL_target*1e9);
fprintf('Proposed core: %.1f x %.1f x %.1f mm, leg %.1f x %.1f mm, Ae=%.1f mm^2\n', ...
    D.outer_x_mm,D.outer_y_mm,D.core_depth_mm,D.leg_x_mm,D.core_depth_mm,G.Ae*1e6);
fprintf('PCB finished slot at each leg: %.1f x %.1f mm; leg pitch %.1f mm\n', ...
    D.pcb_hole_x_mm,D.pcb_hole_y_mm,D.leg_center_pitch_mm);
fprintf('Total gap=%.3f mm (%.3f mm at each equal UU joint)\n',g_total*1e3,g_total*0.5e3);
fprintf('Lm at mui [-25%% nom +25%%]=[%.3f %.3f %.3f] uH\n',Lm_corner*1e6);
fprintf('Bpk=%.1f mT; estimated core loss=%.3f W\n',Bpk*1e3,Pcore_est);
fprintf('PCB stack thickness=%.3f mm (copper + dielectric)\n',W.board_thickness_mm);
fprintf('Opposite-leg target: Lopen=%.3f uH, Lsc=%.3f uH, coupling k=%.4f\n', ...
    Lopen_target*1e6,S.Llk_target*1e6,k_target);
fprintf('Target mutual inductance M=%.3f uH (ideal turns-scaled model)\n',M_target*1e6);
fprintf('Leakage tuning target: k=%.4f; accept Lsc=0.90 to 1.10 uH on first build\n',k_target);
fprintf('Cu skin depth=%.1f um; DC copper-loss lower bound=%.3f W\n',delta*1e6,Pcu_dc_lb);
fprintf('Window-fill proxy=%.3f\n',Ku_proxy);
fprintf('Four-secondary trace bank=%.2f mm; available half-window=%.2f mm\n', ...
    W.secondary_radial_build*1e3,D.window_y_mm/2);

if g_total<=0, warning('Ungapped core AL is already below target AL.'); end
if ~gain_reachable
    warning(['Required voltage gain is not reachable at 30 W in the inductive FHA region. ' ...
        'Change bridge topology, turns ratio, Lr/Lm, or allowed frequency range.']);
end
if Bpk>50e-3, warning('Bpk exceeds the DMR53 1 MHz/50 mT loss reference.'); end
warning(['Opposite-leg leakage cannot be predicted from stack-up alone. Tune U-leg spacing/' ...
    'winding footprint in 3-D FEA, then verify Lsc with secondary shorted.']);
if max(tCu)>2*delta, warning('Some copper layers exceed 2 skin depths; calculate AC resistance with FEA.'); end

%% Turns / square-leg scan at fixed voltage and transformer ratio
% Keep Np:Ns=3:4 so that 36 V half bridge gives 24 V at tank gain=1.
Scan.Np=3:3:18;
Scan.Ns=Scan.Np/n;
Scan.leg_side_mm=3.0:0.25:10.0;
Scan.B_limit=50e-3;
Scan.Pcore_limit=0.30;
[NP,LEGmm]=meshgrid(Scan.Np,Scan.leg_side_mm);
NS=NP/n;
AE=(LEGmm*1e-3).^2;
B_map=Vpri_square./(4*S.fr.*NP.*AE);
Pv_map=M.Pv_ref*(S.fr/M.f_ref)^M.alpha_f.*(B_map/M.B_ref).^M.beta_B;
Ve_map=AE*G.le;                    % same 80 mm mean path for first comparison
Pcore_map=Pv_map.*Ve_map;
gap_map=mu0.*AE.*NP.^2/S.Lm_target-G.le/M.mui_nom;

% DC copper estimate. AC proximity/via losses are not included.
tP=mean(tCu(W.Np_layer>0)); tS=mean(tCu(W.Ns_layer>0));
Rpri_map=rhoCu.*NP.*W.MLT/(W.trace_width_p*tP*W.primary_parallel);
Rsec_each_map=rhoCu.*NS.*W.MLT/(W.trace_width_s*tS*W.secondary_parallel);
Pcu_map=Iin^2.*Rpri_map+Iout^2.*Rsec_each_map/S.secondary_count;
Ptotal_map=Pcore_map+Pcu_map;
feasible=B_map<=Scan.B_limit & Pcore_map<=Scan.Pcore_limit & gap_map>0;
score=Ptotal_map; score(~feasible)=inf;
[bestLoss,bestLinear]=min(score,[],'all','linear');
[bestRow,bestCol]=ind2sub(size(score),bestLinear);
best.Np=NP(bestLinear); best.Ns=NS(bestLinear); best.leg_mm=LEGmm(bestLinear);
best.Ae_mm2=AE(bestLinear)*1e6; best.B_mT=B_map(bestLinear)*1e3;
best.Pcore=Pcore_map(bestLinear); best.Pcu=Pcu_map(bestLinear);
best.gap_mm=gap_map(bestLinear)*1e3;

fprintf('\n=== Fixed-ratio turns / leg scan ===\n');
fprintf('Best estimated point: Np:Ns=%d:%d, square leg %.2f mm, Ae %.2f mm^2\n', ...
    best.Np,best.Ns,best.leg_mm,best.Ae_mm2);
fprintf('Bpk=%.2f mT, Pcore=%.4f W, Pcu_dc=%.4f W, total=%.4f W, gap=%.3f mm\n', ...
    best.B_mT,best.Pcore,best.Pcu,bestLoss,best.gap_mm);

scanTable=table(NP(:),NS(:),LEGmm(:),AE(:)*1e6,B_map(:)*1e3, ...
    Pcore_map(:),Pcu_map(:),Ptotal_map(:),gap_map(:)*1e3,feasible(:), ...
    'VariableNames',{'Np','Ns','LegSide_mm','Ae_mm2','Bpk_mT','Pcore_W', ...
    'PcuDC_W','PtotalEst_W','TotalGap_mm','Feasible'});
outDir=fullfile(fileparts(mfilename('fullpath')),'output'); if ~exist(outDir,'dir'), mkdir(outDir); end
writetable(scanTable,fullfile(outDir,'LLC_turns_leg_scan.csv'));

figScan=figure('Color','w','Name','Turns and magnetic-leg scan','Position',[80 80 1250 800]);
tlScan=tiledlayout(figScan,2,2,'Padding','compact','TileSpacing','compact');
title(tlScan,sprintf('Fixed 36 V to 24 V, half bridge, N_p:N_s=3:4, L_m=%.1f uH',S.Lm_target*1e6));
scan_heatmap(nexttile(tlScan),Scan.Np,Scan.leg_side_mm,B_map*1e3,'B_{pk} (mT)',bestCol,bestRow);
scan_heatmap(nexttile(tlScan),Scan.Np,Scan.leg_side_mm,Pcore_map,'Core loss estimate (W)',bestCol,bestRow);
scan_heatmap(nexttile(tlScan),Scan.Np,Scan.leg_side_mm,Ptotal_map,'Core + DC copper loss (W)',bestCol,bestRow);
scan_heatmap(nexttile(tlScan),Scan.Np,Scan.leg_side_mm,gap_map*1e3, ...
    sprintf('Total gap for L_m=%.1f uH (mm)',S.Lm_target*1e6),bestCol,bestRow);
scanFile=fullfile(outDir,'LLC_turns_leg_scan.png');
try
    exportgraphics(figScan,scanFile,'Resolution',220);
    fprintf('Scan plot saved: %s\n',scanFile);
catch ME
    warning('Scan plot was not overwritten (%s). Continuing.',ME.message);
end
fprintf('Scan CSV saved: %s\n',fullfile(outDir,'LLC_turns_leg_scan.csv'));

%% Plots
figure('Color','w','Name','LLC fixed-turns-ratio check'); tiledlayout(2,1,'Padding','compact');
nexttile; plot(fn,H,'LineWidth',1.5); grid on; hold on;
yline(Mreq,'r--','Required gain'); xline(fn_op,'k:','Chosen point');
xlabel('f_s/f_r'); ylabel('|M|'); title(sprintf('LLC FHA gain, L_n=%.1f, Q=%.3f',Ln,Q));
nexttile; plot(fn,imag(Zin),'LineWidth',1.5); grid on; hold on; yline(0,'r--'); xline(fn_op,'k:');
xlabel('f_s/f_r'); ylabel('Im\{Z_{in}\}'); title('Positive value: inductive/ZVS-compatible region');

%% 2-D construction drawing (schematic; stack thickness is to scale)
fig2=figure('Color','w','Name','2-D UU planar transformer construction', ...
    'Position',[100 100 1250 650]);
tiledlayout(fig2,1,2,'Padding','compact','TileSpacing','compact');

% Top view: windings are on opposite U-core legs.
axA=nexttile; hold(axA,'on'); axis(axA,'equal'); axis(axA,[-32 32 -25 25]); axis(axA,'off');
coreColor=[0.24 0.27 0.30]; pColor=[0.90 0.25 0.18]; sColor=[0.10 0.45 0.85];
rectangle(axA,'Position',[-28 -21 56 7],'FaceColor',coreColor,'EdgeColor','k');
rectangle(axA,'Position',[-28 14 56 7],'FaceColor',coreColor,'EdgeColor','k');
rectangle(axA,'Position',[-28 -21 8 42],'FaceColor',coreColor,'EdgeColor','k');
rectangle(axA,'Position',[20 -21 8 42],'FaceColor',coreColor,'EdgeColor','k');
for q=0:5
    rectangle(axA,'Position',[-20-0.6*q, -12-0.3*q, 8.0+1.2*q, 24+0.6*q], ...
        'Curvature',[0.35 0.35],'EdgeColor',pColor,'LineWidth',1.5);
end
for q=0:7
    rectangle(axA,'Position',[12.8-0.65*q, -12-q*0.12, 7.2+1.3*q, 24+0.24*q], ...
        'Curvature',[0.35 0.35],'EdgeColor',sColor,'LineWidth',1.3);
end
text(axA,-16,0,sprintf('PRIMARY\n%d turns',S.Np),'Color',pColor,'FontWeight','bold','HorizontalAlignment','center');
text(axA,16,0,sprintf('SECONDARY\n%d turns',S.Ns),'Color',sColor,'FontWeight','bold','HorizontalAlignment','center');
text(axA,0,0,sprintf('DMR53 UU core\nopposite-leg winding\nk target = %.4f',k_target), ...
    'HorizontalAlignment','center','FontWeight','bold');
title(axA,'Top view - magnetic dimensions schematic only');

% Board cross-section: actual supplied thicknesses are drawn to scale.
axB=nexttile; hold(axB,'on'); axis(axB,'manual'); axis(axB,[0 100 0 W.board_thickness_mm]);
set(axB,'YDir','reverse','XTick',[]); ylabel(axB,'Board depth (mm)');
title(axB,sprintf('PCB stack cross-section - total %.3f mm',W.board_thickness_mm));
z=0;
for q=1:8
    tc=W.cu_mm(q);
    rectangle(axB,'Position',[5 z 90 tc],'FaceColor',[0.88 0.48 0.10],'EdgeColor','none');
    text(axB,2,z+tc/2,W.layer_name{q},'HorizontalAlignment','right','VerticalAlignment','middle','FontWeight','bold');
    if W.Np_layer(q)>0
        rectangle(axB,'Position',[8 z 34 tc],'FaceColor',pColor,'EdgeColor','none');
        text(axB,25,z+tc/2,sprintf('P: %gT',W.Np_layer(q)),'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',8);
    end
    if W.Ns_layer(q)>0
        rectangle(axB,'Position',[58 z 34 tc],'FaceColor',sColor,'EdgeColor','none');
        text(axB,75,z+tc/2,sprintf('4xS: %gT each',W.Ns_layer(q)),'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',8);
    end
    z=z+tc;
    if q<8
        td=W.diel_mm(q);
        rectangle(axB,'Position',[5 z 90 td],'FaceColor',[0.75 0.88 0.62],'EdgeColor',[0.65 0.75 0.55]);
        text(axB,97,z+td/2,sprintf('%.3f',td),'VerticalAlignment','middle','FontSize',8);
        z=z+td;
    end
end
text(axB,25,0.20,'Primary-side leg','Color',pColor,'FontWeight','bold','HorizontalAlignment','center');
text(axB,75,0.20,'Secondary-side leg','Color',sColor,'FontWeight','bold','HorizontalAlignment','center');
box(axB,'on');

outDir=fullfile(fileparts(mfilename('fullpath')),'output');
if ~exist(outDir,'dir'), mkdir(outDir); end
combinedFile=fullfile(outDir,'LLC_UU_transformer_2D.png');
try
    exportgraphics(fig2,combinedFile,'Resolution',200);
    fprintf('2-D drawing saved: %s\n',combinedFile);
catch ME
    warning('Combined drawing was not overwritten (%s). Continuing.',ME.message);
end

%% PCB winding top views, layer by layer
% Each occupied layer carries ONE turn. Adjacent layers are connected in
% series by vias; therefore turns overlap in plan view rather than forming
% six/eight concentric turns on one copper layer.
fig3=figure('Color','w','Name','PCB winding routing by layer','Position',[50 50 1500 850]);
tl3=tiledlayout(fig3,2,4,'Padding','compact','TileSpacing','compact');
title(tl3,'UU planar transformer - PCB winding routing (one turn per occupied layer)');
for q=1:8
    axT=nexttile(tl3); hold(axT,'on'); axis(axT,'equal'); axis(axT,[-32 32 -20 20]); axis(axT,'off');
    rectangle(axT,'Position',[-30 -18 60 36],'FaceColor',[0.88 0.93 0.82], ...
        'EdgeColor',[0.25 0.45 0.20],'LineWidth',1.0);
    % Core-leg penetration/keep-out areas in the PCB.
    rectangle(axT,'Position',[-19 -8 8 16],'FaceColor',coreColor,'EdgeColor','k');
    rectangle(axT,'Position',[11 -8 8 16],'FaceColor',coreColor,'EdgeColor','k');
    text(axT,-15,0,'U leg','Color','w','Rotation',90,'HorizontalAlignment','center');
    text(axT,15,0,'U leg','Color','w','Rotation',90,'HorizontalAlignment','center');

    if W.Np_layer(q)>0
        pOrder=find(W.Np_layer>0); pStep=find(pOrder==q);
        draw_one_turn(axT,-15,pColor,mod(pStep,2)==0,'P',pStep<numel(pOrder),0);
    else
        text(axT,-15,-13,'No primary copper','Color',[0.45 0.45 0.45], ...
            'HorizontalAlignment','center','FontSize',8);
    end
    if W.Ns_layer(q)>0
        sOrder=find(W.Ns_layer>0); sStep=find(sOrder==q);
        for m=1:S.secondary_count
            sLabel=''; if m==S.secondary_count, sLabel='4xS'; end
            draw_one_turn(axT,15,sColor,mod(sStep,2)==0,sLabel, ...
                sStep<numel(sOrder),0.75*(m-1));
        end
    end
    title(axT,sprintf('%s   Cu %.3f mm',W.layer_name{q},W.cu_mm(q)),'FontWeight','bold');
end
xlabel(tl3,['Filled dot = via to next occupied layer. Alternating arrows show the series path. ' ...
    'Via type/pad size must follow the PCB fabricator rules.']);
topFile=fullfile(outDir,'LLC_PCB_winding_top_view_layers.png');
try
    exportgraphics(fig3,topFile,'Resolution',220);
    fprintf('Layer-by-layer top view saved: %s\n',topFile);
catch ME
    warning('Layer drawing was not overwritten (%s). Continuing.',ME.message);
end

%% Manufacturable series-via topology (electrical routing, not XY dimensions)
fig4=figure('Color','w','Name','Series-turn via topology','Position',[80 80 1400 760]);
tl4=tiledlayout(fig4,1,2,'Padding','compact','TileSpacing','compact');
title(tl4,'PCB turns and distinct layer-transition vias');
axP=nexttile(tl4); draw_via_ladder(axP,2:7,'PRIMARY 6T - terminals on LEFT',pColor,'P');
axS=nexttile(tl4); draw_via_ladder(axS,1:8,'ONE SECONDARY 8T - repeat as four isolated copies',sColor,'S');
xlabel(tl4,['Vij is a unique physical via position joining only Li and Lj. ' ...
    'All other layers at that XY position require antipads. Never reuse one through-via barrel for several transitions.']);
viaFile=fullfile(outDir,'LLC_PCB_via_connection_topology_v2.png');
try
    exportgraphics(fig4,viaFile,'Resolution',220);
    fprintf('Via-connection topology saved: %s\n',viaFile);
catch ME
    warning('Via drawing was not overwritten (%s). Continuing.',ME.message);
end

%% Proposed custom UU core dimension drawing
figDim=figure('Color','w','Name','Proposed UU core dimensions','Position',[80 80 1350 720]);
tlDim=tiledlayout(figDim,1,2,'Padding','compact','TileSpacing','compact');
title(tlDim,'Proposed DMR53 UU core - first prototype dimensions (mm)');

% Top view: top and bottom U cores overlap in projection, 40 x 6 mm.
axD1=nexttile(tlDim); hold(axD1,'on'); axis(axD1,'equal'); axis(axD1,[-7 37 -8 14]); axis(axD1,'off');
rectangle(axD1,'Position',[-4 -4 D.outer_x_mm+8 14], ...
    'FaceColor',[0.55 0.75 0.25],'FaceAlpha',0.35,'EdgeColor',[0.2 0.45 0.1]);
rectangle(axD1,'Position',[0 0 D.outer_x_mm D.core_depth_mm], ...
    'FaceColor',coreColor,'EdgeColor','k','LineWidth',1.5);
% PCB finished slots around the two 6 x 6 leg end faces.
cx1=D.leg_x_mm/2; cx2=D.outer_x_mm-D.leg_x_mm/2; cy=D.core_depth_mm/2;
rectangle(axD1,'Position',[cx1-D.pcb_hole_x_mm/2 cy-D.pcb_hole_y_mm/2 ...
    D.pcb_hole_x_mm D.pcb_hole_y_mm],'EdgeColor',[0.9 0.2 0.1],'LineStyle','--','LineWidth',1.5);
rectangle(axD1,'Position',[cx2-D.pcb_hole_x_mm/2 cy-D.pcb_hole_y_mm/2 ...
    D.pcb_hole_x_mm D.pcb_hole_y_mm],'EdgeColor',[0.1 0.4 0.9],'LineStyle','--','LineWidth',1.5);
plot(axD1,[cx1 cx2],[cy cy],'k+:','LineWidth',1);
dim_h(axD1,0,D.outer_x_mm,-3,sprintf('%.1f overall',D.outer_x_mm));
dim_v(axD1,0,D.core_depth_mm,D.outer_x_mm+3,sprintf('%.1f overall',D.core_depth_mm));
dim_h(axD1,cx1,cx2,8.0,sprintf('%.1f leg pitch',D.leg_center_pitch_mm));
text(axD1,D.outer_x_mm/2,cy,sprintf('TOP U YOKE %.0f x %.0f',D.outer_x_mm,D.core_depth_mm), ...
    'Color','w','FontWeight','bold','HorizontalAlignment','center');
text(axD1,D.outer_x_mm/2,11.5,'Dashed: two PCB slots, 6.6 x 6.6 each', ...
    'Color',[0.15 0.15 0.15],'HorizontalAlignment','center','FontSize',9);
title(axD1,'Top view - upper and lower U cores overlap');

% Side view: two U halves approach the PCB from top and bottom.
axD2=nexttile(tlDim); hold(axD2,'on'); axis(axD2,'equal'); axis(axD2,[-7 37 -22 22]); axis(axD2,'off');
pcbY=-W.board_thickness_mm/2;
rectangle(axD2,'Position',[-3 pcbY D.outer_x_mm+6 W.board_thickness_mm], ...
    'FaceColor',[0.55 0.75 0.25],'FaceAlpha',0.55,'EdgeColor',[0.2 0.45 0.1],'LineWidth',1.2);
% Upper U: yoke and two legs. Lower U is mirrored.
legLength=D.outer_y_mm-D.yoke_y_mm;
rectangle(axD2,'Position',[0 legLength D.outer_x_mm D.yoke_y_mm],'FaceColor',coreColor,'EdgeColor','k');
rectangle(axD2,'Position',[0 0 D.leg_x_mm legLength],'FaceColor',coreColor,'EdgeColor','k');
rectangle(axD2,'Position',[D.outer_x_mm-D.leg_x_mm 0 D.leg_x_mm legLength],'FaceColor',coreColor,'EdgeColor','k');
rectangle(axD2,'Position',[0 -D.outer_y_mm D.outer_x_mm D.yoke_y_mm],'FaceColor',coreColor,'EdgeColor','k');
rectangle(axD2,'Position',[0 -legLength D.leg_x_mm legLength],'FaceColor',coreColor,'EdgeColor','k');
rectangle(axD2,'Position',[D.outer_x_mm-D.leg_x_mm -legLength D.leg_x_mm legLength],'FaceColor',coreColor,'EdgeColor','k');
dim_h(axD2,0,D.outer_x_mm,-19,sprintf('%.1f',D.outer_x_mm));
dim_v(axD2,0,D.outer_y_mm,D.outer_x_mm+3,sprintf('U height %.1f',D.outer_y_mm));
dim_v(axD2,pcbY,pcbY+W.board_thickness_mm,-4.5, ...
    sprintf('PCB %.3f',W.board_thickness_mm));
text(axD2,D.outer_x_mm/2,19,'Upper U core', ...
    'HorizontalAlignment','center','FontWeight','bold');
text(axD2,D.outer_x_mm/2,-18,'Lower U core','HorizontalAlignment','center','FontWeight','bold');
text(axD2,D.outer_x_mm/2,4.5,sprintf('Total magnetic gap %.3f (about %.3f at each leg joint)', ...
    g_total*1e3,g_total*0.5e3),'HorizontalAlignment','center');
title(axD2,'Side view - top/bottom assembly through PCB slots');

dimFile=fullfile(outDir,'LLC_UU_core_dimension_drawing_6p5uH.png');
exportgraphics(figDim,dimFile,'Resolution',240);
fprintf('Core dimension drawing saved: %s\n',dimFile);

function H=llc_gain(fn,Ln,Q)
Zs=1j*(fn-1./fn); Zm=1j*fn*Ln; R=1/Q; Zp=Zm.*R./(Zm+R); H=abs(Zp./(Zs+Zp));
end
function Z=llc_zin(fn,Ln,Q)
Zs=1j*(fn-1./fn); Zm=1j*fn*Ln; R=1/Q; Z=Zs+Zm.*R./(Zm+R);
end

function draw_one_turn(ax,cx,color,reverse,label,hasNext,offset)
% Open rectangular turn around one core leg. A/B are the layer-transition ends.
xL=cx-7-offset; xR=cx+7+offset; yB=-12-offset; yT=12+offset; gap=3;
xa=xR; ya=gap; xb=xR; yb=-gap;
x=[xa xR xL xL xR xb]; y=[ya yT yT yB yB yb];
if reverse, x=fliplr(x); y=fliplr(y); end
plot(ax,x,y,'Color',color,'LineWidth',3.0);
% Direction arrow on the top/bottom straight segment.
k=3; quiver(ax,x(k),y(k),0.35*(x(k+1)-x(k)),0.35*(y(k+1)-y(k)),0, ...
    'Color',color,'LineWidth',1.5,'MaxHeadSize',1.8);
plot(ax,[xa xb],[ya yb],'o','Color',color,'MarkerFaceColor','w','MarkerSize',5);
if hasNext
    if reverse, xv=xa; yv=ya; else, xv=xb; yv=yb; end
    plot(ax,xv,yv,'o','Color','k','MarkerFaceColor',color,'MarkerSize',8);
    if ~isempty(label)
        text(ax,xv-1.0,yv,sprintf('%s via',label),'Color',color,'FontSize',7, ...
            'HorizontalAlignment','right','VerticalAlignment','middle');
    end
else
    if reverse, xt=xa; yt=ya; else, xt=xb; yt=yb; end
    if ~isempty(label)
        text(ax,xt-1.0,yt,sprintf('%s OUT',label),'Color',color,'FontWeight','bold', ...
            'FontSize',7,'HorizontalAlignment','right','VerticalAlignment','middle');
    end
end
end

function draw_via_ladder(ax,layers,ttl,color,prefix)
% Exploded plan-routing schematic. Each row is one PCB copper layer/one turn.
hold(ax,'on'); axis(ax,[0 100 0 numel(layers)+1]); axis(ax,'off'); title(ax,ttl,'FontWeight','bold');
n=numel(layers);
for k=1:n
    y=n-k+1; reverse=mod(k,2)==0;
    rectangle(ax,'Position',[20 y-0.32 52 0.64],'Curvature',[0.15 0.7], ...
        'EdgeColor',color,'LineWidth',2.2);
    text(ax,16,y,sprintf('L%d',layers(k)),'HorizontalAlignment','right','FontWeight','bold');
    % Break the symbolic loop at alternate right-side ends.
    if reverse, yPort=y+0.18; else, yPort=y-0.18; end
    plot(ax,72,yPort,'o','Color',color,'MarkerFaceColor','w','MarkerSize',6);
    if k<n
        % Every transition uses a separate XY via site (shown staggered).
        xv=76+2.4*mod(k-1,5); y2=n-(k+1)+1;
        plot(ax,[72 xv xv 72],[yPort yPort y2-(-1)^k*0.18 y2-(-1)^k*0.18], ...
            'Color',color,'LineWidth',1.3);
        plot(ax,xv,(yPort+y2-(-1)^k*0.18)/2,'o','Color','k', ...
            'MarkerFaceColor',color,'MarkerSize',8);
        text(ax,xv+1,(yPort+y2)/2,sprintf('V%d%d',layers(k),layers(k+1)), ...
            'Color',color,'FontSize',8,'FontWeight','bold');
    end
end

plot(ax,5,n,'s','Color',color,'MarkerFaceColor',color,'MarkerSize',8);
plot(ax,[5 20],[n n],'Color',color,'LineWidth',2);
text(ax,4,n,sprintf('%s IN',prefix),'HorizontalAlignment','right','Color',color,'FontWeight','bold');
plot(ax,5,1,'s','Color',color,'MarkerFaceColor','w','MarkerSize',8);
plot(ax,[5 20],[1 1],'Color',color,'LineWidth',2);
text(ax,4,1,sprintf('%s OUT',prefix),'HorizontalAlignment','right','Color',color,'FontWeight','bold');
text(ax,46,0.45,sprintf('%d layers = %d series turns',n,n), ...
    'HorizontalAlignment','center','Color',color,'FontWeight','bold');
end

function scan_heatmap(ax,np,leg,z,ttl,bestCol,bestRow)
imagesc(ax,np,leg,z); set(ax,'YDir','normal'); colorbar(ax); hold(ax,'on');
plot(ax,np(bestCol),leg(bestRow),'wp','MarkerFaceColor','r','MarkerSize',12);
xlabel(ax,'Primary turns N_p'); ylabel(ax,'Square leg side (mm)'); title(ax,ttl);
xticks(ax,np); grid(ax,'on');
end

function dim_h(ax,x1,x2,y,label)
plot(ax,[x1 x2],[y y],'k-','LineWidth',0.9);
plot(ax,[x1 x1],[y-0.45 y+0.45],'k-'); plot(ax,[x2 x2],[y-0.45 y+0.45],'k-');
plot(ax,x1,y,'k>','MarkerFaceColor','k','MarkerSize',4);
plot(ax,x2,y,'k<','MarkerFaceColor','k','MarkerSize',4);
text(ax,(x1+x2)/2,y+0.55,label,'HorizontalAlignment','center','FontSize',9);
end

function dim_v(ax,y1,y2,x,label)
plot(ax,[x x],[y1 y2],'k-','LineWidth',0.9);
plot(ax,[x-0.45 x+0.45],[y1 y1],'k-'); plot(ax,[x-0.45 x+0.45],[y2 y2],'k-');
plot(ax,x,y1,'k^','MarkerFaceColor','k','MarkerSize',4);
plot(ax,x,y2,'kv','MarkerFaceColor','k','MarkerSize',4);
text(ax,x+0.65,(y1+y2)/2,label,'Rotation',90,'HorizontalAlignment','center','FontSize',9);
end

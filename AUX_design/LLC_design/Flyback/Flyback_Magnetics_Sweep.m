%% 2200 V to 24 V / 100 W planar Flyback UU-core sweep
% Preliminary electromagnetic design. High-voltage insulation and partial
% discharge requirements must be verified separately before production.
clear; clc; close all;

%% Electrical design point
E.Vin=2200; E.Vout=24; E.Pout=100; E.eta=0.90; E.fs=100e3;
E.Np=36; E.Ns=3; E.Lm=2.3e-3;
E.IpriRatedRms=0.30;
E.Iout=E.Pout/E.Vout;
E.Ipk=sqrt(2*E.Pout/(E.eta*E.Lm*E.fs));
E.D=E.Ipk*E.Lm*E.fs/E.Vin;
E.IpriRms=E.Ipk*sqrt(E.D/3);
E.Vref=E.Vout*E.Np/E.Ns;
E.Ddemag=E.Vin*E.D/E.Vref;
E.IsecPk=E.Ipk*E.Np/E.Ns;
E.IsecRms=E.IsecPk*sqrt(E.Ddemag/3);

%% PCB planar winding rules
W.primaryWidth_mm=0.20;
W.secondaryWidth_mm=4.00;
W.traceSpacing_mm=0.20;
W.primaryLayers=2; W.primaryTurnsPerLayer=18;
% AEDT primary series path viewed from PCB top (+Z): L2 outside-in clockwise,
% inner L1-L3 blind via, L3 inside-out clockwise (mirrored layer geometry).
W.secondaryLayers=2; W.secondaryTurnsPerLayer=3;
% Same 8-layer copper stack as the LLC board (finished copper thickness).
W.copperThickness_mm=[0.069 0.064 0.064 0.064 0.064 0.064 0.064 0.069];
W.primaryLayerIds=[2 3]; W.secondaryLayerIds=[6 7];
W.primaryJrms_Amm2=E.IpriRatedRms./ ...
    (W.primaryWidth_mm*W.copperThickness_mm(W.primaryLayerIds));
% First estimate assumes the two secondary layers share RMS current equally.
W.secondaryCurrentPerLayer_A=E.IsecRms/W.secondaryLayers;
W.secondaryJrms_Amm2=W.secondaryCurrentPerLayer_A./ ...
    (W.secondaryWidth_mm*W.copperThickness_mm(W.secondaryLayerIds));
W.primaryJmax_Amm2=max(W.primaryJrms_Amm2);
W.secondaryJmax_Amm2=max(W.secondaryJrms_Amm2);
W.coreClearance_mm=2.0;
W.rhoCu=1.724e-8;          % ohm*m at 20 C
W.copperTempFactor=1.24;   % approximately 80 C copper resistance / 20 C
W.FacPrimary=1.15;         % first-order 100 kHz proximity/via allowance
W.FacSecondary=1.25;
% AUX: two series turns, one in-plane turn on each of L4/L5, on the S leg.
W.auxLayerIds=[4 5]; W.auxTurnsPerLayer=1; E.Naux=2;
E.IauxRms=0.100; % treat the specified 100 mA as RMS for copper sizing
W.auxJtarget_Amm2=8;
W.auxWidth_mm=ceil(max(0.20,E.IauxRms/(W.auxJtarget_Amm2* ...
    min(W.copperThickness_mm(W.auxLayerIds))))/0.05)*0.05;
W.FacAux=1.15;

%% TDG TPG33 local loss model at 100 kHz / 80 C
% Datasheet values: mui=3300+/-25%; Pcv=260 kW/m^3 at 100 kHz,
% 200 mT and 80 C.  The local slope read from the 100 kHz Pcv-Bm curve is
% beta approximately 2.6.  Alpha=1.5 is retained only to form an AEDT-style
% Steinmetz coefficient; this sweep stays at 100 kHz, so alpha does not
% affect its B/geometry comparison. Pv [W/m^3] = k*f^alpha*B^beta.
M.name='TPG33'; M.temperature=80;
M.mui=3300; M.mui_tol=0.25;
M.Bsat25=0.530; M.Bsat100=0.410;
M.Bsat80=M.Bsat25+(M.Bsat100-M.Bsat25)*(80-25)/(100-25);
M.alpha=1.5; M.beta=2.6;
M.Panchor=260e3; M.fanchor=100e3; M.Banchor=0.200;
M.k=M.Panchor/(M.fanchor^M.alpha*M.Banchor^M.beta);
M.fmin=25e3; M.fmax=500e3;

%% Sweep variables
% Square centre-leg cross-section and effective closed magnetic path length.
S.legSide_mm=14:0.25:30;
S.corePath_mm=80:2:240;
[LEmm,LEGmm]=meshgrid(S.corePath_mm,S.legSide_mm);

mu0=4*pi*1e-7;
Ae=(LEGmm*1e-3).^2;
le=LEmm*1e-3;

% DeltaB is the unipolar flyback flux excursion from reset to peak. It is
% also the maximum flux when the core fully resets to approximately zero.
% Datasheet sinusoidal loss curves use Bm=DeltaBpp/2, not DeltaBpp.
Bpk=E.Lm*E.Ipk./(E.Np.*Ae);
Bac=Bpk/2;

% Lm=N^2/(le/(mu0*mur*Ae)+g/(mu0*Ae)); solve for total series gap.
gTotal=mu0.*Ae*E.Np^2/E.Lm-le/M.mui;
gEachJoint=gTotal/2; % a closed UU path crosses both leg-to-leg joints

% First-order volume and loss estimate. Ve=Ae*le is an effective-volume
% approximation; replace with the final core manufacturer's Ve when selected.
Ve=Ae.*le;
PvSine=M.k*E.fs^M.alpha.*Bac.^M.beta;
PcoreSine=PvSine.*Ve;

% Improved Generalized Steinmetz Equation (iGSE) for the actual DCM
% triangular rise and reset. The remaining part of the period has dB/dt=0.
% This normalization makes the expression reproduce the datasheet
% sinusoidal Steinmetz equation exactly for a sine wave.
cosIntegral=2*sqrt(pi)*gamma((M.alpha+1)/2)/gamma((M.alpha+2)/2);
M.ki=M.k/((2*pi)^(M.alpha-1)*2^(M.beta-M.alpha)*cosIntegral);
waveformFactor=E.D^(1-M.alpha)+E.Ddemag^(1-M.alpha);
Pv=M.ki*E.fs^M.alpha.*Bpk.^M.beta*waveformFactor;
Pcore=Pv.*Ve;

%% Geometry-dependent planar winding loss
% Approximate each turn as a square centreline around one UU leg. The turn
% side grows by two trace pitches per successive turn. Primary layers are
% in series. L7/L8 secondary spirals are in parallel, with current sharing
% calculated from their individual DC resistances.
pPitch_mm=W.primaryWidth_mm+W.traceSpacing_mm;
sPitch_mm=W.secondaryWidth_mm+W.traceSpacing_mm;
LpLayer=zeros(size(LEGmm));
for n=1:W.primaryTurnsPerLayer
    side_mm=LEGmm+2*W.coreClearance_mm+W.primaryWidth_mm+2*(n-1)*pPitch_mm;
    LpLayer=LpLayer+4*side_mm*1e-3;
end
LsLayer=zeros(size(LEGmm));
for n=1:W.secondaryTurnsPerLayer
    side_mm=LEGmm+2*W.coreClearance_mm+W.secondaryWidth_mm+2*(n-1)*sPitch_mm;
    LsLayer=LsLayer+4*side_mm*1e-3;
end

Rp=zeros(size(LEGmm));
for layer=W.primaryLayerIds
    area_m2=W.primaryWidth_mm*1e-3*W.copperThickness_mm(layer)*1e-3;
    Rp=Rp+W.rhoCu*W.copperTempFactor*LpLayer/area_m2;
end
RsLayers=zeros([size(LEGmm),W.secondaryLayers]);
for q=1:W.secondaryLayers
    layer=W.secondaryLayerIds(q);
    area_m2=W.secondaryWidth_mm*1e-3*W.copperThickness_mm(layer)*1e-3;
    RsLayers(:,:,q)=W.rhoCu*W.copperTempFactor*LsLayer/area_m2;
end
RsEq=1./sum(1./RsLayers,3);
Pprimary=E.IpriRatedRms^2.*Rp*W.FacPrimary;
Psecondary=E.IsecRms^2.*RsEq*W.FacSecondary;
% Closed-loop length approximation consistent with the other sweep windings.
% AUX centre-line at the radial midpoint of the complete primary copper band.
W.auxOffset_mm=W.coreClearance_mm+W.primaryWidth_mm/2+ ...
    (W.primaryTurnsPerLayer-1)*pPitch_mm/2;
W.auxCoreEdgeClearance_mm=W.auxOffset_mm-W.auxWidth_mm/2;
auxLength_m=4*(LEGmm+2*W.auxOffset_mm)*1e-3;
Raux=zeros(size(LEGmm));
for q=W.auxLayerIds
    Raux=Raux+W.rhoCu*W.copperTempFactor*auxLength_m./ ...
        (W.auxWidth_mm*W.copperThickness_mm(q)*1e-6);
end
Paux=E.IauxRms^2*Raux*W.FacAux;
Pwinding=Pprimary+Psecondary+Paux;
Pmagnetic=Pcore+Pwinding;

% Practical screening limits for the first mechanical prototype.
S.Blimit=0.20;             % T, conservative at 100 kHz
S.gTotalMin=0.10e-3;       % m
S.gTotalMax=1.00e-3;       % m
valid=Bpk<=S.Blimit & gTotal>=S.gTotalMin & gTotal<=S.gTotalMax;

score=Pmagnetic;
score(~valid)=inf;
[bestLoss,idx]=min(score(:));
if isfinite(bestLoss)
    [ir,ic]=ind2sub(size(score),idx);
    Best.legSide_mm=LEGmm(ir,ic);
    Best.corePath_mm=LEmm(ir,ic);
    Best.Ae_mm2=Ae(ir,ic)*1e6;
    Best.Bpk_mT=Bpk(ir,ic)*1e3;
    Best.gTotal_mm=gTotal(ir,ic)*1e3;
    Best.gEach_mm=gEachJoint(ir,ic)*1e3;
    Best.Ve_cm3=Ve(ir,ic)*1e6;
    Best.Pv_kWm3=Pv(ir,ic)/1e3;
    Best.PvSine_kWm3=PvSine(ir,ic)/1e3;
    Best.PcoreSine_W=PcoreSine(ir,ic);
    Best.Rprimary_ohm=Rp(ir,ic);
    Best.RsecondaryEq_ohm=RsEq(ir,ic);
    Best.Pprimary_W=Pprimary(ir,ic);
    Best.Psecondary_W=Psecondary(ir,ic);
    Best.Pwinding_W=Pwinding(ir,ic);
    Best.Pcore_W=Pcore(ir,ic);
    Best.Pmagnetic_W=Pmagnetic(ir,ic);
else
    error('No valid point in the requested scan range.');
end

%% Numerical report
fprintf('\n=== 2200 V / 24 V / 100 W FLYBACK SWEEP ===\n');
fprintf('Np:Ns=%d:%d, fs=%.0f kHz, Lm=%.3f mH, eta=%.1f%%\n', ...
    E.Np,E.Ns,E.fs/1e3,E.Lm*1e3,E.eta*100);
fprintf('Ipk=%.3f A, D=%.2f%%, Ipri_rms=%.3f A\n', ...
    E.Ipk,E.D*100,E.IpriRms);
fprintf('Primary winding thermal rating uses specified %.3f A RMS\n',E.IpriRatedRms);
fprintf('Isec_pk=%.2f A, Isec_rms=%.2f A, Iout=%.3f A\n', ...
    E.IsecPk,E.IsecRms,E.Iout);
fprintf('PCB traces: primary %.2f mm, secondary %.2f mm, spacing %.2f mm\n', ...
    W.primaryWidth_mm,W.secondaryWidth_mm,W.traceSpacing_mm);
fprintf('RMS current density: primary max %.2f A/mm^2, secondary max %.2f A/mm^2\n', ...
    W.primaryJmax_Amm2,W.secondaryJmax_Amm2);
fprintf('%s at %.0f C: k=%.8g, alpha=%.4f, beta=%.4f, mui=%g\n', ...
    M.name,M.temperature,M.k,M.alpha,M.beta,M.mui);
fprintf('Loss convention: DeltaB(reset-to-peak), Bac=DeltaB/2; iGSE ki=%.8g\n',M.ki);
fprintf('\nLowest-loss point inside imposed B/gap limits:\n');
fprintf('leg %.2f x %.2f mm, Ae=%.1f mm^2, le=%.1f mm\n', ...
    Best.legSide_mm,Best.legSide_mm,Best.Ae_mm2,Best.corePath_mm);
fprintf('Bpk=%.1f mT, total gap=%.3f mm, each joint=%.3f mm\n', ...
    Best.Bpk_mT,Best.gTotal_mm,Best.gEach_mm);
fprintf('Ve=%.2f cm^3, iGSE Pv=%.2f kW/m^3, Pcore=%.3f W\n', ...
    Best.Ve_cm3,Best.Pv_kWm3,Best.Pcore_W);
fprintf('Sine-equivalent Pv=%.2f kW/m^3, Pcore=%.3f W; waveform factor=%.3f\n', ...
    Best.PvSine_kWm3,Best.PcoreSine_W,Best.Pcore_W/Best.PcoreSine_W);
fprintf('Rpri@80C=%.3f ohm, Rsec_eq@80C=%.4f ohm\n', ...
    Best.Rprimary_ohm,Best.RsecondaryEq_ohm);
fprintf('Winding loss: primary %.3f W + secondary %.3f W = %.3f W\n', ...
    Best.Pprimary_W,Best.Psecondary_W,Best.Pwinding_W);
fprintf('Estimated core + winding loss=%.3f W\n',Best.Pmagnetic_W);
fprintf('=================================================\n');

%% Export all valid candidates
outDir=fullfile(fileparts(mfilename('fullpath')),'output');
if ~exist(outDir,'dir'), mkdir(outDir); end
candidateTable=table(LEGmm(valid),LEmm(valid),Ae(valid)*1e6, ...
    Bpk(valid)*1e3,Bac(valid)*1e3,gTotal(valid)*1e3,gEachJoint(valid)*1e3, ...
    Ve(valid)*1e6,PvSine(valid)/1e3,PcoreSine(valid), ...
    Pv(valid)/1e3,Pcore(valid),Rp(valid),RsEq(valid), ...
    Pprimary(valid),Psecondary(valid),Pwinding(valid),Pmagnetic(valid),Paux(valid),Raux(valid), ...
    'VariableNames',{'LegSide_mm','CorePath_mm','Ae_mm2','DeltaB_mT','Bac_mT', ...
    'GapTotal_mm','GapEachJoint_mm','Ve_cm3','PvSine_kW_per_m3', ...
    'CoreLossSine_W','PvIGSE_kW_per_m3','CoreLossIGSE_W', ...
    'PrimaryResistance_ohm','SecondaryReq_ohm','PrimaryLoss_W', ...
    'SecondaryLoss_W','WindingLoss_W','CorePlusWindingLoss_W','AuxLoss_W','AuxResistance_ohm'});
candidateTable=sortrows(candidateTable,{'CorePlusWindingLoss_W','LegSide_mm'});
writetable(candidateTable,fullfile(outDir,'Flyback_TPG33_core_sweep.csv'));

%% Line plots (no colour-map surfaces)
selectedPaths=[120 160 200 240];
fig=figure('Color','w','Position',[80 80 1250 820]);
tl=tiledlayout(fig,2,2,'Padding','compact','TileSpacing','compact');
title(tl,{sprintf('TPG33 UU Flyback: %.0f V to %.0f V / %.0f W / %.0f kHz / %.0f C', ...
    E.Vin,E.Vout,E.Pout,E.fs/1e3,M.temperature), ...
    sprintf('N_p:N_s=%d:%d, L_m=%.2f mH, trace P/S=%.2f/%.2f mm, spacing=%.2f mm', ...
    E.Np,E.Ns,E.Lm*1e3,W.primaryWidth_mm,W.secondaryWidth_mm,W.traceSpacing_mm), ...
    sprintf('P: L2/L3 x 18T series; S: L6/L7 x 3T parallel; J_{rms,max} P/S=%.2f/%.2f A/mm^2', ...
    W.primaryJmax_Amm2,W.secondaryJmax_Amm2)});

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on');
for q=1:numel(selectedPaths)
    [~,j]=min(abs(S.corePath_mm-selectedPaths(q)));
    plot(ax,S.legSide_mm,Bpk(:,j)*1e3,'LineWidth',1.5, ...
        'DisplayName',sprintf('l_e = %.0f mm',S.corePath_mm(j)));
end
yline(ax,S.Blimit*1e3,'--','B limit');
xlabel(ax,'Square centre-leg side (mm)'); ylabel(ax,'B_{pk} (mT)');
legend(ax,'Location','northeast');

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on');
for q=1:numel(selectedPaths)
    [~,j]=min(abs(S.corePath_mm-selectedPaths(q)));
    plot(ax,S.legSide_mm,gTotal(:,j)*1e3,'LineWidth',1.5, ...
        'DisplayName',sprintf('l_e = %.0f mm',S.corePath_mm(j)));
end
yline(ax,S.gTotalMin*1e3,'--','minimum gap');
xlabel(ax,'Square centre-leg side (mm)'); ylabel(ax,'Total series gap (mm)');
legend(ax,'Location','northwest');

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on');
[~,j120]=min(abs(S.corePath_mm-120));
plot(ax,S.legSide_mm,Pprimary(:,j120),'LineWidth',1.5,'DisplayName','Primary winding');
plot(ax,S.legSide_mm,Psecondary(:,j120),'LineWidth',1.5,'DisplayName','Secondary winding');
plot(ax,S.legSide_mm,Pwinding(:,j120),'k--','LineWidth',1.6,'DisplayName','Total winding');
xlabel(ax,'Square centre-leg side (mm)'); ylabel(ax,'Estimated winding loss (W)');
title(ax,sprintf('Winding loss at l_e = %.0f mm',S.corePath_mm(j120)));
legend(ax,'Location','northeast');

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on');
validLoss=Pmagnetic; validLoss(~valid)=nan;
for q=1:numel(selectedPaths)
    [~,j]=min(abs(S.corePath_mm-selectedPaths(q)));
    plot(ax,S.legSide_mm,validLoss(:,j),'LineWidth',1.5, ...
        'DisplayName',sprintf('l_e = %.0f mm',S.corePath_mm(j)));
end
plot(ax,Best.legSide_mm,Best.Pmagnetic_W,'ko','MarkerFaceColor','k', ...
    'DisplayName','minimum valid total');
xlabel(ax,'Square centre-leg side (mm)'); ylabel(ax,'Core + winding loss (W)');
legend(ax,'Location','northeast');

exportgraphics(fig,fullfile(outDir,'Flyback_TPG33_core_sweep.png'),'Resolution',180);

%% 2-D line drawing of the selected practical UU-core design
% Choose a 24 mm square leg. Determine the leg pitch from the actual 18-turn
% primary and 3-turn secondary radial builds plus 10 mm P-S copper clearance.
G.leg=24; G.depth=24; G.targetPSClearance=10;
G.pcbThickness=sum(W.copperThickness_mm)+sum([.346 .406 .393 .406 .406 .406 .360]);
G.corePCBclearance=1; % mm, each PCB surface to inner yoke face
G.primaryOuterSide=G.leg+2*(W.coreClearance_mm+W.primaryWidth_mm/2+ ...
    (W.primaryTurnsPerLayer-1)*pPitch_mm);
G.secondaryOuterSide=G.leg+2*(W.coreClearance_mm+W.secondaryWidth_mm/2+ ...
    (W.secondaryTurnsPerLayer-1)*sPitch_mm);
G.minimumLegPitch=G.primaryOuterSide/2+G.secondaryOuterSide/2+ ...
    G.targetPSClearance;
% Round the complete core length upward to an integer manufacturing size.
G.length=ceil(G.leg+G.minimumLegPitch);
G.legPitch=G.length-G.leg;
G=lowProfileUU(G,E,M,mu0);
% Centreline magnetic path: each U contributes one yoke span plus two
% joint-to-yoke-centre legs. A closed UU path traverses both U halves.
% le = 2*[legPitch + 2*(Uheight-leg/2)].
G.le=2*(G.legPitch+2*(G.Uheight-G.leg/2));
G.actualPSClearance=G.legPitch-G.primaryOuterSide/2-G.secondaryOuterSide/2;
G.farthestPSSpan=G.legPitch+G.primaryOuterSide/2+G.secondaryOuterSide/2;
G.slot=G.leg+0.6;
G.boardX=G.length+28; G.boardY=60;
[~,ig]=min(abs(S.legSide_mm-G.leg));
[~,jg]=min(abs(S.corePath_mm-G.le));
G.Bpk_mT=Bpk(ig,jg)*1e3;
G.Pcore_W=Pv(ig,jg)*(G.leg*G.depth*G.le)*1e-9;
G.Pwinding_W=Pwinding(ig,jg);
G.Paux_W=Paux(ig,jg);
fprintf('AUX: L4+L5 series 1T+1T, %.0f mA RMS, trace %.2f mm, J=%.3f A/mm2, loss %.4f W\n', ...
    E.IauxRms*1e3,W.auxWidth_mm,E.IauxRms/(W.auxWidth_mm*W.copperThickness_mm(4)),G.Paux_W);
G.Ptotal_W=G.Pcore_W+G.Pwinding_W;
G.pcbThickness=sum(W.copperThickness_mm)+sum([.346 .406 .393 .406 .406 .406 .360]);

fig2D=figure('Color','w','Position',[60 70 1500 850]);
coreGray=[.65 .65 .65]; % common core fill for every geometry figure
tl2D=tiledlayout(fig2D,1,2,'Padding','compact','TileSpacing','compact');
title(tl2D,{sprintf('TPG33 planar Flyback selected UU core - %.0f V to %.0f V / %.0f W / %.0f kHz', ...
    E.Vin,E.Vout,E.Pout,E.fs/1e3), ...
    sprintf('N_p:N_s=%d:%d, L_m=%.2f mH, trace P/S=%.2f/%.2f mm, spacing=%.2f mm', ...
    E.Np,E.Ns,E.Lm*1e3,W.primaryWidth_mm,W.secondaryWidth_mm,W.traceSpacing_mm), ...
    sprintf('Core=%.0f x %.0f mm, one-U height=%.0f mm, A_e=%.0f mm^2, l_e=%.0f mm', ...
    G.length,G.depth,G.Uheight,G.leg*G.depth,G.le), ...
    sprintf('L2/L3: 18T+18T series; L6/L7: 3T||3T; P-S nearest/farthest=%.1f/%.1f mm', ...
    G.actualPSClearance,G.farthestPSSpan), ...
    sprintf('B_{pk}=%.1f mT, gap=%.3f mm total / %.3f mm each joint, loss core/winding=%.2f/%.2f W', ...
    G.Bpk_mT,G.gTotal_mm,G.gEach_mm,G.Pcore_W,G.Pwinding_W), ...
    'AUX on secondary leg: L4+L5 series 1T+1T; 100 mA RMS; 0.20 mm trace (green)'});

% Top view: line-only core, slots, and representative in-plane spirals.
ax=nexttile(tl2D); hold(ax,'on'); axis(ax,'equal'); axis(ax,'off');
x0=-G.length/2; y0=-G.depth/2;
rectangle(ax,'Position',[-G.boardX/2 -G.boardY/2 G.boardX G.boardY], ...
    'EdgeColor',[.35 .35 .35],'LineStyle',':','LineWidth',1.2);
rectangle(ax,'Position',[x0 y0 G.length G.depth], ...
    'EdgeColor','k','LineWidth',2.0,'FaceColor',coreGray);
legCx=[x0+G.leg/2, x0+G.length-G.leg/2];
for q=1:2
    rectangle(ax,'Position',[legCx(q)-G.slot/2 -G.slot/2 G.slot G.slot], ...
        'EdgeColor','k','LineStyle','--','LineWidth',1.2);
end
% Six primary turns shown on one representative layer around the left leg.
for n=1:W.primaryTurnsPerLayer
    side=G.leg+2*(W.coreClearance_mm+W.primaryWidth_mm/2+(n-1)*pPitch_mm);
    rectangle(ax,'Position',[legCx(1)-side/2 -side/2 side side], ...
        'EdgeColor',[.75 .12 .08],'LineWidth',1.0);
end
% Three secondary turns shown around the right leg; L7/L8 are parallel.
for n=1:W.secondaryTurnsPerLayer
    side=G.leg+2*(W.coreClearance_mm+W.secondaryWidth_mm/2+(n-1)*sPitch_mm);
    rectangle(ax,'Position',[legCx(2)-side/2 -side/2 side side], ...
        'EdgeColor',[.05 .30 .80],'LineWidth',2.0);
end
drawAuxPlan(ax,legCx(2),G,W);
dimHfb(ax,x0,x0+G.length,-49,sprintf('Core overall %.1f',G.length));
dimHfb(ax,legCx(1),legCx(2),G.boardY/2+5, ...
    sprintf('Leg pitch %.1f',legCx(2)-legCx(1)));
dimVfb(ax,y0,y0+G.depth,G.boardX/2+11,sprintf('Core depth %.1f',G.depth));
text(ax,legCx(1),G.boardY/2-3,'PRIMARY: L2/L3, 18T + 18T series', ...
    'Color',[.75 .12 .08],'HorizontalAlignment','center','FontWeight','bold');
text(ax,legCx(2),G.boardY/2-3,'SECONDARY: L6/L7, 3T || 3T', ...
    'Color',[.05 .30 .80],'HorizontalAlignment','center','FontWeight','bold');
title(ax,'Top view - PCB planar winding arrangement');
% Dimension the winding envelopes and their nearest/farthest copper spans.
pLeft=legCx(1)-G.primaryOuterSide/2; pRight=legCx(1)+G.primaryOuterSide/2;
sLeft=legCx(2)-G.secondaryOuterSide/2; sRight=legCx(2)+G.secondaryOuterSide/2;
dimHfb(ax,pRight,sLeft,-35,sprintf('P-S nearest %.1f',G.actualPSClearance));
dimHfb(ax,pLeft,sRight,-42,sprintf('P-S farthest %.1f',G.farthestPSSpan));
dimVfb(ax,-G.primaryOuterSide/2,G.primaryOuterSide/2,pLeft-5, ...
    sprintf('P outer %.1f',G.primaryOuterSide));
dimVfb(ax,-G.secondaryOuterSide/2,G.secondaryOuterSide/2,sRight+3, ...
    sprintf('S outer %.1f',G.secondaryOuterSide));
xlim(ax,[-G.boardX/2-12 G.boardX/2+20]); ylim(ax,[-54 G.boardY/2+8]);

% Side assembly: upper/lower U halves, PCB stack and joint gaps.
ax=nexttile(tl2D); hold(ax,'on'); axis(ax,'equal'); axis(ax,'off');
L=G.length; h=G.Uheight; a=G.leg; stem=h-a; pcb=G.pcbThickness;
gh=G.gEach_mm/2;
% Eight copper layers are horizontal and in the PCB plane.
rectangle(ax,'Position',[-4 -pcb/2 L+8 pcb], ...
    'EdgeColor',[.30 .30 .30],'LineStyle',':','LineWidth',1.2);
layerZ=linspace(-pcb/2,pcb/2,8);
for n=1:8
    plot(ax,[-4 L+4],[layerZ(n) layerZ(n)],'Color',[.45 .45 .45],'LineWidth',0.7);
    text(ax,L+5,layerZ(n),sprintf('L%d',n),'FontSize',7);
end
% Upper and lower U-core outlines.
rectangle(ax,'Position',[0 stem+gh L a],'EdgeColor','k','LineWidth',2,'FaceColor',coreGray);
rectangle(ax,'Position',[0 gh a stem],'EdgeColor','k','LineWidth',2,'FaceColor',coreGray);
rectangle(ax,'Position',[L-a gh a stem],'EdgeColor','k','LineWidth',2,'FaceColor',coreGray);
rectangle(ax,'Position',[0 -h-gh L a],'EdgeColor','k','LineWidth',2,'FaceColor',coreGray);
rectangle(ax,'Position',[0 -stem-gh a stem],'EdgeColor','k','LineWidth',2,'FaceColor',coreGray);
rectangle(ax,'Position',[L-a -stem-gh a stem],'EdgeColor','k','LineWidth',2,'FaceColor',coreGray);
% Emphasise the physical gap at each leg joint.
plot(ax,[0 a],[gh gh],'m-',[0 a],[-gh -gh],'m-','LineWidth',1.5);
plot(ax,[L-a L],[gh gh],'m-',[L-a L],[-gh -gh],'m-','LineWidth',1.5);
dimHfb(ax,0,L,-h-a/2-6,sprintf('Overall %.1f',L));
dimVfb(ax,gh,h+gh,L+9,sprintf('One U height %.1f',h));
dimVfb(ax,-h-gh,h+gh,L+15,sprintf('Assembly %.3f',2*h+2*gh));
dimVfb(ax,-pcb/2,pcb/2,-7,sprintf('PCB %.3f',pcb));
text(ax,L/2,h+gh-a/2,'UPPER U CORE','HorizontalAlignment','center');
text(ax,L/2,-h-gh+a/2,'LOWER U CORE','HorizontalAlignment','center');
text(ax,L/2,7,sprintf('Leg %.1f x %.1f mm; each joint gap %.3f mm', ...
    G.leg,G.depth,G.gEach_mm),'HorizontalAlignment','center');
title(ax,'Side view - top/bottom UU assembly');
xlim(ax,[-12 L+16]); ylim(ax,[-h-a/2-10 h+a/2+8]);

% Design consistency checks.
assert(W.primaryLayers*W.primaryTurnsPerLayer==E.Np,'Primary turns do not sum to Np.');
assert(W.secondaryTurnsPerLayer==E.Ns,'Secondary turns do not match Ns.');
assert(E.D+E.Ddemag<1,'No reset/dead-time margin remains in the DCM cycle.');
assert(G.actualPSClearance>=G.targetPSClearance,'P-S clearance is below target.');
assert(G.gTotal_mm>0,'Selected core requires a non-positive gap.');

fprintf('\n=== SELECTED 80 mm UU CORE AUDIT ===\n');
fprintf('Core %.1f x %.1f mm, one-U height %.1f mm, leg %.1f x %.1f mm\n', ...
    G.length,G.depth,G.Uheight,G.leg,G.depth);
fprintf('Leg pitch %.1f mm, le %.1f mm, Ae %.1f mm^2, Ve %.3f cm^3\n', ...
    G.legPitch,G.le,G.leg*G.depth,G.leg*G.depth*G.le/1000);
fprintf('Primary outer %.1f mm, secondary outer %.1f mm\n', ...
    G.primaryOuterSide,G.secondaryOuterSide);
fprintf('P-S nearest %.1f mm, farthest %.1f mm\n', ...
    G.actualPSClearance,G.farthestPSSpan);
fprintf('DeltaB %.2f mT, Bac %.2f mT, gap total/each %.3f/%.3f mm\n', ...
    G.Bpk_mT,G.Bpk_mT/2,G.gTotal_mm,G.gEach_mm);
fprintf('Loss core/winding/total %.3f/%.3f/%.3f W\n', ...
    G.Pcore_W,G.Pwinding_W,G.Ptotal_W);
fprintf('=====================================\n');

selected2D=fullfile(outDir,'Flyback_TPG33_selected_UU_2D_L2L3_L6L7.png');
exportgraphics(fig2D,selected2D,'Resolution',240);
fprintf('Selected 2-D core/winding drawing: %s\n',selected2D);

%% Alternative B: primary above secondary, both around the right leg
% L1 is treated as the PCB top side. L2/L3 primary is therefore physically
% above L6/L7 secondary. The unused left leg is only the magnetic return.
G2=G;
G2.length=64; G2.legPitch=G2.length-G2.leg;
G2=lowProfileUU(G2,E,M,mu0);
G2.le=2*(G2.legPitch+2*(G2.Uheight-G2.leg/2));
G2.returnLegClearance=G2.legPitch-G2.leg/2- ...
    max(G2.primaryOuterSide,G2.secondaryOuterSide)/2;
G2.gTotal_mm=(mu0*(G2.leg*1e-3)*(G2.depth*1e-3)*E.Np^2/E.Lm- ...
    (G2.le*1e-3)/M.mui)*1e3;
G2.gEach_mm=G2.gTotal_mm/2;
G2.Ve_cm3=G2.leg*G2.depth*G2.le/1000;
% B and loss density are unchanged because Ae, N, Lm and current are equal.
G2.Bpk_mT=G.Bpk_mT;
G2.Pcore_W=Pv(ig,jg)*(G2.Ve_cm3*1e-6);
G2.Pwinding_W=G.Pwinding_W;
G2.Ptotal_W=G2.Pcore_W+G2.Pwinding_W;
% Copper-surface separation from L3 to L6 using the original 8-layer stack.
stackDiel_mm=[.346 .406 .393 .406 .406 .406 .360];
G2.verticalPS_mm=stackDiel_mm(3)+W.copperThickness_mm(4)+ ...
    stackDiel_mm(4)+W.copperThickness_mm(5)+stackDiel_mm(5);

figCmp=figure('Color','w','Position',[50 45 1550 1000]);
tlCmp=tiledlayout(figCmp,2,2,'Padding','compact','TileSpacing','compact');
title(tlCmp,{sprintf('TPG33 planar Flyback winding comparison - %.0f V to %.0f V / %.0f W / %.0f kHz', ...
    E.Vin,E.Vout,E.Pout,E.fs/1e3), ...
    sprintf('N_p:N_s=%d:%d, L_m=%.2f mH; P=L2/L3 18T+18T, S=L6/L7 3T||3T', ...
    E.Np,E.Ns,E.Lm*1e3), ...
    'AUX: L4+L5 series 1T+1T, 100 mA RMS, trace 0.20 mm (green)'});

% Scheme A top view: windings on opposite legs.
ax=nexttile(tlCmp); hold(ax,'on'); axis(ax,'equal'); axis(ax,'off');
xA=-G.length/2; cA=[xA+G.leg/2,xA+G.length-G.leg/2];
rectangle(ax,'Position',[xA -G.depth/2 G.length G.depth],'EdgeColor','k','LineWidth',1.8,'FaceColor',coreGray);
for q=1:2
    rectangle(ax,'Position',[cA(q)-G.slot/2 -G.slot/2 G.slot G.slot], ...
        'EdgeColor','k','LineStyle','--');
end
for n=1:W.primaryTurnsPerLayer
    side=G.leg+2*(W.coreClearance_mm+W.primaryWidth_mm/2+(n-1)*pPitch_mm);
    rectangle(ax,'Position',[cA(1)-side/2 -side/2 side side], ...
        'EdgeColor',[.78 .10 .06],'LineWidth',.8);
end
for n=1:W.secondaryTurnsPerLayer
    side=G.leg+2*(W.coreClearance_mm+W.secondaryWidth_mm/2+(n-1)*sPitch_mm);
    rectangle(ax,'Position',[cA(2)-side/2 -side/2 side side], ...
        'EdgeColor',[.04 .28 .80],'LineWidth',1.8);
end
drawAuxPlan(ax,cA(2),G,W);
pRight=cA(1)+G.primaryOuterSide/2; sLeft=cA(2)-G.secondaryOuterSide/2;
dimHfb(ax,pRight,sLeft,-31,sprintf('P-S lateral %.1f mm',G.actualPSClearance));
dimHfb(ax,xA,xA+G.length,-38,sprintf('Core %.0f mm',G.length));
xlim(ax,[-58 60]); ylim(ax,[-43 35]);
title(ax,sprintf('A - split legs: P left / S right\nl_e=%.0f mm, gap=%.3f mm, loss=%.2f W', ...
    G.le,G.gTotal_mm,G.Ptotal_W));

% Scheme B top view: both windings concentric around the right leg.
ax=nexttile(tlCmp); hold(ax,'on'); axis(ax,'equal'); axis(ax,'off');
xB=-G2.length/2; cB=[xB+G2.leg/2,xB+G2.length-G2.leg/2];
rectangle(ax,'Position',[xB -G2.depth/2 G2.length G2.depth],'EdgeColor','k','LineWidth',1.8,'FaceColor',coreGray);
for q=1:2
    rectangle(ax,'Position',[cB(q)-G2.slot/2 -G2.slot/2 G2.slot G2.slot], ...
        'EdgeColor','k','LineStyle','--');
end
% Draw the lower secondary first, then the upper primary as dashed red.
for n=1:W.secondaryTurnsPerLayer
    side=G2.leg+2*(W.coreClearance_mm+W.secondaryWidth_mm/2+(n-1)*sPitch_mm);
    rectangle(ax,'Position',[cB(2)-side/2 -side/2 side side], ...
        'EdgeColor',[.04 .28 .80],'LineWidth',2.0);
end
for n=1:W.primaryTurnsPerLayer
    side=G2.leg+2*(W.coreClearance_mm+W.primaryWidth_mm/2+(n-1)*pPitch_mm);
    rectangle(ax,'Position',[cB(2)-side/2 -side/2 side side], ...
        'EdgeColor',[.78 .10 .06],'LineStyle','--','LineWidth',.9);
end
drawAuxPlan(ax,cB(2),G2,W);
text(ax,cB(1),0,sprintf('EMPTY\nRETURN LEG'), ...
    'HorizontalAlignment','center','FontWeight','bold');
text(ax,cB(2),30,'P above S on right leg','HorizontalAlignment','center','FontWeight','bold');
dimHfb(ax,xB,xB+G2.length,-38,sprintf('Core %.0f mm',G2.length));
xlim(ax,[-50 55]); ylim(ax,[-43 35]);
title(ax,sprintf('B - stacked on right leg\nl_e=%.0f mm, gap=%.3f mm, loss=%.2f W', ...
    G2.le,G2.gTotal_mm,G2.Ptotal_W));

% Scheme A layer/location diagram.
ax=nexttile(tlCmp); hold(ax,'on'); axis(ax,'off');
axis(ax,[0 100 0 9]);
for n=1:8
    y=9-n;
    plot(ax,[5 95],[y y],'Color',[.65 .65 .65]);
    text(ax,2,y,sprintf('L%d',n),'HorizontalAlignment','right');
end
for n=W.primaryLayerIds
    y=9-n; plot(ax,[12 42],[y y],'Color',[.78 .10 .06],'LineWidth',7);
end
for n=W.secondaryLayerIds
    y=9-n; plot(ax,[58 88],[y y],'Color',[.04 .28 .80],'LineWidth',7);
end
for n=W.auxLayerIds
    plot(ax,[58 88],[9-n 9-n],'Color',[0 .55 .2],'LineWidth',7);
    text(ax,55,9-n,'AUX 1T','HorizontalAlignment','right','Color',[0 .45 .15]);
end
text(ax,27,8.7,'PRIMARY left leg','Color',[.78 .10 .06], ...
    'HorizontalAlignment','center','FontWeight','bold');
text(ax,73,8.7,'SECONDARY right leg','Color',[.04 .28 .80], ...
    'HorizontalAlignment','center','FontWeight','bold');
text(ax,50,.35,sprintf('Horizontal copper clearance = %.1f mm',G.actualPSClearance), ...
    'HorizontalAlignment','center');
title(ax,'A - layer and lateral location');

% Scheme B layer diagram: same lateral position but separated vertically.
ax=nexttile(tlCmp); hold(ax,'on'); axis(ax,'off');
axis(ax,[0 100 0 9]);
for n=1:8
    y=9-n;
    plot(ax,[5 95],[y y],'Color',[.65 .65 .65]);
    text(ax,2,y,sprintf('L%d',n),'HorizontalAlignment','right');
end
for n=W.primaryLayerIds
    y=9-n; plot(ax,[35 75],[y y],'Color',[.78 .10 .06],'LineWidth',7);
end
for n=W.secondaryLayerIds
    y=9-n; plot(ax,[35 75],[y y],'Color',[.04 .28 .80],'LineWidth',7);
end
for n=W.auxLayerIds
    plot(ax,[35 75],[9-n 9-n],'Color',[0 .55 .2],'LineWidth',7);
    text(ax,32,9-n,'AUX 1T','HorizontalAlignment','right','Color',[0 .45 .15]);
end
plot(ax,[82 82],[9-W.primaryLayerIds(end) 9-W.secondaryLayerIds(1)],'k-');
plot(ax,82,9-W.primaryLayerIds(end),'kv','MarkerFaceColor','k');
plot(ax,82,9-W.secondaryLayerIds(1),'k^','MarkerFaceColor','k');
text(ax,84,mean([9-W.primaryLayerIds(end),9-W.secondaryLayerIds(1)]), ...
    sprintf('vertical copper gap\n%.3f mm',G2.verticalPS_mm));
text(ax,55,8.7,'PRIMARY above SECONDARY - same right leg', ...
    'HorizontalAlignment','center','FontWeight','bold');
text(ax,50,.35,sprintf('Left return-leg clearance = %.1f mm',G2.returnLegClearance), ...
    'HorizontalAlignment','center');
title(ax,'B - layer stack and vertical isolation');

comparison2D=fullfile(outDir,'Flyback_TPG33_two_winding_schemes_2D.png');
exportgraphics(figCmp,comparison2D,'Resolution',240);
fprintf('\nScheme B: core %.1f mm, le %.1f mm, gap %.3f mm, vertical P-S %.3f mm\n', ...
    G2.length,G2.le,G2.gTotal_mm,G2.verticalPS_mm);
fprintf('Scheme B loss core/winding/total %.3f/%.3f/%.3f W\n', ...
    G2.Pcore_W,G2.Pwinding_W,G2.Ptotal_W);
fprintf('Two-scheme comparison drawing: %s\n',comparison2D);

%% Alternative C: split the unused return leg into two EE outer legs
G3=G2;
G3.outerLeg=G2.leg/2; G3.yoke=G2.leg/2; G3.window=G2.length-2*G2.leg;
% Each yoke branch carries half the centre flux. With half the centre area,
% its nominal B equals centre-leg B; core loss must use this updated area.
G3.length=G3.leg+2*G3.window+2*G3.outerLeg;
G3.pitch=G3.leg/2+G3.window+G3.outerLeg/2;
% Start with zero-gap height, then solve gap and height simultaneously.
G3.Uheight=G3.yoke+G3.pcbThickness/2+G3.corePCBclearance;
G3.centerPath=2*(G3.Uheight-G3.yoke/2);
G3.branchPath=G3.centerPath+2*G3.pitch;
Ac=G3.leg*G3.depth*1e-6; Ao=G3.outerLeg*G3.depth*1e-6;
Ay=G3.yoke*G3.depth*1e-6;
% Centre reluctance in series with two identical return branches in parallel.
Rc=(G3.centerPath*1e-3)/(mu0*M.mui*Ac);
Rb=(G3.centerPath*1e-3)/(mu0*M.mui*Ao)+ ...
    (2*G3.pitch*1e-3)/(mu0*M.mui*Ay);
G3.Rcore=Rc+Rb/2;
% Equal physical gaps at all three mating faces. Outer gaps act in parallel.
G3.gEach_mm=(E.Np^2/E.Lm-G3.Rcore)/ ...
    ((1/(mu0*Ac)+1/(2*mu0*Ao))*(1-1/M.mui))*1e3;
G3.Uheight=G3.Uheight-G3.gEach_mm/2;
G3.centerPath=2*(G3.Uheight-G3.yoke/2);
G3.branchPath=G3.centerPath+2*G3.pitch;
Rc=G3.centerPath*1e-3/(mu0*M.mui*Ac);
Rb=G3.centerPath*1e-3/(mu0*M.mui*Ao)+2*G3.pitch*1e-3/(mu0*M.mui*Ay);
G3.Rcore=Rc+Rb/2;
G3.gTotal_mm=2*G3.gEach_mm; % centre-referred equivalent; NOT three gaps added
G3.le=G3.Rcore*mu0*M.mui*Ac*1e3;
G3.Vlegs_mm3=2*(G3.Uheight-G3.yoke)*(G3.leg+2*G3.outerLeg)*G3.depth;
G3.Vyokes_mm3=2*G3.length*G3.yoke*G3.depth;
G3.Ve_cm3=(G3.Vlegs_mm3+G3.Vyokes_mm3)/1000; % actual geometric volume
G3.Bpk_mT=G2.Bpk_mT;
G3.Byoke_mT=G3.Bpk_mT*Ac/(2*Ay);
G3.Pcore_W=Pv(ig,jg)*(G3.Vlegs_mm3+ ...
    G3.Vyokes_mm3*(Ac/(2*Ay))^M.beta)*1e-9;
G3.Pwinding_W=G2.Pwinding_W;
G3.Ptotal_W=G3.Pcore_W+G3.Pwinding_W;
G3.returnLegClearance=G3.leg/2+G3.window- ...
    max(G3.primaryOuterSide,G3.secondaryOuterSide)/2;
assert(abs(2*Ao-Ac)<1e-12 && G3.gEach_mm>0 && G3.returnLegClearance>=W.coreClearance_mm);
fprintf('\nScheme C EE: overall %.1f x %.1f mm; one E height %.1f mm\n',G3.length,G3.depth,G3.Uheight);
fprintf('Centre %.1f x %.1f; outer legs EACH %.1f x %.1f; windows EACH %.1f mm\n', ...
    G3.leg,G3.depth,G3.outerLeg,G3.depth,G3.window);
fprintf('Gap EACH of three faces %.4f mm; equivalent centre-referred total %.4f mm\n',G3.gEach_mm,G3.gTotal_mm);
fprintf('Equivalent le %.2f mm; actual volume %.3f cm3; core/winding/total %.3f/%.3f/%.3f W\n', ...
    G3.le,G3.Ve_cm3,G3.Pcore_W,G3.Pwinding_W,G3.Ptotal_W);
fprintf('EE loss assumes equal flux division and uniform regional B; junction/fringing loss requires FEA.\n');

figEE=figure('Color','w','Position',[60 50 1450 760]);
annotation(figEE,'textbox',[.05 .87 .90 .11],'String', ...
    {sprintf('C - TPG33 EE, %.0f W / %.0f kHz; Np:Ns=36:3; Lm=2.3 mH',E.Pout,E.fs/1e3), ...
    sprintf('Centre 24x24 mm; outer legs 12x24 mm each; gap %.4f mm at each joint',G3.gEach_mm), ...
    'PCB surface to inner yoke face: 1.000 mm; AUX L4+L5 1T+1T, 100 mA, 0.20 mm trace'}, ...
    'EdgeColor','none','HorizontalAlignment','center','FontSize',12,'Interpreter','none');
ax=axes('Parent',figEE,'Position',[.05 .12 .40 .61]); drawEEplan(ax,G3,W,pPitch_mm,sPitch_mm,coreGray);
ax=axes('Parent',figEE,'Position',[.54 .12 .41 .61]); hold(ax,'on');axis(ax,'equal');axis(ax,'off');
L=G3.length; h=G3.Uheight; t=G3.yoke; st=h-t; gh=G3.gEach_mm/2;
for signZ=[-1 1]
    if signZ==1, yz=gh+st; lz=gh; else, yz=-gh-h; lz=-gh-st;end
    rectangle(ax,'Position',[-L/2 yz L t],'LineWidth',1.6,'FaceColor',coreGray);
    for b=[-L/2 G3.outerLeg; -G3.leg/2 G3.leg; L/2-G3.outerLeg G3.outerLeg]'
        rectangle(ax,'Position',[b(1) lz b(2) st],'LineWidth',1.6,'FaceColor',coreGray);
    end
end
rectangle(ax,'Position',[-L/2-3 -G3.pcbThickness/2 L+6 G3.pcbThickness],'LineStyle',':');
dimVfb(ax,G3.pcbThickness/2,gh+st,0,'1.000 mm');
dimHfb(ax,-L/2,L/2,-h-8,sprintf('Overall %.1f mm',L));
dimVfb(ax,-h-gh,h+gh,L/2+8,sprintf('Assembly %.3f mm',2*h+2*gh));
title(ax,{'EE side assembly',sprintf('One E height %.3f mm; yoke %.1f mm',h,t)},'FontSize',11);
xlim(ax,[-L/2-8 L/2+18]);ylim(ax,[-h-13 h+8]);
exportgraphics(figEE,fullfile(outDir,'Flyback_TPG33_EE_scheme_C_2D.png'),'Resolution',220);

% Retain A/B figure; add a new three-scheme comparison with the existing views.
figABC=figure('Color','w','Position',[20 30 1800 1000]);
tABC=tiledlayout(figABC,2,3,'Padding','loose','TileSpacing','loose');
oldAxes=findobj(figCmp,'Type','axes');
for k=1:numel(oldAxes)
    src=oldAxes(k); tile=src.Layout.Tile;
    dst=copyobj(src,tABC); mapping=[1 2 4 5]; dst.Layout.Tile=mapping(tile);
end
ax=nexttile(tABC,3);drawEEplan(ax,G3,W,pPitch_mm,sPitch_mm,coreGray);
ax=nexttile(tABC,6);hold(ax,'on');axis(ax,'off');axis(ax,[0 100 0 9]);
for k=1:8
    y=9-k;plot(ax,[5 95],[y y],'Color',[.7 .7 .7]);text(ax,1,y,sprintf('L%d',k));
    if ismember(k,W.primaryLayerIds),plot(ax,[30 70],[y y],'r','LineWidth',6);end
    if ismember(k,W.secondaryLayerIds),plot(ax,[30 70],[y y],'b','LineWidth',6);end
    if ismember(k,W.auxLayerIds),plot(ax,[30 70],[y y],'Color',[0 .55 .2],'LineWidth',6);text(ax,73,y,'AUX 1T');end
end
title(ax,{'C - same winding stack as B, on EE centre leg', ...
    sprintf('P-S vertical copper separation %.3f mm',G3.verticalPS_mm)});
text(ax,50,.35,sprintf('Estimated core/winding loss %.3f / %.3f W',G3.Pcore_W,G3.Pwinding_W),'HorizontalAlignment','center');
title(tABC,{'Flyback A: split-leg UU | B: stacked UU | C: centre-wound EE', ...
    '36:3:2 turns; 2.3 mH; P L2/L3; S L6/L7; AUX L4+L5 series 1T+1T, 100 mA, 0.20 mm'});
exportgraphics(figABC,fullfile(outDir,'Flyback_TPG33_three_winding_schemes_2D.png'),'Resolution',200);

% Verify clearances and target Lm for the three new heights.
for geom={G,G2,G3}
    q=geom{1}; yoke=q.leg;
    if isfield(q,'yoke'), yoke=q.yoke; end
    assert(abs(q.Uheight-yoke+q.gEach_mm/2-q.pcbThickness/2-1)<1e-9);
end
LmEE=E.Np^2/(G3.Rcore+G3.gEach_mm*1e-3*(1/(mu0*Ac)+1/(2*mu0*Ao)));
assert(abs(LmEE/E.Lm-1)<1e-9);
fprintf('1 mm clearance verified: A/B/C single-half heights %.6f / %.6f / %.6f mm\n', ...
    G.Uheight,G2.Uheight,G3.Uheight);

function G=lowProfileUU(G,E,M,mu0)
h0=G.leg+G.pcbThickness/2+G.corePCBclearance;
le0=2*(G.legPitch+2*(h0-G.leg/2))*1e-3;
A=G.leg*G.depth*1e-6;
g=(mu0*A*E.Np^2/E.Lm-le0/M.mui)/(2*(1-1/M.mui));
G.gEach_mm=g*1e3;G.gTotal_mm=2*G.gEach_mm;
G.Uheight=h0-G.gEach_mm/2;
assert(g>0);
end

function drawEEplan(ax,G,W,pPitch,sPitch,coreFill)
if nargin<6, coreFill=[.65 .65 .65]; end
hold(ax,'on');axis(ax,'equal');axis(ax,'off');
rectangle(ax,'Position',[-G.length/2 -G.depth/2 G.length G.depth],'LineWidth',1.6,'FaceColor',coreFill);
for b=[-G.length/2 G.outerLeg;-G.leg/2 G.leg;G.length/2-G.outerLeg G.outerLeg]'
    rectangle(ax,'Position',[b(1) -.5*G.depth b(2) G.depth],'LineStyle','--','LineWidth',1.3);
end
for k=1:W.secondaryTurnsPerLayer
    s=G.leg+2*(W.coreClearance_mm+W.secondaryWidth_mm/2+(k-1)*sPitch);
    rectangle(ax,'Position',[-s/2 -s/2 s s],'EdgeColor',[.04 .28 .8],'LineWidth',1.6);
end
for k=1:W.primaryTurnsPerLayer
    s=G.leg+2*(W.coreClearance_mm+W.primaryWidth_mm/2+(k-1)*pPitch);
    rectangle(ax,'Position',[-s/2 -s/2 s s],'EdgeColor',[.78 .1 .06],'LineStyle','--');
end
drawAuxPlan(ax,0,G,W);
dimHfb(ax,-G.length/2,G.length/2,-34,sprintf('EE overall %.0f mm',G.length));
dimHfb(ax,-G.leg/2,G.leg/2,30,sprintf('Centre %.0f mm',G.leg));
title(ax,{'C - primary above secondary on EE centre leg', ...
    sprintf('Outer legs %.0f mm each; windows %.0f mm each',G.outerLeg,G.window)});
xlim(ax,[-G.length/2-8 G.length/2+8]);ylim(ax,[-40 36]);
end

function drawAuxPlan(ax,cx,G,W)
% One representative centre-line; the identical L4/L5 loops overlap in plan.
side=G.leg+2*W.auxOffset_mm;
rectangle(ax,'Position',[cx-side/2 -side/2 side side], ...
    'EdgeColor',[0 .55 .2],'LineWidth',2,'LineStyle','-.');
end

function dimHfb(ax,x1,x2,y,label)
plot(ax,[x1 x2],[y y],'k-');
plot(ax,x1,y,'k>','MarkerFaceColor','k','MarkerSize',4);
plot(ax,x2,y,'k<','MarkerFaceColor','k','MarkerSize',4);
text(ax,(x1+x2)/2,y+0.8,label,'HorizontalAlignment','center','FontSize',9);
end

function dimVfb(ax,y1,y2,x,label)
plot(ax,[x x],[y1 y2],'k-');
plot(ax,x,y1,'k^','MarkerFaceColor','k','MarkerSize',4);
plot(ax,x,y2,'kv','MarkerFaceColor','k','MarkerSize',4);
text(ax,x+1,(y1+y2)/2,label,'Rotation',90, ...
    'HorizontalAlignment','center','FontSize',9);
end

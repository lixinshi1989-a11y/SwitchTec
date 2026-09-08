%% LLC planar transformer magnetic redesign
% 36 V half bridge -> 24 V / 30 W, 800 kHz
% DMR53, Np=3, four identical Ns=4 output windings, 30 W total
% Target magnetising inductance 6.5 uH and primary-referred leakage 1 uH.
clear; clc; close all;

%% Confirmed electrical requirements
E.Vin=36; E.Vout=24; E.Pout=30; E.f=800e3;
E.Np=3; E.Ns=4; E.Nsec=4;
E.PoutEach=E.Pout/E.Nsec;        % 7.5 W per output for equal sharing
E.IoutEach=E.PoutEach/E.Vout;    % 0.3125 A per output
E.LmReference=6.5e-6; E.Llk=1e-6; E.eta=0.90;
E.Vpri=E.Vin/2;                 % half-bridge square-wave level
E.n=E.Np/E.Ns;
E.Cr=1/((2*pi*E.f)^2*E.Llk);

%% DMR53 material model
% Datasheet anchor: 70 mW/cm^3 at 1 MHz, 50 mT (25 and 100 degC typical).
% Exponents are local engineering assumptions until full loss data are fitted.
M.mui=900; M.mui_tol=0.25;
M.Pref=70e3; M.fref=1e6; M.Bref=50e-3;
M.alpha=1.5; M.beta=2.5;
M.Bdesign=30e-3; M.Blimit=50e-3;

%% Selected first-prototype UU core geometry
% Np=3 uses the selected cross-section to obtain 6.5 uH with a positive gap.
% Planar windings lie in the PCB X-Y planes. U height is therefore set by
% yoke/leg mechanics and PCB thickness, not by stacking four traces vertically.
% The original physical gap is retained.  Shorten each U half so that the
% inner yoke face is exactly 1.0 mm from the nearest PCB surface.
C.length=36e-3; C.leg=10e-3; C.depth=10e-3;
C.PCBthickness=3.245e-3;
C.gapEachJoint=0.052554e-3;
C.coreToPCBSurface=1.0e-3;
C.Uheight=C.leg+C.PCBthickness/2+C.coreToPCBSurface-C.gapEachJoint/2;
C.Ae=C.leg*C.depth;             % 100 mm^2
C.legPitch=C.length-C.leg;      % 24 mm
C.windowBetweenLegs=C.length-2*C.leg; % 18 mm
C.clearLegLength=C.Uheight-C.leg;
C.le=2*(C.legPitch+2*(C.Uheight-C.leg/2));
C.referenceUheight=15e-3;
C.leReference=2*(C.legPitch+2*(C.referenceUheight-C.leg/2));
C.Ve=C.Ae*C.le;
C.slot=10.6e-3;

%% Flux, loss and air gap
mu0=4*pi*1e-7;
Bpk=E.Vpri/(4*E.f*E.Np*C.Ae);
Pv=M.Pref*(E.f/M.fref)^M.alpha*(Bpk/M.Bref)^M.beta;
Pcore=Pv*C.Ve;
gTotal=2*C.gapEachJoint;
E.Lm=E.LmReference*(gTotal+C.leReference/M.mui)/(gTotal+C.le/M.mui);
E.Ln=E.Lm/E.Llk;
AL=E.Lm/E.Np^2;
muiCorners=M.mui*[0.75 1 1.25];
LmCorners=E.LmReference*(gTotal+C.leReference/M.mui)./ ...
    (gTotal+C.le./muiCorners);

%% Leakage requirement and measurement definition
% Lopen ~= Lm + Llk; Lsc = Lopen*(1-k^2).
Lopen=E.Lm+E.Llk;
kTarget=sqrt(1-E.Llk/Lopen);
LsecOpen=Lopen*(E.Ns/E.Np)^2;
Mtarget=kTarget*sqrt(Lopen*LsecOpen);

%% Actual PCB stack and planar winding allocation
P.cu=[69 64 64 64 64 64 64 69]*1e-6;
P.diel=[.346 .406 .393 .406 .406 .406 .360]*1e-3;
P.thickness=sum(P.cu)+sum(P.diel);
assert(abs(P.thickness-C.PCBthickness)<1e-12,'PCB thickness mismatch in core-height calculation.');
% Each nonzero entry is the number of IN-PLANE spiral turns on that layer.
% Two identical 3-turn primary spirals are paralleled on L2/L3.
P.NpTurnsByLayer=[0 3 3 0 0 0 0 0];
P.NpParallel=sum(P.NpTurnsByLayer>0);
% Four independent 4-turn outputs occupy L2/L3/L6/L7 on the opposite leg.
P.NsTurnsByLayer=[0 4 4 0 0 4 4 0];
assert(sum(P.NsTurnsByLayer>0)==E.Nsec,'Need one planar layer per secondary.');
P.wp=1.20e-3; P.ws=0.70e-3; P.spacing=0.20e-3;
P.primarySecondaryClearance=2.0e-3; % minimum lateral P-S copper clearance
P.primaryRadial=E.Np*P.wp+(E.Np-1)*P.spacing;
P.secondaryRadial=E.Ns*P.ws+(E.Ns-1)*P.spacing;
P.availablePlanar=(C.legPitch-C.leg)/2; % half the edge-to-edge leg spacing
P.clearance=2.0e-3;              % copper edge to core-slot edge, production rule
P.MLTp=4*(C.leg+2*P.clearance+P.primaryRadial); % rough closed-loop mean only
P.MLTs=4*(C.leg+2*P.clearance+P.secondaryRadial); % actual loss uses routed lengths
P.actualPSClearance=(C.legPitch-C.leg)-2*P.clearance- ...
    P.primaryRadial-P.secondaryRadial;

rho=1.724e-8; delta=sqrt(rho/(pi*E.f*mu0));
R=llc_routing_metrics(E,C,P,rho);
RpCoils=R.pBuried; Rpdc=R.pEquivalent; RsCoils=R.sTotal; RsEach=mean(RsCoils);
Iin=E.Pout/(E.Vin*E.eta); Iout=E.Pout/E.Vout; % DC supply values only
IpRms=R.IpRms; IsRms=R.IsRms;
FacP=1.5; FacS=1.7; % assumed AC resistance factors, awaiting field solution
PsecDC=IsRms^2*sum(RsCoils);
PcuDC=IpRms^2*Rpdc+PsecDC; % RMS currents with DC resistance
PpriACest=IpRms^2*Rpdc*FacP;
PsecACest=IsRms^2*sum(RsCoils)*FacS;
PcuACest=PpriACest+PsecACest;
PmagEst=Pcore+PcuACest;
fprintf('Primary shared L1 leads + solid-via estimated loss: %.4f W\n',IpRms^2*R.pCommon*FacP);

%% Layer-by-layer winding schedule
% Primary rows exclude shared L1/via loss reported separately.
% Secondary rows attribute the complete output path to its winding layer.
layerName="L"+(1:8)';
role=repmat("Unused/routing",8,1);
pTurns=zeros(8,1); sTurns=zeros(8,1); pCurrent=zeros(8,1); sCurrent=zeros(8,1);
pRdc=zeros(8,1); sRdc=zeros(8,1); pLoss=zeros(8,1); sLoss=zeros(8,1);
pLayers=find(P.NpTurnsByLayer>0);
for k=1:numel(pLayers)
    q=pLayers(k); role(q)=sprintf('Primary P%d (parallel)',k);
    pTurns(q)=P.NpTurnsByLayer(q); pCurrent(q)=IpRms/P.NpParallel;
    pRdc(q)=RpCoils(k);
    pLoss(q)=pCurrent(q)^2*pRdc(q)*FacP;
end
sLayers=find(P.NsTurnsByLayer>0);
for k=1:numel(sLayers)
    q=sLayers(k);
    if role(q)=="Unused/routing"
        role(q)=sprintf('Output S%d',k);
    else
        role(q)=role(q)+sprintf(' + Output S%d',k);
    end
    sTurns(q)=P.NsTurnsByLayer(q); sCurrent(q)=IsRms;
    sRdc(q)=RsCoils(k); % complete output path including surface leads and vias
    sLoss(q)=sCurrent(q)^2*sRdc(q)*FacS;
end
layerTable=table(layerName,role,P.cu(:)*1e3,pTurns,P.wp*1e3*(pTurns>0), ...
    pCurrent,pRdc,pLoss,sTurns,P.ws*1e3*(sTurns>0),sCurrent,sRdc,sLoss, ...
    'VariableNames',{'Layer','Assignment','Copper_mm','PrimaryTurns','PrimaryWidth_mm', ...
    'PrimaryCurrent_A','PrimaryRdc_ohm','PrimaryACLoss_W','SecondaryTurns', ...
    'SecondaryWidth_mm','SecondaryCurrent_A','SecondaryRdc_ohm','SecondaryACLoss_W'});

%% 2-D scan: square leg side versus complete core length
Scan.legSide_mm=6:0.1:14;
Scan.coreLength_mm=28:0.5:50;
Scan.Uheight_mm=C.Uheight*1e3;   % separately adjustable fixed U height
[COREmm,LEGmm]=meshgrid(Scan.coreLength_mm,Scan.legSide_mm);
AEscan=(LEGmm*1e-3).^2;
Hscan=LEGmm+P.thickness*0.5e3+C.coreToPCBSurface*1e3-C.gapEachJoint*0.5e3;
LEscan=2*((COREmm-LEGmm)+2*(Hscan-LEGmm/2))*1e-3;
VEscan=AEscan.*LEscan;
Bscan=E.Vpri./(4*E.f*E.Np.*AEscan);
Pvscan=M.Pref*(E.f/M.fref)^M.alpha.*(Bscan/M.Bref).^M.beta;
PcoreScan=Pvscan.*VEscan;
% Fixed physical gap for the actual sweep; estimated Lm varies with Ae/le.
gScan=gTotal*ones(size(AEscan));
LmScan=E.Lm*(AEscan/C.Ae).*(gTotal+C.le/M.mui)./(gTotal+LEscan/M.mui);
windowScan=COREmm-2*LEGmm;
valid=Bscan<=M.Blimit & gScan>=0.03e-3 & gScan<=0.40e-3 & ...
      windowScan>=12 & LEGmm<Hscan;

% Geometry-dependent winding-loss estimate. Each coil is an in-plane spiral.
% Use the same copper-to-core production clearance as the selected design.
clearance_mm=P.clearance*1e3;
% Local length scaling from the selected routed design; not a PCB autorouter.
MLTpScan=(mean(RpCoils)*P.wp*mean(P.cu(P.NpTurnsByLayer>0))/rho/E.Np)+4*(LEGmm-C.leg*1e3)*1e-3;
MLTsScan=(mean(RsCoils)*P.ws*mean(P.cu(P.NsTurnsByLayer>0))/rho/E.Ns)+4*(LEGmm-C.leg*1e3)*1e-3;
tP=mean(P.cu(P.NpTurnsByLayer>0));
tS=mean(P.cu(P.NsTurnsByLayer>0));
RpEachScan=rho*E.Np.*MLTpScan/(P.wp*tP);
RpScan=RpEachScan/P.NpParallel+R.pCommon;
RsEachScan=rho*E.Ns.*MLTsScan/(P.ws*tS);
IpRmsScan=hypot(E.Nsec*IsRms/E.n,E.Vpri./(4*E.f*LmScan*sqrt(3)));
PpriWindScan=IpRmsScan.^2.*RpScan*FacP;
PsecWindScan=E.Nsec*IsRms^2.*RsEachScan*FacS;
PwindScan=PpriWindScan+PsecWindScan;
PtotalScan=PcoreScan+PwindScan;

%% Report
fprintf('\n=== RE-DESIGNED LLC MAGNETICS ===\n');
fprintf('36 V half bridge -> 24 V / 30 W, %.0f kHz\n',E.f/1e3);
fprintf('Np=%d, %d output windings x Ns=%d; estimated Lm=%.2f uH, Llk=%.2f uH, Cr=%.2f nF\n', ...
    E.Np,E.Nsec,E.Ns,E.Lm*1e6,E.Llk*1e6,E.Cr*1e9);
fprintf('Total output %.1f W; each output %.2f W, %.3f A at %.1f V\n', ...
    E.Pout,E.PoutEach,E.IoutEach,E.Vout);
fprintf('Core: top %.1f x %.1f mm, side height %.1f mm, leg %.1f x %.1f mm\n', ...
    C.length*1e3,C.depth*1e3,C.Uheight*1e3,C.leg*1e3,C.depth*1e3);
fprintf('Core-yoke to PCB-surface clearance=%.3f mm; assembled height=%.3f mm\n', ...
    C.coreToPCBSurface*1e3,(2*C.Uheight+C.gapEachJoint)*1e3);
fprintf('Ae=%.1f mm^2, le=%.1f mm, Ve=%.2f cm^3\n',C.Ae*1e6,C.le*1e3,C.Ve*1e6);
fprintf('Bpk=%.2f mT; DMR53 core-loss estimate=%.3f W\n',Bpk*1e3,Pcore);
fprintf('AL=%.1f nH/T^2; total gap=%.3f mm = %.3f mm per leg joint\n', ...
    AL*1e9,gTotal*1e3,gTotal*0.5e3);
fprintf('Lm at mui -25%%/nom/+25%%: %.2f / %.2f / %.2f uH\n',LmCorners*1e6);
fprintf('Leakage target: Lopen=%.2f uH, Lsc=%.2f uH, k=%.4f, M=%.2f uH\n', ...
    Lopen*1e6,E.Llk*1e6,kTarget,Mtarget*1e6);
fprintf('PCB=%.3f mm; skin depth=%.1f um\n',P.thickness*1e3,delta*1e6);
fprintf('Planar radial build: primary %.2f mm, each secondary %.2f mm, available %.2f mm\n', ...
    P.primaryRadial*1e3,P.secondaryRadial*1e3,P.availablePlanar*1e3);
fprintf('Trace rules: primary %.2f/%.2f mm width/spacing; secondary %.2f/%.2f mm\n', ...
    P.wp*1e3,P.spacing*1e3,P.ws*1e3,P.spacing*1e3);
fprintf('Minimum lateral primary-secondary clearance: %.2f mm\n', ...
    P.primarySecondaryClearance*1e3);
fprintf('Copper-to-core clearance: %.2f mm; actual nearest P-S copper: %.2f mm\n', ...
    P.clearance*1e3,P.actualPSClearance*1e3);
fprintf('Copper: Rpri_dc=%.3f ohm, each Rsec_dc=%.3f ohm, Pcu_dc=%.3f W\n', ...
    Rpdc,RsEach,PcuDC);
fprintf('Estimated AC winding loss: primary %.3f W + four outputs %.3f W\n', ...
    PpriACest,PsecACest);
fprintf('Estimated winding loss incl. AC factors=%.3f W\n',PcuACest);
fprintf('Estimated magnetic assembly loss (core + AC copper)=%.3f W\n',PmagEst);
fprintf('============================================================\n');
disp(layerTable);

assert(Bpk<M.Blimit,'Flux density exceeds selected 50 mT limit.');
assert(gTotal>0,'Selected core needs no positive gap; revise geometry.');
assert(max(P.primaryRadial,P.secondaryRadial)<P.availablePlanar, ...
    'Planar spiral does not fit between the two core legs.');
assert(P.primaryRadial+P.clearance<P.availablePlanar && ...
       P.secondaryRadial+P.clearance<P.availablePlanar, ...
       'Winding plus copper-to-core clearance does not fit.');
assert(P.actualPSClearance>=P.primarySecondaryClearance, ...
       'Primary-secondary lateral copper clearance is below 2 mm.');
warning(['The 1 uH leakage value requires 3-D FEA/prototype tuning. ' ...
    'Measure primary Lsc with all four secondaries phase-aligned and shorted.']);

%% Geometry scan plots
outDir=fullfile(fileparts(mfilename('fullpath')),'output'); if ~exist(outDir,'dir'), mkdir(outDir); end
writetable(layerTable,fullfile(outDir,'LLC_layer_winding_schedule.csv'));
fig=figure('Color','w','Position',[60 40 1350 950]);
tl=tiledlayout(fig,2,2,'Padding','compact','TileSpacing','compact');
title(tl,sprintf('Np=%d, %.0f kHz; core-PCB=1 mm; fixed gap %.6f mm/joint; winding loss locally scaled', ...
    E.Np,E.f/1e3,C.gapEachJoint*1e3));
geometry_lines(nexttile(tl),Scan.coreLength_mm,Scan.legSide_mm,Bscan*1e3, ...
    'B_{pk} (mT)',C.length*1e3,C.leg*1e3);
geometry_lines(nexttile(tl),Scan.coreLength_mm,Scan.legSide_mm,PcoreScan, ...
    'DMR53 core loss estimate (W)',C.length*1e3,C.leg*1e3);
geometry_lines(nexttile(tl),Scan.coreLength_mm,Scan.legSide_mm,PwindScan, ...
    'Estimated winding loss (W)',C.length*1e3,C.leg*1e3);
geometry_lines(nexttile(tl),Scan.coreLength_mm,Scan.legSide_mm,PtotalScan, ...
    'Core + winding loss estimate (W)',C.length*1e3,C.leg*1e3);
exportgraphics(fig,fullfile(outDir,'LLC_geometry_scan_lines_L2L3.png'),'Resolution',220);

%% Inductance, required gap and volume comparison (separate three-panel figure)
Scan.LmFixed=E.Lm; % editable fixed-Lm target; default: selected estimated Lm
% Same calibrated reluctance model as LmScan. Changing gap also changes U
% height to preserve the 1 mm surface clearance: le = leBase - totalGap.
leBase=LEscan+gTotal;
calibratedK=E.Lm*(gTotal+C.le/M.mui)/C.Ae;
gFixedLm=(calibratedK*AEscan/Scan.LmFixed-leBase/M.mui)/(1-1/M.mui);
HfixedLm=LEGmm*1e-3+P.thickness/2+C.coreToPCBSurface-gFixedLm/4;
gapFeasible=gFixedLm>=0 & HfixedLm>LEGmm*1e-3 & windowScan>0;
gapPlot=gFixedLm*0.5e3; % each joint, not total series magnetic gap
gapPlot(~gapFeasible)=NaN;
figL=figure('Color','w','Position',[40 80 1650 560]);
tlL=tiledlayout(figL,1,3,'Padding','compact','TileSpacing','compact');
title(tlL,{sprintf('Np=%d; core-PCB=1 mm; fixed-gap and fixed-Lm comparison (estimated)',E.Np), ...
    'Gap shown = gap per joint = total magnetic gap / 2'},'FontSize',12);
geometry_lines(nexttile(tlL),Scan.coreLength_mm,Scan.legSide_mm,LmScan*1e6, ...
    'Estimated L_m at fixed gap (uH)',C.length*1e3,C.leg*1e3);
geometry_lines(nexttile(tlL),Scan.coreLength_mm,Scan.legSide_mm,gapPlot, ...
    sprintf('Gap per joint = total gap / 2 (mm)\nFixed L_m=%.3f uH',Scan.LmFixed*1e6),C.length*1e3,C.leg*1e3);
geometry_lines(nexttile(tlL),Scan.coreLength_mm,Scan.legSide_mm,VEscan*1e6, ...
    'Effective core volume at fixed gap (cm^3)',C.length*1e3,C.leg*1e3);
exportgraphics(figL,fullfile(outDir,'LLC_Lm_gap_volume_scan.png'),'Resolution',220);
gapTable=table(COREmm(:),LEGmm(:),LmScan(:)*1e6,gFixedLm(:)*1e3, ...
    gFixedLm(:)*0.5e3,HfixedLm(:)*1e3,VEscan(:)*1e6,gapFeasible(:), ...
    'VariableNames',{'CoreLength_mm','LegSide_mm','EstimatedLmAtFixedGap_uH', ...
    'TotalGapAtFixedLm_mm','EachJointGapAtFixedLm_mm','UheightAtFixedLm_mm', ...
    'VolumeAtFixedGap_cm3','NonnegativeGapGeometry'});
writetable(gapTable,fullfile(outDir,'LLC_Lm_gap_volume_scan.csv'));

T=table(COREmm(:),LEGmm(:),AEscan(:)*1e6,LEscan(:)*1e3,VEscan(:)*1e6, ...
    Bscan(:)*1e3,PcoreScan(:),PpriWindScan(:),PsecWindScan(:),PwindScan(:), ...
    PtotalScan(:),gScan(:)*1e3,windowScan(:),valid(:),Hscan(:),LmScan(:)*1e6, ...
    'VariableNames',{'CoreLength_mm','LegSide_mm','Ae_mm2','le_mm','Ve_cm3', ...
    'Bpk_mT','CoreLoss_W','PrimaryWindingLoss_W','SecondaryWindingLoss_W', ...
    'TotalWindingLoss_W','CorePlusWindingLoss_W','TotalGap_mm', ...
    'WindowBetweenLegs_mm','Valid','Uheight_mm','EstimatedLm_uH'});
writetable(T,fullfile(outDir,'LLC_geometry_scan.csv'));

fprintf('Geometry scan PNG: %s\n',fullfile(outDir,'LLC_geometry_scan_lines_L2L3.png'));
fprintf('Geometry scan CSV: %s\n',fullfile(outDir,'LLC_geometry_scan.csv'));

%% Dimension drawing of selected Np=3 core
figD=figure('Color','w','Position',[80 80 1400 760]);
annotation(figD,'textbox',[0.05 0.88 0.90 0.10],'String', ...
    {sprintf('Np:Ns=3:4 | Estimated Lm=%.2f uH | Trace P/S=1.2/0.7 mm',E.Lm*1e6), ...
    sprintf('Gap per joint = total gap / 2 = %.6f mm | Total gap = %.6f mm',C.gapEachJoint*1e3,gTotal*1e3)}, ...
    'FontSize',12,'Interpreter','none','EdgeColor','none','HorizontalAlignment','center');
coreColor=[0.24 0.27 0.30]; pcbColor=[0.60 0.78 0.30];

% Top view: upper/lower U-core yokes overlap in projection.
ax1=axes('Parent',figD,'Position',[0.05 0.12 0.40 0.63]); hold(ax1,'on'); axis(ax1,'equal');
axis(ax1,[-6 C.length*1e3+6 -8 18]); axis(ax1,'off');
rectangle(ax1,'Position',[-3 -3 C.length*1e3+6 16], ...
    'FaceColor',pcbColor,'FaceAlpha',0.30,'EdgeColor',[0.2 0.5 0.1]);
rectangle(ax1,'Position',[0 0 C.length*1e3 C.depth*1e3], ...
    'FaceColor',coreColor,'EdgeColor','k','LineWidth',1.5);
cx=[C.leg*0.5, C.length-C.leg*0.5]*1e3; cy=C.depth*0.5e3;
for k=1:2
    rectangle(ax1,'Position',[cx(k)-C.slot*0.5e3 cy-C.slot*0.5e3 C.slot*1e3 C.slot*1e3], ...
        'EdgeColor',[0.9 0.25 0.12],'LineStyle','--','LineWidth',1.5);
end
dimH(ax1,0,C.length*1e3,-5,sprintf('Overall %.1f',C.length*1e3));
dimV(ax1,0,C.depth*1e3,C.length*1e3+3,sprintf('%.1f',C.depth*1e3));
dimH(ax1,cx(1),cx(2),13,sprintf('Leg pitch %.1f',C.legPitch*1e3));
text(ax1,C.length*0.5e3,cy,'TOP U YOKE','Color','w','FontWeight','bold','HorizontalAlignment','center');
text(ax1,C.length*0.5e3,16,sprintf('PCB slots: 2x %.1f x %.1f',C.slot*1e3,C.slot*1e3), ...
    'HorizontalAlignment','center');
title(ax1,'Top view: 36 x 10');

% Side view: two U halves face each other through PCB slots.
ax2=axes('Parent',figD,'Position',[0.54 0.12 0.41 0.63]); hold(ax2,'on'); axis(ax2,'equal');
axis(ax2,[-8 C.length*1e3+14 -26 20]); axis(ax2,'off');
L=C.length*1e3; h=C.Uheight*1e3; a=C.leg*1e3; stem=h-a;
gh=C.gapEachJoint*0.5e3; pcbHalf=P.thickness*0.5e3;
rectangle(ax2,'Position',[-3 -P.thickness*0.5e3 L+6 P.thickness*1e3], ...
    'FaceColor',pcbColor,'FaceAlpha',0.48,'EdgeColor',[0.2 0.5 0.1]);
rectangle(ax2,'Position',[0 gh+stem L a],'FaceColor',coreColor,'EdgeColor','k');
rectangle(ax2,'Position',[0 gh a stem],'FaceColor',coreColor,'EdgeColor','k');
rectangle(ax2,'Position',[L-a gh a stem],'FaceColor',coreColor,'EdgeColor','k');
rectangle(ax2,'Position',[0 -gh-h L a],'FaceColor',coreColor,'EdgeColor','k');
rectangle(ax2,'Position',[0 -gh-stem a stem],'FaceColor',coreColor,'EdgeColor','k');
rectangle(ax2,'Position',[L-a -gh-stem a stem],'FaceColor',coreColor,'EdgeColor','k');
dimH(ax2,0,L,-23,sprintf('Overall %.1f',L));
dimV(ax2,gh,gh+h,L+3,sprintf('One U height %.3f',h));
dimV(ax2,-P.thickness*0.5e3,P.thickness*0.5e3,-4.5,sprintf('PCB %.3f',P.thickness*1e3));
text(ax2,L/2,gh+h-a/2,'UPPER U','Color','w','FontWeight','bold','HorizontalAlignment','center');
text(ax2,L/2,-gh-h+a/2,'LOWER U','Color','w','FontWeight','bold','HorizontalAlignment','center');
dimV(ax2,pcbHalf,gh+stem,L+8,sprintf('Yoke-PCB %.3f',C.coreToPCBSurface*1e3));
text(ax2,L/2,-h-gh-4,sprintf('Leg %.1f x %.1f mm',a,C.depth*1e3), ...
    'HorizontalAlignment','center','FontSize',10);
title(ax2,{'Side view: upper/lower U assembly', ...
    'Core-yoke to PCB surface = 1.000 mm'},'FontSize',11);

selectedFile=fullfile(outDir,'LLC_selected_Np3_planar_core_dimensions_L2L3.png');
exportgraphics(figD,selectedFile,'Resolution',240);
fprintf('Selected core drawing: %s\n',selectedFile);

function geometry_lines(ax,coreLength,legSide,z,ttl,xSel,ySel)
% Plot selected core lengths as line families versus square leg side.
nShow=7;
idx=unique([round(linspace(1,numel(coreLength),nShow)), ...
    find(abs(coreLength-xSel)==min(abs(coreLength-xSel)),1)]);
colors=lines(numel(idx)); hold(ax,'on');
for k=1:numel(idx)
    plot(ax,legSide,z(:,idx(k)),'LineWidth',1.6,'Color',colors(k,:), ...
        'DisplayName',sprintf('Core L = %.1f mm',coreLength(idx(k))));
end

[~,ix]=min(abs(coreLength-xSel)); [~,iy]=min(abs(legSide-ySel));
plot(ax,legSide(iy),z(iy,ix),'rp','MarkerFaceColor','r','MarkerSize',12, ...
    'DisplayName',sprintf('Selected %.0f/%.0f mm',xSel,ySel));
xlabel(ax,'Square leg side (mm)'); ylabel(ax,ttl); title(ax,ttl); grid(ax,'on');
legend(ax,'Location','best','FontSize',7);
end

function dimH(ax,x1,x2,y,label)
plot(ax,[x1 x2],[y y],'k-'); plot(ax,x1,y,'k>','MarkerFaceColor','k','MarkerSize',4);
plot(ax,x2,y,'k<','MarkerFaceColor','k','MarkerSize',4);
text(ax,(x1+x2)/2,y+0.6,label,'HorizontalAlignment','center','FontSize',9);
end

function dimV(ax,y1,y2,x,label)
plot(ax,[x x],[y1 y2],'k-'); plot(ax,x,y1,'k^','MarkerFaceColor','k','MarkerSize',4);
plot(ax,x,y2,'kv','MarkerFaceColor','k','MarkerSize',4);
text(ax,x+0.7,(y1+y2)/2,label,'Rotation',90,'HorizontalAlignment','center','FontSize',9);
end

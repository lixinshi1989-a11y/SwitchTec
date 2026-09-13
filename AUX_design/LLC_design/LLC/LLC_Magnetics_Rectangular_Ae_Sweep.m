%% LLC planar transformer - rectangular centre-leg area sweep
% 36 V half bridge -> 24 V / 30 W, 800 kHz
% This study keeps the centre-leg depth/height ratio fixed at 12/8 and uses
% effective centre-leg area Ae, rather than square-leg side, as the sweep axis.
clear; clc; close all;

%% Electrical requirements
E.Vin=36; E.Vout=24; E.Pout=30; E.f=800e3;
E.Np=3; E.Ns=4; E.Nsec=4;
E.LmTarget=6.5e-6; E.LlkTarget=1e-6;
E.Vpri=E.Vin/2;
P.wp=1.20e-3; P.ws=0.70e-3; P.spacing=0.20e-3;
P.clearance=2.0e-3;

%% DMR53 local loss fit near 1 MHz / 80 degC
% Pv [W/m^3] = Cm*f[Hz]^X*B[T]^Y.
M.mui=900; M.mui_tol=0.25;
M.X=log(300/70)/log(2); M.Y=2.8;
M.Cm=(70e3)/(1e6^M.X*(50e-3)^M.Y);
M.Blimit=50e-3;

%% Selected rectangular UU-core geometry
% The original 10 x 10 mm square section is replaced by an 8 x 12 mm
% rectangular section. The 8 mm dimension sets the yoke/assembly height;
% the 12 mm dimension is the extrusion depth. Ae is therefore 96 mm^2.
C.length=36e-3;
C.legHeight=8e-3;
C.legDepth=12e-3;
C.aspectRatio=C.legDepth/C.legHeight;
C.Ae=C.legHeight*C.legDepth;
C.PCBthickness=3.245e-3;
C.gapEachJoint=0.052554e-3;
C.coreToPCBSurface=1.0e-3;
C.Uheight=C.legHeight+C.PCBthickness/2+C.coreToPCBSurface- ...
    C.gapEachJoint/2;
C.legPitch=C.length-C.legHeight;
C.windowBetweenLegs=C.length-2*C.legHeight;
C.le=2*(C.legPitch+2*(C.Uheight-C.legHeight/2));
C.Ve=C.Ae*C.le;
C.slotAlongLength=C.legHeight+0.6e-3;
C.slotAcrossDepth=C.legDepth+0.6e-3;

% Calibration reference: previous 10 x 10 mm, 15 mm-high U-core design.
Ref.length=36e-3;
Ref.legHeight=10e-3;
Ref.legDepth=10e-3;
Ref.Ae=Ref.legHeight*Ref.legDepth;
Ref.Uheight=15e-3;
Ref.legPitch=Ref.length-Ref.legHeight;
Ref.le=2*(Ref.legPitch+2*(Ref.Uheight-Ref.legHeight/2));

%% Selected-point magnetic results
mu0=4*pi*1e-7;
gTotal=2*C.gapEachJoint;
% Calibrated reluctance constant: Lm = Kcal*Ae/(g + le/mui).
Kcal=E.LmTarget*(gTotal+Ref.le/M.mui)/Ref.Ae;
E.Lm=Kcal*C.Ae/(gTotal+C.le/M.mui);
Bpk=E.Vpri/(4*E.f*E.Np*C.Ae);
Pv=M.Cm*E.f^M.X*Bpk^M.Y;
Pcore=Pv*C.Ve;
assembledHeight=2*C.Uheight+C.gapEachJoint;

muiCorners=M.mui*[0.75 1 1.25];
LmCorners=Kcal*C.Ae./(gTotal+C.le./muiCorners);

%% Direct geometry-based leakage estimate, referred to the primary
% The windings surround different core legs.  The leakage-field region is
% therefore set by their centre-to-centre spacing dc, not by the nearest
% copper-edge clearance.  The side-by-side current-sheet approximation is
%
% Llk,p = mu0*Np^2*lw/bw * (dc + (xp+xs)/3).
%
% This is a direct geometry equation, not an energy or AEDT-matrix result.
% It includes the winding builds but omits the remaining 2-D/3-D fringing.
P.primaryPitch=P.wp+P.spacing;
P.secondaryPitch=P.ws+P.spacing;
P.primaryBuild=E.Np*P.wp+(E.Np-1)*P.spacing;
P.secondaryBuild=E.Ns*P.ws+(E.Ns-1)*P.spacing;
P.sectionGap=C.windowBetweenLegs-2*P.clearance- ...
    P.primaryBuild-P.secondaryBuild;
pIndex=0:E.Np-1;
sIndex=0:E.Ns-1;
pHalfX=C.legHeight/2+P.clearance+P.wp/2+pIndex*P.primaryPitch;
pHalfY=C.legDepth/2+P.clearance+P.wp/2+pIndex*P.primaryPitch;
sHalfX=C.legHeight/2+P.clearance+P.ws/2+sIndex*P.secondaryPitch;
sHalfY=C.legDepth/2+P.clearance+P.ws/2+sIndex*P.secondaryPitch;
P.primaryMLT=mean(4*(pHalfX+pHalfY));
P.secondaryMLT=mean(4*(sHalfX+sHalfY));
P.meanMLT=0.5*(P.primaryMLT+P.secondaryMLT);
P.primaryBreadth=2*(C.legDepth/2+P.clearance+P.wp+ ...
    (E.Np-1)*P.primaryPitch);
P.secondaryBreadth=2*(C.legDepth/2+P.clearance+P.ws+ ...
    (E.Ns-1)*P.secondaryPitch);
P.effectiveBreadth=min(P.primaryBreadth,P.secondaryBreadth);
P.windingCentreSpacing=C.legPitch;
E.LlkGeometry=mu0*E.Np^2*P.meanMLT/P.effectiveBreadth* ...
    (P.windingCentreSpacing+(P.primaryBuild+P.secondaryBuild)/3);
E.CrGeometry=1/((2*pi*E.f)^2*E.LlkGeometry);
E.LnGeometry=E.Lm/E.LlkGeometry;

%% Sweep nearest primary-secondary copper distance
% Vary the core/winding centre spacing while keeping the 8 x 12 mm leg,
% trace widths, trace spacing and copper-to-core clearances unchanged.
DistanceScan.PSCopperGap_mm=2:0.1:14;
fixedLateral_mm=(C.legHeight+2*P.clearance+ ...
    P.primaryBuild+P.secondaryBuild)*1e3;
DistanceScan.WindingCentreSpacing_mm= ...
    DistanceScan.PSCopperGap_mm+fixedLateral_mm;
DistanceScan.CoreLength_mm=DistanceScan.WindingCentreSpacing_mm+ ...
    C.legHeight*1e3;
DistanceScan.LlkPrimary_uH=mu0*E.Np^2*P.meanMLT/P.effectiveBreadth.* ...
    (DistanceScan.WindingCentreSpacing_mm*1e-3+ ...
    (P.primaryBuild+P.secondaryBuild)/3)*1e6;
DistanceScan.LlkSecondary_uH=DistanceScan.LlkPrimary_uH*(E.Ns/E.Np)^2;
DistanceScan.Cr_nF=1./((2*pi*E.f)^2*DistanceScan.LlkPrimary_uH*1e-6)*1e9;
targetCentreSpacing=E.LlkTarget/(mu0*E.Np^2*P.meanMLT/P.effectiveBreadth)- ...
    (P.primaryBuild+P.secondaryBuild)/3;
targetPSGap=targetCentreSpacing-C.legHeight-2*P.clearance- ...
    P.primaryBuild-P.secondaryBuild;
targetCoreLength=targetCentreSpacing+C.legHeight;

%% Sweep centre-leg area at fixed 12:8 aspect ratio
Scan.Ae_mm2=60:1:140;
Scan.coreLength_mm=28:0.5:50;
[COREmm,AEmm2]=meshgrid(Scan.coreLength_mm,Scan.Ae_mm2);

% For depth/height = r and area = height*depth:
% height=sqrt(Ae/r), depth=sqrt(Ae*r).
LEGHEIGHTmm=sqrt(AEmm2/C.aspectRatio);
LEGDEPTHmm=sqrt(AEmm2*C.aspectRatio);
AEscan=AEmm2*1e-6;
Hscan=LEGHEIGHTmm+0.5*C.PCBthickness*1e3+ ...
    C.coreToPCBSurface*1e3-0.5*C.gapEachJoint*1e3;
LEscan=2*((COREmm-LEGHEIGHTmm)+2*(Hscan-LEGHEIGHTmm/2))*1e-3;
VEscan=AEscan.*LEscan;
Bscan=E.Vpri./(4*E.f*E.Np.*AEscan);
Pvscan=M.Cm*E.f^M.X.*Bscan.^M.Y;
PcoreScan=Pvscan.*VEscan;
LmScan=Kcal*AEscan./(gTotal+LEscan/M.mui);
assembledHeightScan=2*Hscan+C.gapEachJoint*1e3;
windowScan=COREmm-2*LEGHEIGHTmm;

% Apply the side-by-side geometry formula at every Ae/core-length point.
legHeightScan=LEGHEIGHTmm*1e-3;
legDepthScan=LEGDEPTHmm*1e-3;
pMeanHalfX=legHeightScan/2+P.clearance+P.wp/2+ ...
    mean(pIndex)*P.primaryPitch;
pMeanHalfY=legDepthScan/2+P.clearance+P.wp/2+ ...
    mean(pIndex)*P.primaryPitch;
sMeanHalfX=legHeightScan/2+P.clearance+P.ws/2+ ...
    mean(sIndex)*P.secondaryPitch;
sMeanHalfY=legDepthScan/2+P.clearance+P.ws/2+ ...
    mean(sIndex)*P.secondaryPitch;
meanMLTScan=0.5*(4*(pMeanHalfX+pMeanHalfY)+ ...
    4*(sMeanHalfX+sMeanHalfY));
primaryBreadthScan=2*(legDepthScan/2+P.clearance+P.wp+ ...
    (E.Np-1)*P.primaryPitch);
secondaryBreadthScan=2*(legDepthScan/2+P.clearance+P.ws+ ...
    (E.Ns-1)*P.secondaryPitch);
effectiveBreadthScan=min(primaryBreadthScan,secondaryBreadthScan);
sectionGapScan=windowScan*1e-3-2*P.clearance- ...
    P.primaryBuild-P.secondaryBuild;
centreSpacingScan=(COREmm-LEGHEIGHTmm)*1e-3;
LlkGeometryScan=mu0*E.Np^2.*meanMLTScan./effectiveBreadthScan.* ...
    (centreSpacingScan+(P.primaryBuild+P.secondaryBuild)/3);
LlkGeometryScan(sectionGapScan<=0)=NaN;

% Required gap for the fixed Lm target. U height shortens by totalGap/4,
% so le = leBase-totalGap for this two-U geometry.
leBase=LEscan+gTotal;
gFixedLm=(Kcal*AEscan/E.LmTarget-leBase/M.mui)/(1-1/M.mui);
HfixedLm=LEGHEIGHTmm*1e-3+C.PCBthickness/2+C.coreToPCBSurface-gFixedLm/4;
gapFeasible=gFixedLm>=0 & HfixedLm>LEGHEIGHTmm*1e-3 & windowScan>0;
gapEachPlot=0.5*gFixedLm*1e3;
gapEachPlot(~gapFeasible)=NaN;
valid=Bscan<=M.Blimit & windowScan>=12 & LEGHEIGHTmm<Hscan;

%% Console report
fprintf('\n=== RECTANGULAR CENTRE-LEG LLC MAGNETICS ===\n');
fprintf('Centre leg: %.1f x %.1f mm; Ae=%.1f mm^2; depth/height=%.2f\n', ...
    C.legHeight*1e3,C.legDepth*1e3,C.Ae*1e6,C.aspectRatio);
fprintf('Core length %.1f mm; one-U height %.3f mm; assembled height %.3f mm\n', ...
    C.length*1e3,C.Uheight*1e3,assembledHeight*1e3);
fprintf('Window between legs %.1f mm; leg pitch %.1f mm\n', ...
    C.windowBetweenLegs*1e3,C.legPitch*1e3);
fprintf('Bpk %.2f mT; estimated Lm %.3f uH; estimated core loss %.4f W\n', ...
    Bpk*1e3,E.Lm*1e6,Pcore);
fprintf(['Direct geometry leakage estimate %.3f uH ' ...
    '(primary-referred; target %.3f uH)\n'], ...
    E.LlkGeometry*1e6,E.LlkTarget*1e6);
fprintf('Geometry-estimate Cr %.2f nF; Ln %.2f\n', ...
    E.CrGeometry*1e9,E.LnGeometry);
fprintf(['Leakage geometry inputs: mean MLT %.1f mm, effective breadth %.1f mm, ' ...
    'P/S build %.1f/%.1f mm, winding-centre spacing %.1f mm\n'], ...
    P.meanMLT*1e3,P.effectiveBreadth*1e3,P.primaryBuild*1e3, ...
    P.secondaryBuild*1e3,P.windingCentreSpacing*1e3);
fprintf(['Distance scan: geometry formula reaches %.3f uH at nearest P-S copper ' ...
    'gap %.2f mm (centre spacing %.2f mm; core length %.2f mm)\n'], ...
    E.LlkTarget*1e6,targetPSGap*1e3,targetCentreSpacing*1e3, ...
    targetCoreLength*1e3);
fprintf('Lm at mui -25%%/nom/+25%%: %.3f / %.3f / %.3f uH\n',LmCorners*1e6);
fprintf('PCB slots: %.1f x %.1f mm\n', ...
    C.slotAlongLength*1e3,C.slotAcrossDepth*1e3);
fprintf('================================================\n');

assert(Bpk<M.Blimit,'Selected rectangular centre leg exceeds the B limit.');
assert(C.windowBetweenLegs>12e-3,'Selected rectangular legs leave insufficient window width.');
assert(P.sectionGap>0,'Primary and secondary winding sections overlap.');

%% Area-sweep plots
outDir=fullfile(fileparts(mfilename('fullpath')),'output');
if ~exist(outDir,'dir'), mkdir(outDir); end
routingPlot=plot_rectangular_routing(E,C,P,outDir);

fig=figure('Color','w','Position',[60 40 1400 950]);
tl=tiledlayout(fig,2,2,'Padding','compact','TileSpacing','compact');
title(tl,{sprintf('Rectangular centre leg, depth/height = %.2f; Np=%d, %.0f kHz', ...
    C.aspectRatio,E.Np,E.f/1e3), ...
    sprintf('Selected %.1f x %.1f mm, Ae=%.1f mm^2', ...
    C.legHeight*1e3,C.legDepth*1e3,C.Ae*1e6)});
area_lines(nexttile(tl),Scan.coreLength_mm,Scan.Ae_mm2,Bscan*1e3, ...
    'B_{pk} (mT)',C.length*1e3,C.Ae*1e6);
area_lines(nexttile(tl),Scan.coreLength_mm,Scan.Ae_mm2,LmScan*1e6, ...
    'Estimated L_m at fixed gap (uH)',C.length*1e3,C.Ae*1e6);
area_lines(nexttile(tl),Scan.coreLength_mm,Scan.Ae_mm2,PcoreScan, ...
    'DMR53 core-loss estimate (W)',C.length*1e3,C.Ae*1e6);
area_lines(nexttile(tl),Scan.coreLength_mm,Scan.Ae_mm2,assembledHeightScan, ...
    'Assembled core height (mm)',C.length*1e3,C.Ae*1e6);
areaPlot=fullfile(outDir,'LLC_rectangular_centre_leg_Ae_scan.png');
exportgraphics(fig,areaPlot,'Resolution',220);

fig2=figure('Color','w','Position',[40 80 1650 560]);
tl2=tiledlayout(fig2,1,3,'Padding','compact','TileSpacing','compact');
title(tl2,sprintf('Fixed aspect ratio %.2f; horizontal axis is centre-leg area A_e', ...
    C.aspectRatio));
area_lines(nexttile(tl2),Scan.coreLength_mm,Scan.Ae_mm2,gapEachPlot, ...
    sprintf('Required gap per joint for L_m=%.2f uH (mm)',E.LmTarget*1e6), ...
    C.length*1e3,C.Ae*1e6);
area_lines(nexttile(tl2),Scan.coreLength_mm,Scan.Ae_mm2,VEscan*1e6, ...
    'Effective core volume (cm^3)',C.length*1e3,C.Ae*1e6);
area_lines(nexttile(tl2),Scan.coreLength_mm,Scan.Ae_mm2,LEGHEIGHTmm, ...
    'Height-setting leg dimension (mm)',C.length*1e3,C.Ae*1e6);
gapPlotFile=fullfile(outDir,'LLC_rectangular_Ae_gap_volume_height.png');
exportgraphics(fig2,gapPlotFile,'Resolution',220);

figLeak=figure('Color','w','Position',[40 90 1700 700]);
tlLeak=tiledlayout(figLeak,1,2,'Padding','compact','TileSpacing','compact');
title(tlLeak,{sprintf('Primary-referred leakage from the side-by-side winding formula; Np:Ns = %d:%d', ...
    E.Np,E.Ns),'8 x 12 mm rectangular leg; residual 2-D/3-D fringing is not included'});
axLeak=nexttile(tlLeak); 
area_lines(axLeak,Scan.coreLength_mm,Scan.Ae_mm2,LlkGeometryScan*1e6, ...
    'Primary-referred geometry leakage (uH)',C.length*1e3,C.Ae*1e6);
yline(axLeak,E.LlkTarget*1e6,'k--','LineWidth',1.4, ...
    'DisplayName','1 uH target');
title(axLeak,sprintf('Leakage versus centre-leg area; aspect ratio %.2f',C.aspectRatio));

axDistance=nexttile(tlLeak); hold(axDistance,'on');
plot(axDistance,DistanceScan.PSCopperGap_mm,DistanceScan.LlkPrimary_uH, ...
    'b-','LineWidth',2.0,'DisplayName','Geometry formula');
yline(axDistance,E.LlkTarget*1e6,'k--','LineWidth',1.4, ...
    'DisplayName','1 uH target');
yline(axDistance,1.190018,'Color',[0.35 0.35 0.35],'LineStyle',':', ...
    'LineWidth',1.5,'DisplayName','AEDT at current geometry: 1.190 uH');
xline(axDistance,P.sectionGap*1e3,'r--','LineWidth',1.4, ...
    'DisplayName',sprintf('Current copper gap: %.1f mm',P.sectionGap*1e3));
plot(axDistance,P.sectionGap*1e3,E.LlkGeometry*1e6,'rp', ...
    'MarkerFaceColor','r','MarkerSize',12, ...
    'DisplayName',sprintf('Current formula result: %.3f uH',E.LlkGeometry*1e6));
plot(axDistance,targetPSGap*1e3,E.LlkTarget*1e6,'ko', ...
    'MarkerFaceColor',[1 0.85 0],'MarkerSize',8, ...
    'DisplayName',sprintf('Formula target gap: %.2f mm',targetPSGap*1e3));
xlabel(axDistance,'Nearest primary-secondary copper distance (mm)');
ylabel(axDistance,'Primary-referred leakage inductance (uH)');
title(axDistance,{'Leakage sensitivity to primary-secondary copper distance', ...
    '8 x 12 mm leg; Np:Ns = 3:4; other winding dimensions fixed'});
grid(axDistance,'on'); legend(axDistance,'Location','northwest');
leakagePlot=fullfile(outDir,'LLC_rectangular_leakage_combined.png');
exportgraphics(figLeak,leakagePlot,'Resolution',220);

%% Selected rectangular-core dimension sketch
fig3=figure('Color','w','Position',[80 80 1320 620]);
ax1=subplot(1,2,1,'Parent',fig3); hold(ax1,'on'); axis(ax1,'equal'); grid(ax1,'on');
L=C.length*1e3; d=C.legDepth*1e3; a=C.legHeight*1e3;
rectangle(ax1,'Position',[0 0 L d],'FaceColor',[0.24 0.27 0.30],'EdgeColor','k');
cx=[a/2,L-a/2];
for k=1:2
    rectangle(ax1,'Position',[cx(k)-C.slotAlongLength*0.5e3, ...
        d/2-C.slotAcrossDepth*0.5e3,C.slotAlongLength*1e3,C.slotAcrossDepth*1e3], ...
        'EdgeColor',[0.9 0.25 0.12],'LineStyle','--','LineWidth',1.5);
end
xlim(ax1,[-4 L+4]); ylim(ax1,[-3 d+3]);
xlabel(ax1,'Core length (mm)'); ylabel(ax1,'Core depth (mm)');
title(ax1,sprintf('Top view: %.1f mm x %.1f mm',L,d));
text(ax1,L/2,d/2,sprintf('Ae = %.1f mm^2',C.Ae*1e6), ...
    'Color','w','FontWeight','bold','HorizontalAlignment','center');

ax2=subplot(1,2,2,'Parent',fig3); hold(ax2,'on'); axis(ax2,'equal'); grid(ax2,'on');
h=C.Uheight*1e3; stem=h-a; gh=C.gapEachJoint*0.5e3;
rectangle(ax2,'Position',[0 gh+stem L a],'FaceColor',[0.24 0.27 0.30]);
rectangle(ax2,'Position',[0 gh a stem],'FaceColor',[0.24 0.27 0.30]);
rectangle(ax2,'Position',[L-a gh a stem],'FaceColor',[0.24 0.27 0.30]);
rectangle(ax2,'Position',[0 -gh-h L a],'FaceColor',[0.24 0.27 0.30]);
rectangle(ax2,'Position',[0 -gh-stem a stem],'FaceColor',[0.24 0.27 0.30]);
rectangle(ax2,'Position',[L-a -gh-stem a stem],'FaceColor',[0.24 0.27 0.30]);
xlim(ax2,[-4 L+4]); ylim(ax2,[-h-3 h+3]);
xlabel(ax2,'Core length (mm)'); ylabel(ax2,'Assembly height (mm)');
title(ax2,sprintf('Side view: 8 mm height-setting section; total %.3f mm', ...
    assembledHeight*1e3));
dimensionPlot=fullfile(outDir,'LLC_rectangular_selected_dimensions.png');
exportgraphics(fig3,dimensionPlot,'Resolution',220);

%% Export sweep data
T=table(COREmm(:),AEmm2(:),LEGHEIGHTmm(:),LEGDEPTHmm(:), ...
    Bscan(:)*1e3,LmScan(:)*1e6,LlkGeometryScan(:)*1e6, ...
    PcoreScan(:),VEscan(:)*1e6, ...
    assembledHeightScan(:),gapEachPlot(:),windowScan(:),valid(:), ...
    'VariableNames',{'CoreLength_mm','Ae_mm2','LegHeight_mm','LegDepth_mm', ...
    'Bpk_mT','EstimatedLmAtFixedGap_uH','GeometryLeakageEstimate_uH', ...
    'CoreLoss_W','Ve_cm3', ...
    'AssembledHeight_mm','RequiredGapEachJoint_mm','WindowBetweenLegs_mm','Valid'});
csvFile=fullfile(outDir,'LLC_rectangular_centre_leg_Ae_scan.csv');
writetable(T,csvFile);
Tdistance=table(DistanceScan.PSCopperGap_mm(:), ...
    DistanceScan.WindingCentreSpacing_mm(:),DistanceScan.CoreLength_mm(:), ...
    DistanceScan.LlkPrimary_uH(:),DistanceScan.LlkSecondary_uH(:), ...
    DistanceScan.Cr_nF(:), ...
    'VariableNames',{'PSCopperGap_mm','WindingCentreSpacing_mm', ...
    'CoreLength_mm','PrimaryReferredLeakage_uH', ...
    'SecondaryReferredLeakage_uH','Cr_nF'});
distanceCsv=fullfile(outDir,'LLC_rectangular_PS_distance_leakage_scan.csv');
writetable(Tdistance,distanceCsv);
fprintf('Area scan plot: %s\n',areaPlot);
fprintf('Gap/volume/height plot: %s\n',gapPlotFile);
fprintf('Combined leakage plots: %s\n',leakagePlot);
fprintf('Selected dimension sketch: %s\n',dimensionPlot);
fprintf('Layer routing plot: %s\n',routingPlot);
fprintf('Area scan CSV: %s\n',csvFile);
fprintf('P-S distance leakage CSV: %s\n',distanceCsv);

function area_lines(ax,coreLength,areaAxis,z,ttl,xSel,areaSel)
% Plot line families against centre-leg area rather than square-leg side.
nShow=7;
idx=unique([round(linspace(1,numel(coreLength),nShow)), ...
    find(abs(coreLength-xSel)==min(abs(coreLength-xSel)),1)]);
colors=lines(numel(idx)); hold(ax,'on');
for k=1:numel(idx)
    plot(ax,areaAxis,z(:,idx(k)),'LineWidth',1.6,'Color',colors(k,:), ...
        'DisplayName',sprintf('Core L = %.1f mm',coreLength(idx(k))));
end
[~,ix]=min(abs(coreLength-xSel));
[~,iy]=min(abs(areaAxis-areaSel));
plot(ax,areaAxis(iy),z(iy,ix),'rp','MarkerFaceColor','r','MarkerSize',12, ...
    'DisplayName',sprintf('Selected L=%.0f mm, Ae=%.0f mm^2',xSel,areaSel));
xlabel(ax,'Centre-leg area A_e (mm^2)');
ylabel(ax,ttl); title(ax,ttl); grid(ax,'on');
legend(ax,'Location','best','FontSize',7);
end

function outputFile=plot_rectangular_routing(E,C,P,outDir)
% Six-layer centre-line routing view for the selected rectangular legs.
% Coordinates remain referenced to the PCB centre, while leg centres and
% keep-out rectangles are derived from the selected core dimensions.
paths={}; layers=[]; nets=[];
legCenter=0.5*C.legPitch*1e3;
halfX=0.5*C.legHeight*1e3;
halfY=0.5*C.legDepth*1e3;

% Two parallel three-turn primary windings on L2 and L3.
pTemplate=rect_spiral(-legCenter,3,P.wp*1e3,P.spacing*1e3,halfX,halfY,false);
pStart=pTemplate(1,:);
pReturn=[-19.1 pTemplate(end,2)];
for layer=[2 3]
    q=pTemplate;
    q(end+1,:)=pReturn; %#ok<AGROW>
    add_path(q,layer,1);
end
add_path([pStart;-30 pStart(2)],1,1);
add_path([pReturn;-19.1 -9;-30 -9],1,1);

% Four independent four-turn secondaries on L2/L3/L6/L7.
secondaryLayers=[2 3 6 7];
viaX=[17.9 19.4 19.4 17.9];
returnY=[-9.15 -8.25 -8.25 -9.15];
vias=[pStart 1 3;pReturn 1 3];
for k=1:4
    layer=secondaryLayers(k);
    q=rect_spiral(legCenter,4,P.ws*1e3,P.spacing*1e3,halfX,halfY,true);
    if layer==3, q=[q(1,:)+[0 3];q]; end %#ok<AGROW>
    if layer==6, q=[q(1,:)+[0 -3];q]; end %#ok<AGROW>
    q(end+1,:)=[viaX(k) q(end,2)]; %#ok<AGROW>
    add_path(q,layer,k+1);
    surface=1; if layer>4, surface=8; end
    add_path([q(1,:);30 q(1,2)],surface,k+1);
    add_path([q(end,:);viaX(k) returnY(k);30 returnY(k)],surface,k+1);
    vias=[vias;q(1,:) min(layer,surface) max(layer,surface); ...
        q(end,:) min(layer,surface) max(layer,surface)]; %#ok<AGROW>
end

f=figure('Color','w','Position',[40 40 1500 820]);
tl=tiledlayout(f,2,3,'Padding','compact','TileSpacing','compact');
shownLayers=[1 2 3 6 7 8];
for layer=shownLayers
    ax=nexttile(tl); hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
    for centre=[-legCenter legCenter]
        rectangle(ax,'Position',[centre-halfX -halfY 2*halfX 2*halfY], ...
            'FaceColor',[.72 .72 .72],'EdgeColor',[.2 .2 .2]);
    end
    for k=find(layers==layer)
        colour=[.88 .10 .08];
        if nets(k)>1, colour=[.04 .35 .95]; end
        q=paths{k};
        plot(ax,q(:,1),q(:,2),'-','Color',colour,'LineWidth',1.5);
    end
    for k=1:size(vias,1)
        if layer>=vias(k,3) && layer<=vias(k,4)
            plot(ax,vias(k,1),vias(k,2),'ko','MarkerFaceColor','y','MarkerSize',5);
        end
    end
    xlim(ax,[-32 32]); ylim(ax,[-14 14]);
    title(ax,sprintf('L%d (centre-line routing)',layer));
    xlabel(ax,'x / mm'); ylabel(ax,'y / mm');
end
title(tl,sprintf(['Np:Ns=%d:%d; rectangular leg %.1f x %.1f mm; ' ...
    'Lm estimate %.2f uH; P/S trace %.2f/%.2f mm'], ...
    E.Np,E.Ns,C.legHeight*1e3,C.legDepth*1e3,E.Lm*1e6, ...
    P.wp*1e3,P.ws*1e3));
outputFile=fullfile(outDir,'LLC_rectangular_layer_routing.png');
exportgraphics(f,outputFile,'Resolution',180);

    function add_path(q,layer,net)
        paths{end+1}=q;
        layers(end+1)=layer;
        nets(end+1)=net;
    end
end

function q=rect_spiral(cx,n,w,s,halfX,halfY,mirror)
% Rectangular spiral with 2 mm copper-to-core clearance.
pitch=w+s;
ax=halfX+2+w/2+(n-1)*pitch;
ay=halfY+2+w/2+(n-1)*pitch;
xl=cx-ax; xr=cx+ax; yb=-ay; yt=ay;
q=[xl-4 0;xl 0;xl yt];
for k=1:n
    q=[q;xr yt;xr yb]; %#ok<AGROW>
    if k<n
        q=[q;xl+pitch yb]; %#ok<AGROW>
        xl=xl+pitch; xr=xr-pitch; yb=yb+pitch; yt=yt-pitch;
        q=[q;xl yt]; %#ok<AGROW>
    end
end
if mirror, q(:,1)=2*cx-q(:,1); end
end

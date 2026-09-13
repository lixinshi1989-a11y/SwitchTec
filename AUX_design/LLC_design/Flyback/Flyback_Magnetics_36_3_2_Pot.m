%% 36:3:2 scheme C pot-core loss audit, based on Flyback_Magnetics_36_3_2.m
% Reads the saved EE material/electrical rules and the ACTUAL generated pot
% geometry. Does not modify the EE sweep, its results, or the AEDT project.
% Analytical model only: no measured or solved pot-core loss is available.
clear; clc; close all
root=fileparts(mfilename('fullpath'));
baseFile=fullfile(root,'output','36_3_2_compact','Flyback_36_3_2_compact_design.mat');
out=fullfile(root,'output','36_3_2_pot');
geoFile=fullfile(out,'Flyback_36_3_2_Scheme_C_Pot_100kHz_geometry.json');
assert(isfile(baseFile),'Run Flyback_Magnetics_36_3_2.m first.');
assert(isfile(geoFile),'Run build_flyback_36_3_2_scheme_c_pot_aedt.py first.');
base=load(baseFile,'E','W','M','G3'); E=base.E; W=base.W; M=base.M;
G=jsondecode(fileread(geoFile));
assert(isequal([E.Np E.Ns E.Naux],[36 3 2]));
assert(G.validation==1 && abs(G.centre_area_mm2-576)<1e-8);
assert(G.secondary_breadth_mm<=G.primary_breadth_mm);
assert(max(abs(G.copper_mm(:)-W.copperThickness_mm(:)))<1e-10);
mu0=4*pi*1e-7;
R=G.centre_diameter_mm/2; RW=G.window_radius_mm;
RO=G.outer_side_mm/2; chamfer=G.outer_corner_chamfer_mm;
yoke=12; % Same as the EE source and pot AEDT builder.
stem=(G.core_height_mm-G.gap_mm)/2-yoke;
Afoot=4*RO^2-2*chamfer^2;
Vcore=G.native_core_checks.Core_Upper.volume_mm3+G.native_core_checks.Core_Lower.volume_mm3;
Ac=G.centre_area_mm2;
% Recover the return-wall area from actual CAD volume, including lead slots.
Ar=(Vcore-2*yoke*Afoot)/(2*stem)-Ac;
assert(Ar>0 && stem>0);
% One-dimensional pot circuit: centre and return in series; two radial yokes.
% End-region mean paths use half of each yoke thickness. Slot flux crowding,
% fringing, corner flux and DC-bias permeability are not resolved by this model.
vertical=2*stem+yoke;
Rcore=vertical*1e-3/(mu0*M.mui*Ac*1e-6)+ ...
      vertical*1e-3/(mu0*M.mui*Ar*1e-6)+ ...
      log(RW/R)/(pi*mu0*M.mui*yoke*1e-3);
gapCoeff=(1/(mu0*Ac*1e-6)+1/(mu0*Ar*1e-6));
LmPot=E.Np^2/(Rcore+G.gap_mm*1e-3*gapCoeff);
gapForTarget_mm=(E.Np^2/E.Lm-Rcore)/gapCoeff*1e3;

%% Native circular-arc centreline lengths, leads, vias and external bridges
z=G.layer_z_mm(:)'; cu=G.copper_mm(:)';
rho=W.rhoCu*W.copperTempFactor;
pp=W.primaryWidth_mm+W.traceSpacing_mm+G.transition_allowance_mm.primary;
sp=W.secondaryWidth_mm+W.traceSpacing_mm+G.transition_allowance_mm.secondary;
pInner=R+W.coreClearance_mm+W.primaryWidth_mm/2;
sInner=R+W.coreClearance_mm+W.secondaryWidth_mm/2;
ar=G.aux_radial_centre_mm;
[pLength,pOuter,~]=spiralLength(18,pInner,pp,10);
% Inner extra 10-degree arc to the series via; outer lead to Y=-31.
pLength=pLength+pInner*deg2rad(10)+(31+ pOuter(2));
[sLength,sOuter,sEnd]=spiralLength(3,sInner,sp,30);
[aLength,aOuter,~]=spiralLength(1,ar,W.auxWidth_mm+W.traceSpacing_mm,10);
aLength=aLength+ar*deg2rad(10)+(25+aOuter(2));
rP=rho*pLength*1e-3./(W.primaryWidth_mm*cu([2 3])*1e-6);
rS=rho*sLength*1e-3./(W.secondaryWidth_mm*cu([6 7 8])*1e-6);
rA=rho*aLength*1e-3./(W.auxWidth_mm*cu([4 5])*1e-6);
rPvia=rho*abs(z(2)-z(3))*1e-3/(pi*(.1e-3)^2);
rAseries=rho*abs(z(4)-z(5))*1e-3/(pi*(.1e-3)^2);
rAaccess=rho*sum(abs(z(1)-z([4 5])))*1e-3/(pi*(.1e-3)^2);
rAleads=rho*(2*6)*1e-3/(W.auxWidth_mm*cu(1)*1e-6);
% S endpoints reflected into +Y, exactly as in the builder.
endpoints=[sOuter;sEnd].*[1 -1];
busZ=-G.pcb_size_mm(3)/2-.5-.069/2;
busWideLength=zeros(1,2); busNeckLength=zeros(1,2);
for k=1:2
    x=endpoints(k,1); y=endpoints(k,2); lane=sign(x)*4.55;
    by=max(y,R+2+6.5/2);
    busWideLength(k)=31-by;
    busNeckLength(k)=by-y+abs(lane-x);
end
rBus=rho*sum(busWideLength)*1e-3/(6.5*.069*1e-6)+ ...
     rho*sum(busNeckLength)*1e-3/(2.2*.069*1e-6);
sViaArea=pi*(1.1e-3)^2;
rVia67=rho*abs(z(6)-z(7))*1e-3/sViaArea;
rVia78=rho*abs(z(7)-z(8))*1e-3/sViaArea;
rPosts=2*rho*abs(z(8)-busZ)*1e-3/sViaArea;
share=(1./rS)/sum(1./rS);
% DC layer sharing approximation; via resistance is small but its I^2R is
% included below. Final AC sharing and proximity effects require the solver.
Res=struct('rP',rP,'rS',rS,'rA',rA,'rPvia',rPvia, ...
    'rAextra',rAseries+rAaccess+rAleads,'rBus',rBus,'rPosts',rPosts, ...
    'rVia67',rVia67,'rVia78',rVia78,'share',share);

%% Segmented iGSE magnetic loss using the same material fit as the EE script
cosIntegral=2*sqrt(pi)*gamma((M.alpha+1)/2)/gamma((M.alpha+2)/2);
M.ki=M.k/((2*pi)^(M.alpha-1)*2^(M.beta-M.alpha)*cosIntegral);
% The window annulus carries radial flux, B(r)=Phi/(2*pi*r*yoke).
% Centre and outer end regions are conservatively assigned their respective
% vertical-leg flux densities; this is an explicit end-region approximation.
Vcentre=2*(stem+yoke)*Ac;
Vreturn=2*(stem*Ar+yoke*(Afoot-pi*RW^2));
Vradial=2*pi*(RW^2-R^2)*yoke;
assert(abs(Vcentre+Vreturn+Vradial-Vcore)<1e-6);
radialEquivalent=integral(@(r) (Ac./(2*pi*r*yoke)).^M.beta.*(4*pi*r*yoke),R,RW);
Geom=struct('Ac_mm2',Ac,'Ar_mm2',Ar,'Vcore_mm3',Vcore, ...
    'Vcentre_mm3',Vcentre,'Vreturn_mm3',Vreturn,'Vradial_mm3',Vradial, ...
    'radialEquivalent_mm3',radialEquivalent,'Rcore',Rcore,'gapCoeff',gapCoeff);
nominal=operatingPoint(LmPot,1,E,W,M,Geom,Res);
envelope=operatingPoint(LmPot,E.eta,E,W,M,Geom,Res);
target=operatingPoint(E.Lm,E.eta,E,W,M,Geom,Res);
Mode=["Pot: 100 W ideal nominal";"Pot: eta-based sizing envelope";"Pot: target Lm (different gap required)"];
points=[nominal envelope target];
assert(abs(.5*nominal.IsRms/sqrt(nominal.Ddemag/3)*nominal.Ddemag-E.Iout)<1e-8);
Summary=table(Mode,[points.Lm_mH]',[G.gap_mm;G.gap_mm;gapForTarget_mm], ...
    [points.IpRms]',[points.IsRms]',[points.Bpk_mT]',[points.Core_W]', ...
    [points.Primary_W]',[points.Secondary_W]',[points.Aux_W]',[points.Copper_W]',[points.Total_W]', ...
    'VariableNames',{'Mode','Lm_mH','GapEach_mm','IpRms_A','IsRms_A','Bpk_mT', ...
    'Core_W','Primary_W','Secondary_W','Aux_W','Copper_W','Total_W'});
Summary.ConductionMode=string({points.ConductionMode})';
Summary.DeltaB_mT=[points.DeltaB_mT]';
writetable(Summary,fullfile(out,'Flyback_36_3_2_Pot_loss_summary.csv'));
% Per-conductor audit at the sizing envelope operating point.
Item=["Primary L2";"Primary L3";"Primary series via";"Secondary L6";"Secondary L7"; ...
    "Secondary L8";"Secondary buses/necks";"Secondary vias/posts";"AUX L4";"AUX L5";"AUX leads/vias"];
Length_mm=[pLength;pLength;abs(z(2)-z(3));sLength;sLength;sLength;sum(busWideLength+busNeckLength);NaN;aLength;aLength;NaN];
Width_mm=[.2;.2;.2;2.2;2.2;2.2;NaN;2.2;.2;.2;NaN];
Current_A=[envelope.IpRms*ones(3,1);envelope.IsRms*share';envelope.IsRms;NaN;E.IauxRms*ones(3,1)];
Loss_W=[envelope.IpRms^2*rP'*W.FacPrimary;envelope.IpRms^2*rPvia*W.FacPrimary; ...
    (envelope.IsRms*share').^2.*rS'*W.FacSecondary;envelope.Bus_W;envelope.Vias_W; ...
    E.IauxRms^2*rA'*W.FacAux;E.IauxRms^2*Res.rAextra*W.FacAux];
Audit=table(Item,Length_mm,Width_mm,Current_A,Loss_W);
assert(abs(sum(Loss_W)-envelope.Copper_W)<1e-10);
writetable(Audit,fullfile(out,'Flyback_36_3_2_Pot_trace_loss_audit.csv'));

%% Gap sensitivity at fixed manufactured pot dimensions (does not edit AEDT)
gaps=sort(unique([.10:.005:.40 G.gap_mm gapForTarget_mm]));
gapSweep=repmat(envelope,size(gaps));
for k=1:numel(gaps)
    L=E.Np^2/(Rcore+gaps(k)*1e-3*gapCoeff);
    gapSweep(k)=operatingPoint(L,E.eta,E,W,M,Geom,Res);
end
Sweep=struct2table(gapSweep); Sweep.GapEach_mm=gaps';
writetable(Sweep,fullfile(out,'Flyback_36_3_2_Pot_gap_sensitivity.csv'));
fig=figure('Color','w','Position',[80 80 1450 950]);
tl=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
title(tl,{'36:3:2 Pot core - analytical loss estimate, 100 kHz / 80 C', ...
    sprintf('Existing gap %.4f mm; predicted Lm %.3f mH; no AEDT solution',G.gap_mm,LmPot*1e3)});
nexttile; bar([nominal.Primary_W nominal.Secondary_W nominal.Aux_W nominal.Core_W; ...
    envelope.Primary_W envelope.Secondary_W envelope.Aux_W envelope.Core_W],'stacked');
xticklabels({'100 W ideal nominal','Sizing envelope (eta=0.90)'}); ylabel('Loss (W)'); grid on;
legend('Primary','Secondary incl. buses/vias','AUX','Core','Location','northwest');
title(sprintf('Nominal %.3f W; sizing envelope %.3f W',nominal.Total_W,envelope.Total_W));
nexttile; plot(gaps,[gapSweep.Core_W],gaps,[gapSweep.Copper_W],gaps,[gapSweep.Total_W],'LineWidth',1.7); hold on;
xline(G.gap_mm,'k--','Existing gap'); xlabel('Gap at centre / return (mm)'); ylabel('Loss (W)'); grid on;
legend('Core','Copper','Total'); title('Gap sensitivity: fixed core dimensions, eta envelope');
nexttile; yyaxis left; plot(gaps,[gapSweep.Lm_mH],'LineWidth',1.7); ylabel('Lm estimate (mH)');
yyaxis right; plot(gaps,[gapSweep.DeltaB_mT],'LineWidth',1.7); ylabel('Centre flux excursion (mT)');
xline(G.gap_mm,'k--'); xlabel('Gap (mm)'); grid on; title('Reluctance model: no gap fringing');
nexttile; axis off;
text(0,1,sprintf(['POT / C / 36:3:2\n\nCentre D %.3f mm; area %.0f mm^2\n' ...
    'Core %.3f x %.3f x %.3f mm; volume %.2f cm^3\nPCB 82 x 62 x %.3f mm\n' ...
    'P L2/L3: 18T each, 0.20 mm\nS L6/L7/L8: 3T each parallel, 2.20 mm\n' ...
    'AUX L4/L5: 1T each, 0.20 mm\nP / S radial breadth %.3f / %.3f mm\n' ...
    'Minimum turn spacing 0.20 mm\n\nCore fit: inherited TPG33 iGSE; segmented flux model\n' ...
    'Rac/Rdc assumptions: P 1.15, S 1.25, AUX 1.15\nNo fringing, DC-bias or thermal solution'], ...
    2*R,Ac,2*RO,2*RO,G.core_height_mm,Vcore/1000,G.pcb_size_mm(3),G.primary_breadth_mm,G.secondary_breadth_mm), ...
    'VerticalAlignment','top','FontSize',11,'Interpreter','none');
exportgraphics(fig,fullfile(out,'Flyback_36_3_2_Pot_loss_comparison.png'),'Resolution',180);
savefig(fig,fullfile(out,'Flyback_36_3_2_Pot_loss_comparison.fig'));
save(fullfile(out,'Flyback_36_3_2_Pot_design.mat'),'E','W','M','G','Geom','Res','Summary','Audit','Sweep','nominal','envelope','target');
fid=fopen(fullfile(out,'Flyback_36_3_2_Pot_loss_report.txt'),'w'); assert(fid>=0);
fprintf(fid,'36:3:2 Pot C; ANALYTICAL estimates, NOT AEDT solved values.\n');
fprintf(fid,'Source electrical/material rules: %s\nGeometry: %s\n',baseFile,geoFile);
fprintf(fid,'Actual gap %.9f mm; predicted Lm %.6f mH; target-Lm gap %.6f mm (not applied).\n',G.gap_mm,LmPot*1e3,gapForTarget_mm);
fprintf(fid,'CAD core volume %.6f cm3; centre area %.6f mm2; return area %.6f mm2.\n',Vcore/1000,Ac,Ar);
for k=1:3
    q=points(k);
    fprintf(fid,'%s: core %.6f W, copper %.6f W (P %.6f / S %.6f / AUX %.6f), total %.6f W.\n', ...
        Mode(k),q.Core_W,q.Copper_W,q.Primary_W,q.Secondary_W,q.Aux_W,q.Total_W);
    fprintf(fid,'Conduction %s; duty %.6f, demag %.6f; DeltaB %.6f mT, Bpeak %.6f mT.\n', ...
        q.ConductionMode,q.D,q.Ddemag,q.DeltaB_mT,q.Bpk_mT);
end
fprintf(fid,'Envelope regional core loss: centre %.6f, return %.6f, radial yokes %.6f W.\n',envelope.CoreCentre_W,envelope.CoreReturn_W,envelope.CoreRadial_W);
fprintf(fid,['Assumptions: original TPG33 80 C iGSE fit and empirical Rac/Rdc factors; solid-cylinder vias.\n' ...
    'End-region flux approximation; annulus axisymmetric; flux crowding at lead slots, DC bias and fringing omitted.\n' ...
    '100 W waveform excludes the separate AUX output power, consistent with original script.\n' ...
    'Eta=0.90 is a sizing envelope and does not enforce output-energy/loss closure.\n' ...
    'No old EE loss numbers are treated as solved Pot results. No geometry was changed.\n']);
fclose(fid);
%% Include the requested 25 mm square pot and regional flux-density comparison.
squareFile=fullfile(out,'square_core_sweep','SquarePot_sweep.mat');
assert(isfile(squareFile),'Run Flyback_Magnetics_36_3_2_SquarePot_Sweep.m first.');
square=load(squareFile,'S');
[D25,d25env,d25nom]=flybackEvaluateSquarePot(12.5,true,square.S,E,W,M,G);
[Edited,editedEnv]=flybackEvaluateSquarePot(square.S.referenceRadius_mm,false,square.S,E,W,M,G);
S24=square.S;
S24.outerInset_mm=12+S24.window_mm-43/2; % Explicit user dimensions override sweep shape relation.
[D24,d24env,d24nom]=flybackEvaluateSquarePot(12,true,S24,E,W,M,G);
assert(abs(D24.Diameter_mm-24)<1e-9 && abs(D24.CoreSide_mm-43)<1e-9);
for q={d25nom,d25env}
    v=q{1}; tag="Square D25: eta-based sizing envelope";
    if strcmp(v.ConductionMode,d25nom.ConductionMode) && abs(v.IpRms-d25nom.IpRms)<1e-10
        tag="Square D25: 100 W ideal nominal";
    end
    row=table(tag,v.Lm_mH,D25.Gap_mm,v.IpRms,v.IsRms,v.Bpk_mT,v.Core_W, ...
        v.Primary_W,v.Secondary_W,v.Aux_W,v.Copper_W,v.Total_W,string(v.ConductionMode),v.DeltaB_mT, ...
        'VariableNames',Summary.Properties.VariableNames);
    Summary=[Summary;row]; %#ok<AGROW>
end
writetable(Summary,fullfile(out,'Flyback_36_3_2_Pot_loss_summary.csv'));
names=["Original thick pot / Lm=2.3 mH";"Edited square D27.08 / original gap"; ...
       "Square D25 / Lm=2.3 mH";"Square D24 / core 43x43 / Lm=2.3 mH"];
ops=[target editedEnv d25env d24env];
areas=[Ac Edited.CentreArea_mm2 D25.CentreArea_mm2 D24.CentreArea_mm2];
returns=[Ar Edited.ReturnArea_mm2 D25.ReturnArea_mm2 D24.ReturnArea_mm2];
radii=[R Edited.Diameter_mm/2 D25.Diameter_mm/2 D24.Diameter_mm/2];
windows=[RW Edited.WindowRadius_mm D25.WindowRadius_mm D24.WindowRadius_mm];
halfSides=[RO Edited.CoreSide_mm/2 D25.CoreSide_mm/2 D24.CoreSide_mm/2];
yokes=[yoke square.S.yoke_mm square.S.yoke_mm S24.yoke_mm];
volumes=[Vcore/1000 Edited.CoreVolume_cm3 D25.CoreVolume_cm3 D24.CoreVolume_cm3];
gaps=[gapForTarget_mm Edited.Gap_mm D25.Gap_mm D24.Gap_mm];
Comparison=table(names,2*radii',yokes',volumes',gaps',[ops.Lm_mH]', ...
    [ops.Core_W]',[ops.Copper_W]',[ops.Total_W]', ...
    'VariableNames',{'Design','Diameter_mm','Yoke_mm','CoreVolume_cm3','Gap_mm','Lm_mH','Core_W','Copper_W','Total_W'});
Comparison.CoreSide_mm=2*halfSides';
Comparison.CoreHeight_mm=[G.core_height_mm Edited.CoreHeight_mm D25.CoreHeight_mm D24.CoreHeight_mm]';
Summary=table(names,[ops.Lm_mH]',gaps',[ops.IpRms]',[ops.IsRms]',[ops.Bpk_mT]', ...
    [ops.Core_W]',[ops.Primary_W]',[ops.Secondary_W]',[ops.Aux_W]',[ops.Copper_W]',[ops.Total_W]', ...
    string({ops.ConductionMode})',[ops.DeltaB_mT]', 'VariableNames',Summary.Properties.VariableNames);
writetable(Summary,fullfile(out,'Flyback_36_3_2_Pot_loss_summary.csv'));
Flux=table; Profile=table;
regional=zeros(4,5);
for k=1:4
    rr=linspace(radii(k),windows(k),401)';
    if k==1, theta=2*pi*ones(size(rr));
    else, theta=2*pi-8*acos(min(1,halfSides(k)./rr)); end
    gain=areas(k)./(theta.*rr*yokes(k));
    pk=ops(k).Bpk_mT; db=ops(k).DeltaB_mT;
    profile=table(repmat(names(k),numel(rr),1),rr,pk*gain,db*gain,(pk-db)*gain, ...
        'VariableNames',{'Design','Radius_mm','Bpeak_mT','DeltaB_mT','Bmin_mT'});
    Profile=[Profile;profile]; %#ok<AGROW>
    rr3=[radii(k);mean([radii(k) windows(k)]);windows(k)];
    if k==1, tt=2*pi*ones(3,1); else, tt=2*pi-8*acos(min(1,halfSides(k)./rr3)); end
    g3=areas(k)./(tt.*rr3*yokes(k));
    ratio=[1;areas(k)/returns(k);g3];
    region=["Centre post (mean)";"Return posts/wall (mean)";"Yoke inner radius";"Yoke middle radius";"Yoke outer radius"];
    flux=table(repmat(names(k),5,1),region,[0;NaN;rr3],pk*ratio,db*ratio,(pk-db)*ratio, ...
        'VariableNames',{'Design','Region','Radius_mm','Bpeak_mT','DeltaB_mT','Bmin_mT'});
    Flux=[Flux;flux]; regional(k,:)=pk*ratio'; %#ok<AGROW>
end
writetable(Comparison,fullfile(out,'Flyback_Pot_including_D25_comparison.csv'));
writetable(Flux,fullfile(out,'Flyback_Pot_regional_B.csv'));
writetable(Profile,fullfile(out,'Flyback_Pot_yoke_radial_B.csv'));
fB=figure('Color','w','Position',[30 30 1600 1000]);
tB=tiledlayout(fB,2,2,'TileSpacing','compact','Padding','compact');
title(tB,{'Pot comparison including D25 and D24 / core 43x43 mm / 100 kHz / 80 C / eta=0.90 envelope', ...
    'Analytical regional B estimates; flux crowding and gap fringing require 3-D FEA'});
short={'Thick Lm=2.3','Edited D27.08','Square D25','D24 / core 43x43'};
nexttile; bar([[ops.Primary_W]' [ops.Secondary_W]' [ops.Aux_W]' [ops.Core_W]'],'stacked');
xticklabels(short); ylabel('Loss (W)'); grid on; legend('Primary','Secondary','AUX','Core','Location','best');
title(sprintf('D24 / 43x43: core %.3f + copper %.3f = %.3f W',d24env.Core_W,d24env.Copper_W,d24env.Total_W));
nexttile; bar(regional); xticklabels(short); ylabel('B peak (mT)'); grid on;
legend('Centre','Return','Yoke inner','Yoke middle','Yoke outer','Location','best');
yline(200,'k--','Previous screening limit','HandleVisibility','off'); title('Regional peak flux density (mean-field model)');
nexttile; hold on;
for k=1:4
    p=Profile(Profile.Design==names(k),:);
    plot(p.Radius_mm,p.Bpeak_mT,'LineWidth',1.7,'DisplayName',short{k});
end
xlabel('Yoke radius (mm)'); ylabel('Yoke B peak (mT)'); grid on; legend('Location','best');
title('Radial yoke profile; corner returns use angular aperture');
nexttile; axis off;
text(0,1,sprintf(['D24 square core: %.3f x %.3f x %.3f mm\nVolume %.3f cm^3; yokes %.1f mm\n' ...
    'Gap %.5f mm; Lm %.3f mH\n\nCentre Bpeak %.1f mT\nFour corner posts: mean Bpeak %.1f mT\n' ...
    'Yoke inner / middle / outer: %.1f / %.1f / %.1f mT\n\n' ...
    'Bpeak, DeltaB and Bmin are exported separately.\nCCM DC offset is included in Bpeak.\n' ...
    'Original thick pot uses the archived builder geometry.\nEdited square pot uses the saved edited-core sweep.\n' ...
    'No AEDT geometry is overwritten; no field solution run.'], ...
    D24.CoreSide_mm,D24.CoreSide_mm,D24.CoreHeight_mm,D24.CoreVolume_cm3,S24.yoke_mm, ...
    D24.Gap_mm,D24.Lm_mH,regional(4,:)), ...
    'VerticalAlignment','top','Interpreter','none','FontSize',12);
exportgraphics(fB,fullfile(out,'Flyback_Pot_D25_loss_and_B.png'),'Resolution',180);
savefig(fB,fullfile(out,'Flyback_Pot_D25_loss_and_B.fig'));
Comparison.CentreB_mT=regional(:,1); Comparison.ReturnB_mT=regional(:,2);
Comparison.YokeInnerB_mT=regional(:,3); Comparison.YokeMiddleB_mT=regional(:,4);
Comparison.YokeOuterB_mT=regional(:,5);
writetable(Comparison,fullfile(out,'Flyback_Pot_including_D25_comparison.csv'));
flybackPlotPotGeometryComparison(Comparison,G,Edited,D25,D24,windows,out);
SmallDiameterComparison=flybackComparePotD23to20(E,W,M,G,square.S,D24,out);
save(fullfile(out,'Flyback_36_3_2_Pot_design.mat'),'Summary','Comparison','Flux','Profile','D25','d25env','d25nom','Edited','D24','d24env','d24nom','S24','-append');
fid=fopen(fullfile(out,'Flyback_36_3_2_Pot_loss_report.txt'),'a');
fprintf(fid,'\nD25 square: Lm %.6f mH, gap %.6f mm, core %.6f W, copper %.6f W, total %.6f W.\n',D25.Lm_mH,D25.Gap_mm,d25env.Core_W,d25env.Copper_W,d25env.Total_W);
fprintf(fid,'D24 regional Bpeak mT: centre %.6f, return %.6f, yoke inner %.6f, middle %.6f, outer %.6f. Analytical mean-field values.\n',regional(4,:));
fclose(fid);
disp(Comparison); disp(Flux(Flux.Design==names(4),:));
fprintf('Saved Pot loss figures, CSV, audit and MAT to %s\n',out);

function [length_mm,outer,last]=spiralLength(n,inner,pitch,delta_deg)
a0=deg2rad(-90+delta_deg); a1=deg2rad(270-delta_deg);
length_mm=0;
for k=1:n
    r=inner+(n-k)*pitch;
    length_mm=length_mm+r*(a1-a0);
    if k==1, outer=r*[cos(a0) sin(a0)]; end
    last=r*[cos(a1) sin(a1)];
    if k<n
        mid=[0 -(r-pitch/2)]; finish=(r-pitch)*[cos(a0) sin(a0)];
        length_mm=length_mm+arcLength(last,mid,finish);
    end
end
end
function length_mm=arcLength(a,m,b)
c=(2*[m-a;b-a])\[sum(m.^2)-sum(a.^2);sum(b.^2)-sum(a.^2)]; c=c';
r=norm(a-c); t0=atan2(a(2)-c(2),a(1)-c(1)); tm=atan2(m(2)-c(2),m(1)-c(1)); t1=atan2(b(2)-c(2),b(1)-c(1));
d=mod(t1-t0,2*pi); if mod(tm-t0,2*pi)>d+1e-10, d=2*pi-d; end
length_mm=r*d;
end
function q=operatingPoint(L,eta,E,W,M,G,R)
ipk=sqrt(2*E.Pout/(eta*L*E.fs)); duty=ipk*L*E.fs/E.Vin;
demag=E.Vin*duty/(E.Vout*E.Np/E.Ns);
isDCM=duty+demag<1;
if isDCM
    ip=ipk*sqrt(duty/3); is=ipk*(E.Np/E.Ns)*sqrt(demag/3);
    ripple=ipk; mode='DCM';
else
    % CCM volt-second balance and input power determine the trapezoid.
    vref=E.Vout*E.Np/E.Ns;
    duty=vref/(E.Vin+vref); demag=1-duty;
    ripple=E.Vin*duty/(L*E.fs);
    meanOn=(E.Pout/eta)/(E.Vin*duty);
    ipk=meanOn+ripple/2;
    assert(meanOn-ripple/2>=-1e-10);
    ip=sqrt(duty*(meanOn^2+ripple^2/12));
    is=(E.Np/E.Ns)*sqrt(demag*(meanOn^2+ripple^2/12));
    mode='CCM';
end
bp=L*ipk/(E.Np*G.Ac_mm2*1e-6);
deltaB=L*ripple/(E.Np*G.Ac_mm2*1e-6);
pv=M.ki*E.fs^M.alpha*deltaB^M.beta*(duty^(1-M.alpha)+demag^(1-M.alpha));
pc=pv*G.Vcentre_mm3*1e-9;
pr=pv*(G.Ac_mm2/G.Ar_mm2)^M.beta*G.Vreturn_mm3*1e-9;
py=pv*G.radialEquivalent_mm3*1e-9;
p=ip^2*(sum(R.rP)+R.rPvia)*W.FacPrimary;
bus=is^2*R.rBus*W.FacSecondary;
vias=(2*((is*R.share(1))^2*R.rVia67+(is*sum(R.share(1:2)))^2*R.rVia78)+is^2*R.rPosts)*W.FacSecondary;
s=sum((is*R.share).^2.*R.rS)*W.FacSecondary+bus+vias;
a=E.IauxRms^2*(sum(R.rA)+R.rAextra)*W.FacAux;
q=struct('Lm_mH',L*1e3,'IpRms',ip,'IsRms',is,'D',duty,'Ddemag',demag,'DCM_OK',isDCM, ...
    'ConductionMode',mode,'DeltaB_mT',deltaB*1e3, ...
    'Bpk_mT',bp*1e3,'CoreCentre_W',pc,'CoreReturn_W',pr,'CoreRadial_W',py,'Core_W',pc+pr+py, ...
    'Primary_W',p,'Secondary_W',s,'Aux_W',a,'Bus_W',bus,'Vias_W',vias,'Copper_W',p+s+a,'Total_W',pc+pr+py+p+s+a);
end

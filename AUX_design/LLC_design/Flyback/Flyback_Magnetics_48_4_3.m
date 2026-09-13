%% 48:4:3 planar flyback EE redesign, independent of the 36:3:2 files
% Run this script directly. Results go to output/48_4_3.
% Preliminary electrical/mechanical design, NOT a routed AEDT model.
% Copper AC multipliers and iGSE alpha are assumptions; no thermal validation.
% J screening uses the efficiency-envelope RMS; 0.30 A primary rating is
% reported separately and is NOT an automatic temperature-rise pass.
% AUX 100 mA remains assumed winding RMS, not rectified DC output.
clear; clc; close all;

%% Electrical requirements and two explicitly separated current cases
E.Vin=2200; E.Vout=24; E.Pout=100; E.fs=100e3; E.eta=0.90;
E.Np=48; E.Ns=4; E.Naux=3; E.Lm=2.3e-3;
E.primaryRatedRms=0.30; E.auxRms=0.100; % AUX is winding RMS, not DC output
E.Iout=E.Pout/E.Vout; E.ratio=E.Np/E.Ns;
E.VauxIdeal=E.Vout*E.Naux/E.Ns; % AUX on centre leg, as in current compact 36T design
E.envelope=flybackCurrent(E,E.Pout/E.eta);
E.nominal=flybackCurrent(E,E.Pout);
% Efficiency-envelope ideal secondary average is Iout/eta, not Iout.
assert(abs(E.nominal.IsAvg-E.Iout)<1e-10);
assert(E.envelope.D+E.envelope.Ds<1,'DCM reset margin exhausted.');

%% PCB rules and design-screening choices (not universal thermal limits)
W.cu_mm=[.069 .064 .064 .064 .064 .064 .064 .069];
W.diel_mm=[.346 .406 .393 .406 .406 .406 .360];
W.boardThickness_mm=sum(W.cu_mm)+sum(W.diel_mm);
W.pLayers=[2 3]; W.sLayers=[6 7 8]; W.aLayers=[4 5];
W.busCopper_mm=.069; % external common bus allowance; no free PCB breakout layer
W.pTurns=E.Np/numel(W.pLayers); W.sTurns=E.Ns;
W.aTurns=[2 1]; % integer turns on L4/L5, series sum = 3
W.spacing_mm=.20; W.coreCopper_mm=2; W.returnCopper_mm=2;
W.corePCB_mm=1; W.edgeMargin_mm=3; W.auxWidth_mm=.20;
W.temperature_C=80; W.rho=1.724e-8*(1+.00393*(W.temperature_C-20));
W.FacP=1.15; W.FacS=1.25; W.FacA=1.15; % assumed Rac/Rdc
W.maxJ_Amm2=16; % editable screening target; temperature rise still needs validation
W.sShare=W.cu_mm(W.sLayers)/sum(W.cu_mm(W.sLayers));
assert(W.pTurns==fix(W.pTurns) && all(W.aTurns==fix(W.aTurns)) && sum(W.aTurns)==E.Naux);

%% TPG33 local material fit: verified 100 kHz / 200 mT / 80 C anchor
M.mur=3300; M.alpha=1.5; M.beta=2.6; M.anchor_Wm3=260e3;
M.anchor_f=100e3; M.anchor_B=.2;
M.k=M.anchor_Wm3/(M.anchor_f^M.alpha*M.anchor_B^M.beta);
ci=2*sqrt(pi)*gamma((M.alpha+1)/2)/gamma((M.alpha+2)/2);
M.ki=M.k/((2*pi)^(M.alpha-1)*2^(M.beta-M.alpha)*ci);
% iGSE alpha affects waveform correction even at fixed fs. Excludes DC-bias
% and gap-fringing loss; region volumes below are actual EE geometric volumes.

%% Sweep physical EE dimensions and copper widths together
S.leg_mm=12:.5:30;
S.primaryWidths_mm=0.20; % fixed primary width requested
% Secondary width is calculated to match the primary total radial breadth.
S.secondaryWidths_mm=(W.pTurns*S.primaryWidths_mm+(W.pTurns-1)*W.spacing_mm- ...
    (W.sTurns-1)*W.spacing_mm)/W.sTurns;
S.maxB_T=.20; S.minGapEach_mm=.02; S.maxGapEach_mm=2;
S.maxBoardX_mm=160; S.maxBoardY_mm=140;
% Choose the smallest core volume within 10% of the lowest feasible loss.
% Report the absolute minimum-loss candidate separately.
S.compactLossAllowance=.10;
rows=struct([]); n=0;
for leg=S.leg_mm
    for wp=S.primaryWidths_mm
        for ws=(W.pTurns*wp+(W.pTurns-1)*W.spacing_mm-(W.sTurns-1)*W.spacing_mm)/W.sTurns
            n=n+1; candidate=evaluateEE(leg,wp,ws,E,W,M,S);
            if n==1, rows=candidate; else, rows(n)=candidate; end %#ok<SAGROW>
        end
    end
end
T=struct2table(rows);
feasible=find(T.Feasible);
selectionFeasible=~isempty(feasible);
if ~selectionFeasible
    warning('Fixed 0.2 mm design fails current-density screening; export a non-feasible candidate without relaxing limits.');
    feasible=find(T.RadialBreadthConstraintOK & T.Bpk_mT<=S.maxB_T*1e3 & ...
        T.GapEach_mm>=S.minGapEach_mm & T.GapEach_mm<=S.maxGapEach_mm & ...
        T.BoardX_mm<=S.maxBoardX_mm & T.BoardY_mm<=S.maxBoardY_mm);
end
assert(~isempty(feasible),'No magnetic/mechanical candidate for fixed width.');
[minLoss,j]=min(T.TotalEnvelope_W(feasible));
MinimumLoss=rows(feasible(j));
shortlist=feasible(T.TotalEnvelope_W(feasible)<=minLoss*(1+S.compactLossAllowance));
[~,order]=sortrows([T.CoreVolume_cm3(shortlist),T.TotalEnvelope_W(shortlist)],[1 2]);
selected=shortlist(order(1)); Best=rows(selected);
assert(Best.RadialBreadthConstraintOK && Best.SecondaryRadialBreadth_mm<=Best.PrimaryRadialBreadth_mm+1e-9);
T.Selected=false(height(T),1); T.Selected(selected)=true;
T=sortrows(T,{'Feasible','TotalEnvelope_W'},{'descend','ascend'});
outDir=fullfile(fileparts(mfilename('fullpath')),'output','48_4_3');
if ~exist(outDir,'dir'), mkdir(outDir); end
writetable(T,fullfile(outDir,'Flyback_48_4_3_sweep.csv'));
writetable(struct2table(Best),fullfile(outDir,'Flyback_48_4_3_selected.csv'));

%% Conductor audit: common bus is external, not routed over the L8 winding
names=["Primary_L2";"Primary_L3";"Secondary_L6";"Secondary_L7";"Secondary_L8"; ...
    "Secondary_START_external_bus";"Secondary_END_external_bus";"AUX_L4";"AUX_L5"];
layer=[2;3;6;7;8;0;0;4;5]; % 0 = external bus, not a PCB layer
turns=[W.pTurns*ones(2,1);W.sTurns*ones(3,1);0;0;W.aTurns(:)];
width=[Best.PrimaryWidth_mm*ones(2,1);Best.SecondaryWidth_mm*ones(3,1); ...
    Best.SecondaryLeadWidth_mm*[1;1];W.auxWidth_mm*[1;1]];
thick=[W.cu_mm([2 3 6 7 8])';W.busCopper_mm*[1;1];W.cu_mm([4 5])'];
ir=[E.envelope.IpRms*ones(2,1);E.envelope.IsRms*W.sShare'; ...
    E.envelope.IsRms*[1;1];E.auxRms*[1;1]];
irNom=[E.nominal.IpRms*ones(2,1);E.nominal.IsRms*W.sShare'; ...
    E.nominal.IsRms*[1;1];E.auxRms*[1;1]];
pk=[E.envelope.Ipk*ones(2,1);E.envelope.IsPk*W.sShare'; ...
    E.envelope.IsPk*[1;1];nan(2,1)];
lengths=[Best.PrimaryLayerLength_mm*ones(2,1);Best.SecondaryLayerLength_mm*ones(3,1); ...
    Best.SecondaryStartLead_mm;Best.SecondaryEndLead_mm;Best.AuxLayerLength_mm(:)];
res=W.rho*(lengths*1e-3)./(width.*thick*1e-6);
fac=[W.FacP*ones(2,1);W.FacS*ones(5,1);W.FacA*[1;1]];
audit=table(names,layer,turns,width,thick,lengths,irNom,ir,pk,ir./(width.*thick), ...
    res,ir.^2.*res.*fac,'VariableNames',{'Conductor','Layer','Turns','Width_mm', ...
    'Copper_mm','EstimatedLength_mm','Ideal100W_RMS_A','EnvelopeRMS_A','EnvelopePeak_A', ...
    'EnvelopeJ_Amm2','Rdc80C_ohm','EstimatedEnvelopeLoss_W'});
writetable(audit,fullfile(outDir,'Flyback_48_4_3_trace_audit.csv'));
% Explicit terminal/via allowance is separate from these conductor lengths.
assert(abs(sum(audit.EstimatedEnvelopeLoss_W)+Best.InterconnectAllowance_W- ...
    Best.CopperEnvelope_W)<1e-9);
save(fullfile(outDir,'Flyback_48_4_3_design.mat'),'E','W','M','S','Best','MinimumLoss','T','audit');

%% Reproducible numerical report
report=sprintf(['48:4:3 planar EE flyback; 2200 V -> 24 V / 100 W / 100 kHz\n' ...
    'Lm target %.3f mH; ideal AUX voltage %.2f V\n' ...
    'P: L2/L3 %dT each series; S: L6/L7/L8 %dT each parallel; AUX: L4/L5 %dT + %dT series on centre leg\n' ...
    'Envelope Ip RMS %.4f A, peak %.4f A; Is RMS %.4f A, peak %.4f A\n' ...
    'Ideal 100 W Ip RMS %.4f A; Is RMS %.4f A; AUX assumed %.3f A RMS\n' ...
    'SELECTED EE centre %.1f x %.1f mm; outer legs/yoke %.1f mm; windows %.1f mm each\n' ...
    'Core overall %.1f x %.1f x %.3f mm; PCB %.1f x %.1f x %.3f mm\n' ...
    'Gap EACH of three joints %.4f mm; equivalent centre-referred gap %.4f mm\n' ...
    'P/S/AUX widths %.2f / %.2f / %.2f mm; external secondary bus width %.2f mm\n' ...
    'Bpk envelope %.2f mT; core volume %.2f cm3\n' ...
    'Envelope core / copper / total %.4f / %.4f / %.4f W\n' ...
    'Ideal 100 W core / copper / total %.4f / %.4f / %.4f W\n' ...
    'Leakage estimate primary %.3f uH / secondary %.4f uH; %.3f %% of Lm\n' ...
    'Clamp energy x fs %.3f W, NOT automatically a dissipated loss\n' ...
    'Minimum loss in selection pool %.4f W; selected compact design within %.0f %%\n' ...
    'Copper lengths include estimated breakouts; interconnect resistance is an allowance.\n' ...
    'No complete PCB routing, AEDT regeneration or thermal validation in this script.\n'], ...
    E.Lm*1e3,E.VauxIdeal,W.pTurns,W.sTurns,W.aTurns(1),W.aTurns(2), ...
    E.envelope.IpRms,E.envelope.Ipk,E.envelope.IsRms,E.envelope.IsPk, ...
    E.nominal.IpRms,E.nominal.IsRms,E.auxRms, ...
    Best.Leg_mm,Best.Leg_mm,Best.Leg_mm/2,Best.Window_mm, ...
    Best.CoreX_mm,Best.Leg_mm,Best.CoreHeight_mm,Best.BoardX_mm,Best.BoardY_mm,W.boardThickness_mm, ...
    Best.GapEach_mm,2*Best.GapEach_mm,Best.PrimaryWidth_mm,Best.SecondaryWidth_mm,W.auxWidth_mm, ...
    Best.SecondaryLeadWidth_mm,Best.Bpk_mT,Best.CoreVolume_cm3, ...
    Best.CoreEnvelope_W,Best.CopperEnvelope_W,Best.TotalEnvelope_W, ...
    Best.CoreNominal_W,Best.CopperNominal_W,Best.TotalNominal_W, ...
    Best.LeakagePri_uH,Best.LeakagePri_uH/E.ratio^2,Best.LeakagePri_uH*1e-6/E.Lm*100, ...
    Best.ClampEnergyRate_W,MinimumLoss.TotalEnvelope_W,100*S.compactLossAllowance);
fprintf('%s',report); disp(audit);
fid=fopen(fullfile(outDir,'Flyback_48_4_3_report.txt'),'w');
assert(fid>=0); fprintf(fid,'Selected Feasible = %d; original screening limits retained.\n',Best.Feasible); fprintf(fid,'%s',report); fclose(fid);

%% Sweep figure: loss, volume and the explicit selection trade-off
fig=figure('Color','w','Position',[50 60 1200 520]);
tl=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
title(tl,'48:4:3 EE redesign - efficiency-envelope estimates');
ax=nexttile(tl); hold(ax,'on'); grid(ax,'on');
for wp=S.primaryWidths_mm
    for ws=(W.pTurns*wp+(W.pTurns-1)*W.spacing_mm-(W.sTurns-1)*W.spacing_mm)/W.sTurns
        mask=(T.Feasible | ~selectionFeasible) & T.PrimaryWidth_mm==wp & T.SecondaryWidth_mm==ws;
        q=sortrows(T(mask,:),'Leg_mm');
        plot(ax,q.Leg_mm,q.TotalEnvelope_W,'DisplayName',sprintf('P %.2f / S %.2f mm',wp,ws));
    end
end
plot(ax,Best.Leg_mm,Best.TotalEnvelope_W,'kp','MarkerFaceColor','y','MarkerSize',12,'DisplayName','Selected');
xlabel(ax,'Square centre leg (mm)'); ylabel(ax,'Core + copper estimate (W)'); legend(ax,'Location','eastoutside');
ax=nexttile(tl); hold(ax,'on'); grid(ax,'on');
scatter(ax,T.CoreVolume_cm3(T.Feasible | ~selectionFeasible),T.TotalEnvelope_W(T.Feasible | ~selectionFeasible),20,T.Leg_mm(T.Feasible | ~selectionFeasible),'filled');
plot(ax,Best.CoreVolume_cm3,Best.TotalEnvelope_W,'kp','MarkerFaceColor','y','MarkerSize',12);
title(ax,sprintf('Selected screening pass: %d',Best.Feasible));
xlabel(ax,'Core volume (cm^3)'); ylabel(ax,'Core + copper estimate (W)');
cb=colorbar(ax); cb.Label.String='Centre leg (mm)';
exportgraphics(fig,fullfile(outDir,'Flyback_48_4_3_sweep.png'),'Resolution',170);

%% Mechanical winding envelope and layer assignment, not a routing drawing
fig2=figure('Color','w','Position',[60 60 1100 530]);
tl=tiledlayout(fig2,1,2,'TileSpacing','compact','Padding','compact');
title(tl,'Selected 48:4:3 EE - winding envelopes (not connected trace routing)');
ax=nexttile(tl); hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
rectangle(ax,'Position',[-Best.BoardX_mm/2,-Best.BoardY_mm/2,Best.BoardX_mm,Best.BoardY_mm],'LineStyle',':');
for b=[-Best.CoreX_mm/2 Best.Leg_mm/2; -Best.Leg_mm/2 Best.Leg_mm; Best.CoreX_mm/2-Best.Leg_mm/2 Best.Leg_mm/2]'
    rectangle(ax,'Position',[b(1),-Best.Leg_mm/2,b(2),Best.Leg_mm],'FaceColor',[.7 .7 .7]);
end
spec=[W.sTurns Best.SecondaryWidth_mm;W.pTurns Best.PrimaryWidth_mm;max(W.aTurns) W.auxWidth_mm];
colors=[.1 .3 .8;.8 .1 .1;0 .5 .2];
for k=1:3
    for turn=1:spec(k,1)
        pad=2*W.coreCopper_mm+spec(k,2)+2*(turn-1)*(spec(k,2)+W.spacing_mm);
        sx=Best.Leg_mm+pad; sy=sx; cx=0;
        if k==3
            r=Best.Leg_mm/2+W.coreCopper_mm+ ...
                (W.pTurns*Best.PrimaryWidth_mm+(W.pTurns-1)*W.spacing_mm)/2;
            sx=2*(r+(turn-1-(spec(k,1)-1)/2)*(W.auxWidth_mm+W.spacing_mm)); sy=sx;
        end
        rectangle(ax,'Position',[cx-sx/2,-sy/2,sx,sy],'EdgeColor',colors(k,:));
    end
end
xlabel(ax,'X (mm)'); ylabel(ax,'Y (mm)');
title(ax,sprintf('P red / S blue / AUX green; PCB %.1f x %.1f mm',Best.BoardX_mm,Best.BoardY_mm));
ax=nexttile(tl); hold(ax,'on'); axis(ax,[0 100 0 9]); axis(ax,'off');
labels={'Primary access (routing pending)','Primary 24T (series)','Primary 24T (series)', ...
    'AUX 2T - centre leg','AUX 1T - centre leg','Secondary 4T (parallel)', ...
    'Secondary 4T (parallel)','Secondary 4T (parallel)'};
for k=1:8
    plot(ax,[10 85],[9-k 9-k],'Color',[.4 .4 .4],'LineWidth',2);
    text(ax,1,9-k,sprintf('L%d',k)); text(ax,12,9-k+.2,labels{k});
end
title(ax,sprintf('PCB %.3f mm; P-S copper gap %.3f mm',W.boardThickness_mm,Best.PSgap_mm));
exportgraphics(fig2,fullfile(outDir,'Flyback_48_4_3_selected_geometry.png'),'Resolution',170);

%% Matched-winding A/B/C mechanical comparison
[Schemes,Comparison]=flybackCompareABC484(Best,E,W,M,S,outDir);
save(fullfile(outDir,'Flyback_48_4_3_design.mat'),'Schemes','Comparison','-append');

function C=flybackCurrent(E,power)
C.Ipk=sqrt(2*power/(E.Lm*E.fs)); C.D=C.Ipk*E.Lm*E.fs/E.Vin;
C.Ds=E.Vin*C.D/(E.Vout*E.ratio); C.IpRms=C.Ipk*sqrt(C.D/3);
C.IsPk=C.Ipk*E.ratio; C.IsRms=C.IsPk*sqrt(C.Ds/3); C.IsAvg=C.IsPk*C.Ds/2;
end

function R=evaluateEE(leg,wp,ws,E,W,M,S)
mu0=4*pi*1e-7;
np=W.pTurns; ns=W.sTurns; na=max(W.aTurns);
bp=np*wp+(np-1)*W.spacing_mm; bs=ns*ws+(ns-1)*W.spacing_mm;
ba=na*W.auxWidth_mm+(na-1)*W.spacing_mm;
build=max([bp bs ba]);
% The entire radial copper band plus clearances must fit each EE window.
win=ceil((W.coreCopper_mm+build+W.returnCopper_mm)*2)/2;
coreX=2*leg+2*win; outer=leg/2; yoke=leg/2;
pitch=leg/2+win+outer/2; Ac=leg^2*1e-6; Ao=Ac/2; Ay=Ao;
h0=yoke+W.boardThickness_mm/2+W.corePCB_mm;
v0=2*(h0-yoke/2)*1e-3;
rc0=v0/(mu0*M.mur*Ac)+(v0/(mu0*M.mur*Ao)+2*pitch*1e-3/(mu0*M.mur*Ay))/2;
gap=(E.Np^2/E.Lm-rc0)/((1/(mu0*Ac)+1/(2*mu0*Ao))*(1-1/M.mur));
h=h0-gap*1e3/2; stem=h-yoke;
v=2*(h-yoke/2)*1e-3;
rc=v/(mu0*M.mur*Ac)+(v/(mu0*M.mur*Ao)+2*pitch*1e-3/(mu0*M.mur*Ay))/2;
lmCheck=E.Np^2/(rc+gap*(1/(mu0*Ac)+1/(2*mu0*Ao)));
assert(abs(lmCheck/E.Lm-1)<1e-10);
volume=2*stem*(leg+2*outer)*leg+2*coreX*leg*yoke;
% Allow an extra pitch for top-centre spiral transitions and a terminal lane.
leadWidth=ceil(max(ws*sum(W.cu_mm(W.sLayers))/W.busCopper_mm, ...
    E.envelope.IsRms/(W.maxJ_Amm2*W.busCopper_mm))*2)/2;
boardY=ceil(2*(leg/2+W.coreCopper_mm+build+max(wp,ws)+W.spacing_mm+leadWidth+W.edgeMargin_mm));
boardX=ceil(coreX+2*W.edgeMargin_mm);
% Full-turn square MLT sums + explicit provisional lead-length budget.
pCoil=sum(4*(leg+2*W.coreCopper_mm+wp+2*(0:np-1)*(wp+W.spacing_mm)));
sCoil=sum(4*(leg+2*W.coreCopper_mm+ws+2*(0:ns-1)*(ws+W.spacing_mm)));
aRadius=leg/2+W.coreCopper_mm+(np*wp+(np-1)*W.spacing_mm)/2;
aCoil=8*aRadius*W.aTurns;
pOuter=leg/2+W.coreCopper_mm+wp/2+(np-1)*(wp+W.spacing_mm);
sInner=leg/2+W.coreCopper_mm+ws/2;
sOuter=sInner+(ns-1)*(ws+W.spacing_mm);
aOuter=aRadius+(W.aTurns-1)*(W.auxWidth_mm+W.spacing_mm)/2;
pLength=pCoil+max(0,boardY/2-pOuter); % one external lead per series layer
aLength=aCoil+max(0,boardY/2-aOuter);
sLength=sCoil+ns*(ws+W.spacing_mm); % top transition pitch per full turn
lane=ws/2+leadWidth/2+W.spacing_mm;
sLeads=[lane+boardY/2-(sOuter+ws+W.spacing_mm),lane+boardY/2-sInner];
assert(all(sLeads>0));
rp=sum(W.rho*pLength*1e-3./(wp*W.cu_mm(W.pLayers)*1e-6));
rs=W.rho*sLength*1e-3./(ws*W.cu_mm(W.sLayers)*1e-6);
ra=sum(W.rho*aLength*1e-3./(W.auxWidth_mm*W.cu_mm(W.aLayers)*1e-6));
rlead=W.rho*sum(sLeads)*1e-3/(leadWidth*W.busCopper_mm*1e-6);
% Explicit equivalent resistance allowances pending via/pad routing.
rpConnect=.005; rsConnect=.0001; raConnect=.01;
Pp=E.envelope.IpRms^2*rp*W.FacP;
Ps=sum((E.envelope.IsRms*W.sShare).^2.*rs)*W.FacS+E.envelope.IsRms^2*rlead*W.FacS;
Pa=E.auxRms^2*ra*W.FacA;
Pconnect=E.envelope.IpRms^2*rpConnect+E.envelope.IsRms^2*rsConnect+E.auxRms^2*raConnect;
Pcu=Pp+Ps+Pa+Pconnect;
scale=(E.nominal.IpRms/E.envelope.IpRms)^2;
PcuNom=(Pp+Ps+Pconnect-E.auxRms^2*raConnect)*scale+Pa+E.auxRms^2*raConnect;
B=E.Lm*E.envelope.Ipk/(E.Np*Ac);
Bn=E.Lm*E.nominal.Ipk/(E.Np*Ac);
Pv=M.ki*E.fs^M.alpha*B^M.beta*(E.envelope.D^(1-M.alpha)+E.envelope.Ds^(1-M.alpha));
Pvn=M.ki*E.fs^M.alpha*Bn^M.beta*(E.nominal.D^(1-M.alpha)+E.nominal.Ds^(1-M.alpha));
% Equal centre/outer/yoke flux density because each return has half the area.
Pcore=Pv*volume*1e-9; PcoreNom=Pvn*volume*1e-9;
f=0; energyThickness=0; delta=zeros(1,8);
delta(W.pLayers)=np/E.Np; delta(W.sLayers)=-W.sShare;
for k=1:8
    fn=f+delta(k); energyThickness=energyThickness+W.cu_mm(k)*(f^2+f*fn+fn^2)/3;
    f=fn;
    if k<8, energyThickness=energyThickness+W.diel_mm(k)*f^2; end
end
assert(abs(f)<1e-12);
% Same 1-D field-energy approximation as the original sweep; AUX open.
% Lsigma=Lpp-2*n*M+n^2*Lss. Not an exact Maxwell short-circuit inductance.
mlt=.5*(pCoil/np+sCoil/ns);
llk=mu0*E.Np^2*(mlt/min(bp,bs))*energyThickness*1e-3;
Jp=E.primaryRatedRms/(wp*min(W.cu_mm(W.pLayers)));
Js=max(E.envelope.IsRms*W.sShare./(ws*W.cu_mm(W.sLayers)));
Jl=E.envelope.IsRms/(leadWidth*W.busCopper_mm);
Ja=E.auxRms/(W.auxWidth_mm*min(W.cu_mm(W.aLayers)));
breadthOK=bs<=bp+1e-9 && bs>=.95*bp; % hard constraint: 95-100% of primary
ok=breadthOK && B<=S.maxB_T && gap*1e3>=S.minGapEach_mm && gap*1e3<=S.maxGapEach_mm && stem>0 && ...
    boardX<=S.maxBoardX_mm && boardY<=S.maxBoardY_mm && max([E.envelope.IpRms/(wp*min(W.cu_mm(W.pLayers))) Js Jl Ja])<=W.maxJ_Amm2;
R=struct('PrimaryRadialBreadth_mm',bp,'SecondaryRadialBreadth_mm',bs, ...
    'RadialBreadthConstraintOK',breadthOK,'Leg_mm',leg,'PrimaryWidth_mm',wp,'SecondaryWidth_mm',ws, ...
    'SecondaryLeadWidth_mm',leadWidth,'Window_mm',win,'CoreX_mm',coreX, ...
    'CoreHeight_mm',2*h+gap*1e3,'BoardX_mm',boardX,'BoardY_mm',boardY, ...
    'GapEach_mm',gap*1e3,'CoreVolume_cm3',volume*1e-3,'Bpk_mT',B*1e3, ...
    'PrimaryRatedJ_Amm2',Jp,'PrimaryEnvelopeJ_Amm2',E.envelope.IpRms/(wp*min(W.cu_mm(W.pLayers))),'SecondaryJ_Amm2',Js,'SecondaryLeadJ_Amm2',Jl, ...
    'PrimaryLayerLength_mm',pLength,'SecondaryLayerLength_mm',sLength,'AuxLayerLength_mm',aLength, ...
    'SecondaryStartLead_mm',sLeads(1),'SecondaryEndLead_mm',sLeads(2), ...
    'CoreEnvelope_W',Pcore,'CopperEnvelope_W',Pcu,'TotalEnvelope_W',Pcore+Pcu, ...
    'PrimaryEnvelope_W',Pp,'SecondaryEnvelope_W',Ps,'AuxEnvelope_W',Pa, ...
    'InterconnectAllowance_W',Pconnect,'PrimaryRatedLoss_W',E.primaryRatedRms^2*(rp*W.FacP+rpConnect), ...
    'CoreNominal_W',PcoreNom,'CopperNominal_W',PcuNom,'TotalNominal_W',PcoreNom+PcuNom, ...
    'LeakagePri_uH',llk*1e6,'ClampEnergyRate_W',.5*llk*E.envelope.Ipk^2*E.fs, ...
    'PSgap_mm',sum(W.diel_mm(3:5))+sum(W.cu_mm(4:5)),'Feasible',ok);
end

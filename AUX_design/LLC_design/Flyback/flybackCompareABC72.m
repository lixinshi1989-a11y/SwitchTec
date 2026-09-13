function [G,T]=flybackCompareABC72(Best,E,W,M,S,outDir)
% Fair A/B/C/D comparison: hold the selected EE winding design fixed.
% B primary width and series length are recalculated; AC factors are fixed.
% All connection losses remain provisional; this is not three individually optimized/routed designs.
% A split-leg leakage is deliberately NaN: the stacked 1-D model is invalid.
mu0=4*pi*1e-7; leg=Best.Leg_mm; a=leg/2;
bp=W.pTurns*Best.PrimaryWidth_mm+(W.pTurns-1)*W.spacing_mm;
bs=W.sTurns*Best.SecondaryWidth_mm+(W.sTurns-1)*W.spacing_mm;
rp=a+W.coreCopper_mm+bp; rs=a+W.coreCopper_mm+bs;
ba=W.aTurns*W.auxWidth_mm+(W.aTurns-1)*W.spacing_mm;
lateralGap=10; % retained split-leg P-S copper clearance design target
base=struct('Scheme',"",'CoreType',"",'Description',"",'Leg_mm',leg, ...
    'CoreX_mm',0,'CoreDepth_mm',leg,'CoreHeight_mm',0,'HalfHeight_mm',0, ...
    'Yoke_mm',0,'Window_mm',0,'CoreVolume_cm3',0,'BoardX_mm',0, ...
    'BoardY_mm',Best.BoardY_mm,'BoardThickness_mm',W.boardThickness_mm, ...
    'GapEach_mm',0,'GapJoints',0,'EquivalentGap_mm',0,'Lm_mH',0, ...
    'Bpk_mT',Best.Bpk_mT,'PSCopperLateral_mm',nan,'PSCopperVertical_mm',nan, ...
    'PrimaryWidth_mm',Best.PrimaryWidth_mm,'SecondaryWidth_mm',Best.SecondaryWidth_mm, ...
    'SecondaryLeadWidth_mm',Best.SecondaryLeadWidth_mm, ...
    'CoreEnvelope_W',0,'CopperEnvelope_W',Best.CopperEnvelope_W,'TotalEnvelope_W',0, ...
    'CoreNominal_W',0,'TotalNominal_W',0,'LeakagePriEstimate_uH',nan, ...
    'LeakageModel',"",'WithinBoardLimits',false,'WithinGapLimits',false, ...
    'LegCenters_mm',[],'LegWidths_mm',[],'PrimaryCenter_mm',0,'SecondaryCenter_mm',0, ...
    'BoardLeft_mm',0,'BoardRight_mm',0,'AuxCenter_mm',0,'AuxLegWidth_mm',leg, ...
    'AuxCenteredOnPrimary',false,'AuxRadialCenter_mm',nan, ...
    'AuxTraceX_mm',nan,'AuxTurnSides_mm',[],'AuxOuterSide_mm',0, ...
    'AuxLayer1',W.aLayers(1),'AuxLayer2',W.aLayers(2), ...
    'PrimaryTurnsPerLayerPerLeg',W.pTurns,'PrimaryLayerCount',numel(W.pLayers), ...
    'SecondaryEnvelope_W',Best.SecondaryEnvelope_W,'SecondaryJ_Amm2',0,'CurrentDensityOK',false, ...
    'PrimaryLegCount',1,'PrimaryEnvelope_W',Best.PrimaryEnvelope_W, ...
    'PrimaryLengthTotal_mm',Best.PrimaryLayerLength_mm*numel(W.pLayers), ...
    'PrimaryRadialBreadth_mm',bp,'SecondaryRadialBreadth_mm',bs,'TraceSpacing_mm',W.spacing_mm, ...
    'AuxIdealVoltage_V',E.Vout*E.Naux/E.Ns,'AuxEnvelope_W',0);
G=repmat(base,1,4);
for k=1:4
    rp=a+W.coreCopper_mm+bp; rs=a+W.coreCopper_mm+bs;
    q=base; q.Scheme=string(char('A'+k-1));
    if k~=3
        q.CoreType="UU"; q.Yoke_mm=leg;
        if k==1
            q.Description="Split legs: P left, S/AUX right";
            pitch=ceil((rp+rs+lateralGap)*2)/2;
            q.PrimaryCenter_mm=-pitch/2; q.SecondaryCenter_mm=pitch/2;
            q.PSCopperLateral_mm=pitch-rp-rs;
            q.LeakageModel="Not estimated: split-leg needs 3-D field model";
        else
            pLayers=[2 3]; if k==4, pLayers=[1 2 3]; end
            n=E.Np/(2*numel(pLayers)); assert(n==floor(n));
            q.PrimaryTurnsPerLayerPerLeg=n; q.PrimaryLayerCount=numel(pLayers); q.PrimaryLegCount=2;
            q.PrimaryWidth_mm=0.20;
            q.PrimaryRadialBreadth_mm=n*q.PrimaryWidth_mm+(n-1)*W.spacing_mm;
            q.SecondaryRadialBreadth_mm=q.PrimaryRadialBreadth_mm;
            q.SecondaryWidth_mm=(q.SecondaryRadialBreadth_mm-(W.sTurns-1)*W.spacing_mm)/W.sTurns;
            assert(q.SecondaryWidth_mm>0);
            rp=a+W.coreCopper_mm+q.PrimaryRadialBreadth_mm;
            rs=a+W.coreCopper_mm+q.SecondaryRadialBreadth_mm;
            % Preserve external bus width; recalculate layer and breakout lengths.
            sw=q.SecondaryWidth_mm; ns=W.sTurns;
            sLength=sum(4*(leg+2*W.coreCopper_mm+sw+2*(0:ns-1)*(sw+W.spacing_mm)))+ns*(sw+W.spacing_mm);
            sInner=a+W.coreCopper_mm+sw/2;
            sOuter=sInner+(ns-1)*(sw+W.spacing_mm);
            lane=sw/2+q.SecondaryLeadWidth_mm/2+W.spacing_mm;
            sLeads=[lane+q.BoardY_mm/2-(sOuter+sw+W.spacing_mm),lane+q.BoardY_mm/2-sInner];
            rS=W.rho*sLength*1e-3./(sw*W.cu_mm(W.sLayers)*1e-6);
            rBus=W.rho*sum(sLeads)*1e-3/(q.SecondaryLeadWidth_mm*W.busCopper_mm*1e-6);
            q.SecondaryEnvelope_W=(sum((E.envelope.IsRms*W.sShare).^2.*rS)+E.envelope.IsRms^2*rBus)*W.FacS;
            rpb=a+W.coreCopper_mm+q.PrimaryRadialBreadth_mm;
            pitch=rpb+rs+2.0; % B: exactly 2 mm between nearest copper edges
            layerLabel='L2/L3'; if k==4, layerLabel='L1/L2/L3'; end
            q.Description=sprintf('P left/right %s: %dT each, series aiding',layerLabel,n);
            q.PrimaryCenter_mm=-pitch/2; q.SecondaryCenter_mm=pitch/2;
            q.PSCopperLateral_mm=pitch-rpb-rs;
            q.PSCopperVertical_mm=Best.PSgap_mm;
            q.LeakageModel="Not estimated: two-leg P requires 3-D model";
            % B has four and D six series coils; one bridge and two terminal leads.
            % Shared lead-length budget distributed over occupied layers; vias provisional.
            coil=sum(4*(leg+2*W.coreCopper_mm+q.PrimaryWidth_mm+ ...
                2*(0:n-1)*(q.PrimaryWidth_mm+W.spacing_mm)));
            leads=2*max(0,Best.BoardY_mm/2-rpb+q.PrimaryWidth_mm/2);
            lengthPerLayer=2*coil+(pitch+leads)/numel(pLayers);
            q.PrimaryLengthTotal_mm=numel(pLayers)*lengthPerLayer;
            assert(q.PrimaryLegCount*q.PrimaryLayerCount*n==E.Np);
            resistance=sum(W.rho*lengthPerLayer*1e-3./ ...
                (q.PrimaryWidth_mm*W.cu_mm(pLayers)*1e-6));
            q.PrimaryEnvelope_W=E.envelope.IpRms^2*resistance*W.FacP;
        end
        q.CoreX_mm=pitch+leg; q.Window_mm=pitch-leg;
        q.LegCenters_mm=[-pitch/2 pitch/2]; q.LegWidths_mm=[leg leg];
        area=leg^2*1e-6;
        h0=leg+W.boardThickness_mm/2+W.corePCB_mm;
        le0=2*(pitch+2*(h0-leg/2))*1e-3;
        gap=(mu0*area*E.Np^2/E.Lm-le0/M.mur)/(2*(1-1/M.mur));
        q.HalfHeight_mm=h0-gap*1e3/2;
        le=2*(pitch+2*(q.HalfHeight_mm-leg/2))*1e-3;
        q.Lm_mH=E.Np^2/(le/(mu0*M.mur*area)+2*gap/(mu0*area))*1e3;
        q.GapEach_mm=gap*1e3; q.GapJoints=2;
        stem=q.HalfHeight_mm-leg;
        volume=2*q.CoreX_mm*leg*leg+4*leg*leg*stem;
        q.CoreVolume_cm3=volume/1000;
    else
        q.CoreType="EE"; q.Description="P/S centre; AUX right outer leg";
        q.CoreX_mm=Best.CoreX_mm; q.Window_mm=Best.Window_mm; q.Yoke_mm=leg/2;
        q.GapEach_mm=Best.GapEach_mm; q.GapJoints=3;
        q.HalfHeight_mm=(Best.CoreHeight_mm-Best.GapEach_mm)/2;
        q.CoreVolume_cm3=Best.CoreVolume_cm3; q.Lm_mH=E.Lm*1e3;
        q.LegCenters_mm=[-q.CoreX_mm/2+leg/4 0 q.CoreX_mm/2-leg/4];
        q.LegWidths_mm=[leg/2 leg leg/2];
        q.PSCopperVertical_mm=Best.PSgap_mm;
        q.LeakagePriEstimate_uH=Best.LeakagePri_uH;
        q.LeakageModel="1-D stacked energy, AUX open; no fringing";
    end
    q.AuxCenter_mm=q.SecondaryCenter_mm;
    if k==3
        q.AuxCenter_mm=q.LegCenters_mm(3); q.AuxLegWidth_mm=leg/2;
        q.AuxIdealVoltage_V=E.Vout*E.Naux/E.Ns/2;
    end
    % UU AUX surrounds a full leg, EE AUX surrounds a half-width outer leg.
    auxLength=Best.AuxLayerLength_mm;
    if k~=3, auxLength=auxLength+W.aTurns*leg; end
    q.AuxOuterSide_mm=q.AuxLegWidth_mm+2*W.coreCopper_mm+2*ba;
    if ismember(k,[2 4])
        q.AuxCenteredOnPrimary=true;
        q.AuxRadialCenter_mm=leg/2+W.coreCopper_mm+q.PrimaryRadialBreadth_mm/2;
        q.AuxTraceX_mm=q.AuxCenter_mm-q.AuxRadialCenter_mm;
        q.AuxTurnSides_mm=2*(q.AuxRadialCenter_mm+ ...
            ((0:W.aTurns-1)-(W.aTurns-1)/2)*(W.auxWidth_mm+W.spacing_mm));
        q.AuxOuterSide_mm=max(q.AuxTurnSides_mm)+W.auxWidth_mm;
        oldCoil=sum(4*(leg+2*W.coreCopper_mm+W.auxWidth_mm+ ...
            2*(0:W.aTurns-1)*(W.auxWidth_mm+W.spacing_mm)));
        auxLength=auxLength+sum(4*q.AuxTurnSides_mm)-oldCoil;
        assert(ba<=q.PrimaryRadialBreadth_mm);
        q.Description=string(q.Description)+"; AUX radial band centred in P band";
    end
    q.AuxEnvelope_W=E.auxRms^2*sum(W.rho*auxLength*1e-3./ ...
        (W.auxWidth_mm*W.cu_mm(W.aLayers)*1e-6))*W.FacA;
    q.CopperEnvelope_W=Best.CopperEnvelope_W-Best.AuxEnvelope_W+q.AuxEnvelope_W ...
        -Best.PrimaryEnvelope_W+q.PrimaryEnvelope_W-Best.SecondaryEnvelope_W+q.SecondaryEnvelope_W;
    q.EquivalentGap_mm=2*q.GapEach_mm; % EE outer gaps act in parallel
    q.CoreHeight_mm=2*q.HalfHeight_mm+q.GapEach_mm;
    q.BoardLeft_mm=floor(min([-q.CoreX_mm/2,q.PrimaryCenter_mm-rp, ...
        q.SecondaryCenter_mm-rs,q.AuxCenter_mm-q.AuxOuterSide_mm/2])-W.edgeMargin_mm);
    q.BoardRight_mm=ceil(max([q.CoreX_mm/2,q.PrimaryCenter_mm+rp, ...
        q.SecondaryCenter_mm+rs,q.AuxCenter_mm+q.AuxOuterSide_mm/2])+W.edgeMargin_mm);
    if k==3, q.BoardLeft_mm=-Best.BoardX_mm/2; q.BoardRight_mm=Best.BoardX_mm/2; end
    q.BoardX_mm=q.BoardRight_mm-q.BoardLeft_mm;
    % Same Ae and waveform => same local loss density; actual core volume varies.
    q.CoreEnvelope_W=Best.CoreEnvelope_W*q.CoreVolume_cm3/Best.CoreVolume_cm3;
    q.CoreNominal_W=Best.CoreNominal_W*q.CoreVolume_cm3/Best.CoreVolume_cm3;
    q.TotalEnvelope_W=q.CoreEnvelope_W+q.CopperEnvelope_W;
    q.TotalNominal_W=q.CoreNominal_W+Best.CopperNominal_W-Best.AuxEnvelope_W+q.AuxEnvelope_W ...
        +(q.PrimaryEnvelope_W-Best.PrimaryEnvelope_W+q.SecondaryEnvelope_W-Best.SecondaryEnvelope_W)*(E.nominal.IpRms/E.envelope.IpRms)^2;
    q.SecondaryJ_Amm2=max(E.envelope.IsRms*W.sShare./(q.SecondaryWidth_mm*W.cu_mm(W.sLayers)));
    q.CurrentDensityOK=max(q.SecondaryJ_Amm2,E.envelope.IpRms/(q.PrimaryWidth_mm*min(W.cu_mm([2 3]))))<=W.maxJ_Amm2;
    q.WithinBoardLimits=q.BoardX_mm<=S.maxBoardX_mm && q.BoardY_mm<=S.maxBoardY_mm;
    q.WithinGapLimits=q.GapEach_mm>=S.minGapEach_mm && q.GapEach_mm<=S.maxGapEach_mm;
    assert(abs(q.Lm_mH-E.Lm*1e3)<1e-9 && q.HalfHeight_mm>q.Yoke_mm);
    assert(abs(q.HalfHeight_mm-q.Yoke_mm+q.GapEach_mm/2- ...
        W.boardThickness_mm/2-W.corePCB_mm)<1e-10);
    if k==1, assert(q.PSCopperLateral_mm>=lateralGap); end
    if k==2 || k==4, assert(abs(q.PSCopperLateral_mm-2)<1e-9); end
    G(k)=q;
end
% Export scalar fields; vector drawing coordinates remain in Schemes/MAT.
scalars=rmfield(G,{'LegCenters_mm','LegWidths_mm','AuxTurnSides_mm'});
T=struct2table(scalars);
writetable(T,fullfile(outDir,'Flyback_72_6_4_ABCD_comparison.csv'));
disp(T(:,{'Scheme','CoreX_mm','CoreHeight_mm','BoardX_mm','BoardY_mm', ...
    'GapEach_mm','CoreVolume_cm3','TotalEnvelope_W','LeakagePriEstimate_uH','WithinBoardLimits'}));
fid=fopen(fullfile(outDir,'Flyback_72_6_4_ABCD_report.txt'),'w'); assert(fid>=0);
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'72:6:4 A/B/C/D comparison, same selected leg; P width fixed 0.2 mm\n');
fprintf(fid,'P L1/L2/L3: %d each series; S L6/L7/L8: %d each parallel; AUX L4/L5: %d each series\n', ...
    W.pTurns,W.sTurns,W.aTurns);
for q=G
    fprintf(fid,['\n%s: %s\nCore %.1f x %.1f x %.3f mm; volume %.3f cm3\n' ...
        'PCB %.1f x %.1f mm; gap %.4f mm at each of %d joints; Lm %.3f mH\n' ...
        'Envelope core/copper/total %.4f / %.4f / %.4f W; ideal100W total %.4f W\n' ...
        'Leakage primary %.3f uH: %s\nWithin board limits: %d; within gap limits: %d\n'], ...
        q.Scheme,q.Description,q.CoreX_mm,leg,q.CoreHeight_mm,q.CoreVolume_cm3, ...
        q.BoardX_mm,q.BoardY_mm,q.GapEach_mm,q.GapJoints,q.Lm_mH, ...
        q.CoreEnvelope_W,q.CopperEnvelope_W,q.TotalEnvelope_W,q.TotalNominal_W, ...
        q.LeakagePriEstimate_uH,q.LeakageModel,q.WithinBoardLimits,q.WithinGapLimits);
    fprintf(fid,'P: %d legs, %d layers, %d turns/leg/layer; width %.4f mm; S width %.4f mm; spacing %.3f mm; P length %.1f mm\n',q.PrimaryLegCount,q.PrimaryLayerCount,q.PrimaryTurnsPerLayerPerLeg,q.PrimaryWidth_mm,q.SecondaryWidth_mm,q.TraceSpacing_mm,q.PrimaryLengthTotal_mm);
    fprintf(fid,'Secondary J %.3f A/mm2; envelope current-density pass %d\n',q.SecondaryJ_Amm2,q.CurrentDensityOK);
    fprintf(fid,'AUX ideal voltage %.2f V; AUX copper loss %.5f W\n',q.AuxIdealVoltage_V,q.AuxEnvelope_W);
end
fprintf(fid,['\nB primary copper length is recalculated; connection resistance and AC factors remain provisional.\n' ...
    'B: four series coils; D: six series coils, opposite physical winding polarity on opposite UU legs; one bridge plus two terminal leads.\n' ...
    'A/B/D leakage is not estimated; geometry drawings are envelopes, not PCB routing.\n' ...
    'Schemes A/B/D are not independently optimized; they use the selected C winding design.\n']);

fig=figure('Color','w','Position',[20 40 2240 1040]);
tl=tiledlayout(fig,2,4,'TileSpacing','compact','Padding','compact');
title(tl,{'72:6:4 - A split-leg UU | B two-leg primary UU | C centre-wound EE | D two-leg P on L1/L2/L3', ...
    'P width 0.2 mm; secondary breadth matches local primary; winding envelopes, not connected PCB routing'});
for k=1:4
    q=G(k); ax=nexttile(tl,k); hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
    rectangle(ax,'Position',[q.BoardLeft_mm,-q.BoardY_mm/2,q.BoardX_mm,q.BoardY_mm],'LineStyle',':');
    for j=1:numel(q.LegCenters_mm)
        rectangle(ax,'Position',[q.LegCenters_mm(j)-q.LegWidths_mm(j)/2,-leg/2,q.LegWidths_mm(j),leg], ...
            'FaceColor',[.72 .72 .72]);
    end
    drawTurns(ax,q.SecondaryCenter_mm,leg,W.sTurns,q.SecondaryWidth_mm,W,[.1 .3 .8]);
    drawTurns(ax,q.PrimaryCenter_mm,leg,q.PrimaryTurnsPerLayerPerLeg,q.PrimaryWidth_mm,W,[.8 .1 .1]);
    if k==2 || k==4, drawTurns(ax,q.SecondaryCenter_mm,leg,q.PrimaryTurnsPerLayerPerLeg,q.PrimaryWidth_mm,W,[.8 .1 .1]); end
    if q.AuxCenteredOnPrimary
        for side=q.AuxTurnSides_mm
            rectangle(ax,'Position',[q.AuxCenter_mm-side/2,-side/2,side,side],'EdgeColor',[0 .5 .2]);
        end
    else
        drawTurns(ax,q.AuxCenter_mm,leg,W.aTurns,W.auxWidth_mm,W,[0 .5 .2],q.AuxLegWidth_mm);
    end
    if k==2 || k==4
        x1=q.PrimaryCenter_mm+leg/2+W.coreCopper_mm+q.PrimaryRadialBreadth_mm;
        x2=q.SecondaryCenter_mm-leg/2-W.coreCopper_mm-q.SecondaryRadialBreadth_mm;
        plot(ax,[x1 x2],[0 0],'-','Color',[.9 .35 0],'LineWidth',1.5);
        plot(ax,x1,0,'<','Color',[.9 .35 0]); plot(ax,x2,0,'>','Color',[.9 .35 0]);
        text(ax,(x1+x2)/2,2,'2 mm','HorizontalAlignment','center','Color',[.9 .35 0],'FontWeight','bold');
    end
    flybackOverallDimensions(ax,q.BoardLeft_mm,q.BoardRight_mm,-q.BoardY_mm/2,q.BoardY_mm/2,'PCB X','PCB Y');
    xlabel(ax,'X (mm)'); ylabel(ax,'Y (mm)');
    title(ax,{sprintf('%s - %s',q.Scheme,q.CoreType), ...
        sprintf('PCB %.0f x %.0f mm; core %.2f W; total %.2f W',q.BoardX_mm,q.BoardY_mm,q.CoreEnvelope_W,q.TotalEnvelope_W), ...
        sprintf('Core X/Y %.1f / %.1f mm; P %.3f mm; J pass %d',q.CoreX_mm,leg,q.PrimaryWidth_mm,q.CurrentDensityOK)});
    ax=nexttile(tl,k+4); hold(ax,'on'); axis(ax,[0 100 0 9]); axis(ax,'off');
    for j=1:8
        plot(ax,[8 94],[9-j 9-j],'Color',[.8 .8 .8]); text(ax,1,9-j,sprintf('L%d',j));
    end
    if k~=3, px=[12 42]; sx=[59 89]; else, px=[30 78]; sx=px; end
    pLayers=W.pLayers; if k==2, pLayers=[2 3]; elseif k==4, pLayers=[1 2 3]; end
    for j=pLayers
        plot(ax,px,[9-j 9-j],'Color',[.8 .1 .1],'LineWidth',5);
        if k==2 || k==4
            plot(ax,sx,[9-j 9-j],'Color',[.8 .1 .1],'LineWidth',5);
            text(ax,mean(sx),9-j+.25,sprintf('P %dT',q.PrimaryTurnsPerLayerPerLeg),'HorizontalAlignment','center');
        end
        text(ax,mean(px),9-j+.25,sprintf('P %dT',q.PrimaryTurnsPerLayerPerLeg),'HorizontalAlignment','center');
    end
    for j=W.sLayers
        plot(ax,sx,[9-j 9-j],'Color',[.1 .3 .8],'LineWidth',5);
        text(ax,mean(sx),9-j+.25,sprintf('S %dT',W.sTurns),'HorizontalAlignment','center');
    end
    auxLane=sx;
    if k==3, auxLane=[78 94]; end
    for j=W.aLayers
        plot(ax,auxLane,[9-j 9-j],'Color',[0 .5 .2],'LineWidth',5);
        text(ax,mean(auxLane),9-j+.25,sprintf('AUX %dT',W.aTurns),'HorizontalAlignment','center');
    end
    text(ax,50,8.5,q.Description,'HorizontalAlignment','center','FontSize',10);
    if k~=3
        title(ax,sprintf('P-S lateral %.1f mm; leakage: needs 3-D model',q.PSCopperLateral_mm));
    else
        title(ax,sprintf('P-S vertical %.3f mm; leakage estimate %.2f uH',q.PSCopperVertical_mm,q.LeakagePriEstimate_uH));
    end
end
exportgraphics(fig,fullfile(outDir,'Flyback_72_6_4_ABCD_layout.png'),'Resolution',180);

fig=figure('Color','w','Position',[30 60 2200 620]);
tl=tiledlayout(fig,1,4,'TileSpacing','compact','Padding','compact');
% Individual titles identify core X/Y/Z; dimensions span core + dashed PCB.
for k=1:4
    q=G(k); ax=nexttile(tl); hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
    h=q.HalfHeight_mm; gap=q.GapEach_mm/2; stem=h-q.Yoke_mm;
    for signZ=[-1 1]
        if signZ==1, yz=gap+stem; lz=gap; else, yz=-gap-h; lz=-gap-stem; end
        rectangle(ax,'Position',[-q.CoreX_mm/2,yz,q.CoreX_mm,q.Yoke_mm],'FaceColor',[.72 .72 .72]);
        for j=1:numel(q.LegCenters_mm)
            rectangle(ax,'Position',[q.LegCenters_mm(j)-q.LegWidths_mm(j)/2,lz,q.LegWidths_mm(j),stem], ...
                'FaceColor',[.72 .72 .72]);
        end
    end
    rectangle(ax,'Position',[q.BoardLeft_mm,-W.boardThickness_mm/2,q.BoardX_mm,W.boardThickness_mm],'LineStyle','--');
    flybackOverallDimensions(ax,q.BoardLeft_mm,q.BoardRight_mm,-q.CoreHeight_mm/2,q.CoreHeight_mm/2,'Overall X','Overall Z');
    xlabel(ax,'X (mm)'); ylabel(ax,'Z (mm)');
    title(ax,{sprintf('%s %s: %.1f x %.1f x %.3f mm',q.Scheme,q.CoreType,q.CoreX_mm,leg,q.CoreHeight_mm), ...
        sprintf('Each gap %.4f mm; volume %.2f cm^3',q.GapEach_mm,q.CoreVolume_cm3)});
end
exportgraphics(fig,fullfile(outDir,'Flyback_72_6_4_ABCD_side_sections.png'),'Resolution',180);
end

function drawTurns(ax,cx,leg,turns,width,W,color,legWidth)
if nargin<8, legWidth=leg; end
for turn=1:turns
    side=leg+2*W.coreCopper_mm+width+2*(turn-1)*(width+W.spacing_mm);
    sx=side-leg+legWidth;
    rectangle(ax,'Position',[cx-sx/2,-side/2,sx,side],'EdgeColor',color);
end
end

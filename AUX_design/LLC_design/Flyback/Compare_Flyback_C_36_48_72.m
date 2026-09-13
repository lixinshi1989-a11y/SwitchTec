%% Compare the three current C designs on identical geometric scales.
% Run the three magnetics scripts first; this reads their saved C results.
clear; clc;
% Loss and leakage are saved analytical estimates; this does not run AEDT.
root=fileparts(mfilename('fullpath'));
files={fullfile(root,'output','36_3_2_compact','Flyback_36_3_2_compact_design.mat'), ...
    fullfile(root,'output','48_4_3','Flyback_48_4_3_design.mat'), ...
    fullfile(root,'output','72_6_4','Flyback_72_6_4_design.mat')};
labels=["36:3:2","48:4:3","72:6:4"];
for k=1:3
    assert(isfile(files{k}),'Missing result file: %s. Run the corresponding magnetics script first.',files{k});
    data=load(files{k},'Schemes','E','W');
    W=data.W;
    if isfield(W,'primaryLayerIds') % 36T uses the original sweep field names.
        W.pLayers=W.primaryLayerIds; W.sLayers=W.secondaryLayerIds;
        W.aLayers=W.auxLayerIds; W.aTurns=W.auxTurnsPerLayer;
        W.coreCopper_mm=W.coreClearance_mm; W.spacing_mm=W.traceSpacing_mm;
    end
    winding{k}=W; %#ok<SAGROW>
    q=data.Schemes(strcmp(string({data.Schemes.Scheme}),"C"));
    assert(isscalar(q),'Missing C: rerun the design script.');
    assert(q.PrimaryLegCount==1 && q.CoreType=="EE");
    assert(q.PrimaryTurnsPerLayerPerLeg*q.PrimaryLayerCount==data.E.Np);
    if k==1, C=q; else, C(k)=orderfields(q,C); end %#ok<SAGROW>
    assert(q.SecondaryRadialBreadth_mm<=q.PrimaryRadialBreadth_mm+1e-9);
    ns(k)=data.E.Ns; na(k)=data.E.Naux; %#ok<SAGROW>
end
out=fullfile(root,'output','design_comparison');
if ~exist(out,'dir'), mkdir(out); end
T=struct2table(rmfield(C,{'LegCenters_mm','LegWidths_mm','AuxTurnSides_mm'}));
T.Design=labels'; T=movevars(T,'Design','Before',1);
writetable(T,fullfile(out,'Flyback_C_36_48_72_comparison.csv'));
fig=figure('Color','w','Position',[30 30 1800 1350]);
tl=tiledlayout(fig,3,3,'TileSpacing','compact','Padding','compact');
title(tl,{'Scheme C comparison - 36:3:2 / 48:4:3 / 72:6:4', ...
    'P/S: centre leg | AUX: centre (36/48), right outer leg (72) | winding envelopes; common X/Y/Z scales'});
plan=gobjects(1,3); side=gobjects(1,3); layers=gobjects(1,3);
for k=1:3
    q=C(k); leg=q.Leg_mm; W=winding{k};
    ax=nexttile(tl,k); plan(k)=ax; hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
    rectangle(ax,'Position',[q.BoardLeft_mm,-q.BoardY_mm/2,q.BoardX_mm,q.BoardY_mm],'LineStyle',':');
    for j=1:numel(q.LegCenters_mm)
        cx=q.LegCenters_mm(j); lw=q.LegWidths_mm(j);
        rectangle(ax,'Position',[cx-lw/2,-leg/2,lw,leg],'FaceColor',[.72 .72 .72]);
    end
    turns(ax,q.SecondaryCenter_mm,leg,leg,ns(k),q.SecondaryWidth_mm,W,[.1 .3 .8]);
    turns(ax,q.PrimaryCenter_mm,leg,leg,q.PrimaryTurnsPerLayerPerLeg,q.PrimaryWidth_mm,W,[.8 .1 .1]);
    if q.AuxCenteredOnPrimary
        for auxSide=q.AuxTurnSides_mm
            rectangle(ax,'Position',[q.AuxCenter_mm-auxSide/2,-auxSide/2,auxSide,auxSide], ...
                'EdgeColor',[0 .5 .2],'LineWidth',1.2);
        end
    else
        turns(ax,q.AuxCenter_mm,leg,q.AuxLegWidth_mm,max(W.aTurns),W.auxWidth_mm,W,[0 .5 .2]);
    end
    flybackOverallDimensions(ax,q.BoardLeft_mm,q.BoardRight_mm,-q.BoardY_mm/2,q.BoardY_mm/2,'PCB X','PCB Y');
    title(ax,{sprintf('%s - Scheme C',labels(k)), ...
        sprintf('PCB %.0f x %.0f mm; core %.2f W; total %.2f W',q.BoardX_mm,q.BoardY_mm,q.CoreEnvelope_W,q.TotalEnvelope_W), ...
        sprintf('Core X/Y %.1f / %.1f mm; P %.3f mm; J pass %d',q.CoreX_mm,leg,q.PrimaryWidth_mm,q.CurrentDensityOK)});
    xlabel(ax,'X (mm)'); ylabel(ax,'Y (mm)');

    ax=nexttile(tl,k+3); side(k)=ax; hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
    h=q.HalfHeight_mm; gap=q.GapEach_mm/2; stem=h-q.Yoke_mm;
    for signZ=[-1 1]
        if signZ==1, yz=gap+stem; lz=gap; else, yz=-gap-h; lz=-gap-stem; end
        rectangle(ax,'Position',[-q.CoreX_mm/2,yz,q.CoreX_mm,q.Yoke_mm],'FaceColor',[.72 .72 .72]);
        for j=1:numel(q.LegCenters_mm)
            cx=q.LegCenters_mm(j); lw=q.LegWidths_mm(j);
            rectangle(ax,'Position',[cx-lw/2,lz,lw,stem],'FaceColor',[.72 .72 .72]);
        end
    end
    rectangle(ax,'Position',[q.BoardLeft_mm,-q.BoardThickness_mm/2,q.BoardX_mm,q.BoardThickness_mm],'LineStyle','--');
    flybackOverallDimensions(ax,q.BoardLeft_mm,q.BoardRight_mm,-q.CoreHeight_mm/2,q.CoreHeight_mm/2,'Overall X','Overall Z');
    title(ax,{sprintf('Core X/Y/Z: %.1f / %.1f / %.3f mm',q.CoreX_mm,leg,q.CoreHeight_mm), ...
        sprintf('Volume %.2f cm^3; each gap %.4f mm',q.CoreVolume_cm3,q.GapEach_mm)});
    xlabel(ax,'X (mm)'); ylabel(ax,'Z (mm)');

    ax=nexttile(tl,k+6); layers(k)=ax; hold(ax,'on'); axis(ax,[0 100 0 10]); axis(ax,'off');
    aTurns=W.aTurns;
    if isscalar(aTurns), aTurns=repmat(aTurns,1,numel(W.aLayers)); end
    assert(sum(aTurns)==na(k) && numel(W.pLayers)==q.PrimaryLayerCount);
    auxLane=35;
    if abs(q.AuxCenter_mm-q.PrimaryCenter_mm)>1e-9, auxLane=76; end
    for j=1:8
        y=9-j; plot(ax,[8 94],[y y],'Color',[.8 .8 .8]); text(ax,1,y,sprintf('L%d',j));
        if ismember(j,W.pLayers)
            layerTrace(ax,35,y,sprintf('P %dT',q.PrimaryTurnsPerLayerPerLeg),[.8 .1 .1]);
        end
        if ismember(j,W.aLayers)
            layerTrace(ax,auxLane,y,sprintf('AUX %dT',aTurns(W.aLayers==j)),[0 .5 .2]);
        end
        if ismember(j,W.sLayers)
            layerTrace(ax,35,y,sprintf('S %dT',ns(k)),[.1 .3 .8]);
        end
        if ~ismember(j,[W.pLayers W.aLayers W.sLayers])
            text(ax,35,y,'Terminal leads only','HorizontalAlignment','center','Color',[.4 .4 .4]);
        end
    end
    text(ax,35,9,'CENTRE LEG','HorizontalAlignment','center');
    text(ax,76,9,'RIGHT OUTER LEG','HorizontalAlignment','center');
    title(ax,{sprintf('Core %.3f + copper %.3f = %.3f W (envelope estimate)',q.CoreEnvelope_W,q.CopperEnvelope_W,q.TotalEnvelope_W), ...
        sprintf('P / S / spacing: %.2f / %.2f / %.2f mm',q.PrimaryWidth_mm,q.SecondaryWidth_mm,q.TraceSpacing_mm), ...
        sprintf('S J = %.1f A/mm^2; screening pass: %d; leakage requires 3-C',q.SecondaryJ_Amm2,q.CurrentDensityOK)});
end
% Equal plot limits ensure true size comparison between columns.
for axs={plan,side}
    group=axs{1}; xx=vertcat(group.XLim); yy=vertcat(group.YLim);
    for ax=group, xlim(ax,[min(xx(:,1)) max(xx(:,2))]); ylim(ax,[min(yy(:,1)) max(yy(:,2))]); end
end
exportgraphics(fig,fullfile(out,'Flyback_C_36_48_72_comparison.png'),'Resolution',180);
savefig(fig,fullfile(out,'Flyback_C_36_48_72_comparison.fig'));
% Requested two-row layout: top winding plan, bottom L1-L8 allocation.
layoutFig=figure('Color','w','Position',[40 40 1800 1050]);
layoutTiles=tiledlayout(layoutFig,2,3,'TileSpacing','compact','Padding','compact');
title(layoutTiles,{'Scheme C: 36:3:2 / 48:4:3 / 72:6:4', ...
    'P series | S L6/L7/L8 parallel | red P / blue S / green AUX | winding envelopes, not PCB routes'});
for k=1:3
    ap=copyobj(plan(k),layoutTiles); ap.Layout.Tile=k;
    al=copyobj(layers(k),layoutTiles); al.Layout.Tile=k+3;
    q=C(k);
    title(al,{sprintf('P centre: %d layers x %dT; S: 3 parallel layers x %dT', ...
        q.PrimaryLayerCount,q.PrimaryTurnsPerLayerPerLeg,ns(k)), ...
        sprintf('P-S vertical %.3f mm; Llk,P estimate %.2f uH',q.PSCopperVertical_mm,q.LeakagePriEstimate_uH), ...
        sprintf('P / S / spacing %.2f / %.2f / %.2f mm; S J %.1f; J pass %d', ...
        q.PrimaryWidth_mm,q.SecondaryWidth_mm,q.TraceSpacing_mm,q.SecondaryJ_Amm2,q.CurrentDensityOK)});

end
exportgraphics(layoutFig,fullfile(out,'Flyback_C_36_48_72_layout.png'),'Resolution',180);
savefig(layoutFig,fullfile(out,'Flyback_C_36_48_72_layout.fig'));
disp(T(:,{'Design','CoreX_mm','BoardX_mm','BoardY_mm','TotalEnvelope_W'}));

function turns(ax,cx,depth,legWidth,n,w,W,color)
for turn=1:n
    pad=2*W.coreCopper_mm+w+2*(turn-1)*(w+W.spacing_mm);
    sx=legWidth+pad; sy=depth+pad;
    rectangle(ax,'Position',[cx-sx/2,-sy/2,sx,sy],'EdgeColor',color);
end
end

function layerTrace(ax,cx,y,label,color)
plot(ax,[cx-15 cx+15],[y y],'Color',color,'LineWidth',4);
text(ax,cx,y+.22,label,'HorizontalAlignment','center');
end

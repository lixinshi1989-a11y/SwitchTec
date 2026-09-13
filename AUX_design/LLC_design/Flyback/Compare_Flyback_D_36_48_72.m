%% Compare the three current D designs on identical geometric scales.
% Run the three magnetics scripts first; this reads their saved D results.
clear; clc;
root=fileparts(mfilename('fullpath'));
files={fullfile(root,'output','36_3_2_compact','Flyback_36_3_2_compact_design.mat'), ...
    fullfile(root,'output','48_4_3','Flyback_48_4_3_design.mat'), ...
    fullfile(root,'output','72_6_4','Flyback_72_6_4_design.mat')};
labels=["36:3:2","48:4:3","72:6:4"];
for k=1:3
    data=load(files{k},'Schemes','E');
    q=data.Schemes(strcmp(string({data.Schemes.Scheme}),"D"));
    assert(isscalar(q),'Missing D: rerun the design script.');
    assert(q.PrimaryLayerCount==3 && q.PrimaryLegCount==2);
    assert(q.PrimaryTurnsPerLayerPerLeg*6==data.E.Np);
    if k==1, D=q; else, D(k)=orderfields(q,D); end %#ok<SAGROW>
    ns(k)=data.E.Ns; na(k)=data.E.Naux; %#ok<SAGROW>
end
out=fullfile(root,'output','design_comparison');
if ~exist(out,'dir'), mkdir(out); end
T=struct2table(rmfield(D,{'LegCenters_mm','LegWidths_mm','AuxTurnSides_mm'}));
T.Design=labels'; T=movevars(T,'Design','Before',1);
writetable(T,fullfile(out,'Flyback_D_36_48_72_comparison.csv'));
fig=figure('Color','w','Position',[30 30 1800 1350]);
tl=tiledlayout(fig,3,3,'TileSpacing','compact','Padding','compact');
title(tl,{'Scheme D comparison - 36:3:2 / 48:4:3 / 72:6:4', ...
    'P: both legs L1/L2/L3, series aiding | S: right leg L6/L7/L8 parallel | winding envelopes; common X/Y/Z scales'});
plan=gobjects(1,3); side=gobjects(1,3); layers=gobjects(1,3);
for k=1:3
    q=D(k); leg=q.Leg_mm;
    ax=nexttile(tl,k); plan(k)=ax; hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
    rectangle(ax,'Position',[q.BoardLeft_mm,-q.BoardY_mm/2,q.BoardX_mm,q.BoardY_mm],'LineStyle',':');
    for cx=q.LegCenters_mm
        rectangle(ax,'Position',[cx-leg/2,-leg/2,leg,leg],'FaceColor',[.72 .72 .72]);
    end
    turns(ax,q.SecondaryCenter_mm,leg,ns(k),q.SecondaryWidth_mm,q.TraceSpacing_mm,[.1 .3 .8]);
    for cx=q.LegCenters_mm
        turns(ax,cx,leg,q.PrimaryTurnsPerLayerPerLeg,q.PrimaryWidth_mm,q.TraceSpacing_mm,[.8 .1 .1]);
    end
    for auxSide=q.AuxTurnSides_mm
        rectangle(ax,'Position',[q.AuxCenter_mm-auxSide/2,-auxSide/2,auxSide,auxSide], ...
            'EdgeColor',[0 .5 .2]);
    end
    plot(ax,[-1 1],[0 0],'-','Color',[.9 .35 0]);
    plot(ax,-1,0,'<','Color',[.9 .35 0]); plot(ax,1,0,'>','Color',[.9 .35 0]);
    text(ax,0,2,'2 mm','Color',[.9 .35 0],'HorizontalAlignment','center','FontWeight','bold');
    flybackOverallDimensions(ax,q.BoardLeft_mm,q.BoardRight_mm,-q.BoardY_mm/2,q.BoardY_mm/2,'PCB X','PCB Y');
    title(ax,{sprintf('%s - Scheme D',labels(k)), ...
        sprintf('PCB %.0f x %.0f mm; core %.2f W; total %.2f W',q.BoardX_mm,q.BoardY_mm,q.CoreEnvelope_W,q.TotalEnvelope_W), ...
        sprintf('Core X/Y %.1f / %.1f mm; P %.3f mm; J pass %d',q.CoreX_mm,leg,q.PrimaryWidth_mm,q.CurrentDensityOK)});
    xlabel(ax,'X (mm)'); ylabel(ax,'Y (mm)');

    ax=nexttile(tl,k+3); side(k)=ax; hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
    h=q.HalfHeight_mm; gap=q.GapEach_mm/2; stem=h-q.Yoke_mm;
    for signZ=[-1 1]
        if signZ==1, yz=gap+stem; lz=gap; else, yz=-gap-h; lz=-gap-stem; end
        rectangle(ax,'Position',[-q.CoreX_mm/2,yz,q.CoreX_mm,q.Yoke_mm],'FaceColor',[.72 .72 .72]);
        for cx=q.LegCenters_mm
            rectangle(ax,'Position',[cx-leg/2,lz,leg,stem],'FaceColor',[.72 .72 .72]);
        end
    end
    rectangle(ax,'Position',[q.BoardLeft_mm,-q.BoardThickness_mm/2,q.BoardX_mm,q.BoardThickness_mm],'LineStyle','--');
    flybackOverallDimensions(ax,q.BoardLeft_mm,q.BoardRight_mm,-q.CoreHeight_mm/2,q.CoreHeight_mm/2,'Overall X','Overall Z');
    title(ax,{sprintf('Core X/Y/Z: %.1f / %.1f / %.3f mm',q.CoreX_mm,leg,q.CoreHeight_mm), ...
        sprintf('Volume %.2f cm^3; each gap %.4f mm',q.CoreVolume_cm3,q.GapEach_mm)});
    xlabel(ax,'X (mm)'); ylabel(ax,'Z (mm)');

    ax=nexttile(tl,k+6); layers(k)=ax; hold(ax,'on'); axis(ax,[0 100 0 10]); axis(ax,'off');
    for j=1:8
        y=9-j; plot(ax,[8 94],[y y],'Color',[.8 .8 .8]); text(ax,1,y,sprintf('L%d',j));
        if j<=3
            for lane=[12 59]
                plot(ax,[lane lane+30],[y y],'Color',[.8 .1 .1],'LineWidth',4);
                text(ax,lane+15,y+.22,sprintf('P %dT',q.PrimaryTurnsPerLayerPerLeg),'HorizontalAlignment','center');
            end
        elseif j<=5
            plot(ax,[59 89],[y y],'Color',[0 .5 .2],'LineWidth',4);
            nt=ceil(na(k)/2); if j==5, nt=floor(na(k)/2); end
            text(ax,74,y+.22,sprintf('AUX %dT',nt),'HorizontalAlignment','center');
        else
            plot(ax,[59 89],[y y],'Color',[.1 .3 .8],'LineWidth',4);
            text(ax,74,y+.22,sprintf('S %dT',ns(k)),'HorizontalAlignment','center');
        end
    end
    text(ax,27,9,'LEFT LEG','HorizontalAlignment','center'); text(ax,74,9,'RIGHT LEG','HorizontalAlignment','center');
    title(ax,{sprintf('Core %.3f + copper %.3f = %.3f W (envelope estimate)',q.CoreEnvelope_W,q.CopperEnvelope_W,q.TotalEnvelope_W), ...
        sprintf('P / S / spacing: %.2f / %.2f / %.2f mm',q.PrimaryWidth_mm,q.SecondaryWidth_mm,q.TraceSpacing_mm), ...
        sprintf('S J = %.1f A/mm^2; screening pass: %d; leakage requires 3-D',q.SecondaryJ_Amm2,q.CurrentDensityOK)});
end
% Equal plot limits ensure true size comparison between columns.
for axs={plan,side}
    group=axs{1}; xx=vertcat(group.XLim); yy=vertcat(group.YLim);
    for ax=group, xlim(ax,[min(xx(:,1)) max(xx(:,2))]); ylim(ax,[min(yy(:,1)) max(yy(:,2))]); end
end
exportgraphics(fig,fullfile(out,'Flyback_D_36_48_72_comparison.png'),'Resolution',180);
savefig(fig,fullfile(out,'Flyback_D_36_48_72_comparison.fig'));
% Requested two-row layout: top winding plan, bottom L1-L8 allocation.
layoutFig=figure('Color','w','Position',[40 40 1800 1050]);
layoutTiles=tiledlayout(layoutFig,2,3,'TileSpacing','compact','Padding','compact');
title(layoutTiles,{'Scheme D: 36:3:2 / 48:4:3 / 72:6:4', ...
    'P both legs L1/L2/L3 series | S right leg L6/L7/L8 parallel | red P / blue S / green AUX'});
for k=1:3
    ap=copyobj(plan(k),layoutTiles); ap.Layout.Tile=k;
    al=copyobj(layers(k),layoutTiles); al.Layout.Tile=k+3;
    title(al,{sprintf('P left/right L1/L2/L3: %dT each; series aiding',D(k).PrimaryTurnsPerLayerPerLeg), ...
        'Nearest copper edges 2.0 mm; leakage requires 3-D', ...
        sprintf('P / S / spacing %.2f / %.2f / %.2f mm; S J %.1f A/mm^2 (fails screening)', ...
        D(k).PrimaryWidth_mm,D(k).SecondaryWidth_mm,D(k).TraceSpacing_mm,D(k).SecondaryJ_Amm2)});
end
exportgraphics(layoutFig,fullfile(out,'Flyback_D_36_48_72_layout.png'),'Resolution',180);
savefig(layoutFig,fullfile(out,'Flyback_D_36_48_72_layout.fig'));
disp(T(:,{'Design','CoreX_mm','BoardX_mm','BoardY_mm','TotalEnvelope_W'}));

function turns(ax,cx,leg,n,w,spacing,color)
for turn=1:n
    s=leg+4+w+2*(turn-1)*(w+spacing); % existing 2 mm core-to-copper clearance
    rectangle(ax,'Position',[cx-s/2,-s/2,s,s],'EdgeColor',color);
end
end

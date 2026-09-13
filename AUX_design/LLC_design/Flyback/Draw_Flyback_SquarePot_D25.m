%% Draw the requested 25 mm centre diameter, without changing or optimizing it.
% Uses the existing target-Lm=2.3 mH sweep sample, even if screening fails.
clear; clc;
root=fileparts(mfilename('fullpath'));
src=fullfile(root,'output','36_3_2_pot');
dataFile=fullfile(src,'square_core_sweep','SquarePot_sweep.mat');
assert(isfile(dataFile),'Run Flyback_Magnetics_36_3_2_SquarePot_Sweep.m first.');
data=load(dataFile,'T','S','W');
row=data.T(abs(data.T.Diameter_mm-25)<1e-9,:);
assert(height(row)==1,'The saved sweep must contain D=25 mm.');
q=table2struct(row);
G=jsondecode(fileread(fullfile(src,'Flyback_36_3_2_Scheme_C_Pot_100kHz_geometry.json')));
out=fullfile(src,'square_core_sweep','D25');
if ~exist(out,'dir'), mkdir(out); end
drawDesigns(q,{'Requested D=25.00 mm / Lm target 2.3 mH'},data.S,data.W,G,out);
writetable(row,fullfile(out,'SquarePot_D25_parameters.csv'));
disp(row(:,{'Diameter_mm','CoreSide_mm','CoreHeight_mm','CoreVolume_cm3','Gap_mm','Lm_mH','Core_W','Copper_W','Total_W'}));

function drawDesigns(Q,labels,S,W,G,out)
fig=figure('Color','w','Position',[30 30 1050 1500]);
tl=tiledlayout(fig,3,numel(Q),'TileSpacing','compact','Padding','compact');
title(tl,{'36:3:2 square pot - 25 mm centre diameter', ...
    'Red P / blue S / green AUX; circular winding envelopes, not manufacturing routes; analytical losses'});
plans=gobjects(1,numel(Q)); sections=plans;
for k=1:numel(Q)
    q=Q(k); r=q.Diameter_mm/2; a=q.CoreSide_mm/2; rw=q.WindowRadius_mm;
    ax=nexttile(tl,k); plans(k)=ax; hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
    % At the joint plane only the centre circle and four corner returns exist.
    square=polyshape([-a a a -a],[-a -a a a]); ang=linspace(0,2*pi,1441);
    hole=polyshape(rw*cos(ang(1:end-1)),rw*sin(ang(1:end-1))); corners=subtract(square,hole);
    plot(ax,corners,'FaceColor',[.72 .72 .72],'FaceAlpha',1);
    rectangle(ax,'Position',[-r -r 2*r 2*r],'Curvature',[1 1],'FaceColor',[.72 .72 .72]);
    rectangle(ax,'Position',[-a -a 2*a 2*a],'EdgeColor',[.35 .35 .35],'LineStyle','--');
    rectangle(ax,'Position',[-q.BoardX_mm/2 -q.BoardY_mm/2 q.BoardX_mm q.BoardY_mm],'LineStyle',':');
    for turn=1:3
        rr=r+2+1.1+(turn-1)*(2.4+G.transition_allowance_mm.secondary);
        plot(ax,rr*cos(ang),rr*sin(ang),'Color',[.1 .3 .8]);
    end
    for turn=1:18
        rr=r+2+.1+(turn-1)*(.4+G.transition_allowance_mm.primary);
        plot(ax,rr*cos(ang),rr*sin(ang),'Color',[.8 .1 .1]);
    end
    rr=r+2+G.primary_breadth_mm/2;
    plot(ax,rr*cos(ang),rr*sin(ang),'Color',[0 .5 .2],'LineWidth',1.2);
    dimH(ax,-r,r,0,sprintf('Centre D %.2f',2*r));
    dimH(ax,-a,a,-a-2,sprintf('Core X/Y %.2f mm',2*a));
    flybackOverallDimensions(ax,-q.BoardX_mm/2,q.BoardX_mm/2,-q.BoardY_mm/2,q.BoardY_mm/2,'PCB X','PCB Y');
    title(ax,{labels{k},sprintf('Core %.3f + copper %.3f = %.3f W; feasible %d',q.Core_W,q.Copper_W,q.Total_W,q.Feasible), ...
        sprintf('D %.2f mm; core %.2f x %.2f x %.3f mm',2*r,2*a,2*a,q.CoreHeight_mm)});
    xlabel(ax,'X (mm)'); ylabel(ax,'Y (mm)');
    ax=nexttile(tl,k+numel(Q)); sections(k)=ax; hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
    h=(q.CoreHeight_mm-q.Gap_mm)/2; stem=h-S.yoke_mm;
    for signZ=[-1 1]
        if signZ==1, yz=q.Gap_mm/2+stem; lz=q.Gap_mm/2; else, yz=-q.CoreHeight_mm/2; lz=-q.Gap_mm/2-stem; end
        rectangle(ax,'Position',[-a yz 2*a S.yoke_mm],'FaceColor',[.72 .72 .72]);
        rectangle(ax,'Position',[-r lz 2*r stem],'FaceColor',[.72 .72 .72]);
    end
    rectangle(ax,'Position',[-q.BoardX_mm/2 -G.pcb_size_mm(3)/2 q.BoardX_mm G.pcb_size_mm(3)],'LineStyle',':');
    flybackOverallDimensions(ax,-q.BoardX_mm/2,q.BoardX_mm/2,-q.CoreHeight_mm/2,q.CoreHeight_mm/2,'Overall X','Core Z');
    title(ax,{sprintf('X-Z section at Y=0; corner posts lie outside this plane'), ...
        sprintf('Yoke 4.00 mm; gap %.4f mm; Lm %.3f mH; volume %.2f cm^3',q.Gap_mm,q.Lm_mH,q.CoreVolume_cm3)});
    xlabel(ax,'X (mm)'); ylabel(ax,'Z (mm)');
    ax=nexttile(tl,k+2*numel(Q)); hold(ax,'on'); axis(ax,[0 100 0 10]); axis(ax,'off');
    for j=1:8
        y=9-j; plot(ax,[8 95],[y y],'Color',[.85 .85 .85]); text(ax,1,y,sprintf('L%d',j));
        if ismember(j,[2 3]), c=[.8 .1 .1]; label='Primary 18T / 0.20 mm';
        elseif ismember(j,[4 5]), c=[0 .5 .2]; label='AUX 1T / 0.20 mm';
        elseif j>=6, c=[.1 .3 .8]; label='Secondary 3T / 2.20 mm (parallel)';
        else, text(ax,50,y,'Terminal / blind-via access','HorizontalAlignment','center'); continue; end
        plot(ax,[20 80],[y y],'Color',c,'LineWidth',4); text(ax,50,y+.23,label,'HorizontalAlignment','center');
    end
    title(ax,{sprintf('P 18+18 series; S 3T x 3 parallel; AUX 1+1 series'), ...
        sprintf('P/S breadth %.3f / %.3f mm; spacing >=0.20 mm',G.primary_breadth_mm,G.secondary_breadth_mm), ...
        sprintf('J P/S %.2f / %.2f A/mm^2; %s sizing envelope',q.Jp_Amm2,q.Js_Amm2,q.ConductionMode)});
end
for group={plans,sections}
    axes=group{1}; xx=vertcat(axes.XLim); yy=vertcat(axes.YLim);
    for ax=axes, xlim(ax,[min(xx(:,1)) max(xx(:,2))]); ylim(ax,[min(yy(:,1)) max(yy(:,2))]); end
end
exportgraphics(fig,fullfile(out,'SquarePot_D25_design.png'),'Resolution',180);
savefig(fig,fullfile(out,'SquarePot_D25_design.fig'));
exportgraphics(fig,fullfile(out,'SquarePot_D25_design.pdf'),'ContentType','vector');
end
function dimH(ax,x1,x2,y,label)
plot(ax,[x1 x2],[y y],'k-'); plot(ax,x1,y,'k>'); plot(ax,x2,y,'k<');
text(ax,(x1+x2)/2,y+1,label,'HorizontalAlignment','center','FontSize',9);
end


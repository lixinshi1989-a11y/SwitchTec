%% Square pot / four-corner return core, based on the USER-EDITED AEDT.
% Does not run or overwrite the manually edited AEDT. Losses are analytical.
clear; clc;
root=fileparts(mfilename('fullpath'));
src=fullfile(root,'output','36_3_2_pot'); out=fullfile(src,'square_core_sweep');
if ~exist(out,'dir'), mkdir(out); end
base=load(fullfile(root,'output','36_3_2_compact','Flyback_36_3_2_compact_design.mat'),'E','W','M');
E=base.E; W=base.W; M=base.M;
template=jsondecode(fileread(fullfile(src,'Flyback_36_3_2_Scheme_C_Pot_100kHz_geometry.json')));
snapshot=jsondecode(fileread(fullfile(src,'edited_pot_snapshot.json')));
% Snapshot is freshly read from the edited AEDT, not the old builder JSON.
b=cellfun(@str2double,snapshot.Core_Upper.bounds);
assert(abs((b(4)-b(1))-(b(5)-b(2)))<1e-6,'Expected a square envelope.');
S.referenceRadius_mm=template.centre_diameter_mm/2;
S.window_mm=11;
S.outerInset_mm=template.window_radius_mm-(b(4)-b(1))/2;
S.yoke_mm=4;
S.height_mm=b(6)-str2double(snapshot.Core_Lower.bounds{3});
S.referenceGap_mm=template.gap_mm;
S.referenceVolume_mm3=snapshot.Core_Upper.volume_mm3+snapshot.Core_Lower.volume_mm3;
S.diameter_mm=sort(unique([16:.25:44 2*S.referenceRadius_mm]));
S.targetLm_H=E.Lm;
S.minGap_mm=.10; S.maxGap_mm=1.0;
S.maxFlux_T=.20; S.maxBoardX_mm=120; S.maxBoardY_mm=100;
% Preserve the edited square-window offset. All dimensions co-vary with D.
% PCB may grow when needed to keep terminations clear of the winding band.
ci=2*sqrt(pi)*gamma((M.alpha+1)/2)/gamma((M.alpha+2)/2);
M.ki=M.k/((2*pi)^(M.alpha-1)*2^(M.beta-M.alpha)*ci);
for k=1:numel(S.diameter_mm)
    q=flybackEvaluateSquarePot(S.diameter_mm(k)/2,true,S,E,W,M,template);
    if k==1, designs=q; else, designs(k)=q; end %#ok<SAGROW>
end
Current=flybackEvaluateSquarePot(S.referenceRadius_mm,false,S,E,W,M,template);
assert(abs(Current.CoreVolume_cm3*1000-S.referenceVolume_mm3)<.1, ...
    'Analytical geometry no longer matches the edited AEDT snapshot. Refresh geometry inputs.');
T=struct2table(designs); valid=find(T.Feasible);
assert(~isempty(valid),'No feasible sample: inspect flux, gap, and PCB limits.');
[~,j]=min(T.Total_W(valid)); ibest=valid(j); Best=designs(ibest);
[~,iall]=min(T.Total_W); MinimumUnfiltered=designs(iall);
writetable(T,fullfile(out,'SquarePot_centre_diameter_sweep.csv'));
Selected=struct2table([Current Best]); Selected.Design=["Current edited AEDT (fixed gap)";"Lowest-loss feasible sample (target Lm)"];
Selected=movevars(Selected,'Design','Before',1);
writetable(Selected,fullfile(out,'SquarePot_selected_designs.csv'));

%% Centre diameter versus loss, dimensions, flux and required gap
fig=figure('Color','w','Position',[50 40 1550 1000]);
tl=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
title(tl,{'36:3:2 square pot: centre diameter sweep / 100 kHz / 80 C', ...
    '4 mm yokes; 11 mm radial window; square envelope follows diameter; Lm target 2.3 mH; analytical estimates'});
ax=nexttile; plot(T.Diameter_mm,[T.Core_W T.Copper_W T.Total_W],'LineWidth',1.6); hold on;
plot(T.Diameter_mm(~T.Feasible),T.Total_W(~T.Feasible),'x','Color',[.65 .65 .65]);
plot(Best.Diameter_mm,Best.Total_W,'ro','MarkerFaceColor','r');
plot(Current.Diameter_mm,Current.Total_W,'ks','MarkerFaceColor','y');
legend('Core','Copper','Total','Outside limits','Selected target-Lm design','Edited AEDT: original gap','Location','best');
xlabel('Centre diameter (mm)'); ylabel('Loss (W)'); grid on;
title(sprintf('Selected D %.2f mm: %.3f W total',Best.Diameter_mm,Best.Total_W));
nexttile; plot(T.Diameter_mm,[T.CentreB_mT T.ReturnB_mT T.YokeB_mT],'LineWidth',1.6); hold on;
yline(S.maxFlux_T*1000,'k--','Flux limit'); xlabel('Centre diameter (mm)'); ylabel('Peak flux estimate (mT)');
legend('Centre','Corner return','Yoke maximum','Location','best'); grid on;
nexttile; yyaxis left; plot(T.Diameter_mm,T.Gap_mm,'LineWidth',1.6); ylabel('Required gap (mm)');
yline(S.minGap_mm,'--'); yline(S.maxGap_mm,'--'); yyaxis right;
plot(T.Diameter_mm,T.CoreVolume_cm3,'LineWidth',1.6); ylabel('Core volume (cm^3)'); xlabel('Centre diameter (mm)'); grid on;
nexttile; plot(T.Diameter_mm,[T.CoreSide_mm T.BoardX_mm T.BoardY_mm],'LineWidth',1.6); grid on;
xlabel('Centre diameter (mm)'); ylabel('Overall size (mm)'); legend('Square core side','PCB X','PCB Y','Location','best');
exportgraphics(fig,fullfile(out,'SquarePot_diameter_loss_sweep.png'),'Resolution',180);
savefig(fig,fullfile(out,'SquarePot_diameter_loss_sweep.fig'));

%% EE-style diagram: winding plan, true core section, L1-L8 allocation
drawDesigns([Current Best],{'Edited AEDT reference','Selected minimum-loss feasible'},S,W,template,out);
save(fullfile(out,'SquarePot_sweep.mat'),'S','E','W','M','T','Current','Best','MinimumUnfiltered','Selected');
disp(Selected(:,{'Design','Diameter_mm','CoreSide_mm','CoreHeight_mm','Gap_mm','Lm_mH','Core_W','Copper_W','Total_W','Feasible'}));
fid=fopen(fullfile(out,'SquarePot_sweep_report.txt'),'w'); assert(fid>=0);
fprintf(fid,'USER EDITED reference: square %.6f mm, height %.6f mm, yokes 4 mm, CAD volume %.6f cm3.\n',Current.CoreSide_mm,S.height_mm,S.referenceVolume_mm3/1000);
fprintf(fid,'Reference original gap: Lm %.6f mH; core %.6f W, copper %.6f W, total %.6f W; feasible %d.\n',Current.Lm_mH,Current.Core_W,Current.Copper_W,Current.Total_W,Current.Feasible);
fprintf(fid,'Sweep D %.2f to %.2f mm; square half-side = D/2 + 11 - %.9f mm; target Lm %.3f mH.\n',min(S.diameter_mm),max(S.diameter_mm),S.outerInset_mm,E.Lm*1e3);
fprintf(fid,'Selected sampled D %.6f mm; square %.6f mm; gap %.6f mm; core %.6f, copper %.6f, total %.6f W.\n',Best.Diameter_mm,Best.CoreSide_mm,Best.Gap_mm,Best.Core_W,Best.Copper_W,Best.Total_W);
fprintf(fid,'Limits: all regional Bpeak <= %.0f mT; gap %.2f..%.2f mm; PCB <= %.0fx%.0f mm; J<=16 A/mm2.\n',S.maxFlux_T*1e3,S.minGap_mm,S.maxGap_mm,S.maxBoardX_mm,S.maxBoardY_mm);
fprintf(fid,['Loss uses original TPG33 iGSE and Rac/Rdc assumptions. Corner flux redistribution is approximated by angular aperture.\n' ...
    'This is a sampled constrained minimum, not a global optimum or FEA result. No AEDT changes made.\n' ...
    'Layer widths, turns and stack retained. Via/lead access and board edges expand if needed as diameter increases.\n']);
fclose(fid);

function drawDesigns(Q,labels,S,W,G,out)
fig=figure('Color','w','Position',[30 30 1650 1350]);
tl=tiledlayout(fig,3,numel(Q),'TileSpacing','compact','Padding','compact');
title(tl,{'36:3:2 square pot - EE-style geometry and layer comparison', ...
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
exportgraphics(fig,fullfile(out,'SquarePot_EE_style_design.png'),'Resolution',180);
savefig(fig,fullfile(out,'SquarePot_EE_style_design.fig'));
end
function dimH(ax,x1,x2,y,label)
plot(ax,[x1 x2],[y y],'k-'); plot(ax,x1,y,'k>'); plot(ax,x2,y,'k<');
text(ax,(x1+x2)/2,y+1,label,'HorizontalAlignment','center','FontSize',9);
end


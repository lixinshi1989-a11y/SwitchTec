function flybackPlotPotGeometryComparison(C,G,Edited,D25,D24,windows,out,options)
% Geometry companions to the four rows of the Pot loss/B comparison.
labels={'Thick pot / target Lm=2.3 mH','Edited square D27.08 / original gap', ...
    'Square D25 / target Lm=2.3 mH','Square D24 / core 43x43 / Lm=2.3 mH'};
heights=C.CoreHeight_mm';
boards=[reshape(G.pcb_size_mm(1:2),1,2);Edited.BoardX_mm Edited.BoardY_mm; ...
    D25.BoardX_mm D25.BoardY_mm;D24.BoardX_mm D24.BoardY_mm];
isThick=[true false false false];
fileStem='Flyback_Pot_D25_geometry_comparison';
heading='36:3:2 Pot geometry comparison / same cases as loss and B comparison';
if nargin>=8
    labels=options.labels; boards=options.boards; isThick=options.isThick;
    fileStem=options.fileStem; heading=options.heading;
end
fig=figure('Color','w','Position',[20 30 2450 1850]);
tl=tiledlayout(fig,4,4,'TileSpacing','compact','Padding','compact');
title(tl,{heading, ...
    'Common geometric scales within each row | red P / blue S / green AUX | winding envelopes, not connected PCB routing'});
plans=gobjects(1,4); sections=plans;
ang=linspace(0,2*pi,1001); aa=ang(1:end-1);
for k=1:4
    r=C.Diameter_mm(k)/2; a=C.CoreSide_mm(k)/2;
    pw=.2; sw=2.2; pb=G.primary_breadth_mm; sb=G.secondary_breadth_mm;
    if ismember('PrimaryWidth_mm',C.Properties.VariableNames)
        pw=C.PrimaryWidth_mm(k); sw=C.SecondaryWidth_mm(k);
        pb=C.PrimaryBreadth_mm(k); sb=C.SecondaryBreadth_mm(k);
    end
    rw=windows(k); t=C.Yoke_mm(k); gap=C.Gap_mm(k); height=heights(k);
    bx=boards(k,1); by=boards(k,2);
    if isThick(k)
        c=G.outer_corner_chamfer_mm;
        xy=[-a+c -a;a-c -a;a -a+c;a a-c;a-c a;-a+c a;-a a-c;-a -a+c];
    else
        xy=[-a -a;a -a;a a;-a a];
    end
    footprint=polyshape(xy(:,1),xy(:,2));
    returns=subtract(footprint,polyshape(rw*cos(aa),rw*sin(aa)));
    if isThick(k)
        returns=subtract(returns,polyshape([-10 10 10 -10],[-a-1 -a-1 a+1 a+1]));
    end
    ax=nexttile(tl,k); plans(k)=ax; hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
    plot(ax,returns,'FaceColor',[.72 .72 .72],'FaceAlpha',1);
    plot(ax,[xy(:,1);xy(1,1)],[xy(:,2);xy(1,2)],'--','Color',[.4 .4 .4]);
    rectangle(ax,'Position',[-r -r 2*r 2*r],'Curvature',[1 1],'FaceColor',[.72 .72 .72]);
    rectangle(ax,'Position',[-bx/2 -by/2 bx by],'LineStyle',':');
    for j=0:2
        rad=r+2+sw/2+j*(sw+.2+G.transition_allowance_mm.secondary);
        plot(ax,rad*cos(ang),rad*sin(ang),'Color',[.1 .3 .8]);
    end
    for j=0:17
        rad=r+2+pw/2+j*(pw+.2+G.transition_allowance_mm.primary);
        plot(ax,rad*cos(ang),rad*sin(ang),'Color',[.8 .1 .1]);
    end
    rad=r+2+pb/2;
    plot(ax,rad*cos(ang),rad*sin(ang),'Color',[0 .5 .2],'LineWidth',1.2);
    plot(ax,[-r r],[0 0],'k-');
    text(ax,0,1,sprintf('D %.2f mm',2*r),'HorizontalAlignment','center');
    % Yoke samples are projected onto the plan; they lie in the solid
    % upper/lower yoke, not in the air window at the winding plane.
    cornerRadius=sqrt(2)*a;
    if isThick(k), cornerRadius=cornerRadius-G.outer_corner_chamfer_mm/sqrt(2); end
    returnRadius=(rw+cornerRadius)/2;
    fluxR=[r (r+rw)/2 rw];
    plot(ax,-fluxR/sqrt(2),-fluxR/sqrt(2),'k--','LineWidth',1.2);
    positions=[0 -r/2;returnRadius/sqrt(2) returnRadius/sqrt(2); ...
        -fluxR'/sqrt(2) -fluxR'/sqrt(2)];
    tags={'C','R','I','M','O'};
    for n=1:5
        plot(ax,positions(n,1),positions(n,2),'ko','MarkerFaceColor',[1 .85 .15],'MarkerSize',6);
        text(ax,positions(n,1)+1,positions(n,2),tags{n},'FontWeight','bold', ...
            'BackgroundColor','w','Margin',1,'FontSize',10);
    end
    flybackOverallDimensions(ax,-bx/2,bx/2,-by/2,by/2,'PCB X','PCB Y');
    title(ax,{labels{k},sprintf('Core X/Y %.2f / %.2f mm; D %.2f mm',2*a,2*a,2*r), ...
        sprintf('Core %.3f + Cu %.3f = %.3f W',C.Core_W(k),C.Copper_W(k),C.Total_W(k))});
    xlabel(ax,'X (mm)'); ylabel(ax,'Y (mm)');
    ax=nexttile(tl,k+4); sections(k)=ax; hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
    stem=(height-gap)/2-t;
    for signZ=[-1 1]
        if signZ==1, yz=height/2-t; lz=gap/2; else, yz=-height/2; lz=-gap/2-stem; end
        rectangle(ax,'Position',[-a yz 2*a t],'FaceColor',[.72 .72 .72]);
        rectangle(ax,'Position',[-r lz 2*r stem],'FaceColor',[.72 .72 .72]);
        if isThick(k)
            rectangle(ax,'Position',[-a lz a-rw stem],'FaceColor',[.72 .72 .72]);
            rectangle(ax,'Position',[rw lz a-rw stem],'FaceColor',[.72 .72 .72]);
        end
    end
    % PCB envelope and centre opening at Y=0 (outer-wall cutouts omitted).
    for span=[-bx/2 -r-.3;r+.3 bx/2]'
        rectangle(ax,'Position',[span(1) -G.pcb_size_mm(3)/2 diff(span) G.pcb_size_mm(3)],'LineStyle',':');
    end
    flybackOverallDimensions(ax,-bx/2,bx/2,-height/2,height/2,'Overall X','Core Z');
    title(ax,{sprintf('Y=0 section; yoke %.2f mm; volume %.2f cm^3',t,C.CoreVolume_cm3(k)), ...
        sprintf('Gap %.5f mm; Lm %.3f mH',gap,C.Lm_mH(k))});
    xlabel(ax,'X (mm)'); ylabel(ax,'Z (mm)');
    ax=nexttile(tl,k+8); hold(ax,'on'); axis(ax,[0 100 0 10]); axis(ax,'off');
    for layer=1:8
        y=9-layer; plot(ax,[8 96],[y y],'Color',[.85 .85 .85]); text(ax,1,y,sprintf('L%d',layer));
        if layer==1, text(ax,50,y,'Terminal / via access','HorizontalAlignment','center'); continue;
        elseif layer<=3, color=[.8 .1 .1]; label=sprintf('P 18T / %.4f mm',pw);
        elseif layer<=5, color=[0 .5 .2]; label='AUX 1T / 0.20 mm';
        else, color=[.1 .3 .8]; label=sprintf('S 3T / %.4f mm',sw); end
        plot(ax,[15 90],[y y],'Color',color,'LineWidth',4);
        text(ax,52,y+.23,label,'HorizontalAlignment','center');
    end
    title(ax,{'P: 18+18 series | S: 3T x 3 parallel | AUX: 1+1', ...
        sprintf('P/S breadth %.3f / %.3f mm; spacing rule 0.20 mm',pb,sb), ...
        sprintf('8-layer PCB %.3f mm; AUX centred in P band',G.pcb_size_mm(3))});
    ax=nexttile(tl,k+12); axis(ax,[0 1 0 1]); axis(ax,'off');
    values=[C.CentreB_mT(k) C.ReturnB_mT(k) C.YokeInnerB_mT(k) ...
        C.YokeMiddleB_mT(k) C.YokeOuterB_mT(k)];
    rows={sprintf('C  Centre post: Bpk = %.1f mT',values(1)), ...
        sprintf('R  Return posts / wall: Bpk = %.1f mT',values(2)), ...
        sprintf('I   Yoke inner   r = %.2f mm: %.1f mT',fluxR(1),values(3)), ...
        sprintf('M  Yoke middle r = %.2f mm: %.1f mT',fluxR(2),values(4)), ...
        sprintf('O  Yoke outer   r = %.2f mm: %.1f mT',fluxR(3),values(5))};
    for n=1:5
        text(ax,.02,.95-(n-1)*.14,rows{n},'FontSize',11,'Interpreter','none');
    end
    text(ax,.02,.16,{'I/M/O: projected upper/lower yoke locations.', ...
        'C/R: regional mean; yoke: mean over radial section.', ...
        'Peak B at design envelope; analytical, not local FEA B.'}, ...
        'FontSize',9,'VerticalAlignment','top');
    title(ax,'Flux-density positions and B peak (mT)');
end
for group={plans,sections}
    axs=group{1}; xx=vertcat(axs.XLim); yy=vertcat(axs.YLim);
    for ax=axs, xlim(ax,[min(xx(:,1)) max(xx(:,2))]); ylim(ax,[min(yy(:,1)) max(yy(:,2))]); end
end
exportgraphics(fig,fullfile(out,[fileStem '.png']),'Resolution',180);
exportgraphics(fig,fullfile(out,[fileStem '.pdf']),'ContentType','vector');
savefig(fig,fullfile(out,[fileStem '.fig']));
end

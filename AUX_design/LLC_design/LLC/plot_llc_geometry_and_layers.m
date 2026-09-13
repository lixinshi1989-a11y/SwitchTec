function plot_llc_geometry_and_layers(E,C,P,outDir,paths,layers,nets)
% Dimensioned geometry and layer assignment, using the actual routed paths.
% All plotting coordinates are mm. Layer summary is schematic in Z.
boardX=60; boardY=36; boardT=C.PCBthickness*1e3;
coreL=C.length*1e3; depth=C.legDepth*1e3; leg=C.legHeight*1e3;
pitch=C.legPitch*1e3; h=C.Uheight*1e3; gap=C.gapEachJoint*1e3;
totalH=2*h+gap; stem=h-leg; g=gap/2;
palette=[0 114 189;217 83 25;237 177 32;126 47 142]/255;
pcolor=[.86 .08 .08];
physicalVolume=2*(coreL*depth*leg+2*leg*depth*stem)/1000;

fg=figure('Color','w','Position',[70 70 1450 660]);
tg=tiledlayout(fg,1,2,'Padding','loose','TileSpacing','loose');
ax=nexttile(tg); top_view(ax,true);
title(ax,{'Plan view: PCB and routed copper', ...
    sprintf('PCB %.0f x %.0f mm; core legs %.0f x %.0f mm',boardX,boardY,leg,depth)},'FontSize',12);
ax=nexttile(tg); hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
set(ax,'FontSize',10); ax.Toolbar.Visible='off';
grey=[.70 .70 .70];
for signZ=[-1 1]
    if signZ>0, yokeZ=g+stem; legZ=g; else, yokeZ=-g-h; legZ=-g-stem; end
    rectangle(ax,'Position',[-coreL/2 yokeZ coreL leg],'FaceColor',grey,'EdgeColor',[.2 .2 .2]);
    for cx=[-pitch/2 pitch/2]
        rectangle(ax,'Position',[cx-leg/2 legZ leg stem],'FaceColor',grey,'EdgeColor',[.2 .2 .2]);
    end
end
rectangle(ax,'Position',[-boardX/2 -boardT/2 boardX boardT], ...
    'EdgeColor',[.2 .2 .2],'LineStyle','--','LineWidth',1);
dim_x(ax,-boardX/2,boardX/2,-14,-boardT/2,sprintf('Overall X %.1f mm',boardX));
dim_x(ax,-coreL/2,coreL/2,13,totalH/2,sprintf('Core X %.1f mm',coreL));
dim_y(ax,36,-totalH/2,totalH/2,coreL/2,sprintf('Overall Z %.3f mm',totalH));
text(ax,0,-20.5,sprintf('PCB %.3f mm; core-to-PCB clearance %.3f mm per side', ...
    boardT,C.coreToPCBSurface*1e3),'HorizontalAlignment','center','FontSize',10);
xlim(ax,[-35 43]); ylim(ax,[-24 18]); xlabel(ax,'X (mm)'); ylabel(ax,'Z (mm)');
title(ax,{'UU assembly: side section', ...
    sprintf('Core %.1f x %.1f x %.3f mm; ferrite %.3f cm^3',coreL,depth,totalH,physicalVolume), ...
    sprintf('Each joint gap %.6f mm (not exaggerated)',gap)},'FontSize',12);
file=fullfile(outDir,'LLC_7x14_geometry_dimensioned.png');
exportgraphics(fg,file,'Resolution',220); fprintf('Dimensioned geometry: %s\n',file);

fl=figure('Color','w','Position',[100 40 930 1150]);
tl=tiledlayout(fl,2,1,'Padding','loose','TileSpacing','loose');
ax=nexttile(tl); top_view(ax,true);
title(ax,{'LLC UU | four independent 4-turn secondaries', ...
    sprintf('PCB %.0f x %.0f mm; P-S copper gap %.1f mm; paired leads 1.0 mm', ...
    boardX,boardY,P.sectionGap*1e3)},'FontSize',12);
ax=nexttile(tl); hold(ax,'on'); ax.Toolbar.Visible='off';
set(ax,'YDir','reverse','YTick',1:8,'YTickLabel',compose('L%d',1:8), ...
    'XTick',[],'FontSize',11,'Box','off');
xlim(ax,[-1 11]); ylim(ax,[.35 8.65]);
for layer=1:8, plot(ax,[0 10],[layer layer],'-','Color',[.83 .83 .83]); end
barline(ax,[.5 4.3],1,pcolor,'P start / return leads',true);
barline(ax,[.5 4.3],2,pcolor,'P 3T (parallel)',false);
barline(ax,[.5 4.3],3,pcolor,'P 3T (parallel)',false);
barline(ax,[5.6 9.8],1,palette(1,:),'S1 4T',false);
barline(ax,[5.6 7.4],2,palette(1,:),'S1 return',true);
barline(ax,[8.0 9.8],2,palette(2,:),'S2 return',true);
barline(ax,[5.6 9.8],3,palette(2,:),'S2 4T',false);
barline(ax,[5.6 9.8],6,palette(3,:),'S3 4T',false);
barline(ax,[5.6 7.4],7,palette(3,:),'S3 return',true);
barline(ax,[8.0 9.8],7,palette(4,:),'S4 return',true);
barline(ax,[5.6 9.8],8,palette(4,:),'S4 4T',false);
for layer=[4 5], text(ax,5,layer-.16,'No winding copper','Color',[.5 .5 .5], ...
    'HorizontalAlignment','center','FontSize',10); end
title(ax,{'Layer assignment (schematic spacing)', ...
    'Left: primary leg    |    Right: secondary leg', ...
    'Solid: turns; dashed: leads only. Returns are not additional turns.'},'FontSize',11);
xlabel(ax,{'S1: L1 -> L2; S2: L3 -> L2; S3: L6 -> L7; S4: L8 -> L7', ...
    'S1/S4 front; S2/S3 back. Each pair: 1 mm XY copper-edge gap.'},'FontSize',10);
file=fullfile(outDir,'LLC_7x14_layer_assignment.png');
exportgraphics(fl,file,'Resolution',220); fprintf('Layer assignment: %s\n',file);

    function top_view(a,dimensions)
        hold(a,'on'); axis(a,'equal'); grid(a,'on'); a.Toolbar.Visible='off';
        set(a,'FontSize',10);
        rectangle(a,'Position',[-boardX/2 -boardY/2 boardX boardY], ...
            'LineStyle',':','EdgeColor',[.4 .4 .4],'LineWidth',1.2);
        for cx=[-pitch/2 pitch/2]
            rectangle(a,'Position',[cx-leg/2 -depth/2 leg depth], ...
                'FaceColor',[.72 .72 .72],'EdgeColor',[.2 .2 .2]);
        end
        for j=1:numel(paths)
            col=pcolor; if nets(j)>1, col=palette(nets(j)-1,:); end
            q=paths{j}; plot(a,q(:,1),q(:,2),'-','Color',col,'LineWidth',1.1);
        end
        rightP=-pitch/2+leg/2+P.clearance*1e3+P.primaryBuild*1e3;
        leftS=pitch/2-leg/2-P.clearance*1e3-P.secondaryBuild*1e3;
        plot(a,[rightP leftS],[0 0],'-','Color',[.9 .4 0],'LineWidth',1.2);
        plot(a,rightP,0,'>','Color',[.9 .4 0],'MarkerFaceColor',[.9 .4 0],'MarkerSize',5);
        plot(a,leftS,0,'<','Color',[.9 .4 0],'MarkerFaceColor',[.9 .4 0],'MarkerSize',5);
        text(a,(rightP+leftS)/2,1.6,sprintf('%.1f mm',leftS-rightP), ...
            'Color',[.8 .3 0],'FontSize',10,'HorizontalAlignment','center');
        if dimensions
            dim_x(a,-boardX/2,boardX/2,-23,-boardY/2,sprintf('PCB X %.1f mm',boardX));
            dim_y(a,35,-boardY/2,boardY/2,boardX/2,sprintf('PCB Y %.1f mm',boardY));
        end
        xlim(a,[-34 42]); ylim(a,[-29 22]); xlabel(a,'X (mm)'); ylabel(a,'Y (mm)');
    end
end

function barline(ax,x,y,col,label,dashed)
style='-'; width=5; if dashed, style='--'; width=3; end
plot(ax,x,[y y],style,'Color',col,'LineWidth',width);
text(ax,mean(x),y-.19,label,'HorizontalAlignment','center','FontSize',10);
end

function dim_x(ax,x1,x2,y,anchor,label)
col=[.2 .2 .2];
plot(ax,[x1 x1],[anchor y],'-','Color',col,'LineWidth',.7);
plot(ax,[x2 x2],[anchor y],'-','Color',col,'LineWidth',.7);
plot(ax,[x1 x2],[y y],'-','Color',col,'LineWidth',.7);
plot(ax,x1,y,'>','Color',col,'MarkerFaceColor',col,'MarkerSize',5);
plot(ax,x2,y,'<','Color',col,'MarkerFaceColor',col,'MarkerSize',5);
text(ax,mean([x1 x2]),y-1.5,label,'HorizontalAlignment','center', ...
    'VerticalAlignment','top','FontSize',10);
end

function dim_y(ax,x,y1,y2,anchor,label)
col=[.2 .2 .2];
plot(ax,[anchor x],[y1 y1],'-','Color',col,'LineWidth',.7);
plot(ax,[anchor x],[y2 y2],'-','Color',col,'LineWidth',.7);
plot(ax,[x x],[y1 y2],'-','Color',col,'LineWidth',.7);
plot(ax,x,y1,'^','Color',col,'MarkerFaceColor',col,'MarkerSize',5);
plot(ax,x,y2,'v','Color',col,'MarkerFaceColor',col,'MarkerSize',5);
text(ax,x+2,mean([y1 y2]),label,'Rotation',90,'HorizontalAlignment','center','FontSize',10);
end

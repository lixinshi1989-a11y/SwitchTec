function flybackOverallDimensions(ax,x1,x2,y1,y2,hlabel,vlabel)
% Dimension the outside envelope, not winding centre lines.
d=.075*max(x2-x1,y2-y1); c=[.15 .15 .15];
plot(ax,[x1 x1 x2 x2],[y1 y1-d y1-d y1],'Color',c);
plot(ax,x1,y1-d,'>','Color',c,'MarkerFaceColor',c);
plot(ax,x2,y1-d,'<','Color',c,'MarkerFaceColor',c);
text(ax,(x1+x2)/2,y1-1.3*d,sprintf('%s %.1f mm',hlabel,x2-x1), ...
    'HorizontalAlignment','center','VerticalAlignment','top','FontSize',10);
plot(ax,[x2 x2+d x2+d x2],[y1 y1 y2 y2],'Color',c);
plot(ax,x2+d,y1,'^','Color',c,'MarkerFaceColor',c);
plot(ax,x2+d,y2,'v','Color',c,'MarkerFaceColor',c);
text(ax,x2+1.5*d,(y1+y2)/2,sprintf('%s %.1f mm',vlabel,y2-y1), ...
    'Rotation',90,'HorizontalAlignment','center','VerticalAlignment','top','FontSize',10);
xlim(ax,[x1-.5*d x2+2.7*d]); ylim(ax,[y1-2.8*d y2+.6*d]);
end

function C=flybackComparePotD23to20(E,W,M,G,S,D24,out)
% Fixed outer core AND cavity from the D24/43 mm reference. Only the centre
% post/winding radii vary. This preserves the same corner returns and exits.
diameters=[23 22 21 20];
for k=1:4
    local=S;
    local.window_mm=D24.WindowRadius_mm-diameters(k)/2;
    local.outerInset_mm=D24.WindowRadius_mm-43/2;
    % Fill the additional radial window while preserving 2 mm clearance
    % at BOTH the centre post and the outer return core.
    breadth=local.window_mm-2*W.coreClearance_mm;
    winding=W; geometry=G;
    winding.primaryWidth_mm=(breadth-17*(W.traceSpacing_mm+G.transition_allowance_mm.primary))/18;
    winding.secondaryWidth_mm=(breadth-2*(W.traceSpacing_mm+G.transition_allowance_mm.secondary))/3;
    geometry.primary_breadth_mm=breadth; geometry.secondary_breadth_mm=breadth;
    assert(winding.primaryWidth_mm>0 && winding.secondaryWidth_mm>0);
    [q,env]=flybackEvaluateSquarePot(diameters(k)/2,true,local,E,winding,M,geometry);
    q.PrimaryWidth_mm=winding.primaryWidth_mm;
    q.SecondaryWidth_mm=winding.secondaryWidth_mm;
    q.PrimaryBreadth_mm=breadth; q.SecondaryBreadth_mm=breadth;
    q.TraceSpacing_mm=W.traceSpacing_mm;
    q.CoreCopperClearance_mm=W.coreClearance_mm;
    q.AuxRadialCentre_mm=diameters(k)/2+W.coreClearance_mm+breadth/2;
    assert(abs(q.WindowRadius_mm-(diameters(k)/2+W.coreClearance_mm+breadth)-2)<1e-9);
    assert(abs(q.CoreSide_mm-43)<1e-9 && abs(q.WindowRadius_mm-D24.WindowRadius_mm)<1e-9);
    q.Yoke_mm=S.yoke_mm;
    q.RadialWindow_mm=local.window_mm;
    q.IpRms_A=env.IpRms; q.IsRms_A=env.IsRms;
    if k==1, designs=q; else, designs(k)=q; end %#ok<AGROW>
end
C=struct2table(designs);
C.Design=compose('Square D%d / core 43x43 / Lm=2.3 mH',diameters');
C=movevars(C,'Design','Before',1);
options=struct('labels',{{'D23 / core 43x43 / Lm=2.3 mH', ...
    'D22 / core 43x43 / Lm=2.3 mH','D21 / core 43x43 / Lm=2.3 mH','D20 / core 43x43 / Lm=2.3 mH'}}, ...
    'boards',[C.BoardX_mm C.BoardY_mm],'isThick',false(1,4), ...
    'fileStem','Flyback_Pot_D23_D22_D21_D20_geometry_comparison', ...
    'heading','36:3:2 / D23, D22, D21, D20 / fixed 43x43 mm core, 4 mm yokes, cavity radius 23 mm');
flybackPlotPotGeometryComparison(C,G,designs(1),designs(2),designs(3),C.WindowRadius_mm',out,options);
writetable(C,fullfile(out,'Flyback_Pot_D23_D22_D21_D20_comparison.csv'));
save(fullfile(out,'Flyback_Pot_D23_D22_D21_D20_designs.mat'),'C','designs','options');
disp(C(:,{'Design','PrimaryWidth_mm','SecondaryWidth_mm','PrimaryBreadth_mm','Core_W','Copper_W','Total_W'}));
end

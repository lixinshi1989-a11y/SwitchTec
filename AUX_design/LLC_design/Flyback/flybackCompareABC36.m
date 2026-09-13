function [Schemes,Comparison]=flybackCompareABC36(G3,E,W,M,outDir)
% Adapt the 36:3:2 selected winding to the common comparison model.
B.Leg_mm=G3.leg; B.PrimaryWidth_mm=W.primaryWidth_mm;
B.SecondaryWidth_mm=W.secondaryWidth_mm; B.SecondaryLeadWidth_mm=W.busWidth_mm;
B.BoardX_mm=82; B.BoardY_mm=62; % existing routed C envelope
B.CoreX_mm=G3.length; B.CoreHeight_mm=2*G3.Uheight+G3.gEach_mm;
B.Window_mm=G3.window; B.GapEach_mm=G3.gEach_mm;
B.CoreVolume_cm3=G3.Ve_cm3; B.Bpk_mT=G3.Bpk_mT;
B.PSgap_mm=G3.verticalPS_mm; B.LeakagePri_uH=G3.LlkPri_H*1e6;
B.SecondaryEnvelope_W=G3.Psecondary_W; B.PrimaryEnvelope_W=G3.Pprimary_W; B.AuxEnvelope_W=G3.Paux_W;
B.CopperEnvelope_W=G3.Pwinding_W; B.CopperNominal_W=G3.PwindingNominal_W;
B.CoreEnvelope_W=G3.Pcore_W; B.CoreNominal_W=G3.PcoreNominal_W;
V.pTurns=W.primaryTurnsPerLayer; V.sTurns=W.secondaryTurnsPerLayer;
V.aTurns=[1 1]; V.pLayers=W.primaryLayerIds; V.sLayers=W.secondaryLayerIds;
V.aLayers=W.auxLayerIds; V.spacing_mm=W.traceSpacing_mm;
V.coreCopper_mm=W.coreClearance_mm; V.corePCB_mm=1; V.edgeMargin_mm=3;
V.boardThickness_mm=G3.pcbThickness; V.cu_mm=W.copperThickness_mm;
V.rho=W.rhoCu*W.copperTempFactor; V.auxWidth_mm=W.auxWidth_mm;
V.sShare=W.secondaryCurrentShare; V.busCopper_mm=W.busCopper_mm; V.maxJ_Amm2=16; V.FacS=W.FacSecondary; V.FacA=W.FacAux; V.FacP=W.FacPrimary;
F=E; F.envelope.IsRms=E.IsecRms; F.auxRms=E.IauxRms; F.envelope.IpRms=E.IpriRms; F.nominal.IpRms=E.nominalIpriRms;
% Reconstruct equivalent existing lengths from the audited copper losses.
B.PrimaryLayerLength_mm=B.PrimaryEnvelope_W/(F.envelope.IpRms^2*V.FacP* ...
    sum(V.rho./(B.PrimaryWidth_mm*V.cu_mm(V.pLayers)*1e-6)))*1e3;
B.AuxLayerLength_mm=ones(1,2)*B.AuxEnvelope_W/(F.auxRms^2*V.FacA* ...
    sum(V.rho./(V.auxWidth_mm*V.cu_mm(V.aLayers)*1e-6)))*1e3;
N.mur=M.mui; S.maxBoardX_mm=120; S.maxBoardY_mm=100;
S.minGapEach_mm=.05; S.maxGapEach_mm=2;
[Schemes,Comparison]=flybackCompareABC484(B,F,V,N,S,outDir);
copyfile(fullfile(outDir,'Flyback_36_3_2_ABCD_layout.png'), ...
    fullfile(outDir,'Flyback_TPG33_four_winding_schemes_2D.png'));
end

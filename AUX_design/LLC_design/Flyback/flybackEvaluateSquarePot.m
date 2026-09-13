function [q,env,nom]=flybackEvaluateSquarePot(R,holdLm,S,E,W,M,G)
mu0=4*pi*1e-7; RW=R+S.window_mm; RO=RW-S.outerInset_mm; yoke=S.yoke_mm;
Ac=pi*R^2; Afoot=4*RO^2;
assert(RO<RW && RW<sqrt(2)*RO);
% Four actual corner posts: square minus the circular cavity intersection.
Acavity=pi*RW^2-4*(RW^2*acos(RO/RW)-RO*sqrt(RW^2-RO^2));
Ar=Afoot-Acavity;
theta=@(r) 2*pi-8*acos(min(1,RO./r));
radRel=integral(@(r) 2./(mu0*M.mui*theta(r).*r*yoke)*1e3,R,RW,'Waypoints',RO);
gapCoeff=1/(mu0*Ac*1e-6)+1/(mu0*Ar*1e-6);
% Keep total core height and PCB clearances as edited; gap adjusts leg height.
RcAt=@(g) (S.height_mm-2*yoke-g+yoke)*1e-3/(mu0*M.mui)*(1/(Ac*1e-6)+1/(Ar*1e-6))+radRel;
if holdLm
    gap=(E.Np^2/S.targetLm_H-RcAt(0))/(gapCoeff*1e-3*(1-1/M.mui));
else
    gap=S.referenceGap_mm;
end
stem=(S.height_mm-gap)/2-yoke;
Rcore=RcAt(gap); Lm=E.Np^2/(Rcore+gap*1e-3*gapCoeff);
Vcore=2*yoke*Afoot+2*stem*(Ac+Ar);
Geom=struct('Ac_mm2',Ac,'Ar_mm2',Ar,'Vcore_mm3',Vcore, ...
    'Vcentre_mm3',2*(stem+yoke)*Ac,'Vreturn_mm3',2*(stem+yoke)*Ar, ...
    'radialEquivalent_mm3',integral(@(r) (Ac./(theta(r).*r*yoke)).^M.beta.*(2*theta(r).*r*yoke),R,RW,'Waypoints',RO));
G.aux_radial_centre_mm=R+2+G.primary_breadth_mm/2;
G.pcb_size_mm(2)=max(62,ceil(2*(R+2+G.primary_breadth_mm+3)));
boardHalf=G.pcb_size_mm(2)/2;
auxAccess=max(25,R+2+G.primary_breadth_mm+1.5);
z=G.layer_z_mm(:)'; cu=G.copper_mm(:)';
rho=W.rhoCu*W.copperTempFactor;
pp=W.primaryWidth_mm+W.traceSpacing_mm+G.transition_allowance_mm.primary;
sp=W.secondaryWidth_mm+W.traceSpacing_mm+G.transition_allowance_mm.secondary;
pInner=R+W.coreClearance_mm+W.primaryWidth_mm/2;
sInner=R+W.coreClearance_mm+W.secondaryWidth_mm/2;
ar=G.aux_radial_centre_mm;
[pLength,pOuter,~]=spiralLength(18,pInner,pp,10);
% Inner extra 10-degree arc to the series via; outer lead to Y=-31.
pLength=pLength+pInner*deg2rad(10)+(boardHalf+ pOuter(2));
[sLength,sOuter,sEnd]=spiralLength(3,sInner,sp,30);
[aLength,aOuter,~]=spiralLength(1,ar,W.auxWidth_mm+W.traceSpacing_mm,10);
aLength=aLength+ar*deg2rad(10)+(auxAccess+aOuter(2));
rP=rho*pLength*1e-3./(W.primaryWidth_mm*cu([2 3])*1e-6);
rS=rho*sLength*1e-3./(W.secondaryWidth_mm*cu([6 7 8])*1e-6);
rA=rho*aLength*1e-3./(W.auxWidth_mm*cu([4 5])*1e-6);
rPvia=rho*abs(z(2)-z(3))*1e-3/(pi*(.1e-3)^2);
rAseries=rho*abs(z(4)-z(5))*1e-3/(pi*(.1e-3)^2);
rAaccess=rho*sum(abs(z(1)-z([4 5])))*1e-3/(pi*(.1e-3)^2);
rAleads=rho*(2*(boardHalf-auxAccess))*1e-3/(W.auxWidth_mm*cu(1)*1e-6);
% S endpoints reflected into +Y, exactly as in the builder.
endpoints=[sOuter;sEnd].*[1 -1];
busZ=-G.pcb_size_mm(3)/2-.5-.069/2;
busWideLength=zeros(1,2); busNeckLength=zeros(1,2);
for k=1:2
    x=endpoints(k,1); y=endpoints(k,2); lane=sign(x)*4.55;
    by=max(y,R+2+6.5/2);
    busWideLength(k)=boardHalf-by;
    busNeckLength(k)=by-y+abs(lane-x);
end
rBus=rho*sum(busWideLength)*1e-3/(6.5*.069*1e-6)+ ...
     rho*sum(busNeckLength)*1e-3/(W.secondaryWidth_mm*.069*1e-6);
sViaArea=pi*(1.1e-3)^2;
rVia67=rho*abs(z(6)-z(7))*1e-3/sViaArea;
rVia78=rho*abs(z(7)-z(8))*1e-3/sViaArea;
rPosts=2*rho*abs(z(8)-busZ)*1e-3/sViaArea;
share=(1./rS)/sum(1./rS);
% DC layer sharing approximation; via resistance is small but its I^2R is
% included below. Final AC sharing and proximity effects require the solver.
Res=struct('rP',rP,'rS',rS,'rA',rA,'rPvia',rPvia, ...
    'rAextra',rAseries+rAaccess+rAleads,'rBus',rBus,'rPosts',rPosts, ...
    'rVia67',rVia67,'rVia78',rVia78,'share',share);


env=operatingPoint(Lm,E.eta,E,W,M,Geom,Res);
nom=operatingPoint(Lm,1,E,W,M,Geom,Res);
ry=linspace(R,RW,300);
yokeRatio=max(Ac./(theta(ry).*ry*yoke));
peak=[env.Bpk_mT env.Bpk_mT*Ac/Ar env.Bpk_mT*yokeRatio];
Jp=env.IpRms/(W.primaryWidth_mm*min(cu([2 3])));
Js=max(env.IsRms*share./(W.secondaryWidth_mm*cu([6 7 8])));
q=struct('Diameter_mm',2*R,'CentreArea_mm2',Ac,'ReturnArea_mm2',Ar,'CoreSide_mm',2*RO, ...
    'WindowRadius_mm',RW,'CoreHeight_mm',S.height_mm,'CoreVolume_cm3',Vcore/1000, ...
    'BoardX_mm',max(82,ceil(2*RO+6)),'BoardY_mm',2*boardHalf,'Gap_mm',gap,'Lm_mH',Lm*1e3, ...
    'CentreB_mT',peak(1),'ReturnB_mT',peak(2),'YokeB_mT',peak(3),'Core_W',env.Core_W, ...
    'Primary_W',env.Primary_W,'Secondary_W',env.Secondary_W,'Aux_W',env.Aux_W, ...
    'Copper_W',env.Copper_W,'Total_W',env.Total_W,'NominalTotal_W',nom.Total_W, ...
    'Jp_Amm2',Jp,'Js_Amm2',Js,'ConductionMode',string(env.ConductionMode), ...
    'Feasible',gap>=S.minGap_mm && gap<=S.maxGap_mm && max(peak)<=S.maxFlux_T*1e3 && ...
    2*boardHalf<=S.maxBoardY_mm && max(82,ceil(2*RO+6))<=S.maxBoardX_mm && max(Jp,Js)<=16 && stem>0);
sampleR=[R (R+RW)/2 RW];
sampleB=env.Bpk_mT*Ac./(theta(sampleR).*sampleR*yoke);
q.YokeInnerB_mT=sampleB(1);
q.YokeMiddleB_mT=sampleB(2);
q.YokeOuterB_mT=sampleB(3);
end

function [length_mm,outer,last]=spiralLength(n,inner,pitch,delta_deg)
a0=deg2rad(-90+delta_deg); a1=deg2rad(270-delta_deg);
length_mm=0;
for k=1:n
    r=inner+(n-k)*pitch;
    length_mm=length_mm+r*(a1-a0);
    if k==1, outer=r*[cos(a0) sin(a0)]; end
    last=r*[cos(a1) sin(a1)];
    if k<n
        mid=[0 -(r-pitch/2)]; finish=(r-pitch)*[cos(a0) sin(a0)];
        length_mm=length_mm+arcLength(last,mid,finish);
    end
end
end
function length_mm=arcLength(a,m,b)
c=(2*[m-a;b-a])\[sum(m.^2)-sum(a.^2);sum(b.^2)-sum(a.^2)]; c=c';
r=norm(a-c); t0=atan2(a(2)-c(2),a(1)-c(1)); tm=atan2(m(2)-c(2),m(1)-c(1)); t1=atan2(b(2)-c(2),b(1)-c(1));
d=mod(t1-t0,2*pi); if mod(tm-t0,2*pi)>d+1e-10, d=2*pi-d; end
length_mm=r*d;
end
function q=operatingPoint(L,eta,E,W,M,G,R)
ipk=sqrt(2*E.Pout/(eta*L*E.fs)); duty=ipk*L*E.fs/E.Vin;
demag=E.Vin*duty/(E.Vout*E.Np/E.Ns);
isDCM=duty+demag<1;
if isDCM
    ip=ipk*sqrt(duty/3); is=ipk*(E.Np/E.Ns)*sqrt(demag/3);
    ripple=ipk; mode='DCM';
else
    % CCM volt-second balance and input power determine the trapezoid.
    vref=E.Vout*E.Np/E.Ns;
    duty=vref/(E.Vin+vref); demag=1-duty;
    ripple=E.Vin*duty/(L*E.fs);
    meanOn=(E.Pout/eta)/(E.Vin*duty);
    ipk=meanOn+ripple/2;
    assert(meanOn-ripple/2>=-1e-10);
    ip=sqrt(duty*(meanOn^2+ripple^2/12));
    is=(E.Np/E.Ns)*sqrt(demag*(meanOn^2+ripple^2/12));
    mode='CCM';
end
bp=L*ipk/(E.Np*G.Ac_mm2*1e-6);
deltaB=L*ripple/(E.Np*G.Ac_mm2*1e-6);
pv=M.ki*E.fs^M.alpha*deltaB^M.beta*(duty^(1-M.alpha)+demag^(1-M.alpha));
pc=pv*G.Vcentre_mm3*1e-9;
pr=pv*(G.Ac_mm2/G.Ar_mm2)^M.beta*G.Vreturn_mm3*1e-9;
py=pv*G.radialEquivalent_mm3*1e-9;
p=ip^2*(sum(R.rP)+R.rPvia)*W.FacPrimary;
bus=is^2*R.rBus*W.FacSecondary;
vias=(2*((is*R.share(1))^2*R.rVia67+(is*sum(R.share(1:2)))^2*R.rVia78)+is^2*R.rPosts)*W.FacSecondary;
s=sum((is*R.share).^2.*R.rS)*W.FacSecondary+bus+vias;
a=E.IauxRms^2*(sum(R.rA)+R.rAextra)*W.FacAux;
q=struct('Lm_mH',L*1e3,'IpRms',ip,'IsRms',is,'D',duty,'Ddemag',demag,'DCM_OK',isDCM, ...
    'ConductionMode',mode,'DeltaB_mT',deltaB*1e3, ...
    'Bpk_mT',bp*1e3,'CoreCentre_W',pc,'CoreReturn_W',pr,'CoreRadial_W',py,'Core_W',pc+pr+py, ...
    'Primary_W',p,'Secondary_W',s,'Aux_W',a,'Bus_W',bus,'Vias_W',vias,'Copper_W',p+s+a,'Total_W',pc+pr+py+p+s+a);
end

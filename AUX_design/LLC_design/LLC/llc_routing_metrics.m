function R=llc_routing_metrics(E,C,P,rho)
% Centre-line routing matching build_llc_transformer_aedt.py (mm).
% Via resistance uses SOLID copper cylinders, matching AEDT, not plated holes.
assert(E.Np==3 && E.Ns==4 && abs(C.leg-0.010)<1e-9, ...
    'Selected routing is defined for the current 3:4, 10 mm leg design.');
z=zeros(1,8); b=-P.thickness/2;
for j=1:8
    z(j)=b+P.cu(j)/2; b=b+P.cu(j);
    if j<8, b=b+P.diel(j); end
end
paths={}; names={}; layers=[]; widths=[]; nets=[];
for j=[2 3]
    q=spiral(-13,3,P.wp*1e3,P.spacing*1e3,false);
    q(end+1,:)=[-19.1 q(end,2)]; add(q,j,P.wp,1,sprintf('P_L%d',j));
end
add([-27.4 0;-30 0],1,P.wp,1,'P_start_L1');
add([-19.1 -7.6;-19.1 -9;-30 -9],1,P.wp,1,'P_return_L1');
sl=[2 3 6 7]; vx=[17.9 19.4 19.4 17.9]; ry=[-9.15 -8.25 -8.25 -9.15];
R.vias=[-27.4 0 1 3 P.wp*1e3 1;-19.1 -7.6 1 3 P.wp*1e3 1];
for k=1:4
    j=sl(k); q=spiral(13,4,P.ws*1e3,P.spacing*1e3,true);
    if j==3, q=[q(1,:)+[0 3];q]; end
    if j==6, q=[q(1,:)+[0 -3];q]; end
    q(end+1,:)=[vx(k) q(end,2)]; add(q,j,P.ws,k+1,sprintf('S%d_L%d',k,j));
    surf=1; if j>4, surf=8; end
    add([q(1,:);30 q(1,2)],surf,P.ws,k+1,sprintf('S%d_start',k));
    add([q(end,:);vx(k) ry(k);30 ry(k)],surf,P.ws,k+1,sprintf('S%d_return',k));
    R.vias=[R.vias;q(1,:) min(j,surf) max(j,surf) P.ws*1e3 k+1; ...
        q(end,:) min(j,surf) max(j,surf) P.ws*1e3 k+1]; %#ok<AGROW>
end
len=cellfun(@(q)sum(sum(abs(diff(q)),2)),paths)'*1e-3;
res=rho*len./(widths(:).*P.cu(layers(:))');
R.pBuried=res(1:2); R.pCommon=sum(res(3:4)); R.sTotal=zeros(4,1);
vR=zeros(size(R.vias,1),1);
for k=1:numel(vR)
    v=R.vias(k,:); h=z(v(4))-z(v(3))+(P.cu(v(3))+P.cu(v(4)))/2;
    vR(k)=rho*h/(pi*(v(5)*1e-3/2)^2);
end
R.pCommon=R.pCommon+sum(vR(R.vias(:,6)==1));
for k=1:4, R.sTotal(k)=sum(res(nets==k+1))+sum(vR(R.vias(:,6)==k+1)); end
R.pEquivalent=1/sum(1./R.pBuried)+R.pCommon;
% Sinusoidal secondary with full-wave rectification; primary load component
% reflected by Ns/Np, plus triangular magnetising RMS in quadrature.
R.IsRms=pi/(2*sqrt(2))*E.IoutEach;
R.ImRms=E.Vpri/(4*E.f*E.Lm*sqrt(3));
R.IpRms=hypot(E.Nsec*R.IsRms/E.n,R.ImRms);
current=R.IsRms*ones(size(res)); current(nets==1)=R.IpRms;
current(1:2)=R.IpRms/2;
fac=1.7*ones(size(res)); fac(nets==1)=1.5;
R.components=table(string(names(:)),layers(:),len*1e3,res,current,current.^2.*res.*fac, ...
    'VariableNames',{'Trace','Layer','Length_mm','Rdc_ohm','EstimatedRMS_A','EstimatedACLoss_W'});
R.viaTable=array2table([R.vias vR],'VariableNames', ...
    {'X_mm','Y_mm','FirstLayer','LastLayer','SolidDiameter_mm','Net','Rdc_ohm'});
out=fullfile(fileparts(mfilename('fullpath')),'output'); if ~exist(out,'dir'),mkdir(out);end
writetable(R.components,fullfile(out,'LLC_routing_loss_components.csv'));
writetable(R.viaTable,fullfile(out,'LLC_routing_vias.csv'));
f=figure('Color','w','Position',[40 40 1500 820]); tl=tiledlayout(f,2,3);
for j=[1 2 3 6 7 8]
    ax=nexttile(tl); hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
    for cx=[-13 13], rectangle(ax,'Position',[cx-5 -5 10 10],'FaceColor',[.75 .75 .75]); end
    for k=find(layers==j)
        q=paths{k}; col=[.85 .12 .08]; if nets(k)>1,col=[.05 .35 .85];end
        plot(ax,q(:,1),q(:,2),'-','Color',col,'LineWidth',1.5);
    end
    for k=1:size(R.vias,1)
        v=R.vias(k,:);
        if j>=v(3) && j<=v(4),plot(ax,v(1),v(2),'ko','MarkerFaceColor','y');end
    end
    xlim(ax,[-32 32]);ylim(ax,[-13 13]);title(ax,sprintf('L%d (centre-line routing)',j));
    xlabel(ax,'x / mm');ylabel(ax,'y / mm');
end
title(tl,sprintf('Np:Ns=3:4; yellow-position vias, stagger=1.5 mm; Lm estimate %.2f uH; P/S trace %.2f/%.2f mm', ...
    E.Lm*1e6,P.wp*1e3,P.ws*1e3));
exportgraphics(f,fullfile(out,'LLC_YellowCircle_layer_routing.png'),'Resolution',180);
fprintf('Routing RMS estimate: primary %.3f A (magnetising %.3f A); each secondary %.3f A\n',R.IpRms,R.ImRms,R.IsRms);
fprintf('RMS assumes sinusoidal rectifier current plus triangular magnetising current; validate with circuit waveform.\n');
fprintf('Via resistance assumes solid copper as in AEDT; plated-via dimensions require separate input.\n');
    function add(q,layer,w,net,name)
        paths{end+1}=q; layers(end+1)=layer; widths(end+1)=w; nets(end+1)=net; names{end+1}=name;
    end
end
function q=spiral(cx,n,w,s,mirror)
p=w+s; a=5+2+w/2+(n-1)*p;
xl=cx-a; xr=cx+a; yb=-a; yt=a;
q=[xl-4 0;xl 0;xl yt];
for k=1:n
    q=[q;xr yt;xr yb]; %#ok<AGROW>
    if k<n
        q=[q;xl+p yb]; xl=xl+p; xr=xr-p; yb=yb+p; yt=yt-p;
        q=[q;xl yt]; %#ok<AGROW>
    end
end
if mirror,q(:,1)=2*cx-q(:,1);end
end

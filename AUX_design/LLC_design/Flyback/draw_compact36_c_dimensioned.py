"""Dimensioned winding envelopes and stack drawing from the current 36T C outputs.

Dimensions describe copper edges unless explicitly marked CL (centreline).
Closed rectangles are turn envelopes, not connected production PCB artwork.
"""
from pathlib import Path
import csv
import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from matplotlib.backends.backend_pdf import PdfPages

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'output' / '36_3_2_compact'
with (OUT/'Flyback_36_3_2_compact_summary.csv').open() as f:
    design = {k:float(v) for k,v in next(csv.DictReader(f)).items()}
geo = json.loads((OUT/'Flyback_36_3_2_Compact70mm_Connected_geometry.json').read_text())
cu = [.069,.064,.064,.064,.064,.064,.064,.069]
diel = [.346,.406,.393,.406,.406,.406,.360]
P,S,A = '#d62728','#146cc1','#159447'
plt.rcParams.update({'font.size':11,'axes.spines.top':False,'axes.spines.right':False})

def rect(ax,x,y,w,h,**kw):
    ax.add_patch(Rectangle((x,y),w,h,**kw))

def dim(ax,a,b,label,vertical=False,color='#333333',size=10):
    ax.annotate('',xy=b,xytext=a,arrowprops=dict(arrowstyle='<->',color=color,lw=1))
    x,y=(a[0]+b[0])/2,(a[1]+b[1])/2
    ax.text(x+(.9 if vertical else 0),y+(0 if vertical else .9),label,
            ha='left' if vertical else 'center',va='center' if vertical else 'bottom',
            rotation=90 if vertical else 0,color=color,fontsize=size,
            bbox=dict(facecolor='white',edgecolor='none',alpha=.85,pad=.3))

def table(ax,rows,headers,widths=None,fontsize=11):
    ax.axis('off')
    t=ax.table(cellText=rows,colLabels=headers,loc='center',cellLoc='center',colWidths=widths)
    t.auto_set_font_size(False);t.set_fontsize(fontsize);t.scale(1,1.65)
    for (r,c),cell in t.get_celld().items():
        cell.set_edgecolor('#cdd3dc')
        if r==0: cell.set_facecolor('#dfeaf5');cell.set_text_props(weight='bold')
        elif r%2==0:cell.set_facecolor('#f4f7fa')

fig=plt.figure(figsize=(19,13),layout='constrained')
gs=fig.add_gridspec(2,2,width_ratios=[1.2,1],height_ratios=[2,1])
ax=fig.add_subplot(gs[0,0]);ax.set_aspect('equal');ax.grid(alpha=.15)
rect(ax,-41,-31,82,62,fill=False,ls='--',ec='#555',lw=1.5)
for x,w in [(-35,12),(-12,24),(23,12)]:
    rect(ax,x,-12,w,24,facecolor='#b8bcc1',edgecolor='#555')
    rect(ax,x-.3,-12.3,w+.6,24.6,fill=False,ls=':',ec='#666')
for turns,width,col in [(3,2.2,S),(18,.2,P),(1,.2,A)]:
    for i in range(turns):
        r=17.5 if col==A else 12+2+width/2+i*(width+.2)
        # Draw actual radial trace width with an inner hole, using four strips.
        outer=r+width/2;inner=r-width/2
        alpha=.25 if col==S else 1
        for x,y,w,h in [(-outer,-outer,2*outer,width),(-outer,inner,2*outer,width),
                         (-outer,-inner,width,2*inner),(inner,-inner,width,2*inner)]:
            rect(ax,x,y,w,h,facecolor=col,edgecolor='none',alpha=alpha)
dim(ax,(-41,-38),(41,-38),'PCB X = 82.0')
dim(ax,(44,-31),(44,31),'PCB Y = 62.0',True)
dim(ax,(-35,37),(35,37),'Core X = 70.0')
for x0,x1,lab in [(-35,-23,'12'),(-23,-12,'11'),(-12,12,'24'),(12,23,'11'),(23,35,'12')]:
    dim(ax,(x0,29),(x1,29),lab,size=10)
dim(ax,(-38,-12),(-38,12),'Core Y = 24.0',True)
dim(ax,(-21,-26),(21,-26),'P/S copper envelope = 42.0')
ax.text(0,24,'Red: P  |  Blue: S  |  Green: AUX',ha='center',fontsize=10)
ax.text(0,-44,'Turn envelopes only; terminals, transitions and vias omitted.\nP/AUX exit -Y; S exits +Y in the connected AEDT.',ha='center',fontsize=10)
ax.set(xlim=(-47,50),ylim=(-48,42),xlabel='X (mm)',ylabel='Y (mm)',title='C: EE core / centre-leg windings / top view')

info=fig.add_subplot(gs[0,1]);info.axis('off')
text=(
    '36 : 3 : 2  |  100 kHz\n\n'
    'Input 2200 V   |   Output 24 V / 100 W\n'
    'Lm target: 2.300 mH (not a solved value)\n\n'
    'PCB: 82 x 62 x 3.245 mm\n'
    'Core: 70 x 24 x 29.245 mm; TPG33\n'
    'Centre leg: 24 x 24 mm\n'
    'Return legs: 12 x 24 mm each\n'
    'Two windows: 11 mm each; yoke: 12 mm\n'
    'Three joint gaps: {:.6f} mm each\n'
    'PCB surface to inner yoke: 1.000 mm\n'
    'Core-slot clearance: 0.300 mm / side\n\n'
    'PRIMARY: L2 + L3, 18T + 18T series\n'
    'SECONDARY: L6 || L7 || L8, 3T each\n'
    'AUX: L4 + L5, 1T + 1T series\n\n'
    'P/S radial copper breadth: 7.000 mm each\n'
    'AUX centre radius: 17.500 mm\n'
    'AUX clearances to P-band edges: 3.400 mm each\n'
    'Core-to-PCB X margin: 6 mm / side\n'
    'Coil-envelope-to-PCB Y margin: 10 mm / side\n'
    'External secondary bus: 6.50 x 0.069 mm\n\n'
    'Analytical estimates (80 C sizing envelope):\n'
    'Core {:.3f} W + copper {:.3f} W = {:.3f} W\n'
    'Leakage: P {:.2f} uH / S {:.4f} uH\n'
    'Loss/leakage estimates are not Maxwell results.'
).format(design['GapEach_mm'],design['CoreLoss_W'],design['CopperLoss_W'],design['TotalLoss_W'],
         design['LeakagePriEstimate_uH'],design['LeakagePriEstimate_uH']/144)
info.text(.02,.97,text,va='top',fontsize=12.5,linespacing=1.3)

rad=fig.add_subplot(gs[1,0]);rad.set_title('Radial detail: centre-leg right edge to return-leg left edge')
for y,turns,width,col,label in [(2,18,.2,P,'P: 18 turns / layer'),(1,3,2.2,S,'S: 3 turns / layer'),(0,1,.2,A,'AUX: 1 turn / layer')]:
    rad.text(11.8,y+.17,label,ha='right',va='center',color=col,fontsize=10)
    for i in range(turns):
        start=17.4 if col==A else 14+i*(width+.2)
        rect(rad,start,y,width,.35,facecolor=col)
for x in [12,14,17.5,21,23]:rad.axvline(x,ls=':',color='#aaa',lw=.8)
dim(rad,(12,3),(14,3),'2.0');dim(rad,(14,3),(21,3),'7.0');dim(rad,(21,3),(23,3),'2.0')
dim(rad,(14,-.7),(17.4,-.7),'3.4');dim(rad,(17.6,-.7),(21,-.7),'3.4')
rad.set(xlim=(7,24),ylim=(-1.4,4),xlabel='X / radius (mm) | P pitch 0.40; S pitch 2.40; clear spacing 0.20',yticks=[])

rows=[['L1','Leads only','0','AUX 0.20',69],['L2','Primary','18','0.20',64],
      ['L3','Primary','18','0.20',64],['L4','AUX','1','0.20',64],
      ['L5','AUX','1','0.20',64],['L6','Secondary','3','2.20',64],
      ['L7','Secondary','3','2.20',64],['L8','Secondary','3','2.20',69]]
lay=fig.add_subplot(gs[1,1]);table(lay,rows,['Layer','Role','Turns','Trace mm','Cu um'],[.12,.3,.12,.24,.15])
lay.set_title('Layer allocation: P/S spacing 0.20 mm; AUX one turn per layer')
fig.suptitle('36T Compact C — dimensioned design summary (all dimensions in mm)',fontsize=21,weight='bold')
fig.savefig(OUT/'Flyback_36T_C_dimensioned_plan.png',dpi=180)

fig2=plt.figure(figsize=(18,11),layout='constrained');g=fig2.add_gridspec(1,2)
stack=fig2.add_subplot(g[0,0]);z=3.245/2;zs=[]
for i,t in enumerate(cu):
    zs.append(z-t/2)
    color='#888' if i==0 else P if i in (1,2) else A if i in (3,4) else S
    rect(stack,0,z-t,3,t,facecolor=color)
    stack.text(-.2,z-t/2,'L{}  z={:+.4f}'.format(i+1,z-t/2),ha='right',va='center',color=color)
    stack.text(3.2,z-t/2,'Cu {:.0f} um'.format(t*1000),va='center')
    z-=t
    if i<7:
        d=diel[i];rect(stack,0,z-d,3,d,facecolor='#e8e3c9',ec='white')
        stack.text(1.5,z-d/2,'FR4 {:.3f}'.format(d),ha='center',va='center');z-=d
dim(stack,(5,-1.6225),(5,1.6225),'PCB 3.245',True)
dim(stack,(0,1.6225),(0,2.6225),'1.000 to upper yoke',True)
dim(stack,(0,-2.6225),(0,-1.6225),'1.000 to lower yoke',True)
dim(stack,(6,-.6595),(6,.6735),'Nearest P-S copper faces: 1.333',True)
stack.set(xlim=(-4,8),ylim=(-3,3),yticks=[],xticks=[],title='Eight-layer stack / L1 at +Z / not to XY scale')
stack.axis('off');stack.set_title('PCB stack: Z positions and dielectric distances',fontsize=16)
turns=[]
for i in range(18):
    r=14.1+i*.4;turns.append(['P',i+1,'0.20','{:.2f}'.format(2*r),'{:.2f}'.format(2*r-.2),'{:.2f}'.format(2*r+.2)])
for i in range(3):
    r=15.1+i*2.4;turns.append(['S',i+1,'2.20','{:.2f}'.format(2*r),'{:.2f}'.format(2*r-2.2),'{:.2f}'.format(2*r+2.2)])
turns.append(['AUX',1,'0.20','35.00','34.80','35.20'])
ta=fig2.add_subplot(g[0,1]);table(ta,turns,['Coil','Turn*','Width','CL side','Inner side','Outer side'],fontsize=10)
ta.set_title('Each turn: square envelope dimensions\n*Numbered from inside out; same for every layer of that coil.',fontsize=14)
fig2.suptitle('36T Compact C — stack and every-turn dimensions',fontsize=21,weight='bold')
fig2.savefig(OUT/'Flyback_36T_C_stack_and_turns.png',dpi=180)
with PdfPages(OUT/'Flyback_36T_C_dimensioned_summary.pdf') as pdf:
    pdf.savefig(fig);pdf.savefig(fig2)
assert abs(sum(cu)+sum(diel)-3.245)<1e-9
assert abs(18*.2+17*.2-7)<1e-9 and abs(3*2.2+2*.2-7)<1e-9
assert abs((14+21)/2-17.5)<1e-9
print('Saved two dimensioned PNGs and a two-page PDF in '+str(OUT))

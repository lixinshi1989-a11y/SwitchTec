"""Plot the actual CAD trace coordinates, not conceptual winding envelopes."""
import pathlib
import runpy
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle,Circle

root=pathlib.Path(__file__).resolve().parent
env=runpy.run_path(str(root/'check_scheme_b_routing.py'))['env']
fig,axes=plt.subplots(2,3,figsize=(17,12),layout='constrained')
colors={'Primary':'#d42520','Secondary':'#185ace','AUX':'#13813e'}
for ax,layer in zip(axes.flat,[1,2,3,6,7,8]):
    z=env['layer_z'][layer-1]
    ax.add_patch(Rectangle((-34,-31.5),68,63,fill=False,linestyle=':',edgecolor='gray'))
    for cx in [env['LEFT_CX'],env['RIGHT_CX']]:
        ax.add_patch(Rectangle((cx-8,-8),16,16,facecolor='#bbbbbb',edgecolor='black'))
    for t in env['trace_paths']:
        pts=t['points']; external=pts[0][2]<-env['BOARD_T']/2
        if abs(pts[0][2]-z)>1e-7 and not (external and layer==8):
            continue
        col=colors[t['name'].split('_')[0]]
        ax.plot([p[0] for p in pts],[p[1] for p in pts],color=col,
                lw=1.7 if t['width_mm']>=1 else .75,ls='--' if external else '-')
    for v in env['via_records']:
        if v['first_layer']<=layer<=v['last_layer']:
            ax.plot(v['x'],v['y'],'o',ms=3,color=colors[v['name'].split('_')[0]])
    ax.set(xlim=(-36,36),ylim=(-34,34),xlabel='X (mm)',ylabel='Y (mm)')
    ax.set_aspect('equal'); ax.grid(alpha=.18)
    labels={1:'Primary IN/OUT below',2:'Left outside-in / right inside-out',
            3:'Direct bridge to right outer-left corner',6:'S 4T + AUX 2T',7:'S 4T + AUX 1T',
            8:'AUX below / S above; dashed = leads below PCB'}
    ax.set_title('L{}: {}'.format(layer,labels[layer]),fontsize=11)
fig.suptitle('48:4:3 Scheme B - Routing V3\nRed: primary | Blue: secondary | Green: AUX | Dots: vias',fontsize=16)
out=root/'output'/'48_4_3'/'Flyback_48_4_3_Scheme_B_RoutingV3_layers.png'
fig.savefig(str(out),dpi=180)
print(out)

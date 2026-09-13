"""Audit routed copper boxes, adjacent vias and 1 mm paired terminal spacing."""
from pathlib import Path
import sys
import math
import json
import build_llc_7x14_grouped_terminals as builder
builder.make_geometry_builder()
sys.argv = [__file__, str(builder.BUILDER)]
source = Path(__file__).with_name('check_llc_routing.py').read_text()
start = source.index('    # S1_L2/S2_L3')
end = source.index('errors=[]',start)
source = source[:start]+"    return name.split('_')[0]\n"+source[end:]
# General checker excludes comments before primary_points, so these constants
# are evaluated naturally within the secondary routing block.
exec(compile(source,'check_llc_routing.py','exec'))
audit = {'turns_per_secondary':4,'terminals':[], 'aedt_solved':False}
for layer,winding in env['SECONDARY_LAYERS'].items():
    x = env['sec_port_x'][layer]
    start_y = env['secondary_points'][layer][0][1]
    return_y = env['sec_return_y'][layer]
    gap = abs(start_y-return_y)-env['S_WIDTH']
    assert abs(gap-1.0)<1e-9
    audit['terminals'].append(dict(winding=winding,spiral_layer=layer,
        return_layer=env['sec_surface'][layer],x_mm=round(x,6),
        start_y_mm=start_y,return_y_mm=return_y,xy_copper_gap_mm=gap))
for layer,pair in [(2,('S1','S2')),(7,('S3','S4'))]:
    lo,hi = zs[layer-1]-env['CU'][layer-1]/2,zs[layer-1]+env['CU'][layer-1]/2
    groups = [[(a,b) for n,a,b in boxes if net(n)==w and min(b[2],hi)-max(a[2],lo)>1e-8] for w in pair]
    gap = min(math.hypot(max(c[0]-b[0],a[0]-d[0],0),max(c[1]-b[1],a[1]-d[1],0))
              for a,b in groups[0] for c,d in groups[1])
    assert gap>=4-1e-8,(layer,gap)
    audit['L%d_different_secondary_gap_mm'%layer]=round(gap,6)
    print('L%d different-secondary copper gap: %.6f mm'%(layer,gap))
print('PASS: four paired terminal XY edge gaps are exactly 1 mm.')
(builder.ROOT/'output'/(builder.STEM+'_audit.json')).write_text(json.dumps(audit,indent=2))

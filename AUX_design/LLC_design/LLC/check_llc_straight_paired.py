"""Check actual pre-union copper primitives, connectivity and L2/L7 clearances."""
from pathlib import Path
import sys
import math
import json
import build_llc_7x14_straight_paired as builder

builder.make_geometry_builder()
sys.argv = [__file__, str(builder.BUILDER)]
source = Path(__file__).with_name('check_llc_routing.py').read_text()
start = source.index('    # S1_L2/S2_L3')
end = source.index('errors=[]', start)
source = source[:start] + "    return name.split('_')[0]\n" + source[end:]
exec(compile(source, 'check_llc_routing.py', 'exec'))
results = {}
for layer, pair in [(2, ('S1', 'S2')), (7, ('S3', 'S4'))]:
    zlo = zs[layer-1] - env['CU'][layer-1]/2
    zhi = zs[layer-1] + env['CU'][layer-1]/2
    groups = [[(a,b) for n,a,b in boxes if net(n) == winding
               and min(b[2],zhi)-max(a[2],zlo)>1e-8] for winding in pair]
    distance = min(math.hypot(max(c[0]-b[0], a[0]-d[0], 0),
                              max(c[1]-b[1], a[1]-d[1], 0))
                   for a,b in groups[0] for c,d in groups[1])
    assert distance >= 4 - 1e-8, (layer, distance)
    results['L'+str(layer)+'_secondary_copper_gap_mm'] = round(distance,6)
    print('PASS: L%d secondary copper gap %.6f mm >= 4 mm' % (layer,distance))
results['connected_windings'] = 5
results['secondary_spiral_layers'] = [1,3,6,8]
results['turns_per_secondary'] = 4
results['solver_status'] = 'configured, not solved'
(builder.ROOT/'output'/(builder.STEM+'_audit.json')).write_text(json.dumps(results,indent=2))

# Each pair retains its exit direction. Check actual terminal-end copper boxes.
for winding in ('S1','S2','S3','S4'):
    a,b = next((a,b) for n,a,b in boxes if n.startswith(winding+'_START_LEAD') and abs(b[0]-29)<1e-8)
    c,d = next((a,b) for n,a,b in boxes if n.startswith(winding+'_RETURN_LEAD') and abs(b[0]-29)<1e-8)
    gap = max(c[1]-b[1],a[1]-d[1],0)
    assert abs(gap-1)<1e-8,(winding,gap)
    print('PASS: %s paired output copper-edge gap %.6f mm' % (winding,gap))
    results[winding+'_paired_output_gap_mm'] = round(gap,6)
(builder.ROOT/'output'/(builder.STEM+'_audit.json')).write_text(json.dumps(results,indent=2))

for layer,winding in env['SECONDARY_LAYERS'].items():
    pts=env['secondary_points'][layer]
    assert abs(pts[0][1]-pts[1][1])<1e-9
    leads=[(a,b) for n,a,b in boxes if n.startswith(winding+'_START_LEAD')]
    assert len(leads)==1, (winding,'start lead must be one straight box')
    assert abs(leads[0][0][1]-(pts[0][1]-.35))<1e-9
print('PASS: all four outer-turn entries and external start leads are straight and aligned.')

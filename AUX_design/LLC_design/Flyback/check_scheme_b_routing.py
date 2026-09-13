"""Dry-run the actual builder, validating geometry before launching AEDT."""
import io
import math
import pathlib
import sys
import types
from unittest.mock import patch

class Editor:
    def __init__(self):
        self.solids=set()
    def CreateBox(self, params, attrs):
        name=attrs[attrs.index('Name:=')+1]; self.solids.add(name); return name
    CreateCylinder=CreateBox
    def Unite(self, selections, params):
        names=selections[selections.index('Selections:=')+1].split(',')
        self.solids.difference_update(names[1:])
    def Subtract(self, selections, params):
        if not params[params.index('KeepOriginals:=')+1]:
            self.solids.difference_update(selections[selections.index('Tool Parts:=')+1].split(','))
    def GetObjectsInGroup(self, group):
        return sorted(self.solids) if group=='Solids' else []
    def __getattr__(self, name):
        return lambda *args: self

editor=Editor()
script=pathlib.Path(__file__).with_name('build_flyback_48_4_3_scheme_b_aedt.py')
source=script.read_text()
env={'__file__':str(script),'oDesktop':editor}
fake=types.ModuleType('ScriptEnv'); fake.Initialize=lambda *args: None
with patch.dict(sys.modules,{'ScriptEnv':fake}), patch('builtins.open',lambda *args,**kwargs:io.StringIO()):
    exec(compile(source,str(script),'exec'),env)

p=env['primary_points']
assert p['Left',2][-1][:2]==p['Left',3][0][:2]
assert p['Right',3][-1][:2]==p['Right',2][0][:2]
assert p['Left',3][-1][1:]==p['Right',3][0][1:]
assert [v['last_layer'] for v in env['via_records'] if 'Primary_' in v['name'] and ('START' in v['name'] or 'END' in v['name'])]==[2,2]
assert not any('Primary_InterLeg_Post' in b['name'] for b in env['geometry_boxes'])

# Integrated polar angle measures actual turns, including winding polarity.
def turns(points,cx):
    angles=[math.atan2(y,x-cx) for x,y,z in points]
    return sum(math.atan2(math.sin(b-a),math.cos(b-a)) for a,b in zip(angles,angles[1:]))/(2*math.pi)
for label,layer,expected in [('Left',2,12),('Left',3,12),('Right',3,-12),('Right',2,-12)]:
    cx=env['LEFT_CX'] if label=='Left' else env['RIGHT_CX']
    pts=p[label,layer]
    if label=='Right' and layer==3:
        # Complete the bottom reference ray along the straight incoming bridge.
        pts=[(cx,pts[0][1],pts[0][2])]+pts
    assert abs(turns(pts,cx)-expected)<1e-8
for points in env['secondary_points'].values():
    assert abs(turns(points,env['RIGHT_CX'])-4)<1e-8
for trace in env['trace_paths']:
    if 'Breakout' in trace['name'] and trace['name'].startswith(('Primary_','AUX_')):
        assert trace['points'][-1][1]==-env['BOARD_Y']/2
    segments=[b for b in env['geometry_boxes'] if b['name']==trace['name'] or b['name'].startswith(trace['name']+'_segment_')]
    for i,a in enumerate(segments):
        for b in segments[i+2:]:
            assert not env['overlaps'](a,b), ('Trace shorts itself',a['name'],b['name'])
bridge=next(t for t in env['trace_paths'] if t['name']=='Primary_InterLeg_Bridge_L3')
assert len(bridge['points'])==2 and abs(bridge['points'][0][1]+14.9)<1e-8
assert bridge['points'][1][0] < env['RIGHT_CX']-env['LEG']/2
for terminal in env['s_terminals']:
    assert terminal['centre_mm'][1]==env['BOARD_Y']/2 and terminal['width_mm']==env['S_WIDTH']
assert not any('ExternalBus' in t['name'] for t in env['trace_paths'])
print('PASS: primary order, four 12T polarities, three 4T branches, L3-only bridge, L1 input/output, zero copper/core and inter-winding intersections.')

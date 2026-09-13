"""Check generated pre-Unite copper boxes without launching AEDT."""
import ast
from pathlib import Path
import math
import sys

source_path = (Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else
               Path(__file__).with_name('build_llc_transformer_aedt.py'))
source = source_path.read_text()
env = {}
exec(source[source.index('BOARD_X ='):source.index('def mm(')], env)
boxes = []
def box(name, origin, size, material, color):
    if material == 'copper':
        boxes.append((name, tuple(origin), tuple(a+b for a,b in zip(origin,size))))
env.update(create_box=box, unite=lambda names: None)
tree = ast.parse(source)
for node in tree.body:
    if isinstance(node, ast.FunctionDef) and node.name in ('create_trace','rectangular_spiral'):
        exec(compile(ast.Module(body=[node], type_ignores=[]), '<builder>', 'exec'), env)
z = -env['BOARD_T']/2
zs=[]
for i,t in enumerate(env['CU']):
    zs.append(z+t/2)
    z += t+(env['DIEL'][i] if i<7 else 0)
env['layer_z']=zs
def via(name,x,y,first,last,diameter,color):
    low=zs[first-1]-env['CU'][first-1]/2
    high=zs[last-1]+env['CU'][last-1]/2
    box(name,[x-diameter/2,y-diameter/2,low],[diameter,diameter,high-low],'copper',color)
env['create_via']=via
exec(source[source.index('primary_points = {}'):source.index('# Upper and lower U cores.')], env)
def net(name):
    if name.startswith('P'): return 'P'
    # S1_L2/S2_L3/S3_L6/S4_L7 spiral names vs S<layer> routing names
    if '_4T' in name: return name.split('_')[0]
    return {2:'S1',3:'S2',6:'S3',7:'S4'}[int(name.split('_')[0][1:])]
errors=[]
for i,(n,a,b) in enumerate(boxes):
    for m,c,d in boxes[i+1:]:
        if all(min(b[k],d[k])-max(a[k],c[k])>1e-8 for k in range(3)):
            if net(n)!=net(m): errors.append(('different winding short',n,m))
            else:
                base,idx=n.rsplit('_segment_',1) if '_segment_' in n else (n,'0')
                other,jdx=m.rsplit('_segment_',1) if '_segment_' in m else (m,'0')
                if base==other and abs(int(idx)-int(jdx))>1:
                    errors.append(('nonadjacent trace segments intersect',n,m))
        if net(n)!=net(m) and min(b[2],d[2])-max(a[2],c[2])>1e-8:
            dx=max(c[0]-b[0],a[0]-d[0],0)
            dy=max(c[1]-b[1],a[1]-d[1],0)
            if math.hypot(dx,dy)<0.2-1e-8:
                errors.append(('cross-net clearance below 0.2 mm',n,m))
    # All winding copper must clear the vertical legs by 2 mm in XY.
    leg_half_x=env['LEG']/2
    leg_half_y=env.get('CORE_DEPTH',env['LEG'])/2
    for cx in (-env['LEG_PITCH']/2,env['LEG_PITCH']/2):
        dx=max(cx-leg_half_x-b[0],a[0]-(cx+leg_half_x),0)
        dy=max(-leg_half_y-b[1],a[1]-leg_half_y,0)
        if math.hypot(dx,dy)<2-1e-8:
            errors.append(('core leg clearance below 2 mm',n,math.hypot(dx,dy)))
assert not errors, errors
for winding in ('P','S1','S2','S3','S4'):
    items=[item for item in boxes if net(item[0])==winding]
    reached={0}
    while True:
        new=set(reached)
        for i,(_,a,b) in enumerate(items):
            for j in reached:
                _,c,d=items[j]
                if all(min(b[k],d[k])-max(a[k],c[k])>=-1e-8 for k in range(3)):
                    new.add(i)
        if new==reached: break
        reached=new
    assert len(reached)==len(items), ('disconnected winding',winding)
print('SOURCE: %s'%source_path)
print('PASS: %d copper boxes checked; no cross-net volume intersections; core-leg clearance >=2 mm.'%len(boxes))
print('PASS: all five windings connected; cross-net clearance >=0.2 mm.')
return_lanes=sorted(set(env['sec_return_y'].values()))
return_pitch=min(b-a for a,b in zip(return_lanes[:-1],return_lanes[1:]))
print('Surface return spacing: %.2f mm pitch - %.2f mm copper = %.2f mm.'%
      (return_pitch,env['S_WIDTH'],return_pitch-env['S_WIDTH']))

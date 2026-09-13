"""Sample native arc centre lines to audit adjacent-turn edge clearance. Requires NumPy."""
import importlib.util
from pathlib import Path
import numpy as np
spec=importlib.util.spec_from_file_location('pot',str(Path(__file__).with_name('build_flyback_d20_uniform_primary.py')))
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
for turns,w in [(18,m.PWIDTH),(3,m.SWIDTH)]:
    points=[]
    for kind,ps in m.spiral(turns,w,0):
        a=np.array(ps[0][:2]); b=np.array(ps[-1][:2])
        if kind=='Arc':
            mid=np.array(ps[1][:2]); centre=np.linalg.solve(2*np.array([mid-a,b-a]),np.array([mid@mid-a@a,b@b-a@a])); r=np.linalg.norm(a-centre); t=np.arctan2(*(a-centre)[::-1]); t2=np.arctan2(*(b-centre)[::-1]); dt=(t2-t)%(2*np.pi)
            angles=np.linspace(t,t+dt,341)
            xy=centre+np.column_stack((r*np.cos(angles),r*np.sin(angles)))
        else:
            xy=np.linspace(a,b,241)
        points.extend(xy[:-1])
    xy=np.array(points); distance=np.r_[0,np.cumsum(np.linalg.norm(np.diff(xy,axis=0),axis=1))]
    minimum=1e6; pair=None
    for i in range(0,len(xy),128):
        dd=np.linalg.norm(xy[i:i+128,None,:]-xy[None,:,:],axis=2)
        dd[np.abs(distance[i:i+128,None]-distance[None,:])<15]=np.inf
        jj=np.unravel_index(dd.argmin(),dd.shape)
        if dd[jj]<minimum: minimum=float(dd[jj]); pair=[xy[i+jj[0]].tolist(),xy[jj[1]].tolist()]
    print(turns,w,'sampled centreline spacing',minimum,'edge spacing',minimum-w,'at',pair)

    assert minimum-w >= m.SPACE, (turns, minimum-w)

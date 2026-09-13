"""D20 square Pot, 43x43 mm, 36:3:2. Configured 100 kHz; no reports or solve.
Run with AEDT 2024 R2 -ng -RunScriptAndExit.

Series-secondary variant of build_flyback_d20_uniform_primary.py. The
secondary is one turn per layer instead of a 3-turn spiral per layer, and
the three layers are in SERIES instead of parallel. Every turn is the same
plain circle at the same radius, as wide as the whole 9 mm window, and each
layer is rotated so that its start lands exactly on the previous layer's
end, where a via joins them. Primary and AUX are untouched. Written to its
own project name; the UniformPrimary model and its build script are left
alone.
"""
import os
import math
import json

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, 'output', '36_3_2_pot', 'D20_Core43')
NAME = 'Flyback_36_3_2_SquarePot_D20_Core43_SeriesSecondary_100kHz'
CU = [.069,.064,.064,.064,.064,.064,.064,.069]
DIEL = [.346,.406,.393,.406,.406,.406,.360]
BOARD_T = sum(CU)+sum(DIEL)
R = 10.0
WINDOW = 13.0
RW = 23.0
RO = 21.5
WALL = RO-RW  # Square corner returns, not a continuous cylindrical wall.
CHAMFER = 0.0
YOKE = 4.0
GAP = 0.0935123206677404
HALF_H = (13.245-GAP)/2
STEM = HALF_H-YOKE
SLOT_HALF = 10.0
AWIDTH = .2
SPACE = .2
# Routing allowances at the native circular transition arcs (the
# turn-to-turn "jump" arc built by spiral()). PWIDTH/SWIDTH are derived
# FROM these so the 9 mm breadth target and the arc geometry can never
# drift out of sync again. The previous 3 um / 25 um allowances left only
# ~0.6 um / ~2 um of real clearance above the 0.2 mm rule (confirmed by
# check_flyback_d20_spacing.py); native CAD kernel tolerance and the
# corner-join sweep of the transition arc consumed that margin entirely,
# fusing adjacent primary turns near x=0,y=-12.3mm into a hard short
# (solved Lm ~100 uH instead of the 2.3 mH design target). 30/60 um give
# a real, verified margin (~28/~37 um) with a negligible trace-width cost.
TRANSITION_ALLOWANCE = .03
SECONDARY_TRANSITION_ALLOWANCE = .06
# Uniform pitch: align the L3 inner endpoint with L2 by a -24 degree
# rotation after mirroring; no closing arc crosses the transition sector.
LAST_GAP_EXTRA = 0.0
LAST_GAP_SUBDIV = 1
PWIDTH = (9.0-17*(SPACE+TRANSITION_ALLOWANCE)-LAST_GAP_EXTRA)/18
P_BREADTH = 18*PWIDTH+17*(SPACE+TRANSITION_ALLOWANCE)+LAST_GAP_EXTRA
# Secondary: ONE turn per layer, and the layers are stacked rather than
# concentric, so every turn can be the same plain circle filling the whole
# 9 mm window -- no radial traverse, no concentric neighbour to clear.
S_BREADTH = 9.0
SWIDTH = 9.0
S_RADIUS = R+2+S_BREADTH/2
# 336 deg of copper per layer (the same 24 deg terminal sector the primary
# uses) x 3 layers in series = 2.80 effective turns, against 2.72 for the
# previous 3T-per-layer parallel stack, so the 36:3 ratio is preserved.
SDELTA = 12
SSWEEP = 360-2*SDELTA
SSUBDIV = 4
# Via stitching at each layer joint, the way a board would actually be built:
# the two layers are each carried S_PAD degrees PAST the joint so they overlap
# there, and a grid of barrels is dropped in that overlap. Butting the two
# arcs end to end and relying on one big barrel to bridge them would leave
# each layer touching only half the barrel wall.
S_PAD = 7.0
S_VIA_D = 0.8
S_VIA_PITCH = 1.6
S_VIA_R0 = R+2+1.0
S_VIA_R1 = R+2+S_BREADTH-1.0
# A post at the turn's own radius would cut straight down through L7/L8, so
# the L6 terminal escapes radially past every secondary layer before dropping.
S_LEAD = 4.5
S_ESCAPE = 22.3
AR = R+2+P_BREADTH/2
BUS_Z = -BOARD_T/2-.50-.069/2
Z=[]
z=BOARD_T/2
for i,t in enumerate(CU):
    Z.append(z-t/2)
    z-=t
    if i<7: z-=DIEL[i]
assert abs(P_BREADTH-9)<1e-9
assert abs(S_BREADTH-9)<1e-9
assert S_BREADTH<=P_BREADTH
assert abs(S_RADIUS-SWIDTH/2-(R+2))<1e-9 and abs(S_RADIUS+SWIDTH/2-(R+2+S_BREADTH))<1e-9
assert 2*S_PAD<2*SDELTA               # overlap pads must not close a ring's own gap
assert math.degrees((S_VIA_PITCH/2+S_VIA_D/2)/S_VIA_R0)<S_PAD  # array fits in the overlap
assert S_VIA_R0-S_VIA_D/2>=R+2 and S_VIA_R1+S_VIA_D/2<=R+2+S_BREADTH
assert S_ESCAPE-1.0>R+2+S_BREADTH+.2  # post clears the outermost secondary copper
assert 2*RO<62

def mm(v): return '%.9fmm'%v
def polar(r,a,z): return (r*math.cos(a),r*math.sin(a),z)
def attrs(name,mat,color):
    return ['NAME:Attributes','Name:=',name,'MaterialValue:=','"'+mat+'"',
            'SolveInside:=',True,'Color:=',color,'PartCoordinateSystem:=','Global']
def box(name,xyz,dim,mat='vacuum',color='(180 180 180)'):
    e.CreateBox(['NAME:BoxParameters','XPosition:=',mm(xyz[0]),'YPosition:=',mm(xyz[1]),
        'ZPosition:=',mm(xyz[2]),'XSize:=',mm(dim[0]),'YSize:=',mm(dim[1]),'ZSize:=',mm(dim[2])],attrs(name,mat,color))
def cylinder(name,x,y,z,r,h,mat='vacuum',color='(180 180 180)'):
    e.CreateCylinder(['NAME:CylinderParameters','XCenter:=',mm(x),'YCenter:=',mm(y),
        'ZCenter:=',mm(z),'Radius:=',mm(r),'Height:=',mm(h),'WhichAxis:=','Z','NumSides:=','0'],attrs(name,mat,color))
def subtract(blank,parts,keep=False):
    e.Subtract(['NAME:Selections','Blank Parts:=',blank,'Tool Parts:=',','.join(parts)],
        ['NAME:SubtractParameters','KeepOriginals:=',keep])
def unite(parts):
    e.Unite(['NAME:Selections','Selections:=',','.join(parts)],['NAME:UniteParameters','KeepOriginals:=',False])
def wire(name,segments,width,thick,color):
    pts=['NAME:PolylinePoints']; segs=['NAME:PolylineSegments']; index=0
    for kind,points in segments:
        if index==0:
            p=points[0]; pts.append(['NAME:PLPoint','X:=',mm(p[0]),'Y:=',mm(p[1]),'Z:=',mm(p[2])])
        for p in points[1:]:
            pts.append(['NAME:PLPoint','X:=',mm(p[0]),'Y:=',mm(p[1]),'Z:=',mm(p[2])])
        segs.append(['NAME:PLSegment','SegmentType:=',kind,'StartIndex:=',index,'NoOfPoints:=',len(points)])
        index+=len(points)-1
    e.CreatePolyline(['NAME:PolylineParameters','IsPolylineCovered:=',True,'IsPolylineClosed:=',False,
        pts,segs,['NAME:PolylineXSection','XSectionType:=','Rectangle','XSectionOrient:=','Auto',
        'XSectionWidth:=',mm(width),'XSectionTopWidth:=',mm(width),'XSectionHeight:=',mm(thick),
        'XSectionNumSegments:=','0','XSectionBendType:=','Corner']],attrs(name,'copper',color))
def lines(name,points,width,thick,color):
    wire(name,[('Line',[a,b]) for a,b in zip(points[:-1],points[1:]) if a!=b],width,thick,color)
def transform(segments,mirror=False,reverse=False,top=False):
    result=[]
    for kind,points in segments:
        result.append((kind,[((-x if mirror else x),(-y if top else y),z) for x,y,z in points]))
    if reverse: result=[(kind,list(reversed(p))) for kind,p in reversed(result)]
    return result
def spiral(n,width,z,inner=None,last_gap_extra=0.0,last_gap_subdiv=1):
    # P/AUX use 336-degree arcs; wide S uses 260-degree arcs and a wider
    # transition sector so the copper keeps its >=0.2 mm edge clearance.
    # The open final sector contains the inner terminal; no closed copper loop.
    # last_gap_extra (primary only) widens just the turn(n-2)->turn(n-1) gap,
    # to clear the innermost turn's separate closing arc to the via -- see
    # LAST_GAP_EXTRA. All other turns keep the normal `pitch` spacing.
    # A single 3-point arc across the widened gap doubles the radial jump
    # per degree versus every other transition, which sharpens the miter
    # join enough to break volume meshing ("Unexpected error encountered
    # in the meshing process") even though the geometry itself validates.
    # last_gap_subdiv chains several shorter 3-point arcs across the same
    # 24 deg sector instead, keeping each individual joint's bend angle
    # close to the (known-good) normal-transition case.
    inner=R+2+width/2 if inner is None else inner
    pitch=width+SPACE+(SECONDARY_TRANSITION_ALLOWANCE if width==SWIDTH else TRANSITION_ALLOWANCE)
    delta=50 if width==SWIDTH else 12
    a0=math.radians(-90+delta); a1=math.radians(270-delta)
    radii=[inner+(n-1-turn)*pitch+(last_gap_extra if turn<n-1 else 0.0) for turn in range(n)]
    seg=[]
    for turn in range(n):
        r=radii[turn]
        angles=[a0,(a0+a1)/2,a1]
        for a,b in zip(angles[:-1],angles[1:]):
            seg.append(('Arc',[polar(r,a,z),polar(r,(a+b)/2,z),polar(r,b,z)]))
        if turn<n-1:
            r_next=radii[turn+1]
            subdiv=last_gap_subdiv if turn==n-2 else 1
            a_end=a0+2*math.pi
            rs=[r+(r_next-r)*k/subdiv for k in range(subdiv+1)]
            angs=[a1+(a_end-a1)*k/subdiv for k in range(subdiv+1)]
            for k in range(subdiv):
                seg.append(('Arc',[polar(rs[k],angs[k],z),polar((rs[k]+rs[k+1])/2,(angs[k]+angs[k+1])/2,z),polar(rs[k+1],angs[k+1],z)]))
    return seg
def sweepTurn(width,z,r0,r1,a_start_deg,a_end_deg,subdiv=SSUBDIV):
    # One turn from a_start to a_end, walking radially from r0 to r1, built as
    # a chain of short 3-point arcs. Chaining several shallow arcs rather than
    # one steep 3-point arc keeps every miter join close to the shape of a
    # plain constant-radius arc, which is what the volume mesher tolerates.
    a0=math.radians(a_start_deg); a1=math.radians(a_end_deg)
    rs=[r0+(r1-r0)*k/subdiv for k in range(subdiv+1)]
    angs=[a0+(a1-a0)*k/subdiv for k in range(subdiv+1)]
    return [('Arc',[polar(rs[k],angs[k],z),polar((rs[k]+rs[k+1])/2,(angs[k]+angs[k+1])/2,z),
        polar(rs[k+1],angs[k+1],z)]) for k in range(subdiv)]
def viaArray(prefix,point,first,last,color):
    # Rows across the ring width, two columns straddling the joint. Every
    # barrel sits inside the S_PAD overlap, so it lands in copper on BOTH
    # layers, and well clear of either ring's own terminal gap.
    names=[]; base=math.atan2(point[1],point[0])
    rows=int(round((S_VIA_R1-S_VIA_R0)/S_VIA_PITCH))+1
    for i in range(rows):
        r=S_VIA_R0+(S_VIA_R1-S_VIA_R0)*i/(rows-1)
        for j,off in enumerate((-S_VIA_PITCH/2,S_VIA_PITCH/2)):
            name='%s_R%dC%d'%(prefix,i+1,j+1)
            via(name,polar(r,base+off/r,0),first,last,S_VIA_D,color)
            names.append(name)
    return names
def via(name,point,first,last,diameter,color):
    bottom=min(Z[first-1]-CU[first-1]/2,Z[last-1]-CU[last-1]/2)
    top=max(Z[first-1]+CU[first-1]/2,Z[last-1]+CU[last-1]/2)
    cylinder(name,point[0],point[1],bottom,diameter/2,top-bottom,'copper',color)
def chamfered_box(name,z,h):
    box(name,[-RO,-RO,z],[2*RO,2*RO,h],'TPG33')


def build():
    global e
    import ScriptEnv
    ScriptEnv.Initialize('Ansoft.ElectronicsDesktop')
    if not os.path.isdir(OUT): os.makedirs(OUT)
    p=oDesktop.NewProject()
    p.InsertDesign('Maxwell 3D',NAME,'EddyCurrent','')
    d=p.SetActiveDesign(NAME); e=d.SetActiveEditor('3D Modeler')
    e.SetModelUnits(['NAME:Units Parameter','Units:=','mm','Rescale:=',False])
    p.GetDefinitionManager().AddMaterial(['NAME:TPG33','CoordinateSystemType:=','Cartesian','BulkOrSurfaceType:=',1,
        ['NAME:PhysicsTypes','set:=',['Electromagnetic']],'permeability:=','3300','conductivity:=','0'])
    cores=[]
    for tag,sgn in [('Upper',1),('Lower',-1)]:
        bottom=GAP/2 if sgn==1 else -GAP/2-HALF_H
        stem_z=GAP/2 if sgn==1 else -GAP/2-STEM
        name='Core_'+tag
        chamfered_box(name,bottom,HALF_H)
        cylinder(name+'_'+'WindowOuter',0,0,stem_z-.00001,RW,STEM+.00002)
        cylinder(name+'_'+'WindowInner',0,0,stem_z-.001,R,STEM+.002)
        subtract(name+'_'+'WindowOuter',[name+'_'+'WindowInner'])
        subtract(name,[name+'_'+'WindowOuter'])
        cores.append(name)
    # Retain original 82 x 62 mm PCB; adapt only ferrite cutouts to the pot wall.
    z=BOARD_T/2
    for i,t in enumerate(CU):
        z-=t
        if i==7: break
        h=DIEL[i]; name='PCB_Diel_L%d_L%d'%(i+1,i+2)
        box(name,[-41,-31,z-h],[82,62,h],'FR4_epoxy','(100 145 85)')
        cylinder(name+'_PCB_CentreCut',0,0,z-h-.01,R+.3,h+.02)
        subtract(name,[name+'_PCB_CentreCut'])
        box(name+'_PCB_WallCut',[-RO-.3,-RO-.3,z-h-.01],[2*(RO+.3),2*(RO+.3),h+.02])
        cylinder(name+'_PCB_WindowKeep',0,0,z-h-.02,RW-.3,h+.04)
        subtract(name+'_PCB_WallCut',[name+'_PCB_WindowKeep'])
        subtract(name,[name+'_PCB_WallCut']); z-=h
    red='(220 50 30)'; green='(0 150 65)'; blue='(25 90 220)'
    meta=[]; terminals=[]
    # Direct inner-end via. Both layers retain series-aiding circulation.
    pEnds=[]; inner_point=None
    for layer in [2,3]:
        seg=spiral(18,PWIDTH,Z[layer-1])
        if layer==3:
            seg=transform(seg,mirror=True,reverse=True)
            angle=math.radians(-24); ca=math.cos(angle); sa=math.sin(angle)
            seg=[(kind,[(x*ca-y*sa,x*sa+y*ca,z) for x,y,z in pts]) for kind,pts in seg]
            outer=seg[-1][1][-1]
            # Clear the outer turn before moving to the bottom opening;
            # a vertical lead at x=-12 mm would cut the corner return core.
            exit_r=math.hypot(outer[0],outer[1])+.6
            z=Z[layer-1]
            radial=polar(exit_r,math.radians(-126),z)
            exit_point=polar(exit_r,math.radians(-106),z)
            seg.append(('Line',[outer,radial]))
            seg.append(('Arc',[radial,polar(exit_r,math.radians(-116),z),exit_point]))
            term=(exit_point[0],-31,z)
            seg.append(('Line',[exit_point,term]))
            assert abs(seg[0][1][0][0]-inner_point[0])<1e-9
            assert abs(seg[0][1][0][1]-inner_point[1])<1e-9
        else:
            inner_point=seg[-1][1][-1]
            outer=seg[0][1][0];term=(outer[0],-31,Z[layer-1])
            seg.insert(0,('Line',[term,outer]))
        name='Primary_L%d_18T'%layer
        wire(name,seg,PWIDTH,CU[layer-1],red)
        pEnds.append(term)
        meta.append(dict(layer=layer,winding='Primary',turns=18,width_mm=PWIDTH))
    via('Primary_InnerVia',inner_point,2,3,.2,red)
    unite(['Primary_L2_18T','Primary_L3_18T','Primary_InnerVia'])
    terminals.append(('Primary_L2_18T','WindingP',pEnds))
    aParts=[]; aEnds=[]
    for layer in [4,5]:
        seg=spiral(1,AWIDTH,Z[layer-1],AR)
        seg.append(('Arc',[seg[-1][1][-1],polar(AR,math.radians(265),Z[layer-1]),(0,-AR,Z[layer-1])]))
        outer=seg[0][1][0]; access=(outer[0],-25,Z[layer-1])
        seg.insert(0,('Line',[access,outer]))
        if layer==5: seg=transform(seg,mirror=True,reverse=True); access=(-access[0],access[1],access[2])
        name='AUX_L%d_1T'%layer; wire(name,seg,AWIDTH,CU[layer-1],green); aParts.append(name)
        vn='AUX_AccessVia_L%d'%layer; via(vn,access,1,layer,.2,green); aParts.append(vn)
        tn='AUX_Lead_L1_%d'%layer; term=(access[0],-31,Z[0])
        lines(tn,[(access[0],access[1],Z[0]),term],AWIDTH,CU[0],green); aParts.append(tn); aEnds.append(term)
        meta.append(dict(layer=layer,winding='AUX',turns=1,width_mm=AWIDTH))
    via('AUX_SeriesVia',(0,-AR),4,5,.2,green); aParts.append('AUX_SeriesVia'); unite(aParts)
    terminals.append(('AUX_L4_1T','WindingA',aEnds))
    # One turn per layer, three layers in series. Each layer starts exactly
    # where the previous one ended (angle and radius), so all three circulate
    # the same way and their turns add instead of cancelling.
    sParts=[]; term_a=None; term_b=None
    # Joints sit at the nominal layer-change angles; each layer runs S_PAD
    # past its joint so the two layers overlap where the barrels land.
    j1=-90+SDELTA+SSWEEP
    j2=j1+SSWEEP
    for layer,a0,a1 in [(6,-90+SDELTA,j1+S_PAD),(7,j1-S_PAD,j2+S_PAD),(8,j2-S_PAD,j2+SSWEEP)]:
        seg=transform(sweepTurn(SWIDTH,Z[layer-1],S_RADIUS,S_RADIUS,a0,a1),top=True)
        name='Secondary_L%d_1T'%layer
        wire(name,seg,SWIDTH,CU[layer-1],blue); sParts.append(name)
        if layer==6:
            # Separate overlapping solid, not another polyline segment: a 90
            # degree miter on a 9 mm wide ring would throw a 4.5 mm spike.
            start=seg[0][1][0]; scale=S_ESCAPE/S_RADIUS
            term_a=(start[0]*scale,start[1]*scale,start[2])
            lines('Secondary_Lead_L6',[start,term_a],S_LEAD,CU[layer-1],blue)
            sParts.append('Secondary_Lead_L6')
        if layer==8: term_b=seg[-1][1][-1]
        meta.append(dict(layer=layer,winding='Secondary',turns=1,width_mm=SWIDTH))
    # Each array spans only its own layer pair, so it cannot reach the third.
    for prefix,jang,pair in [('Secondary_Via_L6_L7',j1,(6,7)),('Secondary_Via_L7_L8',j2,(7,8))]:
        jp=polar(S_RADIUS,math.radians(jang),0)
        sParts+=viaArray(prefix,(jp[0],-jp[1]),pair[0],pair[1],blue)
    sEnds=[]
    for index,(point,top_z,post_r) in enumerate([(term_a,Z[5]+CU[5]/2,1.0),(term_b,Z[7]+CU[7]/2,1.1)]):
        lane=4.55 if point[0]>0 else -4.55
        vn='Secondary_Post_%d'%index
        cylinder(vn,point[0],point[1],BUS_Z-.069/2,post_r,top_z-(BUS_Z-.069/2),'copper',blue); sParts.append(vn)
        by=max(point[1],R+2+6.5/2)
        bn='Secondary_Bus_%d'%index; term=(lane,31,BUS_Z)
        if math.hypot(point[0]-lane,point[1]-by)>.3:
            # One diagonal, not an L. The corner of an L-shaped neck reaches
            # past r=23 mm, where the pot window is no longer cut away, and
            # clips the square core's corner return.
            lines(bn+'_Neck',[(point[0],point[1],BUS_Z),(lane,by,BUS_Z)],S_LEAD,.069,blue)
            sParts.append(bn+'_Neck'); start_y=by
        else:
            start_y=point[1]-1.0   # run the bus under the post so they merge
        lines(bn,[(lane,start_y,BUS_Z),term],6.5,.069,blue); sParts.append(bn); sEnds.append(term)
    unite(sParts); terminals.append(('Secondary_L6_1T','WindingS',sEnds))
    copper=[t[0] for t in terminals]
    for i in range(1,8):
        name='PCB_Diel_L%d_L%d'%(i,i+1)
        subtract(name,copper,True)
        e.ChangeProperty(['NAME:AllTabs',['NAME:Geometry3DAttributeTab',['NAME:PropServers',name],
            ['NAME:ChangedProps',['NAME:Transparent','Value:=',.92]]]])
    for core in cores:
        e.ChangeProperty(['NAME:AllTabs',['NAME:Geometry3DAttributeTab',['NAME:PropServers',core],
            ['NAME:ChangedProps',['NAME:Transparent','Value:=',.8]]]])
    if list(e.GetObjectsInGroup('Unclassified')): raise RuntimeError('Unclassified CAD bodies')
    # Same 100 kHz, three-winding matrix configuration as the EE source.
    region=['NAME:RegionParameters']
    for direction,padding in zip(['+X','-X','+Y','-Y','+Z','-Z'],[20,20,0,0,20,20]):
        region += [direction+'PaddingType:=','Absolute Offset',direction+'Padding:=',mm(padding)]
    e.CreateRegion(region,['NAME:Attributes','Name:=','Region','Flags:=','Wireframe#','MaterialValue:=','"vacuum"','SolveInside:=',True])
    b=d.GetModule('BoundarySetup')
    for solid,winding,pair in terminals:
        cn=[]
        for index,(x,y,z) in enumerate(pair):
            face=e.GetFaceByPosition(['NAME:FaceParameters','BodyName:=',solid,'XPosition:=',mm(x),'YPosition:=',mm(y),'ZPosition:=',mm(z)])
            if int(face)<=0: raise RuntimeError('Missing terminal face: '+winding)
            name=winding+('_Positive' if index==0 else '_Negative')
            b.AssignCoilTerminal(['NAME:'+name,'Faces:=',[int(face)],'Conductor number:=','1','Point out of terminal:=',index==1]); cn.append(name)
        b.AssignWindingGroup(['NAME:'+winding,'Type:=','Current','IsSolid:=',True,'Current:=','1A' if winding=='WindingP' else '0A',
            'Resistance:=','0ohm','Inductance:=','0H','Voltage:=','0V','ParallelBranchesNum:=','1','Phase:=','0deg'])
        b.AddWindingTerminals(winding,cn)
    b.SetEddyEffect(['NAME:Eddy Effect Setting',['NAME:EddyEffectVector']+
        [['NAME:Data','Object Name:=',n,'Eddy Effect:=',True,'Displacement Current:=',False] for n in copper]])
    b.SetCoreLoss(cores,False)
    entries=['NAME:MatrixEntry']+[['NAME:MatrixEntry','Source:=',n] for n in ['WindingP','WindingS','WindingA']]
    d.GetModule('MaxwellParameterSetup').AssignMatrix(['NAME:Matrix1',entries])
    d.GetModule('AnalysisSetup').InsertSetup('EddyCurrent',['NAME:Leakage_100kHz','Enabled:=',True,'Frequency:=','100kHz',
        'MaximumPasses:=',10,'MinimumPasses:=',2,'MinimumConvergedPasses:=',2,'PercentRefinement:=',30,'PercentError:=',1,'SolveMatrixAtLast:=',True])
    native_checks={}
    for core,sgn in zip(cores,[1,-1]):
        face=e.GetFaceByPosition(['NAME:FaceParameters','BodyName:=',core,'XPosition:=','0mm',
            'YPosition:=','0mm','ZPosition:=',mm(sgn*GAP/2)])
        area=float(e.GetFaceArea(int(face)))
        assert abs(area-math.pi*R*R)<1e-5
        for sx,sy in [(1,1),(-1,1),(-1,-1),(1,-1)]:
            bodies=list(e.GetBodyNamesByPosition(['NAME:Parameters','XPosition:=',mm(sx*(RO-.1)),
                'YPosition:=',mm(sy*(RO-.1)),'ZPosition:=',mm(sgn*(GAP/2+HALF_H/2))]))
            assert core in bodies, 'Missing square corner return: '+core
        native_checks[core]=dict(centre_face_area_mm2=area,volume_mm3=float(e.GetObjectVolume(core)))
    e.FitAll(); p.SaveAs(os.path.join(OUT,NAME+'.aedt'),True)
    validation=d.ValidateDesign(os.path.join(OUT,NAME+'_validation.log'))
    e.ExportModelImageToFile(os.path.join(OUT,NAME+'.png'),1600,1100,[])
    with open(os.path.join(OUT,NAME+'_geometry.json'),'w') as f:
        json.dump(dict(centre_area_mm2=math.pi*R*R,centre_diameter_mm=2*R,window_radius_mm=RW,outer_side_mm=2*RO,
            outer_corner_chamfer_mm=CHAMFER,outer_wall_mm=WALL,core_height_mm=2*HALF_H+GAP,gap_mm=GAP,
            pcb_size_mm=[82,62,BOARD_T],layer_z_mm=Z,copper_mm=CU,dielectric_mm=DIEL,coils=meta,
            primary_breadth_mm=P_BREADTH,secondary_breadth_mm=S_BREADTH,aux_radial_centre_mm=AR,
            minimum_turn_spacing_mm=SPACE,transition_allowance_mm=dict(primary=TRANSITION_ALLOWANCE,secondary=SECONDARY_TRANSITION_ALLOWANCE),
            terminals=terminals,validation=validation,solved=False,native_core_checks=native_checks,
            secondary_topology='1 circular turn per layer, identical width and radius on L6/L7/L8, layers in series through a stitched via array at each joint',
            secondary_width_mm=SWIDTH,secondary_radius_mm=S_RADIUS,secondary_sweep_deg=SSWEEP,
            secondary_joint_overlap_deg=S_PAD,secondary_lead_width_mm=S_LEAD,
            secondary_via=dict(diameter_mm=S_VIA_D,pitch_mm=S_VIA_PITCH,
                radius_range_mm=[S_VIA_R0,S_VIA_R1],
                per_joint=2*(int(round((S_VIA_R1-S_VIA_R0)/S_VIA_PITCH))+1)),
            secondary_effective_turns=3*SSWEEP/360.0,secondary_escape_radius_mm=S_ESCAPE,
            note='D20 core43; target analytical Lm=2.3mH; configured EddyCurrent 100kHz with P/S/AUX matrix. No reports and no solve.'),f,indent=2)
    if validation!=1: raise RuntimeError('AEDT validation failed; inspect the validation log')

if __name__=='__main__': build()

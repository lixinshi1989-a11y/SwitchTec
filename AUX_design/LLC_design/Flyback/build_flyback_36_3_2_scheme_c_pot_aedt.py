"""36:3:2 C, equal-area circular centre post / circular PCB windings.

Run in AEDT 2024 R2: ansysedt.exe -ng -RunScriptAndExit <this file>
Core topology follows Design6_3_layer.aedt: circular post/window inside a
chamfered square pot envelope. Reference winding, casing and split cuts are
not copied: the original Flyback material, stack, turns and gap are retained.
Circular arcs are native CAD arcs, not closed shorted turn rings.
P L2/L3 series; AUX L4/L5 series; S L6/L7/L8 parallel. No solve is run.
"""
import os
import math
import json

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, 'output', '36_3_2_pot')
NAME = 'Flyback_36_3_2_Scheme_C_Pot_100kHz'
CU = [.069,.064,.064,.064,.064,.064,.064,.069]
DIEL = [.346,.406,.393,.406,.406,.406,.360]
BOARD_T = sum(CU)+sum(DIEL)
R = math.sqrt(24.0*24.0/math.pi)
WINDOW = 11.0
RW = R+WINDOW
# Same outer-wall sizing rule as the reference model (minimum 3 mm).
WALL = max(R*R/(2*RW),3.0)
RO = RW+WALL
CHAMFER = R*20.0/30.0
YOKE = 12.0
GAP = .189973179051959
HALF_H = YOKE+BOARD_T/2+1.0-GAP/2
STEM = HALF_H-YOKE
SLOT_HALF = 10.0
PWIDTH = .2
SWIDTH = 2.2
AWIDTH = .2
SPACE = .2
# Small routing allowances preserve >=0.2 mm copper clearance at the
# native circular transition arcs: P 3 um, S 25 um per radial pitch.
TRANSITION_ALLOWANCE = .003
SECONDARY_TRANSITION_ALLOWANCE = .025
P_BREADTH = 18*PWIDTH+17*(SPACE+TRANSITION_ALLOWANCE)
S_BREADTH = 3*SWIDTH+2*(SPACE+SECONDARY_TRANSITION_ALLOWANCE)
AR = R+2+P_BREADTH/2
BUS_Z = -BOARD_T/2-.50-.069/2
Z=[]
z=BOARD_T/2
for i,t in enumerate(CU):
    Z.append(z-t/2)
    z-=t
    if i<7: z-=DIEL[i]
assert abs(math.pi*R*R-576)<1e-9
assert S_BREADTH<=P_BREADTH
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
def spiral(n,width,z,inner=None):
    # P/AUX use 340-degree arcs; wide S uses 300-degree arcs and a wider
    # transition sector so the copper keeps its >=0.2 mm edge clearance.
    # The open final sector contains the inner terminal; no closed copper loop.
    inner=R+2+width/2 if inner is None else inner
    pitch=width+SPACE+(SECONDARY_TRANSITION_ALLOWANCE if width==SWIDTH else TRANSITION_ALLOWANCE)
    delta=30 if width==SWIDTH else 10
    a0=math.radians(-90+delta); a1=math.radians(270-delta)
    seg=[]
    for turn in range(n):
        r=inner+(n-1-turn)*pitch
        angles=[a0,(a0+a1)/2,a1]
        for a,b in zip(angles[:-1],angles[1:]):
            seg.append(('Arc',[polar(r,a,z),polar(r,(a+b)/2,z),polar(r,b,z)]))
        if turn<n-1:
            seg.append(('Arc',[seg[-1][1][-1],polar(r-pitch/2,math.radians(270),z),polar(r-pitch,a0,z)]))
    return seg
def via(name,point,first,last,diameter,color):
    bottom=min(Z[first-1]-CU[first-1]/2,Z[last-1]-CU[last-1]/2)
    top=max(Z[first-1]+CU[first-1]/2,Z[last-1]+CU[last-1]/2)
    cylinder(name,point[0],point[1],bottom,diameter/2,top-bottom,'copper',color)
def chamfered_box(name,z,h):
    box(name,[-RO,-RO,z],[2*RO,2*RO,h],'TPG33')
    # Native cylinders define the circular bore. Corner wedges are cut below.
    for i,(sx,sy) in enumerate([(1,1),(-1,1),(-1,-1),(1,-1)]):
        points=[(sx*RO,sy*(RO-CHAMFER),z-.01),(sx*(RO-CHAMFER),sy*RO,z-.01),
                (sx*(RO+1),sy*(RO+1),z-.01)]
        tool=name+'_corner%d'%i
        pp=['NAME:PolylinePoints']
        for p in points+[points[0]]: pp.append(['NAME:PLPoint','X:=',mm(p[0]),'Y:=',mm(p[1]),'Z:=',mm(p[2])])
        ss=['NAME:PolylineSegments']
        for j in range(3): ss.append(['NAME:PLSegment','SegmentType:=','Line','StartIndex:=',j,'NoOfPoints:=',2])
        e.CreatePolyline(['NAME:PolylineParameters','IsPolylineCovered:=',True,'IsPolylineClosed:=',True,pp,ss,
            ['NAME:PolylineXSection','XSectionType:=','None']],attrs(tool,'vacuum','(180 180 180)'))
        e.ThickenSheet(['NAME:Selections','Selections:=',tool,'NewPartsModelFlag:=','Model'],
            ['NAME:SheetThickenParameters','Thickness:=',mm(2*(h+.02)),'BothSides:=',True])
        subtract(name,[tool])

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
        for side in [-1,1]:
            yy=0 if side==1 else -RO-1
            box(name+'_'+str(side+1)+'_LeadSlot',[-SLOT_HALF,yy,stem_z-.00001],[2*SLOT_HALF,RO+1,STEM+.00002])
            # Cut wall only: leave the centre post intact.
            cylinder(name+'_'+str(side+1)+'_SlotProtectPost',0,0,stem_z-.001,RW,STEM+.002)
            subtract(name+'_'+str(side+1)+'_LeadSlot',[name+'_'+str(side+1)+'_SlotProtectPost'])
            subtract(name,[name+'_'+str(side+1)+'_LeadSlot'])
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
        box(name+'_PCB_LeadKeep',[-SLOT_HALF+.3,-RO-1,z-h-.02],[2*(SLOT_HALF-.3),2*(RO+1),h+.04])
        subtract(name+'_PCB_WallCut',[name+'_PCB_LeadKeep'])
        subtract(name,[name+'_PCB_WallCut']); z-=h
    red='(220 50 30)'; green='(0 150 65)'; blue='(25 90 220)'
    meta=[]; terminals=[]
    # Primary outside-in L2; mirror/reverse on L3 to keep series-aiding polarity.
    pEnds=[]
    for layer in [2,3]:
        seg=spiral(18,PWIDTH,Z[layer-1]); inner=seg[-1][1][-1]
        seg.append(('Arc',[inner,polar(R+2+PWIDTH/2,math.radians(265),Z[layer-1]),(0,-(R+2+PWIDTH/2),Z[layer-1])]))
        outer=seg[0][1][0]; term=(outer[0],-31,Z[layer-1])
        seg.insert(0,('Line',[term,outer]))
        if layer==3: seg=transform(seg,mirror=True,reverse=True)
        name='Primary_L%d_18T'%layer
        wire(name,seg,PWIDTH,CU[layer-1],red)
        pEnds.append(seg[0][1][0] if layer==2 else seg[-1][1][-1])
        meta.append(dict(layer=layer,winding='Primary',turns=18,width_mm=PWIDTH))
    via('Primary_InnerVia',(0,-(R+2+PWIDTH/2)),1,3,.2,red)
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
    sParts=[]; sEndpoints=None
    for layer in [6,7,8]:
        seg=transform(spiral(3,SWIDTH,Z[layer-1]),top=True)
        name='Secondary_L%d_3T'%layer; wire(name,seg,SWIDTH,CU[layer-1],blue); sParts.append(name)
        if layer==6: sEndpoints=[seg[0][1][0],seg[-1][1][-1]]
        meta.append(dict(layer=layer,winding='Secondary',turns=3,width_mm=SWIDTH))
    sEnds=[]
    for index,point in enumerate(sEndpoints):
        lane=4.55 if point[0]>0 else -4.55
        vn='Secondary_Via_%d'%index; via(vn,point,6,8,2.2,blue); sParts.append(vn)
        vn='Secondary_Post_%d'%index
        cylinder(vn,point[0],point[1],BUS_Z-.069/2,1.1,Z[7]+CU[7]/2-(BUS_Z-.069/2),'copper',blue); sParts.append(vn)
        by=max(point[1],R+2+6.5/2)
        if by>point[1]:
            neck='Secondary_Neck_%d'%index
            lines(neck,[(point[0],point[1],BUS_Z),(point[0],by,BUS_Z)],2.2,.069,blue); sParts.append(neck)
        bn='Secondary_Bus_%d'%index; term=(lane,31,BUS_Z)
        lines(bn+'_Neck',[(point[0],by,BUS_Z),(lane,by,BUS_Z)],2.2,.069,blue); sParts.append(bn+'_Neck')
        lines(bn,[(lane,by,BUS_Z),term],6.5,.069,blue); sParts.append(bn); sEnds.append(term)
    unite(sParts); terminals.append(('Secondary_L6_3T','WindingS',sEnds))
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
    pp='L(WindingP,WindingP)'; ss='L(WindingS,WindingS)'; ps='L(WindingP,WindingS)'; sp='L(WindingS,WindingP)'
    d.GetModule('ReportSetup').CreateReport('Primary Secondary Leakage','EddyCurrent','Data Table','Leakage_100kHz : LastAdaptive',
        ['Context:=','Matrix1'],['Freq:=',['All']],['X Component:=','Freq','Y Component:=',[pp,ss,ps,pp+'-'+ps+'*'+sp+'/'+ss,ss+'-'+sp+'*'+ps+'/'+pp]])
    native_checks={}
    for core,sgn in zip(cores,[1,-1]):
        face=e.GetFaceByPosition(['NAME:FaceParameters','BodyName:=',core,'XPosition:=','0mm',
            'YPosition:=','0mm','ZPosition:=',mm(sgn*GAP/2)])
        area=float(e.GetFaceArea(int(face)))
        assert abs(area-576)<1e-5
        for sx,sy in [(1,1),(-1,1),(-1,-1),(1,-1)]:
            bodies=list(e.GetBodyNamesByPosition(['NAME:Parameters','XPosition:=',mm(sx*(RO-.1)),
                'YPosition:=',mm(sy*(RO-.1)),'ZPosition:=',mm(sgn*(GAP/2+HALF_H/2))]))
            assert core not in bodies, 'Corner chamfer incomplete: '+core
        native_checks[core]=dict(centre_face_area_mm2=area,volume_mm3=float(e.GetObjectVolume(core)))
    e.FitAll(); p.SaveAs(os.path.join(OUT,NAME+'.aedt'),True)
    validation=d.ValidateDesign(os.path.join(OUT,'validation.log'))
    e.ExportModelImageToFile(os.path.join(OUT,NAME+'.png'),1600,1100,[])
    with open(os.path.join(OUT,NAME+'_geometry.json'),'w') as f:
        json.dump(dict(centre_area_mm2=576,centre_diameter_mm=2*R,window_radius_mm=RW,outer_side_mm=2*RO,
            outer_corner_chamfer_mm=CHAMFER,outer_wall_mm=WALL,core_height_mm=2*HALF_H+GAP,gap_mm=GAP,
            pcb_size_mm=[82,62,BOARD_T],layer_z_mm=Z,copper_mm=CU,dielectric_mm=DIEL,coils=meta,
            primary_breadth_mm=P_BREADTH,secondary_breadth_mm=S_BREADTH,aux_radial_centre_mm=AR,
            minimum_turn_spacing_mm=SPACE,transition_allowance_mm=dict(primary=TRANSITION_ALLOWANCE,secondary=SECONDARY_TRANSITION_ALLOWANCE),
            terminals=terminals,validation=validation,solved=False,native_core_checks=native_checks,
            note='Gap retained from EE; Lm/loss/leakage must be recalculated for the pot geometry.'),f,indent=2)
    if validation!=1: raise RuntimeError('AEDT validation failed; inspect validation.log')

if __name__=='__main__': build()

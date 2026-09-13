"""Native parameterized square-pot geometry; disconnected full copper rings.
Variant of build_flyback_pot_parametric_rings.py: secondary changed from
3 concentric rings per layer (L6/L7/L8 each 3T, meant to be paralleled
layer-to-layer per the real wound design) to 1 ring per layer across the
same 3 layers (meant to be stacked in series layer-to-layer instead).
Saved under a different project name; the original SeparateRings project
and its build script are untouched.
Run AEDT -ng -RunScriptAndExit. No excitations, mesh operations or analysis
-- same as the base project, these are still disconnected reference rings.
"""
import os,json
import ScriptEnv
ScriptEnv.Initialize('Ansoft.ElectronicsDesktop')
OUT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'output','36_3_2_pot','Parametric_Rings')
if not os.path.isdir(OUT): os.makedirs(OUT)
NAME='Flyback_Pot_Parametric_SeriesSecondaryRings'
p=oDesktop.NewProject();p.InsertDesign('Maxwell 3D',NAME,'EddyCurrent','')
d=p.SetActiveDesign(NAME);e=d.SetActiveEditor('3D Modeler')
e.SetModelUnits(['NAME:Units Parameter','Units:=','mm','Rescale:=',False])
variables=[('D','20mm'),('core_x','43mm'),('core_y','43mm'),('core2winding','2mm'),
 ('yoke_outer_diameter','46mm'),('yoke_thickness','4mm'),('gap','0.0935123206677404mm'),
 ('pcb_thickness','3.245mm'),('core2pcb','1mm'),('primary_turns','36'),('secondary_turns','3'),('aux_turns','2'),
 ('primary_layers','2'),('secondary_parallel_layers','3'),('aux_layers','2'),
 ('primary_turns_per_layer','primary_turns/primary_layers'),('aux_turns_per_layer','aux_turns/aux_layers'),
 # Secondary is now 1 ring per layer, 3 layers meant to stack in series
 # (L6->L7->L8) for the same 3 net turns, instead of 3 rings per layer
 # paralleled across layers. secondary_turns is kept only as the
 # documented total-turns target (=secondary_parallel_layers x
 # secondary_rings_per_layer); the ring geometry itself is driven by
 # secondary_rings_per_layer below.
 ('secondary_rings_per_layer','1'),
 ('trace_spacing','0.2mm'),('primary_transition_allowance','0.003mm'),('secondary_transition_allowance','0.025mm'),
 ('auto_trace_width','1'),('primary_width_manual','0.308277777777778mm'),('secondary_width_manual','2.85mm'),
 ('radial_breadth','yoke_outer_diameter/2-D/2-2*core2winding'),
 ('primary_width','if(auto_trace_width==1,(radial_breadth-(primary_turns_per_layer-1)*(trace_spacing+primary_transition_allowance))/primary_turns_per_layer,primary_width_manual)'),
 ('secondary_width','if(auto_trace_width==1,(radial_breadth-(secondary_rings_per_layer-1)*(trace_spacing+secondary_transition_allowance))/secondary_rings_per_layer,secondary_width_manual)'),
 ('aux_width','0.2mm'),('primary_pitch','primary_width+trace_spacing+primary_transition_allowance'),
 ('secondary_pitch','secondary_width+trace_spacing+secondary_transition_allowance'),('aux_pitch','aux_width+trace_spacing'),
 ('primary_breadth','primary_turns_per_layer*primary_width+(primary_turns_per_layer-1)*(trace_spacing+primary_transition_allowance)'),
 ('aux_breadth','aux_turns_per_layer*aux_width+(aux_turns_per_layer-1)*trace_spacing'),
 ('stem_height','pcb_thickness/2+core2pcb-gap/2'),('core_height','pcb_thickness+2*core2pcb+2*yoke_thickness'),
 ('cu_inner','0.064mm'),('cu_outer','0.069mm')]
for name,value in variables:
 d.ChangeProperty(['NAME:AllTabs',['NAME:LocalVariableTab',['NAME:PropServers','LocalVariables'],['NAME:NewProps',['NAME:'+name,'PropType:=','VariableProp','UserDef:=',True,'Value:=',value]]]])
p.GetDefinitionManager().AddMaterial(['NAME:TPG33','CoordinateSystemType:=','Cartesian','BulkOrSurfaceType:=',1,['NAME:PhysicsTypes','set:=',['Electromagnetic']],'permeability:=','3300','conductivity:=','0'])
def attrs(n,mat,col): return ['NAME:Attributes','Name:=',n,'MaterialValue:=','"'+mat+'"','SolveInside:=',True,'Color:=',col,'Transparency:=',.65 if mat=='TPG33' else 0]
def cyl(n,z,r,h,mat='vacuum'):
 e.CreateCylinder(['NAME:CylinderParameters','XCenter:=','0mm','YCenter:=','0mm','ZCenter:=',z,'Radius:=',r,'Height:=',h,'WhichAxis:=','Z','NumSides:=','0'],attrs(n,mat,'(160 160 160)'))
def sub(n,tool):e.Subtract(['NAME:Selections','Blank Parts:=',n,'Tool Parts:=',tool],['NAME:SubtractParameters','KeepOriginals:=',False])
for name,z,sz in [('Core_Upper','gap/2','gap/2'),('Core_Lower','-core_height/2','-gap/2-stem_height')]:
 e.CreateBox(['NAME:BoxParameters','XPosition:=','-core_x/2','YPosition:=','-core_y/2','ZPosition:=',z,'XSize:=','core_x','YSize:=','core_y','ZSize:=','yoke_thickness+stem_height'],attrs(name,'TPG33','(160 160 160)'))
 cyl(name+'_Window',sz,'yoke_outer_diameter/2','stem_height')
 cyl(name+'_PostKeep',sz,'D/2','stem_height')
 sub(name+'_Window',name+'_PostKeep');sub(name,name+'_Window')
# Independent native annular solids, each with expression-driven radii.
# Turn counts are topology inputs; changing counts requires rebuilding rings.
layers=[(2,'P','1.1755mm','cu_inner'),(3,'P','0.7055mm','cu_inner'),(4,'A','0.2485mm','cu_inner'),(5,'A','-0.2215mm','cu_inner'),(6,'S','-0.6915mm','cu_inner'),(7,'S','-1.1615mm','cu_inner'),(8,'S','-1.588mm','cu_outer')]
for layer,kind,z,cu in layers:
 prefix={'P':'Primary','S':'Secondary','A':'AUX'}[kind]+'_L'+str(layer)
 w={'P':'primary_width','S':'secondary_width','A':'aux_width'}[kind]
 pitch={'P':'primary_pitch','S':'secondary_pitch','A':'aux_pitch'}[kind]
 count={'P':18,'S':1,'A':1}[kind]
 radius='D/2+core2winding' if kind!='A' else 'D/2+core2winding+(primary_breadth-aux_breadth)/2'
 col={'P':'(220 50 30)','S':'(25 90 220)','A':'(0 150 65)'}[kind]
 for turn in range(count):
  name=prefix+'_Turn%02d'%(turn+1)
  inner='('+radius+')+'+str(turn)+'*'+pitch
  cyl(name,z+'-'+cu+'/2',inner+'+'+w,cu,'copper')
  cyl(name+'_Hole',z+'-'+cu+'/2',inner,cu)
  sub(name,name+'_Hole')
  e.ChangeProperty(['NAME:AllTabs',['NAME:Geometry3DAttributeTab',['NAME:PropServers',name],['NAME:ChangedProps',['NAME:Color','R:=',int(col.strip('()').split()[0]),'G:=',int(col.strip('()').split()[1]),'B:=',int(col.strip('()').split()[2])]]]])
assert len(list(e.GetObjectsInGroup('Unclassified')))==0
assert len(list(e.GetObjectsInGroup('Solids')))==43
e.FitAll();p.SaveAs(os.path.join(OUT,NAME+'.aedt'),True)
e.ExportModelImageToFile(os.path.join(OUT,NAME+'.png'),1500,1000,[])
with open(os.path.join(OUT,'geometry_manifest_series_secondary.json'),'w') as f: json.dump(dict(variables=variables,solids=list(e.GetObjectsInGroup('Solids')),unclassified=list(e.GetObjectsInGroup('Unclassified'))),f,indent=2)

"""Run in the active AEDT design after editing integer turn variables.
Only independent copper rings are rebuilt; core and variable definitions stay.
"""
import ScriptEnv
ScriptEnv.Initialize('Ansoft.ElectronicsDesktop')
p=oDesktop.GetActiveProject();d=p.GetActiveDesign();e=d.SetActiveEditor('3D Modeler')
def integer(name):
 value=float(d.GetVariableValue(name))
 if value!=int(value) or value<1: raise ValueError(name+' must be a positive integer')
 return int(value)
np=integer('primary_turns');ns=integer('secondary_turns');na=integer('aux_turns')
if np%2 or na%2: raise ValueError('Primary and AUX turns must divide evenly over their two layers')
if integer('primary_layers')!=2 or integer('aux_layers')!=2 or integer('secondary_parallel_layers')!=3: raise ValueError('This layer stack is P L2/L3, AUX L4/L5, S L6/L7/L8')
counts={'P':np//2,'S':ns,'A':na//2}
old=[str(n) for n in e.GetObjectsInGroup('Solids') if str(n).startswith(('Primary_L','Secondary_L','AUX_L'))]
if old: e.Delete(['NAME:Selections','Selections:=',','.join(old)])
def attrs(n,mat,col): return ['NAME:Attributes','Name:=',n,'MaterialValue:=','"'+mat+'"','SolveInside:=',True,'Color:=',col,'Transparency:=',.65 if mat=='TPG33' else 0]
def cyl(n,z,r,h,mat='vacuum'):
 e.CreateCylinder(['NAME:CylinderParameters','XCenter:=','0mm','YCenter:=','0mm','ZCenter:=',z,'Radius:=',r,'Height:=',h,'WhichAxis:=','Z','NumSides:=','0'],attrs(n,mat,'(160 160 160)'))
def sub(n,tool):e.Subtract(['NAME:Selections','Blank Parts:=',n,'Tool Parts:=',tool],['NAME:SubtractParameters','KeepOriginals:=',False])
layers=[(2,'P','1.1755mm','cu_inner'),(3,'P','0.7055mm','cu_inner'),(4,'A','0.2485mm','cu_inner'),(5,'A','-0.2215mm','cu_inner'),(6,'S','-0.6915mm','cu_inner'),(7,'S','-1.1615mm','cu_inner'),(8,'S','-1.588mm','cu_outer')]
for layer,kind,z,cu in layers:
 prefix={'P':'Primary','S':'Secondary','A':'AUX'}[kind]+'_L'+str(layer)
 w={'P':'primary_width','S':'secondary_width','A':'aux_width'}[kind]
 pitch={'P':'primary_pitch','S':'secondary_pitch','A':'aux_pitch'}[kind]
 count=counts[kind]
 radius='D/2+core2winding' if kind!='A' else 'D/2+core2winding+(primary_breadth-aux_breadth)/2'
 col={'P':'(220 50 30)','S':'(25 90 220)','A':'(0 150 65)'}[kind]
 for turn in range(count):
  name=prefix+'_Turn%02d'%(turn+1)
  inner='('+radius+')+'+str(turn)+'*'+pitch
  cyl(name,z+'-'+cu+'/2',inner+'+'+w,cu,'copper')
  cyl(name+'_Hole',z+'-'+cu+'/2',inner,cu)
  sub(name,name+'_Hole')
  e.ChangeProperty(['NAME:AllTabs',['NAME:Geometry3DAttributeTab',['NAME:PropServers',name],['NAME:ChangedProps',['NAME:Color','R:=',int(col.strip('()').split()[0]),'G:=',int(col.strip('()').split()[1]),'B:=',int(col.strip('()').split()[2])]]]])

e.FitAll()

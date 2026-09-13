"""Create a separate D20/Core43 mesh-tuned AEDT. No solve or reports.
Native AEDT 2024 R2: -ng -RunScriptAndExit <this file>.
"""
import os,json
import ScriptEnv
ScriptEnv.Initialize('Ansoft.ElectronicsDesktop')
root=os.path.dirname(os.path.abspath(__file__))
out=os.path.join(root,'output','36_3_2_pot','D20_Core43')
base='Flyback_36_3_2_SquarePot_D20_Core43_100kHz'
name=base.replace('_100kHz','_MeshV2_100kHz')
p=oDesktop.OpenProject(os.path.join(out,base+'.aedt'))
d=p.SetActiveDesign(base)
e=d.SetActiveEditor('3D Modeler')
m=d.GetModule('MeshSetup')
m.InitialMeshSettings(['NAME:MeshSettings',
 ['NAME:GlobalSurfApproximation','CurvedSurfaceApproxChoice:=','UseSlider','SliderMeshSettings:=',5],
 ['NAME:GlobalCurvilinear','Apply:=',False],
 ['NAME:GlobalModelRes','UseAutoLength:=',False,'DefeatureLength:=','0.001mm'],
 'MeshMethod:=','AnsoftTAU','UseLegacyFaceterForTauVolumeMesh:=',False,
 'DynamicSurfaceResolution:=',False,'UseFlexMeshingForTAUvolumeMesh:=',False,
 'UseAlternativeMeshMethodsAsFallBack:=',False])
coils=['Primary_L2_18T','Secondary_L6_3T','AUX_L4_1T']
cores=['Core_Upper','Core_Lower']
def surface(label,objects,deviation,angle):
 m.AssignTrueSurfOp(['NAME:'+label,'Type:=','SurfApproxBased','Objects:=',objects,
  'CurvedSurfaceApproxChoice:=','ManualSettings','SurfDevChoice:=',2,'SurfDev:=',deviation,
  'NormalDevChoice:=',2,'NormalDev:=',str(angle)+'deg','AspectRatioChoice:=',1,'AspectRatio:=','10'])
surface('Copper_Arc_Surface',coils,'0.005mm',10)
surface('Core_Circular_Surface',cores,'0.02mm',15)
# Mesh the physical centre and corner gap faces without subdividing all
# copper or the entire air region at the 0.0935 mm gap thickness.
gap=0.0935123206677404
faces=[]
for core,sign in zip(cores,[1,-1]):
 for x,y in [(0,0),(19.5,19.5),(-19.5,19.5),(-19.5,-19.5),(19.5,-19.5)]:
  face=int(e.GetFaceByPosition(['NAME:FaceParameters','BodyName:=',core,
   'XPosition:=',str(x)+'mm','YPosition:=',str(y)+'mm','ZPosition:=',str(sign*gap/2)+'mm']))
  if face<=0: raise RuntimeError('Missing gap face')
  if face not in faces: faces.append(face)
m.AssignLengthOp(['NAME:Gap_Face_Seed','RefineInside:=',False,'Faces:=',faces,
 'RestrictElem:=',True,'NumMaxElem:=','25000','RestrictLength:=',True,'MaxLength:=','1mm'])
# Preserve the original 1 percent acceptance criterion, 10 passes, and
# full solid-copper eddy-current physics. No artificial convergence relaxation.
validation=d.ValidateDesign(os.path.join(out,name+'_validation.log'))
if validation!=1: raise RuntimeError('MeshV2 validation failed')
p.SaveAs(os.path.join(out,name+'.aedt'),True)
with open(os.path.join(out,name+'_settings.json'),'w') as f:
 json.dump(dict(source=base,mesh_method='AnsoftTAU',curvilinear=False,
 copper_surface_deviation_mm=.005,core_surface_deviation_mm=.02,
 gap_faces=faces,gap_face_maxlength_mm=1,gap_face_element_cap=25000,
 validation=validation,solved=False,convergence_improvement_verified=False),f,indent=2)

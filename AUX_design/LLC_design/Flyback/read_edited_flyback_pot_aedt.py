"""Read-only AEDT snapshot for Flyback_Magnetics_36_3_2_SquarePot_Sweep.m.
Run in AEDT after saving manual 3D edits. Does not save the source project.
"""
import ScriptEnv,os,json
ScriptEnv.Initialize('Ansoft.ElectronicsDesktop')
root=os.path.dirname(os.path.abspath(__file__))
out=os.path.join(root,'output','36_3_2_pot')
name='Flyback_36_3_2_Scheme_C_Pot_100kHz'
p=oDesktop.OpenProject(os.path.join(out,name+'.aedt'))
d=p.SetActiveDesign(name); e=d.SetActiveEditor('3D Modeler')
data={}
for body in ['Core_Upper','Core_Lower','Primary_L2_18T','Secondary_L6_3T','AUX_L4_1T']:
    faces=[]
    if body.startswith('Core'):
        for face in e.GetFaceIDs(body):
            vertices=[list(e.GetVertexPosition(v)) for v in e.GetVertexIDsFromFace(face)]
            faces.append(dict(id=int(face),area=float(e.GetFaceArea(int(face))),vertices=vertices))
    data[body]=dict(bounds=list(e.GetObjectBoundingBox(body)),volume_mm3=float(e.GetObjectVolume(body)),faces=faces)
with open(os.path.join(out,'edited_pot_snapshot.json'),'w') as f: json.dump(data,f,indent=2)
e.FitAll()
e.ExportModelImageToFile(os.path.join(out,'edited_pot_snapshot.png'),1500,1100,[])

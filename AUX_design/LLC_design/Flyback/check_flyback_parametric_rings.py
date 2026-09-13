import os,json,math
import ScriptEnv
ScriptEnv.Initialize('Ansoft.ElectronicsDesktop')
root=os.path.dirname(os.path.abspath(__file__))
out=os.path.join(root,'output','36_3_2_pot','Parametric_Rings')
p=oDesktop.OpenProject(os.path.join(out,'Flyback_Pot_Parametric_SeparateRings.aedt'))
d=p.SetActiveDesign('Flyback_Pot_Parametric_SeparateRings');e=d.SetActiveEditor('3D Modeler')
def setvar(name,value):d.ChangeProperty(['NAME:AllTabs',['NAME:LocalVariableTab',['NAME:PropServers','LocalVariables'],['NAME:ChangedProps',['NAME:'+name,'Value:=',value]]]])
v0=float(e.GetObjectVolume('Primary_L2_Turn01'))
setvar('D','21mm')
v1=float(e.GetObjectVolume('Primary_L2_Turn01'))
assert abs(v0-v1)>1e-5 and not list(e.GetObjectsInGroup('Unclassified'))
setvar('D','20mm');setvar('primary_turns','40');setvar('secondary_turns','4');setvar('aux_turns','4')
execfile(os.path.join(root,'rebuild_flyback_parametric_ring_turns.py'))
assert len(list(e.GetObjectsInGroup('Solids')))==58
assert not list(e.GetObjectsInGroup('Unclassified'))
with open(os.path.join(out,'parameter_update_test.json'),'w') as f:json.dump(dict(diameter_update_pass=True,turn_rebuild_40_4_4_pass=True,baseline_primary_first_turn_volume_mm3=v0,changed_volume_mm3=v1),f,indent=2)
# Do not save the test variant over the delivered baseline.

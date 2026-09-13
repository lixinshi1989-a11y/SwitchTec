"""Native AEDT validation and saved color audit of the front/back paired-terminal model."""
import os
import shutil
import json
import ScriptEnv
ScriptEnv.Initialize('Ansoft.ElectronicsDesktop')
root = os.path.dirname(os.path.abspath(__file__))
stem = 'LLC_7x14_Secondary_Straight_Paired1mm'
source = os.path.join(root,'output',stem+'_800kHz.aedt')
target = os.path.join(root,'..','tmp',stem+'_NativeValidation.aedt')
shutil.copy2(source,target)
project = oDesktop.OpenProject(target)
design = project.SetActiveDesign('LLC_Transformer_800kHz')
result = design.ValidateDesign(os.path.join(root,'output',stem+'_native_validation.log'))
editor = design.SetActiveEditor('3D Modeler')
colors = {}
for name in ['S1_L1_4T','S2_L3_4T','S3_L6_4T','S4_L8_4T']:
    colors[name] = str(editor.GetPropertyValue('Geometry3DAttributeTab',name,'Color'))
with open(os.path.join(root,'output',stem+'_native_validation.json'),'w') as f:
    json.dump({'validation_result':result,'colors':colors},f,indent=2)
oDesktop.CloseProject(project.GetName())

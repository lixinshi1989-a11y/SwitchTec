import ScriptEnv
import os
ScriptEnv.Initialize('Ansoft.ElectronicsDesktop')
root = os.path.dirname(os.path.abspath(__file__))
source = os.path.join(root, 'output', 'LLC_Rectangular_7x14_Secondary_L1L3_L8L6_ReturnL2L7_Gap4mm_800kHz.aedt')
import shutil
target = os.path.join(root, '..', 'tmp', 'LLC_Secondary_NativeValidation.aedt')
shutil.copy2(source, target)
project = oDesktop.OpenProject(target)
design = project.SetActiveDesign('LLC_Transformer_800kHz')
result = design.ValidateDesign(os.path.join(root, 'output', 'secondary_L1378_native_validation.log'))
with open(os.path.join(root, 'output', 'secondary_L1378_native_validation_result.txt'), 'w') as f:
    f.write(str(result))
oDesktop.CloseProject(project.GetName())

"""Apply four secondary colors to a separate copy of the configured project."""
import os
import ScriptEnv
ScriptEnv.Initialize('Ansoft.ElectronicsDesktop')
root = os.path.dirname(os.path.abspath(__file__))
stem = 'LLC_Rectangular_7x14_Secondary_L1L3_L8L6_ReturnL2L7_Gap4mm'
project = oDesktop.OpenProject(os.path.join(root, 'output', stem + '_800kHz.aedt'))
design = project.SetActiveDesign('LLC_Transformer_800kHz')
editor = design.SetActiveEditor('3D Modeler')
for name, rgb in [('S1_L1_4T', (0,114,189)), ('S2_L3_4T', (217,83,25)),
                  ('S3_L6_4T', (237,177,32)), ('S4_L8_4T', (126,47,142))]:
    editor.ChangeProperty(['NAME:AllTabs', ['NAME:Geometry3DAttributeTab',
        ['NAME:PropServers', name], ['NAME:ChangedProps',
        ['NAME:Color', 'R:=', rgb[0], 'G:=', rgb[1], 'B:=', rgb[2]]]]])
project.SaveAs(os.path.join(root, 'output', stem + '_Colored_800kHz.aedt'), True)
oDesktop.CloseProject(project.GetName())

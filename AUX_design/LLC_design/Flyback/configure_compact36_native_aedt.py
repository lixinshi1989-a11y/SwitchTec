"""Native AEDT batch alternative to the CPython LLC-style matrix configuration."""
import ScriptEnv
import os
ScriptEnv.Initialize('Ansoft.ElectronicsDesktop')
root=os.path.join(os.path.dirname(os.path.abspath(__file__)),'output','36_3_2_compact')
source=os.path.join(root,'Flyback_36_3_2_Compact70mm_Connected_100kHz.aedt')
target=os.path.join(root,'Flyback_36_3_2_Compact70mm_ConfiguredBatch_100kHz.aedt')
project=oDesktop.OpenProject(source)
design=project.SetActiveDesign('Flyback_C_EE_100kHz')
editor=design.SetActiveEditor('3D Modeler')
boundary=design.GetModule('BoundarySetup')
def mm(v): return str(v)+'mm'
region=['NAME:RegionParameters']
for direction,padding in zip(['+X','-X','+Y','-Y','+Z','-Z'],[20,20,0,0,20,20]):
    region += [direction+'PaddingType:=','Absolute Offset',direction+'Padding:=',mm(padding)]
editor.CreateRegion(region,['NAME:Attributes','Name:=','Region','Flags:=','Wireframe#',
    'MaterialValue:=','"vacuum"','SolveInside:=',True])
solids=['Primary_A_L2_18T','Secondary_A_L6_3T','AUX_A_L4_1T']
windings=['WindingP','WindingS','WindingA']
pairs=[[(-20.9,-31,1.1755),(20.9,-31,.7055)],
       [(4.55,31,-2.157),(-4.55,31,-2.157)],
       [(-3,-31,1.588),(3,-31,1.588)]]
for solid,winding,pair in zip(solids,windings,pairs):
    coil_names=[]
    for index,(x,y,z) in enumerate(pair):
        face=editor.GetFaceByPosition(['NAME:FaceParameters','BodyName:=',solid,
            'XPosition:=',mm(x),'YPosition:=',mm(y),'ZPosition:=',mm(z)])
        if int(face)<=0: raise RuntimeError('Missing terminal face: '+winding)
        coil=winding+('_Positive' if index==0 else '_Negative')
        boundary.AssignCoilTerminal(['NAME:'+coil,'Faces:=',[int(face)],
            'Conductor number:=','1','Point out of terminal:=',index==1])
        coil_names.append(coil)
    boundary.AssignWindingGroup(['NAME:'+winding,'Type:=','Current','IsSolid:=',True,
        'Current:=','1A' if winding=='WindingP' else '0A','Resistance:=','0ohm',
        'Inductance:=','0H','Voltage:=','0V','ParallelBranchesNum:=','1','Phase:=','0deg'])
    boundary.AddWindingTerminals(winding,coil_names)
eddy=['NAME:EddyEffectVector']
for solid in solids:
    eddy.append(['NAME:Data','Object Name:=',solid,'Eddy Effect:=',True,'Displacement Current:=',False])
boundary.SetEddyEffect(['NAME:Eddy Effect Setting',eddy])
boundary.SetCoreLoss(['Core_Upper_Yoke','Core_Lower_Yoke'],False)
entries=['NAME:MatrixEntry']
for winding in windings: entries.append(['NAME:MatrixEntry','Source:=',winding])
design.GetModule('MaxwellParameterSetup').AssignMatrix(['NAME:Matrix1',entries])
design.GetModule('AnalysisSetup').InsertSetup('EddyCurrent',['NAME:Leakage_100kHz',
    'Enabled:=',True,'Frequency:=','100kHz','MaximumPasses:=',10,'MinimumPasses:=',2,
    'MinimumConvergedPasses:=',2,'PercentRefinement:=',30,'PercentError:=',1,
    'SolveMatrixAtLast:=',True,'UseHighOrderShapeFunc:=',False])
pp='L(WindingP,WindingP)'; ss='L(WindingS,WindingS)'
ps='L(WindingP,WindingS)'; sp='L(WindingS,WindingP)'
design.GetModule('ReportSetup').CreateReport('Primary Secondary Leakage','EddyCurrent','Data Table',
    'Leakage_100kHz : LastAdaptive',['Context:=','Matrix1'],['Freq:=',['All']],
    ['X Component:=','Freq','Y Component:=',[pp,ss,ps,pp+'-'+ps+'*'+sp+'/'+ss,
                                           ss+'-'+sp+'*'+ps+'/'+pp]])
project.SaveAs(target,True)
with open(os.path.join(root,'ConfiguredBatch_manifest.txt'),'w') as stream:
    stream.write('Project='+target+'\nSetup=Leakage_100kHz\nMatrix=Matrix1: P,S,AUX\n'
        'P=1 A; S=0 A; AUX=0 A (open). Copper eddy effects on.\n'
        'Configured only; no solution yet. Short circuit leakage reports use Lpp-Mps*Msp/Lss and Lss-Mps*Msp/Lpp.\n')

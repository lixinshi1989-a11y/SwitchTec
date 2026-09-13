"""Configure existing parameterized rings using SeparateRings settings.
Series secondary: all three one-turn coil terminals assigned to WindingS.
No physical bridges or mesh overrides; requested inductance report; no solve.
"""
import os,json,re
import ScriptEnv
ScriptEnv.Initialize('Ansoft.ElectronicsDesktop')
out=os.path.join(os.path.dirname(os.path.abspath(__file__)),'output','36_3_2_pot','Parametric_Rings')
name='Flyback_Pot_Parametric_SeriesSecondaryRings'
p=oDesktop.OpenProject(os.path.join(out,name+'.aedt'))
d=p.SetActiveDesign(name);e=d.SetActiveEditor('3D Modeler');b=d.GetModule('BoundarySetup')
solids=list(e.GetObjectsInGroup('Solids'));groups={'WindingP':[],'WindingS':[],'WindingA':[]}
for body in sorted(solids):
 if not body.startswith(('Primary_L','Secondary_L','AUX_L')):continue
 layer=int(re.search('_L([0-9]+)',body).group(1));turn=int(re.search('Turn([0-9]+)',body).group(1))
 kind='P' if body.startswith('Primary') else ('S' if body.startswith('Secondary') else 'A')
 w={'P':'primary_width','S':'secondary_width','A':'aux_width'}[kind]
 pitch={'P':'primary_pitch','S':'secondary_pitch','A':'aux_pitch'}[kind]
 radius='D/2+core2winding' if kind!='A' else 'D/2+core2winding+(primary_breadth-aux_breadth)/2'
 radius='('+radius+')+'+str(turn-1)+'*'+pitch
 z={2:'1.1755mm',3:'0.7055mm',4:'0.2485mm',5:'-0.2215mm',6:'-0.6915mm',7:'-1.1615mm',8:'-1.588mm'}[layer]
 cu='cu_outer' if layer==8 else 'cu_inner'
 sheet=body+'_Terminal'
 # Positive-Y radial cross-section, consistent normal for all turns.
 e.CreateRectangle(['NAME:RectangleParameters','IsCovered:=',True,'XStart:=','0mm','YStart:=',radius,'ZStart:=',z+'-'+cu+'/2',
 'Width:=',w,'Height:=',cu,'WhichAxis:=','X'],['NAME:Attributes','Name:=',sheet,'MaterialValue:=','"vacuum"','SolveInside:=',True])
 winding='WindingP' if kind=='P' else ('WindingS' if kind=='S' else 'WindingA')
 coil=body+'_Coil'
 b.AssignCoilTerminal(['NAME:'+coil,'Objects:=',[sheet],'Conductor number:=','1','Point out of terminal:=',False])
 groups[winding].append(coil)
for winding,coils in groups.items():
 b.AssignWindingGroup(['NAME:'+winding,'Type:=','Current','IsSolid:=',True,'Current:=','0.3A' if winding=='WindingP' else '0A',
 'Resistance:=','0ohm','Inductance:=','0H','Voltage:=','0V','ParallelBranchesNum:=','1','Phase:=','0deg'])
 b.AddWindingTerminals(winding,coils)
assert [len(groups[x]) for x in ['WindingP','WindingS','WindingA']]==[36,3,2]
region=['NAME:RegionParameters']
for direction in ['+X','-X','+Y','-Y','+Z','-Z']:region += [direction+'PaddingType:=','Percentage Offset',direction+'Padding:=','50']
e.CreateRegion(region,['NAME:Attributes','Name:=','Region','Flags:=','Wireframe#','MaterialValue:=','"vacuum"','SolveInside:=',True])
m=d.GetModule('MaxwellParameterSetup')
m.AssignMatrix(['NAME:Matrix1',['NAME:MatrixEntry']+[['NAME:MatrixEntry','Source:=',n] for n in ['WindingP','WindingS','WindingA']]])
d.GetModule('AnalysisSetup').InsertSetup('EddyCurrent',['NAME:Setup1','Enabled:=',True,'Frequency:=','100kHz','MaximumPasses:=',10,
 'MinimumPasses:=',2,'MinimumConvergedPasses:=',1,'PercentRefinement:=',30,'PercentError:=',5,'SolveMatrixAtLast:=',True,'UseHighOrderShapeFunc:=',False])
expression='L(WindingP,WindingP)+12*2*L(WindingS,WindingP)+12*12*L(WindingS,WindingS)'
d.GetModule('ReportSetup').CreateReport('Requested Inductance Combination','EddyCurrent','Data Table','Setup1 : LastAdaptive',
 ['Context:=','Matrix1'],['Freq:=',['All']],['X Component:=','Freq','Y Component:=',[expression]])
validation=d.ValidateDesign(os.path.join(out,name+'_WindingS_Configured_validation.log'))
if validation!=1:raise RuntimeError('Configuration validation failed')
p.SaveAs(os.path.join(out,name+'_WindingS_Configured.aedt'),True)
with open(os.path.join(out,name+'_WindingS_Configured_manifest.json'),'w') as f:json.dump(dict(groups=groups,validation=validation,secondary_connection='three coils directly in WindingS',report_expression=expression,solved=False),f,indent=2)

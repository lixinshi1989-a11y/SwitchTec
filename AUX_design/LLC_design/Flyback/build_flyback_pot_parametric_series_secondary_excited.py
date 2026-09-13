"""Excited variant of build_flyback_pot_parametric_series_secondary_rings.py.
Every turn ring gets a small angular gap (instead of being a closed loop),
consecutive rings are bridged (radial jumper within a layer, vertical via
across layers) into one series chain per winding, and real coil terminals /
winding excitations / matrix / EddyCurrent setup are added so this model can
be solved directly -- same overall recipe as build_flyback_36_3_2_square_pot_
d20_core43_aedt.py, applied to simple stacked/concentric full rings instead
of a continuous spiral.
Secondary here is 1 ring/layer x 3 layers (L6/L7/L8) in SERIES (3 net turns),
matching the SeriesSecondaryRings variant; Primary is 18 rings/layer x 2
layers (L2/L3) in series (36 net turns); AUX is 1 ring/layer x 2 layers
(L4/L5) in series (2 net turns).
Saved under a separate project name; SeparateRings and the plain
SeriesSecondaryRings geometry-only file are both left untouched.
Run AEDT -ng -RunScriptAndExit.
"""
import os, json, math
import ScriptEnv
ScriptEnv.Initialize('Ansoft.ElectronicsDesktop')
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'output', '36_3_2_pot', 'Parametric_Rings')
if not os.path.isdir(OUT): os.makedirs(OUT)
NAME = 'Flyback_Pot_Parametric_SeriesSecondaryRings_Excited'

# ---- numeric geometry (mirrors the AEDT variable formulas in the base build script) ----
D = 20.0; core2winding = 2.0
yoke_outer_diameter = 46.0
gap = 0.0935123206677404
pcb_thickness = 3.245; core2pcb = 1.0; yoke_thickness = 4.0
primary_turns = 36; aux_turns = 2
primary_layers = 2; aux_layers = 2
primary_turns_per_layer = primary_turns // primary_layers   # 18
aux_turns_per_layer = aux_turns // aux_layers                # 1
secondary_rings_per_layer = 1
trace_spacing = 0.2
primary_transition_allowance = 0.003
secondary_transition_allowance = 0.025
radial_breadth = yoke_outer_diameter/2 - D/2 - 2*core2winding   # 9.0
primary_width = (radial_breadth-(primary_turns_per_layer-1)*(trace_spacing+primary_transition_allowance))/primary_turns_per_layer
secondary_width = (radial_breadth-(secondary_rings_per_layer-1)*(trace_spacing+secondary_transition_allowance))/secondary_rings_per_layer
aux_width = 0.2
primary_pitch = primary_width+trace_spacing+primary_transition_allowance
secondary_pitch = secondary_width+trace_spacing+secondary_transition_allowance
aux_pitch = aux_width+trace_spacing
primary_breadth = primary_turns_per_layer*primary_width+(primary_turns_per_layer-1)*(trace_spacing+primary_transition_allowance)
aux_breadth = aux_turns_per_layer*aux_width+(aux_turns_per_layer-1)*trace_spacing
stem_height = pcb_thickness/2+core2pcb-gap/2
core_height = pcb_thickness+2*core2pcb+2*yoke_thickness
cu_inner = 0.064; cu_outer = 0.069
core_x = 43.0; core_y = 43.0

GAP_LEN = 0.4        # mm, straight-line width of each ring's cut gap
JUMPER_W = 0.2        # mm, width of the connecting bridge/via footprint
JUMPER_MARGIN = 0.15  # mm, overlap into each ring so union is unambiguous

layers_p = [(2, 1.1755), (3, 0.7055)]
layers_a = [(4, 0.2485), (5, -0.2215)]
layers_s = [(6, -0.6915), (7, -1.1615), (8, -1.588)]

p = oDesktop.NewProject(); p.InsertDesign('Maxwell 3D', NAME, 'EddyCurrent', '')
d = p.SetActiveDesign(NAME); e = d.SetActiveEditor('3D Modeler')
e.SetModelUnits(['NAME:Units Parameter', 'Units:=', 'mm', 'Rescale:=', False])
p.GetDefinitionManager().AddMaterial(['NAME:TPG33', 'CoordinateSystemType:=', 'Cartesian', 'BulkOrSurfaceType:=', 1,
    ['NAME:PhysicsTypes', 'set:=', ['Electromagnetic']], 'permeability:=', '3300', 'conductivity:=', '0'])

def mm(v): return '%.9fmm' % v
def attrs(n, mat, col): return ['NAME:Attributes', 'Name:=', n, 'MaterialValue:=', '"'+mat+'"', 'SolveInside:=', True, 'Color:=', col]
def box(n, xyz, dim, mat='vacuum', color='(180 180 180)'):
    e.CreateBox(['NAME:BoxParameters', 'XPosition:=', mm(xyz[0]), 'YPosition:=', mm(xyz[1]), 'ZPosition:=', mm(xyz[2]),
        'XSize:=', mm(dim[0]), 'YSize:=', mm(dim[1]), 'ZSize:=', mm(dim[2])], attrs(n, mat, color))
def cyl(n, x, y, z, r, h, mat='vacuum', color='(180 180 180)'):
    e.CreateCylinder(['NAME:CylinderParameters', 'XCenter:=', mm(x), 'YCenter:=', mm(y), 'ZCenter:=', mm(z),
        'Radius:=', mm(r), 'Height:=', mm(h), 'WhichAxis:=', 'Z', 'NumSides:=', '0'], attrs(n, mat, color))
def subtract(n, tool, keep=False):
    e.Subtract(['NAME:Selections', 'Blank Parts:=', n, 'Tool Parts:=', ','.join(tool) if isinstance(tool, list) else tool],
        ['NAME:SubtractParameters', 'KeepOriginals:=', keep])
def unite(parts):
    e.Unite(['NAME:Selections', 'Selections:=', ','.join(parts)], ['NAME:UniteParameters', 'KeepOriginals:=', False])
def rotate(name, angle_deg):
    e.Rotate(['NAME:Selections', 'Selections:=', name, 'NewPartsModelFlag:=', 'Model'],
        ['NAME:RotateParameters', 'RotateAxis:=', 'Z', 'RotateAngle:=', str(angle_deg)+'deg'])
def move(name, dx, dy, dz=0.0):
    e.Move(['NAME:Selections', 'Selections:=', name, 'NewPartsModelFlag:=', 'Model'],
        ['NAME:TranslateParameters', 'TranslateVectorX:=', mm(dx), 'TranslateVectorY:=', mm(dy), 'TranslateVectorZ:=', mm(dz)])

for name, z0, sz in [('Core_Upper', gap/2, gap/2), ('Core_Lower', -core_height/2, -gap/2-stem_height)]:
    box(name, [-core_x/2, -core_y/2, z0], [core_x, core_y, yoke_thickness+stem_height], 'TPG33', '(160 160 160)')
    cyl(name+'_Window', 0, 0, sz, yoke_outer_diameter/2, stem_height)
    cyl(name+'_PostKeep', 0, 0, sz, D/2, stem_height)
    subtract(name+'_Window', [name+'_PostKeep'])
    subtract(name, [name+'_Window'])

def ring_with_gap(name, r_in, width, z, thickness, gap_center_deg, gap_len, color):
    cyl(name, 0, 0, z-thickness/2, r_in+width, thickness, 'copper', color)
    cyl(name+'_Hole', 0, 0, z-thickness/2, r_in, thickness)
    subtract(name, [name+'_Hole'])
    margin = 0.5
    tool = name+'_GapCut'
    box(tool, [r_in-margin, -gap_len/2, z-thickness/2-0.02], [width+2*margin, gap_len, thickness+0.04])
    rotate(tool, gap_center_deg)
    subtract(name, [tool])
    r_mid = r_in+width/2
    half = math.degrees(math.atan2(gap_len/2, r_mid))
    def facepoint(sign):
        ang = math.radians(gap_center_deg+sign*half)
        return (r_mid*math.cos(ang), r_mid*math.sin(ang), z)
    return facepoint(-1), facepoint(+1)

def bridge(name, p1, p2, z, thickness, width, color):
    dx, dy = p2[0]-p1[0], p2[1]-p1[1]
    length = math.hypot(dx, dy)
    angle = math.degrees(math.atan2(dy, dx))
    box(name, [-JUMPER_MARGIN, -width/2, z-thickness/2], [length+2*JUMPER_MARGIN, width, thickness], 'copper', color)
    rotate(name, angle)
    move(name, p1[0], p1[1], 0)

def via_point(name, p, z_top, z_bot, thickness_top, thickness_bot, diameter, color):
    bottom = z_bot - thickness_bot/2
    top = z_top + thickness_top/2
    cyl(name, p[0], p[1], bottom, diameter/2, top-bottom, 'copper', color)

red = '(220 50 30)'; green = '(0 150 65)'; blue = '(25 90 220)'

def build_chain(prefix, layer_specs, count_per_layer, width, pitch, base_radius, thickness_of, color):
    all_names = []
    prev_face = None; prev_z = None; prev_thickness = None
    theta = 0.0
    chain_start = None
    for li, (layer_id, z) in enumerate(layer_specs):
        thickness = thickness_of(layer_id)
        turn_order = range(count_per_layer) if li % 2 else range(count_per_layer-1, -1, -1)
        for turn in turn_order:
            r = base_radius + turn*pitch
            half = math.degrees(math.atan2(GAP_LEN/2, r+width/2))
            theta += half
            name = '%s_L%d_Turn%02d' % (prefix, layer_id, turn+1)
            aface, bface = ring_with_gap(name, r, width, z, thickness, theta, GAP_LEN, color)
            theta += half
            all_names.append(name)
            if prev_face is None:
                chain_start = aface
            else:
                bname = name+'_Bridge'
                if abs(z-prev_z) < 1e-9:
                    bridge(bname, prev_face, aface, z, thickness, JUMPER_W, color)
                else:
                    via_point(bname, prev_face, z, prev_z, thickness, prev_thickness, max(JUMPER_W, 0.2), color)
                all_names.append(bname)
            prev_face = bface; prev_z = z; prev_thickness = thickness
    unite(all_names)
    return all_names[0], chain_start, prev_face

def thickness_p(layer_id): return cu_inner
def thickness_a(layer_id): return cu_inner
def thickness_s(layer_id): return cu_outer if layer_id == 8 else cu_inner

p_solid, p_start, p_end = build_chain('Primary', layers_p, primary_turns_per_layer, primary_width, primary_pitch, D/2+core2winding, thickness_p, red)
a_solid, a_start, a_end = build_chain('AUX', layers_a, aux_turns_per_layer, aux_width, aux_pitch, D/2+core2winding+(primary_breadth-aux_breadth)/2, thickness_a, green)
s_solid, s_start, s_end = build_chain('Secondary', layers_s, secondary_rings_per_layer, secondary_width, secondary_pitch, D/2+core2winding, thickness_s, blue)

assert len(list(e.GetObjectsInGroup('Unclassified'))) == 0

region = ['NAME:RegionParameters']
for direction, padding in zip(['+X', '-X', '+Y', '-Y', '+Z', '-Z'], [20, 20, 20, 20, 20, 20]):
    region += [direction+'PaddingType:=', 'Absolute Offset', direction+'Padding:=', mm(padding)]
e.CreateRegion(region, ['NAME:Attributes', 'Name:=', 'Region', 'Flags:=', 'Wireframe#', 'MaterialValue:=', '"vacuum"', 'SolveInside:=', True])

b = d.GetModule('BoundarySetup')
windings = [(p_solid, 'WindingP', p_start, p_end, '1A'), (s_solid, 'WindingS', s_start, s_end, '0A'), (a_solid, 'WindingA', a_start, a_end, '0A')]
for solid, winding, pt_a, pt_b, current in windings:
    cn = []
    for index, pt in enumerate([pt_a, pt_b]):
        face = e.GetFaceByPosition(['NAME:FaceParameters', 'BodyName:=', solid, 'XPosition:=', mm(pt[0]), 'YPosition:=', mm(pt[1]), 'ZPosition:=', mm(pt[2])])
        if int(face) <= 0: raise RuntimeError('Missing terminal face: '+winding)
        name = winding+('_Positive' if index == 0 else '_Negative')
        b.AssignCoilTerminal(['NAME:'+name, 'Faces:=', [int(face)], 'Conductor number:=', '1', 'Point out of terminal:=', index == 1])
        cn.append(name)
    b.AssignWindingGroup(['NAME:'+winding, 'Type:=', 'Current', 'IsSolid:=', True, 'Current:=', current,
        'Resistance:=', '0ohm', 'Inductance:=', '0H', 'Voltage:=', '0V', 'ParallelBranchesNum:=', '1', 'Phase:=', '0deg'])
    b.AddWindingTerminals(winding, cn)

copper = [p_solid, s_solid, a_solid]
b.SetEddyEffect(['NAME:Eddy Effect Setting', ['NAME:EddyEffectVector']+
    [['NAME:Data', 'Object Name:=', n, 'Eddy Effect:=', True, 'Displacement Current:=', False] for n in copper]])
b.SetCoreLoss(['Core_Upper', 'Core_Lower'], False)
entries = ['NAME:MatrixEntry']+[['NAME:MatrixEntry', 'Source:=', n] for n in ['WindingP', 'WindingS', 'WindingA']]
d.GetModule('MaxwellParameterSetup').AssignMatrix(['NAME:Matrix1', entries])
d.GetModule('AnalysisSetup').InsertSetup('EddyCurrent', ['NAME:Setup100kHz', 'Enabled:=', True, 'Frequency:=', '100kHz',
    'MaximumPasses:=', 10, 'MinimumPasses:=', 2, 'MinimumConvergedPasses:=', 2, 'PercentRefinement:=', 30, 'PercentError:=', 1, 'SolveMatrixAtLast:=', True])

e.FitAll(); p.SaveAs(os.path.join(OUT, NAME+'.aedt'), True)
validation = d.ValidateDesign(os.path.join(OUT, 'validation_excited.log'))
e.ExportModelImageToFile(os.path.join(OUT, NAME+'.png'), 1500, 1000, [])
with open(os.path.join(OUT, 'geometry_manifest_series_secondary_excited.json'), 'w') as f:
    json.dump(dict(primary_solid=p_solid, secondary_solid=s_solid, aux_solid=a_solid,
        primary_width_mm=primary_width, secondary_width_mm=secondary_width, aux_width_mm=aux_width,
        validation=validation, solids=list(e.GetObjectsInGroup('Solids')),
        unclassified=list(e.GetObjectsInGroup('Unclassified'))), f, indent=2)
if validation != 1: raise RuntimeError('AEDT validation failed; inspect validation_excited.log')

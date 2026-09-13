"""Build the planar LLC transformer in Ansys Electronics Desktop 2024 R2.

Save-as geometry variant with 3.6 mm via clearance on L2/L7.
Run directly inside AEDT. The old configure script has different secondary
terminal coordinates; update them before configuring this variant:
L3/L6 START: x=28 mm, y=+3/-3 mm; L2/L7 END lane: y=-14.65 mm.
All output terminal X positions remain 29 mm. No solver setup is assigned here.
Geometry units are millimetres. Blind-via access is limited to L1-L2/L1-L3
and L8-L7/L8-L6. Surface breakouts preserve each winding's trace width.
"""
import ScriptEnv
import os
import math
import json

# Save-as variant: L2/L7 avoid the deeper secondary access vias.
# Clearance means copper edge to via copper edge, not centre distance.
VIA_CLEARANCE = 3.6
ARC_MARGIN = 0.02
clearance_audit = []

ScriptEnv.Initialize("Ansoft.ElectronicsDesktop")
oDesktop.RestoreWindow()
oProject = oDesktop.NewProject()
oProject.InsertDesign("Maxwell 3D", "LLC_Transformer_800kHz", "EddyCurrent", "")
oDesign = oProject.SetActiveDesign("LLC_Transformer_800kHz")
oEditor = oDesign.SetActiveEditor("3D Modeler")
oEditor.SetModelUnits(["NAME:Units Parameter", "Units:=", "mm", "Rescale:=", False])

# -----------------------------------------------------------------------------
# Confirmed design inputs
# -----------------------------------------------------------------------------
BOARD_X = 60.0
BOARD_Y = 36.0
CU = [0.069, 0.064, 0.064, 0.064, 0.064, 0.064, 0.064, 0.069]
DIEL = [0.346, 0.406, 0.393, 0.406, 0.406, 0.406, 0.360]
BOARD_T = sum(CU) + sum(DIEL)       # 3.245 mm

CORE_LENGTH = 30.0
CORE_DEPTH = 14.0
LEG = 7.0
LEG_PITCH = 23.0
SLOT_X = 7.6
SLOT_Y = 14.6
# Keep the previously verified physical gap. Reducing the U height shortens
# the ferrite path and is intentionally allowed to increase Lm slightly.
GAP_EACH_JOINT = 0.052554
CORE_TO_PCB_SURFACE = 0.5
# Inner yoke face = PCB surface + 1 mm. The half-gap is outside each U core.
U_HEIGHT = LEG + BOARD_T / 2.0 + CORE_TO_PCB_SURFACE - GAP_EACH_JOINT / 2.0

P_TURNS = 3
S_TURNS = 4
P_WIDTH = 1.20
S_WIDTH = 0.70
TURN_SPACING = 0.20
LEG_TO_COPPER = 2.00               # production clearance from slot/core to copper
SEC_LEG_TO_COPPER = 2.00           # secondary winding copper-to-core clearance

# L2/L3 contain primary spirals around the left leg and output spirals around
# the right leg. Their nearest copper edges remain more than 2 mm apart.
PRIMARY_LAYERS = {2: "P1", 3: "P2"}
SECONDARY_LAYERS = {2: "S1", 3: "S2", 6: "S3", 7: "S4"}


def mm(value):
    return "{:.6f}mm".format(float(value))


def create_box(name, origin, size, material, color):
    return oEditor.CreateBox(
        ["NAME:BoxParameters", "XPosition:=", mm(origin[0]),
         "YPosition:=", mm(origin[1]), "ZPosition:=", mm(origin[2]),
         "XSize:=", mm(size[0]), "YSize:=", mm(size[1]), "ZSize:=", mm(size[2])],
        ["NAME:Attributes", "Name:=", name, "Flags:=", "", "Color:=", color,
         "Transparency:=", 0.0, "PartCoordinateSystem:=", "Global",
         "UDMId:=", "", "MaterialValue:=", '"{}"'.format(material),
         "SurfaceMaterialValue:=", '""', "SolveInside:=", True,
         "ShellElement:=", False, "ShellElementThickness:=", "0mm",
         "IsMaterialEditable:=", True, "UseMaterialAppearance:=", False,
         "IsLightweight:=", False])


def subtract(blank, tools):
    oEditor.Subtract(
        ["NAME:Selections", "Blank Parts:=", blank, "Tool Parts:=", ",".join(tools)],
        ["NAME:SubtractParameters", "KeepOriginals:=", False])


def unite(parts):
    """Merge all touching copper pieces belonging to one electrical winding."""
    oEditor.Unite(
        ["NAME:Selections", "Selections:=", ",".join(parts)],
        ["NAME:UniteParameters", "KeepOriginals:=", False])


def create_trace(name, points, width, thickness, color):
    # Axis-aligned PCB tracks are unions of overlapping rectangular prisms.
    # Square overlaps fill the complete corner, avoiding swept-profile notches.
    parts = []
    for i, (a, b) in enumerate(zip(points[:-1], points[1:])):
        if a == b:
            continue
        if abs(a[2]-b[2]) > 1e-9 or (abs(a[0]-b[0]) > 1e-9 and abs(a[1]-b[1]) > 1e-9):
            raise ValueError('PCB trace must be planar and axis-aligned: ' + name)
        part = name if not parts else name + '_segment_' + str(i)
        start_cap = width/2 if i > 0 else 0
        end_cap = width/2 if i < len(points)-2 else 0
        if abs(a[1]-b[1]) < 1e-9:
            low = min(a[0],b[0])-(start_cap if a[0]<b[0] else end_cap)
            origin = [low, a[1]-width/2, a[2]-thickness/2]
            size = [abs(b[0]-a[0])+start_cap+end_cap, width, thickness]
        else:
            low = min(a[1],b[1])-(start_cap if a[1]<b[1] else end_cap)
            origin = [a[0]-width/2, low, a[2]-thickness/2]
            size = [width, abs(b[1]-a[1])+start_cap+end_cap, thickness]
        create_box(part, origin, size,
                   'copper', color)
        parts.append(part)
    if len(parts)>1:
        unite(parts)
    return name

def create_swept_trace_unused(name, points, width, thickness, color):
    pts = ["NAME:PolylinePoints"]
    for x, y, z in points:
        pts.append(["NAME:PLPoint", "X:=", mm(x), "Y:=", mm(y), "Z:=", mm(z)])
    segs = ["NAME:PolylineSegments"]
    for i in range(len(points) - 1):
        segs.append(["NAME:PLSegment", "SegmentType:=", "Line",
                     "StartIndex:=", i, "NoOfPoints:=", 2])
    return oEditor.CreatePolyline(
        ["NAME:PolylineParameters", "IsPolylineCovered:=", True,
         "IsPolylineClosed:=", False, pts, segs,
         ["NAME:PolylineXSection", "XSectionType:=", "Rectangle",
          "XSectionOrient:=", "Auto", "XSectionWidth:=", mm(width),
          "XSectionTopWidth:=", mm(width), "XSectionHeight:=", mm(thickness),
          "XSectionNumSegments:=", "0", "XSectionBendType:=", "Corner"]],
        ["NAME:Attributes", "Name:=", name, "Flags:=", "", "Color:=", color,
         "Transparency:=", 0.0, "PartCoordinateSystem:=", "Global",
         "UDMId:=", "", "MaterialValue:=", '"copper"',
         "SurfaceMaterialValue:=", '""', "SolveInside:=", True,
         "ShellElement:=", False, "ShellElementThickness:=", "0mm",
         "IsMaterialEditable:=", True, "UseMaterialAppearance:=", False,
         "IsLightweight:=", False])


def create_via(name, x, y, first_layer, last_layer, diameter, color):
    """Copper blind via between the named layer centres (inclusive)."""
    z1 = layer_z[first_layer - 1]
    z2 = layer_z[last_layer - 1]
    z0 = min(z1-CU[first_layer-1]/2, z2-CU[last_layer-1]/2)
    height = max(z1+CU[first_layer-1]/2, z2+CU[last_layer-1]/2)-z0
    return oEditor.CreateCylinder(
        ["NAME:CylinderParameters", "XCenter:=", mm(x), "YCenter:=", mm(y),
         "ZCenter:=", mm(z0), "Radius:=", mm(diameter / 2.0),
         "Height:=", mm(height), "WhichAxis:=", "Z", "NumSides:=", "0"],
        ["NAME:Attributes", "Name:=", name, "Flags:=", "", "Color:=", color,
         "Transparency:=", 0.0, "PartCoordinateSystem:=", "Global",
         "UDMId:=", "", "MaterialValue:=", '"copper"',
         "SurfaceMaterialValue:=", '""', "SolveInside:=", True,
         "ShellElement:=", False, "ShellElementThickness:=", "0mm",
         "IsMaterialEditable:=", True, "UseMaterialAppearance:=", False,
         "IsLightweight:=", False])


def rectangular_spiral(cx, cy, turns, width, spacing, z, exit_side,
                       core_clearance=LEG_TO_COPPER):
    """Open rectangular spiral around one 7 x 14 mm core-leg slot."""
    pitch = width + spacing
    inner_x = LEG / 2.0 + core_clearance + width / 2.0
    inner_y = CORE_DEPTH / 2.0 + core_clearance + width / 2.0
    outer_x = inner_x + (turns - 1) * pitch
    outer_y = inner_y + (turns - 1) * pitch
    x_left, x_right = cx - outer_x, cx + outer_x
    y_bottom, y_top = cy - outer_y, cy + outer_y
    # Non-self-intersecting rectangular spiral, initially with a left exit.
    pts = [(x_left - 4.0, cy, z), (x_left, cy, z), (x_left, y_top, z)]
    for turn in range(turns):
        pts.extend([(x_right, y_top, z), (x_right, y_bottom, z)])
        if turn < turns - 1:
            pts.append((x_left + pitch, y_bottom, z))
            x_left += pitch
            x_right -= pitch
            y_bottom += pitch
            y_top -= pitch
            pts.append((x_left, y_top, z))
    if exit_side == "right":
        pts = [(2.0 * cx - x, y, zz) for x, y, zz in pts]
    return pts


def clearance_spiral(layer, name):
    """Four turns with concentric circular lower-right corners.

    A single semicircle would cross adjacent turns. Move all four right-hand
    sides together and use exact quarter-circle segments around the END via.
    The final turn ends at the bottom tangent, clear of the deeper END via.
    """
    z = layer_z[layer-1]
    cx = LEG_PITCH/2.0
    vx = cx + LEG/2 + SEC_LEG_TO_COPPER + S_WIDTH/2 - .95
    vy = -(CORE_DEPTH/2 + SEC_LEG_TO_COPPER + S_WIDTH/2)
    inner_radius = VIA_CLEARANCE + S_WIDTH + ARC_MARGIN
    pitch = S_WIDTH + TURN_SPACING
    ix = LEG/2 + SEC_LEG_TO_COPPER + S_WIDTH/2
    iy = CORE_DEPTH/2 + SEC_LEG_TO_COPPER + S_WIDTH/2
    outer_x = ix + (S_TURNS-1)*pitch
    points = [(cx+outer_x+4, 0, z)]
    segments = []
    def line(p):
        segments.append(('Line',len(points)-1,2))
        points.append(p)
    def arc(mid,end):
        segments.append(('Arc',len(points)-1,3))
        points.extend([mid,end])
    radius = inner_radius+(S_TURNS-1)*pitch
    line((vx+radius,0,z))
    for turn in range(S_TURNS):
        radius = inner_radius+(S_TURNS-1-turn)*pitch
        left = cx-(outer_x-turn*pitch)
        top = iy+(S_TURNS-1-turn)*pitch
        line((vx+radius,top,z))
        line((left,top,z))
        line((left,vy-radius,z))
        line((vx,vy-radius,z))
        if turn<S_TURNS-1:
            arc((vx+radius/math.sqrt(2),vy-radius/math.sqrt(2),z),
                (vx+radius,vy,z))
            line((vx+radius-pitch,vy,z))
    # Exact distance to the END via for each straight segment; arc distance
    # is its concentric radius. Also check the displaced deeper START via.
    def segment_distance(a,b,q):
        dx,dy=b[0]-a[0],b[1]-a[1]
        t=max(0,min(1,((q[0]-a[0])*dx+(q[1]-a[1])*dy)/(dx*dx+dy*dy)))
        return math.hypot(a[0]+t*dx-q[0],a[1]+t*dy-q[1])
    minima=[]
    for q in [(vx,vy),(28.0,3.0 if layer==2 else -3.0)]:
        distances=[]
        for kind,start,count in segments:
            if kind=='Line':
                distances.append(segment_distance(points[start],points[start+1],q))
            else:
                r=math.hypot(points[start][0]-vx,points[start][1]-vy)
                angle=math.atan2(q[1]-vy,q[0]-vx)
                if -math.pi/2<=angle<=0:
                    distances.append(abs(math.hypot(q[0]-vx,q[1]-vy)-r))
                else:
                    distances.append(min(math.hypot(points[j][0]-q[0],points[j][1]-q[1])
                                         for j in [start,start+2]))
        gap=min(distances)-S_WIDTH
        assert gap>=VIA_CLEARANCE-1e-8, ('Via clearance failed',layer,q,gap)
        minima.append(gap)
    assert min(p[1] for p in points)-S_WIDTH/2>=-BOARD_Y/2
    clearance_audit.append(dict(layer=layer,end_via_gap_mm=minima[0],
        start_via_gap_mm=minima[1],required_mm=VIA_CLEARANCE,
        endpoint_mm=points[-1],arc_centre_mm=[vx,vy],inner_radius_mm=inner_radius))
    # Boolean quarter-annuli avoid the AEDT swept-profile crossing-edge error.
    # These are exact circular copper solids, not a faceted approximation.
    parts=[]
    thickness=CU[layer-1]
    def cylinder(part,r):
        oEditor.CreateCylinder(['NAME:CylinderParameters','XCenter:=',mm(vx),
            'YCenter:=',mm(vy),'ZCenter:=',mm(z-thickness/2),'Radius:=',mm(r),
            'Height:=',mm(thickness),'WhichAxis:=','Z','NumSides:=','0'],
            ['NAME:Attributes','Name:=',part,'MaterialValue:=','"copper"',
             'SolveInside:=',True,'Color:=','(30 105 220)'])
    for i,(kind,start,count) in enumerate(segments):
        part=name if not parts else name+'_part_'+str(i)
        if kind=='Line':
            create_trace(part,points[start:start+2],S_WIDTH,thickness,'(30 105 220)')
        else:
            r=math.hypot(points[start][0]-vx,points[start][1]-vy)
            cylinder(part,r+S_WIDTH/2)
            cylinder(part+'_Hole',r-S_WIDTH/2)
            extent=2*(r+S_WIDTH)
            create_box(part+'_LeftCut',[vx-extent,vy-extent,z-thickness],
                [extent,2*extent,3*thickness],'vacuum','(255 255 255)')
            create_box(part+'_TopCut',[vx-extent,vy,z-thickness],
                [2*extent,extent,3*thickness],'vacuum','(255 255 255)')
            subtract(part,[part+'_Hole',part+'_LeftCut',part+'_TopCut'])
        parts.append(part)
    unite(parts)
    return points

# -----------------------------------------------------------------------------
# Material definitions
# -----------------------------------------------------------------------------
oDefinitionManager = oProject.GetDefinitionManager()
try:
    oDefinitionManager.AddMaterial(
        ["NAME:DMR53", "CoordinateSystemType:=", "Cartesian",
         "BulkOrSurfaceType:=", 1,
         ["NAME:PhysicsTypes", "set:=", ["Electromagnetic"]],
         "permeability:=", "900", "conductivity:=", "0",
         "mass_density:=", "4800kg_per_m3"])
except Exception:
    pass  # Material may already exist in the user library/project.

# -----------------------------------------------------------------------------
# Eight-layer PCB dielectric slabs and finished core-leg slots
# -----------------------------------------------------------------------------
z_bottom = -BOARD_T / 2.0
layer_z = []
z = z_bottom
for layer in range(1, 9):
    layer_z.append(z + CU[layer - 1] / 2.0)
    z += CU[layer - 1]
    if layer < 8:
        diel_name = "PCB_Diel_L{}_L{}".format(layer, layer + 1)
        create_box(diel_name, [-BOARD_X / 2, -BOARD_Y / 2, z],
                   [BOARD_X, BOARD_Y, DIEL[layer - 1]], "FR4_epoxy", "(110 160 80)")
        holes = []
        for idx, cx in enumerate([-LEG_PITCH / 2.0, LEG_PITCH / 2.0], 1):
            hname = "{}_SlotTool{}".format(diel_name, idx)
            create_box(hname, [cx - SLOT_X / 2, -SLOT_Y / 2, z - 0.01],
                       [SLOT_X, SLOT_Y, DIEL[layer - 1] + 0.02], "vacuum", "(255 255 255)")
            holes.append(hname)
        subtract(diel_name, holes)
        z += DIEL[layer - 1]

# -----------------------------------------------------------------------------
# Planar copper spirals: primary on left leg, outputs on right leg
# -----------------------------------------------------------------------------
primary_points = {}
secondary_points = {}

for layer, winding in PRIMARY_LAYERS.items():
    pts = rectangular_spiral(-LEG_PITCH / 2.0, 0.0, P_TURNS,
                             P_WIDTH, TURN_SPACING, layer_z[layer - 1], "left")
    # Complete the inner bottom edge toward the left yellow-circle position.
    # Stop before the inner-left vertical trace: via edge clearance is 0.30 mm.
    primary_inner_left = (-LEG_PITCH / 2.0 -
                          (LEG / 2.0 + LEG_TO_COPPER + P_WIDTH / 2.0))
    primary_end_via_x = primary_inner_left + P_WIDTH + 0.30
    pts.append((primary_end_via_x, pts[-1][1], pts[-1][2]))
    primary_points[layer] = pts
    create_trace("{}_L{}_3T".format(winding, layer), pts, P_WIDTH,
                 CU[layer - 1], "(220 55 35)")

for layer, winding in SECONDARY_LAYERS.items():
    if layer in (2,7):
        secondary_points[layer] = clearance_spiral(layer,"{}_L{}_4T".format(winding,layer))
        continue
    pts = rectangular_spiral(LEG_PITCH / 2.0, 0.0, S_TURNS,
                             S_WIDTH, TURN_SPACING, layer_z[layer - 1], "right",
                             SEC_LEG_TO_COPPER)
    # Offset the outer/start access for L3/L6 to clear the traversed layer.
    if layer == 3:
        pts.insert(0, (28.0,0,pts[0][2]))
        pts.insert(0, (28.0,3.0,pts[0][2]))
    elif layer == 6:
        pts.insert(0, (28.0,0,pts[0][2]))
        pts.insert(0, (28.0,-3.0,pts[0][2]))
    # Continue along the innermost bottom edge, without crossing any turns.
    # The deeper blind via is beyond the endpoint of the traversed layer.
    secondary_inner_right = (LEG_PITCH / 2.0 +
                             LEG / 2.0 + SEC_LEG_TO_COPPER + S_WIDTH / 2.0)
    via_x = secondary_inner_right - (2.45 if layer in (2, 7) else 0.95)
    pts.append((via_x, pts[-1][1], pts[-1][2]))
    secondary_points[layer] = pts
    create_trace("{}_L{}_4T".format(winding, layer), pts, S_WIDTH,
                 CU[layer - 1], "(30 105 220)")

# -----------------------------------------------------------------------------
# Legal blind vias and same-width surface breakout traces
# -----------------------------------------------------------------------------
# Primary L2/L3 are parallel. Two L1-L3 vias deliberately contact both layers
# at corresponding spiral endpoints; L1 carries the common start/end terminals.
p_start = primary_points[3][0]
p_end = primary_points[3][-1]
# The inner-end via stays inside the spiral. Cross the other turns only on L1.
p_end_via = (p_end[0], p_end[1], layer_z[0])
create_via("P12_START_VIA_L1_L3", p_start[0], p_start[1], 1, 3,
           P_WIDTH, "(220 55 35)")
create_via("P12_END_VIA_L1_L3", p_end_via[0], p_end_via[1], 1, 3,
           P_WIDTH, "(220 55 35)")
create_trace("PRI_START_BREAKOUT_L1",
             [(p_start[0], p_start[1], layer_z[0]), (-29.5, p_start[1], layer_z[0])],
             P_WIDTH, CU[0], "(220 55 35)")
# At the left yellow-circle via, change to L1, go down, then out to the left.
create_trace("PRI_END_BREAKOUT_L1",
             [(p_end_via[0], p_end_via[1], layer_z[0]),
              (-29.5, p_end_via[1], layer_z[0])],
             P_WIDTH, CU[0], "(220 55 35)")

# Each output stays isolated and receives two accessible surface terminals.
# S1: L2 -> L1; S2: L3 -> L1; S3: L6 -> L8; S4: L7 -> L8.
sec_access = {2: (1, 2), 3: (1, 3), 6: (6, 8), 7: (7, 8)}
sec_surface = {2: 1, 3: 1, 6: 8, 7: 8}
# Separate surface return lanes, with 0.20 mm copper-edge spacing.
sec_return_y = {2: -14.65, 3: -9.25, 6: -9.25, 7: -14.65}
for layer in (2, 3, 6, 7):
    pts = secondary_points[layer]
    start_pt, end_pt = pts[0], pts[-1]
    first_layer, last_layer = sec_access[layer]
    surface_layer = sec_surface[layer]
    create_via("S{}_START_VIA_L{}_L{}".format(layer, first_layer, last_layer),
               start_pt[0], start_pt[1], first_layer, last_layer, S_WIDTH,
               "(30 105 220)")
    end_via = (end_pt[0], end_pt[1], layer_z[surface_layer - 1])
    create_via("S{}_END_VIA_L{}_L{}".format(layer, first_layer, last_layer),
               end_via[0], end_via[1], first_layer, last_layer, S_WIDTH,
               "(30 105 220)")
    zsurf = layer_z[surface_layer - 1]
    create_trace("S{}_START_BREAKOUT_L{}".format(layer, surface_layer),
                 [(start_pt[0], start_pt[1], zsurf), (29.0, start_pt[1], zsurf)],
                 S_WIDTH, CU[surface_layer - 1], "(30 105 220)")
    # From the right yellow-circle vias, go down on L1/L8, then out right.
    # The nearer via uses the lower lane to avoid the farther via's return.
    create_trace("S{}_END_BREAKOUT_L{}".format(layer, surface_layer),
                 [(end_via[0],end_via[1],zsurf),
                  (end_via[0],sec_return_y[layer],zsurf),
                  (29.0,sec_return_y[layer],zsurf)],
                 S_WIDTH, CU[surface_layer - 1], "(30 105 220)")

# -----------------------------------------------------------------------------
# One solid per independent electrical winding
# -----------------------------------------------------------------------------
# P1 and P2 are intentionally paralleled by the two shared L1-L3 vias, so the
# complete primary is one electrical winding/solid.
unite(["P1_L2_3T", "P2_L3_3T",
       "P12_START_VIA_L1_L3", "P12_END_VIA_L1_L3",
       "PRI_START_BREAKOUT_L1", "PRI_END_BREAKOUT_L1"])

# The four outputs remain mutually isolated. Each Unite includes only its own
# spiral, two legal blind vias and its two surface breakout traces.
for layer, winding in SECONDARY_LAYERS.items():
    first_layer, last_layer = sec_access[layer]
    surface_layer = sec_surface[layer]
    unite(["{}_L{}_4T".format(winding, layer),
           "S{}_START_VIA_L{}_L{}".format(layer, first_layer, last_layer),
           "S{}_END_VIA_L{}_L{}".format(layer, first_layer, last_layer),
           "S{}_START_BREAKOUT_L{}".format(layer, surface_layer),
           "S{}_END_BREAKOUT_L{}".format(layer, surface_layer)])

# -----------------------------------------------------------------------------
# Upper and lower U cores. Joint is centred at Z=0 inside the PCB slots.
# -----------------------------------------------------------------------------
stem = U_HEIGHT - LEG
g2 = GAP_EACH_JOINT / 2.0
left_x = -CORE_LENGTH / 2.0
right_leg_x = CORE_LENGTH / 2.0 - LEG

upper = []
upper.append("Core_Upper_Yoke")
create_box(upper[-1], [left_x, -CORE_DEPTH / 2, g2 + stem],
           [CORE_LENGTH, CORE_DEPTH, LEG], "DMR53", "(65 70 78)")
for name, x in [("Core_Upper_Leg_P", left_x), ("Core_Upper_Leg_S", right_leg_x)]:
    upper.append(name)
    create_box(name, [x, -CORE_DEPTH / 2, g2], [LEG, CORE_DEPTH, stem], "DMR53", "(65 70 78)")

lower = []
lower.append("Core_Lower_Yoke")
create_box(lower[-1], [left_x, -CORE_DEPTH / 2, -g2 - U_HEIGHT],
           [CORE_LENGTH, CORE_DEPTH, LEG], "DMR53", "(65 70 78)")
for name, x in [("Core_Lower_Leg_P", left_x), ("Core_Lower_Leg_S", right_leg_x)]:
    lower.append(name)
    create_box(name, [x, -CORE_DEPTH / 2, -g2 - stem], [LEG, CORE_DEPTH, stem],
               "DMR53", "(65 70 78)")

# Explicit nonmagnetic joint gaps. Each joint is 52.554 um; a closed U-U
# magnetic path crosses both joints, giving approximately 0.1051 mm total gap.
create_box("AirGap_PrimaryLeg_0p052554mm", [left_x, -CORE_DEPTH / 2, -g2],
           [LEG, CORE_DEPTH, GAP_EACH_JOINT], "vacuum", "(210 235 255)")
create_box("AirGap_SecondaryLeg_0p052554mm", [right_leg_x, -CORE_DEPTH / 2, -g2],
           [LEG, CORE_DEPTH, GAP_EACH_JOINT], "vacuum", "(210 235 255)")

# Add the Maxwell air region after terminal/polarity review. Avoid creating an
# overlapping ordinary vacuum solid here because it can hide geometry errors.
oEditor.FitAll()

# Save beside the script when AEDT exposes the project path through the UI.
if list(oEditor.GetObjectsInGroup('Unclassified')):
    raise RuntimeError('Invalid geometry: inspect arc sweep before saving')
output_dir=os.path.join(os.path.dirname(os.path.abspath(__file__)),'output')
oProject.SaveAs(os.path.join(output_dir,'LLC_Rectangular_7x14_ViaClearance3p6_Geometry.aedt'), True)
with open(os.path.join(output_dir,'LLC_Rectangular_7x14_ViaClearance3p6_audit.json'),'w') as stream:
    json.dump(clearance_audit,stream,indent=2)
print("AEDT model created: U height {:.6f} mm, core-to-PCB {:.3f} mm, each gap {:.6f} mm.".format(
    U_HEIGHT, CORE_TO_PCB_SURFACE, GAP_EACH_JOINT))

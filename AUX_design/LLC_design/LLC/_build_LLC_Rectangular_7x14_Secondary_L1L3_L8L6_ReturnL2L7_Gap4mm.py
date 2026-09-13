"""Build the planar LLC transformer in Ansys Electronics Desktop 2024 R2.

For a complete build with solver configuration, run
``build_and_configure_llc_aedt.py``.  Run this geometry-only script directly
inside AEDT only when solver settings are not wanted.
Geometry units are millimetres. Blind-via access is limited to L1-L2/L1-L3
for primary; secondary inner ends use adjacent-layer vias to L2/L7.
"""
import ScriptEnv
import os

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
SECONDARY_COLORS = {'S1': '(0 114 189)', 'S2': '(217 83 25)', 'S3': '(237 177 32)', 'S4': '(126 47 142)'}
PRIMARY_LAYERS = {2: "P1", 3: "P2"}
SECONDARY_LAYERS = {1: "S1", 3: "S2", 6: "S3", 8: "S4"}


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
    z0 = min(z1 - CU[first_layer - 1] / 2.0, z2 - CU[last_layer - 1] / 2.0)
    height = abs(z2 - z1) + (CU[first_layer - 1] + CU[last_layer - 1]) / 2.0
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

# Each spiral starts outside on its own layer. Only its inner end changes layer.
for layer, winding in SECONDARY_LAYERS.items():
    pts = rectangular_spiral(LEG_PITCH / 2.0, 0.0, S_TURNS,
                             S_WIDTH, TURN_SPACING, layer_z[layer - 1], "right",
                             SEC_LEG_TO_COPPER)
    # Complete the fourth inner edge; retain 0.25 mm to the adjacent turn.
    via_x = LEG_PITCH / 2.0 + LEG / 2.0 + SEC_LEG_TO_COPPER + S_WIDTH / 2.0 - 0.95
    pts.append((via_x, pts[-1][1], pts[-1][2]))
    if layer in (3, 6):
        pts = [(x, -y, z) for x, y, z in pts]
    secondary_points[layer] = pts
    create_trace("{}_L{}_4T".format(winding, layer), pts, S_WIDTH,
                 CU[layer - 1], SECONDARY_COLORS[winding])

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

# Adjacent-layer inner-end vias only: L1-L2, L2-L3, L6-L7, L7-L8.
sec_surface = {1: 2, 3: 2, 6: 7, 8: 7}
sec_return_y = {}
for layer, winding in SECONDARY_LAYERS.items():
    start_pt, end_pt = secondary_points[layer][0], secondary_points[layer][-1]
    target = sec_surface[layer]
    first, last = min(layer, target), max(layer, target)
    create_via(winding + "_END_VIA", end_pt[0], end_pt[1], first, last,
               S_WIDTH, SECONDARY_COLORS[winding])
    create_trace(winding + "_START_LEAD",
                 [start_pt, (29.0, start_pt[1], start_pt[2])],
                 S_WIDTH, CU[layer - 1], SECONDARY_COLORS[winding])
    sec_return_y[layer] = end_pt[1]
    zout = layer_z[target - 1]
    create_trace(winding + "_RETURN_LEAD",
                 [(end_pt[0], end_pt[1], zout), (29.0, end_pt[1], zout)],
                 S_WIDTH, CU[target - 1], SECONDARY_COLORS[winding])

# -----------------------------------------------------------------------------
# One solid per independent electrical winding
# -----------------------------------------------------------------------------
# P1 and P2 are intentionally paralleled by the two shared L1-L3 vias, so the
# complete primary is one electrical winding/solid.
unite(["P1_L2_3T", "P2_L3_3T",
       "P12_START_VIA_L1_L3", "P12_END_VIA_L1_L3",
       "PRI_START_BREAKOUT_L1", "PRI_END_BREAKOUT_L1"])

for layer, winding in SECONDARY_LAYERS.items():
    unite(["{}_L{}_4T".format(winding, layer), winding + "_END_VIA",
           winding + "_START_LEAD", winding + "_RETURN_LEAD"])

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
oProject.SaveAs(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'output', 'LLC_Rectangular_7x14_Secondary_L1L3_L8L6_ReturnL2L7_Gap4mm_Geometry.aedt'), True)
print("AEDT model created: U height {:.6f} mm, core-to-PCB {:.3f} mm, each gap {:.6f} mm.".format(
    U_HEIGHT, CORE_TO_PCB_SURFACE, GAP_EACH_JOINT))

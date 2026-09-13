"""Build the current 48:4:3 Scheme-B flyback geometry in AEDT 2024 R2.

P: 12 turns on L2 and L3 around each U leg; four coils in series aiding.
S: 4 turns on L6/L7/L8 around the right leg; three layers in parallel.
AUX: 2 turns on L6 + 1 turn on L7 around the left leg, in series.
The AUX radial band is centred within the primary copper-edge breadth.

This creates connected copper geometry and vias. Maxwell excitations and a
solution setup are intentionally left for the later leakage/excitation step.
"""
import ScriptEnv
import json
import math
import os

ScriptEnv.Initialize("Ansoft.ElectronicsDesktop")
oDesktop.RestoreWindow()
oProject = oDesktop.NewProject()
oProject.InsertDesign("Maxwell 3D", "Flyback_48_4_3_B_100kHz", "EddyCurrent", "")
oDesign = oProject.SetActiveDesign("Flyback_48_4_3_B_100kHz")
oEditor = oDesign.SetActiveEditor("3D Modeler")
oEditor.SetModelUnits(["NAME:Units Parameter", "Units:=", "mm", "Rescale:=", False])

# MATLAB-selected Scheme-B geometry.
NP = 48
NS = 4
NAUX = 3
FREQ_HZ = 100000.0
LM_H = 2.3e-3
LEG = 16.0
CORE_DEPTH = 16.0
CORE_LENGTH = 47.2
LEG_PITCH = 31.2
BOARD_X = 68.0
BOARD_Y = 63.0
CU = [0.069, 0.064, 0.064, 0.064, 0.064, 0.064, 0.064, 0.069]
DIEL = [0.346, 0.406, 0.393, 0.406, 0.406, 0.406, 0.360]
BOARD_T = sum(CU) + sum(DIEL)
GAP_EACH = 0.1452767185
CORE_TO_PCB = 1.0
HALF_HEIGHT = LEG + BOARD_T / 2.0 + CORE_TO_PCB - GAP_EACH / 2.0
STEM = HALF_HEIGHT - LEG
LEFT_CX = -LEG_PITCH / 2.0
RIGHT_CX = LEG_PITCH / 2.0

P_TURNS = 12
P_WIDTH = 0.20
S_TURNS = 4
S_WIDTH = 1.00
AUX_TURNS = {6: 2, 7: 1}
AUX_WIDTH = 0.20
SPACING = 0.20
CORE_TO_COPPER = 2.00
P_RADIAL_BREADTH = P_TURNS * P_WIDTH + (P_TURNS - 1) * SPACING
AUX_LEFT_TRACE_X = LEFT_CX - (LEG / 2.0 + CORE_TO_COPPER + P_RADIAL_BREADTH / 2.0)

P_COLOR = "(220 50 30)"
S_COLOR = "(25 90 220)"
A_COLOR = "(0 150 65)"
CORE_COLOR = "(120 125 135)"
geometry_boxes = []
trace_paths = []
via_records = []


def mm(value):
    return "{:.9f}mm".format(float(value))


def create_box(name, origin, size, material, color, transparency=0.0):
    geometry_boxes.append(dict(name=name, origin=list(origin), size=list(size), material=material))
    return oEditor.CreateBox(
        ["NAME:BoxParameters", "XPosition:=", mm(origin[0]),
         "YPosition:=", mm(origin[1]), "ZPosition:=", mm(origin[2]),
         "XSize:=", mm(size[0]), "YSize:=", mm(size[1]), "ZSize:=", mm(size[2])],
        ["NAME:Attributes", "Name:=", name, "Flags:=", "", "Color:=", color,
         "Transparency:=", transparency, "PartCoordinateSystem:=", "Global",
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
    if len(parts) > 1:
        oEditor.Unite(
            ["NAME:Selections", "Selections:=", ",".join(parts)],
            ["NAME:UniteParameters", "KeepOriginals:=", False])


def create_trace(name, points, width, thickness, color):
    """Create an axis-aligned planar trace from overlapping copper boxes."""
    trace_paths.append(dict(name=name, points=points, width_mm=width, thickness_mm=thickness))
    parts = []
    for i, pair in enumerate(zip(points[:-1], points[1:])):
        a, b = pair
        if a == b:
            continue
        if abs(a[2] - b[2]) > 1e-9:
            raise ValueError("Non-planar trace segment: " + name)
        if abs(a[0] - b[0]) > 1e-9 and abs(a[1] - b[1]) > 1e-9:
            raise ValueError("Non-orthogonal trace segment: " + name)
        part = name if not parts else name + "_segment_" + str(i)
        start_cap = width / 2.0 if i > 0 else 0.0
        end_cap = width / 2.0 if i < len(points) - 2 else 0.0
        if abs(a[1] - b[1]) < 1e-9:
            low = min(a[0], b[0]) - (start_cap if a[0] < b[0] else end_cap)
            origin = [low, a[1] - width / 2.0, a[2] - thickness / 2.0]
            size = [abs(b[0] - a[0]) + start_cap + end_cap, width, thickness]
        else:
            low = min(a[1], b[1]) - (start_cap if a[1] < b[1] else end_cap)
            origin = [a[0] - width / 2.0, low, a[2] - thickness / 2.0]
            size = [width, abs(b[1] - a[1]) + start_cap + end_cap, thickness]
        create_box(part, origin, size, "copper", color)
        parts.append(part)
    if not parts:
        raise ValueError("Empty trace: " + name)
    unite(parts)
    return name


def create_via(name, x, y, first_layer, last_layer, diameter, color):
    indices = [first_layer - 1, last_layer - 1]
    bottom = min(layer_z[i] - CU[i] / 2.0 for i in indices)
    top = max(layer_z[i] + CU[i] / 2.0 for i in indices)
    via_records.append(dict(name=name, x=x, y=y, first_layer=first_layer, last_layer=last_layer))
    geometry_boxes.append(dict(name=name, origin=[x-diameter/2, y-diameter/2, bottom],
                               size=[diameter,diameter,top-bottom],material="copper"))
    return oEditor.CreateCylinder(
        ["NAME:CylinderParameters", "XCenter:=", mm(x), "YCenter:=", mm(y),
         "ZCenter:=", mm(bottom), "Radius:=", mm(diameter / 2.0),
         "Height:=", mm(top - bottom), "WhichAxis:=", "Z", "NumSides:=", "0"],
        ["NAME:Attributes", "Name:=", name, "Flags:=", "", "Color:=", color,
         "Transparency:=", 0.0, "PartCoordinateSystem:=", "Global",
         "UDMId:=", "", "MaterialValue:=", '"copper"',
         "SurfaceMaterialValue:=", '""', "SolveInside:=", True,
         "ShellElement:=", False, "ShellElementThickness:=", "0mm",
         "IsMaterialEditable:=", True, "UseMaterialAppearance:=", False,
         "IsLightweight:=", False])


def create_post(name, x, y, top_layer, diameter, z_bus, bus_thickness, color):
    bottom = z_bus - bus_thickness / 2.0
    top = layer_z[top_layer - 1] + CU[top_layer - 1] / 2.0
    geometry_boxes.append(dict(name=name, origin=[x-diameter/2,y-diameter/2,bottom],
                               size=[diameter,diameter,top-bottom],material="copper"))
    return oEditor.CreateCylinder(
        ["NAME:CylinderParameters", "XCenter:=", mm(x), "YCenter:=", mm(y),
         "ZCenter:=", mm(bottom), "Radius:=", mm(diameter / 2.0),
         "Height:=", mm(top - bottom), "WhichAxis:=", "Z", "NumSides:=", "0"],
        ["NAME:Attributes", "Name:=", name, "Flags:=", "", "Color:=", color,
         "Transparency:=", 0.0, "PartCoordinateSystem:=", "Global",
         "UDMId:=", "", "MaterialValue:=", '"copper"',
         "SurfaceMaterialValue:=", '""', "SolveInside:=", True])


def centred_spiral(cx, turns, width, spacing, z, clearance, polarity=1):
    """Open square spiral with outer and inner terminals on the -Y centreline."""
    pitch = width + spacing
    inner = LEG / 2.0 + clearance + width / 2.0
    outer = inner + (turns - 1) * pitch
    pts = [(cx, -(outer + pitch), z)]
    for turn in range(turns):
        r = outer - turn * pitch
        pts.extend([(cx + r, -(r + pitch), z), (cx + r, r, z), (cx - r, r, z)])
        if turn < turns - 1:
            pts.append((cx - r, -r, z))
        else:
            pts.extend([(cx - r, -r, z), (cx, -r, z)])
    if polarity < 0:
        pts = [(2.0 * cx - x, y, zz) for x, y, zz in pts]
    return pts


def reverse_pair_layer(points, cx):
    """Reverse current traversal while preserving the pair's winding polarity."""
    return [(2.0 * cx - x, y, z) for x, y, z in reversed(points)]


# Material definition.
dm = oProject.GetDefinitionManager()
try:
    dm.AddMaterial(["NAME:TPG33", "CoordinateSystemType:=", "Cartesian",
                    "BulkOrSurfaceType:=", 1,
                    ["NAME:PhysicsTypes", "set:=", ["Electromagnetic"]],
                    "permeability:=", "3300", "conductivity:=", "0"])
except Exception:
    pass

# PCB stack: L1 is the top copper layer.
layer_z = []
z = BOARD_T / 2.0
dielectric_names = []
for i, thickness in enumerate(CU):
    layer_z.append(z - thickness / 2.0)
    z -= thickness
    if i < 7:
        d = DIEL[i]
        name = "PCB_Diel_L{}_L{}".format(i + 1, i + 2)
        create_box(name, [-BOARD_X / 2.0, -BOARD_Y / 2.0, z - d],
                   [BOARD_X, BOARD_Y, d], "FR4_epoxy", "(100 145 85)", 0.9)
        holes = []
        for label, cx in [("Left", LEFT_CX), ("Right", RIGHT_CX)]:
            hname = name + "_Cut_" + label
            create_box(hname, [cx - LEG / 2.0 - 0.3, -LEG / 2.0 - 0.3, z - d - 0.01],
                       [LEG + 0.6, LEG + 0.6, d + 0.02], "vacuum", "(255 255 255)")
            holes.append(hname)
        subtract(name, holes)
        dielectric_names.append(name)
        z -= d

# U-U core halves and explicit joint gaps.
g2 = GAP_EACH / 2.0
left_x = -CORE_LENGTH / 2.0
right_leg_x = CORE_LENGTH / 2.0 - LEG
for tag, sign in [("Upper", 1), ("Lower", -1)]:
    yoke_z = g2 + STEM if sign > 0 else -g2 - HALF_HEIGHT
    leg_z = g2 if sign > 0 else -g2 - STEM
    parts = ["Core_{}_Yoke".format(tag)]
    create_box(parts[0], [left_x, -CORE_DEPTH / 2.0, yoke_z],
               [CORE_LENGTH, CORE_DEPTH, LEG], "TPG33", CORE_COLOR)
    for label, x in [("Left", left_x), ("Right", right_leg_x)]:
        name = "Core_{}_{}Leg".format(tag, label)
        create_box(name, [x, -CORE_DEPTH / 2.0, leg_z],
                   [LEG, CORE_DEPTH, STEM], "TPG33", CORE_COLOR)
        parts.append(name)
    unite(parts)
for label, x in [("Left", left_x), ("Right", right_leg_x)]:
    gap_tag = ("{:.6f}".format(GAP_EACH)).replace(".", "p")
    create_box("AirGap_{}Leg_{}mm".format(label, gap_tag),
               [x, -CORE_DEPTH / 2.0, -g2], [LEG, CORE_DEPTH, GAP_EACH],
               "vacuum", "(200 225 255)", 0.6)

# Four primary coils connected in series. Opposite leg polarity is deliberate.
primary_parts = []
primary_info = []
primary_points = {}
for label, cx, polarity in [("Left", LEFT_CX, 1), ("Right", RIGHT_CX, -1)]:
    if label == "Left":
        p2 = centred_spiral(cx, P_TURNS, P_WIDTH, SPACING, layer_z[1], CORE_TO_COPPER, polarity)
        p3 = reverse_pair_layer(centred_spiral(cx, P_TURNS, P_WIDTH, SPACING,
                                             layer_z[2], CORE_TO_COPPER, polarity), cx)
        inner = p2[-1]
    else:
        p3 = centred_spiral(cx, P_TURNS, P_WIDTH, SPACING, layer_z[2], CORE_TO_COPPER, polarity)
        p2 = reverse_pair_layer(centred_spiral(cx, P_TURNS, P_WIDTH, SPACING,
                                             layer_z[1], CORE_TO_COPPER, polarity), cx)
        # Enter directly at the outer lower-left corner, not at leg centre.
        p3 = p3[1:]
        inner = p3[-1]
    primary_points[(label, 2)] = p2
    primary_points[(label, 3)] = p3
    for layer, pts in [(2, p2), (3, p3)]:
        name = "Primary_{}_L{}_12T".format(label, layer)
        create_trace(name, pts, P_WIDTH, CU[layer - 1], P_COLOR)
        primary_parts.append(name)
        primary_info.append(dict(name=name, layer=layer, turns=P_TURNS,
                                 width_mm=P_WIDTH, start_mm=pts[0], end_mm=pts[-1]))
    vname = "Primary_{}_SeriesVia_L2_L3".format(label)
    create_via(vname, inner[0], inner[1], 2, 3, P_WIDTH, P_COLOR)
    primary_parts.append(vname)

# Direct L3 bridge: left inside-out -> right outside-in, no additional vias.
create_trace("Primary_InterLeg_Bridge_L3", [primary_points[("Left",3)][-1],
             primary_points[("Right",3)][0]], P_WIDTH, CU[2], P_COLOR)
primary_parts.append("Primary_InterLeg_Bridge_L3")

# Accessible primary terminals on L1.
p_start = primary_points[("Left", 2)][0]
p_end = primary_points[("Right", 2)][-1]
create_via("Primary_START_Via_L1_L2", p_start[0], p_start[1], 1, 2, P_WIDTH, P_COLOR)
create_via("Primary_END_Via_L1_L2", p_end[0], p_end[1], 1, 2, P_WIDTH, P_COLOR)
create_trace("Primary_START_Breakout_L1", [(p_start[0], p_start[1], layer_z[0]),
             (p_start[0], -BOARD_Y/2, layer_z[0])], P_WIDTH, CU[0], P_COLOR)
create_trace("Primary_END_Breakout_L1", [(p_end[0], p_end[1], layer_z[0]),
             (p_end[0], -BOARD_Y/2, layer_z[0])], P_WIDTH, CU[0], P_COLOR)
primary_parts.extend(["Primary_START_Via_L1_L2", "Primary_END_Via_L1_L2",
                      "Primary_START_Breakout_L1", "Primary_END_Breakout_L1"])
unite(primary_parts)

# Three parallel 4-turn secondary layers around the right leg.
secondary_parts = []
secondary_points = {}
for layer in (6, 7, 8):
    pts = centred_spiral(RIGHT_CX, S_TURNS, S_WIDTH, SPACING,
                         layer_z[layer - 1], CORE_TO_COPPER, 1)
    # Rotate 180 degrees: both access sites face +Y, with polarity preserved.
    pts = [(2*RIGHT_CX-x, -y, z) for x,y,z in pts]
    name = "Secondary_Right_L{}_4T".format(layer)
    create_trace(name, pts, S_WIDTH, CU[layer - 1], S_COLOR)
    secondary_parts.append(name)
    secondary_points[layer] = pts

# Shared blind vias create 4T || 4T || 4T. External bridges are below PCB.
s_bus_w = S_WIDTH  # same-width leads: no enlarged copper terminal plates
s_bus_t = 0.069
s_bus_z = -BOARD_T / 2.0 - 0.50 - s_bus_t / 2.0
s_terminals = []
for label, point, neck_x, lane_y in [
        ("START", secondary_points[6][0], RIGHT_CX+2.0, BOARD_Y/2),
        ("END", secondary_points[6][-1], RIGHT_CX-2.0, BOARD_Y/2)]:
    vname = "Secondary_{}_Via_L6_L8".format(label)
    create_via(vname, point[0], point[1], 6, 8, S_WIDTH, S_COLOR)
    secondary_parts.append(vname)
    post = "Secondary_{}_BridgePost".format(label)
    create_post(post, point[0], point[1], 8, S_WIDTH, s_bus_z, s_bus_t, S_COLOR)
    secondary_parts.append(post)
    neck = "Secondary_{}_BridgeNeck".format(label)
    create_trace(neck, [(point[0], point[1], s_bus_z),
                 (neck_x, point[1], s_bus_z), (neck_x, lane_y, s_bus_z)],
                 S_WIDTH, s_bus_t, S_COLOR)
    secondary_parts.append(neck)
    s_terminals.append(dict(label=label, centre_mm=[neck_x, lane_y, s_bus_z],
                            width_mm=s_bus_w))
unite(secondary_parts)

# AUX at the middle of the primary radial band. Left conductor locations are
# Left conductor locations follow the computed primary radial-band midpoint.
aux_parts = []
aux_info = []
radial_centre = abs(AUX_LEFT_TRACE_X - LEFT_CX)
l6_inner_radius = radial_centre - (AUX_WIDTH + SPACING) / 2.0
l6_clearance = l6_inner_radius - LEG / 2.0 - AUX_WIDTH / 2.0
l7_clearance = radial_centre - LEG / 2.0 - AUX_WIDTH / 2.0
a6 = centred_spiral(LEFT_CX, 2, AUX_WIDTH, SPACING, layer_z[5], l6_clearance, 1)
a7_base = centred_spiral(LEFT_CX, 1, AUX_WIDTH, SPACING, layer_z[6], l7_clearance, 1)
# Reverse L7 for series aiding and extend its start to the natural L6 endpoint.
series_y = a6[-1][1]
a7 = reverse_pair_layer(a7_base, LEFT_CX)
a7 = [(LEFT_CX, series_y, layer_z[6]), a7[0]] + a7[1:]
# Separate the two surface-access vias so neither via shorts the other layer.
a6 = [(LEFT_CX - 2.0, -15.0, layer_z[5]),
      (LEFT_CX - 2.0, a6[0][1], layer_z[5])] + a6[1:]
a7.append((LEFT_CX + 2.0, a7[-1][1], layer_z[6]))
a7.append((LEFT_CX + 2.0, -16.0, layer_z[6]))
for layer, pts, turns in [(6, a6, 2), (7, a7, 1)]:
    name = "AUX_Left_L{}_{}T".format(layer, turns)
    create_trace(name, pts, AUX_WIDTH, CU[layer - 1], A_COLOR)
    aux_parts.append(name)
    aux_info.append(dict(name=name, layer=layer, turns=turns,
                         width_mm=AUX_WIDTH, start_mm=pts[0], end_mm=pts[-1]))
create_via("AUX_SeriesVia_L6_L7", LEFT_CX, series_y, 6, 7,
           AUX_WIDTH, A_COLOR)
aux_parts.append("AUX_SeriesVia_L6_L7")
for label, point, first_layer in [("START", a6[0], 6), ("END", a7[-1], 7)]:
    vname = "AUX_{}_Via_L{}_L8".format(label, first_layer)
    create_via(vname, point[0], point[1], first_layer, 8, AUX_WIDTH, A_COLOR)
    aux_parts.append(vname)
    trace = "AUX_{}_Breakout_L8".format(label)
    create_trace(trace, [(point[0], point[1], layer_z[7]),
                 (point[0], -BOARD_Y/2, layer_z[7])], AUX_WIDTH, CU[7], A_COLOR)
    aux_parts.append(trace)
unite(aux_parts)

# Check every copper segment and via against both legs AND both yokes.
# Bounding boxes are exact for trace prisms, conservative for circular vias.
core_boxes = [b for b in geometry_boxes if b["material"] == "TPG33"]
copper_boxes = [b for b in geometry_boxes if b["material"] == "copper"]
def overlaps(a, b):
    return all(min(a["origin"][i]+a["size"][i],b["origin"][i]+b["size"][i]) -
               max(a["origin"][i],b["origin"][i]) > 1e-8 for i in range(3))
for copper in copper_boxes:
    for core in core_boxes:
        if overlaps(copper,core):
            raise RuntimeError("Copper intersects core: " + copper["name"] + " / " + core["name"])
    for other in copper_boxes:
        if copper["name"].split("_")[0] != other["name"].split("_")[0] and overlaps(copper,other):
            raise RuntimeError("Different windings intersect: " + copper["name"] + " / " + other["name"])

# Remove all connected copper volumes from the dielectric solids.
for name in dielectric_names:
    oEditor.Subtract(
        ["NAME:Selections", "Blank Parts:=", name,
         "Tool Parts:=", "Primary_Left_L2_12T,Secondary_Right_L6_4T,AUX_Left_L6_2T"],
        ["NAME:SubtractParameters", "KeepOriginals:=", True])

oEditor.FitAll()
unclassified = list(oEditor.GetObjectsInGroup("Unclassified"))
if unclassified:
    raise RuntimeError("Invalid geometry objects: " + ",".join(unclassified))
solids = list(oEditor.GetObjectsInGroup("Solids"))
required = ["Primary_Left_L2_12T", "Secondary_Right_L6_4T", "AUX_Left_L6_2T",
            "Core_Upper_Yoke", "Core_Lower_Yoke"]
missing = [name for name in required if name not in solids]
if missing:
    raise RuntimeError("Missing final solids: " + ",".join(missing))
for merged in ["Primary_Left_L3_12T", "Primary_Right_L2_12T", "Primary_Right_L3_12T",
               "Secondary_Right_L7_4T", "Secondary_Right_L8_4T", "AUX_Left_L7_1T"]:
    if merged in solids:
        raise RuntimeError("Copper union incomplete: " + merged)

output = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output", "48_4_3")
if not os.path.isdir(output):
    os.makedirs(output)
project = os.path.join(output, "Flyback_48_4_3_Scheme_B_AUX_Xm28_RoutingV3_100kHz.aedt")
oProject.SaveAs(project, True)
metadata = dict(
    project=project,
    design="Flyback_48_4_3_B_100kHz",
    turns_ratio=[NP, NS, NAUX],
    frequency_Hz=FREQ_HZ,
    target_Lm_H=LM_H,
    core_type="UU",
    core_size_mm=[CORE_LENGTH, CORE_DEPTH, 2 * HALF_HEIGHT + GAP_EACH],
    leg_centres_mm=[LEFT_CX, RIGHT_CX],
    gap_each_mm=GAP_EACH,
    pcb_size_mm=[BOARD_X, BOARD_Y, BOARD_T],
    primary=dict(connection="four coils series aiding", layers=[2, 3],
                 sequence="L1 IN -> left L2 outer-inner -> left L3 inner-outer -> L3 bridge -> right L3 outer-inner -> right L2 inner-outer -> L1 OUT",
                 turns_per_leg_per_layer=P_TURNS, width_mm=P_WIDTH,
                 coils=primary_info),
    secondary=dict(connection="4T || 4T || 4T", layers=[6, 7, 8],
                   turns_per_layer=S_TURNS, width_mm=S_WIDTH,
                   terminals=s_terminals),
    aux=dict(connection="L6 2T + L7 1T series", layers=[6, 7],
             turns=[2, 1], width_mm=AUX_WIDTH,
             left_conductor_mean_x_mm=AUX_LEFT_TRACE_X, coils=aux_info),
    nearest_interleg_copper_gap_mm=2.0,
    terminal_sides=dict(primary="-Y bottom on L1",aux="-Y bottom on L8",secondary="+Y top; 1 mm leads below PCB"),
    validation=dict(copper_core_intersections=0, different_winding_intersections=0),
    traces=trace_paths, vias=via_records,
    stage="connected geometry; Maxwell coil excitations and solution setup not assigned")
with open(os.path.join(output, "Flyback_48_4_3_Scheme_B_AUX_Xm28_RoutingV3_geometry.json"), "w") as stream:
    json.dump(metadata, stream, indent=2)

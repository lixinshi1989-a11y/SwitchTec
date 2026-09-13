"""Build only Flyback scheme C EE geometry in AEDT; no solver excitation yet.
Primary L2/L3 spirals are series-connected by an inner L1-L3 blind via.
Secondary L6/L7/L8 are paralleled using blind vias and off-board copper bridges.
AUX L4/L5 are series-connected; solver configuration is a separate step.
"""
import ScriptEnv
import os
import math
import json
ScriptEnv.Initialize("Ansoft.ElectronicsDesktop")
oProject=oDesktop.NewProject()
oProject.InsertDesign("Maxwell 3D","Flyback_C_EE_100kHz","EddyCurrent","")
oDesign=oProject.SetActiveDesign("Flyback_C_EE_100kHz")
oEditor=oDesign.SetActiveEditor("3D Modeler")
oEditor.SetModelUnits(["NAME:Units Parameter","Units:=","mm","Rescale:=",False])
LEG=24.0
LEG_TO_COPPER=2.0
CU=[.069,.064,.064,.064,.064,.064,.064,.069]
DIEL=[.346,.406,.393,.406,.406,.406,.360]
BOARD_T=sum(CU)+sum(DIEL)
DEPTH=24.0
LENGTH=70.0
YOKE=12.0
OUTER=12.0
WINDOW=11.0
CLEARANCE=1.0
mu0=4*math.pi*1e-7
mur=3300.0
Ac=24*24*1e-6
Ao=12*24*1e-6
Ay=12*24*1e-6
h0=YOKE+BOARD_T/2+CLEARANCE
vertical0=2*(h0-YOKE/2)*1e-3
pitch=29e-3
r0=vertical0/(mu0*mur*Ac)+(vertical0/(mu0*mur*Ao)+2*pitch/(mu0*mur*Ay))/2
g=(36.0**2/.0023-r0)/((1/(mu0*Ac)+1/(2*mu0*Ao))*(1-1/mur))
GAP=g*1e3
HEIGHT=h0-GAP/2
STEM=HEIGHT-YOKE
geometry_boxes=[]
def mm(value):
    return "{:.6f}mm".format(float(value))


def create_box(name, origin, size, material, color):
    geometry_boxes.append(dict(name=name,origin=origin,size=size,material=material))
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


def rectangular_spiral(cx, cy, turns, width, spacing, z, exit_side,
                       core_clearance=LEG_TO_COPPER):
    """Open rectangular spiral around the 24 x 24 mm core leg."""
    pitch = width + spacing
    inner = LEG / 2.0 + core_clearance + width / 2.0
    outer = inner + (turns - 1) * pitch
    x_left, x_right = cx - outer, cx + outer
    y_bottom, y_top = cy - outer, cy + outer
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


def centred_secondary_spiral(turns, width, spacing, z):
    """Full turns with both endpoints on the positive-Y centre line.

    Contract on the upper-left side, leaving the top-centre access sites
    clear of adjacent turns. Both layers use identical winding polarity.
    """
    pitch = width + spacing
    inner = LEG / 2.0 + LEG_TO_COPPER + width / 2.0
    outer = inner + (turns - 1) * pitch
    # Reserve one extra pitch above the core for the spiral's top transition;
    # otherwise the final return would close/short the innermost turn.
    pts = [(0.0, outer + pitch, z)]
    for turn in range(turns):
        r = outer - turn * pitch
        pts.extend([(r, r + pitch, z), (r, -r, z), (-r, -r, z)])
        if turn < turns - 1:
            pts.append((-r, r, z))
        else:
            pts.extend([(-r, r, z), (0.0, r, z)])
    return pts


def create_via(name, x, y, first_layer, last_layer, diameter, color):
    # Use the actual copper faces: Flyback L1 is at +Z, unlike the LLC file.
    layers = (first_layer - 1, last_layer - 1)
    bottom = min(layer_z[i] - CU[i]/2 for i in layers)
    top = max(layer_z[i] + CU[i]/2 for i in layers)
    geometry_boxes.append(dict(name=name,origin=[x-diameter/2,y-diameter/2,bottom],
        size=[diameter,diameter,top-bottom],material='copper'))
    oEditor.CreateCylinder(
        ["NAME:CylinderParameters", "XCenter:=", mm(x), "YCenter:=", mm(y),
         "ZCenter:=", mm(bottom), "Radius:=", mm(diameter/2),
         "Height:=", mm(top-bottom), "WhichAxis:=", "Z", "NumSides:=", "0"],
        ["NAME:Attributes", "Name:=", name, "MaterialValue:=", '"copper"',
         "SolveInside:=", True, "Color:=", color])


dm=oProject.GetDefinitionManager()
dm.AddMaterial(["NAME:TPG33","CoordinateSystemType:=","Cartesian","BulkOrSurfaceType:=",1,
 ["NAME:PhysicsTypes","set:=",["Electromagnetic"]],
 "permeability:=","3300","conductivity:=","0"])
# Pair of E halves, equal gaps at all three joints.
for tag,sign in [("Upper",1),("Lower",-1)]:
    yoke_z=GAP/2+STEM if sign==1 else -GAP/2-HEIGHT
    leg_z=GAP/2 if sign==1 else -GAP/2-STEM
    parts=["Core_"+tag+"_Yoke"]
    create_box(parts[0],[-35,-12,yoke_z],[70,24,12],"TPG33","(166 166 166)")
    for lab,x,w in [("Left",-35,12),("Center",-12,24),("Right",23,12)]:
        name="Core_"+tag+"_"+lab
        create_box(name,[x,-12,leg_z],[w,24,STEM],"TPG33","(166 166 166)")
        parts.append(name)
    unite(parts)
for lab,x,w in [("Left",-35,12),("Center",-12,24),("Right",23,12)]:
    create_box("Gap_"+lab,[x,-12,-GAP/2],[w,24,GAP],"vacuum","(200 225 255)")
# L1 at the PCB top; keep every dielectric layer and finished core cut-out.
layer_z=[]
z=BOARD_T/2
for i,t in enumerate(CU):
    layer_z.append(z-t/2)
    z-=t
    if i<7:
        d=DIEL[i]; name="PCB_Diel_L%d_L%d"%(i+1,i+2)
        create_box(name,[-41,-31,z-d],[82,62,d],"FR4_epoxy","(100 145 85)")
        cut=[]
        for lab,x,w in [("Left",-35,12),("Center",-12,24),("Right",23,12)]:
            cn=name+"_Cut_"+lab
            create_box(cn,[x-.3,-12.3,z-d-.01],[w+.6,24.6,d+.02],"vacuum","(255 255 255)")
            cut.append(cn)
        subtract(name,cut)
        z-=d
# Primary/AUX layer traces; secondary endpoints break out on L8 below.
coil_names=[]
coil_info=[]
secondary_points={}
for layer,turns,width,tag,col,clear in [
 (2,18,.2,"Primary_A","(220 50 30)",2),
 (3,18,.2,"Primary_B","(220 50 30)",2),
 (4,1,.2,"AUX_A","(0 150 65)",5.4),
 (5,1,.2,"AUX_B","(0 150 65)",5.4),
 (6,3,2.2,"Secondary_A","(25 90 220)",2),
 (7,3,2.2,"Secondary_B","(25 90 220)",2),
 (8,3,2.2,"Secondary_C","(25 90 220)",2)]:
    pts=rectangular_spiral(0,0,turns,width,.2,layer_z[layer-1],"left",clear)
    # Remove the four-mm outer stub, which would otherwise enter a return leg.
    pts=pts[1:]
    # Bring the inner terminal across the innermost bottom edge, stopping before
    # its own entry column. One open spiral remains, without same-layer bridges.
    final_y=pts[-1][1]
    if layer in (2,3):
        # Common inner terminal at the bottom centre of the core window.
        pts.append((0.0,final_y,pts[-1][2]))
        if layer==3:
            # Mirror then reverse: same clockwise traversal, now inside-out.
            pts=[(-x,y,zv) for x,y,zv in reversed(pts)]
    else:
        pts.append((-abs(final_y)+width+.2,final_y,pts[-1][2]))
    # PCB edges are Y=+/-31 mm. Extend the outer entry column directly
    # to the board edge, without a lateral jog, on its own winding layer.
    if layer==2:
        pts[0]=(pts[0][0],-31.0,pts[0][2])
    elif layer==3:
        pts[-1]=(pts[-1][0],-31.0,pts[-1][2])
    elif layer in (4,5):
        # Full centred turn, shifted to the MATLAB AUX radial band (17.5 mm).
        r=17.5; zz=layer_z[layer-1]
        pts=[(0,-17.9,zz),(r,-17.9,zz),(r,r,zz),(-r,r,zz),(-r,-r,zz),(0,-r,zz)]
        if layer==4:
            pts=[(-3,-24,zz),(-3,-17.9,zz)]+pts[1:]
        else:
            pts=[(-x,y,zv) for x,y,zv in reversed(pts)]
            pts += [(3,-17.9,zz),(3,-25,zz)]
    elif layer in (6,7,8):
        pts=centred_secondary_spiral(turns,width,.2,layer_z[layer-1])
        secondary_points[layer]=pts
    name="%s_L%d_%dT"%(tag,layer,turns)
    create_trace(name,pts,width,CU[layer-1],col)
    coil_names.append(name)
    coil_info.append(dict(name=name,layer=layer,turns=turns,width_mm=width,
        thickness_mm=CU[layer-1],start_mm=pts[0],end_mm=pts[-1]))
# Series primary: one L1-L3 blind via contacts only the matched inner ends.
# L1 has no other copper here; both external primary terminals stay on L2/L3.
via_y=-(LEG/2+2+.2/2)
via_bottom=layer_z[2]-CU[2]/2
via_top=layer_z[0]+CU[0]/2
oEditor.CreateCylinder(["NAME:CylinderParameters","XCenter:=",mm(0),
    "YCenter:=",mm(via_y),"ZCenter:=",mm(via_bottom),"Radius:=",mm(.1),
    "Height:=",mm(via_top-via_bottom),"WhichAxis:=","Z","NumSides:=","0"],
    ["NAME:Attributes","Name:=","Primary_Series_Via_L1_L3",
     "MaterialValue:=",'"copper"',"SolveInside:=",True,"Color:=","(220 50 30)"])
unite(["Primary_A_L2_18T","Primary_B_L3_18T","Primary_Series_Via_L1_L3"])
# AUX series connection and separate L1 access below the primary turns.
aux_parts=["AUX_A_L4_1T","AUX_B_L5_1T"]
create_via("AUX_Series_L4_L5",0,-17.5,4,5,.2,"(0 150 65)")
aux_parts.append("AUX_Series_L4_L5")
for label,x,y,layer in [("START",-3,-24,4),("END",3,-25,5)]:
    vn="AUX_"+label+"_Via_L1_L"+str(layer)
    create_via(vn,x,y,1,layer,.2,"(0 150 65)")
    tn="AUX_"+label+"_Breakout_L1"
    create_trace(tn,[(x,y,layer_z[0]),(x,-31,layer_z[0])],.2,CU[0],"(0 150 65)")
    aux_parts.extend([vn,tn])
unite(aux_parts)
# Parallel L6/L7/L8 ends are joined by shared blind vias. L8 is occupied;
# use separate copper bridges BELOW the PCB with 0.50 mm air standoff.
# These bridges are assembly conductors, not a fictitious ninth PCB layer.
secondary_parts=["Secondary_A_L6_3T","Secondary_B_L7_3T","Secondary_C_L8_3T"]
secondary_terminals=[]
secondary_vias=[]
bus_width=6.5
bus_thickness=.069
bus_standoff=.50
bus_z=-BOARD_T/2-bus_standoff-bus_thickness/2
for label,point,lane_x,bus_y in [
        ("START",secondary_points[6][0],4.55,secondary_points[6][0][1]),
        ("END",secondary_points[6][-1],-4.55,15.5)]:
    name="Secondary_"+label+"_VIA_L6_L8"
    create_via(name,point[0],point[1],6,8,2.2,"(25 90 220)")
    secondary_parts.append(name)
    secondary_vias.append(dict(name=name,xy_mm=list(point[:2]),layers=[6,7,8],diameter_mm=2.2))
    name="Secondary_"+label+"_Bridge_Post"
    bottom=bus_z-bus_thickness/2
    top=layer_z[7]+CU[7]/2
    oEditor.CreateCylinder(
        ["NAME:CylinderParameters","XCenter:=",mm(point[0]),"YCenter:=",mm(point[1]),
         "ZCenter:=",mm(bottom),"Radius:=",mm(1.1),"Height:=",mm(top-bottom),
         "WhichAxis:=","Z","NumSides:=","0"],
        ["NAME:Attributes","Name:=",name,"MaterialValue:=",'"copper"',
         "SolveInside:=",True,"Color:=","(25 90 220)"])
    secondary_parts.append(name)
    if abs(bus_y-point[1])>1e-9:
        name="Secondary_"+label+"_Bridge_Neck"
        create_trace(name,[(point[0],point[1],bus_z),(point[0],bus_y,bus_z)],
                     2.2,bus_thickness,"(25 90 220)")
        secondary_parts.append(name)
    name="Secondary_"+label+"_External_Bridge"
    terminal=(lane_x,31.0,bus_z)
    create_trace(name,[(point[0],bus_y,bus_z),(lane_x,bus_y,bus_z),terminal],
                 bus_width,bus_thickness,"(25 90 220)")
    secondary_parts.append(name)
    secondary_terminals.append(dict(label=label,layer="external_bridge",centre_mm=terminal,width_mm=bus_width))
unite(secondary_parts)
# Clear connected copper out of dielectric to avoid overlapping materials.
for i in range(1,8):
    oEditor.Subtract(["NAME:Selections","Blank Parts:=","PCB_Diel_L%d_L%d"%(i,i+1),
        "Tool Parts:=","Primary_A_L2_18T,Secondary_A_L6_3T,AUX_A_L4_1T"],
        ["NAME:SubtractParameters","KeepOriginals:=",True])
# Display dielectric transparently so buried copper remains visible.
for i in range(1,8):
    oEditor.ChangeProperty(["NAME:AllTabs",["NAME:Geometry3DAttributeTab",
        ["NAME:PropServers","PCB_Diel_L%d_L%d"%(i,i+1)],
        ["NAME:ChangedProps",["NAME:Transparent","Value:=",0.9]]]])
oEditor.FitAll()
def overlaps(a,b):
    return all(min(a['origin'][i]+a['size'][i],b['origin'][i]+b['size'][i])-
               max(a['origin'][i],b['origin'][i])>1e-8 for i in range(3))
for copper in [b for b in geometry_boxes if b['material']=='copper']:
    for other in geometry_boxes:
        if other['material']=='TPG33' or (other['material']=='copper' and
                other['name'].split('_')[0]!=copper['name'].split('_')[0]):
            if overlaps(copper,other):
                raise RuntimeError('Geometry collision: '+copper['name']+' / '+other['name'])
unclassified=list(oEditor.GetObjectsInGroup("Unclassified"))
if unclassified:
    raise RuntimeError("Invalid geometry objects: " + ",".join(unclassified))
solids=list(oEditor.GetObjectsInGroup("Solids"))
if "Secondary_A_L6_3T" not in solids or "Secondary_B_L7_3T" in solids or "Secondary_C_L8_3T" in solids:
    raise RuntimeError("Secondary copper union was not completed")
output=os.path.join(os.path.dirname(os.path.abspath(__file__)),"output","36_3_2_compact")
if not os.path.isdir(output): os.makedirs(output)
project=os.path.join(output,"Flyback_36_3_2_Compact70mm_Connected_100kHz.aedt")
oProject.SaveAs(project,True)
with open(os.path.join(output,"Flyback_36_3_2_Compact70mm_Connected_geometry.json"),"w") as f:
    json.dump(dict(project=project,half_height_mm=HEIGHT,gap_each_mm=GAP,
       core_size_mm=[LENGTH,DEPTH,2*HEIGHT+GAP],pcb_thickness_mm=BOARD_T,
       core_pcb_clearance_mm=CLEARANCE,coils=coil_info,
       stage="primary L2-L3 series; secondary L6/L7/L8 parallel; AUX L4/L5 series with L1 terminals; ready for configuration",
       primary_series_via_mm=[0,via_y,via_bottom,via_top],
       secondary_connection="3T || 3T || 3T (same polarity)",
       secondary_vias=secondary_vias,secondary_terminals=secondary_terminals,
       secondary_to_outer_leg_clearance_mm=2.0,
       external_bridge_standoff_mm=bus_standoff,external_bridge_thickness_mm=bus_thickness,
       pcb_size_mm=[82,62,BOARD_T]),f,indent=2)

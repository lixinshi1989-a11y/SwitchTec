"""Build only Flyback scheme C EE geometry in AEDT; no solver excitation yet.
Primary L2/L3 spirals are series-connected by an inner L1-L3 blind via.
Secondary and AUX layer connections and solver excitations remain unrouted.
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
LENGTH=80.0
YOKE=12.0
OUTER=12.0
WINDOW=16.0
CLEARANCE=1.0
mu0=4*math.pi*1e-7
mur=3300.0
Ac=24*24*1e-6
Ao=12*24*1e-6
Ay=12*24*1e-6
h0=YOKE+BOARD_T/2+CLEARANCE
vertical0=2*(h0-YOKE/2)*1e-3
pitch=34e-3
r0=vertical0/(mu0*mur*Ac)+(vertical0/(mu0*mur*Ao)+2*pitch/(mu0*mur*Ay))/2
g=(36.0**2/.0023-r0)/((1/(mu0*Ac)+1/(2*mu0*Ao))*(1-1/mur))
GAP=g*1e3
HEIGHT=h0-GAP/2
STEM=HEIGHT-YOKE
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


def rectangular_spiral(cx, cy, turns, width, spacing, z, exit_side,
                       core_clearance=LEG_TO_COPPER):
    """Open rectangular spiral around one 10 x 10 mm core-leg slot."""
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



dm=oProject.GetDefinitionManager()
dm.AddMaterial(["NAME:TPG33","CoordinateSystemType:=","Cartesian","BulkOrSurfaceType:=",1,
 ["NAME:PhysicsTypes","set:=",["Electromagnetic"]],
 "permeability:=","3300","conductivity:=","0"])
# Pair of E halves, equal gaps at all three joints.
for tag,sign in [("Upper",1),("Lower",-1)]:
    yoke_z=GAP/2+STEM if sign==1 else -GAP/2-HEIGHT
    leg_z=GAP/2 if sign==1 else -GAP/2-STEM
    parts=["Core_"+tag+"_Yoke"]
    create_box(parts[0],[-40,-12,yoke_z],[80,24,12],"TPG33","(166 166 166)")
    for lab,x,w in [("Left",-40,12),("Center",-12,24),("Right",28,12)]:
        name="Core_"+tag+"_"+lab
        create_box(name,[x,-12,leg_z],[w,24,STEM],"TPG33","(166 166 166)")
        parts.append(name)
    unite(parts)
for lab,x,w in [("Left",-40,12),("Center",-12,24),("Right",28,12)]:
    create_box("Gap_"+lab,[x,-12,-GAP/2],[w,24,GAP],"vacuum","(200 225 255)")
# L1 at the PCB top; keep every dielectric layer and finished core cut-out.
layer_z=[]
z=BOARD_T/2
for i,t in enumerate(CU):
    layer_z.append(z-t/2)
    z-=t
    if i<7:
        d=DIEL[i]; name="PCB_Diel_L%d_L%d"%(i+1,i+2)
        create_box(name,[-46,-31,z-d],[92,62,d],"FR4_epoxy","(100 145 85)")
        cut=[]
        for lab,x,w in [("Left",-40,12),("Center",-12,24),("Right",28,12)]:
            cn=name+"_Cut_"+lab
            create_box(cn,[x-.3,-12.3,z-d-.01],[w+.6,24.6,d+.02],"vacuum","(255 255 255)")
            cut.append(cn)
        subtract(name,cut)
        z-=d
# Board-edge outer terminals. Inner secondary/AUX terminals remain unrouted.
coil_names=[]
coil_info=[]
for layer,turns,width,tag,col,clear in [
 (2,18,.2,"Primary_A","(220 50 30)",2),
 (3,18,.2,"Primary_B","(220 50 30)",2),
 (4,1,.2,"AUX_A","(0 150 65)",5.4),
 (5,1,.2,"AUX_B","(0 150 65)",5.4),
 (6,3,4.0,"Secondary_A","(25 90 220)",2),
 (7,3,4.0,"Secondary_B","(25 90 220)",2)]:
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
        # AUX outer ends leave downwards on their own layers.
        pts[0]=(pts[0][0],-31.0,pts[0][2])
    elif layer in (6,7):
        # Put the outer entry at its top-left corner and extend vertically to
        # the top board edge. This avoids a 4 mm lead through a return leg.
        pts[0]=(pts[0][0],31.0,pts[0][2])
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
# Clear the connected primary out of dielectric to avoid overlapping materials.
for i in range(1,8):
    oEditor.Subtract(["NAME:Selections","Blank Parts:=","PCB_Diel_L%d_L%d"%(i,i+1),
        "Tool Parts:=","Primary_A_L2_18T"],
        ["NAME:SubtractParameters","KeepOriginals:=",True])
# Display dielectric transparently so buried copper remains visible.
for i in range(1,8):
    oEditor.ChangeProperty(["NAME:AllTabs",["NAME:Geometry3DAttributeTab",
        ["NAME:PropServers","PCB_Diel_L%d_L%d"%(i,i+1)],
        ["NAME:ChangedProps",["NAME:Transparent","Value:=",0.9]]]])
oEditor.FitAll()
output=os.path.join(os.path.dirname(os.path.abspath(__file__)),"output")
if not os.path.isdir(output): os.makedirs(output)
project=os.path.join(output,"Flyback_Scheme_C_EE_StraightLeads_100kHz.aedt")
oProject.SaveAs(project,True)
with open(os.path.join(output,"Flyback_Scheme_C_EE_geometry.json"),"w") as f:
    json.dump(dict(project=project,half_height_mm=HEIGHT,gap_each_mm=GAP,
       core_size_mm=[LENGTH,DEPTH,2*HEIGHT+GAP],pcb_thickness_mm=BOARD_T,
       core_pcb_clearance_mm=CLEARANCE,coils=coil_info,
       stage="primary L2-L3 series via connected; secondary/AUX interconnects and excitations not assigned",
       primary_series_via_mm=[0,via_y,via_bottom,via_top],
       secondary_to_outer_leg_clearance_mm=1.6),f,indent=2)

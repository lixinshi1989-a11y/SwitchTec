"""Four colored 4T secondaries; paired terminals at winding outline, 1 mm gap.

S1(L1->L2)/S4(L8->L7): left. S2(L3->L2)/S3(L6->L7): right.
Terminal spacing is the XY copper-edge spacing, not vertical layer separation.
Preserves the 7x14 baseline core, PCB stack and primary. No solve is run.
"""
from pathlib import Path
import inspect
import build_llc_rectangular_7x14_secondary_L1378 as previous
import build_and_configure_llc_aedt as configured

ROOT = Path(__file__).resolve().parent
STEM = 'LLC_7x14_Secondary_GroupedTerminals_1mm'
BUILDER = ROOT / ('_build_' + STEM + '.py')


def make_geometry_builder():
    text = previous.make_geometry_builder()
    start = text.index('# Each spiral starts outside')
    end = text.index('# -----------------------------------------------------------------------------', start)
    text = text[:start] + '''# Pair terminals at the left/right secondary winding outline.
SEC_PORT_GAP = 1.0
SEC_PORT_PITCH = S_WIDTH + SEC_PORT_GAP
sec_port_x = {}
for layer, winding in SECONDARY_LAYERS.items():
    left = layer in (1, 8)
    side = "left" if left else "right"
    pts = rectangular_spiral(LEG_PITCH / 2.0, 0.0, S_TURNS,
                             S_WIDTH, TURN_SPACING, layer_z[layer - 1], side,
                             SEC_LEG_TO_COPPER)
    inner = LEG / 2.0 + SEC_LEG_TO_COPPER + S_WIDTH / 2.0
    via_x = LEG_PITCH / 2.0 + (-inner + 0.95 if left else inner - 0.95)
    pts.append((via_x, pts[-1][1], pts[-1][2]))
    if not left:
        pts = [(x, -y, z) for x, y, z in pts]
    # Trim the original long access tail exactly to the outer copper edge.
    port_x = pts[1][0] + (-S_WIDTH / 2.0 if left else S_WIDTH / 2.0)
    pts[0] = (port_x, 0.0, pts[0][2])
    sec_port_x[layer] = port_x
    secondary_points[layer] = pts
    create_trace("{}_L{}_4T".format(winding, layer), pts, S_WIDTH,
                 CU[layer - 1], SECONDARY_COLORS[winding])

''' + text[end:]
    start = text.index('# Adjacent-layer inner-end vias only:')
    end = text.index('# -----------------------------------------------------------------------------', start)
    text = text[:start] + '''# Inner ends return alongside their own outer/start terminal on L2/L7.
sec_surface = {1: 2, 3: 2, 6: 7, 8: 7}
sec_return_y = {}
for layer, winding in SECONDARY_LAYERS.items():
    end_pt = secondary_points[layer][-1]
    target = sec_surface[layer]
    first, last = min(layer, target), max(layer, target)
    create_via(winding + "_END_VIA", end_pt[0], end_pt[1], first, last,
               S_WIDTH, SECONDARY_COLORS[winding])
    left = layer in (1, 8)
    port_x = sec_port_x[layer]
    route_x = port_x + (S_WIDTH / 2.0 if left else -S_WIDTH / 2.0)
    return_y = -SEC_PORT_PITCH if left else SEC_PORT_PITCH
    sec_return_y[layer] = return_y
    zout = layer_z[target - 1]
    create_trace(winding + "_RETURN_LEAD",
                 [(end_pt[0], end_pt[1], zout), (route_x, end_pt[1], zout),
                  (route_x, return_y, zout), (port_x, return_y, zout)],
                 S_WIDTH, CU[target - 1], SECONDARY_COLORS[winding])

''' + text[end:]
    text = text.replace('winding + "_START_LEAD", winding + "_RETURN_LEAD"',
                        'winding + "_RETURN_LEAD"')
    text = text.replace(previous.STEM + '_Geometry.aedt', STEM + '_Geometry.aedt')
    text = text.replace('"""Build the planar LLC transformer in Ansys Electronics Desktop 2024 R2.',
                        '"""7x14 revision: colored secondaries with paired terminals at their outline.')
    BUILDER.write_text(text, encoding='utf-8')
    return text


def main():
    make_geometry_builder()
    configured.BUILDER = BUILDER
    configured.GEOMETRY_PROJECT = ROOT/'output'/(STEM+'_Geometry.aedt')
    configured.CONFIGURED_PROJECT = ROOT/'output'/(STEM+'_800kHz.aedt')
    cu = [.069,.064,.064,.064,.064,.064,.064,.069]
    diel = [.346,.406,.393,.406,.406,.406,.360]
    z = -(sum(cu)+sum(diel))/2
    zs = []
    for i,t in enumerate(cu):
        zs.append(z+t/2)
        z += t+(diel[i] if i<7 else 0)
    configured.WINDING_SOLIDS = {'WindingP':'P1_L2_3T'}
    configured.TERMINALS = {'WindingP':((-30,0,zs[0],1.2,cu[0]),
                                        (-30,-9.6,zs[0],1.2,cu[0]))}
    for n,layer,target,left in [(1,1,2,True),(2,3,2,False),
                                (3,6,7,False),(4,8,7,True)]:
        name = 'WindingS'+str(n)
        x,y = (2.6,-1.7) if left else (20.4,1.7)
        configured.WINDING_SOLIDS[name] = 'S{}_L{}_4T'.format(n,layer)
        configured.TERMINALS[name] = ((x,0,zs[layer-1],.7,cu[layer-1]),
                                       (x,y,zs[target-1],.7,cu[target-1]))
    # All secondary paths have the same circulation as the primary.
    configured.LEAKAGE_EXPRESSION = (
        'L(WindingP,WindingP)-2*(3/4)*L(WindingS,WindingP)'
        '+(3/4)*(3/4)*L(WindingS,WindingS)')
    source = inspect.getsource(configured.configure_project)
    source = source.replace('for winding, terminal_pair in TERMINALS.items():',
        'for winding, terminal_pair in TERMINALS.items():\n'
        '            if winding != "WindingP":\n'
        '                continue  # Secondary ports terminate at winding outline.')
    exec(compile(source, '<grouped-terminal-configuration>', 'exec'), configured.__dict__)
    configured.main()


if __name__ == '__main__':
    main()

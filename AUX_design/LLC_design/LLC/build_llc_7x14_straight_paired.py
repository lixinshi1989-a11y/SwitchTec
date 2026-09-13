"""7x14: original colored spirals; pair each start/return along Y, 1 mm gap.

All leads retain the original +X exit direction. The outer turn entry is positioned directly
at its paired terminal Y coordinate; the breakout is a straight +X line.
S1/S4: y=-7.65/-9.35 mm. S2/S3: y=+7.65/+9.35 mm.
Only the outer turn entry length changes; inner turns, vias, core, stack and primary are unchanged.

Run with AEDT CPython and workspace .deps on PYTHONPATH. Builds and configures
800 kHz Maxwell; does not solve. Original projects are preserved.
S2/S3 are reflected in Y to separate the two return lanes. Their solver
terminal references are reversed to preserve the parallel matrix polarity.
"""
from pathlib import Path
import build_llc_rectangular_7x14_aedt as baseline
import build_and_configure_llc_aedt as configured

ROOT = Path(__file__).resolve().parent
STEM = "LLC_7x14_Secondary_Straight_Paired1mm"
BUILDER = ROOT / ("_build_" + STEM + ".py")
SECONDARY_COLORS = {
    "S1": "(0 114 189)",
    "S2": "(217 83 25)",
    "S3": "(237 177 32)",
    "S4": "(126 47 142)",
}


def make_geometry_builder():
    text = baseline.BASE_BUILDER.read_text(encoding="utf-8")
    for old, new in baseline.REPLACEMENTS:
        assert text.count(old) == 1, old
        text = text.replace(old, new)
    text = text.replace('SECONDARY_LAYERS = {2: "S1", 3: "S2", 6: "S3", 7: "S4"}',
                        'SECONDARY_LAYERS = {1: "S1", 3: "S2", 6: "S3", 8: "S4"}')
    start = text.index('for layer, winding in SECONDARY_LAYERS.items():')
    end = text.index('# -----------------------------------------------------------------------------', start)
    text = text[:start] + '''# Each spiral starts outside on its own layer. Only its inner end changes layer.
for layer, winding in SECONDARY_LAYERS.items():
    pts = rectangular_spiral(LEG_PITCH / 2.0, 0.0, S_TURNS,
                             S_WIDTH, TURN_SPACING, layer_z[layer - 1], "right",
                             SEC_LEG_TO_COPPER)
    # Complete the fourth inner edge; retain 0.25 mm to the adjacent turn.
    via_x = LEG_PITCH / 2.0 + LEG / 2.0 + SEC_LEG_TO_COPPER + S_WIDTH / 2.0 - 0.95
    pts.append((via_x, pts[-1][1], pts[-1][2]))
    if layer in (3, 6):
        pts = [(x, -y, z) for x, y, z in pts]
    paired_y = pts[-1][1] + (1.70 if pts[-1][1] < 0 else -1.70)
    # Enter the outer rail at the final terminal Y, avoiding an external dogleg.
    pts[0] = (pts[0][0], paired_y, pts[0][2])
    pts[1] = (pts[1][0], paired_y, pts[1][2])
    secondary_points[layer] = pts
    create_trace("{}_L{}_4T".format(winding, layer), pts, S_WIDTH,
                 CU[layer - 1], "(30 105 220)")

''' + text[end:]
    start = text.index('# Each output stays isolated')
    end = text.index('# -----------------------------------------------------------------------------', start)
    text = text[:start] + '''# Adjacent-layer inner-end vias only: L1-L2, L2-L3, L6-L7, L7-L8.
sec_surface = {1: 2, 3: 2, 6: 7, 8: 7}
sec_return_y = {}
for layer, winding in SECONDARY_LAYERS.items():
    start_pt, end_pt = secondary_points[layer][0], secondary_points[layer][-1]
    target = sec_surface[layer]
    first, last = min(layer, target), max(layer, target)
    create_via(winding + "_END_VIA", end_pt[0], end_pt[1], first, last,
               S_WIDTH, "(30 105 220)")
    paired_y = end_pt[1] + (1.70 if end_pt[1] < 0 else -1.70)
    create_trace(winding + "_START_LEAD",
                 [start_pt, (29.0, paired_y, start_pt[2])],
                 S_WIDTH, CU[layer - 1], "(30 105 220)")
    sec_return_y[layer] = end_pt[1]
    zout = layer_z[target - 1]
    create_trace(winding + "_RETURN_LEAD",
                 [(end_pt[0], end_pt[1], zout), (29.0, end_pt[1], zout)],
                 S_WIDTH, CU[target - 1], "(30 105 220)")

''' + text[end:]
    start = text.index('# The four outputs remain mutually isolated.')
    end = text.index('# -----------------------------------------------------------------------------', start)
    text = text[:start] + '''for layer, winding in SECONDARY_LAYERS.items():
    unite(["{}_L{}_4T".format(winding, layer), winding + "_END_VIA",
           winding + "_START_LEAD", winding + "_RETURN_LEAD"])

''' + text[end:]
    text = text.replace('z0 = min(z1, z2) - CU[first_layer - 1] / 2.0',
                        'z0 = min(z1 - CU[first_layer - 1] / 2.0, z2 - CU[last_layer - 1] / 2.0)')
    text = text.replace(baseline.GEOMETRY_PROJECT.name, STEM + "_Geometry.aedt")
    text = text.replace('and L8-L7/L8-L6. Surface breakouts preserve each winding\'s trace width.',
                        'for primary; secondary inner ends use adjacent-layer vias to L2/L7.')
    # Keep spiral, end via and both leads of each winding the same color.
    text = text.replace('PRIMARY_LAYERS =',
                        'SECONDARY_COLORS = ' + repr(SECONDARY_COLORS) + '\nPRIMARY_LAYERS =')
    text = text.replace('"(30 105 220)"', 'SECONDARY_COLORS[winding]')
    BUILDER.write_text(text, encoding="utf-8")
    return text


def main():
    make_geometry_builder()
    configured.BUILDER = BUILDER
    configured.GEOMETRY_PROJECT = ROOT / "output" / (STEM + "_Geometry.aedt")
    configured.CONFIGURED_PROJECT = ROOT / "output" / (STEM + "_800kHz.aedt")
    cu = [.069, .064, .064, .064, .064, .064, .064, .069]
    diel = [.346, .406, .393, .406, .406, .406, .360]
    z = -(sum(cu) + sum(diel)) / 2
    zs = []
    for i, t in enumerate(cu):
        zs.append(z + t / 2)
        z += t + (diel[i] if i < 7 else 0)
    configured.WINDING_SOLIDS = {"WindingP": "P1_L2_3T"}
    configured.TERMINALS = {"WindingP": ((-30, 0, zs[0], 1.2, cu[0]),
                                           (-30, -9.6, zs[0], 1.2, cu[0]))}
    for n, layer, target, y in [(1, 1, 2, -9.35), (2, 3, 2, 9.35),
                                 (3, 6, 7, 9.35), (4, 8, 7, -9.35)]:
        name = "WindingS" + str(n)
        configured.WINDING_SOLIDS[name] = "S{}_L{}_4T".format(n, layer)
        pair = ((30, y + (1.7 if y < 0 else -1.7), zs[layer-1], .7, cu[layer-1]),
                (30, y, zs[target-1], .7, cu[target-1]))
        configured.TERMINALS[name] = pair[::-1] if n in (2, 3) else pair
    configured.LEAKAGE_EXPRESSION = (
        "L(WindingP,WindingP)+2*(3/4)*L(WindingS,WindingP)"
        "+(3/4)*(3/4)*L(WindingS,WindingS)")
    configured.main()


if __name__ == "__main__":
    main()

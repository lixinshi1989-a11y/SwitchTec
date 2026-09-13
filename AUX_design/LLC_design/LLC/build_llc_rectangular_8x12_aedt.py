"""Build the 8 x 12 mm rectangular-leg LLC model with 4.6 mm P-S spacing.

The established AEDT builder remains the source of truth for the PCB stack,
winding connectivity, terminals, materials, matrix, and solver setup. This
wrapper generates a geometry-builder variant with the rectangular magnetic
section, then runs the existing configuration flow under a distinct filename.
"""
from pathlib import Path

import build_and_configure_llc_aedt as configured


ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "output"
BASE_BUILDER = ROOT / "build_llc_transformer_aedt.py"
# Keep the generated native-AEDT script beside the base builder because the
# native script saves to ``<script directory>/output``.
GENERATED_BUILDER = ROOT / "_build_llc_rectangular_8x12_gap4p6_geometry.py"
GEOMETRY_PROJECT = OUTPUT / "LLC_Rectangular_8x12_PSgap4p6_Geometry.aedt"
CONFIGURED_PROJECT = OUTPUT / "LLC_Rectangular_8x12_PSgap4p6_800kHz.aedt"

CORE_LENGTH_MM = 32.0
LEG_WIDTH_MM = 8.0
LEG_PITCH_MM = 24.0
CORE_TO_COPPER_MM = 2.0
PRIMARY_BUILD_MM = 3 * 1.20 + 2 * 0.20
SECONDARY_BUILD_MM = 4 * 0.70 + 3 * 0.20
PS_COPPER_GAP_MM = (
    LEG_PITCH_MM - LEG_WIDTH_MM - 2 * CORE_TO_COPPER_MM
    - PRIMARY_BUILD_MM - SECONDARY_BUILD_MM
)


REPLACEMENTS = [
    ("CORE_LENGTH = 36.0", "CORE_LENGTH = 32.0"),
    (
        "CORE_WIDTH = 10.0\nLEG = 10.0\nLEG_PITCH = 26.0\nSLOT = 10.6",
        "CORE_DEPTH = 12.0\nLEG = 8.0\nLEG_PITCH = 24.0\n"
        "SLOT_X = 8.6\nSLOT_Y = 12.6",
    ),
    (
        "U_HEIGHT = CORE_WIDTH + BOARD_T / 2.0 + CORE_TO_PCB_SURFACE - GAP_EACH_JOINT / 2.0",
        "U_HEIGHT = LEG + BOARD_T / 2.0 + CORE_TO_PCB_SURFACE - GAP_EACH_JOINT / 2.0",
    ),
    (
        "create_box(hname, [cx - SLOT / 2, -SLOT / 2, z - 0.01],\n"
        "                       [SLOT, SLOT, DIEL[layer - 1] + 0.02], \"vacuum\", \"(255 255 255)\")",
        "create_box(hname, [cx - SLOT_X / 2, -SLOT_Y / 2, z - 0.01],\n"
        "                       [SLOT_X, SLOT_Y, DIEL[layer - 1] + 0.02], \"vacuum\", \"(255 255 255)\")",
    ),
    (
        "    \"\"\"Open rectangular spiral around one 10 x 10 mm core-leg slot.\"\"\"\n"
        "    pitch = width + spacing\n"
        "    inner = LEG / 2.0 + core_clearance + width / 2.0\n"
        "    outer = inner + (turns - 1) * pitch\n"
        "    x_left, x_right = cx - outer, cx + outer\n"
        "    y_bottom, y_top = cy - outer, cy + outer",
        "    \"\"\"Open rectangular spiral around one 8 x 12 mm core-leg slot.\"\"\"\n"
        "    pitch = width + spacing\n"
        "    inner_x = LEG / 2.0 + core_clearance + width / 2.0\n"
        "    inner_y = CORE_DEPTH / 2.0 + core_clearance + width / 2.0\n"
        "    outer_x = inner_x + (turns - 1) * pitch\n"
        "    outer_y = inner_y + (turns - 1) * pitch\n"
        "    x_left, x_right = cx - outer_x, cx + outer_x\n"
        "    y_bottom, y_top = cy - outer_y, cy + outer_y",
    ),
    (
        "sec_return_y = {2: -9.15, 3: -8.25, 6: -8.25, 7: -9.15}",
        "sec_return_y = {2: -9.25, 3: -8.25, 6: -8.25, 7: -9.25}",
    ),
    ("stem = U_HEIGHT - CORE_WIDTH", "stem = U_HEIGHT - LEG"),
    (
        "create_box(upper[-1], [left_x, -CORE_WIDTH / 2, g2 + stem],\n"
        "           [CORE_LENGTH, CORE_WIDTH, CORE_WIDTH], \"DMR53\", \"(65 70 78)\")",
        "create_box(upper[-1], [left_x, -CORE_DEPTH / 2, g2 + stem],\n"
        "           [CORE_LENGTH, CORE_DEPTH, LEG], \"DMR53\", \"(65 70 78)\")",
    ),
    (
        "create_box(name, [x, -LEG / 2, g2], [LEG, LEG, stem], \"DMR53\", \"(65 70 78)\")",
        "create_box(name, [x, -CORE_DEPTH / 2, g2], [LEG, CORE_DEPTH, stem], \"DMR53\", \"(65 70 78)\")",
    ),
    (
        "create_box(lower[-1], [left_x, -CORE_WIDTH / 2, -g2 - U_HEIGHT],\n"
        "           [CORE_LENGTH, CORE_WIDTH, CORE_WIDTH], \"DMR53\", \"(65 70 78)\")",
        "create_box(lower[-1], [left_x, -CORE_DEPTH / 2, -g2 - U_HEIGHT],\n"
        "           [CORE_LENGTH, CORE_DEPTH, LEG], \"DMR53\", \"(65 70 78)\")",
    ),
    (
        "create_box(name, [x, -LEG / 2, -g2 - stem], [LEG, LEG, stem],\n"
        "               \"DMR53\", \"(65 70 78)\")",
        "create_box(name, [x, -CORE_DEPTH / 2, -g2 - stem], [LEG, CORE_DEPTH, stem],\n"
        "               \"DMR53\", \"(65 70 78)\")",
    ),
    (
        "create_box(\"AirGap_PrimaryLeg_0p052554mm\", [left_x, -LEG / 2, -g2],\n"
        "           [LEG, LEG, GAP_EACH_JOINT], \"vacuum\", \"(210 235 255)\")",
        "create_box(\"AirGap_PrimaryLeg_0p052554mm\", [left_x, -CORE_DEPTH / 2, -g2],\n"
        "           [LEG, CORE_DEPTH, GAP_EACH_JOINT], \"vacuum\", \"(210 235 255)\")",
    ),
    (
        "create_box(\"AirGap_SecondaryLeg_0p052554mm\", [right_leg_x, -LEG / 2, -g2],\n"
        "           [LEG, LEG, GAP_EACH_JOINT], \"vacuum\", \"(210 235 255)\")",
        "create_box(\"AirGap_SecondaryLeg_0p052554mm\", [right_leg_x, -CORE_DEPTH / 2, -g2],\n"
        "           [LEG, CORE_DEPTH, GAP_EACH_JOINT], \"vacuum\", \"(210 235 255)\")",
    ),
    (
        "'LLC_Planar_Transformer_Np3_Lm6p5uH_v7.aedt'",
        "'LLC_Rectangular_8x12_PSgap4p6_Geometry.aedt'",
    ),
]


def make_geometry_builder():
    text = BASE_BUILDER.read_text(encoding="utf-8")
    for old, new in REPLACEMENTS:
        count = text.count(old)
        if count != 1:
            raise RuntimeError(
                "Expected one geometry-builder match, found {} for {!r}".format(count, old[:80])
            )
        text = text.replace(old, new)
    GENERATED_BUILDER.write_text(text, encoding="utf-8")


def main():
    if abs(PS_COPPER_GAP_MM - 4.6) > 1e-12:
        raise RuntimeError("Calculated primary-secondary copper gap is not 4.6 mm")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    make_geometry_builder()
    configured.GEOMETRY_PROJECT = GEOMETRY_PROJECT
    configured.CONFIGURED_PROJECT = CONFIGURED_PROJECT
    configured.BUILDER = GENERATED_BUILDER
    # The generated coils give negative Lsp with AEDT's terminal reference
    # directions. Use the flux-cancelling polarity in the saved report.
    configured.LEAKAGE_EXPRESSION = (
        "L(WindingP,WindingP)+2*(3/4)*L(WindingS,WindingP)"
        "+(3/4)*(3/4)*L(WindingS,WindingS)"
    )
    configured.main()
    print("RECTANGULAR_GEOMETRY_PROJECT={}".format(GEOMETRY_PROJECT))
    print("RECTANGULAR_CONFIGURED_PROJECT={}".format(CONFIGURED_PROJECT))
    print("CORE_LENGTH={:.1f} mm; LEG_PITCH={:.1f} mm".format(
        CORE_LENGTH_MM, LEG_PITCH_MM))
    print("NEAREST_PRIMARY_SECONDARY_COPPER_GAP={:.1f} mm".format(
        PS_COPPER_GAP_MM))


if __name__ == "__main__":
    main()

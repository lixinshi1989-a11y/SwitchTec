"""Build the LLC planar transformer and configure its Maxwell 3D solve.

Run with the AEDT 2024 R2 CPython plus the local PyAEDT package.  The script
produces one project that is ready for Analyze Setup1; no manual boundary,
matrix, reduction, or result-expression setup is required.
"""
from pathlib import Path
import shutil
import subprocess

from ansys.aedt.core import Maxwell3d
from ansys.aedt.core.generic.constants import Plane


ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "output"
GEOMETRY_PROJECT = OUTPUT / "LLC_Planar_Transformer_Np3_Lm6p5uH_v7.aedt"
CONFIGURED_PROJECT = OUTPUT / "LLC_Planar_Transformer_800kHz_YellowCircle_StaggeredVias.aedt"
BUILDER = ROOT / "build_llc_transformer_aedt.py"
AEDT_EXE = Path(r"C:\Program Files\AnsysEM\v242\Win64\ansysedt.exe")
DESIGN = "LLC_Transformer_800kHz"

FREQUENCY = "800kHz"
TURNS_RATIO = 3.0 / 4.0
# DMR53 local 80 degC fit around 1 MHz and 20-50 mT.
# Pv[W/m^3] = Cm*f[Hz]^X*B[T]^Y.  The fit is anchored to the
# 1 MHz/50 mT/70 mW/cm^3 point; do not use it far outside this range.
DMR53_CM = 7.776210110587722e-05
DMR53_X = 2.0995356735509145
DMR53_Y = 2.8
DMR53_KDC = 0.0
LEAKAGE_EXPRESSION = (
    "L(WindingP,WindingP)-2*(3/4)*L(WindingS,WindingP)"
    "+(3/4)*(3/4)*L(WindingS,WindingS)"
)

L1_Z, L8_Z = -1.5880, 1.5880
CU_L1 = CU_L8 = 0.069
P_WIDTH, S_WIDTH = 1.20, 0.70

WINDING_SOLIDS = {
    "WindingP": "P1_L2_3T",
    "WindingS1": "S1_L2_4T",
    "WindingS2": "S2_L3_4T",
    "WindingS3": "S3_L6_4T",
    "WindingS4": "S4_L7_4T",
}

# (x, centre-y, centre-z, trace width, copper thickness).  The terminal
# extensions end exactly at the X faces of the simulation region.
TERMINALS = {
    "WindingP": ((-30.0, 0.0, L1_Z, P_WIDTH, CU_L1),
                 (-30.0, -9.00, L1_Z, P_WIDTH, CU_L1)),
    "WindingS1": ((30.0, 0.0, L1_Z, S_WIDTH, CU_L1),
                  (30.0, -9.15, L1_Z, S_WIDTH, CU_L1)),
    "WindingS2": ((30.0, 3.0, L1_Z, S_WIDTH, CU_L1),
                  (30.0, -8.25, L1_Z, S_WIDTH, CU_L1)),
    "WindingS3": ((30.0, -3.0, L8_Z, S_WIDTH, CU_L8),
                  (30.0, -8.25, L8_Z, S_WIDTH, CU_L8)),
    "WindingS4": ((30.0, 0.0, L8_Z, S_WIDTH, CU_L8),
                  (30.0, -9.15, L8_Z, S_WIDTH, CU_L8)),
}


def rebuild_geometry():
    """Run the native AEDT geometry builder before adding solver data."""
    if not AEDT_EXE.exists():
        raise FileNotFoundError(str(AEDT_EXE))
    subprocess.run(
        [str(AEDT_EXE), "-ng", "-RunScriptAndExit", str(BUILDER)],
        check=True,
    )
    if not GEOMETRY_PROJECT.exists():
        raise RuntimeError("Geometry builder did not create {}".format(GEOMETRY_PROJECT))


def make_terminal_sheet(m3d, winding, suffix, data):
    x, y, z, width, thickness = data
    return m3d.modeler.create_rectangle(
        orientation=Plane.YZ,
        origin=[x, y - width / 2.0, z - thickness / 2.0],
        sizes=[width, thickness],
        name="Terminal_{}_{}".format(winding, suffix),
        material="copper",
        is_covered=True,
    )


def configure_project():
    shutil.copy2(str(GEOMETRY_PROJECT), str(CONFIGURED_PROJECT))
    m3d = Maxwell3d(
        project=str(CONFIGURED_PROJECT), design=DESIGN, version="2024.2",
        non_graphical=True, new_desktop=True, close_on_exit=True,
        remove_lock=True,
    )
    try:
        names = set(m3d.modeler.object_names)
        missing = [v for v in WINDING_SOLIDS.values() if v not in names]
        if missing:
            raise RuntimeError("Missing united winding solids: {}".format(missing))

        # Extend each accessible PCB lead to the region boundary, preserving
        # the original copper width and thickness.
        for winding, terminal_pair in TERMINALS.items():
            for suffix, data in zip(("Start", "Return"), terminal_pair):
                x, y, z, width, thickness = data
                x0, length = (-30.0, 0.5) if x < 0 else (29.0, 1.0)
                extension = m3d.modeler.create_box(
                    [x0, y - width / 2.0, z - thickness / 2.0],
                    [length, width, thickness],
                    name="{}_{}_TerminalExtension".format(winding, suffix),
                    material="copper",
                )
                if not m3d.modeler.unite([WINDING_SOLIDS[winding], extension.name]):
                    raise RuntimeError("Failed to unite {} {}".format(winding, suffix))

        # Clear real copper/via volumes out of the visualization laminate.
        dielectrics = [n for n in m3d.modeler.object_names if n.startswith("PCB_Diel_")]
        copper = list(WINDING_SOLIDS.values())
        for dielectric in dielectrics:
            if not m3d.modeler.subtract(dielectric, copper, keep_originals=True):
                raise RuntimeError("Failed to clear copper from {}".format(dielectric))

        m3d.modeler.create_region(
            pad_value=[0, 0, 20, 20, 20, 20],
            pad_type="Absolute Offset", name="Region",
        )

        terminal_names = {}
        for winding, pair in TERMINALS.items():
            terminal_names[winding] = [
                make_terminal_sheet(m3d, winding, suffix, data).name
                for suffix, data in zip(("Positive", "Negative"), pair)
            ]

        # Match the user's solved V6 excitation setup exactly.
        for winding in WINDING_SOLIDS:
            source = m3d.assign_winding(
                assignment=None, winding_type="Current", is_solid=True,
                current=1 if winding == "WindingP" else 0,
                resistance=0, inductance=0, voltage=0,
                parallel_branches=1, phase=0, name=winding,
            )
            if not source:
                raise RuntimeError("Failed to assign {}".format(winding))
            positive = m3d.assign_coil(
                [terminal_names[winding][0]], conductors_number=1,
                polarity="Positive", name="{}_Positive".format(winding),
            )
            negative = m3d.assign_coil(
                [terminal_names[winding][1]], conductors_number=1,
                polarity="Negative", name="{}_Negative".format(winding),
            )
            if not positive or not negative:
                raise RuntimeError("Failed to assign coil terminals for {}".format(winding))
            m3d.add_winding_coils(source.name, [positive.name, negative.name])

        m3d.eddy_effects_on(copper, enable_eddy_effects=True,
                            enable_displacement_current=False)
        dmr53 = m3d.materials["DMR53"]
        if not dmr53.set_power_ferrite_coreloss(
            cm=DMR53_CM, x=DMR53_X, y=DMR53_Y, kdc=DMR53_KDC,
            cut_depth="1mm",
        ):
            raise RuntimeError("Failed to configure DMR53 Power Ferrite loss model")

        cores = [n for n in m3d.modeler.object_names if n.startswith("Core_")]
        if cores:
            m3d.set_core_losses(cores, True)

        # PyAEDT 1.5 does not dispatch EddyCurrent through assign_matrix(), so
        # create the same Matrix boundary directly, then use its supported
        # reduction API.
        matrix_props = {"MatrixEntry": {"MatrixEntry": [
            {"Source": name} for name in WINDING_SOLIDS
        ]}}
        matrix = m3d._create_boundary("Matrix1", matrix_props, "Matrix")
        if not matrix:
            raise RuntimeError("Failed to create Matrix1")
        matrix.join_parallel(
            sources=["WindingS1", "WindingS2", "WindingS3", "WindingS4"],
            matrix_name="ReduceMatrix1", join_name="WindingS",
        )

        setup = m3d.create_setup(name="Setup1")
        setup.props["Frequency"] = FREQUENCY
        setup.props["MaximumPasses"] = 10
        setup.props["MinimumPasses"] = 2
        setup.props["MinimumConvergedPasses"] = 1
        setup.props["PercentRefinement"] = 30
        setup.props["PercentError"] = 2
        setup.props["SolveMatrixAtLast"] = True
        setup.props["UseHighOrderShapeFunc"] = False
        setup.update()

        # Store both the three matrix terms and the final leakage formula in
        # AEDT Results.  The reduced secondary name is WindingS (no plural).
        expressions = [
            "L(WindingP,WindingP)",
            "L(WindingS,WindingP)",
            "L(WindingS,WindingS)",
            LEAKAGE_EXPRESSION,
        ]
        report = m3d.post.create_report(
            expressions=expressions,
            setup_sweep_name="Setup1 : LastAdaptive",
            report_category="EddyCurrent", plot_type="Data Table",
            context={"Matrix1": "ReduceMatrix1"},
            plot_name="LLC Leakage 3to4",
        )
        if not report:
            raise RuntimeError("Failed to create leakage result table")

        m3d.save_project(str(CONFIGURED_PROJECT))
        print("CONFIGURED_PROJECT={}".format(CONFIGURED_PROJECT))
        print("SETUP=Setup1, {}".format(FREQUENCY))
        print("MATRIX=Matrix1 -> ReduceMatrix1; WindingS1..S4 parallel -> WindingS")
        print("LEAKAGE_EXPRESSION={}".format(LEAKAGE_EXPRESSION))
        print("DMR53_POWER_FERRITE=Cm={}, X={}, Y={}, Kdc={}".format(
            DMR53_CM, DMR53_X, DMR53_Y, DMR53_KDC))
    finally:
        m3d.release_desktop(close_projects=True, close_desktop=True)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    rebuild_geometry()
    configure_project()


if __name__ == "__main__":
    main()

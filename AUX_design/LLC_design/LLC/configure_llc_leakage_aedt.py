"""Configure and solve the LLC transformer short-circuit leakage test in AEDT.

The source geometry is not modified. A copied project is configured as:
  Primary: 1 A current winding
  S1..S4: independent 0 V windings (all secondaries short-circuited)
  Solver: Maxwell 3D Eddy Current, 800 kHz

The primary effective inductance in this condition is Lsc, the primary-referred
leakage inductance. Run with the AEDT CPython and local .deps PyAEDT package.
"""
from pathlib import Path
import shutil

from ansys.aedt.core import Maxwell3d
from ansys.aedt.core.generic.constants import Plane


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "output" / "LLC_Planar_Transformer_Np3_Lm6p5uH_v7.aedt"
TARGET = ROOT / "output" / "LLC_Planar_Transformer_Leakage_800kHz.aedt"
DESIGN = "LLC_Transformer_800kHz"

FREQ = "800kHz"
L1_Z = -1.5880
L8_Z = 1.5880
CU_L1 = 0.069
CU_L8 = 0.069
P_WIDTH = 1.20
S_WIDTH = 0.70

# After Unite, AEDT retains the first object name in each list.
WINDING_SOLIDS = {
    "Primary": "P1_L2_3T",
    "S1": "S1_L2_4T",
    "S2": "S2_L3_4T",
    "S3": "S3_L6_4T",
    "S4": "S4_L7_4T",
}

# Terminal sheets lie on both accessible lead-end cross sections.
# Each entry: start tuple, return tuple; tuple is x, y, z, width, thickness.
TERMINALS = {
    "Primary": ((-30.0, 0.0, L1_Z, P_WIDTH, CU_L1),
                (-30.0, -8.95, L1_Z, P_WIDTH, CU_L1)),
    "S1": ((30.0, 0.0, L1_Z, S_WIDTH, CU_L1),
           (30.0, -9.05, L1_Z, S_WIDTH, CU_L1)),
    "S2": ((30.0, 3.0, L1_Z, S_WIDTH, CU_L1),
           (30.0, -8.20, L1_Z, S_WIDTH, CU_L1)),
    "S3": ((30.0, -3.0, L8_Z, S_WIDTH, CU_L8),
           (30.0, -8.20, L8_Z, S_WIDTH, CU_L8)),
    "S4": ((30.0, 0.0, L8_Z, S_WIDTH, CU_L8),
           (30.0, -9.05, L8_Z, S_WIDTH, CU_L8)),
}


def terminal_sheet(m3d, winding, suffix, data):
    x, y, z, width, thickness = data
    return m3d.modeler.create_rectangle(
        orientation=Plane.YZ,
        origin=[x, y - width / 2.0, z - thickness / 2.0],
        sizes=[width, thickness],
        name="Terminal_{}_{}".format(winding, suffix),
        material="copper",
        is_covered=True,
    )


def main():
    if not SOURCE.exists():
        raise FileNotFoundError(str(SOURCE))
    shutil.copy2(str(SOURCE), str(TARGET))

    m3d = Maxwell3d(
        project=str(TARGET),
        design=DESIGN,
        version="2024.2",
        non_graphical=True,
        new_desktop=True,
        close_on_exit=True,
        remove_lock=True,
    )
    try:
        existing = set(m3d.modeler.object_names)
        missing = [obj for obj in WINDING_SOLIDS.values() if obj not in existing]
        if missing:
            raise RuntimeError("Missing united winding solids: {}".format(missing))

        # Eddy-current external terminals must lie on the problem-region edge.
        # Extend only the simulation terminals from the PCB lead ends to x=+/-30.
        for winding, terminal_pair in TERMINALS.items():
            for suffix, data in zip(("Start", "Return"), terminal_pair):
                x, y, z, width, thickness = data
                x0, length = (-30.0, 0.5) if x < 0 else (29.0, 1.0)
                ext = m3d.modeler.create_box(
                    origin=[x0, y - width / 2.0, z - thickness / 2.0],
                    sizes=[length, width, thickness],
                    name="{}_{}_TerminalExtension".format(winding, suffix),
                    material="copper",
                )
                if not m3d.modeler.unite([WINDING_SOLIDS[winding], ext.name]):
                    raise RuntimeError("Failed to unite {} {} extension".format(winding, suffix))

        # Copper traces/vias occupy real cavities in the laminate. The geometry
        # builder intentionally retained full dielectric slabs for visualization;
        # Maxwell volume solvers require non-overlapping material volumes.
        dielectric_objects = [name for name in existing
                              if name.startswith("PCB_Diel_")]
        copper_objects = list(WINDING_SOLIDS.values())
        for dielectric in dielectric_objects:
            if not m3d.modeler.subtract(dielectric, copper_objects,
                                        keep_originals=True):
                raise RuntimeError("Failed to clear copper from {}".format(dielectric))

        if "Region" not in existing:
            m3d.modeler.create_region(
                pad_value=[0, 0, 20, 20, 20, 20],
                pad_type="Absolute Offset",
                name="Region",
            )

        terminal_names = {}
        for winding, terminal_pair in TERMINALS.items():
            terminal_names[winding] = []
            for suffix, data in zip(("Start", "Return"), terminal_pair):
                sheet = terminal_sheet(m3d, winding, suffix, data)
                terminal_names[winding].append(sheet.name)

        # Primary excitation. Its two physical PCB spirals are already united
        # and are represented as two parallel branches.
        primary = m3d.assign_winding(
            assignment=None,
            winding_type="Current",
            is_solid=True,
            current=1,
            resistance=0,
            inductance=0,
            parallel_branches=2,
            phase=0,
            name="Primary_1A",
        )
        if not primary:
            raise RuntimeError("Failed to assign Primary winding")
        p_pos = m3d.assign_coil([terminal_names["Primary"][0]], conductors_number=1,
                               polarity="Positive", name="Primary_Positive")
        p_neg = m3d.assign_coil([terminal_names["Primary"][1]], conductors_number=1,
                               polarity="Negative", name="Primary_Negative")
        m3d.add_winding_coils(primary.name, [p_pos.name, p_neg.name])

        # A zero-voltage winding is the Maxwell short-circuit condition. Keep
        # all four outputs separate so no unintended copper connection is made.
        for winding in ("S1", "S2", "S3", "S4"):
            boundary = m3d.assign_winding(
                assignment=None,
                winding_type="Voltage",
                is_solid=True,
                current=0,
                resistance=0,
                inductance=0,
                voltage=0,
                parallel_branches=1,
                phase=0,
                name="{}_Short_0V".format(winding),
            )
            if not boundary:
                raise RuntimeError("Failed to assign {} short".format(winding))
            coil_pos = m3d.assign_coil([terminal_names[winding][0]], conductors_number=1,
                                      polarity="Positive", name="{}_Positive".format(winding))
            coil_neg = m3d.assign_coil([terminal_names[winding][1]], conductors_number=1,
                                      polarity="Negative", name="{}_Negative".format(winding))
            m3d.add_winding_coils(boundary.name, [coil_pos.name, coil_neg.name])

        copper = list(WINDING_SOLIDS.values())
        m3d.eddy_effects_on(copper, enable_eddy_effects=True,
                            enable_displacement_current=False)
        core_objects = [name for name in m3d.modeler.object_names
                        if name.startswith("Core_")]
        if core_objects:
            m3d.set_core_losses(core_objects, False)

        setup = m3d.create_setup(name="Leakage_800kHz")
        setup.props["Frequency"] = FREQ
        setup.props["MaximumPasses"] = 10
        setup.props["MinimumPasses"] = 2
        setup.props["MinimumConvergedPasses"] = 2
        setup.props["PercentError"] = 1
        setup.props["UseHighOrderShapeFunc"] = True
        setup.update()

        m3d.save_project(str(TARGET))
        print("CONFIGURED_PROJECT={}".format(TARGET))
        print("SETUP=Leakage_800kHz")
        print("PRIMARY=1A; S1,S2,S3,S4=0V short circuit")
        print("Run Leakage_800kHz and read the primary effective inductance as Lsc.")
    finally:
        m3d.release_desktop(close_projects=True, close_desktop=True)


if __name__ == "__main__":
    main()

"""Clone solved V6 settings, update only the 6.5 uH gap and 800 kHz setup."""
from pathlib import Path
import shutil
from ansys.aedt.core import Maxwell3d

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "output" / "LLC_Planar_Transformer_Np3_Connected_Gap_v6_united.aedt"
TARGET = ROOT / "output" / "LLC_Planar_Transformer_Lm6p5uH_MatrixLeakage_800kHz.aedt"

OLD_GAP = 0.036
NEW_GAP = 0.052554
DELTA = (NEW_GAP - OLD_GAP) / 2.0

shutil.copy2(str(SOURCE), str(TARGET))
m3d = Maxwell3d(project=str(TARGET), design="LLC_Transformer_800kHz",
                version="2024.2", non_graphical=True, new_desktop=True,
                close_on_exit=True, remove_lock=True)
try:
    upper = ["Core_Upper_Yoke", "Core_Upper_Leg_P", "Core_Upper_Leg_S"]
    lower = ["Core_Lower_Yoke", "Core_Lower_Leg_P", "Core_Lower_Leg_S"]
    if not m3d.modeler.move(upper, [0, 0, DELTA]):
        raise RuntimeError("Failed to move upper U core")
    if not m3d.modeler.move(lower, [0, 0, -DELTA]):
        raise RuntimeError("Failed to move lower U core")

    old_air_gaps = [name for name in m3d.modeler.object_names
                    if name.startswith("AirGap_")]
    if old_air_gaps:
        m3d.modeler.delete(old_air_gaps)
    g2 = NEW_GAP / 2.0
    m3d.modeler.create_box([-18.0, -5.0, -g2], [10.0, 10.0, NEW_GAP],
                           name="AirGap_PrimaryLeg_0p052554mm", material="vacuum")
    m3d.modeler.create_box([8.0, -5.0, -g2], [10.0, 10.0, NEW_GAP],
                           name="AirGap_SecondaryLeg_0p052554mm", material="vacuum")

    setup = m3d.get_setup("Setup1")
    setup.props["Frequency"] = "800kHz"
    setup.update()
    m3d.save_project(str(TARGET))
    print("TARGET={}".format(TARGET))
    print("PRESERVED: WindingP, WindingS1..S4, Matrix1, ReduceMatrix1")
    print("UPDATED: each joint gap={} mm; Setup1 frequency=800kHz".format(NEW_GAP))
finally:
    m3d.release_desktop(close_projects=True, close_desktop=True)

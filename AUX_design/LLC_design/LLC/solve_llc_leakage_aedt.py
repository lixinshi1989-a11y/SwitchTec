"""Solve the configured 800 kHz short-circuit leakage model and export results."""
from pathlib import Path
from ansys.aedt.core import Maxwell3d

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT / "output" / "LLC_Planar_Transformer_Leakage_800kHz.aedt"
OUT = ROOT / "output" / "LLC_leakage_results"
OUT.mkdir(exist_ok=True)

m3d = Maxwell3d(project=str(PROJECT), design="LLC_Transformer_800kHz",
                version="2024.2", non_graphical=True, new_desktop=True,
                close_on_exit=True, remove_lock=True)
try:
    ok = m3d.analyze_setup("Leakage_800kHz", cores=4)
    print("ANALYZE_RETURN={}".format(ok))
    m3d.save_project(str(PROJECT))
    try:
        quantities = m3d.post.available_report_quantities(
            report_category="EddyCurrent", display_type="Data Table"
        )
    except Exception:
        quantities = m3d.post.available_report_quantities(display_type="Data Table")
    selected = [q for q in quantities if any(k in q.lower() for k in
                ("induct", "flux", "current", "winding", "primary"))]
    quantity_file = OUT / "available_inductance_quantities.txt"
    quantity_file.write_text("\n".join(selected), encoding="utf-8")
    print("AVAILABLE_QUANTITIES={}".format(selected))
    exports = m3d.export_results(export_folder=str(OUT))
    print("EXPORTED_RESULTS={}".format(exports))
finally:
    m3d.release_desktop(close_projects=True, close_desktop=True)

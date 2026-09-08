"""Read the user's solved V6 Maxwell setup without modifying it."""
from pathlib import Path
from ansys.aedt.core import Maxwell3d

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT / "output" / "LLC_Planar_Transformer_Np3_Connected_Gap_v6_united.aedt"
REPORT = ROOT / "output" / "V6_solver_settings.txt"

m3d = Maxwell3d(project=str(PROJECT), version="2024.2", non_graphical=True,
                new_desktop=True, close_on_exit=True, remove_lock=False)
lines = []
try:
    lines.append("project=" + str(PROJECT))
    lines.append("design=" + str(m3d.design_name))
    lines.append("solution_type=" + str(m3d.solution_type))
    lines.append("setups=" + repr(m3d.setup_names))
    for setup_name in m3d.setup_names:
        setup = m3d.get_setup(setup_name)
        lines.append("setup[{}]={}".format(setup_name, repr(dict(setup.props))))
    lines.append("boundaries:")
    for boundary in m3d.boundaries:
        lines.append("  {} type={} props={}".format(
            boundary.name, boundary.type, repr(dict(boundary.props))))
    try:
        lines.append("reports=" + repr(m3d.post.all_report_names))
    except Exception as exc:
        lines.append("reports_error=" + repr(exc))
    for category in ("EddyCurrent", None):
        try:
            kwargs = {"display_type": "Data Table"}
            if category:
                kwargs["report_category"] = category
            quantities = m3d.post.available_report_quantities(**kwargs)
            lines.append("quantities[{}]={}".format(category, repr(quantities)))
        except Exception as exc:
            lines.append("quantities_error[{}]={}".format(category, repr(exc)))
    # Native modules reveal matrix parameters and report definitions that are
    # not always represented as high-level PyAEDT boundary objects.
    for module_name in ("MaxwellParameterSetup", "ReportSetup", "BoundarySetup"):
        try:
            module = m3d.odesign.GetModule(module_name)
            lines.append("module[{}]={}".format(module_name, repr(module)))
            for method in ("GetSetupNames", "GetAllReportNames", "GetBoundaries"):
                try:
                    lines.append("  {}={}".format(method, repr(getattr(module, method)())))
                except Exception:
                    pass
        except Exception as exc:
            lines.append("module_error[{}]={}".format(module_name, repr(exc)))
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines))
finally:
    m3d.release_desktop(close_projects=True, close_desktop=True)

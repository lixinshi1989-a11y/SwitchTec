"""Extract complex primary short-circuit inductance from the solved AEDT model."""
from pathlib import Path
import cmath
from ansys.aedt.core import Maxwell3d

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT / "output" / "LLC_Planar_Transformer_Leakage_800kHz.aedt"
OUT = ROOT / "output" / "LLC_leakage_results"
OUT.mkdir(exist_ok=True)

m3d = Maxwell3d(project=str(PROJECT), design="LLC_Transformer_800kHz",
                version="2024.2", non_graphical=True, new_desktop=True,
                close_on_exit=True, remove_lock=True)
try:
    expressions = ["FluxLinkage(Primary_1A)", "InputCurrent(Primary_1A)"]
    data = m3d.post.get_solution_data(
        expressions=expressions,
        report_category="EddyCurrent",
        setup_sweep_name="Leakage_800kHz : LastAdaptive",
    )
    if not data:
        raise RuntimeError("AEDT returned no solution data")
    values = {}
    for expression in expressions:
        _, re = data.get_expression_data(expression, "real", convert_to_SI=True)
        _, im = data.get_expression_data(expression, "imag", convert_to_SI=True)
        if len(re) == 0:
            raise RuntimeError("No data for {}".format(expression))
        values[expression] = complex(float(re[0]), float(im[0]) if len(im) else 0.0)

    flux = values[expressions[0]]
    current = values[expressions[1]]
    lsc = flux / current
    text = (
        "AEDT Maxwell 3D short-circuit leakage result\n"
        "Frequency_Hz=800000\n"
        "Secondary_condition=S1,S2,S3,S4 independent 0V shorts\n"
        "Primary_current_A={}\n"
        "Primary_flux_linkage_Wb_turn={}\n"
        "Lsc_complex_H={}\n"
        "Lsc_real_uH={:.9g}\n"
        "Lsc_magnitude_uH={:.9g}\n"
        "Lsc_phase_deg={:.9g}\n"
    ).format(current, flux, lsc, lsc.real * 1e6, abs(lsc) * 1e6,
             cmath.phase(lsc) * 180.0 / 3.141592653589793)
    result_file = OUT / "LLC_leakage_800kHz_result.txt"
    result_file.write_text(text, encoding="utf-8")
    data.export_data_to_csv(str(OUT / "LLC_leakage_raw_solution.csv"))
    print(text)
    print("RESULT_FILE={}".format(result_file))
finally:
    m3d.release_desktop(close_projects=True, close_desktop=True)

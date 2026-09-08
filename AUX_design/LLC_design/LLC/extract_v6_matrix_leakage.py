"""Extract V6 reduced inductance matrix and evaluate the user's leakage formula."""
from pathlib import Path
from ansys.aedt.core import Maxwell3d

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT / "output" / "LLC_Planar_Transformer_Np3_Connected_Gap_v6_united.aedt"
OUT = ROOT / "output" / "LLC_leakage_results" / "V6_matrix_leakage.txt"
EXPRESSIONS = [
    "L(WindingP,WindingP)",
    "L(WindingS,WindingP)",
    "L(WindingS,WindingS)",
]

m3d = Maxwell3d(project=str(PROJECT), design="LLC_Transformer_800kHz",
                version="2024.2", non_graphical=True, new_desktop=True,
                close_on_exit=True, remove_lock=False)
try:
    data = m3d.post.get_solution_data(
        expressions=EXPRESSIONS,
        report_category="EddyCurrent",
        setup_sweep_name="Setup1 : LastAdaptive",
        context={"Matrix1": "ReduceMatrix1"},
    )
    if not data:
        raise RuntimeError("No V6 reduced-matrix solution data")
    values = {}
    for expression in EXPRESSIONS:
        _, re = data.get_expression_data(expression, "real", convert_to_SI=True)
        _, im = data.get_expression_data(expression, "imag", convert_to_SI=True)
        if len(re) == 0:
            raise RuntimeError("No data for {}".format(expression))
        values[expression] = complex(float(re[0]), float(im[0]) if len(im) else 0.0)
    lpp, lsp, lss = (values[e] for e in EXPRESSIONS)
    ratio = 3.0 / 4.0
    leakage = lpp - 2.0 * ratio * lsp + ratio * ratio * lss
    text = (
        "V6 reduced-matrix leakage calculation\n"
        "Setup=Setup1 : LastAdaptive\n"
        "Frequency_Hz=1000000\n"
        "ReducedMatrix=Matrix1:ReduceMatrix1 (S1..S4 joined in parallel as WindingS)\n"
        "Lpp_H={}\nLsp_H={}\nLss_H={}\n"
        "Formula=Lpp-2*(3/4)*Lsp+(3/4)^2*Lss\n"
        "Leakage_H={}\nLeakage_uH_real={:.9g}\nLeakage_uH_magnitude={:.9g}\n"
    ).format(lpp, lsp, lss, leakage, leakage.real * 1e6, abs(leakage) * 1e6)
    OUT.write_text(text, encoding="utf-8")
    data.export_data_to_csv(str(OUT.with_suffix(".csv")))
    print(text)
finally:
    m3d.release_desktop(close_projects=True, close_desktop=True)

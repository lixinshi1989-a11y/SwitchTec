"""Solve the 8 x 12 mm rectangular-leg model with 4.6 mm P-S spacing."""
from pathlib import Path
import sys

from ansys.aedt.core import Maxwell3d


ROOT = Path(__file__).resolve().parent
PROJECT = ROOT / "output" / "LLC_Rectangular_8x12_PSgap4p6_800kHz.aedt"
OUT = ROOT / "output" / "LLC_rectangular_8x12_gap4p6_results"
DESIGN = "LLC_Transformer_800kHz"
SETUP = "Setup1"
SOLUTION = "Setup1 : LastAdaptive"
RATIO = 3.0 / 4.0
TARGET_H = 1.0e-6
EXPRESSIONS = [
    "L(WindingP,WindingP)",
    "L(WindingS,WindingP)",
    "L(WindingS,WindingS)",
]
LEAKAGE_EXPRESSION = (
    "L(WindingP,WindingP)+2*(3/4)*L(WindingS,WindingP)"
    "+(3/4)*(3/4)*L(WindingS,WindingS)"
)


def first_complex(data, expression):
    _, real = data.get_expression_data(expression, "real", convert_to_SI=True)
    _, imag = data.get_expression_data(expression, "imag", convert_to_SI=True)
    if len(real) == 0:
        raise RuntimeError("No solution data for {}".format(expression))
    return complex(float(real[0]), float(imag[0]) if len(imag) else 0.0)


def main(solve=True):
    if not PROJECT.exists():
        raise FileNotFoundError(str(PROJECT))
    OUT.mkdir(parents=True, exist_ok=True)
    m3d = Maxwell3d(
        project=str(PROJECT), design=DESIGN, version="2024.2",
        non_graphical=True, new_desktop=True, close_on_exit=True,
        remove_lock=True,
    )
    try:
        if solve:
            solved = m3d.analyze_setup(SETUP, cores=4)
            if not solved:
                raise RuntimeError("AEDT did not complete {}".format(SETUP))
            m3d.save_project(str(PROJECT))

        data = m3d.post.get_solution_data(
            expressions=EXPRESSIONS,
            report_category="EddyCurrent",
            setup_sweep_name=SOLUTION,
            context={"Matrix1": "ReduceMatrix1"},
        )
        if not data:
            raise RuntimeError("AEDT returned no reduced-matrix solution data")

        lpp, lsp, lss = [first_complex(data, name) for name in EXPRESSIONS]
        # AEDT's mutual-inductance sign follows the assigned terminal
        # reference directions. Leakage is the flux-cancelling combination,
        # so use the mutual magnitude rather than assuming a positive Lsp.
        leakage = lpp + RATIO * RATIO * lss - 2.0 * RATIO * abs(lsp)
        deviation = (leakage.real / TARGET_H - 1.0) * 100.0
        coupling = lsp.real / max((lpp.real * lss.real) ** 0.5, 1e-30)
        text = (
            "AEDT rectangular 8 x 12 mm LLC, 4.6 mm P-S copper gap\n"
            "Frequency_Hz=800000\n"
            "CoreLength_mm=32\n"
            "WindingCentreSpacing_mm=24\n"
            "PSCopperGap_mm=4.6\n"
            "Setup=Setup1 : LastAdaptive\n"
            "ReducedMatrix=Matrix1:ReduceMatrix1\n"
            "SecondaryReduction=WindingS1..WindingS4 in parallel as WindingS\n"
            "Lpp_H={}\n"
            "Lsp_H={}\n"
            "Lss_H={}\n"
            "CouplingFromRealMatrix={:.9g}\n"
            "Formula=Lpp+(3/4)^2*Lss-2*(3/4)*abs(Lsp)\n"
            "Leakage_H={}\n"
            "Leakage_uH_real={:.9g}\n"
            "Leakage_uH_magnitude={:.9g}\n"
            "Target_uH=1\n"
            "DeviationFromTarget_percent={:.9g}\n"
        ).format(
            lpp, lsp, lss, coupling, leakage,
            leakage.real * 1e6, abs(leakage) * 1e6, deviation,
        )
        result_file = OUT / "LLC_rectangular_8x12_gap4p6_leakage_800kHz.txt"
        result_file.write_text(text, encoding="utf-8")
        data.export_data_to_csv(str(OUT / "LLC_rectangular_8x12_gap4p6_matrix.csv"))

        # Keep the table stored in the AEDT project consistent with the
        # negative mutual-inductance sign produced by its terminal references.
        m3d.post.delete_report("LLC Leakage 3to4")
        report = m3d.post.create_report(
            expressions=EXPRESSIONS + [LEAKAGE_EXPRESSION],
            setup_sweep_name=SOLUTION,
            report_category="EddyCurrent", plot_type="Data Table",
            context={"Matrix1": "ReduceMatrix1"},
            plot_name="LLC Leakage 3to4",
        )
        if not report:
            raise RuntimeError("Failed to update the AEDT leakage result table")
        m3d.save_project(str(PROJECT))
        print(text)
        print("RESULT_FILE={}".format(result_file))
    finally:
        m3d.release_desktop(close_projects=True, close_desktop=True)


if __name__ == "__main__":
    main(solve="--extract-only" not in sys.argv)

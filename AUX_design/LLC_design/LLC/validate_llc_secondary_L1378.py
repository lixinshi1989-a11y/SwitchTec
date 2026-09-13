"""Read-only validation of a temporary copy of the completed Maxwell project."""
from pathlib import Path
import shutil
from ansys.aedt.core import Maxwell3d
from build_llc_rectangular_7x14_secondary_L1378 import ROOT, STEM

project = ROOT / 'output' / (STEM + '_800kHz.aedt')
copy = ROOT.parent / 'tmp' / (STEM + '_validation.aedt')
shutil.copy2(project, copy)
app = Maxwell3d(project=str(copy), design='LLC_Transformer_800kHz',
                version='2024.2', non_graphical=True, new_desktop=True,
                close_on_exit=True)
try:
    result = app.validate_simple(ROOT/'output'/'secondary_L1378_validation.log')
    print('AEDT_VALIDATE_RESULT={}'.format(result), flush=True)
    assert result == 1, 'AEDT design validation failed'
finally:
    app.release_desktop(close_projects=True, close_desktop=True)

"""Configure the latest connected Compact C geometry; add --solve to solve it."""
import sys
import configure_solve_flyback_48_4_3_leakage as workflow

workflow.OUT = workflow.ROOT / 'output' / '36_3_2_compact'
workflow.SOURCE = workflow.OUT / 'Flyback_36_3_2_Compact70mm_Connected_100kHz.aedt'
workflow.TARGET = workflow.OUT / 'Flyback_36_3_2_Compact70mm_Configured_100kHz.aedt'
workflow.RESULT = workflow.OUT / 'leakage_results'
workflow.DESIGN = 'Flyback_C_EE_100kHz'
workflow.LABEL = 'Flyback 36:3:2 Compact C / 100 kHz'
workflow.SOLIDS = {'WindingP':'Primary_A_L2_18T',
    'WindingS':'Secondary_A_L6_3T','WindingA':'AUX_A_L4_1T'}
workflow.TERMINALS = {'WindingP':[(-20.9,-31,1.1755),(20.9,-31,.7055)],
    'WindingS':[(4.55,31,-2.157),(-4.55,31,-2.157)],
    'WindingA':[(-3,-31,1.588),(3,-31,1.588)]}
if '--solve' not in sys.argv and '--extract-only' not in sys.argv:
    sys.argv.append('--configure-only')
workflow.main()

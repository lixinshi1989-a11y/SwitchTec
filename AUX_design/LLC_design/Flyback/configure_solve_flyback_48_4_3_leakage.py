"""Configure RoutingV3 using the local LLC matrix workflow, then solve at 100 kHz.

Run with AEDT CPython. AUX has zero terminal current (open circuit).
Physical parallel secondary copper is one solid winding, not three circuit branches.
"""
from pathlib import Path
import sys
import shutil
import math
import json

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT.parent / '.deps'))
from ansys.aedt.core import Maxwell3d

OUT = ROOT / 'output' / '48_4_3'
SOURCE = OUT / 'Flyback_48_4_3_Scheme_B_AUX_Xm28_RoutingV3_100kHz.aedt'
TARGET = OUT / 'Flyback_48_4_3_Scheme_B_RoutingV3_Leakage_100kHz.aedt'
RESULT = OUT / 'leakage_results'
SETUP = 'Leakage_100kHz'
DESIGN = 'Flyback_48_4_3_B_100kHz'
LABEL = 'Flyback 48:4:3 Scheme B / RoutingV3 / 100 kHz'
SOLIDS = {'WindingP': 'Primary_Left_L2_12T',
          'WindingS': 'Secondary_Right_L6_4T', 'WindingA': 'AUX_Left_L6_2T'}
TERMINALS = {'WindingP': [(-15.6, -31.5, 1.588), (15.6, -31.5, 1.588)],
             'WindingS': [(17.6, 31.5, -2.157), (13.6, 31.5, -2.157)],
             'WindingA': [(-17.6, -31.5, -1.588), (-13.6, -31.5, -1.588)]}


def required(value, message):
    if not value:
        raise RuntimeError(message)
    return value


def main():
    extract_only = '--extract-only' in sys.argv
    RESULT.mkdir(exist_ok=True)
    if not extract_only:
        if TARGET.exists():
            raise FileExistsError('Preserve existing configured project: ' + str(TARGET))
        shutil.copy2(SOURCE, TARGET)
    app = Maxwell3d(project=str(TARGET), design=DESIGN,
                    version='2024.2', non_graphical=True, new_desktop=True,
                    close_on_exit=True, remove_lock=False)
    try:
        if not extract_only:
            required(app.modeler.create_region(pad_value=[20, 20, 0, 0, 20, 20],
                     pad_type='Absolute Offset', name='Region'), 'Region creation failed')
            for winding, solid in SOLIDS.items():
                coils = []
                for polarity, xyz in zip(['Positive', 'Negative'], TERMINALS[winding]):
                    faces = [f for f in app.modeler[solid].faces
                             if max(abs(a-b) for a,b in zip(f.center, xyz)) < 1e-5]
                    if len(faces) != 1:
                        raise RuntimeError('Terminal face mismatch: {} {} {}'.format(winding, xyz, len(faces)))
                    sheet = required(app.modeler.create_object_from_face(faces[0].id), 'Terminal sheet failed')
                    sheet.name = 'Terminal_' + winding + '_' + polarity
                    coil = required(app.assign_coil([sheet.name], conductors_number=1,
                                    polarity=polarity, name=winding+'_'+polarity), 'Coil failed')
                    coils.append(coil.name)
                boundary = required(app.assign_winding(assignment=None, winding_type='Current',
                    is_solid=True, current=1 if winding=='WindingP' else 0,
                    resistance=0, inductance=0, parallel_branches=1, phase=0,
                    name=winding), 'Winding failed')
                required(app.add_winding_coils(boundary.name, coils), 'Winding association failed')
            required(app.eddy_effects_on(list(SOLIDS.values()), enable_eddy_effects=True,
                     enable_displacement_current=False), 'Eddy configuration failed')
            app.set_core_losses(['Core_Upper_Yoke', 'Core_Lower_Yoke'], False)
            required(app._create_boundary('Matrix1', {'MatrixEntry': {'MatrixEntry':
                     [{'Source': name} for name in SOLIDS]}}, 'Matrix'), 'Matrix failed')
            setup = app.create_setup(name=SETUP)
            setup.props.update({'Frequency': '100kHz', 'MaximumPasses': 10,
                'MinimumPasses': 2, 'MinimumConvergedPasses': 2, 'PercentRefinement': 30,
                'PercentError': 1, 'SolveMatrixAtLast': True, 'UseHighOrderShapeFunc': False})
            required(setup.update(), 'Setup failed')
            pp,ss,ps,sp = ('L(WindingP,WindingP)','L(WindingS,WindingS)',
                           'L(WindingP,WindingS)','L(WindingS,WindingP)')
            required(app.post.create_report(expressions=[pp,ss,ps,
                pp+'-'+ps+'*'+sp+'/'+ss, ss+'-'+sp+'*'+ps+'/'+pp],
                setup_sweep_name=SETUP+' : LastAdaptive', report_category='EddyCurrent',
                plot_type='Data Table', context='Matrix1',
                plot_name='Primary Secondary Leakage - lossless short circuit'), 'Report failed')
            app.save_project()
            print('CONFIGURED_PROJECT=' + str(TARGET), flush=True)
            if '--configure-only' in sys.argv:
                return
            required(app.analyze_setup(SETUP, cores=4), 'Solve failed')
            app.save_project()
        expressions = [kind+'('+a+','+b+')' for kind in ['L','R'] for a in SOLIDS for b in SOLIDS]
        data = required(app.post.get_solution_data(expressions=expressions,
            report_category='EddyCurrent', setup_sweep_name=SETUP+' : LastAdaptive',
            context='Matrix1'), 'No matrix solution data')
        values = {}
        for expr in expressions:
            _, real = data.get_expression_data(expr, 'real', convert_to_SI=True)
            if len(real)==0:
                raise RuntimeError('Missing matrix value: '+expr)
            values[expr] = float(real[0])
        data.export_data_to_csv(str(RESULT / 'matrix_100kHz.csv'))
        lpp, lss = values['L(WindingP,WindingP)'], values['L(WindingS,WindingS)']
        mps, msp = values['L(WindingP,WindingS)'], values['L(WindingS,WindingP)']
        omega = 2*math.pi*100000
        def impedance(a,b):
            return complex(values['R('+a+','+b+')'], omega*values['L('+a+','+b+')'])
        zpp,zss = impedance('WindingP','WindingP'),impedance('WindingS','WindingS')
        zps,zsp = impedance('WindingP','WindingS'),impedance('WindingS','WindingP')
        result = dict(frequency_Hz=100000, aux_condition='open: zero terminal current',
            source=str(SOURCE), project=str(TARGET), matrix_SI=values,
            primary_short_circuit_leakage_H=(zpp-zps*zsp/zss).imag/omega,
            secondary_short_circuit_leakage_H=(zss-zsp*zps/zpp).imag/omega,
            primary_lossless_short_circuit_H=lpp-mps*msp/lss,
            secondary_lossless_short_circuit_H=lss-mps*msp/lpp,
            primary_LLC_flux_cancelling_H=lpp+144*lss-12*abs(mps+msp),
            secondary_LLC_flux_cancelling_H=(lpp+144*lss-12*abs(mps+msp))/144,
            coupling_abs=abs((mps+msp)/2)/math.sqrt(lpp*lss),
            note='Linear mu_r=3300; actual V3 leads included; convergence must be checked.')
        (RESULT/'leakage_100kHz.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
        summary = [LABEL,
            'AUX open. Linear TPG33 mu_r=3300. V3 terminal leads included.',
            'Short-circuit: Zp_sc=Zpp-Zps*Zsp/Zss; Zs_sc=Zss-Zsp*Zps/Zpp; L=Im(Z)/omega.',
            'LLC comparison: Lp=Lpp+12^2*Lss-2*12*abs(M); Ls=Lp/12^2.',
            'These are total leakage referred to each port, not two independent series components.']
        summary += ['{} = {:.9g} uH'.format(key, value*1e6)
                    for key,value in result.items() if key.endswith('_H')]
        (RESULT/'leakage_100kHz.txt').write_text('\n'.join(summary)+'\n',encoding='utf-8')
        app.export_convergence(SETUP, output_file=str(RESULT/'convergence.txt'))
        app.post.create_report(expressions=expressions, setup_sweep_name=SETUP+' : LastAdaptive',
            report_category='EddyCurrent', plot_type='Data Table', context='Matrix1',
            plot_name='Flyback Inductance and Resistance Matrix')
        app.save_project()
        print(json.dumps(result,indent=2), flush=True)
    finally:
        app.release_desktop(close_projects=True, close_desktop=True)


if __name__ == '__main__':
    main()

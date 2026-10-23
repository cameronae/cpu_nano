#!/usr/bin/env python3
"""Gowin-family resource estimate. This does not run vendor place-and-route."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--target', choices=['core', 'board'], default='board')
parser.add_argument('--predictor', type=int, choices=[0, 1, 2], default=1)
args = parser.parse_args()
top = 'Datapath' if args.target == 'core' else 'TangNano20K'
# Resolve sources relative to the repository even when called from elsewhere.
files = [Path('Datapath.v'), *[p.relative_to(ROOT) for p in sorted((ROOT/'rtl').glob('*.v'))]]
if args.target == 'board':
    files += [p.relative_to(ROOT) for p in sorted((ROOT/'fpga').glob('*.v'))]
out = ROOT/'build'/'synth'/f'{args.target}-p{args.predictor}'
out.mkdir(parents=True, exist_ok=True)
netlist = out/'netlist.json'
command = ('read_verilog -Irtl ' + ' '.join(str(p) for p in files) +
           f'; chparam -set PREDICTOR {args.predictor} {top}; ' +
           f'synth_gowin -family gw2a -top {top} ' +
           ('-noiopads ' if args.target == 'core' else '') +
           f'-json {netlist.relative_to(ROOT)}')
with (out/'synthesis.log').open('w') as log:
    subprocess.run(['yosys', '-Q', '-T', '-p', command], cwd=ROOT,
                   stdout=log, stderr=subprocess.STDOUT, check=True)
cells = Counter(c['type'] for c in json.loads(netlist.read_text())['modules'][top]['cells'].values())
source_hash = hashlib.sha256()
for p in [*files, Path('rtl/cpu_defs.vh')]:
    source_hash.update(str(p).encode())
    source_hash.update((ROOT/p).read_bytes())
if args.target == 'board':
    source_hash.update((ROOT/'programs/demo.hex').read_bytes())
report = {
    'top': top, 'predictor': args.predictor,
    'tool': subprocess.check_output(['yosys', '-V'], text=True).strip(),
    'source_sha256': source_hash.hexdigest(),
    'lut1_to_lut4_cells': sum(cells[f'LUT{n}'] for n in range(1, 5)),
    'alu_carry_cells': cells['ALU'],
    'flip_flop_cells': sum(n for t,n in cells.items() if t.startswith('DFF')),
    'block_ram_primitives': sum(n for t,n in cells.items() if t.startswith(('SPX','SDPX','DPX'))),
    'distributed_ram_primitives': sum(n for t,n in cells.items() if t.startswith('RAM16')),
    'cells': dict(sorted(cells.items())),
    'limitation': 'Gowin-family synthesis estimate; no vendor packing, placement, routing or timing closure.'
}
(out/'summary.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ('cells','source_sha256')}, indent=2))
print(f'Full logs and netlist: {out.relative_to(ROOT)}')

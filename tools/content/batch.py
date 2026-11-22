"""Prints words that still need authored content: python -I tools/content/batch.py <start> <count> [ext]
Core = NGSL 1.2 order (rank 1..2809); 'basic' = the 50 NGSL supplementary words; ext = NGSL-GR words not in NGSL."""
import csv, sys, re
from pathlib import Path
R = Path(__file__).resolve().parents[2] / 'content'
S = R / 'sources'
d = {r[0].lower(): r[1] for r in csv.reader(open(S / 'NGSL_12_definitions.csv', encoding='utf-8'))}
ng = [r['Lemma'] for r in csv.DictReader(open(S / 'NGSL_12_stats.csv', encoding='utf-8-sig'))]
gr = [r['Word'] for r in csv.DictReader(open(S / 'NGSL-GR_rank.csv', encoding='utf-8-sig'))]
done = set()
for f in (R / 'authored').glob('words_*.tsv'):
    for line in open(f, encoding='utf-8'):
        if line.strip() and not line.startswith('#'):
            done.add(line.split('\t')[0].lower())
mode = sys.argv[3] if len(sys.argv) > 3 else 'core'
if mode == 'core':
    lst = ng
elif mode == 'basic':
    lst = gr[:50]
else:
    s = set(ng); lst = [w for w in gr[50:] if w not in s]
start, n = int(sys.argv[1]), int(sys.argv[2])
skip = {l.strip() for l in open(S / 'skip.txt', encoding='utf-8') if l.strip() and not l.startswith('#')}
todo = [(i + 1, w) for i, w in enumerate(lst) if w.lower() not in done and w.lower() not in skip]
print('remaining', len(todo), 'of', len(lst))
sel = [t for t in todo if t[0] >= start][:n]
print(f'ranks {sel[0][0]}-{sel[-1][0]}:' if sel else 'none')
print(', '.join(w for _, w in sel))

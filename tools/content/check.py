"""Validates authored word files: 5 tab fields, a known part of speech, exactly one [target] in the example."""
import re, sys
from pathlib import Path
POS = {'n', 'v', 'adj', 'adv', 'prep', 'pron', 'det', 'conj', 'num', 'modal', 'int', 'aux'}
bad = 0
seen = {}
for f in sorted((Path(__file__).resolve().parents[2] / 'content' / 'authored').glob('words_*.tsv')):
    for n, line in enumerate(open(f, encoding='utf-8'), 1):
        if not line.strip() or line.startswith('#'):
            continue
        p = line.rstrip('\n').split('\t')
        err = []
        if len(p) != 5: err.append(f'{len(p)} fields')
        else:
            if p[1] not in POS: err.append('pos ' + p[1])
            if len(re.findall(r'\[[^\]]+\]', p[4])) != 1: err.append('targets')
            if ' / ' in p[4]: err.append('slash')
            if p[0].lower() in seen: err.append('dup of ' + seen[p[0].lower()])
            seen[p[0].lower()] = f.name
        if err:
            bad += 1; print(f'{f.name}:{n}: {p[0]}: {", ".join(err)}')
print('entries', len(seen), 'problems', bad)

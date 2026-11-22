"""Builds the app's bundled content from the vendored sources and the authored files.

Usage: python -I tools/content/build.py
Writes Corewords/Resources/{words,phrasal,lessons,phonetics}.json.

Word order and coverage come from the NGSL 1.2 and NGSL-GR 1.0 lists (Browne, Culligan & Phillips, CC BY-SA 4.0).
IPA: content/sources/pron_us.tsv (from CMUdict) and pron_uk.tsv (from Britfone), see tools/content/pron.py.
Definitions, examples and Turkish translations are original (content/authored), CC BY-SA 4.0.
"""
import csv, json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC, AUTH, OUT = ROOT / 'content' / 'sources', ROOT / 'content' / 'authored', ROOT / 'Corewords' / 'Resources'

# Hand-checked IPA for words the dictionaries don't have.
IPA_FIX = {
    'café': ('kæˈfeɪ', 'ˈkæfeɪ'),
    'handwrite': ('ˈhændˌraɪt', 'ˈhændˌraɪt'),
}


def tsv(path):
    for line in open(path, encoding='utf-8'):
        if line.strip() and not line.startswith('#'):
            yield line.rstrip('\n').split('\t')


def load_pron(name):
    return {w: ipa for w, ipa in tsv(SRC / name)}


def ipa_for(phrase, table):
    parts = []
    for w in phrase.lower().split():
        if w not in table:
            return ''
        parts.append(table[w])
    return ' '.join(parts)


def main():
    us, uk = load_pron('pron_us.tsv'), load_pron('pron_uk.tsv')
    skip = {l.strip() for l in open(SRC / 'skip.txt', encoding='utf-8') if l.strip() and not l.startswith('#')}

    stats = list(csv.DictReader(open(SRC / 'NGSL_12_stats.csv', encoding='utf-8-sig')))
    ngsl = [r['Lemma'] for r in stats]
    freq = [float(r['Adjusted Frequency per Million (U)']) for r in stats]
    total = sum(freq)
    gr = [r['Word'] for r in csv.DictReader(open(SRC / 'NGSL-GR_rank.csv', encoding='utf-8-sig'))]
    basic, ext = gr[:50], [w for w in gr[50:] if w not in set(ngsl)]

    forms = {}
    for line in open(SRC / 'NGSL_12_lemmatized_for_teaching.csv', encoding='utf-8-sig'):
        if line.startswith('##') or not line.strip():
            continue
        p = [x.strip() for x in line.strip().split(',') if x.strip()]
        forms.setdefault(p[0].lower(), p[1:])

    authored = {}
    for f in sorted(AUTH.glob('words_*.tsv')):
        for p in tsv(f):
            authored[p[0].lower()] = p

    words, missing = [], []

    def add(word, band, rank, coverage):
        key = word.lower()
        if key in skip:
            return
        a = authored.get(key)
        if not a:
            missing.append(word)
            return
        head = a[0] if band == 'basic' else word if word not in ('TRUE', 'FALSE') else word.lower()
        u, k = IPA_FIX.get(key, (us.get(key, ''), uk.get(key, '')))
        words.append({
            'id': len(words) + 1, 'w': head, 'pos': a[1], 'tr': a[2], 'def': a[3], 'ex': a[4],
            'us': u, 'uk': k, 'band': band, 'rank': rank, 'cov': round(coverage, 2),
            'forms': [f for f in forms.get(key, []) if f.lower() != key][:8],
        })

    # Coverage: NGSL 1.2 covers about 92% of general English; NGSL-GR (5,000 words) about 98% (newgeneralservicelist.com).
    cum = 0.0
    for i, w in enumerate(ngsl):
        cum += freq[i]
        add(w, 'core', i + 1, 92.0 * cum / total)
    for i, w in enumerate(basic):
        add(w, 'basic', i + 1, 0)
    for i, w in enumerate(ext):
        # Frequency data for the extension isn't published; spread the remaining 6% with diminishing returns.
        t = (i + 1) / len(ext)
        add(w, 'ext', len(ngsl) + i + 1, 92.0 + 6.0 * (1 - (1 - t) ** 2))

    phrasal = []
    for p in tsv(AUTH / 'phrasal.tsv'):
        phrasal.append({'id': len(phrasal) + 1, 'w': p[0], 'tr': p[1], 'def': p[2], 'ex': p[3], 'type': p[4],
                        'us': ipa_for(p[0], us), 'uk': ipa_for(p[0], uk)})

    lessons = json.load(open(AUTH / 'lessons.json', encoding='utf-8'))
    for l in lessons:
        for q in l['quiz']:
            assert 0 <= q['answer'] < len(q['options']) and '___' in q['q'], (l['id'], q)

    ph = json.load(open(AUTH / 'phonetics.json', encoding='utf-8'))
    for s in ph['sounds']:
        s['examples'] = [{'w': w, 'us': us.get(w, ''), 'uk': uk.get(w, '')} for w in s.pop('words')]
    for p in ph['pairs']:
        for side in ('a', 'b'):
            w = p[side]
            p[side] = {'w': w, 'us': us.get(w.lower(), ''), 'uk': uk.get(w.lower(), '')}

    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in [('words', words), ('phrasal', phrasal), ('lessons', lessons), ('phonetics', ph)]:
        with open(OUT / f'{name}.json', 'w', encoding='utf-8', newline='\n') as f:
            json.dump(data, f, ensure_ascii=False, separators=(',', ':'))

    bands = {b: sum(1 for w in words if w['band'] == b) for b in ('basic', 'core', 'ext')}
    print('words', len(words), bands, 'phrasal', len(phrasal), 'lessons', len(lessons),
          'sounds', len(ph['sounds']), 'pairs', len(ph['pairs']))
    print('no US IPA:', [w['w'] for w in words if not w['us']][:20], 'no UK IPA:', sum(1 for w in words if not w['uk']))
    print('phrasal without IPA:', [p['w'] for p in phrasal if not p['us']])
    if missing:
        print('MISSING authored entries:', missing[:30], len(missing))
        sys.exit(1)
    for check in (1000, 2000, 2809):
        print(f'coverage after {check}: {words[check - 1]["cov"]}%')


if __name__ == '__main__':
    main()

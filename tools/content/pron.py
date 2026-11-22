"""Builds IPA transcriptions (US from CMUdict, UK from Britfone) for every word the app needs.

Usage: python -I tools/content/pron.py <cmudict.dict> <britfone.main.csv>
Writes content/sources/pron_us.tsv and content/sources/pron_uk.tsv (word \t ipa, stress marks before the
stressed syllable, syllables not dotted). Only the words in the app are kept so the repo stays small.

CMUdict: Copyright (C) 1993-2015 Carnegie Mellon University, BSD-style licence (content/sources/LICENSE-cmudict).
Britfone: Copyright (c) 2017 Jose Llarena, MIT licence (content/sources/LICENSE-britfone).
"""
import csv, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'content' / 'sources'

ARPA_V = {
    'AA': 'ɑː', 'AE': 'æ', 'AH': 'ʌ', 'AO': 'ɔː', 'AW': 'aʊ', 'AY': 'aɪ', 'EH': 'ɛ', 'ER': 'ɝː',
    'EY': 'eɪ', 'IH': 'ɪ', 'IY': 'iː', 'OW': 'oʊ', 'OY': 'ɔɪ', 'UH': 'ʊ', 'UW': 'uː',
}
ARPA_C = {
    'B': 'b', 'CH': 'tʃ', 'D': 'd', 'DH': 'ð', 'F': 'f', 'G': 'ɡ', 'HH': 'h', 'JH': 'dʒ', 'K': 'k', 'L': 'l',
    'M': 'm', 'N': 'n', 'NG': 'ŋ', 'P': 'p', 'R': 'r', 'S': 's', 'SH': 'ʃ', 'T': 't', 'TH': 'θ', 'V': 'v',
    'W': 'w', 'Y': 'j', 'Z': 'z', 'ZH': 'ʒ',
}
# Legal English syllable onsets (maximal onset principle), in IPA.
ONSETS = set()
for c in ['p', 'b', 't', 'd', 'k', 'ɡ', 'g', 'f', 'v', 'θ', 'ð', 's', 'z', 'ʃ', 'ʒ', 'h', 'tʃ', 'dʒ', 'm', 'n',
          'l', 'r', 'ɹ', 'w', 'j']:
    ONSETS.add((c,))
for a in ['p', 'b', 'k', 'ɡ', 'g', 'f', 'θ', 'ʃ']:
    for b in ['r', 'ɹ', 'l', 'w', 'j']:
        ONSETS.add((a, b))
for a in ['t', 'd']:
    for b in ['r', 'ɹ', 'w', 'j']:
        ONSETS.add((a, b))
for b in ['p', 't', 'k', 'm', 'n', 'l', 'w', 'f', 'j']:
    ONSETS.add(('s', b))
for a in ['m', 'n', 'h', 'v', 'l']:
    ONSETS.add((a, 'j'))
for a, b in [('s', 'p'), ('s', 't'), ('s', 'k')]:
    for c in ['r', 'ɹ', 'l', 'w', 'j']:
        if not (b == 't' and c in 'lw'):
            ONSETS.add((a, b, c))


def place_stress(segs):
    """segs: list of (phone, is_vowel, stress) → IPA string with ˈ/ˌ before the stressed syllable."""
    vowels = [i for i, s in enumerate(segs) if s[1]]
    if len(vowels) <= 1:
        return ''.join(s[0] for s in segs)
    starts = {vowels[0]: 0}
    for prev, cur in zip(vowels, vowels[1:]):
        cons = [segs[i][0] for i in range(prev + 1, cur)]
        k = 0
        for n in range(len(cons), 0, -1):
            if tuple(cons[len(cons) - n:]) in ONSETS:
                k = n
                break
        starts[cur] = cur - k
    primary = next((v for v in vowels if segs[v][2] == 1), None)
    for v in vowels:
        # Prefix vowels like the "im" of "important" carry a secondary stress in the sources; dictionaries drop it.
        if primary is not None and v < primary and segs[v][2] == 2 and segs[v][0] in ('ɪ', 'ə', 'i'):
            segs[v] = (segs[v][0], True, 0)
    out = []
    mark_at = {starts[v]: segs[v][2] for v in vowels}
    for i, s in enumerate(segs):
        m = mark_at.get(i)
        if m == 1:
            out.append('ˈ')
        elif m == 2:
            out.append('ˌ')
        out.append(s[0])
    return ''.join(out)


def cmu_to_ipa(phones):
    segs = []
    for p in phones:
        m = re.fullmatch(r'([A-Z]+)([012])?', p)
        base, st = m.group(1), m.group(2)
        if base in ARPA_V:
            st = int(st or 0)
            v = ARPA_V[base]
            if st == 0:
                v = {'ʌ': 'ə', 'ɝː': 'ɚ', 'iː': 'i', 'uː': 'u'}.get(v, v)
            segs.append((v, True, st))
        else:
            segs.append((ARPA_C[base], False, 0))
    return place_stress(segs)


def brit_to_ipa(tokens):
    segs = []
    for t in tokens:
        st = 0
        if t.startswith('ˈ'):
            st, t = 1, t[1:]
        elif t.startswith('ˌ'):
            st, t = 2, t[1:]
        vowel = bool(re.search('[aeiouæɐɑɒɔəɛɜɪʊʌ]', t))
        # Familiar dictionary symbols: ɐ→ʌ (STRUT), ɛ→e (DRESS), ɛə→eə (SQUARE).
        t = {'ɹ': 'r', 'g': 'ɡ', 'ɐ': 'ʌ', 'ɛ': 'e', 'ɛə': 'eə'}.get(t, t)
        segs.append((t, vowel, st))
    return place_stress(segs)


def needed_words():
    words = set()
    for f, col in [('NGSL_12_stats.csv', 'Lemma'), ('NGSL-GR_rank.csv', 'Word')]:
        for r in csv.DictReader(open(SRC / f, encoding='utf-8-sig')):
            words.add(r[col].strip().lower())
    for f in (ROOT / 'content' / 'authored').glob('*.tsv'):
        for line in open(f, encoding='utf-8'):
            if line.startswith('#') or not line.strip():
                continue
            head = line.split('\t')[0]
            for w in re.findall(r"[a-zA-Z']+", head):
                words.add(w.lower())
    import json
    ph = json.load(open(ROOT / 'content' / 'authored' / 'phonetics.json', encoding='utf-8'))
    for s in ph['sounds']:
        words.update(w.lower() for w in s['words'])
    for p in ph['pairs']:
        words.update([p['a'].lower(), p['b'].lower()])
    return words


def main():
    cmu_path, brit_path = sys.argv[1], sys.argv[2]
    need = needed_words()
    us, uk = {}, {}
    for line in open(cmu_path, encoding='utf-8'):
        line = line.split('#')[0].strip()
        if not line:
            continue
        head, *ph = line.split()
        word = re.sub(r'\(\d+\)$', '', head).lower()
        if word in need and word not in us:
            us[word] = cmu_to_ipa(ph)
    for line in open(brit_path, encoding='utf-8'):
        if ',' not in line:
            continue
        head, pr = line.rstrip('\n').split(',', 1)
        word = re.sub(r'\(\d+\)$', '', head).lower()
        if word in need and word not in uk:
            uk[word] = brit_to_ipa(pr.split())
    for name, d in [('pron_us.tsv', us), ('pron_uk.tsv', uk)]:
        with open(SRC / name, 'w', encoding='utf-8', newline='\n') as f:
            for w in sorted(d):
                f.write(f'{w}\t{d[w]}\n')
    print(f'needed {len(need)}, US {len(us)}, UK {len(uk)}')
    missing = sorted(w for w in need if w not in us)
    print('missing US:', len(missing), missing[:60])


if __name__ == '__main__':
    main()

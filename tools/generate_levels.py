#!/usr/bin/env python3
"""Generate the level database (data/levels.json) for Zen Word Puzzle.

Word sources (downloaded automatically into tools/.cache on first run):
  * SCOWL (http://wordlist.aspell.net/) size <= 35  -> common words used as answers
  * ENABLE word list                                  -> extra valid words (bonus words)
  * LDNOOBW bad-word list                             -> removed from everything
Word frequencies come from the `wordfreq` python package (pip install wordfreq).

Usage:  python3 tools/generate_levels.py [--levels 3000] [--daily 400] [--seed 7]

Output format (data/levels.json):
  {"version": 1, "levels": ["BASE|ANSWER,ANSWER,...|BONUS,BONUS,...", ...], "daily": [...]}
The first field is the full word the letter wheel is built from; the game shuffles it.
"""
import argparse
import glob
import io
import json
import os
import random
import re
import tarfile
import urllib.request
from collections import Counter
from itertools import combinations

from wordfreq import zipf_frequency

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".cache")
OUT = os.path.join(HERE, "..", "data", "levels.json")

SCOWL_URL = "https://downloads.sourceforge.net/wordlist/scowl-2020.12.07.tar.gz"
ENABLE_URL = "https://raw.githubusercontent.com/dolph/dictionary/master/enable1.txt"
BAD_URL = ("https://raw.githubusercontent.com/LDNOOBW/"
           "List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/master/en")

# Words that are technically valid but feel wrong as puzzle answers
# (abbreviation-like, archaic, odd plurals of pronouns, sensitive, ...).
ANSWER_BLOCK = set("""
hes ifs ohs pis wot qua tis eta ani ain sri nth ere tae ens oes hin
ays nae nus pas mas pes ups ems ens els ess ats ers ids bis dis fas los
mus nos ons sis tas ti yer yon thee thou thy hath doth
sex sexy sexes nude nudes naked drug drugs dope gay gays lesbian
nazi nazis rape raped rapes rapist kill kills killed killer slay slain
die dies died dead death corpse suicide murder murders bomb bombs gun guns
hell damn damned devil satan sin sins sinned booze beer beers wine vodka
whore pimp pimps slut sluts porn bitch hate hated hates racist racism
abort aborts abortion fetus incest pee piss poop crap fart farts barf puke
pot pothead weed stoned heroin cocaine meth opium
ass asses butt butts boob boobs breast breasts nipple nipples
bra bras panty panties thong thongs
negro negroes nigger
""".split())

# Removed from bonus words too.
EXTRA_BAD = set("""
nigger niggers negro negroes fag fags faggot faggots dyke dykes kike kikes
spic spics chink chinks gook gooks wop wops coon coons retard retards
cunt cunts twat twats fuck fucks shit shits cock cocks dick dicks
porn porno slut sluts whore whores rape rapes raped rapist nazi nazis
""".split())


def fetch(url, name):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        print("downloading", url)
        with urllib.request.urlopen(url) as r, open(path, "wb") as f:
            f.write(r.read())
    return path


def load_scowl(max_size):
    path = fetch(SCOWL_URL, "scowl.tar.gz")
    sizes = [n for n in (10, 20, 35, 40, 50, 55, 60, 70) if n <= max_size]
    words = set()
    with tarfile.open(path) as tar:
        for m in tar.getmembers():
            base = os.path.basename(m.name)
            mm = re.fullmatch(r"(english|american)-words\.(\d+)", base)
            if mm and int(mm.group(2)) in sizes:
                data = tar.extractfile(m).read().decode("latin-1")
                for w in data.split():
                    if re.fullmatch("[a-z]+", w):
                        words.add(w)
    return words


def load_lines(url, name):
    with open(fetch(url, name), encoding="utf-8", errors="ignore") as f:
        return [w.strip().lower() for w in f if w.strip()]


def signature(word):
    return "".join(sorted(word))


def sub_signatures(base):
    """All distinct sorted sub-multisets (length >= 3) of the letters of base."""
    letters = sorted(base)
    out = set()
    for k in range(3, len(letters) + 1):
        for combo in combinations(letters, k):
            out.add("".join(combo))
    return out


# --- difficulty curve -------------------------------------------------------
# (first_level, letter_counts(weighted), min_words, max_words, answer_zipf, base_zipf)
STAGES = [
    (1,    [3],                2,  3, 4.3, 4.5),
    (6,    [4],                3,  5, 4.1, 4.3),
    (16,   [4, 4, 5],          3,  6, 4.0, 4.1),
    (41,   [5],                4,  7, 3.8, 3.9),
    (101,  [5, 5, 6],          5,  9, 3.6, 3.7),
    (251,  [6],                6, 11, 3.4, 3.5),
    (501,  [6, 7],             7, 13, 3.25, 3.3),
    (901,  [7],                8, 15, 3.1, 3.2),
    (1501, [7, 7, 8],          9, 17, 2.9, 3.0),
    (2201, [7, 8],            10, 19, 2.7, 2.9),
    (2701, [8, 8, 7],         11, 21, 2.5, 2.8),
]
CHAPTER_SIZE = 20


def stage_for(n):
    st = STAGES[0]
    for s in STAGES:
        if n >= s[0]:
            st = s
    return st


def wave(n, lo, hi):
    """Sawtooth inside a chapter: gentle start, challenge on the last level."""
    pos = (n - 1) % CHAPTER_SIZE
    if pos < 2:
        hi = max(lo, hi - 2)
    if pos == CHAPTER_SIZE - 1 and n > CHAPTER_SIZE:
        lo = min(hi, lo + 2)
        hi = hi + 2
    return lo, hi


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", type=int, default=3000)
    ap.add_argument("--daily", type=int, default=400)
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()
    rnd = random.Random(args.seed)

    bad = set(load_lines(BAD_URL, "bad.txt")) | EXTRA_BAD
    enable = set(load_lines(ENABLE_URL, "enable1.txt"))
    common = (load_scowl(35) & enable) - bad - ANSWER_BLOCK
    valid = (enable | load_scowl(50)) - bad - EXTRA_BAD

    freq = {}

    def zf(w):
        if w not in freq:
            freq[w] = zipf_frequency(w, "en")
        return freq[w]

    answer_by_sig = {}
    for w in common:
        if 3 <= len(w) <= 8 and zf(w) >= 2.3:
            answer_by_sig.setdefault(signature(w), []).append(w)
    valid_by_sig = {}
    for w in valid:
        if 3 <= len(w) <= 8:
            valid_by_sig.setdefault(signature(w), []).append(w)

    used_sigs = set()
    used_words = set()
    sub_cache = {}

    def analyse(base, ans_zipf):
        sig = signature(base)
        if sig not in sub_cache:
            sub_cache[sig] = sub_signatures(base)
        answers, bonus = [], []
        for s in sub_cache[sig]:
            for w in answer_by_sig.get(s, ()):
                (answers if zf(w) >= ans_zipf else bonus).append(w)
            for w in valid_by_sig.get(s, ()):
                bonus.append(w)
        answers = set(answers)
        bonus = set(bonus) - answers
        return answers, bonus

    def build(base, lo, hi, ans_zipf, late):
        answers, bonus = analyse(base, ans_zipf)
        full = [w for w in answers if len(w) == len(base)]
        if base not in answers or len(answers) < lo:
            return None
        # Keep the words players are most likely to know; late levels favour long words.
        rest = sorted((w for w in answers if len(w) < len(base)),
                      key=lambda w: -(zf(w) + (0.35 * len(w) if late else 0.0)))
        keep = full[:2] + rest
        keep = keep[:hi]
        if len(keep) < lo:
            return None
        dropped = answers - set(keep)
        bonus |= dropped
        ease = sum(zf(w) for w in keep) / len(keep) - 0.04 * len(keep)
        # Well-known words that did not fit feel unfair as "bonus" words.
        missed = sum(1 for w in dropped if zf(w) >= 4.0)
        return keep, sorted(bonus), ease, missed

    candidates_by_len = {}
    for w in common:
        if 3 <= len(w) <= 8:
            candidates_by_len.setdefault(len(w), []).append(w)
    for L in candidates_by_len:
        candidates_by_len[L].sort()
        rnd.shuffle(candidates_by_len[L])

    def pick(n, pool_len, lo, hi, ans_zipf, base_zipf, late, sample=60):
        found = []
        for w in candidates_by_len[pool_len]:
            if w in used_words or signature(w) in used_sigs or zf(w) < base_zipf:
                continue
            res = build(w, lo, hi, ans_zipf, late)
            if res:
                found.append((w, res))
                if len(found) >= sample:
                    break
        return found

    levels = []
    n = 1
    total = args.levels
    while n <= total:
        st = stage_for(n)
        nxt = next((s[0] for s in STAGES if s[0] > n), total + 1)
        end = min(nxt, total + 1)
        # Build the whole stage, then order it from easiest to hardest.
        stage_levels = []
        for k in range(n, end):
            lens = st[1]
            L = lens[rnd.randrange(len(lens))]
            lo, hi = wave(k, st[2], st[3])
            late = k > 900
            relax = 0.0
            options = []
            while not options and relax < 1.6:
                options = pick(k, L, lo, hi, st[4] - relax, st[5] - relax, late)
                if not options:
                    if lo > 2:
                        lo -= 1
                    relax += 0.2
            if not options:
                raise SystemExit(f"no candidates for level {k} (len {L})")
            # Most "natural" option among a sample: easiest base word with enough words.
            options.sort(key=lambda o: (o[1][3], -o[1][2]))
            w, (keep, bonus, ease, _) = options[rnd.randrange(min(4, len(options)))]
            used_words.add(w)
            used_sigs.add(signature(w))
            stage_levels.append((ease, k, w, keep, bonus))
        # Order by ease, keeping chapter sawtooth (challenge levels stay at chapter ends).
        regular = [x for x in stage_levels if not ((x[1] - 1) % CHAPTER_SIZE == CHAPTER_SIZE - 1)]
        challenge = [x for x in stage_levels if (x[1] - 1) % CHAPTER_SIZE == CHAPTER_SIZE - 1]
        regular.sort(key=lambda x: -x[0])
        challenge.sort(key=lambda x: -x[0])
        ri = ci = 0
        for k in range(n, end):
            if (k - 1) % CHAPTER_SIZE == CHAPTER_SIZE - 1 and ci < len(challenge):
                item = challenge[ci]; ci += 1
            elif ri < len(regular):
                item = regular[ri]; ri += 1
            else:
                item = challenge[ci]; ci += 1
            levels.append(item)
        n = end
        print(f"stage up to {end - 1}: {len(levels)} levels")

    daily = []
    for _ in range(args.daily):
        L = rnd.choice([6, 7, 7])
        opts = pick(0, L, 8, 14, 3.2, 3.3, True, sample=12)
        opts.sort(key=lambda o: (o[1][3], -o[1][2]))
        w, (keep, bonus, ease, _) = opts[rnd.randrange(min(4, len(opts)))]
        used_words.add(w)
        used_sigs.add(signature(w))
        daily.append((ease, 0, w, keep, bonus))

    def encode(item):
        _, _, base, keep, bonus = item
        keep = sorted(keep, key=lambda w: (len(w), w))
        return f"{base.upper()}|{','.join(keep).upper()}|{','.join(bonus).upper()}"

    data = {"version": 1, "chapter_size": CHAPTER_SIZE,
            "levels": [encode(x) for x in levels],
            "daily": [encode(x) for x in daily]}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(data, f, separators=(",", ":"))
        f.write("\n")
    print("wrote", OUT, len(levels), "levels,", len(daily), "daily")
    for i in (0, 1, 4, 9, 19, 49, 99, 299, 999, 1999, 2999):
        if i < len(levels):
            print(i + 1, encode(levels[i])[:150])


if __name__ == "__main__":
    main()

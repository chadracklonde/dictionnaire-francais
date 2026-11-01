#!/usr/bin/env python3
"""Moteur de conjugaison de référence (Python).

Même algorithme que engine/lib/conjugation.dart : il sert à valider les
données (conjugation_models.json) et les résultats attendus (expected.json).

    python3 conjugation_ref.py manger
    python3 conjugation_ref.py "se laver"
"""

import json
import re
import sys
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "engine" / "data" / "conjugation_models.json"

PERSONS = ["je", "tu", "il/elle", "nous", "vous", "ils/elles"]
REFLEXIVE = ["me", "te", "se", "nous", "vous", "se"]
ELISION = {"je": "j'", "que": "qu'", "me": "m'", "te": "t'", "se": "s'"}
VOWELS = "aeiouyâàäéèêëîïôöûùü"
VOWELS_SCAN = "aeiouâêîôûéèïü"
CIRC = {"a": "â", "e": "ê", "i": "î", "o": "ô", "u": "û"}
CONS = "bcdfghjklmnpqrstvwxz"

IMPF_END = ["ais", "ais", "ait", "ions", "iez", "aient"]
FUT_END = ["ai", "as", "a", "ons", "ez", "ont"]
PS1_END = ["ai", "as", "a", "âmes", "âtes", "èrent"]
PP_AGREE = ["(e)", "(e)", "(e)", "(e)s", "(e)(s)", "(e)s"]

# Verbes en -eler / -eter : accent grave par défaut (acheter, geler, peler…) ;
# ils doublent la consonne dans ces familles (appeler, jeter, ...).
DOUBLE_RE = re.compile(r"(ppeler|épeler|jeter|ouveler|raveler|museler|hâteler|gameler|usseler|usseter|cemeler|hemeler|onceler|abreter|ueneter|crespeler|empaqueter|encorseter|ippeler|espeler|ficeler|niveler|étinceler|ensorceler|chanceler|morceler|renouveler|bretteler|ruisseler|denteler|atteler|anneler|écheveler|ébûcheter|dételer|feuilleter|cacheter|étiqueter|voleter|hoqueter|épousseter|souffleter|breloqueter|pelleter|rebuter)$")
RE_E_ACUTE = re.compile("é([^aeiouyéèêëàâäîïôöûùü]{1,2})$")
RE_E_GU = re.compile("é(gu|qu)$")

MOODS = {
    "indicatif": ["present", "passe_compose", "imparfait", "plus_que_parfait",
                  "passe_simple", "passe_anterieur", "futur_simple", "futur_anterieur"],
    "subjonctif": ["present", "passe", "imparfait", "plus_que_parfait"],
    "conditionnel": ["present", "passe"],
    "imperatif": ["present", "passe"],
    "infinitif": ["present", "passe"],
    "participe": ["present", "passe"],
}


# ---------------------------------------------------------------- utilitaires

def soft(stem, ending):
    """c -> ç et g -> ge devant a, o, â."""
    if ending and ending[0] in "aoâ":
        if stem.endswith("c"):
            return stem[:-1] + "ç"
        if stem.endswith("g"):
            return stem + "e"
    return stem


def circumflex(stem):
    for i in range(len(stem) - 1, -1, -1):
        ch = stem[i]
        if ch in VOWELS_SCAN:
            return stem[:i] + CIRC.get(ch, ch) + stem[i + 1:]
    return stem


def subj_imparfait(ps):
    if not ps or not ps[1].endswith("s"):
        return None
    stem = ps[1][:-1]
    return [stem + "sse", stem + "sses", circumflex(stem) + "t",
            stem + "ssions", stem + "ssiez", stem + "ssent"]


def elides(word, h_aspire):
    first = word[0]
    if first in VOWELS:
        return True
    return first == "h" and not h_aspire


def join_tokens(tokens, h_aspire):
    out = ""
    prev = None
    for tok in tokens:
        if not tok:
            continue
        if prev is None:
            out = tok
        elif prev in ELISION and elides(tok, h_aspire):
            out = out[:len(out) - len(prev)] + ELISION[prev] + tok
        else:
            out += " " + tok
        prev = tok
    return out


# ------------------------------------------------------------- formes simples

def group1(inf):
    stem = inf[:-2]
    kind = "plain"
    sstem = stem
    if len(stem) > 2 and stem.endswith("y") and not stem.endswith("ey"):
        kind, sstem = "y", stem[:-1] + "i"
    elif stem.endswith("el") or stem.endswith("et"):
        if not DOUBLE_RE.search(re.sub(r"^s[’']", "", inf)):
            kind, sstem = "grave", stem[:-2] + "è" + stem[-1]
        else:
            kind, sstem = "double", stem + stem[-1]
    elif len(stem) >= 2 and stem[-2] == "e" and stem[-1] in CONS:
        kind, sstem = "grave", stem[:-2] + "è" + stem[-1]
    else:
        m = RE_E_ACUTE.search(stem) or RE_E_GU.search(stem)
        if m:
            kind, sstem = "acute", stem[:m.start()] + "è" + stem[m.start() + 1:]

    pres = [sstem + "e", sstem + "es", sstem + "e",
            soft(stem, "ons") + "ons", stem + "ez", sstem + "ent"]
    impf = [soft(stem, e) + e for e in IMPF_END]
    ps = [soft(stem, e) + e for e in PS1_END]
    fut_base = (stem if kind == "acute" else sstem) + "er"
    if inf.endswith("envoyer"):
        fut_base = stem[:-2] + "err"
    return {
        "pres": pres, "impf": impf, "ps": ps,
        "fut": [fut_base + e for e in FUT_END],
        "cond": [fut_base + e for e in IMPF_END],
        "subj": [sstem + "e", sstem + "es", sstem + "e",
                 stem + "ions", stem + "iez", sstem + "ent"],
        "pp": stem + "é",
        "prp": soft(stem, "ant") + "ant",
        "imp": [pres[0], pres[3], pres[4]],
    }


def group2(inf):
    stem = inf[:-2]
    pres = [stem + e for e in ["is", "is", "it", "issons", "issez", "issent"]]
    return {
        "pres": pres,
        "impf": [stem + "iss" + e for e in IMPF_END],
        "ps": [stem + e for e in ["is", "is", "it", "îmes", "îtes", "irent"]],
        "fut": [inf + e for e in FUT_END],
        "cond": [inf + e for e in IMPF_END],
        "subj": [stem + e for e in ["isse", "isses", "isse", "issions", "issiez", "issent"]],
        "pp": stem + "i",
        "prp": stem + "issant",
        "imp": [pres[1], pres[3], pres[4]],
    }


class Conjugator:
    def __init__(self, data=None):
        if data is None:
            data = json.loads(DATA.read_text(encoding="utf-8"))
        self.models = data["models"]
        self.etre_verbs = set(data["etre_verbs"])
        self.impersonal = set(data["impersonal"])
        self.h_aspire = set(data["h_aspire"])

    def find_model(self, inf):
        best, best_score = None, -1
        for model in self.models.values():
            if inf in model.get("exclude", []):
                continue
            for pat in model["match"]:
                if pat.startswith("^"):
                    if inf != pat[1:]:
                        continue
                    score = 1000 + len(pat)
                elif inf.endswith(pat):
                    score = len(pat)
                else:
                    continue
                if score > best_score:
                    best, best_score = model, score
        return best

    def from_model(self, inf, m):
        root = inf[:len(inf) - len(m["strip"])]

        def tails(text):
            return [root + ("" if t == "_" else t) for t in text.split()]

        pres = tails(m["pres"])
        impf_stem = root + ("" if m["impf"] == "_" else m["impf"])
        fut_stem = root + m["fut"]
        if "subj" in m:
            subj = tails(m["subj"])
        else:
            s1 = pres[5][:-3]
            subj = [s1 + "e", s1 + "es", s1 + "e", impf_stem + "ions",
                    impf_stem + "iez", s1 + "ent"]
        imp_spec = m.get("imp")
        if imp_spec == "none":
            imp = None
        elif imp_spec:
            imp = tails(imp_spec)
        else:
            tu = pres[1][:-1] if pres[1].endswith("es") else pres[1]
            imp = [tu, pres[3], pres[4]]
        return {
            "pres": pres,
            "impf": [impf_stem + e for e in IMPF_END],
            "ps": tails(m["ps"]) if "ps" in m else None,
            "fut": [fut_stem + e for e in FUT_END],
            "cond": [fut_stem + e for e in IMPF_END],
            "subj": subj,
            "pp": root + m["pp"],
            "prp": root + m["prp"] if "prp" in m else impf_stem + "ant",
            "imp": imp,
        }

    def simple_forms(self, inf):
        model = self.find_model(inf)
        if model:
            return self.from_model(inf, model)
        if inf.endswith("er"):
            return group1(inf)
        if inf.endswith("ir"):
            return group2(inf)
        return None

    # ---------------------------------------------------------- conjugaison

    def conjugate(self, text):
        inf = text.strip().lower().replace("’", "'")
        reflexive = False
        if inf.startswith("se "):
            reflexive, inf = True, inf[3:].strip()
        elif inf.startswith("s'"):
            reflexive, inf = True, inf[2:].strip()
        s = self.simple_forms(inf)
        if s is None:
            return None

        use_etre = reflexive or inf in self.etre_verbs
        aux = self.simple_forms("être" if use_etre else "avoir")
        impersonal = inf in self.impersonal
        h_asp = inf in self.h_aspire
        pp = s["pp"]

        def agree(i):
            return pp + PP_AGREE[i] if use_etre else pp

        def row(forms, subjunctive=False):
            rows = []
            for i, f in enumerate(forms):
                if not f or (impersonal and i != 2):
                    rows.append("")
                    continue
                pron = "il" if impersonal else PERSONS[i]
                toks = ["que"] if subjunctive else []
                toks.append(pron)
                if reflexive:
                    toks.append(REFLEXIVE[i])
                toks.append(f)
                rows.append(join_tokens(toks, h_asp))
            return rows

        def compound(aux_forms):
            if not aux_forms:
                return [""] * 6
            return [f"{aux_forms[i]} {agree(i)}" for i in range(6)]

        def blank(forms):
            return forms if forms else [""] * 6

        subj_imp = subj_imparfait(s["ps"])
        aux_subj_imp = subj_imparfait(aux["ps"])
        moods = {}
        moods["indicatif"] = {
            "present": row(s["pres"]),
            "passe_compose": row(compound(aux["pres"])),
            "imparfait": row(s["impf"]),
            "plus_que_parfait": row(compound(aux["impf"])),
            "passe_simple": row(blank(s["ps"])),
            "passe_anterieur": row(compound(aux["ps"])) if s["ps"] else [""] * 6,
            "futur_simple": row(s["fut"]),
            "futur_anterieur": row(compound(aux["fut"])),
        }
        moods["subjonctif"] = {
            "present": row(s["subj"], True),
            "passe": row(compound(aux["subj"]), True),
            "imparfait": row(blank(subj_imp), True),
            "plus_que_parfait": row(compound(aux_subj_imp), True) if subj_imp else [""] * 6,
        }
        moods["conditionnel"] = {
            "present": row(s["cond"]),
            "passe": row(compound(aux["cond"])),
        }

        if s["imp"] is None or impersonal:
            imp_now, imp_past = [], []
        else:
            tu, nous, vous = s["imp"]
            if reflexive:
                imp_now = [tu + "-toi", nous + "-nous", vous + "-vous"]
                imp_past = []
            else:
                imp_now = [tu, nous, vous]
                a_tu, a_nous, a_vous = aux["imp"]
                imp_past = [f"{a_tu} {agree(1)}", f"{a_nous} {agree(3)}",
                            f"{a_vous} {agree(4)}"]
        moods["imperatif"] = {"present": imp_now, "passe": imp_past}

        inf_aux = "être" if use_etre else "avoir"
        pp_any = pp + "(e)(s)" if use_etre else pp
        moods["infinitif"] = {
            "present": [join_tokens((["se"] if reflexive else []) + [inf], h_asp)],
            "passe": [join_tokens((["se"] if reflexive else []) + [inf_aux, pp_any], False)],
        }
        part_aux = "étant" if use_etre else "ayant"
        moods["participe"] = {
            "present": [join_tokens((["se"] if reflexive else []) + [s["prp"]], h_asp)],
            "passe": [pp, join_tokens((["se"] if reflexive else []) + [part_aux, pp_any], False)],
        }
        return {
            "infinitive": inf,
            "reflexive": reflexive,
            "auxiliary": inf_aux,
            "pastParticiple": pp,
            "presentParticiple": s["prp"],
            "moods": moods,
        }


if __name__ == "__main__":
    result = Conjugator().conjugate(" ".join(sys.argv[1:]) or "manger")
    if result is None:
        print("Verbe inconnu")
        sys.exit(1)
    print(f"{result['infinitive']} (aux. {result['auxiliary']}, "
          f"participe passé « {result['pastParticiple']} »)")
    for mood, tenses in result["moods"].items():
        print(f"\n== {mood}")
        for tense, forms in tenses.items():
            print(f"  {tense}: {' | '.join(f for f in forms if f)}")
